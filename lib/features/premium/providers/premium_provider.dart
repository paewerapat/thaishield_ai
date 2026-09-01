import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/activity_log.dart';
import '../models/entitlement.dart';
import '../services/billing_service.dart';
import '../models/premium_plan.dart';
import '../services/entitlement_repository.dart';
import '../services/entitlement_store.dart';

/// What a purchase or restore attempt did.
///
/// Every value here has its own sentence on screen, in all six languages,
/// because "something went wrong" is the message that generates a support
/// email. A user who cancelled, a user whose card is still clearing and a user
/// in a country where the store has no products are three different people.
enum StoreOutcome {
  /// No [BillingService] was given to this provider, so this build cannot
  /// talk to a store at all.
  ///
  /// 🚨 In production this means someone forgot to inject one in `main.dart`,
  /// not that billing is unfinished — `main_wiring_test.dart` fails if that
  /// happens. It stays a distinct value so that mistake never reaches a user
  /// disguised as [failed].
  notAvailableYet,

  success,
  cancelled,
  failed,

  /// Accepted, but not paid for yet — a slow card, a parent's approval, cash
  /// at a convenience store. **Access is not granted.** The purchase completes
  /// on its own later, through the stream, possibly after the app has been
  /// closed and reopened.
  pending,

  /// The device has no usable store: signed out of Google/Apple, billing
  /// unsupported in the region, or an emulator without Play Services.
  storeUnavailable,

  /// The store is reachable but does not know this product. Today that is the
  /// normal answer everywhere, because the products cannot be created until
  /// the Payments Profile exists (CLAUDE.md §5).
  productUnavailable,

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
  PremiumProvider({
    EntitlementStore? store,
    EntitlementRepository? repository,
    BillingService? billing,
    ActivityLog? activityLog,
  })  : _store = store ?? EntitlementStore.instance,
        _repository = repository ?? EntitlementRepository.instance,
        // The field is private and the named argument is not, so they cannot
        // share one name and an initializing formal is not available.
        // ignore: prefer_initializing_formals
        _billing = billing,
        // ignore: prefer_initializing_formals
        _activityLog = activityLog;

  final EntitlementStore _store;
  final EntitlementRepository _repository;

  /// Feeds the CMS's "App Users" and "Transactions" pages.
  ///
  /// 🚨 Null by default and injected in `main.dart`, for the same reason
  /// [_billing] is: constructing the Firestore-backed one inside a widget test
  /// would put a network write behind dozens of screen builds. It carries the
  /// same silent-failure risk too — forget the argument and every screen still
  /// works while the CMS shows nobody ever opened the app — so
  /// `main_wiring_test.dart` guards this line as well.
  ///
  /// Nothing in this class awaits a result from it or changes behaviour on
  /// one. Reporting must never be able to fail a purchase.
  final ActivityLog? _activityLog;

  /// 🚨 **Null by default, on purpose.** Constructing [InAppPurchaseBilling]
  /// here would open a platform channel inside every widget test that builds a
  /// screen, and there are dozens. `main.dart` injects the real one;
  /// `main_wiring_test.dart` fails if that line is ever removed, which is the
  /// only thing standing between "billing works" and "every user is quietly
  /// told the store is unavailable".
  final BillingService? _billing;

  StreamSubscription<List<BillingPurchase>>? _purchaseSubscription;

  /// Completed by whichever stream event resolves the purchase the user is
  /// waiting on. The store answers asynchronously and sometimes minutes later,
  /// so [purchase] cannot simply await [BillingService.buy].
  Completer<StoreOutcome>? _awaitingPurchase;
  String? _awaitingProductId;

  /// Restores arrive as zero or more stream events with no "that is all"
  /// marker, so [restore] collects for a bounded window and then decides.
  Completer<StoreOutcome>? _awaitingRestore;

  /// How long to wait for the store to answer before telling the user nothing
  /// happened. Generous, because a real payment sheet can sit open while
  /// someone finds their card; a pending purchase resolves through the stream
  /// afterwards regardless of this timeout.
  static const purchaseTimeout = Duration(minutes: 5);
  static const restoreTimeout = Duration(seconds: 12);

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

