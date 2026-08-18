import 'package:flutter/material.dart';
import '../../../core/models/price_standard.dart';

enum VarianceLevel { below, within, above, significant }

class ScanResult {
  const ScanResult({
    required this.standard,
    this.detectedPrice,
    this.variancePercent,
    this.level,
    this.latitude,
    this.longitude,
    this.isAiEstimated = false,
  });

  final PriceStandard standard;
  final double? detectedPrice;
  final double? variancePercent;
  final VarianceLevel? level;

  /// Where the photo was taken (device GPS), so the user can revisit their
  /// own scan location on a map. This is the user's own location reading —
  /// never a business identity or address — so it does not conflict with
  /// the "never display shop names/locations" rule for scan results.
  final double? latitude;
  final double? longitude;

  /// True when [standard] is not a `price_standards` document at all but a
  /// range Gemini guessed for a dish we do not carry. Nothing here was
  /// reviewed by staff, so the UI labels it and never dresses it up as a
  /// standard (`CLAUDE.md` §10).
  final bool isAiEstimated;

  bool get hasLocation => latitude != null && longitude != null;

  /// True when this result only identifies the dish (e.g. via Gemini Vision
  /// from a food photo) with no price actually read from the image — so we
  /// show the typical reference range instead of a variance comparison.
  bool get isReferenceOnly => detectedPrice == null;

  static ScanResult referenceOnly(PriceStandard standard, {double? latitude, double? longitude}) {
    return ScanResult(standard: standard, latitude: latitude, longitude: longitude);
  }

  /// A dish that is not in `price_standards`, carrying the model's own range.
  ///
  /// The synthetic [PriceStandard] exists so the results UI can stay one code
  /// path; [isAiEstimated] is what the UI branches on. Its `id` is empty on
  /// purpose — nothing may look this up, write it back, or treat it as a
  /// document. Only `en` and `th` names come back from the model, so the other
  /// four languages fall back to the English name, which for a dish name is
  /// usually the romanisation a traveller would say out loud anyway.
  static ScanResult aiEstimated({
    required String nameEn,
    required String nameTh,
    required double minPrice,
    required double maxPrice,
    double? latitude,
    double? longitude,
  }) {
    return ScanResult(
      standard: PriceStandard(
        id: '',
        nameEn: nameEn,
        nameTh: nameTh.isEmpty ? nameEn : nameTh,
        nameZh: nameEn,
        nameKo: nameEn,
        nameRu: nameEn,
        nameJa: nameEn,
        minPrice: minPrice,
        maxPrice: maxPrice,
        category: 'food',
        updatedAt: DateTime.now(),
      ),
      latitude: latitude,
      longitude: longitude,
      isAiEstimated: true,
    );
  }

  static ScanResult fromDetection(
    PriceStandard standard,
    double detectedPrice, {
    double? latitude,
    double? longitude,
  }) {
    final avg = standard.avgPrice;
    final pct = avg == 0 ? 0.0 : ((detectedPrice - avg) / avg) * 100;

    VarianceLevel level;
    if (detectedPrice >= standard.minPrice && detectedPrice <= standard.maxPrice) {
      level = VarianceLevel.within;
    } else if (pct > 30) {
      level = VarianceLevel.significant;
    } else if (pct > 0) {
      level = VarianceLevel.above;
    } else {
      level = VarianceLevel.below;
    }

    return ScanResult(
      standard: standard,
      detectedPrice: detectedPrice,
      variancePercent: pct,
      level: level,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

const Map<VarianceLevel, Color> varianceColors = {
  VarianceLevel.below: Color(0xFF4FC3F7),
  VarianceLevel.within: Color(0xFF2E7D32),
  VarianceLevel.above: Color(0xFFFFB300),
  VarianceLevel.significant: Color(0xFFEF5350),
};

const Map<VarianceLevel, String> varianceTextKey = {
  VarianceLevel.below: 'variance_below',
  VarianceLevel.within: 'variance_within',
  VarianceLevel.above: 'variance_above',
  VarianceLevel.significant: 'variance_significant',
};
