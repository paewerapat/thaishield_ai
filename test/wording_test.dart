// The §10 wording rules, enforced over *every* string the app can display, in
// *every* language it can display them in.
//
// Why this file exists (task 2.6, 2026-08-24)
// -------------------------------------------
// Four tests already carried a `§10 wording` block: premium, around_you, route
// and dish_identification. Each of them checked `appStrings[key]['en']` — the
// English entry only — for a hand-written list of that one feature's keys.
//
// Measured before writing this: those four lists together name **63 of the 216
// keys (29%)**, and the other five languages were never checked at all. Among
// the 153 unchecked keys were `variance_above` and `variance_significant`, which
// are the single most §10-sensitive strings in the product — they are the app
// telling a tourist what a price means, and they are exactly what §10's
// replacement table ("Overcharge" → "Higher Than Average") was written to
// govern. Also unchecked: every `radar_*`, `proximity_*`, `alert_category_*`,
// `scanner_*` and `sos_*` string.
//
// A per-feature key list is the wrong shape for this rule. §10 applies to all
// user-facing copy, so this test reads the key set **out of `appStrings`
// itself**. A string added tomorrow is covered tomorrow, with nobody
// remembering to add it to a list.
//
// Legal exposure does not stop at the English column. A Thai translation
// reading "ร้านนี้โกง" while the English says "Price Is Higher Than Typical
// Range" is the accusation §10 exists to prevent — and, since the app ships
// Thai first to an audience in Thailand, it is the *most* likely one to be read
// by the shop being described.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thaishield_ai/core/localization/app_text.dart';

const _languages = ['th', 'en', 'zh', 'ko', 'ru', 'ja'];

/// A term §10 forbids, as a pattern rather than a substring.
///
/// A substring match cannot express "this sequence of letters, except inside
/// that longer word", and the Russian column proves why that matters: `опасн`
/// ("danger") is a substring of `безопасн` ("**safe**"). A naive contains-check
/// reports "Радар безопасности" — *Safety* Radar — as a §10 violation. When
/// this rule was first measured it produced five such false alarms out of seven
/// Russian hits, and a linter that cries wolf five times out of seven is one
/// that gets switched off.
class _Banned {
  const _Banned(this.pattern, this.meaning, {this.exemptKeys = const {}});

  final String pattern;

  /// What the term means in English, so a failure is legible to a reviewer who
  /// does not read the language it fired in.
  final String meaning;

  /// Keys where this specific term is allowed, each one a deliberate decision
  /// recorded below — never a blanket pass for the key.
  final Set<String> exemptKeys;

  RegExp get regExp => RegExp(pattern, caseSensitive: false, unicode: true);
}

// `avoid` is banned because of §10's "Avoid This Shop" → "Compare Before
// Purchasing" row: the app must not tell a tourist to stay away from a business
// or a named area, because that is the accusation the whole guide is built to
// prevent.
//
// The two safety tips below use the same word about things that are not a
// business and not an identified place — the midday sun, and walking alone at
// night — which is ordinary personal-safety advice of the kind every embassy
// publishes. They are exempted rather than reworded: rewriting copy in six
// languages to satisfy a linter written in the same change would add five
// unreviewed translations to remove a risk that was judged not to exist. If a
// reviewer disagrees, the fix is to reword all six, not to widen the exemption.
const _avoidExempt = {'safety_tip_5', 'safety_tip_6'};

