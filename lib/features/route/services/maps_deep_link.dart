import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/travel_mode.dart';

/// Builds Google's cross-platform "universal" directions URL.
///
/// This one URL form opens the Google Maps app when it is installed (Android
/// and iOS both claim the host) and the web map when it is not, so there is no
/// need for `comgooglemaps://` or `geo:` schemes and their per-platform
/// fallbacks. See
/// https://developers.google.com/maps/documentation/urls/get-started
///
/// Coordinates go in as plain `lat,lng`; a destination *name* is deliberately
/// not used, because a name search can land the user on a same-named branch in
/// another province.
///
/// Pure so `test/route_test.dart` can assert the shape without a plugin.
Uri googleMapsDirectionsUrl({
  required LatLng origin,
  required LatLng destination,
  required TravelMode mode,
}) {
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'origin': '${origin.latitude},${origin.longitude}',
    'destination': '${destination.latitude},${destination.longitude}',
    'travelmode': mode.deepLinkValue,
  });
}

/// Hands the route off to Google Maps. Returns false when no app or browser
/// could take it, so the caller can surface a message instead of doing nothing.
Future<bool> openInGoogleMaps({
  required LatLng origin,
  required LatLng destination,
  required TravelMode mode,
}) async {
  final url = googleMapsDirectionsUrl(
    origin: origin,
    destination: destination,
    mode: mode,
  );
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
