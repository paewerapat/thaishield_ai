import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thaishield_ai/features/home/widgets/home_tab.dart';

/// Home must not show the travel-news block while the cache is unfiltered.
///
/// 🚨 **The measurement this exists for.** On 2026-09-08 the client reported
/// that Home's Top News showed stories with nothing to do with travel safety,
/// some wearing the wrong category badge. Reading `travel_alerts_cache` that
/// morning: **18 of 32 articles were junk** — a Democracy Now headline
/// roundup, a badminton final, "Suites Across Asia Fit for a President", a
/// Russian general shot in Ukraine, Thailand's aid *to Nepal's* flood victims,
/// and "Thai SMEs face debt tsunami", a metaphor that would badge the card
/// สึนามิ. Home shows the newest article, so any of those could be the first
/// thing a new user sees.
///
/// These read the source rather than pumping the widget, the same approach as
/// `main_wiring_test.dart` and `paywall_reachability_test.dart`: what has to be
/// guaranteed is that Home does not *construct* the block, and a widget test
/// that finds no "Top News" text would also pass if the block were built and
/// merely failed to load.
void main() {
  final source =
      File('lib/features/home/widgets/home_tab.dart').readAsStringSync();

  group('Home hides travel news until the relevance gate is fixed', () {
    test('the flag is off', () {
      expect(
        showTravelNewsOnHome,
        isFalse,
        reason: 'Turned on again? Then functions/index.js must judge the '
            'article as a whole — a disaster word and a Thai place name in the '
            'same text is what let 18 of 32 articles through — and the cache '
            'must be measured again before this flips.',
      );
    });

    test('the block is only built behind the flag', () {
      expect(
        source,
        contains('if (showTravelNewsOnHome) const _ActiveAlertsAndNews(),'),
        reason: 'Home builds the news block unconditionally again.',
      );
      // Every line that *builds* the block — the declaration on the widget
      // class itself ends in `;`, not `,`, so it is not one of these.
      final buildSites = const LineSplitter()
          .convert(source)
          .where((line) => line.contains('_ActiveAlertsAndNews(),'))
          .toList();
      expect(buildSites, hasLength(1),
          reason: 'A second _ActiveAlertsAndNews() slipped back in.');
      expect(
        buildSites.single,
        contains('if (showTravelNewsOnHome)'),
        reason: 'The block is built without the flag guarding it.',
      );
    });

    test('the banner and the card are still there to restore', () {
      // The block is hidden, not deleted: the client asked for it back once
      // the filtering is trustworthy, and re-typing it from scratch would
      // lose the alert-summary logic and the disclaimer line with it.
      expect(source, contains('class _ActiveAlertsAndNews'));
      expect(source, contains('_AlertsBanner'));
      expect(source, contains("appText(context, 'home_top_news')"));
    });
  });
}
