// iPhone only — decided 2026-09-13.
//
// The iOS build ships for iPhone alone, so App Store Connect asks for no 13"
// iPad screenshots. 🚨 Once a build that declares iPad is uploaded, Apple does
// not let a later version drop iPad, so this must hold from the very first
// Codemagic run. Supporting iPad again is a deliberate change: flip this test,
// and produce iPad screenshots in the same round.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every build configuration targets iPhone only', () {
    final pbx =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final families = RegExp(r'TARGETED_DEVICE_FAMILY = ([^;]+);')
        .allMatches(pbx)
        .map((m) => m.group(1)!.replaceAll('"', ''))
        .toList();
    expect(families, isNotEmpty);
    expect(families, everyElement('1'));
  });

  test('Info.plist carries no iPad-only orientation block', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, isNot(contains('~ipad')));
  });
}
