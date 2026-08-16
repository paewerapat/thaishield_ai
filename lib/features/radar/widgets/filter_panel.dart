import 'package:flutter/material.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/models/partner_category.dart';
import '../models/radar_filters.dart';

const _navy = Color(0xFF0D1B2A);
const _green = Color(0xFF2E7D32);

Color riskLevelColor(String riskLevel) {
  switch (riskLevel) {
    case 'danger':
      return const Color(0xFFEF5350);
    case 'caution':
      return const Color(0xFFFF9800);
    default:
      return const Color(0xFF4CAF50);
  }
}

IconData riskLevelIcon(String riskLevel) {
  switch (riskLevel) {
    case 'danger':
      return Icons.warning_rounded;
    case 'caution':
      return Icons.error_outline_rounded;
    default:
      return Icons.check_circle_outline_rounded;
  }
}

/// §10-safe label for a zone risk level, shared by the Radar cards and the
/// Filter panel.
String riskLevelTextKey(String riskLevel) {
  switch (riskLevel) {
    case 'danger':
      return 'radar_group_zone_danger';
    case 'caution':
      return 'radar_group_zone_caution';
    default:
      return 'radar_group_zone_safe';
  }
}

/// Opens the Filter panel and resolves to the chosen filters, or null when the
/// sheet is dismissed without applying.
Future<RadarFilters?> showRadarFilterPanel(
  BuildContext context,
  RadarFilters current,
) {
  return showModalBottomSheet<RadarFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => FilterPanel(initial: current),
  );
}

class FilterPanel extends StatefulWidget {
  const FilterPanel({super.key, required this.initial});

  final RadarFilters initial;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late RadarFilters _filters = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appText(context, 'filter_title'),
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appText(context, 'filter_subtitle'),
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _filters = _filters.isAll
                          ? RadarFilters.none()
                          : RadarFilters.all(),
                    ),
                    child: Text(
                      appText(
                        context,
                        _filters.isAll ? 'filter_clear_all' : 'filter_select_all',
                      ),
                      style: const TextStyle(
                        color: _green,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(text: appText(context, 'filter_categories')),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in PartnerCategory.values)
                          _FilterChip(
                            icon: partnerCategoryIcon[category]!,
                            color: partnerCategoryColor[category]!,
                            label: appText(context, category.textKey),
                            selected: _filters.categories.contains(category),
                            onTap: () => setState(
                              () => _filters = _filters.toggleCategory(category),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(text: appText(context, 'filter_areas')),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final risk in alertZoneRiskLevels)
                          _FilterChip(
                            icon: riskLevelIcon(risk),
                            color: riskLevelColor(risk),
                            label: appText(context, riskLevelTextKey(risk)),
                            selected: _filters.riskLevels.contains(risk),
                            onTap: () => setState(
                              () => _filters = _filters.toggleRiskLevel(risk),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(_filters),
                  child: Text(
                    appText(context, 'filter_apply'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _navy,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : const Color(0xFFE0E0E0),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? _navy : Colors.grey[600],
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_rounded, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
