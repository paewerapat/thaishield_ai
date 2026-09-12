import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The iOS permission dialogs, and the Xcode wiring that ships them.
///
/// 🚨 Added 2026-09-12, in the same round as the in-app localization sweep
/// (CLAUDE.md §10.1). Until that day the five `NS*UsageDescription` strings
/// existed only in English: no `*.lproj` beside `Info.plist`, and nothing in
/// `knownRegions`. A Korean, Russian or Japanese phone met English at the
/// camera, microphone and location prompts — for most users the **first**
/// sentence the app ever shows, and shown before any Dart code runs.
///
/// **Why this is a test and not a build.** CLAUDE.md §1: there is no Mac on
/// this project, and iOS is built by Codemagic. A localized resource is wired
/// up in `project.pbxproj`, which nothing else here validates, and the usual
/// failure is silent — a `.lproj` that exists on disk, is never registered,
/// and is simply absent from the bundle. Nobody would notice until a reviewer
/// or a tourist saw English. So the wiring is asserted from Dart, on Windows,
/// on every `flutter test`.
///
/// ⚠️ **These strings follow the DEVICE language, not the app's picker.** iOS
/// presents the prompt itself, before the app is consulted, so a phone set to
/// English shows the English line even if the user chose Korean inside the
/// app. There is no supported way around that, and it is not a bug to "fix"
/// later — it is the boundary between the two.
void main() {
  const locales = <String, String>{
    // Flutter language code -> iOS .lproj directory. They differ for Chinese:
    // Apple identifies it by script, and a device set to 简体中文 reports
    // zh-Hans-CN, so plain `zh.lproj` would not be selected.
    'en': 'en',
    'th': 'th',
    'zh': 'zh-Hans',
    'ko': 'ko',
    'ru': 'ru',
    'ja': 'ja',
  };

  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  final pbxproj =
      File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  /// The purpose strings iOS shows in a permission alert.
  Set<String> usageKeysIn(String plist) => RegExp(r'<key>(NS\w*UsageDescription)</key>')
      .allMatches(plist)
      .map((m) => m.group(1)!)
      .toSet();

  Map<String, String> parseStrings(String source) {
    final withoutComments = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    final entries = <String, String>{};
    for (final match in RegExp(r'"([^"]+)"\s*=\s*"([^"]*)"\s*;')
        .allMatches(withoutComments)) {
      entries[match.group(1)!] = match.group(2)!;
    }
    return entries;
  }

  group('the six InfoPlist.strings files', () {
    test('one exists for every language the app ships', () {
      for (final directory in locales.values) {
        final file = File('ios/Runner/$directory.lproj/InfoPlist.strings');
        expect(file.existsSync(), isTrue,
            reason: 'missing ios/Runner/$directory.lproj/InfoPlist.strings');
        expect(parseStrings(file.readAsStringSync()), isNotEmpty,
            reason: '$directory.lproj/InfoPlist.strings parsed to nothing — '
                'check the "KEY" = "value"; syntax');
      }
    });

    test('every usage description in Info.plist is translated in all six', () {
      final required = usageKeysIn(infoPlist);
      expect(required, isNotEmpty,
          reason: 'no NS*UsageDescription found in Info.plist — the scan has '
              'stopped matching rather than the app having stopped asking');

      for (final entry in locales.entries) {
        final strings = parseStrings(
          File('ios/Runner/${entry.value}.lproj/InfoPlist.strings')
              .readAsStringSync(),
        );
        for (final key in required) {
          expect(strings[key]?.trim(), isNotEmpty,
              reason: '$key is declared in Info.plist but ${entry.value}.lproj '
                  'has no translation, so that language silently falls back to '
                  'the English compiled into Info.plist');
        }
      }
    });

    test('no file carries a key that Info.plist does not declare', () {
      // A stray key is dead weight that reads as coverage. It also hides a
      // typo: a misspelled key looks translated and never reaches a dialog.
      final allowed = usageKeysIn(infoPlist);
      for (final directory in locales.values) {
        final strings = parseStrings(
          File('ios/Runner/$directory.lproj/InfoPlist.strings').readAsStringSync(),
        );
        for (final key in strings.keys) {
          expect(allowed, contains(key),
              reason: '$directory.lproj declares $key, which is not in '
                  'Info.plist — a typo, or a leftover');
        }
      }
    });

    test('the five languages actually differ from English', () {
      // The whole point. Copying the English across six files would satisfy
      // every other test in this group.
      final english = parseStrings(
        File('ios/Runner/en.lproj/InfoPlist.strings').readAsStringSync(),
      );
      for (final entry in locales.entries) {
        if (entry.key == 'en') continue;
        final strings = parseStrings(
          File('ios/Runner/${entry.value}.lproj/InfoPlist.strings')
              .readAsStringSync(),
        );
        for (final key in english.keys) {
          expect(strings[key], isNot(english[key]),
              reason: '${entry.value}.lproj/$key is identical to the English. '
                  'If that is ever genuinely right, it is not right for a '
                  'sentence this long.');
        }
      }
    });

    test('no purpose string promises a language the app does not accept', () {
      // 🚨 `NSSpeechRecognitionUsageDescription` said "your spoken English"
      // until 2026-09-12, while SOS has accepted six STT locales since it
      // shipped (CLAUDE.md §2.3). A purpose string that misdescribes what the
      // app does with the data is exactly what App Review reads.
      final english = parseStrings(
        File('ios/Runner/en.lproj/InfoPlist.strings').readAsStringSync(),
      );
      final speech = english['NSSpeechRecognitionUsageDescription'];
      if (speech != null) {
        expect(speech.toLowerCase(), isNot(contains('english')),
            reason: 'the speech purpose string names English specifically, but '
                'SOS transcribes th/en/zh/ko/ru/ja');
      }

      // Info.plist is the fallback for any language with no .lproj of its own,
      // so the same sentence has to be right there too — it was the one that
      // was actually wrong, and fixing only en.lproj would have left it.
      final plistSpeech = RegExp(
        r'<key>NSSpeechRecognitionUsageDescription</key>\s*<string>([^<]*)</string>',
      ).firstMatch(infoPlist)?.group(1);
      if (plistSpeech != null) {
        expect(plistSpeech.toLowerCase(), isNot(contains('english')),
            reason: 'Info.plist still names English as the spoken language');
      }
    });
  });

  group('the Xcode wiring, which is the half that silently does nothing', () {
    test('every .lproj is registered as a file reference', () {
      for (final directory in locales.values) {
        expect(pbxproj, contains('$directory.lproj/InfoPlist.strings'),
            reason: '$directory.lproj exists on disk but is not referenced in '
                'project.pbxproj, so Xcode will not copy it into the bundle');
      }
    });

    test('every locale is in knownRegions', () {
      // Xcode drops a localization whose region is not declared here, without
      // an error.
      final regions = RegExp(r'knownRegions = \(([^)]*)\)', dotAll: true)
          .firstMatch(pbxproj)
          ?.group(1);
      expect(regions, isNotNull, reason: 'knownRegions not found');
      for (final directory in locales.values) {
        expect(regions, contains(directory),
            reason: '$directory missing from knownRegions');
      }
    });

    test('the variant group enters the Resources phase as a PBXBuildFile', () {
      // 🚨 The realistic way to get this wrong: put the PBXVariantGroup's own
      // id into `files = (...)` instead of the PBXBuildFile that wraps it.
      // Xcode's UI tolerates a lot; the build does not.
      final variantGroup = RegExp(
        r'([0-9A-F]{24}) /\* InfoPlist\.strings \*/ = \{\s*isa = PBXVariantGroup;',
      ).firstMatch(pbxproj);
      expect(variantGroup, isNotNull,
          reason: 'no PBXVariantGroup named InfoPlist.strings');
      final groupId = variantGroup!.group(1)!;

      final buildFile = RegExp(
        r'([0-9A-F]{24}) /\* InfoPlist\.strings in Resources \*/ = '
        '\\{isa = PBXBuildFile; fileRef = $groupId',
      ).firstMatch(pbxproj);
      expect(buildFile, isNotNull,
          reason: 'no PBXBuildFile wrapping the InfoPlist.strings variant '
              'group');

      expect(
        pbxproj,
        contains('${buildFile!.group(1)!} /* InfoPlist.strings in Resources */,'),
        reason: 'the build file is never added to a Resources build phase',
      );
    });

    test('the variant group lists all six locales as children', () {
      final children = RegExp(
        r'/\* InfoPlist\.strings \*/ = \{\s*isa = PBXVariantGroup;\s*'
        r'children = \(([^)]*)\)',
        dotAll: true,
      ).firstMatch(pbxproj)?.group(1);
      expect(children, isNotNull);
      for (final directory in locales.values) {
        expect(children, contains(directory),
            reason: '$directory is not a child of the variant group, so it is '
                'not part of the localized resource');
      }
    });

    test('no object id is defined twice', () {
      // A duplicated id corrupts the project in ways Xcode reports as
      // something else entirely. Cheap to assert, and this file was
      // hand-edited.
      final ids = RegExp(r'^\t\t([0-9A-F]{24}) ', multiLine: true)
          .allMatches(pbxproj)
          .map((m) => m.group(1)!)
          .toList();
      final seen = <String>{};
      final duplicates = ids.where((id) => !seen.add(id)).toSet();
      expect(duplicates, isEmpty, reason: 'duplicate object ids: $duplicates');
    });
  });
}
