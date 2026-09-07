import 'package:flutter_test/flutter_test.dart';
import 'package:thaishield_ai/core/models/price_standard.dart';

/// `PriceStandard.localizedName` — the dish name on the Scanner result card
/// and in the price list.
///
/// Until 2026-09-06 it returned the raw field for the language, blank or not,
/// because all six names were required in the CMS and a person typed each one.
/// The CMS's auto-translate button changes the second half of that: a name can
/// now be machine translated and flagged `mt_pending`, and such a name must not
/// be shown until a person has read it. English is the fallback, as for zones.
void main() {
  PriceStandard dish({List<String> pending = const []}) => PriceStandard(
        id: 'pad_thai',
        nameEn: 'Pad Thai',
        nameTh: 'ผัดไทย',
        nameZh: '泰式炒河粉',
        nameKo: '팟타이',
        nameRu: 'Пад Тай',
        nameJa: 'パッタイ',
        minPrice: 40,
        maxPrice: 80,
        category: 'food',
        updatedAt: DateTime(2026, 9, 6),
        mtPending: pending,
      );

  test('each language gets its own reviewed name', () {
    final d = dish();
    expect(d.localizedName('th'), 'ผัดไทย');
    expect(d.localizedName('zh'), '泰式炒河粉');
    expect(d.localizedName('ko'), '팟타이');
    expect(d.localizedName('ru'), 'Пад Тай');
    expect(d.localizedName('ja'), 'パッタイ');
    expect(d.localizedName('en'), 'Pad Thai');
  });

  test('a machine translation pending review falls back to English', () {
    final d = dish(pending: const ['name_ko', 'name_ru']);
    expect(d.localizedName('ko'), 'Pad Thai');
    expect(d.localizedName('ru'), 'Pad Thai');
    // Unaffected languages keep their own text.
    expect(d.localizedName('ja'), 'パッタイ');
  });

  test('a blank or unknown language falls back to English, never to ""', () {
    final blankKo = PriceStandard(
      id: 'x',
      nameEn: 'Khao Soi',
      nameTh: 'ข้าวซอย',
      nameZh: '',
      nameKo: '   ',
      nameRu: '',
      nameJa: '',
      minPrice: 1,
      maxPrice: 2,
      category: 'food',
      updatedAt: DateTime(2026, 9, 6),
    );
    expect(blankKo.localizedName('ko'), 'Khao Soi');
    expect(blankKo.localizedName('zh'), 'Khao Soi');
    expect(blankKo.localizedName('de'), 'Khao Soi');
  });
}
