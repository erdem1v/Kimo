import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Gelen soru şikâyet sebepleri.
///
/// Havuz kalktığı için KALİTE sebepleri (okunmuyor, cevap yanlış, yanlış konu…)
/// arayüzden çıktı: artık şikâyet edilen tek içerik bir arkadaşın sana
/// gönderdiği soru ve orada "şıkların yeri yanlış" bir moderasyon konusu değil.
/// Veritabanındaki CHECK o değerleri hâlâ kabul ediyor — eski satırlar var ve
/// onları geçersiz kılmak veriyi bozardı.
///
/// Tasarımın (3n) listelediği beş sebep [inbox] içinde.
enum ReportReason {
  inappropriate,
  spam,
  harassment,
  copyright,
  personalInfo,
  other;

  /// Gelen kutusunda gösterilen sebepler, tasarımdaki sırayla.
  ///
  /// `personalInfo` listede değil ama enum'da duruyor: eski şikâyet satırları
  /// bu değeri taşıyor ve moderasyon ekranı onları okuyabilmeli.
  static const List<ReportReason> inbox = <ReportReason>[
    ReportReason.inappropriate,
    ReportReason.spam,
    ReportReason.harassment,
    ReportReason.copyright,
    ReportReason.other,
  ];

  String get label => switch (this) {
    ReportReason.inappropriate => 'Uygunsuz içerik',
    ReportReason.spam => 'Soruyla ilgisi yok / spam',
    ReportReason.harassment => 'Taciz veya zorbalık',
    ReportReason.copyright => 'Telif hakkı ihlali (yayın sorusu)',
    ReportReason.personalInfo => 'Kişisel bilgi görünüyor',
    ReportReason.other => 'Diğer',
  };

  String get hint => switch (this) {
    ReportReason.inappropriate => 'Hakaret, şiddet ya da müstehcen içerik.',
    ReportReason.spam => 'Soru değil; reklam, bağlantı ya da alakasız görsel.',
    ReportReason.harassment => 'Sana yönelik rahatsız edici bir gönderim.',
    ReportReason.copyright =>
      'Bir yayınevinin sorusu; izinsiz paylaşılıyor.',
    ReportReason.personalInfo =>
      'İsim, telefon, okul adı gibi bilgiler görünüyor.',
    ReportReason.other => 'Kısaca ne olduğunu yaz.',
  };

  IconData get icon => switch (this) {
    ReportReason.inappropriate => Icons.report_gmailerrorred_rounded,
    ReportReason.spam => Icons.block_rounded,
    ReportReason.harassment => Icons.sentiment_very_dissatisfied_rounded,
    ReportReason.copyright => Icons.copyright_rounded,
    ReportReason.personalInfo => Icons.badge_outlined,
    ReportReason.other => Icons.more_horiz_rounded,
  };

  /// Güvenlik sınıfı: moderasyon kuyruğunda önceliklidir ve tek şikâyette
  /// içeriği geçici olarak gizler (veritabanındaki trigger uygular).
  bool get isSafety =>
      this == ReportReason.inappropriate ||
      this == ReportReason.harassment ||
      this == ReportReason.personalInfo;

  Color get color => isSafety ? AppColors.red : AppColors.orange;

  /// Veritabanındaki değer. Her sebebin KENDİ değeri var: ikisini aynı değere
  /// eşlemek moderasyon ekranında "hangi sebep" sorusunu cevaplanamaz hâle
  /// getirirdi.
  String get dbValue => switch (this) {
    ReportReason.inappropriate => 'inappropriate',
    ReportReason.spam => 'spam',
    ReportReason.harassment => 'harassment',
    ReportReason.copyright => 'copyright',
    ReportReason.personalInfo => 'personal_info',
    ReportReason.other => 'other',
  };

  /// Veritabanı değerinden okur. Havuz dönemindeki kalite sebepleri ve
  /// bilinmeyen değerler `other`a düşer: moderasyon ekranı eski satırları da
  /// listeleyebilmeli, çökmemeli.
  static ReportReason fromDb(String? value) => switch (value) {
    'inappropriate' => ReportReason.inappropriate,
    'spam' => ReportReason.spam,
    'harassment' => ReportReason.harassment,
    'copyright' => ReportReason.copyright,
    'personal_info' => ReportReason.personalInfo,
    _ => ReportReason.other,
  };
}
