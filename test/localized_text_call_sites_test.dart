import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every screen that shows a place's name or advisory must ask for the
/// **reader's** language.
///
/// 🚨 Written 2026-09-02 after the QA gate found `around_you_panel.dart` calling
/// `localizedDescription(isTh ? 'th' : 'en')`. A Chinese, Korean, Russian or
/// Japanese reader was shown English even when their translation existed — on
/// the one string in the app that describes a real place, and two lines below a
/// name that localised correctly. It survived every existing test because the
/// model itself is fine: `localizedDescription` does the right thing with
/// whatever it is handed, and nothing checked what the call sites hand it.
///
/// A source scan rather than a widget test, deliberately. A widget test proves
/// one screen under one locale; this proves the property for **every call site
/// that exists or will exist**, which is what actually failed here — one of
/// fifteen call sites was wrong while fourteen were right.
///
/// The model's own fallback to English stays the only fallback: a blank column
/// is a missing translation, and that is `localizedDescription`'s business, not
/// the caller's.
void main() {
  final callPattern = RegExp(
    r'localized(?:Name|Description)\(([^)]*)\)',
    dotAll: true,
  );

  /// A language argument is acceptable when it names the reader's locale.
  /// Anything else — a literal, a ternary between two literals — is a caller
  /// deciding on the reader's behalf.
  bool readsTheReadersLocale(String argument) {
    final a = argument.trim();
    return a.contains('Localizations.localeOf') ||
        a.contains('langCode') ||
        a.contains('languageCode') ||
        a.contains('locale.');
  }

  test('every localizedName/localizedDescription call reads the real locale',
      () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();

      for (final match in callPattern.allMatches(source)) {
        final argument = match.group(1) ?? '';
        if (argument.trim().isEmpty) continue;
        if (readsTheReadersLocale(argument)) continue;

        final line = source.substring(0, match.start).split('\n').length;
        offenders.add(
          '${entity.path}:$line  ->  ${match.group(0)!.replaceAll('\n', ' ')}',
        );
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These call sites pick a language for the reader instead of '
          'reading theirs. A hard-coded pair like `isTh ? \'th\' : \'en\'` '
          'shows English to four of the six languages the app offers:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the scan actually finds the call sites it is guarding', () {
    // 🚨 A source-scanning test that matches nothing passes forever. This one
    // would have gone green if the regex were wrong, the folder moved, or the
    // methods were renamed — which is exactly how a guard quietly stops
    // guarding. Pin that it still sees a realistic number of call sites.
    var found = 0;
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      found += callPattern.allMatches(entity.readAsStringSync()).length;
    }
    expect(found, greaterThanOrEqualTo(10),
        reason: 'the scan found $found call sites; it used to find 15, so '
            'either the methods were renamed or the pattern stopped matching');
  });
}
