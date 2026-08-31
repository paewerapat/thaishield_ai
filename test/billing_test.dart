import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/features/premium/models/entitlement.dart';
import 'package:thaishield_ai/features/premium/models/premium_plan.dart';
import 'package:thaishield_ai/features/premium/providers/premium_provider.dart';
import 'package:thaishield_ai/features/premium/services/billing_service.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_repository.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_store.dart';

/// Task 2.8 — the purchase flow, against a store that can be told how to
/// behave.
///
/// 🚨 **Why a fake rather than the real store.** Nothing in this project can
/// exercise a real purchase: the products do not exist in either store, and
/// creating them needs the Payments Profile, which needs Thai bank details the
/// client expects around November 2026 (CLAUDE.md §5). Waiting for that would
/// mean shipping the code that takes people's money with no coverage at all
/// and finding out whether it worked on the day money started moving.
///
/// So [PremiumProvider] talks to [BillingService], and this file acts out the
/// cases that are hard to reach by hand even when the store *is* live: a
/// pending payment, a cancellation, a redelivered purchase for a retired
/// product, a restore that finds nothing.
///
/// What this cannot prove: that [InAppPurchaseBilling] maps the plugin's types
/// correctly. That layer is deliberately thin, and it stays on the manual
/// checklist until a store account can sell something.
class _FakeBilling implements BillingService {
  /// Set these per test rather than through a constructor — every case here
  /// changes one thing about an otherwise working store, and naming that one
  /// thing at the point of use reads better than a constructor call whose
  /// arguments have to be counted.
  bool available = true;

  Set<String> knownProducts = const {
    'thaishield_premium_weekly',
    'thaishield_premium_monthly',
  };

  /// Purchases the store will emit as soon as [buy] is called. Empty means the
  /// store simply never answers, which is what a timeout looks like.
  List<BillingPurchase> replyToBuy = const [];

  /// What a restore replays.
  List<BillingPurchase> replyToRestore = const [];

  bool buyCalled = false;
  bool restoreCalled = false;
  final List<String> completed = [];

  final _controller = StreamController<List<BillingPurchase>>.broadcast();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<List<BillingPurchase>> get purchaseUpdates => _controller.stream;

