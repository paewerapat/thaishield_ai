/// Response parsing for the two network calls the SOS screen makes.
///
/// Extracted from `sos_screen.dart` so it can be tested without a widget, a
/// microphone or a network: both of these silently dropped part of what the
/// user said, and neither failure is visible in an integration test that only
/// checks "some Thai came back".
library;

/// The transcript from a Cloud Speech-to-Text **v1** `speech:recognize`
/// response.
///
/// `results` is a *repeated* field — the API documents it as "sequential list
/// of transcription results corresponding to sequential portions of audio",
/// and it starts a new entry at each pause it detects. One spoken sentence
/// with a breath in the middle therefore arrives as two or more results.
///
/// This used to read `results.first` only, so everything after the speaker's
/// first pause was thrown away: "สวัสดี ตอนนี้คุณทำอะไรอยู่ เป็นยังไงบ้าง"
/// reached the translator as "สวัสดี ตอนนี้". Every result has to be joined
/// back together, in order.
///
/// Within a single result, `alternatives` is ranked by confidence and only
/// the best one is wanted — that field really is a list of competing
/// transcriptions of the same audio, not more audio.
String? transcriptFromSpeechResponse(Map<String, dynamic> body) {
  final results = body['results'];
  if (results is! List || results.isEmpty) return null;

  final segments = <String>[];
  for (final result in results) {
    if (result is! Map) continue;
    final alternatives = result['alternatives'];
    if (alternatives is! List || alternatives.isEmpty) continue;
    final best = alternatives.first;
    if (best is! Map) continue;
    final transcript = best['transcript'];
    if (transcript is! String) continue;
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) continue;
    segments.add(trimmed);
  }

  if (segments.isEmpty) return null;
  return segments.join(' ');
}

/// The translated text from a Gemini `generateContent` response.
///
/// `parts` is also repeated, and this also used to read only the first one.
/// A part carrying `thought: true` is the model's reasoning rather than the
/// answer — returning that to a tourist to read aloud would be worse than
/// returning nothing, so those are skipped rather than joined.
String? textFromGeminiResponse(Map<String, dynamic> body) {
  final candidates = body['candidates'];
  if (candidates is! List || candidates.isEmpty) return null;

  final first = candidates.first;
  if (first is! Map) return null;
  final content = first['content'];
  if (content is! Map) return null;
  final parts = content['parts'];
  if (parts is! List || parts.isEmpty) return null;

  final chunks = <String>[];
  for (final part in parts) {
    if (part is! Map) continue;
    if (part['thought'] == true) continue;
    final text = part['text'];
    if (text is! String) continue;
    if (text.trim().isEmpty) continue;
    chunks.add(text);
  }

  if (chunks.isEmpty) return null;
  final joined = chunks.join().trim();
  return joined.isEmpty ? null : joined;
}
