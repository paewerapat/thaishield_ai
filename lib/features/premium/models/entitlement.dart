import 'premium_plan.dart';

/// Where an entitlement came from. Kept on the record itself so a QA unlock can
/// never be mistaken for a purchase — including in whatever diagnostics Phase
/// 2C adds around receipt validation.
enum EntitlementSource {
  /// Granted by Google Play / the App Store. The only source that will exist
  /// in production once 2C lands.
  store,

  /// The debug override (§ "QA unlock" in `PremiumProvider`). Never written in
  /// a release build.
  qaOverride,
}

/// A record that the user has access, and until when.
///
/// 🚨 **This is a cache, not the source of truth.** The store account is the
/// truth — see CLAUDE.md §4. It is persisted only so the app can open offline,
/// or before the store SDK has answered, without flashing the paywall at
/// someone who has paid. Phase 2C must re-verify on every launch and overwrite
/// this; a cancelled subscription that is only ever read from disk would grant
/// access forever.
class Entitlement {
  const Entitlement({
    required this.plan,
    required this.source,
    required this.expiresAt,
  });

  /// A lifetime purchase — no expiry to check.
  const Entitlement.lifetime(this.source)
      : plan = PremiumPlan.lifetime,
        expiresAt = null;

  final PremiumPlan plan;
  final EntitlementSource source;

  /// Null for [PremiumPlan.lifetime]; a UTC instant otherwise.
  final DateTime? expiresAt;

  bool isActiveAt(DateTime now) {
    final expiry = expiresAt;
    if (expiry == null) return true;
    return now.isBefore(expiry);
  }

  Map<String, dynamic> toJson() => {
        'product_id': plan.productId,
        'source': source.name,
        'expires_at': expiresAt?.toIso8601String(),
      };

  /// Returns null for anything unreadable — a schema change or a hand-edited
  /// preferences file must drop the user to free, never crash the app and
  /// never grant access by accident.
  static Entitlement? fromJson(Map<String, dynamic> json) {
    final plan = PremiumPlan.fromProductId(json['product_id'] as String? ?? '');
    if (plan == null) return null;

    EntitlementSource? source;
    for (final value in EntitlementSource.values) {
      if (value.name == json['source']) source = value;
    }
    if (source == null) return null;

    final rawExpiry = json['expires_at'];
    if (rawExpiry == null) {
      // Only a lifetime plan is allowed to carry no expiry. A subscription
      // stored without one would be an unbounded grant.
      if (plan.duration != null) return null;
      return Entitlement(plan: plan, source: source, expiresAt: null);
    }

    final expiry = DateTime.tryParse(rawExpiry as String);
    if (expiry == null) return null;
    return Entitlement(plan: plan, source: source, expiresAt: expiry);
  }
}
