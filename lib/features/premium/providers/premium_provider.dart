import 'package:flutter/foundation.dart';

import '../models/entitlement.dart';
import '../models/premium_plan.dart';
import '../services/entitlement_repository.dart';
import '../services/entitlement_store.dart';

/// What a purchase or restore attempt did. Phase 2B only ever produces
/// [notAvailableYet]; the other values exist so 2C fills in a switch the UI
/// already handles rather than reshaping the call sites.
enum StoreOutcome {
  /// Billing is not wired yet (Phase 2C, task 2.8).
  notAvailableYet,
  success,
  cancelled,
  failed,

  /// The store had nothing to give back. Distinct from [failed] because
  /// "you have no purchases on this account" is a normal answer that deserves
  /// its own message, not an error.
  nothingToRestore,
}

/// **The single source of truth for whether the app is unlocked.**
///
/// Every gate in the app reads `isPremium` from here and nowhere else. The UI,
/// the gates and the paywall are finished and testable now; Phase 2C task 2.8
/// replaces the two stubs below ([purchase] and [restore]) with
/// `in_app_purchase` calls. No screen changes.
///
/// ## How this works without a user system
///
/// There is none, deliberately (§7 — no Firebase Auth in the app). Google Play
/// and the App Store hold the identity: a purchase attaches to the **Google
/// account / Apple ID**, not to the handset.
///
/// Both products are **auto-renewing subscriptions** again since 2026-08-30
/// (see [PremiumPlan]), and the store account is enough on its own: a
/// subscription is replayed on a new device by `restorePurchases()` on both
/// platforms. Two layers now, in order of authority:
///
/// 1. **The store** — the truth, including cancellation, refund, pause and a
///    lapse on a failed payment, none of which any local record can know.
/// 2. **[EntitlementStore]** — a local cache so the app opens correctly
///    offline and does not flash the paywall at someone who has paid.
///
/// Entitlements still do not cross between Android and iOS, which the paywall
/// says out loud (`premium_platform_note`).
class PremiumProvider extends ChangeNotifier {
  PremiumProvider({EntitlementStore? store, EntitlementRepository? repository})
      : _store = store ?? EntitlementStore.instance,
        _repository = repository ?? EntitlementRepository.instance;

  final EntitlementStore _store;
  final EntitlementRepository _repository;

  /// How many Safety Radar results the free tier shows before the upsell card.
  /// Enough to prove the feature works, few enough that a busy area is
  /// visibly cut short.
  static const freeRadarResultLimit = 3;

  /// QA unlock for builds that cannot use the debug switch in Profile — set it
  /// on any build QA needs unlocked without paying:
  ///   flutter run --dart-define=PREMIUM_OVERRIDE=true
  ///
  /// Defaults to false, so a release build produced without the flag ships
  /// locked. It is deliberately a compile-time constant: nothing at runtime can
  /// turn it on.
  static const bool qaOverrideFlag =
      bool.fromEnvironment('PREMIUM_OVERRIDE');

  Entitlement? _entitlement;
  bool _loaded = false;

  /// False until [load] has read the cache. `main()` awaits [load] before
  /// `runApp`, exactly as it already does for the saved locale, so this is
  /// true from the first frame and no screen has to handle an "unknown" state.
  bool get isLoaded => _loaded;

  Entitlement? get entitlement => _entitlement;

  bool get isPremium {
    if (qaOverrideFlag) return true;
    final current = _entitlement;
    return current != null && current.isActiveAt(DateTime.now().toUtc());
  }

  /// True when access came from the QA override rather than a purchase, so the
  /// Profile card can label it honestly instead of showing a fake plan.
  bool get isQaUnlocked =>
      qaOverrideFlag || _entitlement?.source == EntitlementSource.qaOverride;

  /// True while the free trial is what is granting access — the Profile card
  /// and the paywall both say something different in that case, because a user
  /// on day 2 of a trial has not paid and should be told the clock is running.
  bool get isOnTrial {
    final current = _entitlement;
    return current != null &&
        current.isTrial &&
        current.isActiveAt(DateTime.now().toUtc());
  }

  /// Whole days left on the current pass or trial, rounded up so the last
  /// partial day still reads as "1 day" rather than "0".
  int? get daysRemaining {
    final current = _entitlement;
    if (current == null) return null;
    final left = current.remainingAt(DateTime.now().toUtc());
    if (left == Duration.zero) return 0;
    return (left.inMinutes / (24 * 60)).ceil();
  }

  Future<void> load() async {
    _entitlement = await _store.read();
    _loaded = true;
    notifyListeners();
  }

