import 'package:flutter_test/flutter_test.dart';
import 'package:thaishield_ai/core/models/alert_zone.dart';

/// The English fallback that the whole four-languages-optional decision rests
/// on.
///
/// 🚨 On 2026-09-02 the client agreed to make zh/ko/ru/ja optional in the CMS
/// **on the strength of this method** — the argument was "a blank column is
/// safe, because the reader gets the English a staff member actually wrote".
/// Nothing tested that. The method was correct, but a refactor could have
/// turned every unfilled advisory into an empty card on the one screen that
/// describes a real place, and the suite would have stayed green.
///
/// Written after the QA gate found the sibling failure: a caller passing
/// `isTh ? 'th' : 'en'` so four of the six languages never reached this method
/// at all. `localized_text_call_sites_test.dart` guards the callers; this
/// guards what they call.
void main() {
  AlertZone zone({
    String zh = '',
    String ko = '',
    String ru = '',
    String ja = '',
    String th = 'ราคาบริเวณนี้แตกต่างจากค่าเฉลี่ย',
    String en = 'Prices here vary more than the city average.',
  }) {
    return AlertZone(
      id: 'z',
      name: 'Test Area',
      centerLat: 13.75,
      centerLng: 100.5,
      radiusKm: 1,
      riskLevel: 'caution',
      descriptionEn: en,
      descriptionTh: th,
      descriptionZh: zh,
      descriptionKo: ko,
      descriptionRu: ru,
      descriptionJa: ja,
    );
  }

  group('a filled translation is used', () {
    test('each of the six languages gets its own text', () {
      final full = zone(zh: '中文', ko: '한국어', ru: 'Русский', ja: '日本語');
      expect(full.localizedDescription('th'), 'ราคาบริเวณนี้แตกต่างจากค่าเฉลี่ย');
      expect(full.localizedDescription('en'), startsWith('Prices here'));
      expect(full.localizedDescription('zh'), '中文');
      expect(full.localizedDescription('ko'), '한국어');
      expect(full.localizedDescription('ru'), 'Русский');
      expect(full.localizedDescription('ja'), '日本語');
    });
  });

  group('a blank translation falls back to English', () {
    test('every optional language falls back, and none is left empty', () {
      // The state of 192 of the 193 live zones.
      final bare = zone();
      for (final lang in ['zh', 'ko', 'ru', 'ja']) {
        expect(bare.localizedDescription(lang), startsWith('Prices here'),
            reason: 'a $lang reader must see the English advisory, never a '
                'blank card');
      }
    });

    test('whitespace counts as blank, not as a translation', () {
      // A translator who leaves a space behind should not silently blank the
      // advisory for that language.
      expect(zone(ko: '   ').localizedDescription('ko'), startsWith('Prices here'));
    });

    test('it falls back to English, NOT to Thai', () {
      // 🚨 Deliberate. Thai is required and would always be available, so
      // falling back to it would be easy — and would show Thai script to a
      // Russian tourist, which is less useful than English and reads as a bug.
      expect(zone().localizedDescription('ru'), isNot(contains('ราคา')));
    });

    test('an unknown language code still gets English, never an empty string',
        () {
      // The app ships six locales, but a device or a future build can hand in
      // anything. Whatever arrives, an advisory must appear.
      for (final lang in ['de', 'fr', '', 'zz']) {
        expect(zone().localizedDescription(lang), startsWith('Prices here'),
            reason: 'language "$lang" produced no advisory at all');
      }
    });
  });

  group('names fall back differently, and that is intended', () {
    test('a missing official name falls back to the canonical name', () {
      // Not to English: a place name usually has no translation, and `name`
      // carries the real one. This is why the two methods do not share code.
      final z = zone();
      expect(z.localizedName('ko'), 'Test Area');
      expect(z.localizedName('th'), 'Test Area');
    });
  });
}
