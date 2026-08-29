import 'package:flutter/material.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/models/partner_category.dart';
import '../../../core/utils/geo_utils.dart';
import '../../premium/providers/premium_provider.dart';
import '../../premium/widgets/premium_lock_card.dart';
import '../../radar/models/radar_result.dart';

const _navy = Color(0xFF0D1B2A);
const _muted = Color(0xFF607D8B);
const _green = Color(0xFF4CAF50);
const _amber = Color(0xFFFF9800);
const _red = Color(0xFFEF5350);
const _blue = Color(0xFF1565C0);

/// "What's around you", drawn on the Map itself — the approved item (ข) from
/// the 2026-08-22 scope round.
///
/// The Safety Radar already computed all of this (2A task 2.1); what it did not
/// do was put it where people look. The Radar lives on its own screen off the
/// Home tab, so a user standing on the Map — the screen that shows where they
/// are — had to leave it to find out what was around them. This panel closes
/// that gap without a second data path: it renders a [RadarResult] the Map
/// already asked `RadarService` for.
///
/// Shape: a sheet the user can drag. Collapsed it shows the four counts, which
/// is the whole "how busy is this area" answer in one line. Dragged up it lists
/// the nearby advisories and the nearest partners with distances in metres.
///
/// The free tier sees the counts in full but only the nearest few list entries,
/// matching the Radar's own gate — see [PremiumProvider.freeRadarResultLimit].
/// Counts are deliberately never gated: they are the part that tells someone
/// whether the area is worth looking at, and hiding them would make the Map
/// feel broken rather than limited.
class AroundYouPanel extends StatelessWidget {
  const AroundYouPanel({
    super.key,
    required this.result,
    required this.isPremium,
    required this.onShowEntry,
    required this.onUnlock,
    this.address,
    this.standingIn,
    this.updatedAt,
    this.onViewAll,
  });

  /// Null while the user's position is still unknown or the scan has not run.
  /// The panel renders nothing at all in that case rather than an empty shell,
  /// because a sheet promising "around you" before there is an "you" reads as
  /// a failure.
  final RadarResult? result;

  final bool isPremium;

  /// Centres the map on an entry and opens its detail — the same gesture the
  /// Radar's "Show on Map" performs, minus the tab switch.
  final void Function(RadarEntry entry) onShowEntry;

  final VoidCallback onUnlock;

  /// Reverse-geocoded name of where the user is standing. Null while it is
  /// still being looked up; the panel says so rather than showing a blank.
  final String? address;

  /// The mapped area the user is actually inside, if any. Null is the common
  /// case — most of the map has no zone — and is stated as "no information
  /// here", never as "safe" (§10).
  final RadarZoneEntry? standingIn;

  /// When the counts below were computed, so nobody reads a stale sheet as
  /// current.
  final DateTime? updatedAt;

  /// Opens the full Radar. Null hides the "view all" links entirely rather
  /// than showing a control that does nothing.
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final current = result;
    if (current == null) return const SizedBox.shrink();

    final isTh = Localizations.localeOf(context).languageCode == 'th';

    final zones = current.entries.whereType<RadarZoneEntry>().toList();
    final partners = current.entries.whereType<RadarPartnerEntry>().toList();

    // Only non-safe zones are "alerts". A safe-rated area two streets away is
    // not something to notify anyone about, and listing it would dilute the
    // ones that matter.
    final advisories =
        zones.where((z) => z.zone.riskLevel != 'safe').toList();

    final limit = isPremium ? null : PremiumProvider.freeRadarResultLimit;
    final shownAdvisories = _take(advisories, limit);
    final shownPartners = _take(partners, limit);
    final hidden = (advisories.length - shownAdvisories.length) +
        (partners.length - shownPartners.length);

