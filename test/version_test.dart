import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 🚨 The patch number and the build number must stay identical.
///
/// `version: 1.1.0+25` means version **name** 1.1.0 and **build** 25 — two
/// separate things. Only the build was being bumped, so the name every user and
/// both stores would see sat at 1.1.0 for weeks while the build climbed to 25,
/// and Profile printed "1.1.0 (25)", which reads like two different versions.
///
/// They are tied together now so one number answers "which build is this".
/// Profile prints the name alone on the strength of that, and the feedback
/// email quotes it — so if these two ever drift, a bug report names a build
/// that does not exist. Bump both.
void main() {
  test('the patch number equals the build number', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$',
            multiLine: true)
        .firstMatch(pubspec);

    expect(match, isNotNull, reason: 'no version line in pubspec.yaml');

    final patch = match!.group(3);
    final build = match.group(4);

    expect(
      patch,
      build,
      reason:
          'version name ${match.group(1)}.${match.group(2)}.$patch does not '
          'match build $build. Profile prints the name alone, so a user would '
          'report a build number that is not the one they are running.',
    );
  });
}
