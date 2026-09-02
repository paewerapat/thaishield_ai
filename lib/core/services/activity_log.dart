import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'install_identity.dart';

/// What the CMS's "App Users" column shows.
///
/// Three values rather than a boolean, because "has access" and "has paid" are
/// different questions and the client asked to see both: someone on day 2 of
/// the 3-day trial is unlocked and has given us nothing.
enum AccessStatus {
  free,
  trial,
  premium;

  String get wireName => name;
}

/// What happened to one store transaction, as the CMS's Transactions page
/// prints it.
///
/// Every terminal state is logged, not just the successful ones. A log that
/// only contains completed purchases cannot answer the question the client
/// will actually ask — "someone says they paid and has nothing, what
/// happened?" — because the interesting rows are exactly the failures,
/// cancellations and the pending payments that never cleared.
enum PurchaseLogStatus {
  purchased,
  restored,
  pending,
  cancelled,
  failed;

  String get wireName => name;
}

/// Writes the two records the CMS reads: one row per install, one row per store
/// transaction.
///
/// 🚨 **Every method here must fail soft.** Nothing in this file is on the path
/// to a working app — it exists so the client can see who is using the product
/// and what has been bought. A Firestore outage, a rules change or a device
/// with no network must cost a log line and never a feature, never a purchase
/// and never a frame. That rule is why every implementation swallows its
/// errors, and why the callers do not await anything they need.
abstract class ActivityLog {
  /// Files or refreshes this install's row.
  ///
  /// Called on launch and again whenever access changes, so the CMS's status
  /// column is right without polling anything. `first_seen_at` is written only
  /// when the row is created — that is the "เริ่มใช้งานเมื่อไหร่" column and it
  /// must not move.
  Future<void> recordActivity({
    required AccessStatus status,
    String? planId,
    DateTime? expiresAt,
    String? locale,
  });

  /// Files one store transaction.
  Future<void> recordPurchase({
    required String purchaseId,
    required String productId,
    required PurchaseLogStatus status,
    DateTime? purchasedAt,
    DateTime? expiresAt,
    double? priceAmount,
    String? priceCurrency,
    String? errorMessage,
  });
}

/// The real implementation. See `firestore.rules` for the shapes it is allowed
/// to write and for why those rules are not a security boundary.
class FirestoreActivityLog implements ActivityLog {
  FirestoreActivityLog({
    FirebaseFirestore? firestore,
    InstallIdentity? identity,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _identity = identity ?? InstallIdentity.instance;

  final FirebaseFirestore _db;
  final InstallIdentity _identity;

  static const usersCollection = 'app_users';
  static const transactionsCollection = 'purchase_transactions';

  /// Read once per process. `PackageInfo.fromPlatform()` crosses a platform
  /// channel, and the launch record is written on the first frame's heels.
  String? _appVersion;

  @override
  Future<void> recordActivity({
    required AccessStatus status,
    String? planId,
    DateTime? expiresAt,
    String? locale,
  }) async {
    try {
      final installId = await _identity.read();
      final doc = _db.collection(usersCollection).doc(installId);

      // A transaction, rather than a read followed by a write, because the
      // launch record and a purchase landing from the store stream can arrive
      // within the same second. Without it the later write would overwrite
      // `first_seen_at` with a fresh server timestamp and the "started using"
      // date would silently become "last used".
      //
      // 🚨 **This `tx.get` needs `allow get` on `app_users` in
      // `firestore.rules`.** A transaction reads before it writes, so a rule
      // of `allow read: if false` fails the whole transaction and no row is
      // ever written — and because everything here swallows its errors, the
      // app looks perfectly healthy while the CMS stays empty forever. That
      // shipped on 2026-09-01 and was caught on a device the next day. If the
      // rule is ever tightened back to `read`, this stops working again with
      // no other symptom.
      await _db.runTransaction((tx) async {
        final snapshot = await tx.get(doc);

        final data = <String, Object?>{
          'platform': platformTag,
          'app_version': await _version(),
          'status': status.wireName,
          'plan_id': planId,
          'expires_at':
              expiresAt == null ? null : Timestamp.fromDate(expiresAt.toUtc()),
          // Server time throughout. A handset with a wrong clock would
          // otherwise sort to the top or the bottom of every CMS list and be
          // read as a real signup date.
          'last_seen_at': FieldValue.serverTimestamp(),
        };
        if (locale != null) data['locale'] = locale;
        if (!snapshot.exists) {
          data['first_seen_at'] = FieldValue.serverTimestamp();
        }

        // merge: the row keeps `first_seen_at` and any field a later app
        // version stops sending.
        tx.set(doc, data, SetOptions(merge: true));
      });
    } catch (_) {
      // See the class comment: a lost log line, never a lost feature.
    }
  }

  @override
  Future<void> recordPurchase({
    required String purchaseId,
    required String productId,
    required PurchaseLogStatus status,
    DateTime? purchasedAt,
    DateTime? expiresAt,
    double? priceAmount,
    String? priceCurrency,
    String? errorMessage,
  }) async {
    if (!isLoggable(purchaseId)) return;

    try {
      final installId = await _identity.read();

      await _db.collection(transactionsCollection).doc(purchaseId).set({
        'install_id': installId,
        'product_id': productId,
        'status': status.wireName,
        'platform': platformTag,
        'purchased_at': purchasedAt == null
            ? null
            : Timestamp.fromDate(purchasedAt.toUtc()),
        'expires_at':
            expiresAt == null ? null : Timestamp.fromDate(expiresAt.toUtc()),
        'price_amount': priceAmount,
        'price_currency': priceCurrency,
        'error_message': errorMessage,
        'recorded_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // As above.
    }
  }

  /// Whether a transaction can be filed at all.
  ///
  /// A row with no id cannot be keyed, and inventing a key would create a
  /// second document every time the store redelivers the same purchase — which
  /// Play does until it is acknowledged. Both stores supply an id for anything
  /// that reached a terminal state; the empty string turns up only when the
  /// plugin reports an error before the store ever assigned one. Dropping
  /// those is deliberate: the alternative is every failed purchase in the
  /// project collapsing into one shared document that each new failure
  /// overwrites.
  ///
  /// Static and public so `test/activity_log_test.dart` can pin the rule
  /// without a Firestore instance.
  static bool isLoggable(String purchaseId) => purchaseId.isNotEmpty;

  Future<String> _version() async {
    final cached = _appVersion;
    if (cached != null) return cached;
    final info = await PackageInfo.fromPlatform();

    // 🚨 **The name alone. Never `info.buildNumber` beside it.**
    //
    // `--split-per-abi` prefixes the version code by architecture, so one
    // release reports three different build numbers: 1026 on armeabi-v7a,
    // 2026 on arm64-v8a, 4026 on x86_64. Printing it turned a single release
    // into three apparent versions in the client's App Users report — seen on
    // a real row on 2026-09-02, which read `1.1.26 (4026)`.
    //
    // The name is unambiguous on its own because `pubspec.yaml` keeps the
    // patch number and the build number identical (1.1.26 IS build 26) and
    // `test/version_test.dart` fails if they ever drift. Profile and the
    // feedback email already print the name alone for exactly this reason;
    // this is the same decision, arrived at the hard way.
    final version = info.version;
    _appVersion = version;
    return version;
  }

  /// `defaultTargetPlatform` rather than `dart:io`, so this file stays
  /// importable by the widget tests — the same reason
  /// `EntitlementRepository._platformTag` avoids it.
  static String get platformTag {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }
}
