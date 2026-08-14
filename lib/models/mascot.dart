import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Uygulamanın maskotu bir ayıdır; kullanıcı ayının hangi karakterle
/// konuşacağını seçer. Bildirim/koç metinleri bu karaktere göre yazılır.
///
/// Görseller sonra eklenecek — şimdilik [emoji] yer tutucu olarak kullanılır.
enum Mascot {
  evHanimi,
  arabeskci,
  sanayiUstasi,
  akademisyen,
  ceo;

  String get label => switch (this) {
    Mascot.evHanimi => 'Müşfik Ev Hanımı Ayı',
    Mascot.arabeskci => 'Adanalı Arabeskçi İsmail Hoşses Ayı',
    Mascot.sanayiUstasi => 'Sanayi Ustası Ayı',
    Mascot.akademisyen => 'Akademisyen Ayı',
    Mascot.ceo => 'CEO Ayı',
  };

  /// Karakteri bir cümlede anlatan tanıtım.
  String get tagline => switch (this) {
    Mascot.evHanimi => 'Şefkatli, sıcak; seni hep gözetir.',
    Mascot.arabeskci => 'Dramatik, duygulu; hatalarına ağıt yakar.',
    Mascot.sanayiUstasi => 'Lafı dolandırmaz, sert ama haklı.',
    Mascot.akademisyen => 'Ölçülü ve titiz; kaynak gösterir.',
    Mascot.ceo => 'Hedef odaklı; her şey performans.',
  };

  /// Karakterin ağzından örnek bir bildirim (ses tonunu göstermek için).
  String get sample => switch (this) {
    Mascot.evHanimi => 'Canım benim, bugün 5 soru bekliyor. Üşenme e mi?',
    Mascot.arabeskci => 'Bu soru beni benden aldı dostum… gel çözelim şunu.',
    Mascot.sanayiUstasi => 'Hadi bakalım usta, tezgâhta 5 soru duruyor.',
    Mascot.akademisyen => 'Tekrar aralığın doldu: bugün 5 soru planlandı.',
    Mascot.ceo => 'Günlük hedefin %25. Aksiyon zamanı.',
  };

  /// Görsel gelene kadar yer tutucu. Maskotun adı Kimo ve hepsi aynı ayı;
  /// karakterler yüzle değil renkle ve sesle ayrışır.
  String get emoji => '🐻';

  Color get color => switch (this) {
    Mascot.evHanimi => AppColors.pink,
    Mascot.arabeskci => AppColors.orange,
    Mascot.sanayiUstasi => AppColors.teal,
    Mascot.akademisyen => AppColors.indigo,
    Mascot.ceo => AppColors.blue,
  };

  /// Kullanıcı metadata'sında saklanan değer.
  String get dbValue => switch (this) {
    Mascot.evHanimi => 'ev_hanimi',
    Mascot.arabeskci => 'arabeskci',
    Mascot.sanayiUstasi => 'sanayi_ustasi',
    Mascot.akademisyen => 'akademisyen',
    Mascot.ceo => 'ceo',
  };

  static Mascot? fromDb(String? value) => switch (value) {
    'ev_hanimi' => Mascot.evHanimi,
    'arabeskci' => Mascot.arabeskci,
    'sanayi_ustasi' => Mascot.sanayiUstasi,
    'akademisyen' => Mascot.akademisyen,
    'ceo' => Mascot.ceo,
    _ => null,
  };
}
