/// Bir pratik oturumunun sonucu. Saf veri — hiçbir sunucu durumu yok.
///
/// Buradaki her sayı oturum boyunca **gerçekten olan** şeyden türüyor:
/// `xpGained` sunucunun döndürdüğü `xp_awarded` toplamı, `longestCombo`
/// sunucunun döndürdüğü `combo` değerlerinin en büyüğü, `gems` `claim_daily_goal`
/// çağrısının döndürdüğü ödül. Hiçbiri istemcide uydurulmuyor: task'ın kuralı
/// "arayüzde gösterilen her mekanik sunucuda gerçekten çalışıyor olmalı".
class SessionResult {
  const SessionResult({
    required this.solved,
    required this.correct,
    required this.firstTryCorrect,
    required this.longestCombo,
    required this.xpGained,
    required this.gemsAwarded,
    required this.streak,
    required this.streakGrew,
    required this.totalXp,
    required this.remaining,
    required this.goalReached,
  });

  /// Bu oturumda cevaplanan soru sayısı.
  final int solved;

  /// Doğru cevap sayısı.
  final int correct;

  /// İlk denemede doğru bilinen sayısı (bu sürümde tek deneme var, dolayısıyla
  /// [correct] ile aynı; ayrı tutuluyor çünkü "ikinci şans" eklenirse bu sayı
  /// ayrışacak ve o gün ekranın metni değişmemeli).
  final int firstTryCorrect;

  /// Oturum boyunca sunucudan dönen en büyük kombo.
  final int longestCombo;

  /// Sunucunun gerçekten verdiği XP toplamı (tavanlar uygulandıktan SONRA).
  final int xpGained;

  /// Günlük sandıktan çıkan elmas. 0 = sandık bu oturumda açılmadı.
  final int gemsAwarded;

  final int streak;

  /// Seri bu oturumda büyüdü mü (dünden bugüne geçiş).
  final bool streakGrew;

  final int totalXp;

  /// Listede kalan, çözülmemiş soru sayısı — "ekstra tur" teklifi bundan.
  final int remaining;

  /// Günlük hedefe bu oturumda ulaşıldı mı.
  final bool goalReached;

  /// XP'den türetilen seviye. Yeni sütun yok: seviye ayrı bir sayaç değil,
  /// toplam XP'nin okunuşu.
  static const int xpPerLevel = 1000;
  int get level => totalXp ~/ xpPerLevel + 1;

  /// Seviye şeridinin doluluğu (0–1).
  double get levelProgress => (totalXp % xpPerLevel) / xpPerLevel;

  int get xpToNextLevel => xpPerLevel - (totalXp % xpPerLevel);
}
