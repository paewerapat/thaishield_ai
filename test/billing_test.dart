import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/features/premium/models/entitlement.dart';
import 'package:thaishield_ai/features/premium/models/premium_plan.dart';
import 'package:thaishield_ai/features/premium/providers/premium_provider.dart';
import 'package:thaishield_ai/features/premium/services/billing_service.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_repository.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_store.dart';
import 'package:thaishield_ai/features/premium/services/purchase_verifier.dart';

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
    'thaishield_premium_14days',
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

  /// Purchases the app told Play it may sell again — the pass, once its
  /// fortnight is over. A subscription must never appear here.
  final List<String> consumed = [];

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

  @override
  Future<void> consume(BillingPurchase purchase) async {
    consumed.add(purchase.purchaseId);
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
  DateTime? purchasedAt,
  String token = 'play-token',
}) {
  return BillingPurchase(
    productId: productId,
    purchaseId: id,
    status: status,
    purchasedAt: purchasedAt,
    verificationToken: token,
    pendingCompletePurchase: pendingComplete,
  );
}

/// A verifier that answers whatever the test wants, including "no opinion".
class _FakeVerifier implements PurchaseVerifier {
  _FakeVerifier(this.answer);

  _FakeVerifier.noOpinion() : answer = const PurchaseVerification.noOpinion();

  PurchaseVerification answer;
  final List<String> asked = [];

  @override
  Future<PurchaseVerification> verify({
    required String productId,
    required String token,
  }) async {
    asked.add('$productId/$token');
    return answer;
  }
}

/// Remembers what was filed, and can answer a lookup the way Firestore would
/// for a purchase this device did not make.
class _RecordingRepository implements EntitlementRepository {
  final List<Entitlement> saved = [];
  final Map<String, Entitlement> filed = {};

  @override
  Future<void> save(Entitlement entitlement) async {
    saved.add(entitlement);
    final id = entitlement.purchaseId;
    if (id != null) filed[id] = entitlement;
  }

  @override
  Future<Entitlement?> fetch(String purchaseId) async => filed[purchaseId];

  @override
  Future<Entitlement?> restoreBest(Iterable<String> purchaseIds) async {
    Entitlement? best;
    for (final id in purchaseIds) {
      final found = filed[id];
      if (found == null) continue;
      if (best == null || found.expiresAt.isAfter(best.expiresAt)) best = found;
    }
    return best;
  }
}

