import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/geo_utils.dart';
import '../models/route_suggestion.dart';
import '../models/travel_mode.dart';
import '../services/maps_deep_link.dart';
import '../services/route_service.dart';

const _headerGreen = Color(0xFF0A1810);
const _pageGrey = Color(0xFFF3F5F7);
const _navy = Color(0xFF0D1B2A);
const _gold = Color(0xFFFFB300);
const _green = Color(0xFF2E7D32);
const _muted = Color(0xFF546E7A);

enum _RouteState { locating, calculating, ready, failed }

/// Route Suggestion preview — Phase 2B task 2.4.
///
/// Pushed from the Map's partner sheet. Shows one route from the user's
/// current position to [destination] with a travel-mode toggle, and hands off
/// to Google Maps for the actual turn-by-turn navigation — this screen
/// deliberately does not try to be a navigator (no live re-routing and no
/// background location, which §7 rules out anyway).
class RoutePreviewScreen extends StatefulWidget {
  const RoutePreviewScreen({
    super.key,
    required this.destination,
    required this.destinationName,
  });

  final LatLng destination;

  /// Shown in the header and the summary card only. The hand-off to Google
  /// Maps travels by coordinates — see `maps_deep_link.dart`.
  final String destinationName;

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  _RouteState _state = _RouteState.locating;
  TravelMode _mode = TravelMode.drive;
  RouteSuggestion? _route;
  LatLng? _origin;
  String _errorKey = 'route_error_request';

  GoogleMapController? _mapController;