const Map<String, List<_Banned>> _banned = {
  'en': [
    _Banned('scam', 'scam'),
    _Banned('fraud', 'fraud'),
    _Banned('cheat', 'cheat'),
    _Banned('overcharg', 'overcharge'),
    _Banned('rip-?off', 'rip-off'),
    _Banned('goug', 'price gouging'),
    _Banned('dangerous', 'dangerous'),
    _Banned('unsafe', 'unsafe'),
    _Banned('blacklist', 'blacklist'),
    _Banned('exploit', 'exploitation'),
    _Banned('dishonest', 'dishonest'),
    _Banned('tourist trap', 'tourist trap'),
    // §10 replaces "Guaranteed/Verified Fair Price" with "Certified Fair
    // Price": the app reports what partners agreed to, it does not underwrite
    // the price.
    _Banned('guarantee', 'guarantee'),
    _Banned('avoid', 'avoid', exemptKeys: _avoidExempt),
  ],
  'th': [
    _Banned('หลอก', 'deceive'),
    _Banned('โกง', 'cheat'),
    _Banned('ฉ้อ', 'defraud'),
    _Banned('ทุจริต', 'dishonest'),
    _Banned('อันตราย', 'dangerous'),
    _Banned('ไม่ปลอดภัย', 'unsafe'),
    _Banned('แบล็[คก]', 'blacklist'),
    _Banned('เอาเปรียบ', 'take advantage of'),
    _Banned('ขูดรีด', 'extortionate'),
    _Banned('ปลอม', 'fake'),
    _Banned('รับประกัน', 'guarantee'),
    _Banned('หลีกเลี่ยง', 'avoid', exemptKeys: _avoidExempt),
  ],
  'zh': [
    _Banned('诈骗', 'scam'),
    _Banned('欺诈', 'fraud'),
    _Banned('骗', 'deceive'),
    _Banned('宰客', 'fleece tourists'),
    _Banned('危险', 'dangerous'),
    _Banned('不安全', 'unsafe'),
    _Banned('黑名单', 'blacklist'),
    _Banned('剥削', 'exploitation'),
    _Banned('保证', 'guarantee'),
    _Banned('避免', 'avoid', exemptKeys: _avoidExempt),
  ],
  'ko': [
    _Banned('사기', 'fraud'),
    _Banned('바가지', 'rip-off'),
    _Banned('위험', 'dangerous'),
    _Banned('안전하지 ?않', 'unsafe'),
    _Banned('블랙리스트', 'blacklist'),
    _Banned('착취', 'exploitation'),
    _Banned('가짜', 'fake'),
    _Banned('보장', 'guarantee'),
    _Banned('피하', 'avoid', exemptKeys: _avoidExempt),
  ],
  'ru': [
    _Banned('мошенн', 'fraud'),
    _Banned('обман', 'deception'),
    _Banned('надува', 'swindle'),
    // The lookbehind is the entire point — see the _Banned doc comment.
    _Banned('(?<!без)опасн', 'dangerous'),
    _Banned('небезопасн', 'unsafe'),
    _Banned('[чё]ерный список|чёрный список', 'blacklist'),
    _Banned('эксплуат', 'exploitation'),
    _Banned('поддельн', 'counterfeit'),
    _Banned('гарантир', 'guarantee'),
    _Banned('избега', 'avoid', exemptKeys: _avoidExempt),
  ],
  'ja': [
    _Banned('詐欺', 'fraud'),
    _Banned('ぼったくり', 'rip-off'),
    _Banned('騙', 'deceive'),
    _Banned('危険', 'dangerous'),
    _Banned('安全でない', 'unsafe'),
    _Banned('ブラックリスト', 'blacklist'),
    _Banned('搾取', 'exploitation'),
    _Banned('保証', 'guarantee'),
    _Banned('避け', 'avoid', exemptKeys: _avoidExempt),
  ],
};