  /// Grants the 3-day trial, once per install, to someone who has never had a
  /// pass.
  ///
  /// 🚨 **Superseded, but not yet replaceable.** A store-run free trial
  /// attaches to a subscription, and both products became subscriptions on
  /// 2026-08-30 — so 2.8 should move this to a store introductory offer and
  /// delete this method. It survives because a build with no billing wired has
  /// no other way to reach the paid state, and deleting it before its
  /// replacement works would leave the trial untestable.
  ///
  /// Called from the first screen after [load], not from `main()`, so a user
  /// who already subscribed is never touched by it.
  ///
  /// Refuses when: the trial was already used on this install, or anything is
  /// currently active. It deliberately does **not** check Firestore first —
  /// that would put a network round-trip in front of the first frame to defend
  /// against someone reinstalling for 3 free days.
  Future<bool> startTrialIfEligible() async {
    if (_entitlement != null) return false;
    if (await _store.trialUsed()) return false;

    final trial = Entitlement.trial(startedAt: DateTime.now().toUtc());
    _entitlement = trial;
    await _store.write(trial);
    await _store.markTrialUsed();
    notifyListeners();
    return true;
  }

  /// Phase 2C, task 2.8 replaces this body with the Play Billing / StoreKit
  /// flow. Everything around it — the paywall, the gates, the Profile card —
  /// is already written against this signature.
  ///
  /// What 2.8 has to do, once the store confirms a purchase:
  ///   1. build the [Entitlement] from **what the store reported** — the
  ///      subscription's own expiry date, not `now + plan.duration`. A
  ///      subscription can be cancelled, refunded, paused or lapse on a failed
  ///      payment, and a duration knows none of that;
  ///   2. `await grantPurchase(...)` below, which caches it;
  ///   3. **acknowledge** the Play purchase. Never consume it — a subscription
  ///      is not a consumable, and consuming one is not a thing to do.
  ///
  /// ⚠️ `grantPurchase` still derives the expiry from `plan.duration`, which is
  /// only correct while nothing real is wired. 2.8 must give it the store's
  /// date instead; the signature already takes one.
  Future<StoreOutcome> purchase(PremiumPlan plan) async {
    return StoreOutcome.notAvailableYet;
  }

  /// "Restore Purchases". Required by both stores.
  ///
  /// 2C wires this to `InAppPurchase.restorePurchases()` and grants whatever
  /// active subscription the store reports.
  ///
  /// ✅ **This works on iOS and Android alike since 2026-08-30.** It did not
  /// while the products were one-time consumables: StoreKit never replays a
  /// consumable, so an iPhone had nothing to restore, and the client accepted
  /// that on 2026-08-23. Subscriptions are replayed on both platforms, so the
  /// limitation is gone — `premium_platform_note` no longer discloses it, and
  /// the test that used to pin the disclosure now pins its absence. **Do not
  /// reintroduce the per-platform warning:** it would now scare users away
  /// from something that works.
  Future<StoreOutcome> restore() async {
    return StoreOutcome.notAvailableYet;
  }

  /// Applies a confirmed purchase. Split out from [purchase] so 2C wires the
  /// store SDK to a method that is already covered by tests.
  ///
  /// Writes the local cache first: the pass must survive the app closing even
  /// if Firestore is unreachable at that moment.
  Future<void> grantPurchase({
    required PremiumPlan plan,
    required String purchaseId,
    DateTime? purchasedAt,
  }) async {
    final start = (purchasedAt ?? DateTime.now()).toUtc();
    final entitlement = Entitlement(
      plan: plan,
      source: EntitlementSource.store,
      expiresAt: start.add(plan.duration),
      purchaseId: purchaseId,
    );

    _entitlement = entitlement;
    await _store.write(entitlement);
    notifyListeners();

    // Best-effort, and last: this is what makes the pass recoverable on
    // another device, but failing it must not cost the user the purchase they
    // just made.
    await _repository.save(entitlement);
  }

  /// Rebuilds access from purchases the store says this account owns.
  ///
  /// Keeps whichever entitlement runs longest — including the one already
  /// cached, so restoring can never shorten a pass the user is part way
  /// through.
  Future<StoreOutcome> restoreFromPurchaseIds(
    Iterable<String> purchaseIds,
  ) async {
    if (purchaseIds.isEmpty) return StoreOutcome.nothingToRestore;

    final found = await _repository.restoreBest(purchaseIds);
    if (found == null) return StoreOutcome.nothingToRestore;

    final current = _entitlement;
    if (current != null && !current.expiresAt.isBefore(found.expiresAt)) {
      return StoreOutcome.success;
    }

    _entitlement = found;
    await _store.write(found);
    notifyListeners();
    return StoreOutcome.success;
  }

  /// QA unlock from the debug switch in Profile.
  ///
  /// Refuses outside debug builds even if something calls it, so the switch can
  /// never become a way to unlock a shipped app. Written through the cache so
  /// it survives a restart the way a real pass would, tagged
  /// [EntitlementSource.qaOverride] so it is always distinguishable from one,
  /// and never filed in Firestore.
  Future<void> qaUnlock(PremiumPlan plan) async {
    if (!kDebugMode) return;

    final entitlement = Entitlement(
      plan: plan,
      source: EntitlementSource.qaOverride,
      expiresAt: DateTime.now().toUtc().add(plan.duration),
    );

    _entitlement = entitlement;
    await _store.write(entitlement);
    notifyListeners();
  }

  Future<void> qaLock() async {
    if (!kDebugMode) return;
    _entitlement = null;
    await _store.clear();
    notifyListeners();
  }
}
