// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'AI YKS Coach';

  @override
  String get todaysReviewsTitle => 'Bugünün Tekrarları';

  @override
  String reviewsDueSubtitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count soru seni bekliyor',
      one: '1 soru seni bekliyor',
      zero: 'Bugün tekrar yok',
    );
    return '$_temp0';
  }

  @override
  String get emptyReviewsTitle => 'Harika! Bugünlük her şey tamam 🎉';

  @override
  String get emptyReviewsBody =>
      'Tekrar zamanı gelen soru yok. Yeni sorular çözerek hata bankanı büyütebilirsin.';

  @override
  String get conceptLabel => 'Kavram';

  @override
  String get difficultyLabel => 'Zorluk';

  @override
  String get difficultyEasy => 'Kolay';

  @override
  String get difficultyMedium => 'Orta';

  @override
  String get difficultyHard => 'Zor';

  @override
  String get showAnswer => 'Cevabı Göster';

  @override
  String get hideAnswer => 'Cevabı Gizle';

  @override
  String get correctAnswerLabel => 'Doğru cevap';

  @override
  String get solutionLabel => 'Çözüm';

  @override
  String get answeredCorrect => 'Doğru bildim';

  @override
  String get answeredWrong => 'Bilemedim';

  @override
  String nextReviewScheduled(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün',
      one: '1 gün',
    );
    return 'Sonraki tekrar $_temp0 sonra.';
  }

  @override
  String get sessionCompleteTitle => 'Seans tamamlandı 👏';

  @override
  String sessionCompleteBody(int correct, int total) {
    return '$correct / $total doğru. Sorularının bir sonraki tekrarı planlandı.';
  }

  @override
  String get restartSession => 'Yeni seans';

  @override
  String get heartsLabel => 'Can';

  @override
  String get xpLabel => 'XP';

  @override
  String get streakLabel => 'Seri';

  @override
  String streakDays(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün',
      one: '1 gün',
    );
    return '$_temp0';
  }
}
