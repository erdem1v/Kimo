import '../state/user_profile.dart';

/// Müfredat haritasının içeriği: ders → ünite → konu.
///
/// ÖNEMLİ: Buradaki konu adları, Edge Function'daki `taxonomy.ts` ile BİREBİR
/// aynı olmalıdır. AI çözülen sorunun konusunu o listeden seçer; harita da
/// ilerlemeyi bu adla eşleştirir. Biri değişirse diğeri de değişmeli.
///
/// Ünite adları MEB öğrenme alanları / yaygın ders kitabı üniteleriyle
/// uyumludur.
class Unit {
  const Unit(this.name, this.topics);

  final String name;
  final List<String> topics;
}

class YksCurriculum {
  const YksCurriculum._();

  /// [curriculum] ('eski'|'maarif') ve [exam] ('TYT'|'AYT') için ders → üniteler.
  static Map<String, List<Unit>> forExam(String curriculum, String exam) {
    final bool maarif = curriculum == UserProfile.maarif;
    if (maarif) return exam == 'AYT' ? _maarifAyt : _maarifTyt;
    return exam == 'AYT' ? _eskiAyt : _eskiTyt;
  }

  /// Bir dersteki toplam konu sayısı.
  static int topicCount(List<Unit> units) =>
      units.fold(0, (int a, Unit u) => a + u.topics.length);

