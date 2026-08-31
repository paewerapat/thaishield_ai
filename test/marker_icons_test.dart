import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thaishield_ai/core/models/partner_category.dart';
import 'package:thaishield_ai/features/map/services/marker_icons.dart';

/// The map pins the design poster asks for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(MarkerIcons.instance.clearCache);

  group('MarkerIcons', () {
    test('every category rasterises', () async {
      // A category that throws would silently fall back to the stock teardrop,
      // which looks like "this pin has no icon yet" rather than like a bug.
      for (final category in PartnerCategory.values) {
        final bytes = await MarkerIcons.instance.rawBytesFor(category, 2);
        expect(bytes, isNotNull, reason: category.name);
        expect(bytes!.length, greaterThan(0), reason: category.name);
      }
    });

    test('all eleven are drawn by warmUp', () async {
      await MarkerIcons.instance.warmUp(2);
      expect(MarkerIcons.instance.cachedCount, PartnerCategory.values.length);
    });

    test('drawing the same pin twice does not redraw it', () async {
      await MarkerIcons.instance.forCategory(PartnerCategory.restaurant, 2);
      expect(MarkerIcons.instance.cachedCount, 1);

      await MarkerIcons.instance.forCategory(PartnerCategory.restaurant, 2);
      expect(MarkerIcons.instance.cachedCount, 1);
    });

    test('a different screen density is a different bitmap', () async {
      await MarkerIcons.instance.forCategory(PartnerCategory.hotel, 2);
      await MarkerIcons.instance.forCategory(PartnerCategory.hotel, 3);
      expect(MarkerIcons.instance.cachedCount, 2);
    });

    test('the eleven pins carry eleven different symbols', () {
      // The whole point of the change: pins that were identical apart from
      // colour now carry their own symbol.
      //
      // 🚨 This asserts the code points, not the pixels, and that is not
      // laziness. `flutter test` stubs font rendering — every glyph rasterises
      // to the same box — so comparing two drawn bitmaps passes or fails for
      // reasons that have nothing to do with the icons. It was written that
      // way first and failed against correct code. Whether the symbols *look*
      // right is a manual check, and it is on the QA sheet.
      final codePoints = {
        for (final category in PartnerCategory.values)
          partnerCategoryIcon[category]!.codePoint,
      };

      expect(
        codePoints,
        hasLength(PartnerCategory.values.length),
        reason: 'two categories share a symbol, so their pins are identical',
      );
    });
  });

  group('the colour rule the client asked for', () {
    // 🚨 2026-08-29: every partner business is blue, so the map reads as one
    // programme instead of eleven colours to decode. Adding per-category
    // glyphs must not have quietly reintroduced per-category fills.
    const partnerBusinesses = [
      PartnerCategory.restaurant,
      PartnerCategory.hotel,
      PartnerCategory.atmBank,
      PartnerCategory.shopping,
      PartnerCategory.attraction,
      PartnerCategory.touristInfo,
    ];

    test('every partner business shares one marker hue', () {
      final hues = partnerBusinesses
          .map((c) => partnerCategoryMarkerHue[c])
          .toSet();
      expect(hues, hasLength(1), reason: 'partner pins are not one colour');
    });

    test('emergency and transport stay distinct from partners', () {
      final partner = partnerCategoryMarkerHue[PartnerCategory.restaurant];
      expect(partnerCategoryMarkerHue[PartnerCategory.hospital],
          isNot(equals(partner)));
      expect(partnerCategoryMarkerHue[PartnerCategory.transport],
          isNot(equals(partner)));
    });

    test('every category has a glyph to draw', () {
      for (final category in PartnerCategory.values) {
        expect(partnerCategoryIcon[category], isA<IconData>(),
            reason: '${category.name} has no icon');
      }
    });
  });
}
