import '../models/models.dart';

/// Supabase yapılandırılmamışken (yerel çalıştırma, ekran görüntüsü, test)
/// hata bankasını dolduran örnek kayıtlar.
///
/// Sahte KOÇ cevapları, uydurma rozetler ve kullanılmayan konu kartları
/// buradan kaldırıldı: hiçbiri gerçek bir mekaniğe karşılık gelmiyordu.
class MockData {
  const MockData._();

  static List<MistakeEntry> seedMistakes() => <MistakeEntry>[
        MistakeEntry(
          subject: 'Matematik',
          concept: 'Hız - Zaman Problemleri',
          type: MistakeType.bilgiEksigi,
          note: 'Yol = hız × zaman formülünü ters kurdum.',
          date: DateTime(2026, 7, 30),
          hasPhoto: true,
        ),
        MistakeEntry(
          subject: 'Geometri',
          concept: 'Çemberde Açılar',
          type: MistakeType.islemHatasi,
          note: 'Merkez açıyı çevre açı sanıp 2 ile çarpmayı unuttum.',
          date: DateTime(2026, 7, 28),
        ),
        MistakeEntry(
          subject: 'Fizik',
          concept: 'Düzgün Hızlanan Hareket',
          type: MistakeType.dikkatsizlik,
          note: 'cm/s → m/s birim çevrimini atladım.',
          date: DateTime(2026, 7, 26),
          hasPhoto: true,
        ),
      ];
}