  // ======================================================= ESKİ MÜFREDAT TYT
  static const Map<String, List<Unit>> _eskiTyt = <String, List<Unit>>{
    'Türkçe': <Unit>[
      Unit('Anlam Bilgisi', <String>[
        'Sözcükte Anlam', 'Cümlede Anlam', 'Paragrafta Anlam',
      ]),
      Unit('Dil Bilgisi', <String>[
        'Ses Bilgisi', 'Biçim Bilgisi', 'Sözcük Türleri', 'Fiiller',
        'Cümlenin Ögeleri', 'Cümle Türleri',
      ]),
      Unit('Yazım ve Anlatım', <String>[
        'Yazım Kuralları', 'Noktalama İşaretleri', 'Anlatım Bozuklukları',
      ]),
    ],
    'Matematik': <Unit>[
      Unit('Mantık', <String>['Önermeler ve Bileşik Önermeler']),
      Unit('Kümeler', <String>[
        'Kümelerde Temel Kavramlar', 'Kümelerde İşlemler',
      ]),
      Unit('Sayılar ve Denklemler', <String>[
        'Sayı Kümeleri', 'Bölünebilme Kuralları',
        'Birinci Dereceden Denklemler ve Eşitsizlikler',
        'Üslü İfadeler ve Denklemler',
        'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar',
      ]),
      Unit('Veri', <String>[
        'Merkezi Eğilim ve Yayılım Ölçüleri',
        'Verilerin Grafikle Gösterilmesi',
      ]),
      Unit('Sayma ve Olasılık', <String>[
        'Sıralama ve Seçme', 'Basit Olayların Olasılıkları',
      ]),
      Unit('Fonksiyonlar', <String>[
        'Fonksiyon Kavramı ve Gösterimi',
        'İki Fonksiyonun Bileşkesi ve Bir Fonksiyonun Tersi',
      ]),
      Unit('Polinomlar', <String>[
        'Polinom Kavramı ve Polinomlarda İşlemler',
        'Polinomların Çarpanlara Ayrılması',
      ]),
      Unit('İkinci Dereceden Denklemler', <String>[
        'İkinci Dereceden Bir Bilinmeyenli Denklemler',
      ]),
    ],
    'Geometri': <Unit>[
      Unit('Üçgenler', <String>[
        'Üçgenlerde Temel Kavramlar', 'Üçgenlerde Eşlik ve Benzerlik',
        'Üçgenin Yardımcı Elemanları', 'Dik Üçgen ve Trigonometri',
        'Üçgenin Alanı',
      ]),
      Unit('Dörtgenler ve Çokgenler', <String>[
        'Çokgenler', 'Dörtgenler ve Özellikleri', 'Özel Dörtgenler',
      ]),
      Unit('Katı Cisimler', <String>['Katı Cisimler']),
    ],
    'Fizik': <Unit>[
      Unit('Mekanik', <String>[
        'Fizik Bilimine Giriş',
        'Madde ve Özellikleri',
        'Hareket ve Kuvvet',
        'Enerji',
        'Basınç ve Kaldırma Kuvveti',
      ]),
      Unit('Isı, Elektrik ve Manyetizma', <String>[
        'Isı ve Sıcaklık',
        'Elektrostatik',
        'Elektrik ve Manyetizma',
      ]),
      Unit('Dalgalar ve Optik', <String>[
        'Dalgalar',
        'Optik',
      ]),

    ],
    'Kimya': <Unit>[
      Unit('Kimyanın Temelleri', <String>[
        'Kimya Bilimi',
        'Atom ve Periyodik Sistem',
        'Kimyasal Türler Arası Etkileşimler',
      ]),
      Unit('Maddenin Hâlleri ve Karışımlar', <String>[
        'Maddenin Hâlleri',
        'Kimyanın Temel Kanunları ve Kimyasal Hesaplamalar',
        'Karışımlar',
      ]),
      Unit('Asitler, Bazlar ve Günlük Kimya', <String>[
        'Asitler, Bazlar ve Tuzlar',
        'Kimya Her Yerde',
        'Doğa ve Kimya',
      ]),

    ],
    'Biyoloji': <Unit>[
      Unit('Canlıların Temel Bileşenleri', <String>[
        'Canlıların Ortak Özellikleri',
        'Canlıların Yapısında Bulunan İnorganik Bileşikler',
        'Canlıların Yapısında Bulunan Organik Bileşikler',
      ]),
      Unit('Hücre', <String>[
        'Hücresel Yapılar ve Görevleri',
        'Hücre Zarından Madde Geçişleri',
        'Hücre Döngüsü ve Mitoz',
        'Eşeysiz Üreme',
        'Mayoz',
        'Eşeyli Üreme',
      ]),
      Unit('Canlılar Dünyası ve Kalıtım', <String>[
        'Canlıların Sınıflandırılması',
        'Canlı Âlemleri',
        'Kalıtım',
        'Genetik Varyasyonlar',
      ]),
      Unit('Ekoloji', <String>[
        'Ekosistem Ekolojisi',
        'Güncel Çevre Sorunları',
        'Doğal Kaynakların Sürdürülebilirliği',
        'Biyolojik Çeşitliliğin Korunması',
      ]),

    ],
    'Tarih': <Unit>[
      Unit('Tarih Bilimi', <String>['Tarih ve Zaman']),
      Unit('İlk Çağlardan Türk-İslam Dünyasına', <String>[
        'İlk ve Orta Çağlarda Türk Dünyası', 'İslam Medeniyetinin Doğuşu',
        "Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet'i Kabulü",
        'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi',
      ]),
      Unit('Osmanlı Tarihi', <String>[
        'Beylikten Devlete Osmanlı Siyaseti (1302-1453)',
        'Devletleşme Sürecinde Savaşçılar ve Askerler',
        'Beylikten Devlete Osmanlı Medeniyeti',
        'Dünya Gücü Osmanlı (1453-1595)', 'Sultan ve Osmanlı Merkez Teşkilatı',
        'Klasik Çağda Osmanlı Toplum Düzeni',
        'Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774)',
        'Değişim Çağında Avrupa ve Osmanlı',
        'Uluslararası İlişkilerde Denge Stratejisi (1774-1914)',
      ]),
      Unit('Yakın Çağ ve Cumhuriyet', <String>[
        'Devrimler Çağında Değişen Devlet-Toplum İlişkileri',
        'XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat',
        'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya', 'Millî Mücadele',
        'Atatürkçülük ve Türk İnkılabı',
      ]),
    ],
    'Coğrafya': <Unit>[
      Unit('Doğal Sistemler', <String>[
        'Coğrafya Bilimi, İnsan ve Doğa', "Dünya'nın Şekli ve Hareketleri",
        'Yer ve Zaman, Koordinat Sistemi', 'Harita Bilimi', 'İklim Bilimi',
        "Dünya'nın Yapısı ve Oluşum Süreci",
        'Su Kaynakları, Topraklar, Bitkiler',
      ]),
      Unit('Beşerî Sistemler', <String>[
        'Yerleşmeler', 'Nüfus, Göç, Ekonomik Faaliyetler', 'Ulaşım',
      ]),
      Unit('Küresel Ortam', <String>['Bölgeler ve Ülkeler']),
      Unit('Çevre ve Toplum', <String>['İnsan ve Çevre', 'Afetler']),
    ],
    'Felsefe': <Unit>[
      Unit('Felsefeye Giriş', <String>[
        'Felsefeyi Tanıma', 'Felsefe ile Düşünme', 'Felsefi Okuma ve Yazma',
      ]),
      Unit('Felsefenin Temel Konuları', <String>[
        'Varlık Felsefesi', 'Bilgi Felsefesi', 'Bilim Felsefesi',
        'Ahlak Felsefesi', 'Din Felsefesi', 'Siyaset Felsefesi',
        'Sanat Felsefesi',
      ]),
      Unit('Felsefe Tarihi', <String>[
        'MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi',
        'MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi',
        '15. Yüzyıl-17. Yüzyıl Felsefesi', '18. Yüzyıl-19. Yüzyıl Felsefesi',
        '20. Yüzyıl Felsefesi',
      ]),
    ],
    'Din Kültürü': <Unit>[
      Unit('İnanç', <String>[
        'Bilgi ve İnanç', 'Din ve İslam', 'Allah İnsan İlişkisi',
        'İslam Düşüncesinde İtikadi, Siyasi ve Fıkhi Yorumlar',
      ]),
      Unit('İbadet ve Ahlak', <String>[
        'İslam ve İbadet', 'Ahlaki Tutum Davranışlar', 'Din ve Hayat',
      ]),
      Unit('Değerler ve Kültür', <String>[
        'Gençlik ve Değerler', 'Gönül Coğrafyamız', 'Hz. Muhammed ve Gençlik',
      ]),
    ],
  };

