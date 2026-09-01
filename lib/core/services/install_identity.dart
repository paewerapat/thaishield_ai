import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// The only handle the CMS has on "a user".
///
/// ## Why this exists and what it deliberately is not
///
/// The client asked for a list of app users in the CMS showing an **email**,
/// when each one started using the app, and whether they are Premium. The
/// email half is not buildable as the product stands and was not guessed at:
///
///  - the app has no accounts and no Firebase Auth (CLAUDE.md §7), so it never
///    sees an email address;
///  - **neither store hands one back either.** Play's Developer API returns an
///    `obfuscatedExternalAccountId` — and only the one *we* sent it — and
///    StoreKit returns no buyer identity at all. Receipt validation does not
///    change that;
///  - the published Privacy Policy states, in Thai and English, that the app
///    creates no account, name, email address, phone number or profile. Adding
///    one is a rewrite of a live legal page, both stores' Data Safety forms,
///    and a PDPA lawful basis.
///
/// So the decision on 2026-09-01 was: **ship every column that does not need an
/// identity, and leave the email out rather than invent a stand-in for it.**
/// This class is that decision in code — a random id, generated on the device,
/// tied to an install and to nothing else.
///
/// 🚨 **It is not a person and must never be presented as one.** Reinstalling,
/// clearing app data or switching phone produces a new id, and two people
/// sharing a handset produce one. The CMS labels the column "Install" for that
/// reason. If real user identity is ever wanted, it comes from adding sign-in,
/// not from tightening this.
///
/// It is also not a device fingerprint: nothing here reads the IMEI, the
/// advertising id, the Android ID or anything else the OS assigns. Those are
/// exactly what both stores' privacy reviews look for, and a random number in
/// our own `SharedPreferences` is disclosable without changing a word of the
/// policy beyond §4.
class InstallIdentity {
  InstallIdentity._();

  static final instance = InstallIdentity._();

  static const _key = 'install_id';

  /// Cached so the launch record and any purchase logged in the same session
  /// agree, without re-reading preferences each time.
  String? _cached;

  /// Returns this install's id, creating it on first call.
  ///
  /// Sits behind the same fail-soft rule as everything else in the reporting
  /// path: if preferences cannot be read, this throws and the caller drops the
  /// record. Nothing a user can see depends on it.
  Future<String> read() async {
    final cached = _cached;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }

    final created = generate();
    await prefs.setString(_key, created);
    _cached = created;
    return created;
  }

  /// 32 hex characters from `Random.secure()`.
  ///
  /// Deliberately not the `uuid` package — a whole dependency for one line —
  /// and deliberately not `Random()`, whose seed on a freshly booted phone is
  /// guessable enough that two installs could collide. Collisions matter here
  /// because the id is the document key: two installs sharing one would merge
  /// into a single row and report a first-seen date that belongs to somebody
  /// else.
  static String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Test seam. Not used by the app.
  void overrideForTest(String? id) => _cached = id;
}
