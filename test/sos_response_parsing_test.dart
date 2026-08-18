import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thaishield_ai/features/sos/services/sos_response_parsing.dart';

void main() {
  group('transcriptFromSpeechResponse', () {
    test('joins every result, not just the first', () {
      // The bug as reported on 2026-08-18: the user said
      // "สวัสดี ตอนนี้คุณทำอะไรอยู่ เป็นยังไงบ้าง" and only "สวัสดี ตอนนี้"
      // reached the translator. Cloud Speech-to-Text v1 returns one `results`
      // entry per portion of audio between pauses; reading `results.first`
      // discarded everything the speaker said after their first breath.
      final body = jsonDecode('''
      {
        "results": [
          {"alternatives": [{"transcript": "สวัสดี ตอนนี้", "confidence": 0.9}]},
          {"alternatives": [{"transcript": "คุณทำอะไรอยู่", "confidence": 0.9}]},
          {"alternatives": [{"transcript": "เป็นยังไงบ้าง", "confidence": 0.9}]}
        ]
      }
      ''') as Map<String, dynamic>;

      expect(
        transcriptFromSpeechResponse(body),
        'สวัสดี ตอนนี้ คุณทำอะไรอยู่ เป็นยังไงบ้าง',
      );
    });

    test('keeps only the best alternative within one result', () {
      // `alternatives` is competing transcriptions of the *same* audio, so
      // joining them would repeat what the user said.
      final body = <String, dynamic>{
        'results': [
          {
            'alternatives': [
              {'transcript': 'help me', 'confidence': 0.94},
              {'transcript': 'kelp me', 'confidence': 0.41},
            ],
          },
        ],
      };

      expect(transcriptFromSpeechResponse(body), 'help me');
    });

    test('skips malformed and empty segments instead of dropping the rest',
        () {
      final body = <String, dynamic>{
        'results': [
          {'alternatives': []},
          {'alternatives': [{'transcript': '   '}]},
          {'noAlternatives': true},
          {'alternatives': [{'transcript': 'my passport is gone'}]},
        ],
      };

      expect(transcriptFromSpeechResponse(body), 'my passport is gone');
    });

    test('returns null when nothing was recognised', () {
      expect(transcriptFromSpeechResponse(<String, dynamic>{}), isNull);
      expect(
        transcriptFromSpeechResponse(<String, dynamic>{'results': []}),
        isNull,
      );
      expect(
        transcriptFromSpeechResponse(<String, dynamic>{
          'results': [
            {'alternatives': [{'transcript': ''}]},
          ],
        }),
        isNull,
      );
    });
  });

  group('textFromGeminiResponse', () {
    test('joins every text part', () {
      final body = <String, dynamic>{
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'สวัสดีครับ ตอนนี้'},
                {'text': 'คุณเป็นยังไงบ้างครับ'},
              ],
            },
          },
        ],
      };

      expect(
        textFromGeminiResponse(body),
        'สวัสดีครับ ตอนนี้คุณเป็นยังไงบ้างครับ',
      );
    });

    test('never returns the model reasoning as the translation', () {
      // A `thought` part is the model thinking out loud. Reading parts.first
      // blindly would hand that to a tourist to show a Thai stranger.
      final body = <String, dynamic>{
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'The user is asking for help. I should…', 'thought': true},
                {'text': 'ช่วยด้วยครับ'},
              ],
            },
          },
        ],
      };

      expect(textFromGeminiResponse(body), 'ช่วยด้วยครับ');
    });

    test('returns null when the response carries no usable text', () {
      expect(textFromGeminiResponse(<String, dynamic>{}), isNull);
      expect(
        textFromGeminiResponse(<String, dynamic>{'candidates': []}),
        isNull,
      );
      expect(
        textFromGeminiResponse(<String, dynamic>{
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'thinking…', 'thought': true},
                ],
              },
            },
          ],
        }),
        isNull,
      );
    });
  });
}
