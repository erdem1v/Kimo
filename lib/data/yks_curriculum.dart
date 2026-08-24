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
      Unit('Önermeler ve Bileşik Önermeler', <String>[
        'Önermeler', 'Bileşik Önermeler', 'Koşullu Önerme',
        'İki Yönlü Koşullu Önerme', 'Niceleyiciler',
        'Tanım, Aksiyom, Teorem ve İspat Kavramları',
      ]),
      Unit('Kümelerde Temel Kavramlar', <String>[
        'Kümelerde Temel Kavramlar', 'Alt Küme',
      ]),
      Unit('Kümelerde İşlemler', <String>[
        'Kümelerde Kesişim ve Birleşim İşlemleri',
        'Kümelerde Fark ve Tümleme İşlemleri', 'Küme Problemleri',
        'Sıralı İkililer ve Kartezyen Çarpım',
      ]),
      Unit('Sayı Kümeleri', <String>[
        'Sayı Kümeleri', 'Temel İşlemler', 'Tek ve Çift Sayılar',
        'Pozitif ve Negatif Sayılar', 'Ardışık Sayılar', 'Sayı Basamakları',
        'Asal ve Aralarında Asal Sayılar',
        'Ondalık ve Devirli Ondalık Sayılar', 'Rasyonel Sayılarda İşlemler',
      ]),
      Unit('Bölünebilme Kuralları', <String>[
        'Tamsayılarda Kalanlı Bölme İşlemi', 'Bölünebilme Kuralları 1',
        'Bölünebilme Kuralları 2', 'Asal Çarpanlar',
        'EBOB-EKOK Kavramı ve Özellikleri', 'EBOB-EKOK Problemleri',
        'Periyodik Problemler',
      ]),
      Unit('Birinci Dereceden Denklemler ve Eşitsizlikler', <String>[
        'Aralık Kavramı', 'Birinci Dereceden Bir Bilinmeyenli Denklemler',
        'Basit Eşitsizlikler',
        'Birinci Dereceden İki Bilinmeyenli Denklemler',
        'Birinci Dereceden İki Bilinmeyenli Eşitsizlikler',
        'Birinci Dereceden İki Bilinmeyenli Eşitsizlik Sistemleri',
        'Mutlak Değer Kavramı ve Özellikleri',
        'Mutlak Değerli Denklemler ve Eşitsizlikler',
      ]),
      Unit('Üslü İfadeler ve Denklemler', <String>[
        'Üslü İfadeler ve Özellikleri',
        'Üslü İfade İçeren Denklem ve Eşitsizlikler',
        'Köklü İfadeler ve Özellikleri',
        'Köklü İfadeleri İçeren Denklem ve Eşitsizlikler',
      ]),
      Unit('Denklemler ve Eşitsizlikler ile İlgili Uygulamalar', <String>[
        'Oran-Orantı Kavramları ve Özellikleri', 'Oran-Orantı Problemleri',
        'Sayı Problemleri', 'Kesir Problemleri', 'Yaş Problemleri',
        'İşçi Problemleri', 'Yüzde Problemleri', 'Kar-Zarar Problemleri',
        'Karışım Problemleri', 'Hareket Problemleri', 'Rutin Olmayan Problemler',
      ]),
      Unit('Merkezi Eğilim ve Yayılım Ölçüleri', <String>[
        'Merkezi Eğilim Ölçüleri', 'Merkezi Yayılım Ölçüleri',
      ]),
      Unit('Verilerin Grafikle Gösterilmesi', <String>[
        'Histogram', 'Çizgi, Sütun ve Daire Grafikleri',
      ]),
      Unit('Sıralama ve Seçme', <String>[
        'Saymanın Temel İlkesi', 'Faktöriyel Kavramı', 'Permütasyon',
        'Tekrarlı Permütasyon', 'Kombinasyon Kavramı ve Özellikleri',
        'Kombinasyon Problemleri', 'Kombinasyon ve Geometri',
        'Pascal Üçgeni ve Binom Açılımı',
      ]),
      Unit('Basit Olayların Olasılıkları', <String>[
        'Olasılıkta Temel Kavramlar', 'Olasılık Kavramı İle İlgili Uygulamalar',
      ]),
      Unit('Fonksiyon Kavramı ve Gösterimi', <String>[
        'Fonksiyon Kavramı ve Gösterimi', 'Fonksiyon Soruları',
        'İçine, Örten, Birebir ve Eşit Fonksiyonlar', 'Birim ve Sabit Fonksiyon',
        'Doğrusal ve Parçalı Fonksiyonlar', 'Tek-Çift Fonksiyonlar',
        'Fonksiyonlarda Dört İşlem', 'Fonksiyon Grafikleri',
      ]),
      Unit('İki Fonksiyonun Bileşkesi ve Bir Fonksiyonun Tersi', <String>[
        'İki Fonksiyonun Bileşkesi', 'Bir Fonksiyonun Tersi',
        'Fonksiyon Grafikleri ile İlgili Uygulamalar',
      ]),
      Unit('Polinom Kavramı ve Polinomlarda İşlemler', <String>[
        'Polinom Kavramı', 'Polinomlarda Toplama, Çıkarma ve Çarpma İşlemleri',
        'Polinomlarda Bölme İşlemi',
        'Polinomlarda Bölme İşlemi Yapmadan Kalan Bulma',
      ]),
      Unit('Polinomların Çarpanlara Ayrılması', <String>[
        'Ortak Çarpan Parantezine Alma',
        'Tam Kare veya İki Kare Farkı Özdeşliklerinde Faydalanarak Çarpanlara Ayırma',
        'Tam Küp, İki Küp Toplamı veya Farkı Özdeşliklerinden Faydalanarak Çarpanlara Ayırma',
        'Üç Terimli İfadelerin Çarpanlarına Ayrılması',
        'Rasyonel İfadelerin Sadeleştirilmesi',
      ]),
      Unit('İkinci Dereceden Bir Bilinmeyenli Denklemler', <String>[
        'İkinci Dereceden Bir Bilinmeyenli Denklemler',
        'İkinci Dereceden Bir Bilinmeyenli Denklemlerin Çözüm Kümesi',
        'Diskriminant Kavramı ve Diskriminantın Kullanılması',
        'İkinci Dereceden Denklemlerde Kök-Katsayı İlişkisi', 'Karmaşık Sayılar',
      ]),
    ],
    'Geometri': <Unit>[
      Unit('Üçgenlerde Temel Kavramlar', <String>[
        'Açı Kavramı ve Çeşitleri',
        'Paralel İki Doğrunun Bir Kesenle Yaptığı Açılar', 'Üçgende Açılar',
        'İkizkenar ve Eşkenar Üçgende Açı Özellikleri',
        'Üçgende Açı-Kenar Bağıntıları', 'Üçgen Eşitsizliği',
      ]),
      Unit('Üçgenlerde Eşlik ve Benzerlik', <String>[
        'Üçgenlerde Eşlik', 'Üçgenlerde Benzerlik',
        'Üçgende Temel Orantı Teoremi',
        'Üçgenlerin Benzerliği İle İlgili Uygulamalar',
      ]),
      Unit('Üçgenin Yardımcı Elemanları', <String>[
        'Üçgende Açıortay ve Özellikleri', 'Üçgende Açıortay Teoremleri',
        'Üçgende Kenarortay', 'Üçgende Yükseklik', 'Üçgende Kenar Orta Dikme',
      ]),
      Unit('Dik Üçgen ve Trigonometri', <String>[
        'Dik Üçgende Pisagor Teoremi', 'Dik Üçgende Öklid Teoremi',
        'Trigonometrik Oranlar',
        '30, 45 ve 60 Derecelerin Trigonometrik Oranları', 'Birim Çember',
      ]),
      Unit('Üçgenin Alanı', <String>[
        'Üçgenin Alanı', 'Üçgenin Alanıyla İlgili Uygulamalar',
      ]),
      Unit('Çokgenler', <String>['Çokgenler']),
      Unit('Dörtgenler ve Özellikleri', <String>['Dörtgenler ve Özellikleri']),
      Unit('Özel Dörtgenler', <String>[
        'Yamukta Açı ve Uzunluk', 'İkizkenar ve Dik Yamuk', 'Yamuğun Alanı',
        'Paralelkenarda Açı ve Uzunluk', 'Eşkenar Dörtgen',
        'Paralelkenarın Alanı', 'Dikdörtgende Açı ve Uzunluk', 'Kare',
        'Dikdörtgenin Alanı', 'Deltoid',
      ]),
      Unit('Katı Cisimler', <String>[
        'Dik Prizmalar', 'Küp', 'Dik Piramitler', 'Düzgün Dört Yüzlü',
      ]),
    ],
    'Fizik': <Unit>[
      Unit('Fizik Bilimine Giriş', <String>[
        'Fiziğin Doğası', 'Fiziğin Uygulama Alanları',
        'Fiziksel Nicelikler ve Birimler', 'Bilim Araştırma Merkezleri',
      ]),
      Unit('Madde ve Özellikleri', <String>[
        'Özkütle', 'Dayanıklılık', 'Adezyon ve Kohezyon',
      ]),
      Unit('Hareket ve Kuvvet', <String>[
        'Hareket', 'Kuvvet', "Newton'un Hareket Yasaları", 'Sürtünme Kuvveti',
      ]),
      Unit('Enerji', <String>[
        'İş, Enerji ve Güç', 'Kinetik ve Potansiyel Enerji',
        'Enerjinin Korunumu ve Dönüşümü', 'Verim', 'Enerji Kaynakları',
      ]),
      Unit('Isı ve Sıcaklık', <String>[
        'Isı, Sıcaklık ve İç Enerji', 'Hâl Değişimi', 'Isıl Denge',
        'Enerji İletim Yolları ve Yalıtım', 'Genleşme ve Büzülme',
      ]),
      Unit('Elektrostatik', <String>['Elektrostatik']),
      Unit('Elektrik ve Manyetizma', <String>[
        'Elektrik Akımı ve Direnç', 'Elektrik Devreleri',
        'Mıknatıslar ve Manyetik Alan', 'Akım ve Manyetik Alan',
      ]),
      Unit('Basınç ve Kaldırma Kuvveti', <String>[
        'Basınç', 'Kaldırma Kuvveti',
      ]),
      Unit('Dalgalar', <String>[
        'Dalga Hareketi', 'Yay Dalgaları', 'Su Dalgaları', 'Ses Dalgaları',
        'Deprem Dalgaları',
      ]),
      Unit('Optik', <String>[
        'Işığın Doğası', 'Gölge', 'Yansıma', 'Düzlem Ayna', 'Küresel Aynalar',
        'Kırılma', 'Mercekler', 'Prizmalar', 'Renk',
      ]),
    ],
    'Kimya': <Unit>[
      Unit('Kimya Bilimi', <String>[
        'Kimya Biliminin Gelişimi', 'Kimyanın Çalışma Alanları',
        'Kimyada Kullanılan Maddeler', 'Kimya Laboratuvarında Güvenlik',
      ]),
      Unit('Atom ve Periyodik Sistem', <String>[
        'Atom Modelleri', 'Atomun Yapısı', 'Periyodik Sistem',
      ]),
      Unit('Kimyasal Türler Arası Etkileşimler', <String>[
        'Kimyasal Türler', 'Kimyasal Türler Arası Etkileşimler',
        'Güçlü Etkileşimler (İyonik-Kovalent-Metalik Bağ)',
        'Zayıf Etkileşimler', 'Fiziksel ve Kimyasal Değişimler',
      ]),
      Unit('Maddenin Hâlleri', <String>[
        'Maddenin Hâlleri', 'Katılar', 'Sıvılar', 'Gazlar', 'Plazma',
      ]),
      Unit('Kimyanın Temel Kanunları ve Hesaplamalar', <String>[
        'Kimyanın Temel Kanunları', 'Mol Kavramı', 'Kimyasal Tepkimeler',
        'Kimyasal Hesaplamalar',
      ]),
      Unit('Karışımlar', <String>[
        'Karışımların Sınıflandırılması', 'Karışımların Ayrılması',
      ]),
      Unit('Asitler, Bazlar ve Tuzlar', <String>[
        'Asitler ve Bazlar', 'Asit-Baz Tepkimeleri',
        'Asit ve Bazların Kullanımı', 'Tuzlar',
      ]),
      Unit('Kimya Her Yerde', <String>[
        'Temizlik Maddeleri', 'Yaygın Kimyasallar',
      ]),
    ],
    'Biyoloji': <Unit>[
      Unit('Yaşam Bilimi Biyoloji', <String>[
        'Canlıların Ortak Özellikleri', 'Canlıların Temel Bileşenleri',
      ]),
      Unit('Hücre', <String>['Hücre']),
      Unit('Canlılar Dünyası', <String>[
        'Canlıların Çeşitliliği ve Sınıflandırma', 'Canlı Âlemleri',
      ]),
      Unit('Hücre Bölünmeleri', <String>[
        'Mitoz ve Eşeysiz Üreme', 'Mayoz ve Eşeyli Üreme',
      ]),
      Unit('Kalıtım', <String>['Kalıtım']),
      Unit('Ekosistem Ekolojisi', <String>[
        'Ekosistem Ekolojisi', 'Güncel Çevre Sorunları',
        'Doğal Kaynakların Sürdürülebilirliği',
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
      Unit('Kuvvet ve Hareket', <String>[
        'Vektörler', 'Bağıl Hareket', "Newton'un Hareket Yasaları",
        'Bir Boyutta Sabit İvmeli Hareket', 'İki Boyutta Hareket (Atışlar)',
        'İş ve Enerji', 'İtme ve Momentum', 'Tork', 'Denge', 'Basit Makineler',
      ]),
      Unit('Elektrik ve Manyetizma', <String>[
        'Elektriksel Kuvvet ve Alan', 'Elektriksel Potansiyel',
        'Kondansatörler', 'Manyetizma ve İndüksiyon', 'Alternatif Akım',
        'Transformatörler',
      ]),
      Unit('Çembersel Hareket', <String>[
        'Düzgün Çembersel Hareket', 'Dönme Hareketi', 'Açısal Momentum',
        'Kütle Çekimi', 'Kepler Kanunları',
      ]),
      Unit('Basit Harmonik Hareket', <String>['Basit Harmonik Hareket']),
      Unit('Dalga Mekaniği', <String>[
        'Su Dalgalarında Kırınım ve Girişim', 'Elektromanyetik Dalgalar',
      ]),
      Unit('Atom Fiziği ve Radyoaktivite', <String>[
        'Atom Modelleri', 'Büyük Patlama', 'Radyoaktivite',
      ]),
      Unit('Modern Fizik', <String>[
        'Özel Görelilik', 'Siyah Cisim Işıması', 'Fotoelektrik Olay',
        'Compton Olayı',
      ]),
      Unit('Modern Fiziğin Teknolojideki Uygulamaları', <String>[
        'Görüntüleme Teknolojileri', 'Yarı İletkenler', 'Süper İletkenler',
        'Nanoteknoloji', 'LASER',
      ]),
    ],
    'Kimya': <Unit>[
      Unit('Modern Atom Teorisi', <String>[
        'Atomun Kuantum Modeli', 'Elektron Dizilimi', 'Periyodik Özellikler',
        'Elementlerin Sınıflandırılması', 'Yükseltgenme Basamakları',
      ]),
      Unit('Gazlar', <String>[
        'Gazların Özellikleri', 'Gaz Yasaları', 'Kinetik Teori',
        'Kısmi Basınçlar', 'Gerçek Gazlar',
      ]),
      Unit('Sıvı Çözeltiler ve Çözünürlük', <String>[
        'Çözücü-Çözünen Etkileşimleri', 'Derişim', 'Koligatif Özellikler',
        'Çözünürlük', 'Çözünürlüğe Etki Eden Faktörler',
      ]),
      Unit('Kimyasal Tepkimelerde Enerji', <String>[
        'Tepkime Entalpisi', 'Oluşum Entalpisi', 'Bağ Enerjileri',
        'Hess Yasası',
      ]),
      Unit('Kimyasal Tepkimelerde Hız', <String>[
        'Tepkime Hızı', 'Hıza Etki Eden Faktörler',
      ]),
      Unit('Kimyasal Tepkimelerde Denge', <String>[
        'Kimyasal Denge', 'Dengeyi Etkileyen Faktörler',
        'Asit-Baz Dengesi (pH-pOH)',
      ]),
      Unit('Kimya ve Elektrik', <String>[
        'Redoks Tepkimeleri', 'Elektrokimyasal Hücreler', 'İstemlilik',
        'Galvanik Piller', 'Elektroliz', 'Korozyon',
      ]),
      Unit('Karbon Kimyasına Giriş', <String>[
        'Organik ve Anorganik Bileşikler', 'Basit ve Molekül Formülleri',
        'Karbon Allotropları', 'Lewis Formülleri', 'Hibritleşme',
      ]),
      Unit('Organik Bileşikler', <String>[
        'Hidrokarbonlar', 'Fonksiyonel Gruplar', 'Alkoller', 'Eterler',
        'Karbonil Bileşikleri (Aldehit-Keton)', 'Karboksilik Asitler',
        'Esterler',
      ]),
      Unit('Enerji Kaynakları ve Bilimsel Gelişmeler', <String>[
        'Fosil Yakıtlar', 'Alternatif Enerji Kaynakları', 'Sürdürülebilirlik',
        'Nanoteknoloji',
      ]),
    ],
    'Biyoloji': <Unit>[
      Unit('İnsan Fizyolojisi', <String>[
        'Sinir Sistemi', 'Destek ve Hareket Sistemi', 'Sindirim Sistemi',
        'Dolaşım Sistemi', 'Solunum Sistemi', 'Üriner Sistem (Boşaltım)',
        'Üreme Sistemi',
      ]),
      Unit('Komünite ve Popülasyon Ekolojisi', <String>[
        'Komünite Ekolojisi', 'Popülasyon Ekolojisi',
      ]),
      Unit('Genden Proteine', <String>[
        'Nükleik Asitler', 'Protein Sentezi',
      ]),
      Unit('Canlılarda Enerji Dönüşümleri', <String>[
        'Canlılık ve Enerji (ATP)', 'Fotosentez', 'Kemosentez',
        'Hücresel Solunum',
      ]),
      Unit('Bitki Biyolojisi', <String>[
        'Bitkilerin Yapısı', 'Bitkilerde Taşıma ve Beslenme',
        'Bitkilerde Üreme',
      ]),
      Unit('Canlılar ve Çevre', <String>['Canlılar ve Çevre']),
    ],
    'Edebiyat': <Unit>[
      Unit('Edebî Türler', <String>[
        'Edebiyat Bilgisi ve Metin Türleri', 'Hikâye', 'Şiir Bilgisi',
        'Roman', 'Tiyatro',
      ]),
      Unit('İslamiyet Öncesi ve Geçiş Dönemi', <String>[
        'İslamiyet Öncesi Türk Edebiyatı', 'Geçiş Dönemi Eserleri',
      ]),
      Unit('Halk Edebiyatı', <String>[
        'Halk Edebiyatı (Âşık-Anonim)', 'Dini-Tasavvufi Halk Edebiyatı',
      ]),
      Unit('Divan Edebiyatı', <String>['Divan Edebiyatı']),
      Unit('Batı Etkisinde Gelişen Edebiyat', <String>[
        'Tanzimat Edebiyatı', 'Servet-i Fünun Edebiyatı', 'Fecr-i Ati',
        'Millî Edebiyat',
      ]),
      Unit('Cumhuriyet Dönemi', <String>[
        'Cumhuriyet Dönemi Şiiri (Garip)',
        'Cumhuriyet Dönemi Şiiri (İkinci Yeni)',
        'Cumhuriyet Dönemi Roman-Hikâye', 'Cumhuriyet Dönemi Tiyatro',
      ]),
      Unit('Edebiyat Bilgileri', <String>[
        'Öğretici Metinler', 'Edebî Akımlar', 'Edebî Sanatlar',
        'Şiir Bilgisi (Nazım Biçimleri-Ölçü)',
      ]),
    ],
    'Tarih': <Unit>[
      Unit('Değişim Çağında Osmanlı', <String>[
        'Değişen Dünya Dengeleri ve Osmanlı Siyaseti (1595-1774)',
        'Değişim Çağında Avrupa ve Osmanlı',
        'Uluslararası İlişkilerde Denge (1774-1914)', 'Devrimler Çağı',
        'Sermaye ve Emek', 'XIX-XX. Yüzyılda Gündelik Hayat',
        'Nüfus Politikaları', 'XX. Yüzyıl Başlarında Osmanlı',
      ]),
      Unit('Millî Mücadele ve İnkılaplar', <String>[
        'Millî Mücadele', 'Atatürkçülük ve Türk İnkılabı', 'Atatürk İlkeleri',
      ]),
      Unit('Çağdaş Türk ve Dünya Tarihi', <String>[
        'İki Savaş Arası Dönem', 'II. Dünya Savaşı', 'Soğuk Savaş Dönemi',
        'Toplumsal Devrim Çağında Dünya ve Türkiye',
        'XXI. Yüzyılın Eşiğinde Türkiye ve Dünya',
      ]),
    ],
    'Coğrafya': <Unit>[
      Unit('Doğal Sistemler', <String>[
        'Ekosistem ve Madde Döngüsü', 'Doğal Sistemler (Biyoçeşitlilik)',
      ]),
      Unit('Beşerî Sistemler', <String>[
        'Nüfus Politikaları', 'Göç ve Şehirleşme',
        "Türkiye'de Nüfus ve Yerleşme", 'Beşerî Sistemler',
        'Doğal Kaynaklar',
      ]),
      Unit('Türkiye Ekonomisi', <String>[
        "Türkiye'de Tarım", "Türkiye'de Sanayi",
        "Türkiye'de Ticaret-Ulaşım-Turizm", 'Bölgesel Kalkınma Projeleri',
        'Türkiye Ekonomisinin Sektörel Dağılımı',
        "Türkiye'de Madenler ve Enerji Kaynakları",
      ]),
      Unit('Küresel Ortam', <String>['Küresel Ortam: Bölgeler ve Ülkeler']),
      Unit('Çevre ve Toplum', <String>[
        'Çevre ve Toplum', 'Doğal Afetler ve Toplum',
      ]),
    ],
    'Felsefe Grubu': <Unit>[
      Unit('Felsefe Tarihi', <String>[
        'İlk Çağ Felsefesi', 'Ortaçağ Felsefesi', 'Yeni Çağ Felsefesi',
        '19. Yüzyıl Felsefesi', '20. Yüzyıl Felsefesi',
      ]),
      Unit('Psikoloji', <String>[
        'Psikolojiye Giriş', 'Öğrenme-Bellek-Düşünme', 'Kişilik ve Ruh Sağlığı',
      ]),
      Unit('Sosyoloji', <String>[
        'Sosyoloji: Toplum ve Kültür', 'Sosyoloji: Toplumsal Kurumlar',
        'Sosyoloji: Toplumsal Değişme ve Küreselleşme',
      ]),
      Unit('Mantık', <String>[
        'Klasik Mantık', 'Önermeler ve Çıkarım', 'Sembolik Mantık',
      ]),
    ],
    'Din Kültürü': <Unit>[
      Unit('İnanç ve İbadet', <String>[
        'Dünya ve Ahiret', 'İnançla İlgili Meseleler',
      ]),
      Unit("Kur'an ve Hz. Muhammed", <String>[
        "Kur'an'a Göre Hz. Muhammed", "Kur'an'da Kavramlar",
      ]),
      Unit('Dinler ve Kültür', <String>[
        'Yahudilik ve Hristiyanlık', 'Hint ve Çin Dinleri', "Anadolu'da İslam",
      ]),
      Unit('İslam Düşüncesi', <String>[
        'İslam ve Bilim', 'Tasavvufi Yorumlar', 'Güncel Dinî Meseleler',
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
