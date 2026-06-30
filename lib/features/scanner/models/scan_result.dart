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

  bool get hasLocation => latitude != null && longitude != null;

  /// True when this result only identifies the dish (e.g. via Gemini Vision
  /// from a food photo) with no price actually read from the image — so we
  /// show the typical reference range instead of a variance comparison.
  bool get isReferenceOnly => detectedPrice == null;

  static ScanResult referenceOnly(PriceStandard standard, {double? latitude, double? longitude}) {
    return ScanResult(standard: standard, latitude: latitude, longitude: longitude);
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
