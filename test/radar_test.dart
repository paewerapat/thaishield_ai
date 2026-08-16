// Phase 2A — Safety Radar unit tests.
//
// Everything here is pure Dart (no Firebase, no plugins, no device), which is
// the whole reason the geo maths and the category table live outside the
// widgets.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thaishield_ai/core/models/alert_zone.dart';
import 'package:thaishield_ai/core/models/partner_category.dart';
import 'package:thaishield_ai/core/utils/geo_utils.dart';
import 'package:thaishield_ai/features/radar/models/radar_filters.dart';

/// A square zone roughly 1.1 km on each side, centred on Silom.
AlertZone _squareZone({
  String riskLevel = 'caution',
  double centerLat = 13.7244,
  double centerLng = 100.5278,
  double halfSideDeg = 0.005, // ~555 m
}) {
  return AlertZone(
    id: 'zone_test',
    name: 'Test Area',
    centerLat: centerLat,
    centerLng: centerLng,
    radiusKm: 0.8,
    riskLevel: riskLevel,
    descriptionEn: '',
    descriptionTh: '',
    polygon: [
      LatLng(centerLat - halfSideDeg, centerLng - halfSideDeg),
      LatLng(centerLat - halfSideDeg, centerLng + halfSideDeg),
      LatLng(centerLat + halfSideDeg, centerLng + halfSideDeg),
      LatLng(centerLat + halfSideDeg, centerLng - halfSideDeg),
    ],
  );
}

