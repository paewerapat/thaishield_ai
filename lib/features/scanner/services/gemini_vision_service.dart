import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/api_keys.dart';
import '../models/dish_identification.dart';

class GeminiVisionService {
  GeminiVisionService._();
  static final instance = GeminiVisionService._();

  static const _model = 'gemini-3.5-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// Identifies the dish shown in [imageFile].
  ///
  /// First against [knownDishNames] (the English names already in our
  /// `price_standards` collection). If it is none of those, the model is asked
  /// what the dish actually is and what it typically costs, so a dish missing
  /// from the collection produces a clearly-labelled estimate instead of the
  /// dead end it used to.
  ///
  /// [latitude]/[longitude] are optional and only used as context to
  /// disambiguate regional dish names — never stored, and never turned into
  /// location-specific pricing.
  ///
  /// Returns null only when the request itself failed.
  Future<DishIdentification?> identifyDish(
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
        'If it matches one of them, put that name in dish_name and leave the other fields '
        'empty.\n\n'
        'If the photo does NOT match any dish in that list, set dish_name to "UNKNOWN" and '
        'instead: put the common English name of the dish in generic_name_en, its Thai name '
        'in generic_name_th, and the price a customer in Thailand would typically pay for '
        'one ordinary serving in estimated_min_thb and estimated_max_thb. Give a realistic '
        'range that covers ordinary places rather than a single figure, and set confidence '
        'to "low" whenever you are unsure what the dish is or what it costs.\n\n'
        'If you cannot tell what the food is at all, set dish_name to "UNKNOWN" and '
        'confidence to "low".\n\n'
        'Never mention any restaurant, shop, brand, or location in your answer, and never '
        'suggest that any price is unfair, too high, or a scam — state prices only as '
        'neutral information.';

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
            'generic_name_en': {'type': 'STRING'},
            'generic_name_th': {'type': 'STRING'},
            'estimated_min_thb': {'type': 'NUMBER'},
            'estimated_max_thb': {'type': 'NUMBER'},
            'confidence': {
              'type': 'STRING',
              'enum': ['high', 'medium', 'low'],
            },
          },
          'required': ['dish_name', 'confidence'],
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
      return identificationFromGeminiResponse(decoded);
    } catch (_) {
      return null;
    }
  }
}

/// Parses the vision response. Separate from the request so it can be tested
/// without a network or a photo.
DishIdentification? identificationFromGeminiResponse(
  Map<String, dynamic> body,
) {
  final candidates = body['candidates'];
  if (candidates is! List || candidates.isEmpty) return null;
  final first = candidates.first;
  if (first is! Map) return null;
  final content = first['content'];
  if (content is! Map) return null;
  final parts = content['parts'];
  if (parts is! List || parts.isEmpty) return null;

  // Same repeated-field trap as the SOS parsers: take every non-thought part,
  // because the JSON payload can arrive split across more than one.
  final buffer = StringBuffer();
  for (final part in parts) {
    if (part is! Map) continue;
    if (part['thought'] == true) continue;
    final text = part['text'];
    if (text is String) buffer.write(text);
  }
  final raw = buffer.toString().trim();
  if (raw.isEmpty) return null;

  final Map<String, dynamic> parsed;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    parsed = decoded;
  } catch (_) {
    return null;
  }

  final dishName = (parsed['dish_name'] as String?)?.trim();
  final isKnown =
      dishName != null && dishName.isNotEmpty && dishName.toUpperCase() != 'UNKNOWN';

  double? asPrice(Object? value) {
    final number = value is num ? value.toDouble() : null;
    if (number == null || number <= 0 || !number.isFinite) return null;
    return number;
  }

  return DishIdentification(
    knownDishName: isKnown ? dishName : null,
    genericNameEn: (parsed['generic_name_en'] as String?)?.trim(),
    genericNameTh: (parsed['generic_name_th'] as String?)?.trim(),
    estimatedMin: asPrice(parsed['estimated_min_thb']),
    estimatedMax: asPrice(parsed['estimated_max_thb']),
    confidence: parseDishConfidence(parsed['confidence'] as String?),
  );
}
