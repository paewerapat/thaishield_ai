import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/core/services/activity_log.dart';
import 'package:thaishield_ai/core/services/install_identity.dart';
import 'package:thaishield_ai/features/premium/models/entitlement.dart';
import 'package:thaishield_ai/features/premium/models/premium_plan.dart';
import 'package:thaishield_ai/features/premium/providers/premium_provider.dart';
import 'package:thaishield_ai/features/premium/services/billing_service.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_repository.dart';
import 'package:thaishield_ai/features/premium/services/entitlement_store.dart';

/// The reporting layer behind the CMS's **App Users** and **Transactions**
/// pages (added 2026-09-01 at the client's request).
///
/// 🚨 **What these tests are actually protecting.** Everything on this path is
/// fire-and-forget and swallows its own errors on purpose — a Firestore
/// problem must cost a log line, never a purchase. That is the right trade and
/// it has an obvious cost: *nothing a user or a screen can see distinguishes
/// "reporting works" from "reporting silently writes nothing".* The client
/// would find out weeks later, from an empty admin page, and conclude the app
/// has no users. These tests are the only thing standing in that gap, which is
/// why they assert against a recording fake rather than trusting the wiring.
///
/// What they cannot prove: that [FirestoreActivityLog] writes documents
/// Firestore actually accepts. That is `firestore.rules`, and it is checked by
/// deploying the rules and watching a real launch — the same manual gap
/// `InAppPurchaseBilling` has.
class _RecordingLog implements ActivityLog {
  final List<
      ({
        AccessStatus status,
        String? planId,
        DateTime? expiresAt,
        String? locale
      })> activity = [];

  final List<
      ({
        String purchaseId,
        String productId,
        PurchaseLogStatus status,
        DateTime? expiresAt,
        double? priceAmount,
        String? priceCurrency
      })> purchases = [];

  @override
  Future<void> recordActivity({
    required AccessStatus status,
    String? planId,
    DateTime? expiresAt,
    String? locale,
  }) async {
    activity.add((
      status: status,
      planId: planId,
      expiresAt: expiresAt,
      locale: locale,
    ));
  }

  @override
  Future<void> recordPurchase({
    required String purchaseId,
    required String productId,
    required PurchaseLogStatus status,
    DateTime? purchasedAt,
    DateTime? expiresAt,
    double? priceAmount,
    String? priceCurrency,
    String? errorMessage,
  }) async {
    purchases.add((
      purchaseId: purchaseId,
      productId: productId,
      status: status,
      expiresAt: expiresAt,
      priceAmount: priceAmount,
      priceCurrency: priceCurrency,
    ));
  }
}

class _FakeBilling implements BillingService {
  Set<String> knownProducts = const {
    'thaishield_premium_weekly',
    'thaishield_premium_monthly',
  };
  List<BillingPurchase> replyToBuy = const [];

  final _controller = StreamController<List<BillingPurchase>>.broadcast();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<List<BillingPurchase>> get purchaseUpdates => _controller.stream;

  @override
  Future<List<BillingProduct>> queryProducts(Set<String> productIds) async =>
      productIds
          .where(knownProducts.contains)
          .map((id) => BillingProduct(
                id: id,
                localizedPrice: '฿359.00',
                rawPrice: 359,
                currencyCode: 'THB',
              ))
          .toList(growable: false);

  @override
  Future<bool> buy(BillingProduct product) async {
    if (replyToBuy.isNotEmpty) {
      scheduleMicrotask(() => _controller.add(replyToBuy));
    }
    return true;
  }

  @override
  Future<void> restore() async {}

  @override
  Future<void> complete(BillingPurchase purchase) async {}

  /// Pushes an event the way the store does — unprompted. Play redelivers
  /// purchases nobody asked for, which is exactly the case below.
  void emit(List<BillingPurchase> purchases) => _controller.add(purchases);

  @override
  void dispose() => _controller.close();
}

class _NullRepository implements EntitlementRepository {
  @override
  Future<void> save(Entitlement entitlement) async {}

  @override
  Future<Entitlement?> fetch(String purchaseId) async => null;

  @override
  Future<Entitlement?> restoreBest(Iterable<String> purchaseIds) async => null;
}

BillingPurchase _purchase(
  String productId, {
  BillingPurchaseStatus status = BillingPurchaseStatus.purchased,
  String id = 'GPA.1234',
}) =>
    BillingPurchase(
      productId: productId,
      purchaseId: id,
      status: status,
      pendingCompletePurchase: true,
    );

