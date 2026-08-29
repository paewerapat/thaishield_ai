import 'package:flutter/material.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/models/partner_category.dart';
import '../../../core/utils/geo_utils.dart';
import '../models/radar_result.dart';
import 'filter_panel.dart';

const _navy = Color(0xFF0D1B2A);
const _muted = Color(0xFF90A4AE);

const Map<RadarGroup, String> radarGroupTextKey = {
  RadarGroup.zoneDanger: 'radar_group_zone_danger',
  RadarGroup.zoneCaution: 'radar_group_zone_caution',
  RadarGroup.zoneSafe: 'radar_group_zone_safe',
  RadarGroup.emergencyServices: 'radar_group_emergency',
  RadarGroup.partners: 'radar_group_partners',
  RadarGroup.transport: 'radar_group_transport',
};

const Map<RadarGroup, IconData> radarGroupIcon = {
  RadarGroup.zoneDanger: Icons.warning_rounded,
  RadarGroup.zoneCaution: Icons.error_outline_rounded,
  RadarGroup.zoneSafe: Icons.check_circle_outline_rounded,
  RadarGroup.emergencyServices: Icons.local_hospital_rounded,
  RadarGroup.partners: Icons.storefront_rounded,
  RadarGroup.transport: Icons.local_taxi_rounded,
};

const Map<RadarGroup, Color> radarGroupColor = {
  RadarGroup.zoneDanger: Color(0xFFEF5350),
  RadarGroup.zoneCaution: Color(0xFFFF9800),
  RadarGroup.zoneSafe: Color(0xFF4CAF50),
  RadarGroup.emergencyServices: Color(0xFFD32F2F),
  RadarGroup.partners: Color(0xFF1565C0),
  RadarGroup.transport: Color(0xFF00897B),
};

/// One "Safe Area / Advisory / Alert Zone / Partners / Emergency / Transport"
/// block of the Radar results.
class RadarGroupSection extends StatelessWidget {
  const RadarGroupSection({
    super.key,
    required this.group,
    required this.entries,
    required this.onShowOnMap,
  });

  final RadarGroup group;
  final List<RadarEntry> entries;
  final void Function(double lat, double lng) onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final color = radarGroupColor[group]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(radarGroupIcon[group], color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                appText(context, radarGroupTextKey[group]!),
                style: const TextStyle(
                  color: _navy,
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${entries.length}',
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: switch (entry) {
              RadarZoneEntry() =>
                RadarZoneCard(entry: entry, onShowOnMap: onShowOnMap),
              RadarPartnerEntry() =>
                RadarPartnerCard(entry: entry, onShowOnMap: onShowOnMap),
            },
          ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E9EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class RadarZoneCard extends StatelessWidget {
  const RadarZoneCard({
    super.key,
    required this.entry,
    required this.onShowOnMap,
  });

  final RadarZoneEntry entry;
  final void Function(double lat, double lng) onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final isTh = langCode == 'th';
    final zone = entry.zone;
    final color = riskLevelColor(zone.riskLevel);
    final description = zone.localizedDescription(langCode);

    return _CardShell(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(riskLevelIcon(zone.riskLevel), color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  zone.localizedName(Localizations.localeOf(context).languageCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _DistanceLabel(
                text: entry.isInside
                    ? appText(context, 'radar_you_are_inside')
                    : formatDistance(entry.distanceKm, isTh: isTh),
                color: entry.isInside ? color : _muted,
                emphasised: entry.isInside,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            appText(context, riskLevelTextKey(zone.riskLevel)),
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF546E7A),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _ShowOnMapLink(
            onTap: () => onShowOnMap(zone.centerLat, zone.centerLng),
          ),
        ],
      ),
    );
  }
}

class RadarPartnerCard extends StatelessWidget {
  const RadarPartnerCard({
    super.key,
    required this.entry,
    required this.onShowOnMap,
  });

  final RadarPartnerEntry entry;
  final void Function(double lat, double lng) onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final isTh = Localizations.localeOf(context).languageCode == 'th';
    final partner = entry.partner;
    final category = entry.category;
    final color = partnerCategoryColor[category]!;

    return _CardShell(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(partnerCategoryIcon[category], color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  partner.localizedName(Localizations.localeOf(context).languageCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _DistanceLabel(
                text: formatDistance(entry.distanceKm, isTh: isTh),
                color: _muted,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                appText(context, category.textKey),
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (partner.rating > 0) ...[
                const SizedBox(width: 8),
                const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 13),
                const SizedBox(width: 2),
                Text(
                  partner.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Color(0xFF546E7A),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (partner.isVerified)
                _Badge(
                  label: appText(context, 'radar_badge_certified'),
                  color: const Color(0xFF2E7D32),
                )
              else
                _Badge(
                  label: appText(context, 'radar_badge_partner'),
                  color: const Color(0xFF1565C0),
                ),
              if (partner.priceTier != 'fair')
                _Badge(
                  label: appText(context, 'radar_badge_above_range'),
                  color: const Color(0xFFFF9800),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _ShowOnMapLink(
            onTap: () => onShowOnMap(partner.lat, partner.lng),
          ),
        ],
      ),
    );
  }
}

class _DistanceLabel extends StatelessWidget {
  const _DistanceLabel({
    required this.text,
    required this.color,
    this.emphasised = false,
  });

  final String text;
  final Color color;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: emphasised
            ? color.withValues(alpha: 0.12)
            : const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: emphasised ? color : const Color(0xFF607D8B),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ShowOnMapLink extends StatelessWidget {
  const _ShowOnMapLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
    );
  }
}
