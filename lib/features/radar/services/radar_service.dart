import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/models/alert_zone.dart';
import '../../../core/models/partner_category.dart';
import '../../../core/models/partner_location.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/geo_utils.dart';
import '../models/radar_result.dart';

/// On-demand radius search over the data the app already has
/// (`partner_locations` + `alert_zones`). No extra Firestore collections and
/// no client writes — CLAUDE.md §4 "Definition of done (2A)".
///
/// Both collections are small and staff-maintained, so they are fetched whole
/// and cached in memory for [_cacheTtl]; changing the radius or the filters
/// re-runs the maths locally instead of hitting Firestore again.
class RadarService {
  RadarService._();
  static final instance = RadarService._();

  static const _cacheTtl = Duration(minutes: 10);

  /// Radius options offered by the Radar UI, in kilometres.
  static const radiusOptionsKm = <double>[0.5, 1, 3, 5];
  static const defaultRadiusKm = 1.0;

  List<PartnerLocation> _partners = const [];
  List<AlertZone> _zones = const [];
  DateTime? _fetchedAt;

  bool get _isCacheFresh {
    final at = _fetchedAt;
    return at != null && DateTime.now().difference(at) < _cacheTtl;
  }

  Future<void> _ensureLoaded({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheFresh) return;
    // Both reads run concurrently — one round trip's latency instead of two.
    // The record form keeps the static types and, unlike awaiting the two
    // futures in sequence, does not leave the second error unhandled when the
    // first read fails.
    final (partners, zones) = await (
      FirestoreService.instance.getPartnerLocations(),
      FirestoreService.instance.getAlertZones(),
    ).wait;
    _partners = partners;
    _zones = zones;
    _fetchedAt = DateTime.now();
  }

  /// "What's Around Me" — everything within [radiusKm] of [center], sorted
  /// nearest-first.
  ///
  /// [categories] and [riskLevels], when non-null, restrict which partner
  /// types and which zone risk levels are returned (the Filter panel, task
  /// 2.3). Passing an empty set returns nothing of that kind.
  Future<RadarResult> scan({
    required LatLng center,
    double radiusKm = defaultRadiusKm,
    Set<PartnerCategory>? categories,
    Set<String>? riskLevels,
    bool forceRefresh = false,
  }) async {
    await _ensureLoaded(forceRefresh: forceRefresh);

    final entries = <RadarEntry>[];

    for (final partner in _partners) {
      if (categories != null && !categories.contains(partner.category)) {
        continue;
      }
      final d = distanceKm(center, LatLng(partner.lat, partner.lng));
      if (d > radiusKm) continue;
      entries.add(RadarPartnerEntry(partner: partner, distanceKm: d));
    }

    for (final zone in _zones) {
      if (riskLevels != null && !riskLevels.contains(zone.riskLevel)) continue;
      final d = distanceToZoneKm(center, zone);
      if (d > radiusKm) continue;
      entries.add(
        RadarZoneEntry(
          zone: zone,
          distanceKm: d,
          isInside: isInsideZone(center, zone),
        ),
      );
    }

    entries.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return RadarResult(center: center, radiusKm: radiusKm, entries: entries);
  }

  /// The single zone worth surfacing on open (task 2.2): a zone the user is
  /// standing in wins; otherwise the nearest advisory/alert zone within
  /// [alertWithinKm]. Returns null when there is nothing to report, which is
  /// the common case and must render nothing at all.
  ///
  /// Foreground, on-open only — there is no background watcher here by design
  /// (§7).
  Future<RadarZoneEntry?> zoneAtOrNear(
    LatLng point, {
    double alertWithinKm = 1.0,
  }) async {
    await _ensureLoaded();

    RadarZoneEntry? best;
    for (final zone in _zones) {
      final inside = isInsideZone(point, zone);
      final d = inside ? 0.0 : distanceToZoneKm(point, zone);

      // Outside zones only matter when they are close AND non-safe: a "safe"
      // zone two streets away is not news.
      if (!inside && (d > alertWithinKm || zone.riskLevel == 'safe')) continue;

      final entry =
          RadarZoneEntry(zone: zone, distanceKm: d, isInside: inside);
      if (best == null || _outranks(entry, best)) best = entry;
    }
    return best;
  }

  /// Inside beats outside; then higher risk; then closer.
  bool _outranks(RadarZoneEntry a, RadarZoneEntry b) {
    if (a.isInside != b.isInside) return a.isInside;
    final rankA = _riskRank(a.zone.riskLevel);
    final rankB = _riskRank(b.zone.riskLevel);
    if (rankA != rankB) return rankA > rankB;
    return a.distanceKm < b.distanceKm;
  }

  int _riskRank(String riskLevel) {
    switch (riskLevel) {
      case 'danger':
        return 2;
      case 'caution':
        return 1;
      default:
        return 0;
    }
  }
}
