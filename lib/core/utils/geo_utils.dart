import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/alert_zone.dart';

const double _earthRadiusKm = 6371.0088;

double _toRadians(double degrees) => degrees * math.pi / 180;

/// Great-circle distance in kilometres between two coordinates.
double distanceKm(LatLng a, LatLng b) {
  final dLat = _toRadians(b.latitude - a.latitude);
  final dLng = _toRadians(b.longitude - a.longitude);
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);

  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * _earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
}

/// Ray-casting point-in-polygon test. Points are treated as a closed ring, so
/// the caller does not need to repeat the first vertex at the end.
bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  if (polygon.length < 3) return false;

  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final yi = polygon[i].latitude;
    final xi = polygon[i].longitude;
    final yj = polygon[j].latitude;
    final xj = polygon[j].longitude;

    final crosses = (yi > point.latitude) != (yj > point.latitude) &&
        point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi;
    if (crosses) inside = !inside;
  }
  return inside;
}

/// Whether `point` falls inside `zone`.
///
/// Follows the two-step check CLAUDE.md §3 prescribes: `center_*` + `radius_km`
/// are derived convenience values, so they are used as a cheap bounding-circle
/// rejection first, and only points that survive it pay for the precise
/// polygon test. Zones stored without a usable polygon (fewer than 3 vertices,
/// which the map renders as a plain circle) fall back to the radius result.
bool isInsideZone(LatLng point, AlertZone zone) {
  final withinRadius =
      distanceKm(point, LatLng(zone.centerLat, zone.centerLng)) <= zone.radiusKm;
  if (!withinRadius) return false;
  if (zone.polygon.length < 3) return true;
  return isPointInPolygon(point, zone.polygon);
}

/// Shortest distance in kilometres from `p` to the segment `a`–`b`.
///
/// Works in a local equirectangular projection: longitudes are scaled by
/// cos(latitude) so a degree east measures the same as a degree north. Over
/// the few kilometres a zone spans, the error is negligible.
double _distanceToSegmentKm(LatLng p, LatLng a, LatLng b) {
  final scale = math.cos(_toRadians(p.latitude));
  double x(LatLng c) => (c.longitude - p.longitude) * scale;
  double y(LatLng c) => c.latitude - p.latitude;

  final ax = x(a), ay = y(a), bx = x(b), by = y(b);
  final dx = bx - ax, dy = by - ay;
  final lengthSq = dx * dx + dy * dy;

  // Degenerate segment (repeated vertex) — fall back to the endpoint.
  if (lengthSq == 0) return distanceKm(p, a);

  // Projection of p (the origin here) onto the segment, clamped to it.
  final t = (-(ax * dx + ay * dy) / lengthSq).clamp(0.0, 1.0);
  final closest = LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );
  return distanceKm(p, closest);
}

/// Distance from `point` to the nearest edge of `zone`, in kilometres.
/// Returns 0 when the point is inside the zone.
///
/// Zones drawn as polygons measure to the actual polygon edge; zones stored
/// without a usable polygon (which the map renders as a plain circle) fall
/// back to the bounding circle from `center_*` + `radius_km`.
double distanceToZoneKm(LatLng point, AlertZone zone) {
  if (isInsideZone(point, zone)) return 0;

  final polygon = zone.polygon;
  if (polygon.length >= 3) {
    var nearest = double.infinity;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final d = _distanceToSegmentKm(point, polygon[j], polygon[i]);
      if (d < nearest) nearest = d;
    }
    return nearest;
  }

  final toCenter = distanceKm(point, LatLng(zone.centerLat, zone.centerLng));
  return math.max(0, toCenter - zone.radiusKm);
}

/// Formats a distance for display: metres under 1 km, one decimal above it.
String formatDistance(double km, {required bool isTh}) {
  if (km < 1) {
    final metres = (km * 1000).round();
    return isTh ? '$metres ม.' : '$metres m';
  }
  final value = km.toStringAsFixed(1);
  return isTh ? '$value กม.' : '$value km';
}

/// The smallest [LatLngBounds] containing every point in [points], padded by
/// [paddingDeg] so a route drawn edge-to-edge is not clipped by the map frame.
///
/// Returns null for an empty list. A single point (or a degenerate route where
/// origin and destination coincide) still yields a valid box, because
/// `GoogleMap` rejects bounds whose southwest corner is not strictly below and
/// left of the northeast one.
LatLngBounds? boundsFor(List<LatLng> points, {double paddingDeg = 0.002}) {
  if (points.isEmpty) return null;

  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;

  for (final p in points) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }

  return LatLngBounds(
    southwest: LatLng(minLat - paddingDeg, minLng - paddingDeg),
    northeast: LatLng(maxLat + paddingDeg, maxLng + paddingDeg),
  );
}
