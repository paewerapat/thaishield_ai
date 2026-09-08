import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// The store, behind an interface the rest of the app can be tested against.
///
/// ## Why this exists rather than calling `InAppPurchase.instance` directly
///
/// A real purchase still cannot be exercised from a test. Wiring the plugin
/// straight into [PremiumProvider] would have meant shipping the one part of
/// the app that takes people's money with no coverage at all, and finding out
/// whether it worked on the day money started moving.
///
/// *(Both Play products exist and are active since 2026-09-08, and the client
/// linked the payments profile the same day. What that unblocks is a sandbox
/// purchase on a real handset — not a unit test, which still needs the fake.)*
///
/// So the provider talks to this interface, the tests supply a fake that can
/// act out cancellation, failure, a pending purchase and a restore, and
/// [InAppPurchaseBilling] is the thin mapping layer that is left to verify by
/// hand once the products exist.
///
/// ## What this deliberately does not do
///
/// **It does not validate receipts.** A client cannot: the check has to happen
/// somewhere the user does not control, against Play's Developer API or
/// Apple's App Store Server API. That is `validatePurchase` in
/// `functions/index.js`, and [PremiumProvider] calls it through
/// [PurchaseVerifier] — this layer stays a pure mapping onto the plugin and
/// makes no trust decision of its own.
abstract class BillingService {
  /// False when the device has no store, the user is signed out of it, or
  /// billing is unavailable for the region. The paywall says so rather than
  /// offering a button that cannot work.
  Future<bool> isAvailable();

  /// Everything the store says about purchases, including ones that complete
  /// outside the app — a card that finally clears, a family-sharing grant, a
  /// subscription renewing. **The app must listen for the whole session, not
  /// only while a purchase screen is open**, which is why [PremiumProvider]
  /// subscribes at startup and not in the paywall.
  Stream<List<BillingPurchase>> get purchaseUpdates;

  /// Store-side product records, for real localised prices. Ids the store does
  /// not know are simply absent from the result — the caller must handle a
  /// shorter list than it asked for, which is exactly what happens today
  /// because neither store has these products yet.
  Future<List<BillingProduct>> queryProducts(Set<String> productIds);

  /// Starts a purchase. Returns false when the flow could not even be opened.
  ///
  /// 🚨 Success here means "the sheet opened", not "the user paid". The
  /// outcome arrives on [purchaseUpdates], possibly minutes later, possibly
  /// after the app has been killed and reopened.
  Future<bool> buy(BillingProduct product);

  /// Asks the store to replay this account's purchases. Results arrive on
  /// [purchaseUpdates] with [BillingPurchaseStatus.restored].
  Future<void> restore();

  /// Tells the store the app has delivered what was bought.
  ///
  /// 🚨 **This acknowledges. It does not consume.** Play cancels and refunds any
  /// purchase that is not acknowledged within three days, so every terminal
  /// state goes through here. Consuming is a different call with a different
  /// meaning and its own timing — see [consume] — and it must never touch a
  /// subscription.
  Future<void> complete(BillingPurchase purchase);

  /// Consumes a one-time purchase so the store will sell it again.
  ///
  /// 🚨 **Only [PremiumPlan.pass14Days], and only once its 14 days are over.**
  /// Play keeps replaying a "buy" product to every device on the account until
  /// it is consumed, and refuses to sell it a second time while it is
  /// unconsumed. Those two facts pull in opposite directions and fix the
  /// timing between them:
  ///
  /// - consume it **on purchase day** and the user cannot restore their own
  ///   pass on a second device — `premium_platform_note` promises they can on
  ///   Android — and this app loses the replay it uses to re-grant access;
  /// - **never** consume it and the same user can never buy a second fortnight.
  ///
  /// So it happens when the pass expires, which is what
  /// `PremiumProvider._onPurchaseUpdates` does with an expired replay.
  ///
  /// 🚨 **Never call this for [PremiumPlan.monthly].** Consuming a subscription
  /// is not a recoverable mistake.
  ///
  /// A no-op on iOS: StoreKit has no consume step — `completePurchase`
  /// finishes a consumable — which is exactly why the pass cannot be restored
  /// there.
  Future<void> consume(BillingPurchase purchase);

  void dispose();
}

/// A product as the store describes it, in the user's own currency.
@immutable
class BillingProduct {
  const BillingProduct({
    required this.id,
    required this.localizedPrice,
    required this.rawPrice,
    required this.currencyCode,
  });

  final String id;

  /// Already formatted by the store — "฿129.00", "$3.50", "¥600". Show this
  /// rather than formatting [rawPrice], because the store knows the currency's
  /// conventions and whether tax is included.
  final String localizedPrice;

  final double rawPrice;
  final String currencyCode;
}

enum BillingPurchaseStatus {
  /// Awaiting something outside the app — a slow card, a parent's approval,
  /// cash payment at a convenience store. Access must **not** be granted, and
  /// the purchase must **not** be completed, until it moves on.
  pending,
  purchased,
  restored,
  cancelled,
  error,
}

/// One purchase, as the store reports it.
@immutable
class BillingPurchase {
  const BillingPurchase({
    required this.productId,
    required this.purchaseId,
    required this.status,
    this.purchasedAt,
    this.verificationToken = '',
    this.pendingCompletePurchase = false,
    this.errorMessage,
  });

  final String productId;

  /// The store's own transaction handle — Play's `purchaseID`, StoreKit's
  /// transaction identifier. Stable for the account, which is what makes a
  /// restore on a new device possible.
  final String purchaseId;

  final BillingPurchaseStatus status;

