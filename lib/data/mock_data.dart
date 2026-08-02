import '../models/models.dart';

/// Tüm ekranları besleyen sahte (mock) veriler. Gerçek veri katmanı ileride
/// buraya bağlanacak; şimdilik yalnızca arayüz için.
class MockData {
  const MockData._();

  static const List<PracticeQuestion> practiceQuestions = <PracticeQuestion>[
    PracticeQuestion(
      subject: 'TYT Matematik',
      concept: 'Oran - Orantı',
      text:
          'Bir sınıftaki kızların erkeklere oranı 3/5\'tir. Sınıfta toplam 24 öğrenci varsa kaç kız öğrenci vardır?',
      options: <String>['9', '12', '15', '10'],
      correctIndex: 0,
      explanation:
          'Kız/Erkek = 3/5 → toplam 3+5 = 8 pay. 24 ÷ 8 = 3. Kızlar 3 × 3 = 9.',
    ),
    PracticeQuestion(
      subject: 'TYT Matematik',
      concept: 'Yüzde Problemleri',
      text:
          'Bir ürün %20 indirimle 240 TL\'ye satılıyor. Ürünün indirimsiz fiyatı kaç TL\'dir?',
      options: <String>['280', '300', '320', '288'],
      correctIndex: 1,
      explanation:
          '%20 indirim → satış fiyatı, asıl fiyatın %80\'i. 240 ÷ 0,80 = 300 TL.',
    ),
    PracticeQuestion(
      subject: 'TYT Geometri',
      concept: 'Dik Üçgen',
      text:
          'Dik kenarları 6 cm ve 8 cm olan bir dik üçgenin hipotenüsü kaç cm\'dir?',
      options: <String>['10', '12', '14', '9'],
      correctIndex: 0,
      explanation: 'Pisagor: √(6² + 8²) = √(36 + 64) = √100 = 10 cm.',
    ),
    PracticeQuestion(
      subject: 'TYT Matematik',
      concept: 'Sayı Örüntüleri',
      text: '2, 6, 12, 20, ... örüntüsünde 5. terim kaçtır?',
      options: <String>['28', '30', '25', '32'],
      correctIndex: 1,
      explanation: 'Kural n·(n+1): 1·2=2, 2·3=6, 3·4=12, 4·5=20, 5·6=30.',
    ),
    PracticeQuestion(
      subject: 'TYT Matematik',
      concept: 'Birinci Dereceden Denklem',
      text: '3x − 7 = 11 denkleminde x kaçtır?',
      options: <String>['4', '5', '6', '7'],
      correctIndex: 2,
      explanation: '3x = 11 + 7 = 18 → x = 18 ÷ 3 = 6.',
    ),
    PracticeQuestion(
      subject: 'TYT Geometri',
      concept: 'Üçgende Açılar',
      text: 'Bir üçgenin iç açıları toplamı kaç derecedir?',
      options: <String>['90°', '180°', '270°', '360°'],
      correctIndex: 1,
      explanation: 'Her üçgenin iç açıları toplamı her zaman 180°\'dir.',
    ),
  ];

  static const List<ChatMessage> initialChat = <ChatMessage>[
    ChatMessage(
      'Selam! 👋 Ben senin YKS koçunum. Bugün neye çalışmak istersin? İstersen sana kişisel bir tekrar planı çıkarabilirim.',
    ),
    ChatMessage('Matematik netim biraz düşük, ne yapmalıyım?', isUser: true),
    ChatMessage(
      'Anladım. En hızlı yol, yanlış yaptığın soruları düzenli tekrar etmek. Hata bankana son eklediğin "Oran-Orantı" konusundan başlayalım mı? 💪',
    ),
  ];

  static const List<String> quickReplies = <String>[
    'Bugün ne çalışmalıyım?',
    'Matematik netim düşük',
    'Beni motive et',
    'Bu konuyu açıkla',
  ];

  static const List<String> coachReplies = <String>[
    'Harika bir soru! 📚 Sana bugün için 10 soruluk kısa bir matematik tekrarı öneriyorum. "Bugün" sekmesinden hemen başlayabilirsin.',
    'Netini yükseltmenin en hızlı yolu, yanlışlarını tekrar etmek. Bu hafta hata bankana 3 soru eklemişsin, aferin! Şimdi onları çözme zamanı. 🎯',
    'Motivasyon mu lazım? 🔥 Unutma: her doğru cevap seni hedefine bir adım yaklaştırır. 12 günlük serini sakın bozma!',
    'Bu konuyu 3 adımda halledelim: 1) Temel kuralı tekrar et, 2) 2 örnek çöz, 3) yanlışını hata bankasına ekle. Hazırsan "Bugün" sekmesine geçelim. 😊',
  ];

  static const List<TopicCard> topics = <TopicCard>[
    TopicCard(
        emoji: '🔢',
        title: 'Sayılar',
        subtitle: 'TYT Matematik',
        progress: 0.8),
    TopicCard(
        emoji: '📐',
        title: 'Geometri',
        subtitle: 'TYT · Üçgenler',
        progress: 0.45),
    TopicCard(
        emoji: '⚛️',
        title: 'Fizik',
        subtitle: 'TYT · Hareket',
        progress: 0.3),
    TopicCard(
        emoji: '📖',
        title: 'Paragraf',
        subtitle: 'TYT Türkçe',
        progress: 0.6),
    TopicCard(
        emoji: '🧪',
        title: 'Kimya',
        subtitle: 'TYT · Karışımlar',
        progress: 0.1),
  ];

  static const List<AchievementBadge> badges = <AchievementBadge>[
    AchievementBadge(emoji: '🔥', title: '7 Gün Seri', earned: true),
    AchievementBadge(emoji: '💯', title: '100 Soru', earned: true),
    AchievementBadge(emoji: '🌅', title: 'Erken Kuş', earned: true),
    AchievementBadge(emoji: '🎯', title: 'Hedefi Tuttur', earned: false),
    AchievementBadge(emoji: '🏆', title: 'Lig Şampiyonu', earned: false),
    AchievementBadge(emoji: '📚', title: '500 Soru', earned: false),
  ];

  static List<MistakeEntry> seedMistakes() => <MistakeEntry>[
        MistakeEntry(
          subject: 'Matematik',
          concept: 'Hız - Zaman Problemleri',
          type: MistakeType.kavramEksikligi,
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