void main() {
  const pass14Days = 'thaishield_premium_14days';
  const monthly = 'thaishield_premium_monthly';

  late _FakeBilling billing;
  late _RecordingRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    billing = _FakeBilling();
    repository = _RecordingRepository();
  });

  Future<PremiumProvider> build({PurchaseVerifier? verifier}) async {
    final provider = PremiumProvider(
      store: EntitlementStore.instance,
      repository: repository,
      billing: billing,
      verifier: verifier,
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
      billing.replyToBuy = [
        _purchase(pass14Days, purchasedAt: DateTime.now().toUtc()),
      ];
      final provider = await build();

      await provider.purchase(PremiumPlan.pass14Days);

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
        await provider.purchase(PremiumPlan.pass14Days),
        StoreOutcome.productUnavailable,
      );
      expect(billing.buyCalled, isFalse);
    });

    test('the pass runs 14 days from when the store says it was bought',
        () async {
      // 🚨 Not from now. A pass dated "now" on every replay is a pass that a
      // reinstall on day 13 renews for free — the store's purchase time is the
      // only date that cannot be restarted by deleting the app.
      final boughtAt = DateTime.now().toUtc().subtract(const Duration(days: 4));
      billing.replyToBuy = [_purchase(pass14Days, purchasedAt: boughtAt)];
      final provider = await build();

      await provider.purchase(PremiumPlan.pass14Days);

      final expiry = provider.entitlement!.expiresAt;
      expect(
        expiry.difference(boughtAt.add(const Duration(days: 14))).abs(),
        lessThan(const Duration(seconds: 2)),
      );
    });

    test('a pass nothing can date grants nothing rather than a free fortnight',
        () async {
      // No purchase time from the store and no record of our own. The old
      // behaviour was `now + 14 days`, which is the exploit above.
      billing.replyToBuy = [_purchase(pass14Days)];
      final provider = await build();

      final outcome = await provider.purchase(PremiumPlan.pass14Days);

      expect(outcome, StoreOutcome.failed);
      expect(provider.isPremium, isFalse);
      // Still acknowledged: an unacknowledged Play purchase is refunded after
      // three days, and this user did pay.
      expect(billing.completed, ['GPA.1234']);
    });

    test('a pass with no date falls back to the record another device filed',
        () async {
      // The device that bought it wrote the expiry down; this one is replaying
      // the purchase without a date, which Play does on some restores.
      final expiry = DateTime.now().toUtc().add(const Duration(days: 6));
      repository.filed['GPA.1234'] = Entitlement(
        plan: PremiumPlan.pass14Days,
        source: EntitlementSource.store,
        expiresAt: expiry,
        purchaseId: 'GPA.1234',
      );
      billing.replyToBuy = [_purchase(pass14Days)];
      final provider = await build();

      await provider.purchase(PremiumPlan.pass14Days);

      expect(provider.entitlement!.expiresAt, expiry);
    });

    test('the subscription keeps its rolling horizon', () async {
      // A client cannot see a renewal date; what it can see is that the store
      // is reporting the subscription at all, which it only does while it is
      // live. So a period from now, refreshed on every launch.
      final before = DateTime.now().toUtc();
      billing.replyToBuy = [_purchase(monthly)];
      final provider = await build();

      await provider.purchase(PremiumPlan.monthly);

      final expiry = provider.entitlement!.expiresAt;
      expect(expiry.isAfter(before.add(const Duration(days: 29))), isTrue);
      expect(expiry.isBefore(before.add(const Duration(days: 31))), isTrue);
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
        _purchase(pass14Days, status: BillingPurchaseStatus.restored),
      ];
      await provider.restore();

      expect(provider.entitlement!.expiresAt, far);
    });
  });

  group('the durable copy of a purchase', () {
    test('the pass is filed, because nothing else can answer for it', () async {
      // Consumed at the end of its fortnight, so Play stops replaying it, and
      // StoreKit never replays it at all. A record of our own is the only way
      // a second device can honour the days already paid for.
      billing.replyToBuy = [
        _purchase(pass14Days, purchasedAt: DateTime.now().toUtc()),
      ];
      final provider = await build();

      await provider.purchase(PremiumPlan.pass14Days);

      expect(repository.saved, hasLength(1));
      expect(repository.saved.single.plan, PremiumPlan.pass14Days);
    });

    test('the subscription is not filed', () async {
      // Both stores replay it, and they know about cancellation, refund, pause
      // and failed payment — none of which a stored date can see. A second,
      // staler answer is worse than none.
      billing.replyToBuy = [_purchase(monthly)];
      final provider = await build();

      await provider.purchase(PremiumPlan.monthly);

      expect(repository.saved, isEmpty);
    });
  });

  group('the pass is consumed when it ends, never before', () {
    test('a replayed pass whose fortnight is over is consumed, not granted',
        () async {
      // Play keeps replaying an unconsumed "buy" product forever and refuses
      // to sell a second one while it exists. Consuming here is what lets the
      // user buy another fortnight.
      final boughtAt = DateTime.now().toUtc().subtract(const Duration(days: 20));
      final provider = await build();

      billing.emit([
        _purchase(pass14Days,
            status: BillingPurchaseStatus.restored, purchasedAt: boughtAt),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(billing.consumed, ['GPA.1234']);
      expect(provider.isPremium, isFalse);
      // Consuming acknowledges too, so completing as well would be a second
      // call about a purchase Play has already finished with.
      expect(billing.completed, isEmpty);
    });

    test('a pass still inside its fortnight is granted and left alone',
        () async {
      final boughtAt = DateTime.now().toUtc().subtract(const Duration(days: 2));
      final provider = await build();

      billing.emit([_purchase(pass14Days, purchasedAt: boughtAt)]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isPremium, isTrue);
      expect(billing.consumed, isEmpty);
      expect(billing.completed, ['GPA.1234']);
    });

    test('an expired subscription is never consumed', () async {
      // 🚨 Consuming a subscription is not a recoverable mistake. An expired
      // one simply stops being reported by the store.
      final provider = await build();

      billing.emit([_purchase(monthly)]);
      await Future<void>.delayed(Duration.zero);

      expect(billing.consumed, isEmpty);
      expect(provider.isPremium, isTrue);
    });
  });

  group('server-side receipt validation', () {
    test('the store\'s own expiry replaces the app\'s estimate', () async {
      // The rolling horizon over-grants access to someone who cancels and then
      // stays offline. When the server has the real renewal date, it wins.
      final real = DateTime.now().toUtc().add(const Duration(days: 3));
      final verifier = _FakeVerifier(PurchaseVerification(
        hasOpinion: true,
        valid: true,
        expiresAt: real,
      ));
      billing.replyToBuy = [_purchase(monthly)];
      final provider = await build(verifier: verifier);

      await provider.purchase(PremiumPlan.monthly);

      expect(provider.entitlement!.expiresAt, real);
      expect(verifier.asked, ['thaishield_premium_monthly/play-token']);
    });

    test('a purchase the store disowns unlocks nothing', () async {
      final verifier = _FakeVerifier(const PurchaseVerification(
        hasOpinion: true,
        valid: false,
        reason: 'not_purchased',
      ));
      billing.replyToBuy = [
        _purchase(monthly, purchasedAt: DateTime.now().toUtc()),
      ];
      final provider = await build(verifier: verifier);

      final outcome = await provider.purchase(PremiumPlan.monthly);

      expect(outcome, StoreOutcome.failed);
      expect(provider.isPremium, isFalse);
      expect(billing.completed, ['GPA.1234']);
    });

    test('no opinion falls back to the store SDK rather than denying access',
        () async {
      // 🚨 The function being down, or its Play permission not granted yet,
      // must never read as "this user did not pay".
      final verifier = _FakeVerifier.noOpinion();
      billing.replyToBuy = [_purchase(monthly)];
      final provider = await build(verifier: verifier);

      await provider.purchase(PremiumPlan.monthly);

      expect(provider.isPremium, isTrue);
    });

    test('a verifier that throws is treated the same as silence', () async {
      billing.replyToBuy = [_purchase(monthly)];
      final provider = await build(verifier: _ThrowingVerifier());

      await provider.purchase(PremiumPlan.monthly);

      expect(provider.isPremium, isTrue);
    });
  });

  group('store prices', () {
    test('are offered for the paywall when the store knows the products',
        () async {
      final provider = await build();
      final products = await provider.storeProducts();

      expect(products.map((p) => p.id), containsAll([pass14Days, monthly]));
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


class _ThrowingVerifier implements PurchaseVerifier {
  @override
  Future<PurchaseVerification> verify({
    required String productId,
    required String token,
  }) async =>
      throw StateError('the verifier is broken');
}
