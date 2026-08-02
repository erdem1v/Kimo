/// Uygulama genelinde kullanılan sabitler.
///
/// Not: Bunlar oyunlaştırma dengesi (game balance) için başlangıç değerleridir;
/// ileride uzaktan yapılandırma (Remote Config) ile ayarlanabilir.
class AppConstants {
  const AppConstants._();

  /// Doğru cevap başına kazanılan XP.
  static const int xpPerCorrectAnswer = 10;

  /// Bir seansa başlarken varsayılan can sayısı.
  static const int initialHearts = 5;

  /// Demoda gösterilen örnek günlük seri (streak).
  static const int demoStreak = 3;
}
