import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/entitlement.dart';
import '../models/premium_plan.dart';

/// The durable, cross-device copy of a purchased pass.
///
/// ## Why this exists
///
/// Both products are **one-time consumables** ([PremiumPlan]), and consumables
/// are not restorable the way a subscription is. Play stops returning a
/// purchase once it is consumed, and StoreKit does not replay consumables at
/// all. Without a record of our own, a user who changes phone — or reinstalls —
/// on day 3 of a 14-day pass simply loses the other 11 days, and the app has no
/// way to tell them apart from someone who never paid. "Restore Purchases" is
/// in the agreed scope of task 2.8, so it has to actually restore something.
///
/// So each purchase is filed here under the store's own transaction id, and a
/// restore is: ask the store what this account bought → look the ids up here →
/// take the furthest expiry.
///
/// ## What it is keyed by, and why not by user
///
/// There is no user system, deliberately (§7 — no Firebase Auth in the app), so
/// there is no account to file this under. The store's transaction id is the
/// only durable handle the app ever sees, and it is the same id on every device
/// signed into that Google/Apple account. That is enough for restore and
/// nothing more: it is not a login and cannot be used to identify a person.
///
/// ## 🚨 This is not a security boundary
///
/// Rules have to let an unauthenticated client write here, so a determined user
/// can create a document and grant themselves a pass. That is accepted for the
/// same reason the local cache is: **the store receipt is the source of truth**,
/// and Phase 2C task 2.8 validates it. When it does, the write below moves
/// behind a Cloud Function that checks the receipt with Google/Apple before
/// writing, and `firestore.rules` drops client writes to `if false`. Until
/// then, treat what comes back as a hint about how much time is left, never as
/// evidence that money changed hands.
///
/// Nothing here is required for the app to work: every method fails soft, and a
/// user with no network keeps whatever the local cache says.
class EntitlementRepository {
  EntitlementRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static final instance = EntitlementRepository();

  final FirebaseFirestore _db;

  static const collection = 'entitlements';

  CollectionReference<Map<String, dynamic>> get _entitlements =>
      _db.collection(collection);

  /// Files a purchase so another device can find it.
  ///
  /// Only called for [EntitlementSource.store] records with a [purchaseId] —
  /// a trial is per-install by design and a QA unlock must never leave the
  /// device it was toggled on.
  Future<void> save(Entitlement entitlement) async {
    final id = entitlement.purchaseId;
    if (id == null || entitlement.source != EntitlementSource.store) return;

    try {
      await _entitlements.doc(id).set({
        'product_id': entitlement.plan?.productId,
        'expires_at': Timestamp.fromDate(entitlement.expiresAt),
        'platform': _platformTag,
        // Server time, so a device with a wrong clock cannot backdate a record
        // and 2C's validation has something trustworthy to compare against.
        'recorded_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // A failed write costs the user a cross-device restore, not their pass.
      // The local cache already has it.
    }
  }

  /// Looks up one purchase. Returns null when it is unknown, unreadable, or the
  /// network is down.
  Future<Entitlement?> fetch(String purchaseId) async {
    try {
      final doc = await _entitlements.doc(purchaseId).get();
      final data = doc.data();
      if (data == null) return null;
      return _parse(purchaseId, data);
    } catch (_) {
      return null;
    }
  }

  /// The entitlement with the furthest expiry among [purchaseIds] — what the
  /// store told us this account owns.
  ///
  /// Buying a second pass while one is still running should extend access, not
  /// shorten it, so the latest expiry wins rather than the newest purchase.
  Future<Entitlement?> restoreBest(Iterable<String> purchaseIds) async {
    Entitlement? best;
    for (final id in purchaseIds) {
      final found = await fetch(id);
      if (found == null) continue;
      if (best == null || found.expiresAt.isAfter(best.expiresAt)) {
        best = found;
      }
    }
    return best;
  }

  /// Rejects anything it cannot read completely. A half-parsed record here
  /// would become an entitlement with a wrong expiry, which is worse than none.
  static Entitlement? _parse(String purchaseId, Map<String, dynamic> data) {
    final plan = PremiumPlan.fromProductId(data['product_id'] as String? ?? '');
    if (plan == null) return null;

    final rawExpiry = data['expires_at'];
    if (rawExpiry is! Timestamp) return null;

    return Entitlement(
      plan: plan,
      source: EntitlementSource.store,
      expiresAt: rawExpiry.toDate().toUtc(),
      purchaseId: purchaseId,
    );
  }

  /// Recorded so support can tell an Android record from an iOS one. It is not
  /// used to match anything: entitlements do not cross platforms, which the
  /// paywall says out loud (`premium_platform_note`).
  static String get _platformTag {
    // Deliberately not `dart:io` — this file is imported by tests that run on
    // the Flutter test platform, and the value is a label, not logic.
    return const bool.fromEnvironment('dart.library.js_util')
        ? 'web'
        : 'mobile';
  }
}