  // ======================================================= ESKİ MÜFREDAT AYT
  static const Map<String, List<Unit>> _eskiAyt = <String, List<Unit>>{
    'Matematik': <Unit>[
      Unit('Trigonometri', <String>[
        'Yönlü Açılar', 'Trigonometrik Fonksiyonlar',
        'Toplam-Fark ve İki Kat Açı Formülleri', 'Trigonometrik Denklemler',
      ]),
      Unit('Fonksiyonlarda Uygulamalar', <String>[
        'Fonksiyonların Grafik ve Problemleri',
        'İkinci Dereceden Fonksiyonlar ve Grafikleri',
        'Fonksiyonların Dönüşümleri',
      ]),
      Unit('Denklem ve Eşitsizlik Sistemleri', <String>[
        'İkinci Dereceden İki Bilinmeyenli Denklem Sistemleri',
        'İkinci Dereceden Eşitsizlikler',
      ]),
      Unit('Üstel ve Logaritmik Fonksiyonlar', <String>[
        'Üstel Fonksiyon', 'Logaritma Fonksiyonu',
        'Üstel ve Logaritmik Denklem ve Eşitsizlikler',
      ]),
      Unit('Diziler', <String>['Diziler']),
      Unit('Türev', <String>[
        'Limit ve Süreklilik', 'Türev', 'Türev Uygulamaları',
      ]),
      Unit('İntegral', <String>[
        'Belirsiz İntegral', 'Belirli İntegral ve Alan Hesabı',
      ]),
      Unit('Olasılık', <String>[
        'Koşullu Olasılık', 'Deneysel ve Teorik Olasılık',
      ]),
    ],
    'Geometri': <Unit>[
      Unit('Analitik Geometri', <String>[
        'Doğrunun Analitik İncelenmesi', 'Çemberin Analitik İncelenmesi',
      ]),
      Unit('Dönüşümler', <String>['Analitik Düzlemde Temel Dönüşümler']),
      Unit('Çember ve Daire', <String>[
        'Çemberde Temel Kavramlar', 'Çemberde Açılar', 'Çemberde Teğet',
        'Dairenin Çevresi ve Alanı',
      ]),
      Unit('Uzay Geometri', <String>[
        'Katı Cisimler (Küre, Silindir, Koni)',
      ]),
    ],
    'Fizik': <Unit>[
      Unit('Mekanik', <String>[
        'Kuvvet ve Hareket',
        'Çembersel Hareket',
        'Basit Harmonik Hareket',
      ]),
      Unit('Elektromanyetizma ve Dalgalar', <String>[
        'Elektrik ve Manyetizma',
        'Dalga Mekaniği',
      ]),
      Unit('Modern Fizik', <String>[
        'Atom Fiziğine Giriş ve Radyoaktivite',
        'Modern Fizik',
        'Modern Fiziğin Teknolojideki Uygulamaları',
      ]),

    ],
    'Kimya': <Unit>[
      Unit('Atom, Gazlar ve Çözeltiler', <String>[
        'Modern Atom Teorisi',
        'Gazlar',
        'Sıvı Çözeltiler ve Çözünürlük',
      ]),
      Unit('Tepkimelerde Enerji, Hız ve Denge', <String>[
        'Kimyasal Tepkimelerde Enerji',
        'Kimyasal Tepkimelerde Hız',
        'Kimyasal Tepkimelerde Denge',
      ]),
      Unit('Elektrokimya ve Organik Kimya', <String>[
        'Kimya ve Elektrik',
        'Karbon Kimyasına Giriş',
        'Organik Bileşikler',
        'Enerji Kaynakları ve Bilimsel Gelişmeler',
      ]),

    ],
    'Biyoloji': <Unit>[
      Unit('İnsan Fizyolojisi', <String>[
        'Sinir Sistemi',
        'Endokrin Sistem',
        'İskelet Sistemi',
        'Kas Sistemi',
        'Duyu Organları',
        'Kan Dolaşımı',
        'Lenf Dolaşımı',
        'Sindirim Sistemi',
        'Solunum Sistemi',
        'Üriner Sistem',
        'Üreme Sistemi',
        'Bağışıklık Sistemi',
        'Embriyonik Gelişim',
      ]),
      Unit('Ekoloji', <String>[
        'Komünite Ekolojisi',
        'Popülasyon Ekolojisi',
      ]),
      Unit('Genetik ve Enerji Dönüşümleri', <String>[
        'Nükleik Asitler',
        'Genetik Şifre ve Protein Sentezi',
        'Genetik Mühendisliği ve Biyoteknoloji',
        'Canlılık ve Enerji',
        'Fotosentez',
        'Kemosentez',
        'Hücresel Solunum',
        'Fermantasyon',
      ]),
      Unit('Bitki Biyolojisi', <String>[
        'Bitkisel Dokular',
        'Bitkisel Organlar',
        'Bitkilerde Madde Taşınması',
        'Bitkilerde Hareket',
        'Bitki Hormonları',
        'Bitkilerde Eşeyli Üreme',
        'Canlılar ve Çevre',
      ]),

    ],
    'Edebiyat': <Unit>[
      Unit('Giriş ve Genel Konular', <String>[
        'Edebiyata Giriş',
        'Şiir Bilgisi',
        'Edebî Sanatlar',
        'Edebî Akımlar',
      ]),
      Unit('Şiir', <String>[
        'İslamiyet Öncesi Türk Şiiri',
        'Geçiş Dönemi Türk Şiiri',
        'Halk Şiiri',
        'Divan Şiiri',
        'Tanzimat Dönemi Türk Şiiri',
        'Servetifünun Dönemi Türk Şiiri',
        'Fecriati Dönemi Türk Şiiri',
        'Millî Edebiyat Dönemi Türk Şiiri',
        'Cumhuriyet Dönemi Türk Şiiri',
      ]),
      Unit('Hikâye', <String>[
        'Hikâye Türleri ve Hikâyenin Yapı Unsurları',
        "Tanzimat Dönemi'ne Kadar Halk Hikâyesi ve Mesneviler",
        'Tanzimat ve Servetifünun Dönemi Türk Hikâyesi',
        'Millî Edebiyat Dönemi Türk Hikâyesi',
        'Cumhuriyet Dönemi Türk Hikâyesi',
      ]),
      Unit('Roman', <String>[
        'Roman Türü ve Yapı Unsurları',
        'Tanzimat Dönemi Türk Romanı',
        'Servetifünun Dönemi Türk Romanı',
        'Millî Edebiyat Dönemi Türk Romanı',
        'Cumhuriyet Dönemi Türk Romanı',
        'Dünya Edebiyatında Roman',
      ]),
      Unit('Tiyatro', <String>[
        'Tiyatro Türü ve Yapı Unsurları',
        'Geleneksel Türk Tiyatrosu',
        'Tanzimat, Servetifünun ve Millî Edebiyat Dönemi Türk Tiyatrosu',
        'Cumhuriyet Dönemi Türk Tiyatrosu',
      ]),
      Unit('Diğer Türler', <String>[
        'Masal/Fabl',
        'Destan/Efsane',
        'Öğretici Metinler',
        'Divan Edebiyatı Nesir Türleri',
      ]),

    ],
    'Tarih': <Unit>[
      Unit('Tarih Bilimi', <String>[
        'Tarih ve Zaman',
      ]),
      Unit('İlk Çağlardan Türk-İslam Dünyasına', <String>[
        'İlk ve Orta Çağlarda Türk Dünyası',
        'İslam Medeniyetinin Doğuşu',
        "Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet'i Kabulü",
        'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi',
      ]),
      Unit('Osmanlı Tarihi', <String>[
        'Beylikten Devlete Osmanlı Siyaseti (1302-1453)',
        'Devletleşme Sürecinde Savaşçılar ve Askerler',
        'Beylikten Devlete Osmanlı Medeniyeti',
        'Dünya Gücü Osmanlı (1453-1595)',
        'Sultan ve Osmanlı Merkez Teşkilatı',
        'Klasik Çağda Osmanlı Toplum Düzeni',
        'Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774)',
        'Değişim Çağında Avrupa ve Osmanlı',
        'Uluslararası İlişkilerde Denge Stratejisi (1774-1914)',
      ]),
      Unit('Yakın Çağ ve Cumhuriyet', <String>[
        'Devrimler Çağında Değişen Devlet-Toplum İlişkileri',
        'XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat',
        'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya',
        'Millî Mücadele',
        'Atatürkçülük ve Türk İnkılabı',
      ]),
      Unit('Çağdaş Türkiye ve Dünya', <String>[
        'İki Savaş Arasındaki Dönemde Türkiye ve Dünya',
        'II. Dünya Savaşı Sürecinde Türkiye ve Dünya',
        'II. Dünya Savaşı Sonrasında Türkiye ve Dünya',
        'Toplumsal Devrim Çağında Dünya ve Türkiye',
        'XXI. Yüzyılın Eşiğinde Türkiye ve Dünya',
      ]),

    ],
    'Coğrafya': <Unit>[
      Unit('Ekosistem ve Doğa', <String>[
        'Ekosistemlerin İşleyişi ve Özellikleri',
        'Ekstrem Doğa Olayları ve Doğa Olaylarının Geleceği',
      ]),
      Unit('Beşerî ve Ekonomik Sistemler', <String>[
        'Nüfus Politikaları ve Yerleşmeler',
        'Ekonomik Faaliyetler ve Doğal Kaynaklar',
        "Türkiye'de Ekonomi",
        'Ekonomi, Şehirleşme ve Göç',
        'Ulaşım, Ticaret, Turizm',
        "Türkiye'nin İşlevsel Bölgeleri ve Kalkınma Projeleri",
      ]),
      Unit('Kültür ve Küresel Ortam', <String>[
        'Kültür Bölgeleri',
        'Küreselleşen Dünya',
        'Jeopolitik Konum ve Ülkeler Arası Etkileşim',
      ]),
      Unit('Çevre ve Toplum', <String>[
        'Çevre Sorunları',
        'Doğal Çevrenin Sınırlılığı, Çevresel Örgüt ve Anlaşmalar',
      ]),

    ],
    'Felsefe Grubu': <Unit>[
      Unit('Felsefe', <String>[
        'Felsefeyi Tanıma',
        'Felsefe ile Düşünme',
        'Felsefi Okuma ve Yazma',
        'Varlık Felsefesi',
        'Bilgi Felsefesi',
        'Bilim Felsefesi',
        'Ahlak Felsefesi',
        'Din Felsefesi',
        'Siyaset Felsefesi',
        'Sanat Felsefesi',
        'MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi',
        'MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi',
        '15. Yüzyıl-17. Yüzyıl Felsefesi',
        '18. Yüzyıl-19. Yüzyıl Felsefesi',
        '20. Yüzyıl Felsefesi',
      ]),
      Unit('Mantık', <String>[
        'Mantığa Giriş',
        'Klasik Mantık',
        'Mantık ve Dil',
        'Sembolik Mantık',
      ]),
      Unit('Psikoloji', <String>[
        'Psikoloji Bilimini Tanıyalım',
        'Psikolojinin Temel Süreçleri',
        'Öğrenme, Bellek, Düşünme',
        'Ruh Sağlığının Temelleri',
      ]),
      Unit('Sosyoloji', <String>[
        'Sosyolojiye Giriş',
        'Toplumsal Yapı',
        'Birey ve Toplum',
        'Toplum ve Kültür',
        'Toplumsal Kurumlar',
        'Toplumsal Değişme ve Gelişme',
      ]),

    ],
    'Din Kültürü': <Unit>[
      Unit('İnanç ve İbadet', <String>[
        'Dünya ve Ahiret',
        'İnançla İlgili Meseleler',
      ]),
      Unit("Kur'an ve Hz. Muhammed", <String>[
        "Kur'an'a Göre Hz. Muhammed",
        "Kur'an'da Bazı Kavramlar",
      ]),
      Unit('Dinler ve Kültür', <String>[
        'Yahudilik ve Hristiyanlık',
        'Hint ve Çin Dinleri',
        "Anadolu'da İslam",
      ]),
      Unit('İslam Düşüncesi', <String>[
        'İslam ve Bilim',
        'İslam Düşüncesinde Tasavvufi Yorumlar',
        'Güncel Dinî Meseleler',
      ]),

    ],
  };

