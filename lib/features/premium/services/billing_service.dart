import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// The store, behind an interface the rest of the app can be tested against.
///
/// ## Why this exists rather than calling `InAppPurchase.instance` directly
///
/// Nothing in this project can exercise a real purchase yet. The products do
/// not exist in either store — creating them needs the Payments Profile, which
/// needs Thai bank details the client expects to have around November 2026
/// (CLAUDE.md §5). Wiring the plugin straight into [PremiumProvider] would have
/// meant shipping the one part of the app that takes people's money with no
/// test coverage at all, and finding out whether it worked on the day money
/// started moving.
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
/// Apple's verifyReceipt. That belongs in a Cloud Function, which cannot be
/// deployed until the developer account is given a Firebase role (CLAUDE.md
/// §2.4 — the same block that holds `computeRoute`). Until then the app trusts
/// what the store SDK hands it, which is the normal client-only posture and is
/// **not** a security boundary — see [EntitlementRepository] for the same
/// caveat stated about the local cache.
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
  /// 🚨 **Acknowledge, never consume.** Play cancels and refunds any purchase
  /// that is not acknowledged within three days. Consuming is for one-time
  /// products; doing it to a subscription is not a recoverable mistake. The
  /// plugin's `completePurchase` acknowledges — the consume path is a separate
  /// call this project must never make.
  Future<void> complete(BillingPurchase purchase);

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
