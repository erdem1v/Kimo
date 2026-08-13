import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Havuz sorusu şikayet sebepleri.
///
/// İki sınıf var: KALİTE sorunları (okunmuyor, cevap yanlış…) 3 şikayette,
/// GÜVENLİK sorunları (uygunsuz içerik, kişisel bilgi) tek şikayette soruyu
/// havuzdan düşürür. Eşikler veritabanındaki trigger'da uygulanır.
enum ReportReason {
  unreadable,
  optionsWrong,
  answerWrong,
  wrongTopic,
  inappropriate,
  personalInfo,
  other;

  String get label => switch (this) {
        ReportReason.unreadable => 'Soru okunmuyor',
        ReportReason.optionsWrong => 'Şıkların yeri yanlış',
        ReportReason.answerWrong => 'İşaretli cevap yanlış',
        ReportReason.wrongTopic => 'Yanlış ders / konu',
        ReportReason.inappropriate => 'Uygunsuz içerik',
        ReportReason.personalInfo => 'Kişisel bilgi görünüyor',
        ReportReason.other => 'Başka bir sorun var',
      };

  String get hint => switch (this) {
        ReportReason.unreadable =>
          'Fotoğraf bulanık, karanlık ya da soru kesilmiş.',
        ReportReason.optionsWrong =>
          'Şıklar eksik, karışmış ya da metinleri hatalı.',
        ReportReason.answerWrong => 'Doğru olarak işaretlenen şık hatalı.',
        ReportReason.wrongTopic =>
          'Soru gösterilen ders veya konuya ait değil.',
        ReportReason.inappropriate =>
          'Hakaret, şiddet ya da soruyla ilgisiz içerik.',
        ReportReason.personalInfo =>
          'İsim, telefon, okul adı gibi bilgiler görünüyor.',
        ReportReason.other => 'Kısaca ne olduğunu yaz.',
      };

  IconData get icon => switch (this) {
        ReportReason.unreadable => Icons.blur_on_rounded,
        ReportReason.optionsWrong => Icons.swap_vert_rounded,
        ReportReason.answerWrong => Icons.rule_rounded,
        ReportReason.wrongTopic => Icons.wrong_location_rounded,
        ReportReason.inappropriate => Icons.report_gmailerrorred_rounded,
        ReportReason.personalInfo => Icons.badge_outlined,
        ReportReason.other => Icons.more_horiz_rounded,
      };

  /// Güvenlik sınıfı: tek şikayette soru havuzdan düşer.
  bool get isSafety =>
      this == ReportReason.inappropriate || this == ReportReason.personalInfo;

  Color get color => isSafety ? AppColors.red : AppColors.orange;

  /// Veritabanındaki değer.
  String get dbValue => switch (this) {
        ReportReason.unreadable => 'unreadable',
        ReportReason.optionsWrong => 'options_wrong',
        ReportReason.answerWrong => 'answer_wrong',
        ReportReason.wrongTopic => 'wrong_topic',
        ReportReason.inappropriate => 'inappropriate',
        ReportReason.personalInfo => 'personal_info',
        ReportReason.other => 'other',
      };
}