void main() {
  const monthly = 'thaishield_premium_monthly';

  late _RecordingLog log;
  late _FakeBilling billing;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    InstallIdentity.instance.overrideForTest(null);
    log = _RecordingLog();
    billing = _FakeBilling();
    await EntitlementStore.instance.clear();
  });

  Future<PremiumProvider> build() async {
    final provider = PremiumProvider(
      store: EntitlementStore.instance,
      repository: _NullRepository(),
      billing: billing,
      activityLog: log,
    );
    await provider.load();
    return provider;
  }

  group('install identity', () {
    test('is 32 hex characters', () {
      expect(InstallIdentity.generate(), matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('two ids do not collide', () {
      // The id is the document key. Two installs sharing one would merge into
      // a single CMS row reporting somebody else's first-seen date.
      final ids = List.generate(200, (_) => InstallIdentity.generate());
      expect(ids.toSet(), hasLength(200));
    });

    test('is the same on every read, and survives a restart', () async {
      final first = await InstallIdentity.instance.read();
      expect(await InstallIdentity.instance.read(), first);

      // A fresh process reading the same preferences: the in-memory cache is
      // gone, the stored value is not. If this regressed, every launch would
      // file a new row and the client's user count would be a count of app
      // opens.
      InstallIdentity.instance.overrideForTest(null);
      expect(await InstallIdentity.instance.read(), first);
    });

    test('carries no device or advertising identifier', () {
      // Both stores' privacy reviews look for exactly these. A random number
      // in our own preferences is disclosable without touching the published
      // policy beyond section 4; a hardware id is not, and reaching for one
      // later to "make the id survive a reinstall" is the change that would
      // quietly break that.
      final source =
          File('lib/core/services/install_identity.dart').readAsStringSync();
      for (final banned in [
        'androidId',
        'advertisingId',
        'deviceId',
        'device_info',
        'imei',
      ]) {
        expect(source.contains(banned), isFalse, reason: 'found $banned');
      }
    });
  });

  group('app user row', () {
    test('a free launch reports free, with no plan and no expiry', () async {
      final provider = await build();
      provider.recordUsage(locale: 'th');

      expect(log.activity, hasLength(1));
      expect(log.activity.single.status, AccessStatus.free);
      expect(log.activity.single.planId, isNull);
      expect(log.activity.single.expiresAt, isNull);
      expect(log.activity.single.locale, 'th');
    });

    test('the trial reports trial, not premium', () async {
      // The client asked to see who is Premium. Someone on day 2 of the free
      // trial is unlocked and has paid nothing; counting them as Premium
      // overstates revenue in the one column that will be read as revenue.
      final provider = await build();
      await provider.startTrialIfEligible();

      expect(log.activity.last.status, AccessStatus.trial);
      expect(log.activity.last.planId, isNull);
      expect(log.activity.last.expiresAt, isNotNull);
    });

    test('a purchase reports premium with the plan and the expiry', () async {
      final provider = await build();
      await provider.grantPurchase(
        plan: PremiumPlan.monthly,
        purchaseId: 'GPA.1234',
        expiresAt: DateTime.utc(2026, 12, 1),
      );

      expect(log.activity.last.status, AccessStatus.premium);
      expect(log.activity.last.planId, monthly);
      expect(log.activity.last.expiresAt, DateTime.utc(2026, 12, 1));
    });

    test('a lapsed pass reports free, and drops the stale expiry', () async {
      final provider = await build();
      await provider.grantPurchase(
        plan: PremiumPlan.monthly,
        purchaseId: 'GPA.1234',
        expiresAt: DateTime.utc(2020),
      );
      log.activity.clear();
      provider.recordUsage();

      // An expiry left on a row that has lapsed reads in the CMS as a pass the
      // user still holds.
      expect(log.activity.single.status, AccessStatus.free);
      expect(log.activity.single.expiresAt, isNull);
    });

    test('a null locale is sent rather than guessed', () async {
      // main.dart sends null until the user has actually chosen a language,
      // because LocaleProvider's unset default is `en` — reporting that would
      // file every first launch as an English speaker, including the Thai and
      // Chinese users the language screen exists to catch.
      final provider = await build();
      provider.recordUsage();
      expect(log.activity.single.locale, isNull);
    });
  });

  group('transaction rows', () {
    test('a completed purchase is logged with the store price', () async {
      final provider = await build();
      billing.replyToBuy = [_purchase(monthly)];

      await provider.purchase(PremiumPlan.monthly);

      expect(log.purchases, hasLength(1));
      final row = log.purchases.single;
      expect(row.purchaseId, 'GPA.1234');
      expect(row.productId, monthly);
      expect(row.status, PurchaseLogStatus.purchased);
      // From the store's own ProductDetails, never PremiumPlan.priceUsd. A row
      // claiming 10.00 USD when the user was charged 359 baht is a wrong
      // number in a financial log, which is worse than a blank one.
      expect(row.priceAmount, 359);
      expect(row.priceCurrency, 'THB');
    });

    test('a cancelled purchase is logged, and grants no expiry', () async {
      final provider = await build();
      billing.replyToBuy = [
        _purchase(monthly, status: BillingPurchaseStatus.cancelled),
      ];

      await provider.purchase(PremiumPlan.monthly);

      expect(log.purchases.single.status, PurchaseLogStatus.cancelled);
      expect(log.purchases.single.expiresAt, isNull);
    });

    test('a failed purchase is logged', () async {
      // The whole point of the log: "I paid and got nothing" is only
      // answerable if the failures are in it.
      final provider = await build();
      billing.replyToBuy = [
        _purchase(monthly, status: BillingPurchaseStatus.error),
      ];

      await provider.purchase(PremiumPlan.monthly);

      expect(log.purchases.single.status, PurchaseLogStatus.failed);
    });

    test('a pending payment is logged before it clears', () async {
      final provider = await build();
      billing.replyToBuy = [
        _purchase(monthly, status: BillingPurchaseStatus.pending),
      ];

      await provider.purchase(PremiumPlan.monthly);

      expect(log.purchases.single.status, PurchaseLogStatus.pending);
      expect(log.purchases.single.expiresAt, isNull);
    });

    test('a product this build does not know is still logged', () async {
      // Somebody's money against a product the app cannot honour is the single
      // most useful row the page can carry, which is why firestore.rules
      // deliberately does not allowlist product ids on this collection.
      // Arrives unprompted, which is how a retired product reaches the app at
      // all: the store redelivers an old purchase to a build that has since
      // dropped the id. It never goes through `purchase()`, because this build
      // could not offer that product for sale.
      await build();
      billing.emit([_purchase('thaishield_premium_retired')]);
      await Future<void>.delayed(Duration.zero);

      expect(
        log.purchases.map((p) => p.productId),
        contains('thaishield_premium_retired'),
      );
    });

    test('a transaction with no store id is refused, not keyed on empty', () {
      // Every such event would otherwise collide into one shared document that
      // each new failure overwrites.
      expect(FirestoreActivityLog.isLoggable(''), isFalse);
      expect(FirestoreActivityLog.isLoggable('GPA.1234'), isTrue);
    });
  });

  group('what the privacy policy promises', () {
    // 🚨 These pin a claim in a **published legal document** against the code
    // that has to be true for it. The policy lives in the other repo
    // (`thaishield-ai-web-admin/app/privacy/page.tsx`) and was amended on
    // 2026-09-01 to disclose the install id, so nothing in this repo's normal
    // workflow would notice the two drifting apart. A refactor that deletes
    // the tile leaves the app working, the analyzer clean and the policy
    // false.

    test('the install id is shown on the Profile screen', () {
      // §7 of the policy tells the user to quote "the installation identifier
      // shown on the app's Profile screen" to have their record deleted. The
      // app has no account screen, so this tile is the only surface that can
      // show it — and a right nobody can exercise is a worse compliance
      // position than never having claimed it.
      final source = File(
        'lib/features/profile/screens/profile_screen.dart',
      ).readAsStringSync();

      expect(
        source.contains('InstallIdentity.instance.read()'),
        isTrue,
        reason:
            'Profile no longer reads the install id. The published privacy '
            'policy tells users it is shown there.',
      );
      expect(
        source.contains(r'ID $_installId'),
        isTrue,
        reason: 'Profile reads the install id but no longer displays it.',
      );
    });

    test('the copy confirmation exists in all six languages', () {
      // wording_test.dart enforces six languages for every key; this asserts
      // the key itself has not been deleted along with the feature.
      final source =
          File('lib/core/localization/app_text.dart').readAsStringSync();
      expect(source.contains("'profile_id_copied'"), isTrue);
    });
  });

  group('the QA override', () {
    test('does not report a tester as a paying customer', () async {
      final provider = await build();
      await EntitlementStore.instance.write(
        Entitlement(
          plan: PremiumPlan.monthly,
          source: EntitlementSource.qaOverride,
          expiresAt: DateTime.utc(2030),
        ),
      );
      await provider.load();
      provider.recordUsage();

      expect(provider.isPremium, isTrue, reason: 'the tester is unlocked');
      expect(
        log.activity.last.status,
        AccessStatus.free,
        reason: "but must not appear in the client's list as a customer",
      );
    });
  });
}
