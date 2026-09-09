import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Map search field must stand alone — no hardcoded location shortcuts.
///
/// The row under the search field used to hold five chips written into the
/// source: Bangkok, Sukhumvit, Phuket Airport, Chiang Mai, Pattaya. The client
/// asked for them gone on 2026-09-09. They were never data: a tourist in Krabi
/// or Hua Hin saw five places they were not in, and tapping one moved the map
/// away from wherever they actually stood.
///
/// This reads the source rather than pumping the widget, the same approach as
/// `home_travel_news_test.dart`: a widget test that finds no "Bangkok" text
/// would also pass if the row were built and merely rendered off screen.
void main() {
  final source =
      File('lib/features/map/screens/map_screen.dart').readAsStringSync();

  group('Map search has no hardcoded place shortcuts', () {
    test('the chip row and its list are gone', () {
      expect(source, isNot(contains('_mapSearchSuggestions')));
      expect(source, isNot(contains('_SuggestionChip')));
      expect(source, isNot(contains('onSuggestionTap')));
    });

    test('no place name is written into the search bar', () {
      for (final place in const [
        "'Sukhumvit'",
        "'Phuket Airport'",
        "'Chiang Mai'",
        "'Pattaya'",
      ]) {
        expect(source, isNot(contains(place)),
            reason: '$place is back in the Map screen.');
      }
    });

    test('the map still opens on a fallback centre', () {
      // `_bangkok` is not a shortcut — it is where the camera sits until the
      // device gives up a location, so removing the chips must not take it.
      expect(source, contains('const _bangkok = LatLng(13.7563, 100.5018);'));
    });
  });
}
