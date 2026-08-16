import '../../../core/models/partner_category.dart';

/// The three `alert_zones.risk_level` values, in the order the Filter panel
/// lists them.
const alertZoneRiskLevels = <String>['safe', 'caution', 'danger'];

/// What the Radar is currently allowed to return (Phase 2A task 2.3).
/// Everything is selected by default — a filter only ever narrows.
class RadarFilters {
  const RadarFilters({required this.categories, required this.riskLevels});

  final Set<PartnerCategory> categories;
  final Set<String> riskLevels;

  factory RadarFilters.all() => RadarFilters(
        categories: PartnerCategory.values.toSet(),
        riskLevels: alertZoneRiskLevels.toSet(),
      );

  factory RadarFilters.none() => const RadarFilters(
        categories: <PartnerCategory>{},
        riskLevels: <String>{},
      );

  bool get isAll =>
      categories.length == PartnerCategory.values.length &&
      riskLevels.length == alertZoneRiskLevels.length;

  /// How many options are switched off — what the "N filters active" chip
  /// counts. 0 means "showing everything".
  int get activeCount =>
      (PartnerCategory.values.length - categories.length) +
      (alertZoneRiskLevels.length - riskLevels.length);

  RadarFilters copyWith({
    Set<PartnerCategory>? categories,
    Set<String>? riskLevels,
  }) =>
      RadarFilters(
        categories: categories ?? this.categories,
        riskLevels: riskLevels ?? this.riskLevels,
      );

  RadarFilters toggleCategory(PartnerCategory category) {
    final next = Set<PartnerCategory>.of(categories);
    if (!next.remove(category)) next.add(category);
    return copyWith(categories: next);
  }

  RadarFilters toggleRiskLevel(String riskLevel) {
    final next = Set<String>.of(riskLevels);
    if (!next.remove(riskLevel)) next.add(riskLevel);
    return copyWith(riskLevels: next);
  }
}
