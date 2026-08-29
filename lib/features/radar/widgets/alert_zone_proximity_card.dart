import 'package:flutter/material.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/geo_utils.dart';
import '../models/radar_result.dart';
import '../services/radar_service.dart';
import 'filter_panel.dart';

/// Alert Zone proximity card — Phase 2A task 2.2.
///
/// A **foreground, on-open** check: it reuses the `alert_zones` data the Radar
/// already loads and renders nothing at all when there is no zone worth
/// reporting. There is deliberately no background watcher, geofence or push
/// notification here (CLAUDE.md §7).
///
/// It also never triggers the OS location prompt — see
/// `LocationService.currentIfPermitted`.
///
/// The check re-runs whenever the Home tab comes back to the foreground
/// ([isActive] flipping to true, or the app resuming). It used to fire only
/// from `initState`, which sounds equivalent but is not: `HomeScreen` keeps
/// every tab alive in an `IndexedStack`, so this widget is built exactly once
/// per app launch. That made two documented behaviours impossible — granting
/// location from the Map or Radar could not switch the card on mid-session,
/// and the very common "no GPS fix yet at cold start" miss silenced the card
/// until the app was killed. See INTEGRATION_TEST.md §F9.
class AlertZoneProximityCard extends StatefulWidget {
  const AlertZoneProximityCard({
    super.key,
    required this.onShowOnMap,
    this.isActive = true,
  });

  final void Function(double lat, double lng) onShowOnMap;

  /// Whether the Home tab is the one currently on screen. Re-checking while
  /// the user is off on another tab would spend a GPS fix nobody can see.
  final bool isActive;

  @override
  State<AlertZoneProximityCard> createState() => _AlertZoneProximityCardState();
}

class _AlertZoneProximityCardState extends State<AlertZoneProximityCard>
    with WidgetsBindingObserver {
  RadarZoneEntry? _entry;
  bool _dismissed = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AlertZoneProximityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Home tab just became the visible one — the user may have granted
    // location on the Map or Radar in between.
    if (widget.isActive && !oldWidget.isActive) _check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Covers granting the permission in OS Settings and coming back.
    if (state == AppLifecycleState.resumed && widget.isActive) _check();
  }

  Future<void> _check() async {
    // Nothing to gain from re-checking once a zone is showing, and a dismissed
    // card must stay dismissed.
    if (_checking || _entry != null || _dismissed) return;
    _checking = true;
    try {
      final location = await LocationService.instance.currentIfPermitted();
      if (!location.isOk) return;
      final entry =
          await RadarService.instance.zoneAtOrNear(location.position!);
      if (!mounted || entry == null) return;
      setState(() => _entry = entry);
    } catch (_) {
      // Silent by design — this card is supplementary, and a failed check
      // must never block or clutter the Home tab. Recoverable because the
      // next activation retries.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    if (entry == null || _dismissed) return const SizedBox.shrink();

    final isTh = Localizations.localeOf(context).languageCode == 'th';
    final langCode = Localizations.localeOf(context).languageCode;
    final zone = entry.zone;
    final color = riskLevelColor(zone.riskLevel);
    final description = zone.localizedDescription(langCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(riskLevelIcon(zone.riskLevel), color: color, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appText(
                        context,
                        entry.isInside
                            ? 'proximity_inside_title'
                            : 'proximity_near_title',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF0D1B2A),
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.isInside
                          ? appText(context, 'radar_you_are_inside')
                          : appText(context, 'proximity_distance_away')
                              .replaceFirst(
                              '{distance}',
                              formatDistance(entry.distanceKm, isTh: isTh),
                            ),
                      style: TextStyle(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => setState(() => _dismissed = true),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.localizedName(Localizations.localeOf(context).languageCode),
                  style: const TextStyle(
                    color: Color(0xFF0D1B2A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  appText(context, riskLevelTextKey(zone.riskLevel)),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF546E7A),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: () => widget.onShowOnMap(zone.centerLat, zone.centerLng),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map_rounded, color: Color(0xFF2E7D32), size: 15),
                      const SizedBox(width: 5),
                      Text(
                        appText(context, 'radar_view_on_map'),
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            appText(context, 'proximity_disclaimer'),
            style: TextStyle(color: Colors.grey[500], fontSize: 10, height: 1.3),
          ),
        ],
      ),
    );
  }
}