    _listenForPurchases();
  }

  /// Subscribes for the whole session, not just while the paywall is open.
  ///
  /// 🚨 Purchases arrive here that nobody is waiting for: a card that clears an
  /// hour later, a subscription renewing, a family-sharing grant, a purchase
  /// made on another device. Play also redelivers anything that was never
  /// acknowledged. Listening only during the purchase screen loses all of
  /// those, and an unacknowledged Play purchase is **refunded automatically
  /// after three days** — the user pays, gets nothing, and the money goes back
  /// while the app looks broken.
  void _listenForPurchases() {
    final billing = _billing;
    if (billing == null || _purchaseSubscription != null) return;

    _purchaseSubscription = billing.purchaseUpdates.listen(
      _onPurchaseUpdates,
      onError: (_) {
        // A broken stream must not take the app down, and must not be
        // mistaken for a refusal: whoever is waiting is told it failed, and
        // free features carry on working.
        _resolvePurchase(StoreOutcome.failed);
      },
    );
  }

  Future<void> _onPurchaseUpdates(List<BillingPurchase> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == BillingPurchaseStatus.pending) {
        // Deliberately no access and no completion. Telling the store the
        // goods were delivered before it has the money is how a pending
        // purchase turns into a free subscription.
        _logPurchase(purchase);
        if (purchase.productId == _awaitingProductId) {
          _resolvePurchase(StoreOutcome.pending);
        }
        continue;
      }

      if (purchase.grantsAccess) {
        final plan = PremiumPlan.fromProductId(purchase.productId);
        if (plan == null) {
          // A product id this build does not know — a retired plan replayed
          // from an old purchase, or a store misconfiguration. Complete it so
          // the store stops redelivering, but grant nothing.
          //
          // Still logged: this is the single most useful row the Transactions
          // page can carry, because it is somebody's money against a product
          // the app cannot honour. `firestore.rules` deliberately does not
          // allowlist product ids on that collection for this reason.
          _logPurchase(purchase);
          await _completeQuietly(purchase);
          continue;
        }

        await grantPurchase(
          plan: plan,
          purchaseId: purchase.purchaseId,
          expiresAt: _horizonFor(plan),
        );
      }

      // Log before acknowledging, and log every terminal state rather than
      // only the successful ones: the rows worth having in the CMS when a user
      // writes in saying they paid and got nothing are the cancellations, the
      // errors and the pending payments that never cleared.
      _logPurchase(purchase);

      // Acknowledge every terminal state, including errors and cancellations:
      // an unacknowledged purchase is redelivered forever and, on Play, is
      // refunded after three days.
      await _completeQuietly(purchase);

      if (purchase.productId == _awaitingProductId) {
        _resolvePurchase(_outcomeFor(purchase));
      }
      if (purchase.status == BillingPurchaseStatus.restored) {
        _resolveRestore(StoreOutcome.success);
      }
    }
  }

  /// How long access is granted for when the store confirms a subscription.
  ///
  /// 🚨 **This is a cache horizon, not the real renewal date.** A client cannot
  /// learn when a subscription actually renews — that needs Play's Developer
  /// API or Apple's verifyReceipt, called from somewhere the user does not
  /// control. Until the receipt-validation Cloud Function can be deployed
  /// (blocked on the Firebase role, same as `computeRoute`), this is the
  /// honest approximation:
  ///
  /// - both stores only report subscriptions that are **active right now**, so
  ///   a confirmation means the current period has not ended;
  /// - the period is at most [PremiumPlan.duration] long;
  /// - the app re-confirms with the store on every launch, so the horizon is
  ///   pushed forward continuously while the subscription lives.
  ///
  /// What this over-grants: someone who cancels and then never opens the app
  /// online again keeps access until the horizon — at most one billing period.
  /// That is the specific cost of not having server validation, and it is the
  /// reason to deploy that function rather than a detail to leave undocumented.
  ///
  /// It deliberately does **not** use the purchase date. On a restore that is
  /// the *original* subscription date, so a user six months into a monthly plan
  /// would be handed an expiry five months in the past and locked out of
  /// something they are paying for.
  DateTime _horizonFor(PremiumPlan plan) =>
      DateTime.now().toUtc().add(plan.duration);

  StoreOutcome _outcomeFor(BillingPurchase purchase) {
    switch (purchase.status) {
      case BillingPurchaseStatus.purchased:
      case BillingPurchaseStatus.restored:
        return StoreOutcome.success;
      case BillingPurchaseStatus.cancelled:
        return StoreOutcome.cancelled;
      case BillingPurchaseStatus.pending:
        return StoreOutcome.pending;
      case BillingPurchaseStatus.error:
        return StoreOutcome.failed;
    }
  }

  /// The store's own price for each product, remembered from the last
  /// `queryProducts` answer.
  ///
  /// The purchase stream does not carry a price — it reports what was bought,
  /// not what it cost — so the amount on a transaction row has to come from
  /// the product lookup that preceded it. Empty on a restore, where there was
  /// no lookup, which is why both price fields are nullable all the way into
  /// the CMS. **Never substitute `PremiumPlan.priceUsd` here**: that is the
  /// compiled list price, and a row claiming 3.50 USD when the user was
  /// charged in baht at a different tier would be a wrong number in a
  /// financial log, which is worse than a blank.
  final Map<String, BillingProduct> _lastKnownPrices = {};

  void _rememberPrices(Iterable<BillingProduct> products) {
    for (final product in products) {
      _lastKnownPrices[product.id] = product;
    }
  }

  /// Files one store transaction. Fire-and-forget by design — see
  /// [_activityLog].
  void _logPurchase(BillingPurchase purchase) {
    final log = _activityLog;
    if (log == null) return;

    final price = _lastKnownPrices[purchase.productId];
    final plan = PremiumPlan.fromProductId(purchase.productId);

    unawaited(log.recordPurchase(
      purchaseId: purchase.purchaseId,
      productId: purchase.productId,
      status: _logStatusFor(purchase.status),
      purchasedAt: purchase.purchasedAt,
      // Only for states that actually granted access; a cancelled row with an
      // expiry reads as a pass somebody still holds.
      expiresAt:
          purchase.grantsAccess && plan != null ? _horizonFor(plan) : null,
      priceAmount: price?.rawPrice,
      priceCurrency: price?.currencyCode,
      errorMessage: purchase.errorMessage,
    ));
  }

  static PurchaseLogStatus _logStatusFor(BillingPurchaseStatus status) {
    switch (status) {
      case BillingPurchaseStatus.purchased:
        return PurchaseLogStatus.purchased;
      case BillingPurchaseStatus.restored:
        return PurchaseLogStatus.restored;
      case BillingPurchaseStatus.pending:
        return PurchaseLogStatus.pending;
      case BillingPurchaseStatus.cancelled:
        return PurchaseLogStatus.cancelled;
      case BillingPurchaseStatus.error:
        return PurchaseLogStatus.failed;
    }
  }

  /// What the CMS's status column should say for this install right now.
  ///
  /// The QA override is reported as [AccessStatus.free] on purpose. It only
  /// exists in a build QA was handed, and a tester's unlocked handset showing
  /// up in the client's list as a paying customer is a number they would act
  /// on. `isPremium` deliberately does not agree with this getter for that one
  /// case.
  AccessStatus get _statusNow {
    final current = _entitlement;
    if (current == null) return AccessStatus.free;
    if (!current.isActiveAt(DateTime.now().toUtc())) return AccessStatus.free;
    switch (current.source) {
      case EntitlementSource.store:
        return AccessStatus.premium;
      case EntitlementSource.trial:
        return AccessStatus.trial;
      case EntitlementSource.qaOverride:
        return AccessStatus.free;
    }
  }

  /// Files or refreshes this install's row in the CMS's App Users list.
  ///
  /// Called from `main.dart` on launch with the chosen [locale], and again
  /// from this class whenever access changes, so the status column is current
  /// without anything polling. Passing null for [locale] leaves whatever the
  /// row already has — the write merges.
  ///
  /// 🚨 There is no email and no name in what this sends. See
  /// `InstallIdentity` for why, and do not add one without the privacy policy
  /// and both Data Safety forms changing in the same breath.
  void recordUsage({String? locale}) {
    final log = _activityLog;
    if (log == null) return;

    final current = _entitlement;
    unawaited(log.recordActivity(
      status: _statusNow,
      planId: current?.plan?.productId,
      // Only meaningful while something is running. A stale expiry on a row
      // that has lapsed back to free reads as a pass that is still good.
      expiresAt: _statusNow == AccessStatus.free ? null : current?.expiresAt,
      locale: locale,
    ));
  }

  /// Acknowledging must never be what breaks a purchase the user already made.
  Future<void> _completeQuietly(BillingPurchase purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _billing?.complete(purchase);
    } catch (_) {
      // The store will redeliver; nothing here is worth losing access over.
    }
  }

  void _resolvePurchase(StoreOutcome outcome) {
    final waiting = _awaitingPurchase;
    _awaitingPurchase = null;
    _awaitingProductId = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete(outcome);
  }

  void _resolveRestore(StoreOutcome outcome) {
    final waiting = _awaitingRestore;
    if (waiting != null && !waiting.isCompleted) waiting.complete(outcome);
  }

  /// Real, localised store prices for the paywall — "฿129.00" rather than the
  /// USD figure compiled into [PremiumPlan].
  ///
  /// Returns an empty list whenever the store cannot answer, which is the
  /// normal case today because neither store has these products yet. The
  /// paywall falls back to the compiled figure and keeps its note explaining
  /// that the store's price is what is actually charged.
  Future<List<BillingProduct>> storeProducts() async {
    final billing = _billing;
    if (billing == null) return const [];
    try {
      if (!await billing.isAvailable()) return const [];
      final products = await billing.queryProducts(
        PremiumPlan.values.map((p) => p.productId).toSet(),
      );
      _rememberPrices(products);
      return products;
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _billing?.dispose();
    super.dispose();
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
    recordUsage();
    return true;
  }

  /// Buys [plan] through the store.
  ///
  /// Opening the sheet and paying for it are two different events, sometimes
  /// days apart, so this waits on the purchase stream rather than on
  /// [BillingService.buy]. A [StoreOutcome.pending] answer is not a failure:
  /// the purchase resolves later through [_onPurchaseUpdates], even if the app
  /// is closed in the meantime.
  Future<StoreOutcome> purchase(PremiumPlan plan) async {
    final billing = _billing;
    if (billing == null) return StoreOutcome.notAvailableYet;

    // Never leave a previous attempt hanging: the user pressed buy again.
    _resolvePurchase(StoreOutcome.cancelled);

    try {
      if (!await billing.isAvailable()) return StoreOutcome.storeUnavailable;

      final products = await billing.queryProducts({plan.productId});
      _rememberPrices(products);
      final product = products
          .where((p) => p.id == plan.productId)
          .cast<BillingProduct?>()
          .firstWhere((p) => p != null, orElse: () => null);
      if (product == null) return StoreOutcome.productUnavailable;

      final completer = Completer<StoreOutcome>();
      _awaitingPurchase = completer;
      _awaitingProductId = plan.productId;

      if (!await billing.buy(product)) {
        _resolvePurchase(StoreOutcome.failed);
        return StoreOutcome.failed;
      }

      return await completer.future.timeout(
        purchaseTimeout,
        // Not a failure of the purchase — only of our waiting for it. If it
        // does land later the stream still grants access.
        onTimeout: () => StoreOutcome.pending,
      );
    } catch (_) {
      _resolvePurchase(StoreOutcome.failed);
      return StoreOutcome.failed;
    } finally {
      _awaitingPurchase = null;
      _awaitingProductId = null;
    }
  }


  /// "Restore Purchases". Required by both stores.
  ///
  /// ✅ **Works on iOS and Android alike since 2026-08-30.** It did not while
  /// the products were one-time consumables: StoreKit never replays a
  /// consumable, so an iPhone had nothing to restore, and the client accepted
  /// that on 2026-08-23. Subscriptions are replayed on both platforms, so the
  /// limitation is gone — `premium_platform_note` no longer discloses it, and
  /// the test that used to pin the disclosure now pins its absence. **Do not
  /// reintroduce the per-platform warning:** it would scare users away from
  /// something that works.
  ///
  /// The store sends restored purchases as ordinary stream events with no
  /// "that is all" marker, so this waits a bounded window and reports
  /// [StoreOutcome.nothingToRestore] if none arrive. Access is granted by
  /// [_onPurchaseUpdates] as each one lands, not here — so a restore that
  /// completes just after the window still works, it just is not what the
  /// snackbar reported.
  Future<StoreOutcome> restore() async {
    final billing = _billing;
    if (billing == null) return StoreOutcome.notAvailableYet;

    try {
      if (!await billing.isAvailable()) return StoreOutcome.storeUnavailable;

      final completer = Completer<StoreOutcome>();
      _awaitingRestore = completer;

      await billing.restore();

      return await completer.future.timeout(
        restoreTimeout,
        onTimeout: () => StoreOutcome.nothingToRestore,
      );
    } catch (_) {
      return StoreOutcome.failed;
    } finally {
      _awaitingRestore = null;
    }
  }


  /// Applies a confirmed purchase.
  ///
  /// Takes [expiresAt] from the caller rather than computing it. That is the
  /// change task 2.8 was told to make: the old signature took `purchasedAt`
  /// and derived `now + plan.duration`, which is right for a fixed-length pass
  /// and wrong for a subscription — and catastrophically wrong on a restore,
  /// where the purchase date is the *original* subscription date and would
  /// hand a paying customer an expiry months in the past. See [_horizonFor]
  /// for what the caller should pass and why a client cannot do better without
  /// server-side receipt validation.
  ///
  /// 🚨 Never shortens access. A renewal, a restore and a redelivered purchase
  /// all arrive here, and the store can report the same subscription many
  /// times in a session; taking the later expiry means none of them can cut
  /// short a period the user has already paid for.
  Future<void> grantPurchase({
    required PremiumPlan plan,
    required String purchaseId,
    required DateTime expiresAt,
  }) async {
    final expiry = expiresAt.toUtc();
    final current = _entitlement;
    final keepExisting = current != null &&
        current.source == EntitlementSource.store &&
        current.expiresAt.isAfter(expiry);

    final entitlement = Entitlement(
      plan: plan,
      source: EntitlementSource.store,
      expiresAt: keepExisting ? current.expiresAt : expiry,
      purchaseId: purchaseId,
    );

    _entitlement = entitlement;
    await _store.write(entitlement);
    notifyListeners();
    recordUsage();
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
    recordUsage();
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
