import '../widgets/kimo/kimo_pose.dart';

/// Kimo'nun **ses tonu ve aksesuarı**. Persona ayrı bir karakter DEĞİL: maskot
/// her zaman aynı ayı, **aynı yüz**.
///
/// TASK 12: yüz aynı kaldı ama persona artık görünür — her personanın bir
/// aksesuarı var (Tur 7 · n2). Task 04 `Mascot.emoji` ve `Mascot.color`u
/// silerek personayı görünmez kılmıştı; o karar YÜZ düzeyinde korunuyor
/// (kafa/kulak/göz/burun/ağız geometrisi dört varyantta birebir aynı),
/// aksesuar düzeyinde tersine çevrildi.
///
/// Bu dosya bilerek çıplak: görünen ad, tarif ve örnek cümle arayüz metnidir ve
/// `app_tr.arb`'de durur (bkz. `features/onboarding/persona_card.dart`); bildirim
/// cümleleri veritabanındadır (`push_lines`, bkz. `data/notification_lines.dart`).
/// Burada yalnızca kimlik ve veritabanı karşılığı kalıyor.
///
/// Akademisyen personası Task 04'te ürün kararıyla kaldırıldı; göç 0055 mevcut
/// kullanıcıları `evHanimi`'ye eşliyor.
enum Mascot {
  evHanimi,
  arabeskci,
  sanayiUstasi,
  ceo;

  /// `profiles.mascot` ve auth metadata'sında saklanan değer. Sunucudaki
  /// `push_lines.mascot` CHECK kısıtı ve `upsert_my_profile`'ın doğrulaması
  /// bu dört değeri tanır — yazımı değiştirmek bildirimleri sessizce değil,
  /// gürültüyle (22023) durdurur.
  String get dbValue => switch (this) {
        Mascot.evHanimi => 'ev_hanimi',
        Mascot.arabeskci => 'arabeskci',
        Mascot.sanayiUstasi => 'sanayi_ustasi',
        Mascot.ceo => 'ceo',
      };

  /// Tanınmayan değer `null` döner; çağıranlar [Mascot.evHanimi]'ye düşer.
  static Mascot? fromDb(String? value) => switch (value) {
        'ev_hanimi' => Mascot.evHanimi,
        'arabeskci' => Mascot.arabeskci,
        'sanayi_ustasi' => Mascot.sanayiUstasi,
        'ceo' => Mascot.ceo,
        _ => null,
      };

  /// Personanın görsel aksesuarı.
  ///
  /// Eşleme burada duruyor çünkü `Mascot` personanın KİMLİĞİ, `KimoAccessory`
  /// ise çizim katmanının adı; ikisini tek enum yapmak maskot widget'ını
  /// veri katmanına bağlardı.
  KimoAccessory get accessory => switch (this) {
        Mascot.evHanimi => KimoAccessory.anac,
        Mascot.arabeskci => KimoAccessory.arabeskci,
        Mascot.sanayiUstasi => KimoAccessory.usta,
        Mascot.ceo => KimoAccessory.ceo,
      };

  /// Seçim yapılmamışsa kullanılan ton. Sunucudaki `send_push`'un
  /// `coalesce(mascot, 'ev_hanimi')` varsayılanıyla aynı olmak zorunda:
  /// ikisi ayrışırsa kullanıcı uygulamada bir sesi, bildirimde başkasını duyar.
  static const Mascot fallback = Mascot.evHanimi;
}
