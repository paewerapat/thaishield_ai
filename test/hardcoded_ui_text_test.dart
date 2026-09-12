import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No screen may print a string literal at the user.
///
/// 🚨 Written 2026-09-12, after the client reported that "some parts still do
/// not change with the language — the app's home screen, for example". They
/// were right, and the Home tab was the clearest case: of the five tiles under
/// *Useful Tools*, `Safety Radar` and `Safety Tips` came from `appText` while
/// `AI Price Scanner`, `Smart Map` and `AI Voice SOS` were English literals
/// sitting beside them. On the first screen of the app, in every language.
///
/// **Why nothing caught it.** `wording_test.dart` reads `appStrings`, so a
/// string that never reaches the table is invisible to it; it scans exactly
/// one file as source (`map_screen.dart`, and only `label:`) because that is
/// where the last outbreak was found in August. `localized_text_call_sites_test.dart`
/// guards the other half — CMS content asking for the reader's language — and
/// says nothing about static chrome. The gap between the two is precisely
/// where these three tiles lived.
///
/// This is a **source scan**, like its two siblings, and for the same reason:
/// a widget test proves one screen under one locale, while the failure mode
/// here is one call site out of hundreds being written the lazy way. The scan
/// covers every file that exists or will exist.
void main() {
  /// Widget arguments whose value is read aloud by a human being.
  const argumentPatterns = <String>[
    r'Text\(\s*',
    r'SelectableText\(\s*',
    r'label:\s*',
    r'labelText:\s*',
    r'hintText:\s*',
    r'helperText:\s*',
    r'errorText:\s*',
    r'tooltip:\s*',
    r'semanticLabel:\s*',
    r'title:\s*',
    r'subtitle:\s*',
  ];

  /// Literals that are correctly **not** translated, each with the reason it
  /// is allowed. Keyed by file so the same word cannot be waved through
  /// somewhere it has not been thought about.
  ///
  /// Keep this list short and argue every entry. A brand name and a language's
  /// own name are the only two honest reasons a literal survives here; the
  /// third is copy that only a developer ever sees.
  const allowed = <String, Set<String>>{
    // The product name. Identical in all six languages by design — it is how
    // the app is listed in both stores.
    'lib/main.dart': {'ThaiShield'},
    'lib/features/home/widgets/home_tab.dart': {'ThaiShield AI'},
    'lib/features/scanner/screens/scanner_screen.dart': {'ThaiShield AI'},
    'lib/features/sos/screens/sos_screen.dart': {'ThaiShield AI'},
    'lib/features/radar/screens/radar_screen.dart': {'ThaiShield AI'},
    'lib/features/route/screens/route_preview_screen.dart': {'ThaiShield AI'},
    'lib/features/premium/screens/paywall_screen.dart': {'ThaiShield AI'},
    // Profile shows the brand, and — in debug builds only — the QA unlock
    // switch, which no tourist can reach. `premium_test.dart` pins that it
    // cannot exist in a release build.
    'lib/features/profile/screens/profile_screen.dart': {
      'ThaiShield AI',
      'QA: unlock Premium',
    },
    // 🚨 The one screen that must NOT be localised. It is shown before a
    // language has been chosen, and every option names itself in its own
    // script so a reader can find their own line without already reading one
    // of the other five.
    'lib/features/onboarding/screens/language_selection_screen.dart': {
      'ไทย / Thai',
      'English',
      '中文 / Chinese',
      '한국어 / Korean',
      'Русский / Russian',
      '日本語 / Japanese',
      'ThaiShield ',
      'AI',
      'เที่ยวไทย ปลอดภัย ฉลาดเลือก',
      "don't get lost, stay informed",
    },
  };

  /// Does this literal read as something a person would be shown?
  ///
  /// Deliberately generous about what counts as prose and deliberately silent
  /// about interpolations: `Text('$spokenText')` is the user's own words being
  /// echoed back, which is data, not chrome.
  bool isUserFacingProse(String literal) {
    final text = literal.trim();
    if (text.length < 2) return false;
    if (text.contains(r'$')) return false; // interpolated data, not a label
    // Any non-Latin script here is real copy — no key is written in Thai.
    final hasThaiOrCjkOrCyrillic = RegExp(
      r'[฀-๿぀-ヿ一-鿿가-힯Ѐ-ӿ]',
    ).hasMatch(text);
    if (hasThaiOrCjkOrCyrillic) return true;
    if (!RegExp(r'[A-Za-z]').hasMatch(text)) return false;
    if (text.startsWith('assets/') || text.startsWith('http')) return false;
    // An appText key, an enum value, a Firestore field: lower_snake_case.
    if (RegExp(r'^[a-z0-9_.]+$').hasMatch(text)) return false;
    // A single bare word is far more often an identifier than a sentence.
    if (!text.contains(' ')) return false;
    return true;
  }

  final literalArgument = RegExp(
    '(?:${argumentPatterns.join('|')})'
    r'''(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")''',
  );

  test('no screen prints a string literal at the user', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');

      // The localization table itself is nothing but literals, and the seed
      // scripts write sample Firestore rows rather than draw anything.
      //
      // `lib/l10n/` used to be skipped here too. It was deleted on 2026-09-12
      // — the ARB/AppLocalizations path was never wired up — and the entry
      // went with it rather than being left as a standing exemption for a
      // directory nothing would notice coming back.
      if (path.startsWith('lib/core/localization/')) continue;
      if (path.startsWith('lib/tools/')) continue;
      if (path.endsWith('firebase_options.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

        for (final match in literalArgument.allMatches(line)) {
          final literal = match.group(1) ?? match.group(2) ?? '';
          if (!isUserFacingProse(literal)) continue;
          if (allowed[path]?.contains(literal) ?? false) continue;
          offenders.add('$path:${i + 1}  ->  "$literal"');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These strings are printed at the user without going through '
          '`appText`, so they stay in one language whatever the reader picked. '
          'Move each into `lib/core/localization/app_text.dart` with all six '
          'languages — or, if it is genuinely a brand name or a language\'s '
          'own name, add it to `allowed` above **with the reason**:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the scan actually reaches the screens it is guarding', () {
    // 🚨 A source scan that matches nothing passes forever. The sibling test
    // `localized_text_call_sites_test.dart` carries the same guard for the
    // same reason: this one would go green if `lib/` moved, if the regex
    // stopped matching, or if someone narrowed the argument list to nothing.
    var literalsFound = 0;
    var filesScanned = 0;
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      filesScanned++;
      literalsFound +=
          literalArgument.allMatches(entity.readAsStringSync()).length;
    }

    expect(filesScanned, greaterThanOrEqualTo(30),
        reason: 'only $filesScanned Dart files found under lib/');
    expect(literalsFound, greaterThanOrEqualTo(10),
        reason: 'the pattern matched $literalsFound literal arguments across '
            'the whole app, which means it has stopped matching rather than '
            'that the app has stopped having any');
  });

  test('every allowlisted literal is still in the file that claims it', () {
    // An allowlist outlives the code it excuses. Once a literal is gone, its
    // entry is a standing permission for that exact string to come back
    // somewhere it was never argued for.
    for (final entry in allowed.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} no longer exists');
      final source = file.readAsStringSync();
      for (final literal in entry.value) {
        expect(
          source.contains(literal),
          isTrue,
          reason: '"$literal" is allowlisted for ${entry.key} but no longer '
              'appears there — delete the entry rather than leaving a blanket '
              'exemption behind.',
        );
      }
    }
  });
}