  // ==================================================== MAARİF MODELİ (2028+)
  static const Map<String, List<Unit>> _maarifTyt = <String, List<Unit>>{
    'Türkçe': <Unit>[
      Unit('Metin Türleri', <String>[
        'Şiir', 'Öyküleyici Metin', 'Tiyatro', 'Öğretici Metin',
      ]),
      Unit('Dil Bilgisi', <String>[
        'Ses Bilgisi', 'Yapı Bilgisi (Ekler)', 'İsim ve Sıfat',
        'Zamir-Zarf-Edat', 'Fiil ve Fiilimsi', 'Cümlenin Ögeleri',
        'Anlatım Bozuklukları',
      ]),
    ],
    'Matematik': <Unit>[
      Unit('Sayılar', <String>[
        'Üslü İfadeler', 'Köklü İfadeler', 'Sayı Kümeleri',
        'Özdeşlikler (İki Kare Farkı-Tam Kare)',
      ]),
      Unit('Nicelikler ve Değişimler', <String>[
        'Doğrusal Fonksiyonlar', 'Mutlak Değer', 'Denklem-Eşitsizlik',
        'Fonksiyonlar ve Denklemler',
      ]),
      Unit('Mantıksal Çıkarım', <String>[
        'Mantıksal Çıkarım', 'Algoritma ve Bilişim',
      ]),
      Unit('Trigonometri', <String>['Trigonometriye Giriş']),
      Unit('Veriden Olasılığa', <String>['Veriden Olasılığa']),
    ],
    // Maarif programında geometri matematiğin içinde geçse de uygulamada AYRI
    // DERS olarak tutulur (eski müfredatla tutarlı olsun diye).
    'Geometri': <Unit>[
      Unit('Üçgenler', <String>['Üçgende Eşlik ve Benzerlik']),
      Unit('Çokgenler ve Dörtgenler', <String>['Çokgenler', 'Dörtgenler']),
      Unit('Çember', <String>['Çember']),
      Unit('Analitik Geometri', <String>['Analitik Geometriye Giriş']),
    ],
    'Fizik': <Unit>[
      Unit('Fizik Bilimi', <String>['Fizik Bilimi ve Kariyer']),
      Unit('Kuvvet ve Hareket', <String>['Kuvvet ve Hareket']),
      Unit('Akışkanlar', <String>[
        'Akışkanlar (Basınç)', 'Akışkanlar (Kaldırma Kuvveti-Bernoulli)',
      ]),
      Unit('Enerji', <String>['Enerji (Isı-Hâl Değişimi)']),
      Unit('Elektrik', <String>['Elektrik']),
      Unit('Dalgalar', <String>['Dalgalar']),
    ],
    'Kimya': <Unit>[
      Unit('Etkileşim', <String>[
        'Kimya Hayattır', 'Atomdan Periyodik Tabloya',
        'Kimyasal Türler Arası Etkileşimler',
      ]),
      Unit('Çeşitlilik', <String>[
        'Kimyasal Tepkimeler', 'Gazlar', 'Çözeltiler', 'Redoks (Etkileşim)',
      ]),
      Unit('Sürdürülebilirlik', <String>['Sürdürülebilirlik']),
    ],
    'Biyoloji': <Unit>[
      Unit('Yaşam', <String>[
        'Canlıların Ortak Özellikleri', 'Üç Âlem/Domain Sistemi',
      ]),
      Unit('Organizasyon', <String>['Hücre', 'Organik Moleküller']),
      Unit('Enerji', <String>['Fotosentez', 'Hücresel Solunum']),
      Unit('Ekoloji', <String>['Ekosistem Ekolojisi']),
    ],
    'Tarih': <Unit>[
      Unit('Tarih Bilimi', <String>[
        'Geçmişin İnşa Sürecinde Tarih', 'Medeniyet/Uygarlık Tarihi',
      ]),
      Unit('Türk Tarihi', <String>[
        "Türkistan'dan Türkiye'ye", 'Beylikten Devlete Osmanlı',
        "Cihan Devleti Osmanlı (İstanbul'un Fethi)",
      ]),
    ],
    'Coğrafya': <Unit>[
      Unit('Coğrafi Beceriler', <String>[
        'Coğrafyanın Doğası', 'Mekânsal Bilgi Teknolojileri',
      ]),
      Unit('Doğal Sistemler', <String>['Doğal Sistemler ve Süreçler (İklim)']),
      Unit('Beşerî Sistemler', <String>[
        'Beşerî Sistemler ve Süreçler', 'Ekonomik Faaliyetler ve Etkileri',
      ]),
      Unit('Çevre ve Küresel Bağlantılar', <String>[
        'Afetler ve Sürdürülebilir Çevre', 'Bölgesel/Küresel Bağlantılar',
      ]),
    ],
    'Felsefe': <Unit>[
      Unit('Felsefeye Giriş', <String>[
        'Felsefeye Giriş', 'Felsefe ile Düşünme (Argümantasyon)',
      ]),
      Unit('Felsefenin Temel Konuları', <String>[
        'Bilgi Felsefesi', 'Bilim Felsefesi', 'Ahlak Felsefesi',
      ]),
    ],
    'Din Kültürü': <Unit>[
      Unit('İnanç', <String>[
        'Allah-İnsan İlişkisi', "İslam'da İnanç Esasları",
        "İslam'da Varlık ve Bilgi",
      ]),
      Unit('İbadet ve Ahlak', <String>[
        "İslam'da İbadetler", "İslam'da Ahlak İlkeleri",
      ]),
      Unit('Hz. Muhammed ve Güncel Konular', <String>[
        "Kur'an'a Göre Hz. Muhammed", 'Din, Çevre ve Teknoloji',
      ]),
    ],
  };

