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
/// That alone was enough while the plans were subscriptions. It is not enough
/// now. Both products are **one-time consumables** (see [PremiumPlan]), and
/// consumables are not replayed on a new device the way a subscription is — so
/// each purchase is also filed in Firestore under its store transaction id
/// ([EntitlementRepository]) and a restore reads it back. Three layers, in
/// order of authority:
///
/// 1. **The store receipt** — the truth. 2C validates it.
/// 2. **Firestore** — how much time is left, readable from any device.
/// 3. **[EntitlementStore]** — a local cache so the app opens correctly
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
  /// The stores cannot do this for us — a store-run free trial only attaches to
  /// a subscription, and both products are one-time passes — so the app grants
  /// it and owns the clock. Called from the first screen after [load], not from
  /// `main()`, so a user who already bought something is never touched by it.
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
  /// What 2.8 has to do, in order, once the store confirms a purchase:
  ///   1. build the [Entitlement] with `expiresAt = now + plan.duration` and
  ///      the store's transaction id as `purchaseId`;
  ///   2. `await grantPurchase(...)` below, which caches it and files it;
  ///   3. **acknowledge but do not consume** the Play purchase until the pass
  ///      expires — a consumed purchase stops being returned by
  ///      `queryPurchases`, which is what makes a restore possible at all.
  Future<StoreOutcome> purchase(PremiumPlan plan) async {
    return StoreOutcome.notAvailableYet;
  }

  /// "Restore Purchases". Required by both stores, and it has real work to do
  /// here: a consumable pass bought on another phone is only recoverable
  /// through the Firestore copy.
  ///
  /// 2C wires this to `InAppPurchase.restorePurchases()`, collects the
  /// transaction ids the store replays, and hands them to
  /// [restoreFromPurchaseIds].
  ///
  /// 🚨 **On iOS this will find nothing, and that is accepted.** StoreKit does
  /// not replay consumables, so `restorePurchases()` returns no transaction id
  /// for a pass and there is nothing to look the Firestore record up by. On
  /// Android the same call works, because an unconsumed purchase is still
  /// returned by `queryPurchases` — which is exactly why 2.8 must acknowledge
  /// but **not consume** a Play purchase until the pass expires.
  ///
  /// The client accepted this on 2026-08-23 rather than requiring StoreKit 2.
  /// The obligation that came with accepting it is that the app says so before
  /// anyone pays: `premium_platform_note` states the limit per platform, and a
  /// test pins that it keeps doing so. Do not "fix" that copy back to a single
  /// promise about both stores.
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
