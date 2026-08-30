import 'premium_plan.dart';

/// Where an entitlement came from. Kept on the record itself so a trial or a QA
/// unlock can never be mistaken for a purchase — including in whatever
/// diagnostics Phase 2C adds around receipt validation.
enum EntitlementSource {
  /// Bought through Google Play / the App Store.
  store,

  /// The 3-day trial the app grants a new install (`PremiumPlan.trialDuration`).
  ///
  /// 🚨 **Superseded, and kept only until billing exists.** A store-run free
  /// trial attaches to a subscription, and both products became subscriptions
  /// on 2026-08-30 — so task 2.8 should replace this with a store introductory
  /// offer, which also closes the hole where a reinstall earns another trial.
  /// It survives because a build with no billing wired has no other way to
  /// reach the paid state. See `PremiumProvider.startTrialIfEligible`.
  trial,

  /// The debug override (§ "QA unlock" in `PremiumProvider`). Never written in
  /// a release build.
  qaOverride,
}

/// A record that the user has access, and until when.
///
/// 🚨 **This is a cache, not proof of purchase.** The store receipt is the
/// truth. This is persisted so the app can open offline, or before the store
/// SDK has answered, without flashing the paywall at someone who has paid.
/// Phase 2C must re-verify against the store on launch and overwrite it.
///
/// Every entitlement expires — [expiresAt] is non-null. There is deliberately
/// no way to express "access forever": the lifetime plan was cancelled on
/// 2026-08-22 and stayed cancelled on 2026-08-30, and a record with no expiry
/// would be an unbounded grant that any corrupted file could hand out.
///
/// ⚠️ **Since the products became subscriptions, [expiresAt] means less than it
/// used to.** For a fixed-length pass it was the whole truth. For a
/// subscription it is only the end of the period the store last confirmed —
/// a cancellation, refund, pause or failed payment can end access sooner, and
/// none of them are visible here. Task 2.8 must fill this from what the store
/// reports and re-check on every launch, never from `PremiumPlan.duration`.
class Entitlement {
  const Entitlement({
    required this.plan,
    required this.source,
    required this.expiresAt,
    this.purchaseId,
  });

  /// The 3-day trial. Carries no [plan] because nothing was bought.
  Entitlement.trial({required DateTime startedAt})
      : plan = null,
        source = EntitlementSource.trial,
        purchaseId = null,
        expiresAt = startedAt.add(PremiumPlan.trialDuration);

  /// Which pass was bought. Null for a trial, which is not a purchase.
  final PremiumPlan? plan;

  final EntitlementSource source;

  /// A UTC instant. Always set — see the class comment.
  final DateTime expiresAt;

  /// The store's own identifier for the transaction — Play's `purchaseToken`,
  /// StoreKit's `originalTransactionId`. Null for a trial or a QA unlock.
  ///
  /// This is the key the Firestore copy is filed under
  /// (`EntitlementRepository`), so a user who reinstalls or changes phone can
  /// have the remaining days of a pass restored rather than losing them. It is
  /// filled in by Phase 2C task 2.8, which is what actually talks to the
  /// stores.
  final String? purchaseId;

  bool get isTrial => source == EntitlementSource.trial;

  bool isActiveAt(DateTime now) => now.isBefore(expiresAt);

  /// What is left on the pass at [now], floored at zero.
  Duration remainingAt(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  Map<String, dynamic> toJson() => {
        'product_id': plan?.productId,
        'source': source.name,
        'expires_at': expiresAt.toIso8601String(),
        if (purchaseId != null) 'purchase_id': purchaseId,
      };

  /// Returns null for anything unreadable — a schema change or a hand-edited
  /// preferences file must drop the user to free, never crash the app and
  /// never grant access by accident.
  static Entitlement? fromJson(Map<String, dynamic> json) {
    EntitlementSource? source;
    for (final value in EntitlementSource.values) {
      if (value.name == json['source']) source = value;
    }
    if (source == null) return null;

    // A purchase must name a plan we recognise; a trial must not name one at
    // all. Anything in between is a record we cannot reason about.
    final rawProductId = json['product_id'] as String?;
    final PremiumPlan? plan;
    if (source == EntitlementSource.trial) {
      if (rawProductId != null) return null;
      plan = null;
    } else {
      if (rawProductId == null) return null;
      plan = PremiumPlan.fromProductId(rawProductId);
      if (plan == null) return null;
    }

    final rawExpiry = json['expires_at'];
    if (rawExpiry is! String) return null;
    final expiry = DateTime.tryParse(rawExpiry);
    if (expiry == null) return null;

    return Entitlement(
      plan: plan,
      source: source,
      expiresAt: expiry,
      purchaseId: json['purchase_id'] as String?,
    );
  }
}
