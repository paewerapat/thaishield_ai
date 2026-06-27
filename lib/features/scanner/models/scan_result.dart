import 'package:flutter/material.dart';
import '../../../core/models/price_standard.dart';

enum VarianceLevel { below, within, above, significant }

class ScanResult {
  const ScanResult({
    required this.standard,
    required this.detectedPrice,
    required this.variancePercent,
    required this.level,
  });

  final PriceStandard standard;
  final double detectedPrice;
  final double variancePercent;
  final VarianceLevel level;

  static ScanResult fromDetection(PriceStandard standard, double detectedPrice) {
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
