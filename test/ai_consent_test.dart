import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thaishield_ai/core/localization/app_text.dart';
import 'package:thaishield_ai/core/services/ai_consent.dart';
import 'package:thaishield_ai/core/widgets/ai_consent_sheet.dart';

/// The AI-processing consent App Review asked for on 2026-09-16
/// (guidelines 5.1.1 / 5.1.2): the scanner and SOS must ask before a photo or
/// a recording is sent to Google's AI services, and the user must be able to
/// withdraw the answer.
const _languages = ['th', 'en', 'zh', 'ko', 'ru', 'ja'];

const _consentKeys = [
  'ai_consent_title',
  'ai_consent_body_scanner',
  'ai_consent_body_sos',
  'ai_consent_common',
  'ai_consent_agree',
  'ai_consent_decline',
  'ai_consent_privacy_link',
  'profile_ai_title',
  'profile_ai_subtitle',
];

Widget _host(Widget child, {String language = 'en'}) {
  return MaterialApp(
    locale: Locale(language),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('th'),
      Locale('en'),
      Locale('zh'),
      Locale('ko'),
      Locale('ru'),
      Locale('ja'),
    ],
    home: child,
  );
}

/// A button that runs [ensureAiConsent] and remembers the answer, so a test
/// can drive the sheet the way the scanner and SOS do.
class _Asker extends StatefulWidget {
  const _Asker({required this.store, required this.purpose});
  final AiConsentStore store;
  final AiConsentPurpose purpose;

  @override
  State<_Asker> createState() => _AskerState();
}

class _AskerState extends State<_Asker> {
  bool? answer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            final result =
                await ensureAiConsent(context, widget.purpose, store: widget.store);
            setState(() => answer = result);
          },
          child: Text('ask ${answer ?? '-'}'),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AiConsentStore.instance.resetForTest();
  });

  group('AiConsentStore', () {
    test('starts unloaded and not granted', () {
      final store = AiConsentStore();
      expect(store.isLoaded, isFalse);
      expect(store.isGranted, isFalse);
    });

    test('grant persists across a fresh instance; revoke clears it', () async {
      final store = AiConsentStore();
      await store.load();
      expect(store.isGranted, isFalse);

      await store.grant();
      expect(store.isGranted, isTrue);

      final again = AiConsentStore();
      expect(await again.load(), isTrue, reason: 'consent must survive relaunch');

      await again.revoke();
      expect(await AiConsentStore().load(), isFalse);
    });

    test('notifies listeners on every change, so the Profile switch tracks it',
        () async {
      final store = AiConsentStore();
      var ticks = 0;
      store.addListener(() => ticks++);
      await store.load();
      await store.grant();
      await store.revoke();
      expect(ticks, 3);
    });
  });

  group('ensureAiConsent', () {
    testWidgets('asks once, and never again after the user agrees',
        (tester) async {
      final store = AiConsentStore();
      await tester.pumpWidget(_host(
        _Asker(store: store, purpose: AiConsentPurpose.scanner),
      ));

      await tester.tap(find.textContaining('ask'));
      await tester.pumpAndSettle();

      // The sheet names what leaves the device and where it goes, in the
      // reader's language — that is the whole point of asking.
      expect(find.text(appTextIn('en', 'ai_consent_title')), findsOneWidget);
      expect(find.text(appTextIn('en', 'ai_consent_body_scanner')),
          findsOneWidget);
      expect(find.text(appTextIn('en', 'ai_consent_common')), findsOneWidget);

      await tester.tap(find.text(appTextIn('en', 'ai_consent_agree')));
      await tester.pumpAndSettle();
      expect(find.text('ask true'), findsOneWidget);
      expect(store.isGranted, isTrue);

      // Second press: no sheet, straight through.
      await tester.tap(find.textContaining('ask'));
      await tester.pumpAndSettle();
      expect(find.text(appTextIn('en', 'ai_consent_title')), findsNothing);
      expect(find.text('ask true'), findsOneWidget);
    });

    testWidgets('"not now" blocks the feature and records nothing',
        (tester) async {
      final store = AiConsentStore();
      await tester.pumpWidget(_host(
        _Asker(store: store, purpose: AiConsentPurpose.sos),
      ));

      await tester.tap(find.textContaining('ask'));
      await tester.pumpAndSettle();
      expect(find.text(appTextIn('en', 'ai_consent_body_sos')), findsOneWidget);

      await tester.tap(find.text(appTextIn('en', 'ai_consent_decline')));
      await tester.pumpAndSettle();
      expect(find.text('ask false'), findsOneWidget);
      expect(store.isGranted, isFalse);

      // "Not now" is not "never": the next press asks again.
      await tester.tap(find.textContaining('ask'));
      await tester.pumpAndSettle();
      expect(find.text(appTextIn('en', 'ai_consent_title')), findsOneWidget);
    });

    testWidgets('the sheet is in the reader\'s language, not English',
        (tester) async {
      final store = AiConsentStore();
      await tester.pumpWidget(_host(
        _Asker(store: store, purpose: AiConsentPurpose.scanner),
        language: 'ja',
      ));
      await tester.tap(find.textContaining('ask'));
      await tester.pumpAndSettle();
      expect(find.text(appTextIn('ja', 'ai_consent_title')), findsOneWidget);
      expect(find.text(appTextIn('en', 'ai_consent_title')), findsNothing);
    });
  });

  group('the consent copy', () {
    test('exists in all six languages', () {
      for (final key in _consentKeys) {
        final entry = appStrings[key];
        expect(entry, isNotNull, reason: '$key is missing');
        for (final language in _languages) {
          expect(entry![language]?.trim(), isNotEmpty,
              reason: '$key has no $language text');
        }
      }
    });

    test('names the recipient and the data, in every language', () {
      // A consent that does not say who receives the data is not the consent
      // the guideline asks for. Google and Gemini are proper nouns, so they
      // appear unchanged in every column.
      for (final language in _languages) {
        for (final key in ['ai_consent_body_scanner', 'ai_consent_body_sos']) {
          final text = appStrings[key]![language]!;
          expect(text, contains('Google'), reason: '$key/$language');
          expect(text, contains('Gemini'), reason: '$key/$language');
        }
        expect(appStrings['ai_consent_body_sos']![language]!,
            contains('Speech-to-Text'), reason: language);
      }
    });

    test('tells the user it can be withdrawn', () {
      final en = appStrings['ai_consent_common']!['en']!.toLowerCase();
      expect(en, contains('change your mind'));
      expect(en, contains('profile'));
    });
  });

  test('the debug platform override is not left set by this file', () {
    expect(debugDefaultTargetPlatformOverride, isNull);
  });
}
