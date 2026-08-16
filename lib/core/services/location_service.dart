import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum LocationStatus { ok, denied, serviceDisabled, error }

class LocationResult {
  const LocationResult(this.status, [this.position]);

  final LocationStatus status;
  final LatLng? position;

  bool get isOk => status == LocationStatus.ok && position != null;
}

/// Foreground, on-demand location lookup shared by the Safety Radar and the
/// Alert Zone proximity check. Deliberately has no stream/background mode —
/// CLAUDE.md §7 rules out background geofencing.
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  Future<LocationResult> current({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.denied);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );
      return LocationResult(
        LocationStatus.ok,
        LatLng(pos.latitude, pos.longitude),
      );
    } catch (_) {
      return const LocationResult(LocationStatus.error);
    }
  }

  /// Like [current], but never shows the OS permission prompt — it returns
  /// `denied` when permission has not already been granted.
  ///
  /// Used by the Alert Zone proximity check on the Home tab, which runs
  /// unprompted on open and must not hijack first launch with a permission
  /// dialog. The user grants location from the Map or the Radar; the card
  /// picks it up the next time the Home tab comes to the foreground.
  ///
  /// Accuracy matches [current] deliberately. `medium` resolves to a coarse
  /// provider that leans on network location, which is simply absent on some
  /// devices and emulators — the request then times out and the card goes
  /// quiet while the Radar, asking for `high` at the same spot, answers fine.
  Future<LocationResult> currentIfPermitted({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return const LocationResult(LocationStatus.denied);
      }
      return current(accuracy: accuracy, timeout: timeout);
    } catch (_) {
      return const LocationResult(LocationStatus.error);
    }
  }
}
