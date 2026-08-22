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

  /// Clears the entitlement but **not** [trialUsed] — a QA lock, or any future
  /// reset, must not hand out a second trial.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