  @override
  Future<List<BillingProduct>> queryProducts(Set<String> productIds) async {
    return productIds
        .where(knownProducts.contains)
        .map(
          (id) => BillingProduct(
            id: id,
            localizedPrice: '฿129.00',
            rawPrice: 129,
            currencyCode: 'THB',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<bool> buy(BillingProduct product) async {
    buyCalled = true;
    if (replyToBuy.isNotEmpty) emit(replyToBuy);
    return true;
  }

  @override
  Future<void> restore() async {
    restoreCalled = true;
    if (replyToRestore.isNotEmpty) emit(replyToRestore);
  }

  @override
  Future<void> complete(BillingPurchase purchase) async {
    completed.add(purchase.purchaseId);
  }

  /// Pushes an event the way the store does — asynchronously, after the caller
  /// is already waiting.
  void emit(List<BillingPurchase> purchases) {
    scheduleMicrotask(() => _controller.add(purchases));
  }

  @override
  void dispose() => _controller.close();
}

BillingPurchase _purchase(
  String productId, {
  BillingPurchaseStatus status = BillingPurchaseStatus.purchased,
  String id = 'GPA.1234',
  bool pendingComplete = true,
}) {
  return BillingPurchase(
    productId: productId,
    purchaseId: id,
    status: status,
    pendingCompletePurchase: pendingComplete,
  );
}

class _NullRepository implements EntitlementRepository {
  final List<Entitlement> saved = [];

  @override
  Future<void> save(Entitlement entitlement) async => saved.add(entitlement);

  @override
  Future<Entitlement?> fetch(String purchaseId) async => null;

  @override
  Future<Entitlement?> restoreBest(Iterable<String> purchaseIds) async => null;
}

void main() {
  const weekly = 'thaishield_premium_weekly';
  const monthly = 'thaishield_premium_monthly';

  late _FakeBilling billing;
  late _NullRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    billing = _FakeBilling();
    repository = _NullRepository();
  });

  Future<PremiumProvider> build() async {
    final provider = PremiumProvider(
      store: EntitlementStore.instance,
      repository: repository,
      billing: billing,
    );
    await provider.load();
    return provider;
  }

  group('buying', () {
    test('a completed purchase unlocks the app', () async {
      billing.replyToBuy = [_purchase(monthly)];
      final provider = await build();

      expect(await provider.purchase(PremiumPlan.monthly), StoreOutcome.success);
      expect(provider.isPremium, isTrue);
      expect(provider.entitlement!.source, EntitlementSource.store);
      expect(provider.entitlement!.plan, PremiumPlan.monthly);
      expect(provider.entitlement!.purchaseId, 'GPA.1234');
    });

    test('the purchase is acknowledged', () async {
      // 🚨 Play refunds any purchase that is not acknowledged within three
      // days. The user pays, keeps access for three days, then silently loses
      // both the money and the subscription while the app looks fine.
      billing.replyToBuy = [_purchase(weekly)];
      final provider = await build();

      await provider.purchase(PremiumPlan.weekly);

      expect(billing.completed, ['GPA.1234']);
    });

    test('a cancelled purchase unlocks nothing and is not an error', () async {
      billing.replyToBuy = [
        _purchase(monthly, status: BillingPurchaseStatus.cancelled),
      ];
      final provider = await build();

      expect(
        await provider.purchase(PremiumPlan.monthly),
        StoreOutcome.cancelled,
      );
      expect(provider.isPremium, isFalse);
    });

    test('a failed purchase unlocks nothing', () async {
      billing.replyToBuy = [
        _purchase(monthly, status: BillingPurchaseStatus.error),
      ];
      final provider = await build();

      expect(await provider.purchase(PremiumPlan.monthly), StoreOutcome.failed);
      expect(provider.isPremium, isFalse);
    });

    test('a pending payment grants nothing and is not completed', () async {
      // Telling the store the goods were delivered before it has the money is
      // how a pending purchase becomes a free subscription.
      billing.replyToBuy = [
        _purchase(monthly, status: BillingPurchaseStatus.pending),
      ];
      final provider = await build();

      expect(await provider.purchase(PremiumPlan.monthly), StoreOutcome.pending);
      expect(provider.isPremium, isFalse);
      expect(billing.completed, isEmpty);
    });

    test('says the store is unreachable rather than blaming the payment',
        () async {
      billing.available = false;
      final provider = await build();

      expect(
        await provider.purchase(PremiumPlan.monthly),
        StoreOutcome.storeUnavailable,
      );
      expect(billing.buyCalled, isFalse);
    });

    test('says so when the store does not sell this product', () async {
      // The normal answer today, everywhere: the products cannot be created
      // until the client's Payments Profile exists.
      billing.knownProducts = const {};
      final provider = await build();

      expect(
        await provider.purchase(PremiumPlan.weekly),
        StoreOutcome.productUnavailable,
      );
      expect(billing.buyCalled, isFalse);
    });

    test('the expiry comes from the plan period, not from the store date',
        () async {
      billing.replyToBuy = [_purchase(weekly)];
      final provider = await build();
      final before = DateTime.now().toUtc();

      await provider.purchase(PremiumPlan.weekly);

      final expiry = provider.entitlement!.expiresAt;
      expect(expiry.isAfter(before.add(const Duration(days: 6))), isTrue);
      expect(expiry.isBefore(before.add(const Duration(days: 8))), isTrue);
    });
  });

  group('purchases that arrive on their own', () {
    test('a purchase completed outside the app still unlocks it', () async {
      // A card that clears an hour later, a renewal, a purchase made on another
      // device, or anything Play redelivers because it was never acknowledged.
      // The provider listens for the whole session, not only while the paywall
      // is open — which is why this works with nobody waiting on it.
      final provider = await build();
      expect(provider.isPremium, isFalse);

      billing.emit([_purchase(monthly)]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPremium, isTrue);
      expect(billing.completed, ['GPA.1234']);
    });

    test('a retired product is acknowledged but grants nothing', () async {
      // An old `_2weeks` purchase replayed from a user who bought one before
      // 2026-08-30. Granting on it would resurrect a plan that no longer
      // exists; leaving it unacknowledged makes the store redeliver forever.
      final provider = await build();

      billing.emit([
        _purchase('thaishield_premium_2weeks', id: 'GPA.retired'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPremium, isFalse);
      expect(billing.completed, ['GPA.retired']);
    });
  });

  group('restoring', () {
    test('replays an active subscription onto a new device', () async {
      billing.replyToRestore = [
        _purchase(monthly, status: BillingPurchaseStatus.restored),
      ];
      final provider = await build();

      expect(await provider.restore(), StoreOutcome.success);
      expect(provider.isPremium, isTrue);
    });

    test('says so when the account owns nothing', () async {
      final provider = await build();

      expect(await provider.restore(), StoreOutcome.nothingToRestore);
      expect(billing.restoreCalled, isTrue);
      expect(provider.isPremium, isFalse);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('never shortens access that is already running', () async {
      final provider = await build();
      final far = DateTime.now().toUtc().add(const Duration(days: 300));
      await provider.grantPurchase(
        plan: PremiumPlan.monthly,
        purchaseId: 'GPA.long',
        expiresAt: far,
      );

      billing.replyToRestore = [
        _purchase(weekly, status: BillingPurchaseStatus.restored),
      ];
      await provider.restore();

      expect(provider.entitlement!.expiresAt, far);
    });
  });

  group('the obsolete Firestore copy', () {
    test('is not written any more', () async {
      // It existed because one-time consumables are not restorable. Both
      // stores replay subscriptions, so the store answers that question now —
      // and knows about cancellation, refund, pause and failed payment, none
      // of which a stored date can see. A second, staler answer is worse than
      // none.
      billing.replyToBuy = [_purchase(monthly)];
      final provider = await build();

      await provider.purchase(PremiumPlan.monthly);

      expect(repository.saved, isEmpty);
    });
  });

  group('store prices', () {
    test('are offered for the paywall when the store knows the products',
        () async {
      final provider = await build();
      final products = await provider.storeProducts();

      expect(products.map((p) => p.id), containsAll([weekly, monthly]));
      expect(products.first.localizedPrice, '฿129.00');
    });

    test('are empty rather than throwing when the store has nothing', () async {
      // Today's real answer, and the paywall must fall back to the compiled
      // USD figure rather than showing a blank price.
      billing.knownProducts = const {};
      final provider = await build();

      expect(await provider.storeProducts(), isEmpty);
    });

    test('are empty when there is no store at all', () async {
      billing.available = false;
      final provider = await build();

      expect(await provider.storeProducts(), isEmpty);
    });
  });
}
