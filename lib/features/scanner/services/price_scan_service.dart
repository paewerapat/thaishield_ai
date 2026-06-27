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
  /// list, picking the nearest price number found on that line.
  List<ScanResult> matchPrices(String text, List<PriceStandard> standards) {
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
        results.add(ScanResult.fromDetection(standard, detectedPrice));
        matchedIds.add(standard.id);
      }
    }
    return results;
  }

  void dispose() => _recognizer.close();
}
