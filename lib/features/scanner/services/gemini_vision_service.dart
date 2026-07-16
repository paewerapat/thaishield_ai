import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_keys.dart';

class GeminiVisionService {
  GeminiVisionService._();
  static final instance = GeminiVisionService._();

  static const _model = 'gemini-2.5-flash-001';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent';

  /// Identifies the dish shown in [imageFile] by matching it against
  /// [knownDishNames] (the English names already in our `price_standards`
  /// Firestore collection). Returns the exact matching name from that list,
  /// or null if no specific known dish could be identified.
  /// [latitude]/[longitude] are optional and only used as context to
  /// disambiguate regional dishes.
  Future<String?> identifyDish(
    File imageFile, {
    required List<String> knownDishNames,
    double? latitude,
    double? longitude,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final locationContext = (latitude != null && longitude != null)
        ? 'The photo was taken near latitude $latitude, longitude $longitude in Thailand. '
            'Use this only to help disambiguate regional dish names — never mention the '
            'location in your answer.'
        : '';

    final dishList = knownDishNames.map((n) => '- $n').join('\n');

    final prompt =
        'You are identifying a Thai food or drink dish from a photo for a travel app. '
        '$locationContext '
        'Look at the photo and decide which ONE of the following known dish names it matches '
        '(copy the name EXACTLY as written below, character for character — do not '
        'paraphrase, translate, or invent a new name):\n$dishList\n\n'
        'If the photo does not clearly match any dish in that list, set dish_name to '
        '"UNKNOWN". Do not mention any restaurant, shop, brand, or location in your answer.';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'dish_name': {'type': 'STRING'},
          },
          'required': ['dish_name'],
        },
      },
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_endpoint?key=${ApiKeys.gemini}'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final parts = (candidates.first['content']?['parts'] as List?) ?? [];
      if (parts.isEmpty) return null;

      final text = parts.first['text'] as String?;
      if (text == null || text.trim().isEmpty) return null;

      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final dishName = (parsed['dish_name'] as String?)?.trim();
      if (dishName == null || dishName.isEmpty || dishName.toUpperCase() == 'UNKNOWN') {
        return null;
      }
      return dishName;
    } catch (_) {
      return null;
    }
  }
}
