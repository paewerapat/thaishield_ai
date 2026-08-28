// Phase 2B task 2.4 — Route Suggestion unit tests.
//
// Same rule as `radar_test.dart`: everything here is pure Dart with no
// network, no plugin and no device, which is why the wire format, the deep
// link and the duration rounding all live outside the widgets.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thaishield_ai/core/localization/app_text.dart';
import 'package:thaishield_ai/core/utils/geo_utils.dart';
import 'package:thaishield_ai/core/utils/polyline.dart';
import 'package:thaishield_ai/features/route/models/route_suggestion.dart';
import 'package:thaishield_ai/features/route/models/travel_mode.dart';
import 'package:thaishield_ai/features/route/services/maps_deep_link.dart';
import 'package:thaishield_ai/features/route/services/route_service.dart';

const _languages = ['th', 'en', 'zh', 'ko', 'ru', 'ja'];

/// The encoder half of the polyline algorithm, written here so the decoder can
/// be round-tripped against Bangkok-scale coordinates rather than only against
/// the coarse coordinates in Google's documentation sample. Nothing in the app
/// encodes polylines, so this belongs in the test rather than in `lib/`.
String _encodePolyline(List<LatLng> points) {
  final buffer = StringBuffer();
  var prevLat = 0;
  var prevLng = 0;

  for (final point in points) {
    final lat = (point.latitude * 1e5).round();
    final lng = (point.longitude * 1e5).round();
    _encodeValue(buffer, lat - prevLat);
    _encodeValue(buffer, lng - prevLng);
    prevLat = lat;
    prevLng = lng;
  }
  return buffer.toString();
}

