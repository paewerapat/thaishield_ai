/// The two plans the paywall compares.
///
/// [productId] is the identifier the same plan carries in Play Console and App
/// Store Connect, so 2C's `in_app_purchase` lookup needs no translation table.
///
/// 🚨 **The two plans no longer share a billing model** (client decision
/// 2026-09-07). [monthly] is an auto-renewing subscription; [pass14Days] is a
/// one-time purchase. A product's type cannot be changed after it is created,
/// only replaced under a new id, so this is the one paragraph in the file worth
/// re-reading before touching either console.
///
/// **Why the short plan is a one-time pass again.** The client asked for 14
/// days at $3.50, and no store sells a 14-day period in any product type: Play
/// offers weekly, 4-weekly, monthly, 2/3/4/6/8-monthly and yearly billing, its
/// rental option offers 24h / 48h / 72h / 1 week / 30 days / 60 days, and Apple
/// offers 1 week, 1 / 2 / 3 / 6 months and a year. Shown that, the client chose
/// 14 days over auto-renewal on 2026-09-07. So the store sells a pass and
/// **this app keeps the clock**.
///
/// Two consequences that shape task 2.8, both of them the reverse of what the
/// subscription design needed:
///
/// 1. **The pass must be consumed, and that costs iOS restore.** A Play "buy"
///    product is a permanent entitlement until the app consumes it, and an
///    unconsumed one can never be bought again — so consuming it is what makes
///    a second fortnight possible. It is also what takes iOS restore away
///    again: StoreKit never replays a consumable. That limitation was gone
///    between 2026-08-30 and 2026-09-07 and is now back, with the client's
///    agreement, and `premium_platform_note` has to keep saying so.
/// 2. **Expiry is arithmetic here, not a store fact — for the pass only.**
///    `expiresAt = purchasedAt + duration` is right for [pass14Days] provided
///    `purchasedAt` is the store's own `purchaseTime`; take it from the device
///    clock at grant time and a reinstall hands out a free fortnight. For
///    [monthly] it is still only an approximation of what the store knows, and
///    2.8 must use the store's date there — a subscription can be cancelled,
///    refunded, paused or lapse on a failed payment, and none of that is
///    visible from a duration.
///
/// ⚠️ **Auto-renewal was a poor fit for this audience and that was said out
/// loud, twice.** A tourist who visits for a fortnight and flies home keeps
/// being charged until they remember to cancel. That risk now applies to
/// [monthly] alone; what the code owes the user is copy that states each plan's
/// model plainly — see `premium_legal_note` — rather than burying it.
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
///    it is task 2.8's job to use the store's own date instead.
///
///    ⚠️ `grantPurchase` takes `purchasedAt`, not an expiry — so 2.8 has to
///    change the signature, not just pass a different argument. An earlier
///    version of this note claimed the signature already accepted one; it does
///    not, and believing it would have produced a subscription whose end date
///    is a guess.
/// 2. **The stores can run the free trial**, because a store trial attaches to
///    a subscription. `PremiumProvider.startTrialIfEligible` stays until 2.8
///    wires billing — it is the only trial that exists in a build with no
///    store connection — and is retired when the store's own offer replaces it.
enum PremiumPlan {
  /// Fourteen days, bought once. The short plan, for a stay too brief to want
  /// a month, and the length the client asked for on 2026-09-07.
  ///
  /// The id deliberately does not reuse `thaishield_premium_2weeks` or
  /// `thaishield_premium_weekly`. The first was documented as a consumable in a
  /// design that was cancelled; the second was never created but was written
  /// down everywhere as a subscription. An id that has already meant one
  /// product type is the last thing to point at another, and neither store
  /// lets an id be re-typed or reused.
  pass14Days(
    productId: 'thaishield_premium_14days',
    titleKey: 'premium_plan_14days',
    periodKey: 'premium_period_14days',
    priceUsd: 3.5,
    duration: Duration(days: 14),
    isSubscription: false,
  ),

  /// One month. Cheaper per day than [weekly], which is what makes it the one
  /// worth highlighting.
  monthly(
    productId: 'thaishield_premium_monthly',
    titleKey: 'premium_plan_monthly',
    periodKey: 'premium_period_monthly',
    priceUsd: 10,
    duration: Duration(days: 30),
    isSubscription: true,
  );

  const PremiumPlan({
    required this.productId,
    required this.titleKey,
    required this.periodKey,
    required this.priceUsd,
    required this.duration,
    required this.isSubscription,
  });

  final String productId;
  final String titleKey;
  final String periodKey;

  /// The list price in USD. $10 for [monthly] since 2026-08-30, $3.50 for the
  /// short plan throughout — only its length changed on 2026-09-07.
  ///
  /// ⚠️ This is what the **comparison screen** draws before billing is live.
  /// Once purchases work, the figure shown must come from
  /// `ProductDetails.price` — the store's own localised, tax-inclusive string
  /// for the user's country — never from a number compiled into the app, which
  /// cannot follow a price change, a currency, or a regional tax rule.
  final double priceUsd;

  /// How long the plan buys, used to describe it and to compute expiry.
  ///
  /// For [pass14Days] this **is** how long access lasts: nothing renews it and
  /// the store tracks no end date, so the app adds it to the store's
  /// `purchaseTime` and that is the answer.
  ///
  /// ⚠️ For [monthly] it is not the source of truth. A subscription can be
  /// cancelled, refunded, paused or lapse on a failed payment, and none of
  /// those are visible from a duration — only from the store. There, treat this
  /// as what the plan *sells*, not as what the user currently *has*.
  final Duration duration;

  /// Kept as a named constant rather than scattered `Duration(days: 3)` calls,
  /// because the trial length is a commercial decision the client can change
  /// and it has to move in exactly one place when they do.
  static const trialDuration = Duration(days: 3);

  /// Whether the store renews this plan by itself.
  ///
  /// True for [monthly], false for [pass14Days] — the first time the two plans
  /// have disagreed, which is why this stopped being a getter that returned a
  /// constant on 2026-09-07.
  ///
  /// The paywall reads it, because a screen that sells both models cannot say
  /// one thing about renewal and cancellation: see `premium_cta` /
  /// `premium_cta_pass` and `premium_cancel_anytime`. Task 2.8 has to branch on
  /// it too — acknowledging a subscription and consuming a one-time purchase
  /// are different calls, and getting that wrong is not recoverable.
  final bool isSubscription;

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
