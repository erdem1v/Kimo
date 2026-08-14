import 'dart:math';

import '../models/mascot.dart';

/// Bildirim senaryoları. Her senaryo için her maskotun kendi sesinden beş
/// cümle vardır; gönderim anında rastgele biri seçilir (aynı metin tekrar
/// edilince bildirim görünmez olur).
///
/// Yer tutucular:
///   {n}    → sayı (seri günü, soru adedi, gün sayısı)
///   {ad}   → arkadaşın takma adı
///   {sira} → lig sıralaması
///   {lig}  → lig adı
enum NotifyKind {
  /// Seri bugün sürdürülmedi, gece yarısı kırılacak.
  streakRisk,

  /// Bugün planlanmış tekrarlar var, henüz yapılmadı.
  reviewsDue,

  /// Lig haftasının son günü; sıralama kritik.
  leagueLastDay,

  /// Hafta kapandı, terfi/düşme sonucu.
  leagueResult,

  /// Arkadaş soru gönderdi.
  questionReceived,

  /// Arkadaşlık isteği geldi.
  friendRequest,

  /// Gönderdiğin soruyu arkadaşın çözdü.
  questionSolved,

  /// Uzun süredir uygulamaya girilmedi.
  comeback,
}

class MascotLines {
  const MascotLines._();

  static final Random _rnd = Random();

  /// Senaryo ve maskota göre rastgele bir cümle; yer tutucular doldurulur.
  static String pick(
    NotifyKind kind,
    Mascot mascot, {
    int? n,
    String? ad,
    int? sira,
    String? lig,
  }) {
    final List<String> lines = _lines[kind]?[mascot] ?? const <String>[];
    if (lines.isEmpty) return '';
    String s = lines[_rnd.nextInt(lines.length)];
    if (n != null) s = s.replaceAll('{n}', '$n');
    if (ad != null) s = s.replaceAll('{ad}', ad);
    if (sira != null) s = s.replaceAll('{sira}', '$sira');
    if (lig != null) s = s.replaceAll('{lig}', lig);
    return s;
  }

  /// Bildirime dokunulunca nereye gidileceğini belirleyen anahtar.
  /// Sunucudaki push_lines.kind ile aynı yazımı kullanır.
  static String payload(NotifyKind kind) => switch (kind) {
        NotifyKind.streakRisk => 'streak_risk',
        NotifyKind.reviewsDue => 'reviews_due',
        NotifyKind.leagueLastDay => 'league_last_day',
        NotifyKind.leagueResult => 'league_result',
        NotifyKind.questionReceived => 'question_received',
        NotifyKind.friendRequest => 'friend_request',
        NotifyKind.questionSolved => 'question_solved',
        NotifyKind.comeback => 'comeback',
      };

  /// Bildirim başlığı (kısa, senaryoya göre sabit).
  static String title(NotifyKind kind) => switch (kind) {
        NotifyKind.streakRisk => 'Serin tehlikede 🔥',
        NotifyKind.reviewsDue => 'Tekrar zamanı 🔁',
        NotifyKind.leagueLastDay => 'Ligde son gün ⚔️',
        NotifyKind.leagueResult => 'Hafta kapandı 🏆',
        NotifyKind.questionReceived => 'Sana soru geldi 📨',
        NotifyKind.friendRequest => 'Arkadaşlık isteği 🤝',
        NotifyKind.questionSolved => 'Soru çözüldü ✅',
        NotifyKind.comeback => 'Seni özledik 👋',
      };

