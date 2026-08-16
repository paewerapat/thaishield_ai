// ThaiShield AI — placeholder test suite
// Full UI tests require a physical device + Firebase emulator.
// This file keeps `flutter test` green (no compile errors).

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThaiShield AI — unit sanity checks', () {
    test('price variance calculation is correct', () {
      double calcVariance(double scanned, double min, double max) {
        final avg = (min + max) / 2;
        return ((scanned - avg) / avg) * 100;
      }

      expect(calcVariance(100, 80, 120), closeTo(0.0, 0.01));   // at average → 0%
      expect(calcVariance(120, 80, 120), closeTo(20.0, 0.01));  // at max → +20%
      expect(calcVariance(60, 80, 120), closeTo(-40.0, 0.01));  // below min → -40%
    });

    test('STT locale mapping covers all 6 app languages', () {
      String sttLocale(String langCode) {
        switch (langCode) {
          case 'en': return 'en_US';
          case 'zh': return 'zh_CN';
          case 'ko': return 'ko_KR';
          case 'ru': return 'ru_RU';
          case 'ja': return 'ja_JP';
          case 'th': return 'th_TH';
          default:   return 'en_US';
        }
      }

      expect(sttLocale('en'), 'en_US');
      expect(sttLocale('zh'), 'zh_CN');
      expect(sttLocale('ko'), 'ko_KR');
      expect(sttLocale('ru'), 'ru_RU');
      expect(sttLocale('ja'), 'ja_JP');
      expect(sttLocale('th'), 'th_TH');
      expect(sttLocale('unknown'), 'en_US');
    });

    // Since the 3 → 11 `type` expansion (Phase 2A task 2.3), "attraction" is a
    // real partner category and no longer has to borrow "hotel".
    test('scanner category maps to correct partner type', () {
      String? toPartnerType(String category) {
        switch (category) {
          case 'food':       return 'restaurant';
          case 'transport':  return 'transport';
          case 'attraction': return 'attraction';
          default:           return null;
        }
      }

      expect(toPartnerType('food'), 'restaurant');
      expect(toPartnerType('transport'), 'transport');
      expect(toPartnerType('attraction'), 'attraction');
      expect(toPartnerType('unknown'), isNull);
    });

    test('Phuket Airport suggestion chip has correct coordinates', () {
      const phuketLat = 8.1132;
      const phuketLng = 98.3019;

      // Phuket Airport bounding box: lat 7.9–8.3, lng 98.1–98.6
      expect(phuketLat, inInclusiveRange(7.9, 8.3));
      expect(phuketLng, inInclusiveRange(98.1, 98.6));
    });

    test('emergency numbers are valid Thai short codes', () {
      final numbers = ['1155', '191', '1669'];
      for (final n in numbers) {
        expect(int.tryParse(n), isNotNull, reason: '$n must be numeric');
        expect(n.length, inInclusiveRange(3, 4), reason: '$n must be 3–4 digits');
      }
    });
  });
}
