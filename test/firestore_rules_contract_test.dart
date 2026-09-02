import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thaishield_ai/core/services/activity_log.dart';

/// The contract between what the app writes and what `firestore.rules` allows.
///
/// 🚨 **This is the gap that let the first reporting bug ship.** The rules say
/// `hasOnly([...])` and `status in [...]`; the app writes a map of string keys.
/// Neither side is type-checked against the other, both are just text, and when
/// they disagree Firestore rejects the write — which
/// `FirestoreActivityLog` then swallows by design, so the app looks perfectly
/// healthy while the CMS stays empty forever.
///
/// `activity_log_test.dart` cannot cover this: it asserts against a fake with
/// no rules in it. Nothing could, until this file. Adding one enum value, or
/// renaming one field, is enough to kill every write in the app, and the only
/// symptom is an admin page that reports nobody has ever opened it.
///
/// A text scan of both files, because that is genuinely what the two sides
/// are. It runs in milliseconds and needs no emulator, no credentials and no
/// network.
void main() {
  late String rules;
  late String dart;

  setUp(() {
    rules = File('firestore.rules').readAsStringSync();
    dart = File('lib/core/services/activity_log.dart').readAsStringSync();
  });

  /// The contents of the first `[...]` following [anchor] in the rules.
  List<String> listAfter(String anchor) {
    final start = rules.indexOf(anchor);
    expect(start, greaterThan(-1), reason: 'no "$anchor" in firestore.rules');
    final open = rules.indexOf('[', start);
    final close = rules.indexOf(']', open);
    return RegExp(r"'([^']+)'")
        .allMatches(rules.substring(open, close))
        .map((m) => m.group(1)!)
        .toList();
  }

  group('app_users', () {
    test('every AccessStatus the app can write is allowed by the rules', () {
      // `status in ['free','trial','premium']` — a value missing here is a
      // rejected write for whoever is in that state.
      final allowed = listAfter("request.resource.data.status in").toSet();
      for (final status in AccessStatus.values) {
        expect(allowed, contains(status.wireName),
            reason: 'firestore.rules refuses status "${status.wireName}"');
      }
    });

    test('every field recordActivity writes is allowed by hasOnly', () {
      // 🚨 `hasOnly` is exact: ONE unexpected key rejects the entire document,
      // so an added field is not a partial write, it is a total outage.
      final allowed = listAfter('function isAppUserShape').toSet();

      // The keys as they appear in the write map in recordActivity.
      const written = [
        'platform',
        'app_version',
        'status',
        'plan_id',
        'expires_at',
        'last_seen_at',
        'first_seen_at',
      ];
      for (final key in written) {
        expect(dart.contains("'$key'"), isTrue,
            reason: 'this test is stale: activity_log.dart no longer writes '
                '"$key", so update the list here rather than deleting it');
        expect(allowed, contains(key),
            reason: 'firestore.rules hasOnly() omits "$key", so every '
                'app_users write is rejected');
      }
    });

    test('the transaction can read the document it is about to write', () {
      // 🚨 The bug this whole file exists for. `recordActivity` writes inside a
      // transaction, a transaction reads before it writes, and `allow read: if
      // false` fails the whole thing — no row, no error, no symptom.
      expect(dart.contains('runTransaction'), isTrue);

      // Comments stripped: the block documents why `read` is wrong, and that
      // explanation contains the very string being searched for. A naive scan
      // flags its own warning, and the only way to pass is to delete it.
      final block = rules
          .substring(
            rules.indexOf('match /app_users/'),
            rules.indexOf('match /purchase_transactions/'),
          )
          .split(RegExp(r'\r?\n'))
          .where((line) => !line.trimLeft().startsWith('//'))
          .join(' ');
      expect(block.contains('allow get: if true'), isTrue,
          reason: 'app_users must allow `get` or the transaction in '
              'recordActivity fails and no row is ever written');
      expect(block.contains('allow read:'), isFalse,
          reason: '`read` grants `list` too — enumeration of every install. '
              'Use `get` + `list: if false`.');
    });
  });

  group('purchase_transactions', () {
    test('every PurchaseLogStatus the app can write is allowed', () {
      final block = rules.substring(rules.indexOf('match /purchase_transactions/'));
      final open = block.indexOf('status in');
      final allowed = RegExp(r"'([^']+)'")
          .allMatches(block.substring(open, block.indexOf(']', open)))
          .map((m) => m.group(1)!)
          .toSet();

      for (final status in PurchaseLogStatus.values) {
        expect(allowed, contains(status.wireName),
            reason: 'firestore.rules refuses status "${status.wireName}". '
                'The failure states are the rows worth having.');
      }
    });

    test('every field recordPurchase writes is allowed by hasOnly', () {
      final block = rules.substring(rules.indexOf('match /purchase_transactions/'));
      final open = block.indexOf('hasOnly');
      final allowed = RegExp(r"'([^']+)'")
          .allMatches(block.substring(open, block.indexOf(']', open)))
          .map((m) => m.group(1)!)
          .toSet();

      const written = [
        'install_id',
        'product_id',
        'status',
        'platform',
        'purchased_at',
        'expires_at',
        'price_amount',
        'price_currency',
        'error_message',
        'recorded_at',
      ];
      for (final key in written) {
        expect(dart.contains("'$key'"), isTrue,
            reason: 'this test is stale: activity_log.dart no longer writes '
                '"$key"');
        expect(allowed, contains(key),
            reason: 'firestore.rules hasOnly() omits "$key", so every '
                'purchase_transactions write is rejected');
      }
    });

    test('product ids are NOT allowlisted', () {
      // Deliberate, and the opposite of `entitlements`. A row here grants
      // nothing, and the rows most worth having name a product this build did
      // not expect — somebody's money against something the app cannot honour.
      final block = rules.substring(rules.indexOf('match /purchase_transactions/'));
      expect(block.contains('thaishield_premium_'), isFalse,
          reason: 'an allowlist here would drop exactly the diagnostic rows '
              'the Transactions page exists for');
    });
  });
}
