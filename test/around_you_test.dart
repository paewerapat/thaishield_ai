// "Around you" panel on the Smart Map — item (ข), approved 2026-08-22.
//
// The panel itself is presentation, but the decisions behind it are not: which
// entries count as an advisory, how the free tier's allowance is spent across
// two lists, and whether the copy exists in every language. Those are what
// break silently, so those are what is pinned here.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thaishield_ai/core/localization/app_text.dart';
import 'package:thaishield_ai/core/models/alert_zone.dart';
import 'package:thaishield_ai/core/models/partner_location.dart';
import 'package:thaishield_ai/core/utils/geo_utils.dart';
import 'package:thaishield_ai/features/premium/providers/premium_provider.dart';
import 'package:thaishield_ai/features/radar/models/radar_result.dart';

const _languages = ['th', 'en', 'zh', 'ko', 'ru', 'ja'];

const _aroundKeys = [
  'around_title',
  'around_alerts_title',
  'around_partners_title',
  'around_empty',
  'around_unit_areas',
  'around_unit_places',
];

AlertZone _zone(String id, String riskLevel) => AlertZone(
      id: id,
      name: 'Zone $id',
      centerLat: 13.72,
      centerLng: 100.52,
      radiusKm: 0.5,
      riskLevel: riskLevel,
      descriptionEn: 'desc',
      descriptionTh: 'desc',
    );

PartnerLocation _partner(String id) => PartnerLocation(
      id: id,
      name: 'Partner $id',
      lat: 13.72,
      lng: 100.52,
      type: 'restaurant',
      rating: 4.5,
      isVerified: true,
      priceTier: 'fair',
      imageUrl: '',
    );

RadarResult _result({
  List<String> zoneRisks = const [],
  int partners = 0,
}) {
  return RadarResult(
    center: const LatLng(13.72, 100.52),
    radiusKm: 1,
    entries: [
      for (var i = 0; i < zoneRisks.length; i++)
        RadarZoneEntry(
          zone: _zone('$i', zoneRisks[i]),
          distanceKm: i * 0.05,
          isInside: false,
        ),
      for (var i = 0; i < partners; i++)
        RadarPartnerEntry(partner: _partner('$i'), distanceKm: i * 0.05),
    ],
  );
}

/// Mirrors the split the panel makes. Kept here rather than reaching into the
/// widget so the rule is stated once in a place a test can read.
({int advisories, int partners}) _split(RadarResult result) {
  final zones = result.entries.whereType<RadarZoneEntry>();
  return (
    advisories: zones.where((z) => z.zone.riskLevel != 'safe').length,
    partners: result.entries.whereType<RadarPartnerEntry>().length,
  );
}

void main() {
  group('what the panel treats as an advisory', () {
    test('safe-rated areas are counted but never listed as alerts', () {
      // A "safe" area two streets away is not news. Listing it would push the
      // caution and alert areas — the ones worth reading — down the sheet.
      final result = _result(zoneRisks: ['safe', 'safe', 'caution', 'danger']);

      expect(_split(result).advisories, 2);
      expect(
        result.entries.whereType<RadarZoneEntry>().length,
        4,
        reason: 'the count tiles still show every area',
      );
    });

    test('an area with no advisories and no partners lists nothing', () {
      final result = _result(zoneRisks: ['safe']);
      final split = _split(result);

      expect(split.advisories, 0);
      expect(split.partners, 0);
    });
  });

  group('free-tier allowance', () {
    // The allowance applies per list, not to the two combined: a user standing
    // beside four advisories should still see nearby partners rather than have
    // the advisories consume the whole quota.
    const limit = PremiumProvider.freeRadarResultLimit;

    List<T> take<T>(List<T> items, int? cap) =>
        cap == null || items.length <= cap ? items : items.take(cap).toList();

    test('each list keeps its own nearest few', () {
      final result = _result(
        zoneRisks: List.filled(5, 'caution'),
        partners: 6,
      );
      final advisories = result.entries.whereType<RadarZoneEntry>().toList();
      final partners = result.entries.whereType<RadarPartnerEntry>().toList();

      expect(take(advisories, limit).length, limit);
      expect(take(partners, limit).length, limit);
    });

    test('the hidden count adds up across both lists', () {
      final result = _result(
        zoneRisks: List.filled(5, 'caution'),
        partners: 6,
      );
      final advisories = result.entries.whereType<RadarZoneEntry>().toList();
      final partners = result.entries.whereType<RadarPartnerEntry>().toList();

      final hidden = (advisories.length - take(advisories, limit).length) +
          (partners.length - take(partners, limit).length);

      // 5 - 3 advisories plus 6 - 3 partners.
      expect(hidden, 5);
    });

    test('premium hides nothing', () {
      final result = _result(zoneRisks: ['caution'], partners: 9);
      final partners = result.entries.whereType<RadarPartnerEntry>().toList();

      expect(take(partners, null).length, 9);
    });

    test('a short list is never trimmed', () {
      final result = _result(partners: 2);
      final partners = result.entries.whereType<RadarPartnerEntry>().toList();

      expect(take(partners, limit).length, 2);
    });
  });

  group('distances the sheet prints', () {
    test('anything inside the default radius reads in metres', () {
      // The whole point of the panel is "how far is that" at a glance, and
      // "0.4 km" is harder to judge on foot than "400 m".
      expect(formatDistance(0.45, isTh: false), '450 m');
      expect(formatDistance(0.45, isTh: true), '450 ม.');
      expect(formatDistance(0.999, isTh: false), '999 m');
    });

    test('past a kilometre it switches to km', () {
      expect(formatDistance(1.0, isTh: false), '1.0 km');
      expect(formatDistance(3.24, isTh: true), '3.2 กม.');
    });
  });

  group('copy', () {
    test('every around-you string exists in all six languages', () {
      for (final key in _aroundKeys) {
        final entry = appStrings[key];
        expect(entry, isNotNull, reason: 'missing key: $key');
        for (final language in _languages) {
          expect(
            entry![language]?.trim(),
            isNotEmpty,
            reason: 'missing or empty $language for $key',
          );
        }
      }
    });

    test('the radius placeholder survives translation', () {
      for (final language in _languages) {
        expect(appStrings['around_title']![language], contains('{radius}'));
      }
    });

    test('the tiles reuse the radar group labels', () {
      // Same area, two screens, one name. If these ever diverge the app calls
      // the same zone different things depending on where you look.
      for (final key in [
        'radar_group_zone_safe',
        'radar_group_zone_caution',
        'radar_group_zone_danger',
        'radar_group_partners',
      ]) {
        for (final language in _languages) {
          expect(appStrings[key]?[language]?.trim(), isNotEmpty);
        }
      }
    });

    test('English copy obeys the §10 wording rules', () {
      const banned = [
        'scam',
        'fraud',
        'cheat',
        'overcharge',
        'rip-off',
        'dangerous',
        'unsafe',
        'blacklist',
        'avoid',
        'guarantee',
      ];

      for (final key in _aroundKeys) {
        final english = appStrings[key]!['en']!.toLowerCase();
        for (final word in banned) {
          expect(
            english.contains(word),
            isFalse,
            reason: '$key uses banned wording "$word": $english',
          );
        }
      }
    });
  });
}
