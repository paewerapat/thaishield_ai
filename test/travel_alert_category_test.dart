// Regression tests for INTEGRATION_TEST.md §F7 — a headline that uses a
// disaster word figuratively must not be badged as that disaster.
//
// Pure Dart: TravelAlert.category reads only title/description, so no
// Firebase, no plugins, no device.

import 'package:flutter_test/flutter_test.dart';
import 'package:thaishield_ai/features/home/models/travel_alert.dart';

TravelAlert _alert(String title, [String description = '']) => TravelAlert(
      title: title,
      description: description,
      url: 'https://example.com/a',
      imageUrl: null,
      sourceName: 'Example',
      publishedAt: DateTime(2026, 8, 16),
    );

void main() {
  group('TravelAlert.category — real events', () {
    test('classifies each disruption type', () {
      expect(_alert('Flash flood hits Bangkok').category, AlertCategory.flood);
      expect(_alert('Fire guts Chatuchak market').category, AlertCategory.fire);
      expect(_alert('Tropical storm nears Phuket').category, AlertCategory.storm);
      expect(_alert('Earthquake felt in Chiang Mai').category,
          AlertCategory.earthquake);
      expect(_alert('Bus crash on Rama IV').category, AlertCategory.accident);
    });

    test('reads the description when the title is vague', () {
      expect(
        _alert('Travel disruption', 'A wildfire has closed the highway').category,
        AlertCategory.fire,
      );
    });

    test('falls back to other for an unrecognised event', () {
      expect(_alert('Power outage in Sukhumvit').category, AlertCategory.other);
    });
  });

  group('TravelAlert.category — figurative usage (F7)', () {
    test('"under fire" is not a fire', () {
      // The exact headline that shipped a red ไฟไหม้ badge to the Home tab.
      final alert = _alert(
        "Thai darling and Blackpink's Lisa under fire for allegedly "
        'prioritising rumoured boyfriend over an event',
      );
      expect(alert.category, AlertCategory.other);
    });

    test('other non-event idioms do not raise a hazard category', () {
      expect(_alert('Minister fires back at critics').category,
          AlertCategory.other);
      expect(_alert('Album takes the internet by storm').category,
          AlertCategory.other);
      expect(_alert('Post drew a flood of comments').category,
          AlertCategory.other);
      expect(_alert('Signed up for a crash course in Thai').category,
          AlertCategory.other);
    });
  });

  group('TravelAlert.category — word boundaries (F7)', () {
    test('does not match a disaster word inside a longer word', () {
      expect(_alert('Firearm seized at Don Mueang').category,
          AlertCategory.other);
      expect(_alert('Misfire in the coalition talks').category,
          AlertCategory.other);
      expect(_alert('Quaker meeting house opens').category, AlertCategory.other);
    });

    test('still matches plurals and inflections that are real events', () {
      expect(_alert('Floods close three provinces').category,
          AlertCategory.flood);
      expect(_alert('Wildfires spread near the border').category,
          AlertCategory.fire);
      expect(_alert('Storms delay flights').category, AlertCategory.storm);
    });
  });
}
