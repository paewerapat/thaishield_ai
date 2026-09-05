import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'travel_mode.dart';

/// One computed route, ready to draw.
class RouteSuggestion {
  const RouteSuggestion({
    required this.mode,
    required this.distanceMeters,
    required this.duration,
    required this.points,
  });

  final TravelMode mode;
  final int distanceMeters;
  final Duration duration;

  /// Decoded route geometry. Empty only if the API returned a route with no
  /// polyline, which the UI treats as "draw the endpoints, skip the line".
  final List<LatLng> points;

  double get distanceKm => distanceMeters / 1000;
}

/// Why a route could not be produced. Each maps to one `route_error_*` string
/// so the screen never shows a raw status code.
enum RouteFailure {
  /// The service reports itself unconfigured — a build/config mistake, never
  /// something the user can fix by retrying. No longer produced since the key
  /// moved into the `computeRoute` Cloud Function (2026-08-29); kept so the
  /// `route_error_*` copy stays complete and an old build still has a string.
  notConfigured,

  /// The API answered, but with no route: no transit service between the two
  /// points, or a destination unreachable in this mode.
  noRoute,

  /// Network down, DNS failure, timeout.
  network,

  /// Non-200: key restricted or unbilled, API not enabled, malformed request.
  requestFailed,
}

/// Result of one route lookup — exactly one of [route] / [failure] is set.
class RouteOutcome {
  const RouteOutcome.success(RouteSuggestion this.route) : failure = null;
  const RouteOutcome.failed(RouteFailure this.failure) : route = null;

  final RouteSuggestion? route;
  final RouteFailure? failure;

  bool get isSuccess => route != null;
}

/// Splits a travel time into the pieces the `route_duration_*` strings expect.
///
/// Anything under a minute still reads "1 min" rather than "0 min" — a route
/// the API answered for always takes *some* time, and a zero would look like a
/// failure. Pure so the rounding is unit-testable.
({String key, int hours, int minutes}) routeDurationParts(Duration duration) {
  final totalMinutes = (duration.inSeconds / 60).round();
  final clamped = totalMinutes < 1 ? 1 : totalMinutes;

  if (clamped < 60) {
    return (key: 'route_duration_m', hours: 0, minutes: clamped);
  }
  return (
    key: 'route_duration_hm',
    hours: clamped ~/ 60,
    minutes: clamped % 60,
  );
}