void main() {
  group('§10 legal safe wording — every key, every language', () {
    test('the rule set covers all six shipped languages', () {
      // If a seventh language is ever added, this fails until its banned list
      // is written — rather than silently shipping an unchecked column.
      expect(_banned.keys.toSet(), _languages.toSet());
    });

    test('every key carries all six languages, none blank', () {
      // §10 can only be enforced on text that exists. A missing entry falls
      // back to English at runtime, which hides the gap from a human reader
      // while leaving the string unreviewed in that language.
      for (final entry in appStrings.entries) {
        for (final language in _languages) {
          final value = entry.value[language];
          expect(
            value,
            isNotNull,
            reason: '${entry.key} has no "$language" entry',
          );
          expect(
            value!.trim(),
            isNotEmpty,
            reason: '${entry.key} has a blank "$language" entry',
          );
        }
      }
    });

    test('no displayable string uses accusatory wording, in any language', () {
      final failures = <String>[];

      for (final entry in appStrings.entries) {
        final key = entry.key;
        for (final language in _languages) {
          final text = entry.value[language];
          if (text == null) continue;
          for (final banned in _banned[language]!) {
            if (banned.exemptKeys.contains(key)) continue;
            if (banned.regExp.hasMatch(text)) {
              failures.add(
                '$key [$language] uses "${banned.meaning}" '
                '(/${banned.pattern}/): $text',
              );
            }
          }
        }
      }

      expect(
        failures,
        isEmpty,
        reason:
            'CLAUDE.md §10 forbids accusatory wording in every user-facing '
            'string. Rewrite using the replacement table, or — if the term is '
            'genuinely not about a shop, person or identified area — add the '
            'key to that term\'s exemptKeys with the reason written down.\n'
            '${failures.join('\n')}',
      );
    });

    test('the exemptions still name real keys', () {
      // An exemption for a key that no longer exists is a rule nobody is
      // reading any more, and it quietly widens over time.
      for (final key in _avoidExempt) {
        expect(
          appStrings.containsKey(key),
          isTrue,
          reason: '$key is exempted from the "avoid" rule but no longer exists',
        );
      }
    });

    test('map badges are never written as literals', () {
      // The rule above can only see strings that reach `appStrings`. On
      // 2026-08-27 device QA found the ones that never do: `map_screen.dart`
      // passed 'VERIFIED', 'FAIR PRICE', 'PARTNER' and 'ABOVE TYPICAL RANGE'
      // straight into its badge widget. English-only in a six-language app —
      // and "Verified" is the exact word §10's table replaces with
      // "Certified", which the Radar had been getting right the whole time
      // from `radar_badge_certified`. Same partner, two different labels,
      // depending on which screen you opened.
      //
      // So this test reads the source. Every badge label on the map must come
      // from the table, where the rule above can then check it.
      final source =
          File('lib/features/map/screens/map_screen.dart').readAsStringSync();

      final literalLabels =
          RegExp(r"label:\s*'([^']*)'").allMatches(source).map((m) => m[1]!);

      expect(
        literalLabels,
        isEmpty,
        reason:
            'These badge labels bypass the localization table, so they ship in '
            'one language and no §10 check can see them. Move each into '
            'app_text.dart and read it with appText(context, key): '
            '${literalLabels.join(', ')}',
      );
    });

    test('the shared badge keys still say Certified, not Verified', () {
      // §10's replacement table, on the three keys the Radar and the Map now
      // share. If someone "simplifies" the wording back, both screens regress
      // together and the word returns to a build the client already accepted.
      expect(appStrings['radar_badge_certified']!['en'], 'Certified Fair Price');
      for (final language in _languages) {
        final text = appStrings['radar_badge_certified']![language]!;
        expect(
          text.toLowerCase(),
          isNot(contains('verified')),
          reason: 'radar_badge_certified [$language] reads as Verified: $text',
        );
      }
    });

    test('the price-variance labels stay statistical', () {
      // The four strings §10's replacement table is really aimed at: the app
      // saying what a scanned price *means*. Neutral wording here is what keeps
      // a variance figure an observation rather than an allegation, so they get
      // a check of their own that does not depend on the banned list above.
      for (final key in [
        'variance_within',
        'variance_above',
        'variance_significant',
        'variance_below',
      ]) {
        expect(
          appStrings.containsKey(key),
          isTrue,
          reason: '$key is gone — update this test with whatever replaced it',
        );
        final english = appStrings[key]!['en']!.toLowerCase();
        for (final word in ['too ', 'should', 'must', 'never', 'don\'t']) {
          expect(
            english.contains(word),
            isFalse,
            reason: '$key instructs rather than reports: $english',
          );
        }
      }
    });
  });
}
