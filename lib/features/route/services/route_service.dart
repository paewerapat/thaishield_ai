import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/utils/polyline.dart';
import '../models/route_suggestion.dart';
import '../models/travel_mode.dart';

/// Route Suggestion backend — Phase 2B task 2.4.
///
/// ## Why the Routes API and not the Directions API
///
/// The quotation says "Directions API", and that is still the right name for
/// the feature, but the legacy `maps.googleapis.com/maps/api/directions`
/// endpoint **is closed to new customers** — a Cloud project that did not
/// already have it enabled cannot turn it on. Its supported successor is the
/// Routes API (`routes.googleapis.com`, POST + `computeRoutes`), which is what
/// this calls. Same feature, same billing account, one that can actually be
/// enabled. This is the same trap §2.2 records for the Gemini 2.x models.
///
/// ## Cost
///
/// Routes bills **per request**, so every avoidable call is money. Two
/// guards:
///   * `X-Goog-FieldMask` is mandatory on this API and is kept to the three
///     fields the preview actually draws. A wider mask (or `*`) moves the call
///     into a more expensive SKU for data nothing renders.
///   * [_cacheTtl] holds each (origin, destination, mode) answer, so flipping
///     the travel-mode toggle back and forth costs one request per mode rather
///     than one per tap. Origins are rounded to ~11 m first, otherwise GPS
///     jitter alone would miss every cache hit while the user stands still.
class RouteService {
  RouteService._();
  static final instance = RouteService._();

  /// The project's own Cloud Function, not Google's endpoint directly.
  ///
  /// Routes is a web service, so no Android/iOS application restriction
  /// applies to its key — an embedded key is readable by anyone who unzips the
  /// APK, and the only guards were "restrict to Routes API" and a quota cap.
  /// Since 2026-08-29 the key lives as a Functions secret and the app holds
  /// nothing worth stealing.
  ///
  /// The `cloudfunctions.net` form is used rather than the `run.app` URL
  /// because it is derivable from region and project id, so it can be written
  /// here before the first deploy.
  ///
  /// 🚨 **This endpoint is unauthenticated.** Moving the key server-side stops
  /// it leaking; it does not stop someone who finds this URL from spending the
  /// project's Routes quota. Firebase App Check is what closes that, and it
  /// works without the accounts §7 forbids. Until then the daily quota cap is
  /// the only bound on the damage.
  static const _endpoint =
      'https://asia-southeast1-thaishield-ai-790eb.cloudfunctions.net/computeRoute';


  static const _cacheTtl = Duration(minutes: 5);
  static const _timeout = Duration(seconds: 15);

  final _cache = <String, _CacheEntry>{};

  /// True when a build actually passed `ROUTES_API_KEY`. The UI checks this
  /// before offering the entry point, so a misconfigured build shows the
  /// feature as unavailable instead of failing after the user taps.
  /// Always true since the key moved server-side: there is no longer a build
  /// flag that can be missing. A misdeployed or unreachable function now
  /// surfaces through the ordinary network-failure path instead, which the
  /// preview screen already handles with a retry.
  bool get isConfigured => true;

  static String _cacheKey(LatLng origin, LatLng destination, TravelMode mode) {
    String r(double v) => v.toStringAsFixed(4);
    return '${r(origin.latitude)},${r(origin.longitude)}'
        '|${r(destination.latitude)},${r(destination.longitude)}'
        '|${mode.apiValue}';
  }

  /// Visible for tests — drops every cached answer.
  void clearCache() => _cache.clear();

  Future<RouteOutcome> route({
    required LatLng origin,
    required LatLng destination,
    required TravelMode mode,
    String languageCode = 'en',
  }) async {
    if (!isConfigured) {
      return const RouteOutcome.failed(RouteFailure.notConfigured);
    }

    final key = _cacheKey(origin, destination, mode);
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return RouteOutcome.success(cached.route);
    }

    final body = jsonEncode({
      'origin': _waypoint(origin),
      'destination': _waypoint(destination),
      'travelMode': mode.apiValue,
      // Bangkok traffic is the whole reason an ETA is worth showing, but this
      // field is only legal for road vehicles — see `supportsTrafficAwareRouting`.
      if (mode.supportsTrafficAwareRouting) 'routingPreference': 'TRAFFIC_AWARE',
      'languageCode': languageCode,
      'units': 'METRIC',
    });

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(_timeout);
    } catch (_) {
      return const RouteOutcome.failed(RouteFailure.network);
    }

    if (response.statusCode != 200) {
      return const RouteOutcome.failed(RouteFailure.requestFailed);
    }

    final Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is! Map<String, dynamic>) {
        return const RouteOutcome.failed(RouteFailure.requestFailed);
      }
      decoded = parsed;
    } catch (_) {
      return const RouteOutcome.failed(RouteFailure.requestFailed);
    }

    final route = routeFromRoutesApiResponse(decoded, mode);
    // A 200 with an empty `routes` array is how the API says "no route
    // exists" — most often no transit service between these two points.
    if (route == null) return const RouteOutcome.failed(RouteFailure.noRoute);

    _cache[key] = _CacheEntry(route, DateTime.now());
    return RouteOutcome.success(route);
  }

  static Map<String, dynamic> _waypoint(LatLng point) => {
        'location': {
          'latLng': {
            'latitude': point.latitude,
            'longitude': point.longitude,
          },
        },
      };
}

class _CacheEntry {
  const _CacheEntry(this.route, this.at);
  final RouteSuggestion route;
  final DateTime at;

  bool get isExpired =>
      DateTime.now().difference(at) >= RouteService._cacheTtl;
}

/// Parses a `computeRoutes` response body. Split out from the request so
/// `test/route_test.dart` can cover the wire format without a network.
///
/// Returns null when the body carries no usable route.
RouteSuggestion? routeFromRoutesApiResponse(
  Map<String, dynamic> body,
  TravelMode mode,
) {
  final routes = body['routes'];
  if (routes is! List || routes.isEmpty) return null;

  final first = routes.first;
  if (first is! Map) return null;

  final distance = first['distanceMeters'];
  final duration = parseProtobufDuration(first['duration']);
  if (distance is! num || duration == null) return null;

  // `polyline` is absent on some TRANSIT legs; the summary is still worth
  // showing, so an empty geometry is not a parse failure.
  final polyline = first['polyline'];
  final encoded =
      polyline is Map ? polyline['encodedPolyline'] as String? : null;

  return RouteSuggestion(
    mode: mode,
    distanceMeters: distance.round(),
    duration: duration,
    points: encoded == null ? const [] : decodePolyline(encoded),
  );
}

/// Reads protobuf's `Duration` JSON encoding — seconds with a trailing `s`,
/// optionally fractional (`"1234s"`, `"1234.5s"`). Returns null if it is
/// anything else, so a format change surfaces as "no route" rather than a
/// silently wrong ETA.
Duration? parseProtobufDuration(Object? value) {
  if (value is! String || !value.endsWith('s')) return null;
  final seconds = double.tryParse(value.substring(0, value.length - 1));
  if (seconds == null || seconds.isNaN || seconds.isNegative) return null;
  return Duration(seconds: seconds.round());
}