  /// Set when a route arrives before the map is ready, and applied by
  /// [_onMapCreated]. `newLatLngBounds` throws if the map has no size yet, so
  /// the fit cannot simply be fired the moment the route lands.
  LatLngBounds? _pendingFit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _state = _RouteState.locating);

    final location = await LocationService.instance.current();
    if (!mounted) return;

    if (!location.isOk) {
      setState(() {
        _state = _RouteState.failed;
        _errorKey = switch (location.status) {
          LocationStatus.denied => 'route_location_denied',
          LocationStatus.serviceDisabled => 'radar_location_disabled',
          _ => 'radar_location_error',
        };
      });
      return;
    }

    _origin = location.position;
    await _loadRoute();
  }

  Future<void> _loadRoute() async {
    final origin = _origin;
    if (origin == null) return _start();

    final languageCode = Localizations.localeOf(context).languageCode;
    setState(() => _state = _RouteState.calculating);

    final outcome = await RouteService.instance.route(
      origin: origin,
      destination: widget.destination,
      mode: _mode,
      languageCode: languageCode,
    );
    if (!mounted) return;

    if (!outcome.isSuccess) {
      setState(() {
        _state = _RouteState.failed;
        _errorKey = switch (outcome.failure!) {
          RouteFailure.notConfigured => 'route_error_not_configured',
          RouteFailure.noRoute => 'route_error_no_route',
          RouteFailure.network => 'route_error_network',
          RouteFailure.requestFailed => 'route_error_request',
        };
      });
      return;
    }

    final route = outcome.route!;
    setState(() {
      _route = route;
      _state = _RouteState.ready;
    });
    _fit(route);
  }

  void _onModeChanged(TravelMode mode) {
    if (mode == _mode || _state == _RouteState.calculating) return;
    setState(() => _mode = mode);
    _loadRoute();
  }

  /// Frames the whole route. Falls back to the two endpoints when the API
  /// returned a route without geometry (which happens on some transit legs),
  /// so the user still sees where they are and where they are going.
  void _fit(RouteSuggestion route) {
    final origin = _origin;
    if (origin == null) return;

    final points =
        route.points.isNotEmpty ? route.points : [origin, widget.destination];
    final bounds = boundsFor(points);
    if (bounds == null) return;

    final controller = _mapController;
    if (controller == null) {
      _pendingFit = bounds;
      return;
    }
    _pendingFit = null;
    _animateTo(controller, bounds);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final pending = _pendingFit;
    if (pending == null) return;
    _pendingFit = null;
    _animateTo(controller, pending);
  }

  void _animateTo(GoogleMapController controller, LatLngBounds bounds) {
    // Swallowed on purpose: a failed camera move leaves the map on its
    // initial position, which still shows the destination. Not worth an error
    // state of its own.
    controller
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 56))
        .catchError((_) {});
  }

  Future<void> _openInGoogleMaps() async {
    final origin = _origin;
    if (origin == null) return;

    final opened = await openInGoogleMaps(
      origin: origin,
      destination: widget.destination,
      mode: _mode,
    );
    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(appText(context, 'route_open_failed'))),
    );
  }

  Set<Marker> get _markers {
    final origin = _origin;
    return {
      if (origin != null)
        Marker(
          markerId: const MarkerId('route_origin'),
          position: origin,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      Marker(
        markerId: const MarkerId('route_destination'),
        position: widget.destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        ),
      ),
    };
  }

  Set<Polyline> get _polylines {
    final route = _route;
    if (route == null || route.points.isEmpty) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: route.points,
        color: _green,
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageGrey,
      body: Column(
        children: [
          _RouteHeader(
            destinationName: widget.destinationName,
            onBack: () => Navigator.of(context).pop(),
          ),
          _TravelModeToggle(
            selected: _mode,
            onChanged: _onModeChanged,
            busy: _state == _RouteState.locating ||
                _state == _RouteState.calculating,
          ),
          Expanded(child: _buildBody()),
          const _RouteDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_state == _RouteState.failed) {
      final unconfigured = _errorKey == 'route_error_not_configured';
      return _CenteredMessage(
        icon: unconfigured
            ? Icons.cloud_off_rounded
            : Icons.wrong_location_rounded,
        message: appText(context, _errorKey),
        // A build without the key will never succeed, so a "Try Again" button
        // there would only loop the user through the same dead end.
        onRetry: unconfigured
            ? null
            : () => _origin == null ? _start() : _loadRoute(),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.destination,
            zoom: 14,
          ),
          markers: _markers,
          polylines: _polylines,
          onMapCreated: _onMapCreated,
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
        if (_state != _RouteState.ready)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.75),
              child: _CenteredMessage(
                busy: true,
                message: appText(
                  context,
                  _state == _RouteState.locating
                      ? 'route_locating'
                      : 'route_calculating',
                ),
              ),
            ),
          ),
        if (_route != null && _state == _RouteState.ready)
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: _RouteSummaryCard(
              route: _route!,
              destinationName: widget.destinationName,
              onOpenInGoogleMaps: _openInGoogleMaps,
            ),
          ),
      ],
    );
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({required this.destinationName, required this.onBack});

  final String destinationName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _headerGreen,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 20, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ThaiShield AI',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appText(context, 'route_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appText(context, 'route_to')
                          .replaceFirst('{name}', destinationName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TravelModeToggle extends StatelessWidget {
  const _TravelModeToggle({
    required this.selected,
    required this.onChanged,
    required this.busy,
  });

  final TravelMode selected;
  final ValueChanged<TravelMode> onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          for (final mode in TravelMode.values) ...[
            Expanded(
              child: _ModeChip(
                mode: mode,
                selected: mode == selected,
                onTap: busy ? null : () => onChanged(mode),
              ),
            ),
            if (mode != TravelMode.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TravelMode mode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _green : _pageGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _green : const Color(0xFFE0E0E0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode.icon,
              size: 19,
              color: selected ? Colors.white : _muted,
            ),
            const SizedBox(height: 3),
            Text(
              appText(context, mode.textKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : _muted,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSummaryCard extends StatelessWidget {
  const _RouteSummaryCard({
    required this.route,
    required this.destinationName,
    required this.onOpenInGoogleMaps,
  });

  final RouteSuggestion route;
  final String destinationName;
  final VoidCallback onOpenInGoogleMaps;

  String _duration(BuildContext context) {
    final parts = routeDurationParts(route.duration);
    return appText(context, parts.key)
        .replaceFirst('{h}', '${parts.hours}')
        .replaceFirst('{m}', '${parts.minutes}');
  }

  @override
  Widget build(BuildContext context) {
    final isTh = Localizations.localeOf(context).languageCode == 'th';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            destinationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _navy,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            appText(context, 'route_from_your_location'),
            style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: appText(context, 'route_estimated_time'),
                  value: _duration(context),
                  icon: Icons.schedule_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: const Color(0xFFE0E0E0),
              ),
              Expanded(
                child: _Metric(
                  label: appText(context, 'route_distance'),
                  value: formatDistance(route.distanceKm, isTh: isTh),
                  icon: Icons.straighten_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenInGoogleMaps,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: Text(
                appText(context, 'route_open_in_maps'),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: const Color(0xFF90A4AE)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF90A4AE),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _navy,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.message,
    this.icon,
    this.onRetry,
    this.busy = false,
  });

  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const CircularProgressIndicator(color: _green)
            else if (icon != null)
              Icon(icon, color: const Color(0xFF90A4AE), size: 44),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(appText(context, 'radar_retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteDisclaimer extends StatelessWidget {
  const _RouteDisclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: SafeArea(
        top: false,
        child: Text(
          appText(context, 'route_disclaimer'),
          style: TextStyle(color: Colors.grey[500], fontSize: 10, height: 1.35),
        ),
      ),
    );
  }
}
