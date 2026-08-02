import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('tr')];

  /// Uygulamanın adı
  ///
  /// In tr, this message translates to:
  /// **'AI YKS Coach'**
  String get appTitle;

  /// Ana ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Bugünün Tekrarları'**
  String get todaysReviewsTitle;

  /// Bugün tekrar edilecek soru sayısı
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =0{Bugün tekrar yok} =1{1 soru seni bekliyor} other{{count} soru seni bekliyor}}'**
  String reviewsDueSubtitle(num count);

  /// No description provided for @emptyReviewsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Harika! Bugünlük her şey tamam 🎉'**
  String get emptyReviewsTitle;

  /// No description provided for @emptyReviewsBody.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar zamanı gelen soru yok. Yeni sorular çözerek hata bankanı büyütebilirsin.'**
  String get emptyReviewsBody;

  /// No description provided for @conceptLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kavram'**
  String get conceptLabel;

  /// No description provided for @difficultyLabel.
  ///
  /// In tr, this message translates to:
  /// **'Zorluk'**
  String get difficultyLabel;

  /// No description provided for @showAnswer.
  ///
  /// In tr, this message translates to:
  /// **'Cevabı Göster'**
  String get showAnswer;

  /// No description provided for @hideAnswer.
  ///
  /// In tr, this message translates to:
  /// **'Cevabı Gizle'**
  String get hideAnswer;

  /// No description provided for @correctAnswerLabel.
  ///
  /// In tr, this message translates to:
  /// **'Doğru cevap'**
  String get correctAnswerLabel;

  /// No description provided for @solutionLabel.
  ///
  /// In tr, this message translates to:
  /// **'Çözüm'**
  String get solutionLabel;

  /// No description provided for @answeredCorrect.
  ///
  /// In tr, this message translates to:
  /// **'Doğru bildim'**
  String get answeredCorrect;

  /// No description provided for @answeredWrong.
  ///
  /// In tr, this message translates to:
  /// **'Bilemedim'**
  String get answeredWrong;

  /// Bir soru cevaplandıktan sonra planlanan sonraki tekrar
  ///
  /// In tr, this message translates to:
  /// **'Sonraki tekrar {days, plural, =1{1 gün} other{{days} gün}} sonra.'**
  String nextReviewScheduled(num days);

  /// No description provided for @sessionCompleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Seans tamamlandı 👏'**
  String get sessionCompleteTitle;

  /// Seans özeti
  ///
  /// In tr, this message translates to:
  /// **'{correct} / {total} doğru. Sorularının bir sonraki tekrarı planlandı.'**
  String sessionCompleteBody(int correct, int total);

  /// No description provided for @restartSession.
  ///
  /// In tr, this message translates to:
  /// **'Yeni seans'**
  String get restartSession;

  /// No description provided for @heartsLabel.
  ///
  /// In tr, this message translates to:
  /// **'Can'**
  String get heartsLabel;

  /// No description provided for @xpLabel.
  ///
  /// In tr, this message translates to:
  /// **'XP'**
  String get xpLabel;

  /// No description provided for @streakLabel.
  ///
  /// In tr, this message translates to:
  /// **'Seri'**
  String get streakLabel;

  /// No description provided for @streakDays.
  ///
  /// In tr, this message translates to:
  /// **'{days, plural, =1{1 gün} other{{days} gün}}'**
  String streakDays(num days);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
