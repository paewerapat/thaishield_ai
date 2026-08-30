/// The two plans the paywall compares.
///
/// [productId] is the identifier the same plan carries in Play Console and App
/// Store Connect, so 2C's `in_app_purchase` lookup needs no translation table.
///
/// 🚨 **Both are auto-renewing subscriptions.** The client settled this on
/// 2026-08-30, replacing the one-time passes agreed on 2026-08-22. Create them
/// in both stores as **auto-renewing subscriptions** — a product's type cannot
/// be changed after it is created, only replaced under a new id, so this is the
/// one instruction in the file worth re-reading before touching the consoles.
///
/// **Why the 14-day pass became weekly.** Neither store sells a 14-day billing
/// period. The available periods are 1 week, 1 month, 2 months, 3 months, 6
/// months and 1 year, and that gap is what forced the one-time-pass design in
/// the first place. Asked to make both plans cancellable, the client chose to
/// move the short plan to weekly rather than keep a second billing model on the
/// same screen.
///
/// ⚠️ **Auto-renewal is a poor fit for the audience, and that was said out loud
/// before it was chosen.** A tourist who visits for a fortnight and flies home
/// keeps being charged until they remember to cancel, which turns into refund
/// requests and one-star reviews. The decision was the client's; the mitigation
/// this code owes them is copy that states the renewal plainly — see
/// `premium_legal_note` — rather than burying it.
///
/// Two consequences that shape the rest of this feature, both the reverse of
/// what the consumable design needed:
///
/// 1. **The stores track renewal and expiry, not the app.** `Entitlement`
///    should hold what the store reported.
///
///    ⚠️ **It does not yet.** `PremiumProvider.grantPurchase` still computes
///    `expiresAt` as `purchasedAt + duration`, which was right for a
///    fixed-length pass and is only approximately right for a subscription —
///    it cannot see a cancellation, refund, pause or failed payment. That is
///    harmless while `purchase()` is a stub returning `notAvailableYet`, and
///    it is task 2.8's job to pass the store's own date instead. The signature
///    already accepts one.
/// 2. **The stores can run the free trial**, because a store trial attaches to
///    a subscription. `PremiumProvider.startTrialIfEligible` stays until 2.8
///    wires billing — it is the only trial that exists in a build with no
///    store connection — and is retired when the store's own offer replaces it.
enum PremiumPlan {
  /// One week. The short plan, for a stay too brief to want a month.
  ///
  /// The id deliberately does not reuse `thaishield_premium_2weeks`: that id
  /// was documented as a consumable, and an id that once meant one product type
  /// is the last thing to point at another.
  weekly(
    productId: 'thaishield_premium_weekly',
    titleKey: 'premium_plan_weekly',
    periodKey: 'premium_period_weekly',
    priceUsd: 3.5,
    duration: Duration(days: 7),
  ),

  /// One month. Cheaper per day than [weekly], which is what makes it the one
  /// worth highlighting.
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

  /// The list price in USD, from the client's 2026-08-30 decision.
  ///
  /// ⚠️ This is what the **comparison screen** draws before billing is live.
  /// Once purchases work, the figure shown must come from
  /// `ProductDetails.price` — the store's own localised, tax-inclusive string
  /// for the user's country — never from a number compiled into the app, which
  /// cannot follow a price change, a currency, or a regional tax rule.
  final double priceUsd;

  /// The billing period, used to describe the plan and to size the fallback
  /// expiry the app assumes between store checks.
  ///
  /// ⚠️ Not the source of truth for when access ends. A subscription can be
  /// cancelled, refunded, paused or lapse on a failed payment, and none of
  /// those are visible from a duration — only from the store. Treat this as
  /// what the plan *sells*, not as what the user currently *has*.
  final Duration duration;

  /// Kept as a named constant rather than scattered `Duration(days: 3)` calls,
  /// because the trial length is a commercial decision the client can change
  /// and it has to move in exactly one place when they do.
  static const trialDuration = Duration(days: 3);

  /// Both plans renew.
  ///
  /// ⚠️ Nothing in `lib/` reads this yet — only the tests do, where it pins the
  /// product type so a silent flip fails the suite. An earlier version of this
  /// comment claimed call sites asked it instead of assuming, and credited that
  /// for making the 2026-08-30 change cheap; the QA gate pointed out there are
  /// no such call sites, and the change was cheap for a duller reason, which is
  /// that the paywall never branched on the billing model at all.
  ///
  /// It stays because task 2.8 has to branch on it — acknowledging a
  /// subscription and consuming a consumable are different calls, and getting
  /// that wrong is not recoverable.
  bool get isSubscription => true;

  /// The plan the comparison screen highlights — the monthly, which is the
  /// better value per day and the one a longer stay wants.
  static const recommended = PremiumPlan.monthly;

  static PremiumPlan? fromProductId(String id) {
    for (final plan in PremiumPlan.values) {
      if (plan.productId == id) return plan;
    }
    return null;
  }
}
