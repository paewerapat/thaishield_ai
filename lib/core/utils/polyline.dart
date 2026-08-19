import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decodes Google's [encoded polyline algorithm][spec] into coordinates.
///
/// [spec]: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
///
/// The Routes API returns the route geometry this way rather than as a list of
/// points — a Bangkok cross-town route is a few hundred vertices, so the
/// encoding is roughly a third of the JSON a coordinate array would cost.
///
/// Pure Dart on purpose: the wire format is the one part of the route pipeline
/// that is easy to get subtly wrong (the sign bit and the 5-bit chunking), and
/// this way `test/route_test.dart` can pin it without a network or a device.
///
/// Malformed input yields whatever decoded cleanly before the damage rather
/// than throwing — a half-drawn route is a better failure than a crash on a
/// screen the user opened while walking somewhere.
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    final dLat = _decodeValue(encoded, index);
    if (dLat == null) break;
    index = dLat.nextIndex;

    final dLng = _decodeValue(encoded, index);
    if (dLng == null) break;
    index = dLng.nextIndex;

    lat += dLat.value;
    lng += dLng.value;
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}

class _Decoded {
  const _Decoded(this.value, this.nextIndex);
  final int value;
  final int nextIndex;
}

/// Reads one zig-zag-encoded varint starting at [index].
/// Returns null when the string ends mid-value.
_Decoded? _decodeValue(String encoded, int index) {
  var shift = 0;
  var result = 0;
  int byte;

  do {
    if (index >= encoded.length) return null;
    byte = encoded.codeUnitAt(index++) - 63;
    if (byte < 0) return null;
    result |= (byte & 0x1f) << shift;
    shift += 5;
    // 6 chunks × 5 bits covers the full ±180° range; anything longer is junk.
    if (shift > 30) return null;
  } while (byte >= 0x20);

  // Low bit is the sign, so odd values are negative.
  return _Decoded((result & 1) != 0 ? ~(result >> 1) : (result >> 1), index);
}