  /// When the store says the purchase happened. Absent on some platforms and
  /// on restores, which is why the caller must have a fallback rather than
  /// assuming it is there.
  final DateTime? purchasedAt;

  /// What a server needs to ask the store about this purchase: Play's purchase
  /// token, or the base64 App Store receipt. Empty when the platform did not
  /// supply one, which is the signal to skip verification rather than to fail
  /// it — see [PurchaseVerifier].
  ///
  /// 🚨 Not a secret to guard, but not a thing to log either: it is the handle
  /// that identifies one person's transaction.
  final String verificationToken;

  /// The store is still waiting to be told the app delivered the goods.
  final bool pendingCompletePurchase;

  final String? errorMessage;

  bool get grantsAccess =>
      status == BillingPurchaseStatus.purchased ||
      status == BillingPurchaseStatus.restored;
}

/// The real thing: `in_app_purchase` mapped onto [BillingService].
///
/// 🚨 **This class is the untested part of task 2.8 and knows it.** Everything
/// above it is covered by tests against a fake; this layer can only be checked
/// against a live store, which needs products, which needs the Payments
/// Profile. Keep it thin enough to read in one sitting and put no decisions in
/// it — decisions belong in [PremiumProvider], where they can be tested.
class InAppPurchaseBilling implements BillingService {
  InAppPurchaseBilling({InAppPurchase? plugin})
      : _plugin = plugin ?? InAppPurchase.instance;

  final InAppPurchase _plugin;

  @override
  Future<bool> isAvailable() => _plugin.isAvailable();

  @override
  Stream<List<BillingPurchase>> get purchaseUpdates =>
      _plugin.purchaseStream.map(
        (list) => list.map(_toBillingPurchase).toList(growable: false),
      );

  @override
  Future<List<BillingProduct>> queryProducts(Set<String> productIds) async {
    final response = await _plugin.queryProductDetails(productIds);
    return response.productDetails
        .map(
          (p) => BillingProduct(
            id: p.id,
            localizedPrice: p.price,
            rawPrice: p.rawPrice,
            currencyCode: p.currencyCode,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<bool> buy(BillingProduct product) async {
    final response = await _plugin.queryProductDetails({product.id});
    final details = response.productDetails
        .where((p) => p.id == product.id)
        .toList(growable: false);
    if (details.isEmpty) return false;

    // 🚨 `buyNonConsumable`, not `buyConsumable`, for both plans. Despite the
    // name it is the correct call for an auto-renewing subscription — the
    // plugin's consumable path exists for products that are used up and
    // repurchased. Sending a subscription down it is the mistake that cannot
    // be undone.
    return _plugin.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details.first),
    );
  }

  @override
  Future<void> restore() => _plugin.restorePurchases();

  @override
  Future<void> consume(BillingPurchase purchase) async {
    if (!Platform.isAndroid) return;

    final details = _live[purchase.purchaseId];
    if (details == null) return;

    // The federated `InAppPurchase` API has no consume: it is Play-only, so it
    // lives on the Android addition. `consumePurchase` also acknowledges, so a
    // consumed purchase must not be completed again afterwards — the caller
    // treats consume and complete as alternatives, not a sequence.
    final android =
        _plugin.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    await android.consumePurchase(details);
    _live.remove(purchase.purchaseId);
  }

  @override
  Future<void> complete(BillingPurchase purchase) async {
    // Nothing to do: the plugin's own PurchaseDetails is what completePurchase
    // needs, and it is held by [PremiumProvider] only as a [BillingPurchase].
    // The live details are kept here, keyed by the store's id, so the mapping
    // layer stays the only place that touches plugin types.
    final details = _live.remove(purchase.purchaseId);
    if (details == null) return;
    if (!details.pendingCompletePurchase) return;
    await _plugin.completePurchase(details);
  }

  /// Plugin objects held only long enough to acknowledge them.
  final Map<String, PurchaseDetails> _live = {};

  BillingPurchase _toBillingPurchase(PurchaseDetails details) {
    if (details.pendingCompletePurchase) _live[details.purchaseID ?? ''] = details;

    return BillingPurchase(
      productId: details.productID,
      purchaseId: details.purchaseID ?? '',
      status: _toStatus(details.status),
      purchasedAt: _parseTransactionDate(details.transactionDate),
      // `serverVerificationData` is Play's purchase token on Android and the
      // base64 receipt on iOS — the two things `validatePurchase` knows how to
      // ask about. `localVerificationData` is deliberately not used: it is the
      // device's own copy, which is the thing being checked.
      verificationToken: details.verificationData.serverVerificationData,
      pendingCompletePurchase: details.pendingCompletePurchase,
      errorMessage: details.error?.message,
    );
  }

  static BillingPurchaseStatus _toStatus(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.pending:
        return BillingPurchaseStatus.pending;
      case PurchaseStatus.purchased:
        return BillingPurchaseStatus.purchased;
      case PurchaseStatus.restored:
        return BillingPurchaseStatus.restored;
      case PurchaseStatus.canceled:
        return BillingPurchaseStatus.cancelled;
      case PurchaseStatus.error:
        return BillingPurchaseStatus.error;
    }
  }

  /// `transactionDate` is milliseconds-since-epoch as a **string**, and is null
  /// on platforms and paths that do not supply it. Anything unparseable is
  /// treated as absent rather than as 1970, which would expire the purchase the
  /// instant it was granted.
  static DateTime? _parseTransactionDate(String? raw) {
    if (raw == null) return null;
    final millis = int.tryParse(raw);
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  @override
  void dispose() => _live.clear();
}