void _encodeValue(StringBuffer buffer, int value) {
  var v = value < 0 ? ~(value << 1) : (value << 1);
  while (v >= 0x20) {
    buffer.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  buffer.writeCharCode(v + 63);
}

/// Every string this feature adds. Kept explicit rather than derived from a
/// prefix so a key deleted by accident fails the test instead of silently
/// shrinking the list.
const _routeKeys = [
  'route_title',
  'route_subtitle',
  'route_to',
  'route_from_your_location',
  'route_mode_drive',
  'route_mode_transit',
  'route_mode_walk',
  'route_locating',
  'route_calculating',
  'route_estimated_time',
  'route_distance',
  'route_duration_hm',
  'route_duration_m',
  'route_open_in_maps',
  'route_open_failed',
  'route_directions_button',
  'route_location_denied',
  'route_error_not_configured',
  'route_error_no_route',
  'route_error_network',
  'route_error_request',
  'route_disclaimer',
];

void main() {
  group('decodePolyline', () {
    test('decodes the example from Google documentation', () {
      // The sample published with the algorithm: three points across
      // California, chosen there because the deltas are large enough that a
      // chunking mistake shows up immediately.
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

      expect(points.length, 3);
      expect(points[0].latitude, closeTo(38.5, 0.00001));
      expect(points[0].longitude, closeTo(-120.2, 0.00001));
      expect(points[1].latitude, closeTo(40.7, 0.00001));
      expect(points[1].longitude, closeTo(-120.95, 0.00001));
      expect(points[2].latitude, closeTo(43.252, 0.00001));
      expect(points[2].longitude, closeTo(-126.453, 0.00001));
    });

    test('round-trips Bangkok-scale coordinates', () {
      // Silom to Sathorn: positive latitudes, positive longitudes and deltas
      // of a few hundred metres. These are the magnitudes the app actually
      // decodes, and a sign-bit slip that the California sample survives shows
      // up here as a point on the wrong side of the city.
      const original = [
        LatLng(13.72440, 100.52780),
        LatLng(13.72610, 100.53120),
        LatLng(13.72855, 100.53401),
        LatLng(13.71990, 100.52200),
      ];

      final decoded = decodePolyline(_encodePolyline(original));

      expect(decoded.length, original.length);
      for (var i = 0; i < original.length; i++) {
        // 1e-5 degrees is the precision the format itself carries.
        expect(decoded[i].latitude, closeTo(original[i].latitude, 0.00001));
        expect(decoded[i].longitude, closeTo(original[i].longitude, 0.00001));
      }
      expect(distanceKm(decoded.first, decoded[1]), lessThan(1));
    });

    test('empty input yields no points', () {
      expect(decodePolyline(''), isEmpty);
    });

    test('truncated input keeps what decoded cleanly instead of throwing', () {
      final full = decodePolyline('_p~iF~ps|U_ulLnnqC');
      expect(full.length, 2);

      // Chop the last chunk mid-value: the first point still stands.
      final truncated = decodePolyline('_p~iF~ps|U_ulL');
      expect(truncated.length, 1);
      expect(truncated.first.latitude, closeTo(38.5, 0.00001));
    });

    test('junk input does not throw', () {
      expect(() => decodePolyline('!!!'), returnsNormally);
      expect(() => decodePolyline('~~~~~~~~~~~~~~~~'), returnsNormally);
    });
  });

  group('boundsFor', () {
    test('covers every point', () {
      final bounds = boundsFor(const [
        LatLng(13.72, 100.52),
        LatLng(13.75, 100.56),
        LatLng(13.70, 100.50),
      ])!;

      expect(bounds.southwest.latitude, lessThan(13.70));
      expect(bounds.southwest.longitude, lessThan(100.50));
      expect(bounds.northeast.latitude, greaterThan(13.75));
      expect(bounds.northeast.longitude, greaterThan(100.56));
    });

    test('a single point still yields a non-degenerate box', () {
      // `GoogleMap` rejects bounds whose corners coincide, which is exactly
      // what a zero-length route would produce without the padding.
      final bounds = boundsFor(const [LatLng(13.72, 100.52)])!;
      expect(bounds.southwest.latitude, lessThan(bounds.northeast.latitude));
      expect(bounds.southwest.longitude, lessThan(bounds.northeast.longitude));
    });

    test('returns null for an empty route', () {
      expect(boundsFor(const []), isNull);
    });
  });

  group('parseProtobufDuration', () {
    test('reads whole and fractional seconds', () {
      expect(parseProtobufDuration('1234s'), const Duration(seconds: 1234));
      expect(parseProtobufDuration('1234.5s'), const Duration(seconds: 1235));
      expect(parseProtobufDuration('0s'), Duration.zero);
    });

    test('rejects anything that is not the protobuf shape', () {
      // A format change must surface as "no route", never as a wrong ETA.
      expect(parseProtobufDuration('1234'), isNull);
      expect(parseProtobufDuration(1234), isNull);
      expect(parseProtobufDuration(null), isNull);
      expect(parseProtobufDuration('abcs'), isNull);
      expect(parseProtobufDuration('-60s'), isNull);
    });
  });

  group('routeFromRoutesApiResponse', () {
    Map<String, dynamic> body({
      Object? distance = 4200,
      Object? duration = '900s',
      String? polyline = '_p~iF~ps|U_ulLnnqC',
    }) {
      return {
        'routes': [
          {
            'distanceMeters': ?distance,
            'duration': ?duration,
            if (polyline != null)
              'polyline': {'encodedPolyline': polyline},
          },
        ],
      };
    }

    test('parses a normal response', () {
      final route = routeFromRoutesApiResponse(body(), TravelMode.drive)!;

      expect(route.mode, TravelMode.drive);
      expect(route.distanceMeters, 4200);
      expect(route.distanceKm, closeTo(4.2, 0.001));
      expect(route.duration, const Duration(minutes: 15));
      expect(route.points.length, 2);
    });

    test('an empty routes array means no route', () {
      expect(
        routeFromRoutesApiResponse({'routes': []}, TravelMode.transit),
        isNull,
      );
      expect(
        routeFromRoutesApiResponse(const {}, TravelMode.transit),
        isNull,
      );
    });

    test('a missing distance or duration is a parse failure', () {
      expect(
        routeFromRoutesApiResponse(body(distance: null), TravelMode.drive),
        isNull,
      );
      expect(
        routeFromRoutesApiResponse(body(duration: null), TravelMode.drive),
        isNull,
      );
    });

    test('a route without geometry still parses', () {
      // Some transit legs come back with no polyline; the summary is still
      // worth showing, so this is not a failure.
      final route =
          routeFromRoutesApiResponse(body(polyline: null), TravelMode.transit)!;
      expect(route.points, isEmpty);
      expect(route.distanceMeters, 4200);
    });
  });

  group('routeDurationParts', () {
    test('under an hour uses the minutes-only string', () {
      final parts = routeDurationParts(const Duration(minutes: 23));
      expect(parts.key, 'route_duration_m');
      expect(parts.minutes, 23);
    });

    test('an hour or more splits into hours and minutes', () {
      final parts = routeDurationParts(const Duration(minutes: 95));
      expect(parts.key, 'route_duration_hm');
      expect(parts.hours, 1);
      expect(parts.minutes, 35);
    });

    test('exactly one hour reads as 1 hr 0 min, not 60 min', () {
      final parts = routeDurationParts(const Duration(minutes: 60));
      expect(parts.key, 'route_duration_hm');
      expect(parts.hours, 1);
      expect(parts.minutes, 0);
    });

    test('a sub-minute route never reads as 0 min', () {
      final parts = routeDurationParts(const Duration(seconds: 12));
      expect(parts.key, 'route_duration_m');
      expect(parts.minutes, 1);
    });
  });

  group('googleMapsDirectionsUrl', () {
    const origin = LatLng(13.7244, 100.5278);
    const destination = LatLng(13.7460, 100.5340);

    test('builds the universal directions URL', () {
      final url = googleMapsDirectionsUrl(
        origin: origin,
        destination: destination,
        mode: TravelMode.drive,
      );

      expect(url.scheme, 'https');
      expect(url.host, 'www.google.com');
      expect(url.path, '/maps/dir/');
      expect(url.queryParameters['api'], '1');
      expect(url.queryParameters['origin'], '13.7244,100.5278');
      expect(url.queryParameters['destination'], '13.746,100.534');
      expect(url.queryParameters['travelmode'], 'driving');
    });

    test('every travel mode maps to a value the deep link accepts', () {
      // Google Maps silently falls back to driving for an unknown travelmode,
      // so a typo here would show the user a different route from the preview
      // with no error anywhere.
      const accepted = {'driving', 'walking', 'transit', 'bicycling'};
      for (final mode in TravelMode.values) {
        expect(
          accepted,
          contains(mode.deepLinkValue),
          reason: '${mode.name} has no Google Maps travelmode',
        );
      }
    });
  });

  group('TravelMode', () {
    test('only road vehicles carry a routing preference', () {
      // The Routes API rejects `routingPreference` on WALK and TRANSIT with
      // HTTP 400 rather than ignoring it.
      expect(TravelMode.drive.supportsTrafficAwareRouting, isTrue);
      expect(TravelMode.walk.supportsTrafficAwareRouting, isFalse);
      expect(TravelMode.transit.supportsTrafficAwareRouting, isFalse);
    });

    test('API values match the Routes API enum', () {
      expect(TravelMode.drive.apiValue, 'DRIVE');
      expect(TravelMode.walk.apiValue, 'WALK');
      expect(TravelMode.transit.apiValue, 'TRANSIT');
    });
  });

  group('RouteService configuration', () {
    test('needs no build-time key now that the call is proxied', () {
      // Until 2026-08-29 this asserted the opposite: without
      // --dart-define=ROUTES_API_KEY the service reported itself unconfigured,
      // because the key travelled in the APK. The key is a Functions secret
      // now, so a build carries nothing that can be missing — and `flutter
      // test`, which passes no defines, is exactly the build that proves it.
      expect(RouteService.instance.isConfigured, isTrue);
    });
  });

  group('route copy', () {
    test('every route string exists in all six languages', () {
      for (final key in _routeKeys) {
        final entry = appStrings[key];
        expect(entry, isNotNull, reason: 'missing key: $key');
        for (final language in _languages) {
          expect(
            entry![language],
            isNotNull,
            reason: 'missing $language for $key',
          );
          expect(
            entry[language]!.trim(),
            isNotEmpty,
            reason: 'empty $language for $key',
          );
        }
      }
    });

    test('placeholders survive translation', () {
      for (final language in _languages) {
        expect(appStrings['route_to']![language], contains('{name}'));
        expect(appStrings['route_duration_m']![language], contains('{m}'));
        expect(appStrings['route_duration_hm']![language], contains('{h}'));
        expect(appStrings['route_duration_hm']![language], contains('{m}'));
      }
    });

    test('English copy obeys the §10 wording rules', () {
      // A route screen is where "safe route" / "avoid this area" is most
      // tempting to write, and both are exactly the judgement §10 forbids.
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
        'safe route',
        'safest',
      ];

      for (final key in _routeKeys) {
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

    test('the disclaimer states the numbers are estimates', () {
      // §10 requires a disclaimer wherever the app shows derived figures;
      // here the figures are the ETA and the distance.
      final english = appStrings['route_disclaimer']!['en']!.toLowerCase();
      expect(english, contains('estimate'));
      expect(english, contains('informational purposes only'));
    });
  });
}
