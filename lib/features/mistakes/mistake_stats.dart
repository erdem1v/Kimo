import '../../models/models.dart';
import '../reviews/domain/review_scheduler.dart';

/// "Hatalarım" ekranının bütün sayıları — saf veri, widget yok.
///
/// Ayrı bir dosyada çünkü **test edilebilir olması gerekiyor**: bu sayılar
/// (hâkim oranı, inatçı eşiği, son 7 günün pencereleri) ekranın iddialarının
/// tamamı ve hiçbiri sunucudan gelmiyor — hepsi mevcut alanlardan türüyor.
/// Bir widget'ın içinde hesaplansalardı ancak cihazda doğrulanabilirlerdi.
class MistakeStats {
  const MistakeStats({
    required this.total,
    required this.mastered,
    required this.learning,
    required this.dueToday,
    required this.leeches,
    required this.bySubject,
    required this.week,
    required this.weekLabels,
  });

  final int total;

  /// 30 günlük adımı doğru geçmiş, kuyruktan çıkmış sorular.
  final int mastered;

  /// Hâlâ tekrar kuyruğunda olanlar.
  final int learning;

  /// Bugün (ya da daha önce) tekrarı gelmiş, henüz hâkim olunmamışlar.
  final int dueToday;

  /// İnatçılar — en çok yanılınandan aza doğru sıralı.
  final List<MistakeEntry> leeches;

  /// Ders → soru sayısı, çoktan aza.
  final Map<String, int> bySubject;

  /// Son 7 günde eklenen soru sayısı; `week.last` = bugün.
  final List<int> week;

  /// `week` ile aynı sırada gün kısaltmaları.
  final List<String> weekLabels;

  static const List<String> _dayNames = <String>[
    'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz',
  ];

  /// İnatçı eşiği tek kaynaktan: zamanlayıcının kendi eşiği.
  ///
  /// Ekrandaki "en az dört kez" metni bu sabitle aynı olmak zorunda; ikisi
  /// ayrışırsa arayüz gerçekte olmayan bir kural anlatır.
  static const int leechThreshold = 4;

  int get masteredPercent =>
      total == 0 ? 0 : ((mastered / total) * 100).round();

  int get weekPeak => week.isEmpty ? 0 : week.reduce((int a, int b) => a > b ? a : b);

  /// [now] dışarıdan veriliyor: saat bağımlılığı olmadan test edilebilsin.
  factory MistakeStats.from(List<MistakeEntry> items, {DateTime? now}) {
    final DateTime today = _dateOnly(now ?? DateTime.now());

    int mastered = 0;
    int learning = 0;
    int dueToday = 0;
    final List<MistakeEntry> leeches = <MistakeEntry>[];
    final Map<String, int> bySubject = <String, int>{};
    final List<int> week = List<int>.filled(7, 0);

    for (final MistakeEntry e in items) {
      if (e.mastered) {
        mastered++;
      } else {
        learning++;
        // `dueReviews()` sorgusuyla BİREBİR aynı kural: hâkim olunmamış ve
        // planlanan gün bugün ya da geçmiş. Planı bilinmeyen (yerel) kayıt
        // sayılmıyor — bilinmeyeni "bugün" saymak sayıyı şişirirdi.
        final DateTime? due = e.nextReviewDate;
        if (due != null && !_dateOnly(due).isAfter(today)) dueToday++;
      }

      if (e.isLeech || e.lapses >= leechThreshold) leeches.add(e);

      bySubject[e.subject] = (bySubject[e.subject] ?? 0) + 1;

      final int ago = today.difference(_dateOnly(e.date)).inDays;
      if (ago >= 0 && ago < 7) week[6 - ago]++;
    }

    leeches.sort((MistakeEntry a, MistakeEntry b) => b.lapses.compareTo(a.lapses));

    final List<MapEntry<String, int>> sorted = bySubject.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));

    return MistakeStats(
      total: items.length,
      mastered: mastered,
      learning: learning,
      dueToday: dueToday,
      leeches: leeches,
      bySubject: Map<String, int>.fromEntries(sorted),
      week: week,
      weekLabels: <String>[
        for (int i = 6; i >= 0; i--)
          _dayNames[today.subtract(Duration(days: i)).weekday - 1],
      ],
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Zamanlayıcının kendi eşiği — [MistakeStats.leechThreshold] ile aynı olmak
/// zorunda. Derleyici bunu yakalayamıyor (biri `const`, diğeri bir örnek
/// alanı), bu yüzden `test/features/mistakes/mistake_stats_test.dart` ikisinin
/// eşitliğini açıkça iddia ediyor. Ayrışırlarsa arayüz gerçekte olmayan bir
/// kural anlatır.
final int schedulerLeechThreshold = const ReviewScheduler().leechThreshold;
