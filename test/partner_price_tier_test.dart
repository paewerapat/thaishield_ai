// Places with no price tier — client report 2026-09-13.
//
// Staff could not save a hospital, a police station or a transport stop in the
// CMS, because price tier was a required Fair/Caution/High pick. The CMS now
// stores those places WITHOUT a `price_tier` field. What must hold on this
// side: such a place shows no price badge at all — neither the green "within
// typical range" (a claim nobody made) nor the orange "above typical range"
// (worse: a price warning on a hospital).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thaishield_ai/core/models/partner_category.dart';
import 'package:thaishield_ai/core/models/partner_location.dart';

PartnerLocation _place(String type, String tier) => PartnerLocation(
      id: 'x',
      name: 'x',
      lat: 13.7,
      lng: 100.5,
      type: type,
      rating: 0,
      isVerified: false,
      priceTier: tier,
      imageUrl: '',
    );

void main() {
  test('exactly these six categories carry no price tier', () {
    // Mirrors TYPES_WITHOUT_PRICE_TIER in the web-admin repo.
    expect(
      PartnerCategory.values.where((c) => !c.hasPriceTier).map((c) => c.value),
      unorderedEquals([
        'transport',
        'hospital',
        'police',
        'tourist_police',
        'atm_bank',
        'tourist_info',
      ]),
    );
  });

  test('a stored document with no price_tier shows no price badge', () {
    final p = _place('restaurant', '');
    expect(p.showsPriceTier, isFalse);
    expect(p.isAboveTypicalRange, isFalse);
  });

  test('a hospital shows no price badge even if a legacy doc says fair or high',
      () {
    for (final tier in ['fair', 'caution', 'high']) {
      final p = _place('hospital', tier);
      expect(p.showsPriceTier, isFalse, reason: tier);
      expect(p.isAboveTypicalRange, isFalse, reason: tier);
    }
  });

  test('commercial places keep their badge', () {
    expect(_place('restaurant', 'fair').showsPriceTier, isTrue);
    expect(_place('restaurant', 'fair').isAboveTypicalRange, isFalse);
    expect(_place('hotel', 'caution').isAboveTypicalRange, isTrue);
    expect(_place('shopping', 'high').isAboveTypicalRange, isTrue);
  });

  test('an unknown tier string is never read as above typical range', () {
    // Before 2026-09-13 anything other than "fair" drew the orange badge.
    for (final tier in ['none', 'n/a', 'free', 'FAIR']) {
      expect(_place('restaurant', tier).isAboveTypicalRange, isFalse,
          reason: tier);
    }
  });

  test('fromFirestore no longer invents "fair" for a missing field', () {
    final src =
        File('lib/core/models/partner_location.dart').readAsStringSync();
    expect(src, contains("d['price_tier'] ?? ''"));
  });

  test('no screen compares priceTier directly', () {
    for (final path in [
      'lib/features/map/screens/map_screen.dart',
      'lib/features/radar/widgets/radar_cards.dart',
    ]) {
      expect(File(path).readAsStringSync(), isNot(contains('priceTier')),
          reason: '$path should use showsPriceTier / isAboveTypicalRange');
    }
  });
}