  static const Map<String, List<Unit>> _maarifAyt = <String, List<Unit>>{
    'Matematik': <Unit>[
      Unit('Nicelikler ve Değişimler', <String>['Nicelikler ve Değişimler']),
      Unit('İstatistiksel Araştırma', <String>[
        'İstatistiksel Araştırma Süreci',
      ]),
      Unit('Analiz', <String>['Türev', 'İntegral', 'Logaritma']),
    ],
    'Geometri': <Unit>[
      Unit('Geometrik Şekiller', <String>['Geometrik Şekiller']),
    ],
    'Fizik': <Unit>[
      Unit('Kuvvet ve Hareket', <String>[
        'Kuvvet ve Hareket (Newton Yasaları)', 'Çembersel Hareket',
      ]),
      Unit('Elektrik ve Manyetizma', <String>[
        'Elektriksel ve Manyetik Alan', 'İndüksiyon ve Transformatörler',
      ]),
      Unit('Madde ve Doğası', <String>['Madde ve Doğası (Yarı İletkenler)']),
      Unit('Optik, Enerji ve Dalgalar', <String>[
        'Optik', 'Enerji', 'Dalgalar',
      ]),
    ],
    'Kimya': <Unit>[
      Unit('Tepkimeler', <String>[
        'Kimyasal Tepkimeler ve Enerji', 'Tepkime Hızı', 'Kimyasal Denge',
      ]),
      Unit('Çözeltilerde Denge', <String>['Asit-Baz Dengeleri']),
      Unit('Sürdürülebilirlik', <String>['Sürdürülebilirlik (Yeşil Kimya)']),
    ],
    'Biyoloji': <Unit>[
      Unit('Tepki', <String>[
        'Sinir Sistemi ve Refleks', 'İskelet-Kas-Eklem Sistemi',
        'Bağışıklık ve Alerji',
      ]),
      Unit('Homeostazi', <String>[
        'Endokrin Sistem', 'Dolaşım Sistemi', 'Solunum Sistemi',
        'Boşaltım Sistemi',
        'Denge Bozuklukları (Diyabet-Hipertansiyon-Obezite)',
      ]),
    ],
    'Edebiyat': <Unit>[
      Unit('Bir Diyeceğim Var!', <String>[
        'Mektup-Dilekçe-E-posta', 'Geleneksel Türk Tiyatrosu',
      ]),
      Unit('Kültür Yolculuğu', <String>[
        'Orhun Abideleri ve Geçiş Dönemi', 'Âşık Tarzı Halk Şiiri',
        'Halk Hikâyesi',
      ]),
      Unit('Yaşamın İzinde', <String>[
        'Roman', 'Biyografi ve Tezkire', 'Radyo Tiyatrosu',
      ]),
      Unit('Hayatın Aynası', <String>[
        'Modern Türk Tiyatrosu', 'Küçürek Hikâye', 'Belgesel',
      ]),
    ],
    'Tarih': <Unit>[
      Unit('Osmanlı ve Değişim', <String>[
        "Osmanlı'da Gerileme ve Değişim",
        'Fransız İhtilali ve Milliyetçilik',
      ]),
      Unit('Savaşlar Çağı', <String>[
        'Balkan Savaşları', "I. Dünya Savaşı'na Giden Süreç",
      ]),
    ],
    'Coğrafya': <Unit>[
      Unit('Beşerî Coğrafya', <String>['İleri Nüfus', 'İleri Yerleşme']),
      Unit('Ekonomik Coğrafya', <String>['Ekonomik Coğrafya']),
    ],
  };
}