void main() {
  group('distanceKm', () {
    test('is zero for the same point', () {
      const p = LatLng(13.7563, 100.5018);
      expect(distanceKm(p, p), closeTo(0, 0.0001));
    });

    test('one degree of latitude is about 111 km', () {
      expect(
        distanceKm(const LatLng(13.0, 100.0), const LatLng(14.0, 100.0)),
        closeTo(111.2, 0.5),
      );
    });

    test('is symmetric', () {
      const a = LatLng(13.7563, 100.5018);
      const b = LatLng(18.7883, 98.9853);
      expect(distanceKm(a, b), closeTo(distanceKm(b, a), 0.0001));
    });

    test('Bangkok to Chiang Mai is about 580 km', () {
      expect(
        distanceKm(const LatLng(13.7563, 100.5018), const LatLng(18.7883, 98.9853)),
        closeTo(580, 15),
      );
    });
  });

  group('isPointInPolygon', () {
    final zone = _squareZone();

    test('accepts a point at the centre', () {
      expect(
        isPointInPolygon(LatLng(zone.centerLat, zone.centerLng), zone.polygon),
        isTrue,
      );
    });

    test('rejects a point outside', () {
      expect(
        isPointInPolygon(
          LatLng(zone.centerLat + 0.02, zone.centerLng),
          zone.polygon,
        ),
        isFalse,
      );
    });

    test('rejects anything when the ring has fewer than 3 vertices', () {
      const p = LatLng(13.7244, 100.5278);
      expect(isPointInPolygon(p, const []), isFalse);
      expect(isPointInPolygon(p, const [p, p]), isFalse);
    });
  });

  group('isInsideZone', () {
    test('is true at the centre of a polygon zone', () {
      final zone = _squareZone();
      expect(
        isInsideZone(LatLng(zone.centerLat, zone.centerLng), zone),
        isTrue,
      );
    });

    test('is false well outside the bounding radius', () {
      final zone = _squareZone();
      expect(
        isInsideZone(LatLng(zone.centerLat + 0.2, zone.centerLng), zone),
        isFalse,
      );
    });

    test(
      'a point inside the bounding circle but outside the polygon is excluded — '
      'this is the whole point of the two-step check',
      () {
        // A wide, shallow zone: its bounding radius (~1.1 km, driven by the
        // east-west extent) reaches far north of the shape itself.
        const centerLat = 13.7244;
        const centerLng = 100.5278;
        final zone = AlertZone(
          id: 'wide_zone',
          name: 'Wide Zone',
          centerLat: centerLat,
          centerLng: centerLng,
          radiusKm: 1.1,
          riskLevel: 'caution',
          descriptionEn: '',
          descriptionTh: '',
          polygon: const [
            LatLng(centerLat - 0.002, centerLng - 0.01),
            LatLng(centerLat - 0.002, centerLng + 0.01),
            LatLng(centerLat + 0.002, centerLng + 0.01),
            LatLng(centerLat + 0.002, centerLng - 0.01),
          ],
        );

        // ~890 m due north of the centre: comfortably inside the bounding
        // circle, well outside the shape.
        const north = LatLng(centerLat + 0.008, centerLng);
        expect(
          distanceKm(north, const LatLng(centerLat, centerLng)),
          lessThan(zone.radiusKm),
          reason: 'the cheap pre-check must accept this point',
        );
        expect(isInsideZone(north, zone), isFalse);

        // ...while a point actually within the shape is still accepted.
        expect(
          isInsideZone(const LatLng(centerLat, centerLng + 0.008), zone),
          isTrue,
        );
      },
    );

    test('falls back to the radius when the zone has no usable polygon', () {
      const zone = AlertZone(
        id: 'circle_zone',
        name: 'Circle Zone',
        centerLat: 13.7244,
        centerLng: 100.5278,
        radiusKm: 1.0,
        riskLevel: 'safe',
        descriptionEn: '',
        descriptionTh: '',
      );
      expect(isInsideZone(const LatLng(13.7244, 100.5278), zone), isTrue);
      expect(isInsideZone(const LatLng(13.7444, 100.5278), zone), isFalse);
    });
  });

  group('distanceToZoneKm', () {
    test('is zero inside the zone', () {
      final zone = _squareZone();
      expect(
        distanceToZoneKm(LatLng(zone.centerLat, zone.centerLng), zone),
        0,
      );
    });

    test('measures to the nearest polygon edge, not to the centre', () {
      final zone = _squareZone();
      // Due north of the top edge, ~555 m of zone + ~555 m of gap.
      final outside = LatLng(zone.centerLat + 0.01, zone.centerLng);
      final toCentre = distanceKm(outside, LatLng(zone.centerLat, zone.centerLng));

      final toEdge = distanceToZoneKm(outside, zone);
      expect(toEdge, closeTo(0.555, 0.08));
      expect(toEdge, lessThan(toCentre));
    });

    test('grows with distance', () {
      final zone = _squareZone();
      final near = distanceToZoneKm(LatLng(zone.centerLat + 0.01, zone.centerLng), zone);
      final far = distanceToZoneKm(LatLng(zone.centerLat + 0.05, zone.centerLng), zone);
      expect(far, greaterThan(near));
    });
  });

  group('formatDistance', () {
    test('uses metres below 1 km', () {
      expect(formatDistance(0.42, isTh: false), '420 m');
      expect(formatDistance(0.42, isTh: true), '420 ม.');
    });

    test('uses one decimal kilometre above 1 km', () {
      expect(formatDistance(2.34, isTh: false), '2.3 km');
      expect(formatDistance(2.34, isTh: true), '2.3 กม.');
    });
  });

  group('PartnerCategory', () {
    test('has exactly the 11 documented values, in order', () {
      expect(
        PartnerCategory.values.map((c) => c.value).toList(),
        [
          'restaurant',
          'hotel',
          'transport',
          'hospital',
          'pharmacy',
          'police',
          'tourist_police',
          'atm_bank',
          'shopping',
          'attraction',
          'tourist_info',
        ],
        reason: 'must stay in sync with PARTNER_LOCATION_TYPES in the web-admin repo',
      );
    });

    test('round-trips every value', () {
      for (final category in PartnerCategory.values) {
        expect(PartnerCategory.fromValue(category.value), category);
      }
    });

    test('falls back to restaurant for unknown or missing values', () {
      expect(PartnerCategory.fromValue('museum'), PartnerCategory.restaurant);
      expect(PartnerCategory.fromValue(''), PartnerCategory.restaurant);
      expect(PartnerCategory.fromValue(null), PartnerCategory.restaurant);
    });

    test('groups the four emergency categories together', () {
      const emergency = {
        PartnerCategory.hospital,
        PartnerCategory.pharmacy,
        PartnerCategory.police,
        PartnerCategory.touristPolice,
      };
      for (final category in PartnerCategory.values) {
        expect(
          category.radarGroup == RadarGroup.emergencyServices,
          emergency.contains(category),
          reason: '${category.value} is in the wrong radar group',
        );
      }
      expect(
        PartnerCategory.transport.radarGroup,
        RadarGroup.transport,
      );
    });

    test('every category has an icon, a colour and a marker hue', () {
      for (final category in PartnerCategory.values) {
        expect(partnerCategoryIcon[category], isNotNull, reason: category.value);
        expect(partnerCategoryColor[category], isNotNull, reason: category.value);
        expect(partnerCategoryMarkerHue[category], isNotNull, reason: category.value);
      }
    });
  });

  group('RadarFilters', () {
    test('starts with everything selected', () {
      final filters = RadarFilters.all();
      expect(filters.isAll, isTrue);
      expect(filters.activeCount, 0);
      expect(filters.categories.length, PartnerCategory.values.length);
      expect(filters.riskLevels.length, alertZoneRiskLevels.length);
    });

    test('toggling a category switches it off and back on', () {
      final off = RadarFilters.all().toggleCategory(PartnerCategory.hotel);
      expect(off.categories.contains(PartnerCategory.hotel), isFalse);
      expect(off.isAll, isFalse);
      expect(off.activeCount, 1);

      final backOn = off.toggleCategory(PartnerCategory.hotel);
      expect(backOn.isAll, isTrue);
      expect(backOn.activeCount, 0);
    });

    test('counts category and risk-level exclusions together', () {
      final filters = RadarFilters.all()
          .toggleCategory(PartnerCategory.hotel)
          .toggleCategory(PartnerCategory.shopping)
          .toggleRiskLevel('safe');
      expect(filters.activeCount, 3);
    });

    test('none() excludes everything', () {
      final filters = RadarFilters.none();
      expect(filters.categories, isEmpty);
      expect(filters.riskLevels, isEmpty);
      expect(filters.isAll, isFalse);
    });

    test('toggling does not mutate the original', () {
      final original = RadarFilters.all();
      original.toggleCategory(PartnerCategory.hotel);
      expect(original.isAll, isTrue);
    });
  });
}
