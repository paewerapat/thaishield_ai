import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/entitlement.dart';

/// Local cache of the current entitlement.
///
/// 🚨 Read the warning on [Entitlement] before using this for anything: the
/// store account is the source of truth, this is only what the app remembers
/// between launches so a paying user is not shown a paywall while the store
/// SDK is still starting up. It is **per-device and per-install** — clearing
/// app data wipes it — which is exactly why it must never be the only record
/// of a purchase.
class EntitlementStore {
  EntitlementStore._();
  static final instance = EntitlementStore._();

  static const _key = 'premium_entitlement';
  static const _trialUsedKey = 'premium_trial_used';

  /// Whether this install has already been given the free trial.
  ///
  /// Per-install, like everything else here, so clearing app data or
  /// reinstalling earns another trial. That hole is known and accepted: closing
  /// it needs either an account or a server-side device record, and both are
  /// out of scope (§7). It costs 3 days of access to someone determined enough
  /// to reinstall, which is cheaper than the alternatives.
  Future<bool> trialUsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trialUsedKey) ?? false;
  }

  Future<void> markTrialUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trialUsedKey, true);
  }

  Future<Entitlement?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return Entitlement.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Entitlement entitlement) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(entitlement.toJson()));
  }

  /// Clears the entitlement but **not** [trialUsed] — any reset must not hand
  /// out a second trial.
  ///
  /// 🚨 Not called by the QA switch any more (2026-09-05). `qaLock` used to
  /// come here, which destroyed whatever was cached — a trial, and once billing
  /// is live a paid subscription. The switch now keeps its own slot below.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // --- The debug QA switch's own slot ------------------------------------
  //
  // Kept apart from [_key] on purpose. The switch in Profile must be able to
  // hide a live trial (so a tester can reach the paywall) and grant a fake pass
  // (so they can reach the gated screens) without ever touching the record a
  // real store purchase left behind. Before 2026-09-05 both actions wrote the
  // main slot, so flipping the switch off wiped a tester's trial for good and
  // would have wiped a real subscription out of the cache in 2C.

  static const _qaLockedKey = 'premium_qa_locked';
  static const _qaOverrideKey = 'premium_qa_override';

  Future<QaState> readQaState() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_qaLockedKey) ?? false) return const QaState.locked();

    final raw = prefs.getString(_qaOverrideKey);
    if (raw == null) return const QaState.none();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const QaState.none();
      final override = Entitlement.fromJson(decoded);
      if (override == null) return const QaState.none();
      return QaState.unlocked(override);
    } catch (_) {
      return const QaState.none();
    }
  }

  Future<void> writeQaState(QaState state) async {
    final prefs = await SharedPreferences.getInstance();
    final override = state.override;
    if (state.locked) {
      await prefs.setBool(_qaLockedKey, true);
      await prefs.remove(_qaOverrideKey);
    } else if (override != null) {
      await prefs.remove(_qaLockedKey);
      await prefs.setString(_qaOverrideKey, jsonEncode(override.toJson()));
    } else {
      await prefs.remove(_qaLockedKey);
      await prefs.remove(_qaOverrideKey);
    }
  }
}

/// What the debug QA switch has asked for, independent of the real entitlement.
///
/// Exactly one of three: nothing (the real record decides), locked (access is
/// hidden even if the real record grants it), or unlocked (a QA pass is shown
/// in place of the real record). Never written in a release build — see
/// `PremiumProvider.qaUnlock` / `qaLock`.
class QaState {
  const QaState.none()
      : locked = false,
        override = null;

  const QaState.locked()
      : locked = true,
        override = null;

  const QaState.unlocked(Entitlement this.override) : locked = false;

  final bool locked;
  final Entitlement? override;

  bool get isNone => !locked && override == null;
}
