import 'package:flutter/material.dart';

/// The travel modes the Route Suggestion toggle offers (Phase 2B task 2.4).
///
/// Deliberately limited to the three modes that are supported **both** by the
/// Routes API and by the `google.com/maps/dir` deep link, so the preview and
/// the hand-off to Google Maps can never disagree about how the user is
/// travelling. `TWO_WHEELER` — motorbike, which matters in Thailand — is left
/// out for exactly that reason: the Routes API accepts it, the deep link has
/// no equivalent and silently falls back to driving.
enum TravelMode {
  drive(
    apiValue: 'DRIVE',
    deepLinkValue: 'driving',
    textKey: 'route_mode_drive',
    icon: Icons.directions_car_rounded,
  ),
  transit(
    apiValue: 'TRANSIT',
    deepLinkValue: 'transit',
    textKey: 'route_mode_transit',
    icon: Icons.directions_transit_rounded,
  ),
  walk(
    apiValue: 'WALK',
    deepLinkValue: 'walking',
    textKey: 'route_mode_walk',
    icon: Icons.directions_walk_rounded,
  );

  const TravelMode({
    required this.apiValue,
    required this.deepLinkValue,
    required this.textKey,
    required this.icon,
  });

  /// `travelMode` in the Routes API request body.
  final String apiValue;

  /// `travelmode` in the Google Maps universal URL.
  final String deepLinkValue;

  /// Key into `app_text.dart`.
  final String textKey;

  final IconData icon;

  /// Whether the Routes API accepts `routingPreference` for this mode.
  ///
  /// It only applies to road vehicles — sending it with `WALK` or `TRANSIT` is
  /// rejected outright with HTTP 400, not ignored.
  bool get supportsTrafficAwareRouting => this == TravelMode.drive;
}