  static const Map<NotifyKind, Map<Mascot, List<String>>> _lines =
      <NotifyKind, Map<Mascot, List<String>>>{
    // ------------------------------------------------------- seri tehlikede
    NotifyKind.streakRisk: <Mascot, List<String>>{
      Mascot.evHanimi: <String>[
        'Canım, {n} günlük serin gidiyor. Bir soru çöz de içim rahat etsin.',
        'Yavrum üşenme, tek soru yeter. {n} günlük emeğin var.',
        'Akşam oldu, hâlâ soru çözmedin. Serini düşün biraz.',
        '{n} gündür aksatmadın, bugün de aksatma olur mu?',
        'Bir soru çöz de yatarken huzurlu olayım.',
      ],
      Mascot.arabeskci: <String>[
        'Yandı gülüm {n} günlük serin, bir soru çöz de sönmesin.',
        'Bu seri benim her şeyimdi… bırakma dostum.',
        '{n} gün emek verdik, bir gecede yıkılmasın.',
        'Gözüm yollarda, elin soruda olsun.',
        'Seri gidiyor, gitme diyemedim sana.',
      ],
      Mascot.sanayiUstasi: <String>[
        'Usta, {n} günlük emek çöpe gidiyor. Geç tezgâha.',
        'Bugün elini sürmedin. Bir soru, bitti gitti.',
        'Serinin ipi kopmak üzere. Bağla şunu.',
        '{n} gün çalıştın, bugün mü bırakacaksın?',
        'Vardiya bitmedi. Bir soru kaldı.',
      ],
      Mascot.akademisyen: <String>[
        'Serinizin bugünkü koşulu sağlanmadı: en az bir tekrar.',
        '{n} günlük seriniz gece yarısı sona erecek.',
        'Bugün kayıt girilmedi. Sürekliliği korumanız önerilir.',
        'Tek bir tekrar, {n} günlük seriyi korumaya yeterlidir.',
        'Aralıklı tekrarın etkisi süreklilikle artar; bugünü boş geçmeyin.',
      ],
      Mascot.ceo: <String>[
        '{n} günlük seri risk altında. Bugünkü aksiyon tamamlanmadı.',
        'Günlük hedef sıfır. Kapatalım mı?',
        'Süreklilik metriğin bugün kırılıyor. Tek soru yeter.',
        '{n} gün üst üste performans — bugün düşürme.',
        'Son teslim gece yarısı. Bir soru, seri devam.',
      ],
    },

    // -------------------------------------------------------- tekrar zamanı
    NotifyKind.reviewsDue: <Mascot, List<String>>{
      Mascot.evHanimi: <String>[
        'Canım, bugün {n} soru bekliyor seni. Üşenme e mi?',
        'Sofra hazır, {n} tekrar seni bekliyor.',
        'Yavrum, biraz oturup {n} soru çözsen?',
        'Hataların seni özledi, {n} tane var.',
        'Bir çay koy, {n} soruyu birlikte halledelim.',
      ],
      Mascot.arabeskci: <String>[
        '{n} soru var dostum, gel şu dertle yüzleşelim.',
        'Eski hataların kapıda, {n} tane. Alalım içeri.',
        'Bugün {n} soru… biraz acıtacak ama iyi gelecek.',
        'Gel gel, {n} soru bekliyor. Kaçma kaderinden.',
        'Dert çok, soru {n}. Başlayalım.',
      ],
      Mascot.sanayiUstasi: <String>[
        'Tezgâhta {n} soru duruyor usta.',
        '{n} parça iş var, halledelim.',
        'Bugünün yükü {n} soru. Kolay gelsin.',
        'Aletleri kap, {n} soru bizi bekliyor.',
        'İş birikmesin: {n} tekrar hazır.',
      ],
      Mascot.akademisyen: <String>[
        'Bugün için {n} tekrar planlandı.',
        'Tekrar aralığınız doldu: {n} soru.',
        '{n} sorunun hatırlanma olasılığı bugün en yüksek.',
        'Planlanan {n} tekrar henüz tamamlanmadı.',
        'Bugünkü çalışma listeniz: {n} soru.',
      ],
      Mascot.ceo: <String>[
        'Bugünün kuyruğu: {n} soru.',
        '{n} görev açık. Kapatma zamanı.',
        'Günlük hedefe {n} soru uzaktasın.',
        '{n} tekrar bekliyor. Öncelik sırası hazır.',
        'Biriken iş: {n}. Bugün eritelim.',
      ],
    },

    // --------------------------------------------------------- ligde son gün
    NotifyKind.leagueLastDay: <Mascot, List<String>>{
      Mascot.evHanimi: <String>[
        'Ligde {sira}. sıradasın canım, son gün. Biraz gayret!',
        'Yavrum bugün kapanıyor, {sira}. sıradan kurtaralım seni.',
        'Son akşam. Bir iki soru, sıran yükselsin.',
        '{lig} elden gidecek, biraz çabala.',
        'Bugün son şansın, sonra üzülme.',
      ],
      Mascot.arabeskci: <String>[
        'Son gün dostum, {sira}. sıradayız. Kaderi değiştirelim.',
        '{lig} gidiyor elden, hâlâ tutabilirsin.',
        'Bu gece biter her şey. {sira}. sıra kader değil.',
        'Az kaldı, bir hamle yeter.',
        'Ağlamak yok, çözmek var. Son gün.',
      ],
      Mascot.sanayiUstasi: <String>[
        'Son gün usta, {sira}. sıradasın. Vites büyüt.',
        'Hafta kapanıyor, {lig} elden gitmesin.',
        '{sira}. sıra iyi değil. Bugün toparla.',
        'Mesai bitiyor, iş yarım.',
        'Son çıkış bugün. Sonrası yok.',
      ],
      Mascot.akademisyen: <String>[
        'Hafta bugün kapanıyor; sıralamanız {sira}.',
        '{sira}. sıradasınız; ilk beş üst lige geçecek.',
        'Bugünkü performans haftalık sonucu belirleyecek.',
        'Son gün: sıralamanız {sira}.',
        'Değerlendirme gece yarısı yapılacaktır.',
      ],
      Mascot.ceo: <String>[
        'Dönem kapanıyor. Sıra: {sira}.',
        'Son gün. {sira}. sıradan yukarı çıkmalıyız.',
        '{lig} pozisyonun risk altında.',
        'Bugün kapanış. Hedef: ilk beş.',
        'Son 24 saat. Sıralamayı düzelt.',
      ],
    },

    // -------------------------------------------------------- hafta sonucu
    NotifyKind.leagueResult: <Mascot, List<String>>{
      Mascot.evHanimi: <String>[
        'Müjde canım, {lig}\'ndesin! Gurur duydum.',
        'Yavrum {lig}\'nde artık, helal olsun.',
        'Bu hafta bitti, {lig}\'ndesin. Aferin sana.',
        'Emeklerin boşa gitmedi: {lig}.',
        'Yeni hafta, yeni grup. {lig}\'nde bekliyorum seni.',
      ],
      Mascot.arabeskci: <String>[
        'Yükseldik dostum, {lig}! Bu sevinç bizim.',
        'Kaderimiz döndü, {lig}\'ndeyiz.',
        'Hafta bitti, {lig} yazıldı alnımıza.',
        'Düştük ama bittik demek değil. {lig}\'nde toparlarız.',
        'Yeni hafta, yeni umut: {lig}.',
      ],
      Mascot.sanayiUstasi: <String>[
        'Hafta kapandı, {lig}\'ndesin. Hayırlı olsun.',
        'Terfi var usta: {lig}.',
        'Bu hafta iş iyi gitti: {lig}.',
        'Düşmüşüz. Toparlanır, {lig}\'nde çalışırız.',
        'Yeni hafta başladı, tezgâh yeni: {lig}.',
      ],
      Mascot.akademisyen: <String>[
        'Haftalık değerlendirme tamamlandı: {lig}.',
        'Sıralamanız sonucunda {lig}\'ne geçtiniz.',
        'Bu haftaki grubunuz {lig} olarak belirlendi.',
        'Sonuç: {lig}. Yeni hafta başladı.',
        'Performansınız {lig} ile sonuçlandı.',
      ],
      Mascot.ceo: <String>[
        'Dönem kapandı: {lig}. Tebrikler.',
        'Terfi onaylandı — {lig}.',
        'Yeni dönem, yeni lig: {lig}.',
        'Sonuç: {lig}. Hedefleri güncelleyelim.',
        'Performans değerlendirmesi: {lig}.',
      ],
    },

    // ------------------------------------------------------ arkadaştan soru
    NotifyKind.questionReceived: <Mascot, List<String>>{
      Mascot.evHanimi: <String>[
        '{ad} sana bir soru yolladı canım, bak bakalım.',
        'Arkadaşından soru geldi; {ad} çözebilecek misin diye merak ediyor.',
        '{ad}\'ın gönderdiği soru masada duruyor.',
        'Bir soru geldi {ad}\'dan, kırma çocuğu.',
        '{ad} seni düşünmüş, soru göndermiş.',
      ],
      Mascot.arabeskci: <String>[
        '{ad} bir soru yolladı, meydan okuyor sanki.',
        'Dostun {ad}\'dan bir soru… ağır olabilir.',
        '{ad} attı soruyu, top sende.',
        'Gel bakalım, {ad} ne yollamış.',
        '{ad}\'dan haber var, sorulu haber.',
      ],
      Mascot.sanayiUstasi: <String>[
        '{ad} bir iş yolladı. Bak bakalım.',
        'Tezgâha {ad}\'dan soru düştü.',
        '{ad} meydan okuyor usta.',
        'İş geldi: {ad}\'dan bir soru.',
        '{ad} sınıyor seni. Göster kendini.',
      ],
      Mascot.akademisyen: <String>[
        '{ad} size bir soru iletti.',
        'Yeni soru; gönderen: {ad}.',
        '{ad}\'ın paylaştığı soru çözüm bekliyor.',
        'Gelen kutunuzda {ad}\'dan bir soru var.',
        '{ad} tarafından bir soru gönderildi.',
      ],
      Mascot.ceo: <String>[
        '{ad}\'dan yeni bir görev geldi.',
        'Gelen soru: {ad}. Aksiyon bekliyor.',
        '{ad} sana bir soru atadı.',
        'Kuyruğuna {ad}\'dan bir soru eklendi.',
        '{ad} meydan okudu. Cevap ver.',
      ],
    },

    // --------------------------------------------------- arkadaşlık isteği
    NotifyKind.friendRequest: <Mascot, List<String>>{
      Mascot.evHanimi: <String>[
        '{ad} arkadaş olmak istiyor canım.',
        'Kapıda {ad} var, arkadaşlık istiyor.',
        '{ad} seni eklemiş, bir bak istersen.',
        'Yeni bir arkadaş: {ad}. Sevindim.',
        '{ad}\'dan istek geldi, bekletme.',
      ],
      Mascot.arabeskci: <String>[
        '{ad} dost olmak istiyor. Dostluk güzeldir.',
        'Bir istek var {ad}\'dan, gönül kapısı çalıyor.',
        '{ad} elini uzatmış, tut istersen.',
        'Yeni bir dost mu geliyor? {ad}.',
        '{ad} arkadaşlık istedi, çok düşünme.',
      ],
      Mascot.sanayiUstasi: <String>[
        '{ad} arkadaşlık istiyor. Karar senin.',
        'Yeni çırak mı geliyor? {ad} istek attı.',
        '{ad} ekibe katılmak istiyor.',
        'İstek var: {ad}.',
        '{ad} seni eklemiş usta.',
      ],
      Mascot.akademisyen: <String>[
        '{ad} arkadaşlık isteği gönderdi.',
        'Yeni bağlantı talebi: {ad}.',
        '{ad} sizinle bağlantı kurmak istiyor.',
        'Bekleyen arkadaşlık isteğiniz var: {ad}.',
        '{ad} tarafından istek iletildi.',
      ],
      Mascot.ceo: <String>[
        '{ad} ağına katılmak istiyor.',
        'Yeni bağlantı talebi: {ad}.',
        '{ad} arkadaşlık isteği gönderdi, onay bekliyor.',
        'Çevren büyüyor: {ad}.',
        '{ad}\'dan istek. Değerlendir.',
      ],
    },

    // --------------------------------------------------- gönderilen çözüldü
    NotifyKind.questionSolved: <Mascot, List<String>>{
      Mascot.evHanimi: <String>[
        '{ad} gönderdiğin soruyu çözdü, aferin ona.',
        'Soruna cevap geldi canım, {ad} bakmış.',
        '{ad} çözmüş bile, hadi bir tane daha yolla.',
        'Gönderdiğin soru boş kalmadı, {ad} uğraşmış.',
        '{ad}\'dan haber var: soru çözüldü.',
      ],
      Mascot.arabeskci: <String>[
        '{ad} çözdü soruyu, helal olsun.',
        'Yolladığın soru cevabını buldu: {ad}.',
        '{ad} altından kalktı, sen de boş durma.',
        'Soru gitti, cevap geldi. {ad}.',
        '{ad} meydanı boş bırakmadı.',
      ],
      Mascot.sanayiUstasi: <String>[
        '{ad} işi bitirmiş.',
        'Yolladığın soruyu {ad} halletti.',
        '{ad} tezgâhtan kalkmış, çözmüş.',
        'İş tamam: {ad} çözdü.',
        '{ad} eli yatkınmış, çözdü soruyu.',
      ],
      Mascot.akademisyen: <String>[
        '{ad} gönderdiğiniz soruyu çözdü.',
        'Sonuç bildirimi: {ad} yanıtladı.',
        '{ad} tarafından çözüm tamamlandı.',
        'Gönderdiğiniz soru {ad} tarafından cevaplandı.',
        '{ad}\'ın çözümü kaydedildi.',
      ],
      Mascot.ceo: <String>[
        '{ad} gönderdiğin soruyu kapattı.',
        'Görev tamamlandı: {ad}.',
        '{ad} çözdü. Bir tane daha gönder.',
        'Sonuç geldi: {ad} yanıtladı.',
        '{ad} teslim etti.',
      ],
    },

    // ------------------------------------------------------------ geri dönüş
    NotifyKind.comeback: <Mascot, List<String>>{
      Mascot.evHanimi: <String>[
        'Günlerdir yoksun canım, merak ettim.',
        '{n} gündür uğramadın, iyi misin?',
        'Kapıyı açık bıraktım, istediğin zaman gel.',
        'Hataların seni bekliyor, küsme onlara.',
        'Başlamak için bir soru yeter.',
      ],
      Mascot.arabeskci: <String>[
        '{n} gündür yoksun… beni de sorularını da bıraktın.',
        'Gitme demiştim, gittin.',
        'Dönersen kapı açık, sorular da öyle.',
        'Yokluğun ağır dostum.',
        'Bir soru çöz, eski günlere dönelim.',
      ],
      Mascot.sanayiUstasi: <String>[
        '{n} gündür tezgâh boş usta.',
        'İş birikti, gelsen iyi olur.',
        'Aletler paslanıyor. Gel şu işi yapalım.',
        'Uzun mola oldu. Toparlanalım.',
        'Kapıyı kapatmadım, bekliyorum.',
      ],
      Mascot.akademisyen: <String>[
        '{n} gündür çalışma kaydı yok.',
        'Ara verdiniz; unutma eğrisi işliyor.',
        'Tekrarlarınız birikti, planı güncelleyelim.',
        'Uzun aralar hatırlamayı zorlaştırır.',
        'Kaldığınız yerden devam edebilirsiniz.',
      ],
      Mascot.ceo: <String>[
        '{n} gündür aktivite yok.',
        'Performans durdu. Yeniden başlayalım.',
        'Biriken iş büyüyor. Kısa bir seans yeter.',
        'Ara uzadı, ivme kaybediyoruz.',
        'Bugün on dakika ayır, toparlarız.',
      ],
    },
  };
}
