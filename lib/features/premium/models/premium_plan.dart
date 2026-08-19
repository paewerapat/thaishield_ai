/// The three plans the paywall compares (Phase 2B task 2.5).
///
/// [productId] is the identifier the same plan will carry in Play Console and
/// App Store Connect, so 2C's `in_app_purchase` lookup needs no translation
/// table. Set them up under exactly these ids — monthly and yearly as
/// **subscriptions**, lifetime as a **non-consumable one-time product**. They
/// are different product types in both stores and cannot be swapped later.
enum PremiumPlan {
  monthly(
    productId: 'thaishield_premium_monthly',
    titleKey: 'premium_plan_monthly',
    periodKey: 'premium_period_monthly',
    priceThb: 99,
    duration: Duration(days: 30),
  ),
  yearly(
    productId: 'thaishield_premium_yearly',
    titleKey: 'premium_plan_yearly',
    periodKey: 'premium_period_yearly',
    priceThb: 799,
    duration: Duration(days: 365),
  ),
  lifetime(
    productId: 'thaishield_premium_lifetime',
    titleKey: 'premium_plan_lifetime',
    periodKey: 'premium_period_lifetime',
    priceThb: 1999,
    duration: null,
  );

  const PremiumPlan({
    required this.productId,
    required this.titleKey,
    required this.periodKey,
    required this.priceThb,
    required this.duration,
  });

  final String productId;
  final String titleKey;
  final String periodKey;

  /// The price from the client's own `feature-design.jpg` (V2 design, received
  /// 2026-08-19): ฿99 monthly, ฿799 yearly, ฿1,999 lifetime.
  ///
  /// ⚠️ Still only what the **2B** screen lays out. Once purchases are live the
  /// figure shown must come from `ProductDetails.price` — the store's own
  /// localised, tax-inclusive string for the user's country — never from a
  /// number compiled into the app, which cannot follow a price change, a
  /// currency, or a regional tax rule.
  final int priceThb;

  /// How long one purchase grants access. Null means it never expires, which
  /// is what makes [lifetime] a non-consumable rather than a subscription.
  final Duration? duration;

  bool get isSubscription => duration != null;

  /// The plan the comparison screen highlights. Yearly, because it is the one
  /// worth reading twice — monthly anchors the price and lifetime is the
  /// outlier.
  static const recommended = PremiumPlan.yearly;

  static PremiumPlan? fromProductId(String id) {
    for (final plan in PremiumPlan.values) {
      if (plan.productId == id) return plan;
    }
    return null;
  }
}
