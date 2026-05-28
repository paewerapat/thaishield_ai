// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'ТайШилд';

  @override
  String get appTagline => 'Ваш спутник безопасного путешествия';

  @override
  String get selectLanguage => 'Выберите язык';

  @override
  String get selectLanguageSubtitle =>
      'Выберите предпочитаемый язык для продолжения';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get languageEnglish => 'Английский';

  @override
  String get languageChinese => 'Китайский';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageKorean => 'Корейский';

  @override
  String get languageJapanese => 'Японский';

  @override
  String get homeTitle => 'ТайШилд';

  @override
  String get mapTab => 'Карта';

  @override
  String get scannerTab => 'Сканер';

  @override
  String get sosTab => 'SOS';
}
