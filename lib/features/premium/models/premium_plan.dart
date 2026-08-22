/// The two passes the paywall compares.
///
/// [productId] is the identifier the same pass carries in Play Console and App
/// Store Connect, so 2C's `in_app_purchase` lookup needs no translation table.
///
/// 🚨 **Both are one-time consumables, not subscriptions.** The client settled
/// this on 2026-08-22: a tourist buys a pass, it runs out, and nothing is ever
/// charged again unless they buy another one. Create them in both stores as
/// **consumable / non-renewing one-time products** — a product's type cannot be
/// changed after it is created, only replaced with a new id.
///
/// Two consequences that shape the rest of this feature:
///
/// 1. **The stores will not track expiry for us.** A subscription reports its
///    own renewal state; a consumable is a single event. The app therefore owns
///    the clock — see `Entitlement.expiresAt`, computed from [duration].
/// 2. **The stores will not run the free trial for us** either, because a store
///    trial can only be attached to a subscription. The 3-day trial is granted
///    by the app itself — see `PremiumProvider.startTrialIfEligible`.
enum PremiumPlan {
  /// 14 days. Sized for a typical holiday, and the only pass the trial leads
  /// into.
  twoWeeks(
    productId: 'thaishield_premium_2weeks',
    titleKey: 'premium_plan_2weeks',
    periodKey: 'premium_period_2weeks',
    priceUsd: 7,
    duration: Duration(days: 14),
  ),

  /// 30 days, for a longer stay. Cheaper per day than [twoWeeks], which is
  /// what makes it the one worth highlighting.
  monthly(
    productId: 'thaishield_premium_monthly',
    titleKey: 'premium_plan_monthly',
    periodKey: 'premium_period_monthly',
    priceUsd: 10,
    duration: Duration(days: 30),
  );

  const PremiumPlan({
    required this.productId,
    required this.titleKey,
    required this.periodKey,
    required this.priceUsd,
    required this.duration,
  });

  final String productId;
  final String titleKey;
  final String periodKey;

  /// The list price in USD, from the client's 2026-08-22 decision.
  ///
  /// ⚠️ This is what the **comparison screen** draws before billing is live.
  /// Once purchases work, the figure shown must come from
  /// `ProductDetails.price` — the store's own localised, tax-inclusive string
  /// for the user's country — never from a number compiled into the app, which
  /// cannot follow a price change, a currency, or a regional tax rule.
  final int priceUsd;

  /// How long one purchase grants access, counted from the moment the store
  /// confirms it. Never null: every pass expires, which is the whole point of
  /// selling passes rather than subscriptions.
  final Duration duration;

  /// Kept as a named constant rather than scattered `Duration(days: 3)` calls,
  /// because the trial length is a commercial decision the client can change
  /// and it has to move in exactly one place when they do.
  static const trialDuration = Duration(days: 3);

  /// Neither pass renews. This exists so call sites read as a question about
  /// the product rather than an assumption, and so the day someone adds a real
  /// subscription there is one place to change.
  bool get isSubscription => false;

  /// The plan the comparison screen highlights — the 30-day pass, which is the
  /// better value per day and the one a longer stay wants.
  static const recommended = PremiumPlan.monthly;

  static PremiumPlan? fromProductId(String id) {
    for (final plan in PremiumPlan.values) {
      if (plan.productId == id) return plan;
    }
    return null;
  }
}
