/// Sürüme göre açılıp kapanan arayüz parçaları.
///
/// Depoda uzaktan yapılandırma YOK ve `app_config` istemciye bilinçli olarak
/// kapalı (`lib/services/legal_links.dart` bu kararı yazıyor). Bu yüzden
/// mekanizma derleme zamanı: `SupabaseConfig` ve `LegalLinks` ile aynı desen,
/// yalnızca `String` yerine `bool`.
class Features {
  const Features._();

  /// Elmas v1'de arayüzde GİZLİ (Task 10).
  ///
  /// **Silinmedi.** Sunucu tarafı hiç değişmedi: `claim_daily_goal` elmas
  /// vermeye devam ediyor (göç `20260902000400_gems_reward.sql`) ve
  /// `my_daily_state.gems` hâlâ okunuyor. Yalnızca ÇİZİM kapatıldı, yani
  /// bakiyeler v1 boyunca birikiyor. v2'de AI koç gelince geri açılacak ve o
  /// an kullanıcıların bakiyesi hazır olacak.
  ///
  /// GERİ AÇMA REÇETESİ:
  ///   1. Göz kontrolü (kod değişikliği gerekmez):
  ///      `flutter run --dart-define-from-file=supabase.json \
  ///                   --dart-define=SHOW_GEMS=true`
  ///   2. v2'ye almak için bu dosyada TEK SATIR:
  ///      `bool.fromEnvironment('SHOW_GEMS')`
  ///      → `bool.fromEnvironment('SHOW_GEMS', defaultValue: true)`
  ///   3. `test/features/gems_hidden_test.dart` tersine çevrilir: şu an
  ///      GÖRÜNMEZ iddia ediyor, v2'de aynı üç iddia `findsOneWidget` ile.
  ///   4. Başka hiçbir şey. Göç yok, geri dolum yok.
  ///
  /// KAPILANAN ÜÇ YER (hepsi collection-`if`, hiçbir şey ölü sembol olmuyor):
  ///   * `features/home/today_screen.dart`      — HUD hapı
  ///   * `features/profile/profile_screen.dart` — rozet (HER İKİ DAL)
  ///   * `features/practice/session_end_screen.dart` — sandık kartı
  ///
  /// Sandık kartının içeriğinin TAMAMI elmas olduğu için kart bütün olarak
  /// çizilmiyor; kullanıcı boş bir sandık açmıyor. Günlük hedefin duyurusu
  /// (`sessionGoalReached`) ve ödülün XP kısmı (`+{xpGained}` karosu) yerinde
  /// kalıyor, yani ödül hâlâ görünür.
  /// NEDEN `ff_` AİLESİNE ALINMADI (Task 13 notu): Task 12 uzaktan bayrak
  /// altyapısını getirdi ve aşağıdaki üç sabit için "yürürlükteki karar
  /// sunucuda" diye yazıyor. Elmas o aileye BİLEREK alınmadı — bu bir kill
  /// switch değil, bir **v2 ürün kararı**. Uzaktan açılması istenmiyor: v2
  /// geldiğinde elmasın kazanımı, sandığı ve kutlaması birlikte dönecek ve o
  /// an bir `app_config` satırı değil bir sürüm gerekiyor.
  static const bool gemsVisible = bool.fromEnvironment('SHOW_GEMS');

  // ==================================================== sunucu bayrağı YEDEKLERİ
  //
  // Task 12 (0079) uzaktan açılıp kapanan bayrakları getirdi: `app_config` →
  // `feature_flags()` → `my_daily_state`. YÜRÜRLÜKTEKİ KARAR SUNUCUDA; aşağıdaki
  // üç sabit yalnızca **sütun okunamadığında** devreye giriyor
  // (`DailyState.pairStreakEnabled` ve kardeşleri).
  //
  // NEDEN HÂLÂ BURADA BİR DEĞER VAR: `DailyState == null` (ağ yok, oturum yok)
  // ile "bayrak false" ayrı iki şey. Görünüm okunamadığında riskli bir yüzeyi
  // çizmek ya da çizmemek bir karardır ve o karar derleme zamanında verilmiş
  // olmalı — çalışma zamanında tahmin edilmemeli.
  //
  // NEDEN `bool.fromEnvironment` DEĞİL: bunlar bir geliştirici anahtarı değil,
  // sunucu okunamadığındaki ÜRÜN varsayılanı. `--dart-define` ile
  // değiştirilebilir olmaları, iki ayrı kapatma yolu (sunucu + derleme)
  // olduğu yanılsamasını üretirdi; yürürlükteki tek yol sunucu.

  /// Ortak seri okunamadığında ÇİZİLMİYOR.
  ///
  /// Sunucu varsayılanıyla aynı (`ff_pair_streak = false`, göç 0079): AB
  /// Komisyonu'nun DSA Md. 28(1) Kılavuzu (14 Temmuz 2025, par. 57(b)(viii))
  /// "streaks"i küçükler için varsayılan kapalı istiyor. Kapalı tarafta hata
  /// yapmak burada doğru taraf.
  static const bool pairStreakFallback = false;

  /// Çoklu çekim okunamadığında çiziliyor: premium kapısı ayrıca var, yani
  /// yanlış tarafa düşmenin bedeli yalnızca bir paywall görmek.
  static const bool multiCaptureFallback = true;

  /// Ödüllü reklam okunamadığında çiziliyor: `ad_offer` zaten sunucudan geliyor
  /// ve o okunamadıysa reklam satırı da çizilmiyor — bu bayrak ondan önceki
  /// kaba anahtar.
  static const bool adRewardFallback = true;

  /// Satın alma okunamadığında ÇİZİLMİYOR.
  ///
  /// Diğer üçünden farklı olarak KAPALI tarafta duruyor, bilinçli: satın alma
  /// yüzeyi mağaza sorgusuna da bağlı (`PlusPlans.isConfigured` çalışma zamanı
  /// durumundan türüyor) ve sunucu okunamadığında "satın al" düğmesi çizmek,
  /// arkasında ne olduğunu bilmediğimiz bir düğme çizmek olurdu. Deponun
  /// kuralı: hiçbir şey yapmayan arayüz çizilmez.
  static const bool iapFallback = false;
}
