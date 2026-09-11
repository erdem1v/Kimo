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
  static const bool gemsVisible = bool.fromEnvironment('SHOW_GEMS');
}