    return DraggableScrollableSheet(
        // 0.26, not 0.16. The collapsed sheet exists to answer "how busy is this
      // area" without any gesture, and at 0.16 the bottom navigation clipped the
      // count row in half — the one thing it promises to show. Measured on the
      // emulator 2026-08-23 after the labels grew to three lines.
      //
      // The map lifts and then hides its floating buttons by listening for
      // DraggableScrollableNotification, so these fractions can change without a
      // second literal needing to be kept in step — but
      // `_MapScreenState._aroundHideButtonsAbove` must stay above this minimum,
      // or the buttons vanish while the sheet is still collapsed.
      initialChildSize: 0.26,
      minChildSize: 0.26,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.26, 0.5, 0.75],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 16,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              const _DragHandle(),
              const SizedBox(height: 10),
              _YouAreHere(
                address: address,
                standingIn: standingIn,
                updatedAt: updatedAt,
              ),
              const SizedBox(height: 14),
              _Header(radiusKm: current.radiusKm, isTh: isTh),
              const SizedBox(height: 12),
              _CountTiles(result: current, zones: zones, partners: partners),
              if (shownAdvisories.isNotEmpty) ...[
                const SizedBox(height: 18),
                _SectionTitle(
                  text: appText(context, 'around_alerts_title'),
                  onViewAll: onViewAll,
                ),
                const SizedBox(height: 8),
                for (final entry in shownAdvisories)
                  _AdvisoryRow(
                    entry: entry,
                    isTh: isTh,
                    onTap: () => onShowEntry(entry),
                  ),
              ],
              if (shownPartners.isNotEmpty) ...[
                const SizedBox(height: 18),
                _SectionTitle(
                  text: appText(context, 'around_partners_title'),
                  onViewAll: onViewAll,
                ),
                const SizedBox(height: 8),
                for (final entry in shownPartners)
                  _PartnerRow(
                    entry: entry,
                    isTh: isTh,
                    onTap: () => onShowEntry(entry),
                  ),
              ],
              if (advisories.isEmpty && partners.isEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  appText(context, 'around_empty'),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
              if (hidden > 0) ...[
                const SizedBox(height: 16),
                PremiumLockedResultsCard(
                  hiddenCount: hidden,
                  onUnlock: onUnlock,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static List<T> _take<T>(List<T> items, int? limit) =>
      limit == null || items.length <= limit ? items : items.take(limit).toList();
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFCFD8DC),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// "You are here" — the address, the mapped area the user is standing in, and
/// when the numbers below were taken.
///
/// The poster this came from also carried a "safety index 95/100" here. That
/// was dropped: scoring an area is exactly the judgement §10 forbids, and no
/// data in this project could compute it honestly. What replaces it is the
/// name of the area the user is actually inside, which is a fact.
class _YouAreHere extends StatelessWidget {
  const _YouAreHere({
    required this.address,
    required this.standingIn,
    required this.updatedAt,
  });

  final String? address;
  final RadarZoneEntry? standingIn;
  final DateTime? updatedAt;

  static const _riskColors = {
    'safe': Color(0xFF2E7D32),
    'caution': Color(0xFFEF6C00),
    'danger': Color(0xFFC62828),
  };

  static const _riskKeys = {
    'safe': 'radar_group_zone_safe',
    'caution': 'radar_group_zone_caution',
    'danger': 'radar_group_zone_danger',
  };

  @override
  Widget build(BuildContext context) {
    final zone = standingIn;
    final risk = zone?.zone.riskLevel;
    // An unmapped spot is the ordinary case, not a good one. Grey says "no
    // information"; green would say "checked and fine", which is a claim.
    final colour = _riskColors[risk] ?? const Color(0xFF90A4AE);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4, right: 8),
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appText(context, 'around_you_are_at'),
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address ?? appText(context, 'around_locating'),
                    style: TextStyle(
                      color: address == null
                          ? const Color(0xFF90A4AE)
                          : const Color(0xFF45585F),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Wrap, not Row: Russian and Japanese zone names are long, and a fixed
        // row across a phone width is how the map legend overflowed once
        // already.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colour.withValues(alpha: 0.35)),
              ),
              child: Text(
                risk == null
                    ? appText(context, 'around_no_zone')
                    : appText(context, _riskKeys[risk]!),
                style: TextStyle(
                  color: colour,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (updatedAt != null)
              Text(
                appText(context, 'around_updated_at')
                    .replaceFirst('{time}', _clock(updatedAt!)),
                style: const TextStyle(
                  color: Color(0xFF90A4AE),
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _clock(DateTime at) {
    final local = at.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.radiusKm, required this.isTh});

  final double radiusKm;
  final bool isTh;

  @override
  Widget build(BuildContext context) {
    // The radius comes from the result, not a literal, so the heading cannot
    // drift from the ring drawn on the map or from what was actually searched.
    final radius = radiusKm < 1
        ? formatDistance(radiusKm, isTh: isTh)
        : (isTh ? '${_trim(radiusKm)} กม.' : '${_trim(radiusKm)} km');

    return Text(
      appText(context, 'around_title').replaceFirst('{radius}', radius),
      style: const TextStyle(
        color: _navy,
        fontSize: 14.5,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  static String _trim(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';
}

class _CountTiles extends StatelessWidget {
  const _CountTiles({
    required this.result,
    required this.zones,
    required this.partners,
  });

  final RadarResult result;
  final List<RadarZoneEntry> zones;
  final List<RadarPartnerEntry> partners;

  @override
  Widget build(BuildContext context) {
    int zonesOf(String risk) =>
        zones.where((z) => z.zone.riskLevel == risk).length;

    return Row(
      children: [
        _Tile(
          label: appText(context, 'radar_group_zone_safe'),
          count: zonesOf('safe'),
          color: _green,
          unitKey: 'around_unit_areas',
        ),
        const SizedBox(width: 8),
        _Tile(
          label: appText(context, 'radar_group_zone_caution'),
          count: zonesOf('caution'),
          color: _amber,
          unitKey: 'around_unit_areas',
        ),
        const SizedBox(width: 8),
        _Tile(
          label: appText(context, 'radar_group_zone_danger'),
          count: zonesOf('danger'),
          color: _red,
          unitKey: 'around_unit_areas',
        ),
        const SizedBox(width: 8),
        _Tile(
          // Every partner category counts here — a pharmacy and a police post
          // are as much "somewhere you can go" as a restaurant is, and the
          // Radar's finer grouping is one drag away.
          label: appText(context, 'radar_group_partners'),
          count: partners.length,
          color: _blue,
          unitKey: 'around_unit_places',
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.count,
    required this.color,
    required this.unitKey,
  });

  final String label;
  final int count;
  final Color color;
  final String unitKey;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              label,
              // Three lines, not two. The Thai zone labels are long — "พื้นที่
              // คำแนะนำสำหรับนักท่องเที่ยว" clipped mid-word at two lines, which
              // is worse than small: a truncated label for an area type is a
              // label that tells the user nothing. Caught on the emulator
              // 2026-08-23.
              maxLines: 3,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: const TextStyle(
                color: _navy,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              appText(context, unitKey),
              style: const TextStyle(color: _muted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, this.onViewAll});

  final String text;

  /// Null hides the link. A "view all" that goes nowhere is worse than none.
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      text,
      style: const TextStyle(
        color: _navy,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );

    if (onViewAll == null) return title;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: title),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: const Color(0xFF2E7D32),
          ),
          child: Text(
            appText(context, 'around_view_all'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AdvisoryRow extends StatelessWidget {
  const _AdvisoryRow({
    required this.entry,
    required this.isTh,
    required this.onTap,
  });

  final RadarZoneEntry entry;
  final bool isTh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDanger = entry.zone.riskLevel == 'danger';
    final color = isDanger ? _red : _amber;

    return _RowShell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            isDanger ? Icons.error_rounded : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.zone.localizedName(Localizations.localeOf(context).languageCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.zone.localizedDescription(isTh ? 'th' : 'en'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            // "You are here" beats a distance of 0 m, which reads like a
            // rounding artefact rather than the most important fact on the row.
            entry.isInside
                ? appText(context, 'radar_you_are_inside')
                : formatDistance(entry.distanceKm, isTh: isTh),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerRow extends StatelessWidget {
  const _PartnerRow({
    required this.entry,
    required this.isTh,
    required this.onTap,
  });

  final RadarPartnerEntry entry;
  final bool isTh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = entry.category;
    final color = partnerCategoryColor[category] ?? _blue;

    return _RowShell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              partnerCategoryIcon[category] ?? Icons.place_rounded,
              color: color,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.partner.localizedName(Localizations.localeOf(context).languageCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  appText(context, category.textKey),
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDistance(entry.distanceKm, isTh: isTh),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (entry.partner.rating > 0) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB300),
                      size: 13,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      entry.partner.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
