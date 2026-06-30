import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/models/price_standard.dart';
import '../models/scan_result.dart';

class PriceScanService {
  PriceScanService._();
  static final instance = PriceScanService._();

  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _priceRegex = RegExp(r'\d+(?:[.,]\d{1,2})?');

  Future<String> recognizeText(File imageFile) async {
    final input = InputImage.fromFile(imageFile);
    final result = await _recognizer.processImage(input);
    return result.text;
  }

  /// Matches each line of recognized [text] against the cached [standards]
  /// list, picking the nearest price number found on that line. [latitude]
  /// and [longitude] (the device's location when the photo was taken) are
  /// carried through to each result so the user can revisit their scan spot.
  List<ScanResult> matchPrices(
    String text,
    List<PriceStandard> standards, {
    double? latitude,
    double? longitude,
  }) {
    final lines = text.split('\n');
    final results = <ScanResult>[];
    final matchedIds = <String>{};

    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final standard in standards) {
        if (matchedIds.contains(standard.id)) continue;
        if (!lower.contains(standard.nameEn.toLowerCase())) continue;

        final numbers = _priceRegex
            .allMatches(line)
            .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '')))
            .whereType<double>()
            .where((n) => n > 0)
            .toList();
        if (numbers.isEmpty) continue;

        final detectedPrice = numbers.reduce((a, b) => a > b ? a : b);
        results.add(ScanResult.fromDetection(
          standard,
          detectedPrice,
          latitude: latitude,
          longitude: longitude,
        ));
        matchedIds.add(standard.id);
      }
    }
    return results;
  }

  /// Finds the [PriceStandard] whose English name best matches [dishName]
  /// (e.g. a name identified by Gemini Vision from a food photo).
  PriceStandard? findStandardByName(String dishName, List<PriceStandard> standards) {
    final lower = dishName.toLowerCase().trim();

    for (final standard in standards) {
      if (standard.nameEn.toLowerCase() == lower) return standard;
    }
    for (final standard in standards) {
      final name = standard.nameEn.toLowerCase();
      if (lower.contains(name) || name.contains(lower)) return standard;
    }
    return null;
  }

  void dispose() => _recognizer.close();
}
