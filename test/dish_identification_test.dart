import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thaishield_ai/core/localization/app_text.dart';
import 'package:thaishield_ai/features/scanner/models/scan_result.dart';
import 'package:thaishield_ai/features/scanner/services/gemini_vision_service.dart';

/// Wraps a vision payload the way the Gemini API returns it.
Map<String, dynamic> geminiEnvelope(Map<String, dynamic> payload) {
  return {
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': jsonEncode(payload)},
          ],
        },
      },
    ],
  };
}

void main() {
  group('identificationFromGeminiResponse', () {
    test('a dish we carry comes back as a known dish, with no estimate', () {
      final result = identificationFromGeminiResponse(
        geminiEnvelope({'dish_name': 'Pad Thai', 'confidence': 'high'}),
      );

      expect(result, isNotNull);
      expect(result!.isKnownDish, isTrue);
      expect(result.knownDishName, 'Pad Thai');
      expect(result.hasUsableEstimate, isFalse);
    });

    test('a dish we do not carry comes back as a usable estimate', () {
      final result = identificationFromGeminiResponse(
        geminiEnvelope({
          'dish_name': 'UNKNOWN',
          'generic_name_en': 'Khao Soi',
          'generic_name_th': 'ข้าวซอย',
          'estimated_min_thb': 50,
          'estimated_max_thb': 120,
          'confidence': 'high',
        }),
      );

      expect(result, isNotNull);
      expect(result!.isKnownDish, isFalse);
      expect(result.hasUsableEstimate, isTrue);
      expect(result.genericNameEn, 'Khao Soi');
      expect(result.estimatedMin, 50);
      expect(result.estimatedMax, 120);
    });

    test('a low-confidence guess is never shown as a price', () {
      // A number a tourist might repeat to a vendor is worse than no number.
      final result = identificationFromGeminiResponse(
        geminiEnvelope({
          'dish_name': 'UNKNOWN',
          'generic_name_en': 'Some noodle dish',
          'estimated_min_thb': 40,
          'estimated_max_thb': 90,
          'confidence': 'low',
        }),
      );

      expect(result!.hasUsableEstimate, isFalse);
    });

    test('nonsense numbers are rejected rather than rendered', () {
      final inverted = identificationFromGeminiResponse(
        geminiEnvelope({
          'dish_name': 'UNKNOWN',
          'generic_name_en': 'Mango Sticky Rice',
          'estimated_min_thb': 200,
          'estimated_max_thb': 60, // max below min
          'confidence': 'high',
        }),
      );
      expect(inverted!.hasUsableEstimate, isFalse);

      final zero = identificationFromGeminiResponse(
        geminiEnvelope({
          'dish_name': 'UNKNOWN',
          'generic_name_en': 'Mango Sticky Rice',
          'estimated_min_thb': 0,
          'estimated_max_thb': 0,
          'confidence': 'high',
        }),
      );
      expect(zero!.hasUsableEstimate, isFalse);
    });

    test('an unreadable photo yields neither a dish nor an estimate', () {
      final result = identificationFromGeminiResponse(
        geminiEnvelope({'dish_name': 'UNKNOWN', 'confidence': 'low'}),
      );

      expect(result!.isKnownDish, isFalse);
      expect(result.hasUsableEstimate, isFalse);
    });

    test('survives a malformed response instead of throwing', () {
      expect(identificationFromGeminiResponse(<String, dynamic>{}), isNull);
      expect(
        identificationFromGeminiResponse(<String, dynamic>{'candidates': []}),
        isNull,
      );
      expect(
        identificationFromGeminiResponse({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'not json at all'},
                ],
              },
            },
          ],
        }),
        isNull,
      );
    });
  });

  group('ScanResult.aiEstimated', () {
    test('is flagged as an estimate and carries no variance bar', () {
      final result = ScanResult.aiEstimated(
        nameEn: 'Khao Soi',
        nameTh: 'ข้าวซอย',
        minPrice: 50,
        maxPrice: 120,
      );

      expect(result.isAiEstimated, isTrue);
      // No price was read from the photo, so there is nothing to compare
      // against — §2.2 allows a variance bar only on an OCR match.
      expect(result.isReferenceOnly, isTrue);
      expect(result.detectedPrice, isNull);
      expect(result.variancePercent, isNull);
      expect(result.level, isNull);
    });

    test('never poses as a price_standards document', () {
      final result = ScanResult.aiEstimated(
        nameEn: 'Khao Soi',
        nameTh: 'ข้าวซอย',
        minPrice: 50,
        maxPrice: 120,
      );

      expect(result.standard.id, isEmpty);
    });

    test('falls back to the English name for languages the model omits', () {
      final result = ScanResult.aiEstimated(
        nameEn: 'Khao Soi',
        nameTh: '',
        minPrice: 50,
        maxPrice: 120,
      );

      expect(result.standard.localizedName('th'), 'Khao Soi');
      expect(result.standard.localizedName('ja'), 'Khao Soi');
    });
  });

  group('estimate copy', () {
    test('is translated into all six app languages', () {
      for (final key in [
        'scanner_ai_estimated',
        'scanner_estimated_range',
        'scanner_tip_estimated',
      ]) {
        for (final lang in ['th', 'en', 'zh', 'ko', 'ru', 'ja']) {
          expect(
            appStrings[key]?[lang],
            isNotNull,
            reason: '$key is missing $lang',
          );
          expect(appStrings[key]![lang], isNotEmpty, reason: '$key/$lang empty');
        }
      }
    });

    test('carries no accusatory wording (CLAUDE.md §10)', () {
      const banned = [
        'scam',
        'fraud',
        'cheat',
        'overcharge',
        'rip-off',
        'ripoff',
        'โกง',
        'หลอก',
        'ต้มตุ๋น',
      ];

      for (final key in [
        'scanner_ai_estimated',
        'scanner_estimated_range',
        'scanner_tip_estimated',
      ]) {
        for (final entry in appStrings[key]!.entries) {
          final text = entry.value.toLowerCase();
          for (final word in banned) {
            expect(
              text.contains(word),
              isFalse,
              reason: '$key/${entry.key} contains "$word"',
            );
          }
        }
      }
    });
  });
}
