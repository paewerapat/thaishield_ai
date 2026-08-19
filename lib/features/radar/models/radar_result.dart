import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/models/alert_zone.dart';
import '../../../core/models/partner_category.dart';
import '../../../core/models/partner_location.dart';

/// One card in the Radar result list.
sealed class RadarEntry {
  const RadarEntry();

  /// Straight-line distance from the search centre, in kilometres.
  double get distanceKm;

  RadarGroup get group;

  /// Stable key for widget lists.
  String get id;
}

class RadarPartnerEntry extends RadarEntry {
  const RadarPartnerEntry({required this.partner, required this.distanceKm});

  final PartnerLocation partner;

  @override
  final double distanceKm;

  PartnerCategory get category => partner.category;

  @override
  RadarGroup get group => category.radarGroup;

  @override
  String get id => 'partner_${partner.id}';
}

class RadarZoneEntry extends RadarEntry {
  const RadarZoneEntry({
    required this.zone,
    required this.distanceKm,
    required this.isInside,
  });

  final AlertZone zone;

  /// Distance to the nearest edge of the zone — 0 when the user is inside it.
  @override
  final double distanceKm;

  final bool isInside;

  @override
  RadarGroup get group {
    switch (zone.riskLevel) {
      case 'danger':
        return RadarGroup.zoneDanger;
      case 'caution':
        return RadarGroup.zoneCaution;
      default:
        return RadarGroup.zoneSafe;
    }
  }

  @override
  String get id => 'zone_${zone.id}';
}

class RadarResult {
  const RadarResult({
    required this.center,
    required this.radiusKm,
    required this.entries,
  });

  final LatLng center;
  final double radiusKm;

  /// All entries inside the radius, already sorted nearest-first.
  final List<RadarEntry> entries;

  bool get isEmpty => entries.isEmpty;

  int get count => entries.length;

  /// Entries bucketed by card group, in `RadarGroup` declaration order.
  /// Groups with no entries are omitted.
  Map<RadarGroup, List<RadarEntry>> get grouped {
    final map = <RadarGroup, List<RadarEntry>>{};
    for (final group in RadarGroup.values) {
      final items = entries.where((e) => e.group == group).toList();
      if (items.isNotEmpty) map[group] = items;
    }
    return map;
  }

  int countIn(RadarGroup group) =>
      entries.where((e) => e.group == group).length;

  /// The same result truncated to the [limit] nearest entries.
  ///
  /// Used by the free tier's Radar list (Phase 2B task 2.5). Truncating the
  /// flat, distance-sorted list before grouping keeps what free users see the
  /// *closest* things around them, rather than the first few of whichever
  /// group happens to sort first.
  RadarResult take(int limit) {
    if (limit >= entries.length) return this;
    return RadarResult(
      center: center,
      radiusKm: radiusKm,
      entries: entries.take(limit < 0 ? 0 : limit).toList(),
    );
  }
}
