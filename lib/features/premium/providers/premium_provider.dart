import 'package:flutter/foundation.dart';

import '../models/entitlement.dart';
import '../models/premium_plan.dart';
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
}

/// **The single source of truth for whether the app is unlocked.**
///
/// Every gate in the app reads `isPremium` from here and nowhere else. That is
/// the whole point of this class in Phase 2B: the UI, the gates and the paywall
/// are finished and testable now, and Phase 2C task 2.8 only has to replace the
/// two stubs below ([purchase] and [restore]) with `in_app_purchase` calls plus
/// a store-driven refresh. No screen changes.
///
/// ## How this works without a user system
///
/// There is none, deliberately (§7 — no Firebase Auth in the app). Google Play
/// and the App Store already hold the identity: a purchase is attached to the
/// **Google account / Apple ID**, not to the handset. So 2C's launch sequence
/// is `restore()` → the store returns whatever that account owns → write it to
/// [EntitlementStore] → `notifyListeners`. Reinstalling, or signing in on a new
/// phone, recovers access automatically; entitlements do **not** cross between
/// Android and iOS, which the paywall has to say out loud.
///
/// The cached [Entitlement] must never be treated as proof of purchase — see
/// the warning on that class.
class PremiumProvider extends ChangeNotifier {
  PremiumProvider({EntitlementStore? store})
      : _store = store ?? EntitlementStore.instance;

  final EntitlementStore _store;

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
  /// It stays exposed for 2C, where a store round-trip is genuinely async and
  /// the paywall must not flash at a paying user while it is in flight.
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

  Future<void> load() async {
    _entitlement = await _store.read();
    _loaded = true;
    notifyListeners();
  }

  /// Phase 2C, task 2.8 replaces this body with the Play Billing / StoreKit
  /// flow. Everything around it — the paywall, the gates, the Profile card —
  /// is already written against this signature.
  Future<StoreOutcome> purchase(PremiumPlan plan) async {
    return StoreOutcome.notAvailableYet;
  }

  /// "Restore Purchases". Apple rejects apps that sell a non-consumable
  /// without one, so the button exists from 2B even though it cannot do
  /// anything until 2C.
  Future<StoreOutcome> restore() async {
    return StoreOutcome.notAvailableYet;
  }

  /// QA unlock from the debug switch in Profile.
  ///
  /// Refuses outside debug builds even if something calls it, so the switch
  /// can never become a way to unlock a shipped app. Written through the cache
  /// so it survives a restart the way a real purchase would, and tagged
  /// [EntitlementSource.qaOverride] so it is always distinguishable from one.
  Future<void> qaUnlock(PremiumPlan plan) async {
    if (!kDebugMode) return;

    final entitlement = plan.duration == null
        ? const Entitlement.lifetime(EntitlementSource.qaOverride)
        : Entitlement(
            plan: plan,
            source: EntitlementSource.qaOverride,
            expiresAt: DateTime.now().toUtc().add(plan.duration!),
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
