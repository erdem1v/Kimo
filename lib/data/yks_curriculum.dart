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
      Unit('Sözcükte Anlam', <String>[
        'Sözcükte Anlam 1', 'Sözcükte Anlam 2', 'Sözcükte Anlam 3',
        'Sözcükte Anlam 4',
      ]),
      Unit('Cümlede Anlam', <String>[
        'Cümlede Anlam 1', 'Cümlede Anlam 2', 'Cümlede Anlam 3',
      ]),
      Unit('Paragrafta Anlam', <String>[
        'Paragrafta Anlam 1', 'Paragrafta Anlam 2', 'Paragrafta Anlam 3',
        'Paragrafın Yapısı',
      ]),
      Unit('Ses Bilgisi', <String>['Ses Bilgisi-1', 'Ses Bilgisi-2']),
      Unit('Biçim Bilgisi', <String>['Biçim Bilgisi 1', 'Biçim Bilgisi 2']),
      Unit('Sözcük Türleri', <String>[
        'İsim', 'Sıfat', 'Zamir', 'İsim ve Sıfat Tamlamaları', 'Zarf',
        'Edat, Bağlaç ve Ünlem',
      ]),
      Unit('Fiiller', <String>[
        'Fiilde Kip', 'Ek-Fiil', 'Fiilde Yapı', 'Fiilimsiler', 'Fiilde Çatı',
      ]),
      Unit('Cümlenin Ögeleri', <String>['Cümlenin Ögeleri']),
      Unit('Cümle Türleri', <String>['Cümle Türleri']),
      Unit('Yazım Kuralları', <String>[
        'Yazım Kuralları-1', 'Yazım Kuralları-2', 'Yazım Kuralları-3',
      ]),
      Unit('Noktalama İşaretleri', <String>[
        'Noktalama İşaretleri-1', 'Noktalama İşaretleri-2',
        'Noktalama İşaretleri-3',
      ]),
      Unit('Anlatım Bozuklukları', <String>[
        'Anlama Dayalı Bozukluklar', 'Yapıya Dayalı Bozukluklar',
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
      Unit('Fizik Bilimine Giriş', <String>['Fizik Bilimine Giriş']),
      Unit('Madde ve Özellikleri', <String>[
        'Kütle ve Hacim', 'Özkütle', 'Dayanıklılık',
        'Adezyon, Kohezyon, Yüzey Gerilimi ve Kılcallık',
      ]),
      Unit('Hareket ve Kuvvet', <String>[
        'Hareket Kavramları', 'İvme Kavramı', 'Kuvvet Kavramı',
        "Newton'ın Hareket Yasaları", 'Sürtünme Kuvveti',
      ]),
      Unit('Enerji', <String>[
        'İş, Enerji ve Güç Kavramı', 'Enerji Çeşitleri ve Mekanik Enerji',
        'Enerji Korunumu', 'Verim ve Enerji Kaynakları',
      ]),
      Unit('Isı ve Sıcaklık', <String>[
        'Isı ve Sıcaklık Kavramları, Termometreler', 'Isı Alışverişi',
        'Hal Değişimi', 'Isıl Denge', 'Enerji İletim Yolları', 'Genleşme',
      ]),
      Unit('Elektrostatik', <String>[
        'Elektrik Yüklerinin Özellikleri ve Elektrikle Yüklenme Çeşitleri',
        'İletken ve Yalıtkanlarda Yük Dağılımı',
        'Elektriksel Kuvvet ve Elektrik Alan',
      ]),
      Unit('Elektrik ve Manyetizma', <String>[
        'Elektrik Akımı ve Direnç', 'Ohm Yasası ve Dirençlerin Bağlanması',
        'Üreteçler', 'Elektrik Enerjisi, Elektriksel Güç ve Lamba Parlaklıkları',
        'Mıknatıslar ve Manyetik Alan', 'Akım ve Manyetik Alan',
      ]),
      Unit('Basınç ve Kaldırma Kuvveti', <String>[
        'Basınç Kavramı, Katılarda Basınç ve Basınç Kuvveti',
        'Durgun Sıvılarda Basınç ve Basınç Kuvveti, Pascal Prensibi',
        'Gaz Basıncı, Atmosfer Basıncı ve Basınç Ölçen Aletler',
        'Akışkan Basıncı (Bernoulli İlkesi)', 'Kaldırma Kuvveti',
      ]),
      Unit('Dalgalar', <String>[
        'Dalgalarda Temel Kavramlar ve Özellikleri',
        'Yay Dalgalarının Hızı ve Yansıması',
        'Yay Dalgalarının Farklı Ortamlara Geçişi ve Yay Dalgalarının Girişimi',
        'Su Dalgalarının Özellikleri ve Yansıması',
        'Su Dalgalarının Hızı ve Kırılması', 'Ses Dalgaları', 'Deprem Dalgaları',
      ]),
      Unit('Optik', <String>[
        'Işık, Işık Şiddeti, Işık Akısı ve Aydınlanma Şiddeti', 'Gölge',
        'Işığın Yansıması ve Düzlem Aynalar',
        'Küresel Aynaların Özellikleri ve Küresel Aynalarda Özel Işınlar',
        'Küresel Aynalarda Görüntü Oluşumu', 'Işığın Kırılması',
        'Tam Yansıma, Sınır Açısı ve Görünür Uzaklık',
        'Merceklerin Özellikleri ve Merceklerde Özel Işınlar',
        'Merceklerde Görüntü Oluşumu', 'Işık Prizmaları', 'Renk',
      ]),
    ],
    'Kimya': <Unit>[
      Unit('Kimya Bilimi', <String>[
        'Simyadan Kimyaya',
        'Kimya Disiplinleri ve Kimyacıların Çalışma Alanları',
        'Kimyanın Sembolik Dili',
        'Kimya Uygulamalarında İş Sağlığı ve Güvenliği',
      ]),
      Unit('Atom ve Periyodik Sistem', <String>[
        'Atom Modelleri', 'Atomun Yapısı',
        'Elementlerin Periyodik Sistemdeki Yerleşim Esasları',
        'Elementlerin Sınıflandırılması',
        'Periyodik Özelliklerin Değişme Eğilimleri',
      ]),
      Unit('Kimyasal Türler Arası Etkileşimler', <String>[
        'Kimyasal Tür ve Kimyasal Türler Arası Etkileşimlerin Sınıflandırılması',
        'Güçlü Etkileşimler', 'Zayıf Etkileşimler',
        'Fiziksel ve Kimyasal Değişimler',
      ]),
      Unit('Maddenin Hâlleri', <String>[
        'Maddenin Fiziksel Hâlleri', 'Katılar ve Sıvılar', 'Gazlar ve Plazma',
      ]),
      Unit('Kimyanın Temel Kanunları ve Kimyasal Hesaplamalar', <String>[
        'Kimyanın Temel Kanunları', 'Mol Kavramı',
        'Kimyasal Tepkimeler ve Denklemler', 'Kimyasal Tepkimelerde Hesaplamalar',
      ]),
      Unit('Karışımlar', <String>[
        'Homojen-Heterojen Karışımlar (I)', 'Homojen-Heterojen Karışımlar (II)',
        'Ayırma ve Saflaştırma Teknikleri',
      ]),
      Unit('Asitler, Bazlar ve Tuzlar', <String>[
        'Asitlerin ve Bazların Özellikleri', 'Asitlerin ve Bazların Tepkimeleri',
        'Asitler ve Bazlar - Tuzlar',
      ]),
      Unit('Kimya Her Yerde', <String>[
        'Yaygın Günlük Hayat Kimyasalları', 'Kozmetikler-İlaçlar-Gıdalar',
      ]),
      Unit('Doğa ve Kimya', <String>['Su ve Hayat', 'Çevre Kimyası']),
    ],
    'Biyoloji': <Unit>[
      Unit('Canlıların Ortak Özellikleri', <String>[
        'Canlıların Ortak Özellikleri',
      ]),
      Unit('Canlıların Yapısında Bulunan İnorganik Bileşikler', <String>[
        'İnorganik Bileşiklerin Genel Özellikleri ve Canlılar İçin Önemi',
      ]),
      Unit('Canlıların Yapısında Bulunan Organik Bileşikler', <String>[
        'Organik Bileşiklerin Genel Özellikleri, Karbonhidratlar', 'Lipitler',
        'Proteinler', 'Enzimler', 'Vitaminler ve Hormonlar', 'Nükleik Asitler',
        'ATP (Adenozin trifosfat)', 'Sağlıklı Beslenme',
      ]),
      Unit('Hücresel Yapılar ve Görevleri', <String>[
        'Hücre Teorisi, Prokaryot ve Ökaryot Hücre Yapısı',
        'Hücre Zarı, Hücre Duvarı, Sitoplazma, Çekirdek',
        'Ribozom, Endoplazmik Retikulum, Golgi Aygıtı, Lizozom, Koful',
        'Peroksizom, Sentrozom, Hücre İskeleti', 'Mitokondri ve Plastitler',
      ]),
      Unit('Hücre Zarından Madde Geçişleri', <String>[
        'Hücre Zarından Madde Geçişleri, Basit Difüzyon, Kolaylaştırılmış Difüzyon',
        'Osmoz', 'Aktif Taşıma', 'Endositoz, Ekzositoz',
        'Bilimsel Yöntem ve Basamakları',
      ]),
      Unit('Canlıların Sınıflandırılması', <String>[
        'Canlıların Sınıflandırılmasının Amacı ve Önemi, Sınıflandırmada Kullanılan Kategoriler',
      ]),
      Unit('Canlı Âlemleri', <String>[
        'Bakteriler Âlemi, Arkeler Âlemi', 'Protista Âlemi', 'Bitkiler Âlemi',
        'Mantarlar Âlemi', 'Hayvanlar Âlemi-Omurgasız Hayvanlar',
        'Hayvanlar Âlemi-Omurgalı Hayvanlar', 'Virüsler',
      ]),
      Unit('Hücre Döngüsü ve Mitoz', <String>[
        'Hücre Bölünmesinin Gerekliliği, Hücre Döngüsü ve İnterfaz',
        'Mitozun Genel Özellikleri ve Evreleri', 'Hücre Döngüsünün Kontrolü',
      ]),
      Unit('Eşeysiz Üreme', <String>[
        'Eşeysiz Üremenin Genel Özellikleri ve Çeşitleri',
      ]),
      Unit('Mayoz', <String>['Mayozun Genel Özellikleri ve Evreleri']),
      Unit('Eşeyli Üreme', <String>[
        'Eşeyli Üremenin Genel Özellikleri ve Örnekleri',
      ]),
      Unit('Kalıtım', <String>[
        'Kalıtımla İlgili Kavramlar, Olasılık İlkeleri ve Gamet Çeşitlerinin Bulunması',
        'Mendel İlkeleri ve Çaprazlamalar',
        'Eş Baskınlık, Çok Alellilik, Kan Gruplarının Kalıtımı',
        'Eşeye Bağlı Kalıtım, Akraba Evliliği', 'Soyağacı Analizi ve Örnekleri',
      ]),
      Unit('Genetik Varyasyonlar', <String>[
        'Genetik Varyasyonların Kaynakları ve Biyolojik Çeşitlilik',
      ]),
      Unit('Ekosistem Ekolojisi', <String>[
        'Ekolojik Kavramlar, Ekosistemin Canlı ve Cansız Bileşenleri',
        'Canlılardaki Beslenme Şekilleri', 'Ekosistemde Madde ve Enerji Akışı',
        'Madde Döngüleri',
      ]),
      Unit('Güncel Çevre Sorunları', <String>[
        'Güncel Çevre Sorunlarının Sebepleri, Hava Kirliliği, Asit Yağmurları, Küresel İklim Değişikliği',
        'Su Kirliliği, Toprak Kirliliği, Radyoaktif Kirlilik, Ses Kirliliği',
        'Erozyon, Doğal Hayat Alanlarının Tahribi ve Orman Yangınları, Biyolojik Çeşitliliğin Azalması',
        'Çevre Sorunlarının Ortaya Çıkmasında Bireylerin Rolü ve Çözüm Önerileri',
      ]),
      Unit('Doğal Kaynakların Sürdürülebilirliği', <String>[
        'Doğal Kaynakların Sürdürülebilirliğinin Önemi',
      ]),
      Unit('Biyolojik Çeşitliliğin Korunması', <String>[
        'Biyolojik Çeşitliliğin Yaşam İçin Önemi ve Korunması',
      ]),
    ],
    'Tarih': <Unit>[
      Unit('Tarih ve Zaman', <String>[
        'İnsanlığın Hafızası Tarih', 'Zamanın Taksimi',
      ]),
      Unit('İlk ve Orta Çağlarda Türk Dünyası', <String>[
        "Avrasya'da İlk Türk İzleri, Coğrafya ile Oluşan Yaşam Tarzı", 'Boylardan Devlete-I',
        'Boylardan Devlete-II', 'Kavimler Göçü',
      ]),
      Unit('İslam Medeniyetinin Doğuşu', <String>[
        "İslamiyet'in Doğduğu Dönemde Dünya, İslamiyet Yayılıyor", 'Emeviler',
        'Abbasi Devleti ve Türkler-Bilim Medeniyeti',
      ]),
      Unit("Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet'i Kabulü", <String>[
        "Türklerin İslamiyet'i Kabulü", "İslamiyet'in Türk Devlet ve Toplum Yapısına Etkisi",
        'Büyük Selçuklu Devleti',
      ]),
      Unit('Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi', <String>[
        "Türklerin Anadolu'ya Yerleşme Süreci", "Anadolu'nun İlk Türk Siyasi Teşekkülleri",
        'Hilal ve Haç Mücadelesi', 'Moğol İstilası ve Anadolu',
      ]),
      Unit('Beylikten Devlete Osmanlı Siyaseti (1302-1453)', <String>[
        "Osmanlı Beyliği'nin Kuruluşu ve İlk Fetihleri", "Osmanlı Devleti'nin Rumeli'deki İskân ve İstimâlet Politikası",
        "Anadolu'da Türk Siyasi Birliğini Sağlama Çabaları",
      ]),
      Unit('Devletleşme Sürecinde Savaşçılar ve Askerler', <String>[
        'Devletleşme Sürecinde Savaşçılar ve Askerler',
      ]),
      Unit('Beylikten Devlete Osmanlı Medeniyeti', <String>[
        'Beylikten Devlete Osmanlı Medeniyeti',
      ]),
      Unit('Dünya Gücü Osmanlı (1453-1595)', <String>[
        "İstanbul'un Fethi ve Fethin Sonuçları", 'Türk İslam Dünyasında Birliği Sağlama Çabaları',
        'Dünyanın Muhteşem Gücü Osmanlı', 'Stratejik Siyaset ve Dünya Gücü Olan Osmanlı Devleti',
      ]),
      Unit('Sultan ve Osmanlı Merkez Teşkilatı', <String>[
        'Saray ve Şehir Kültürü, Gelenekler Işığında Devlet İdaresi',
      ]),
      Unit('Klasik Çağda Osmanlı Toplum Düzeni', <String>[
        "Osmanlı Devleti'nde Millet Sistemi, Fethettiği Yerlerdeki Kültürel Değişim", 'Osmanlı Toprak Sistemi, Lonca Teşkilatı, Vakıflar',
      ]),
      Unit('Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774)', <String>[
        'Uzun Savaşlardan Diplomasiye', 'Okyanusların Önem Kazanması ve Sömürgecilik Faaliyetleri',
        'Fetihlerden Savunmaya',
      ]),
      Unit('Değişim Çağında Avrupa ve Osmanlı', <String>[
        "Avrupa'da Değişim Çağı", "Osmanlı Devleti'nde Değişim",
        "Osmanlı Devleti'nde İsyanlar ve Düzeni Koruma Çabaları",
      ]),
      Unit('Devrimler Çağında Değişen Devlet-Toplum İlişkileri', <String>[
        'İhtilaller Çağı, Sömürgeciliğin Küresel Etkileri', "Osmanlı Devleti'nde Modern Orduya Geçiş",
        'XIX. Yüzyılda Sosyal Hayattaki Değişimler',
      ]),
      Unit('Uluslararası İlişkilerde Denge Stratejisi (1774-1914)', <String>[
        "Osmanlı Devleti'ne Yönelik Tehditler-I", "Osmanlı Devleti'nde Demokratikleşme Hareketleri",
        "Osmanlı Devleti'nde Darbeler", 'Osmanlı Devletine Yönelik Tehditler-II',
      ]),
      Unit('XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat', <String>[
        "Osmanlı Devleti'nde Sanayileşme Çabaları", 'XIX ve XX. Yüzyılda Osmanlı Nüfusu, Metropoller, Salgınlar ve Kamuoyu',
      ]),
      Unit('XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya', <String>[
        "Mustafa Kemal'in Lider Olarak Yetişmesinde Etkili Koşullar", '20. Yüzyıl Başlarında Osmanlı Devleti',
        'I. Dünya Savaşı Sürecinde Osmanlı Devleti', "I. Dünya Savaşı'nın Sonuçları",
      ]),
      Unit('Millî Mücadele', <String>[
        "Millî Mücadele'ye Hazırlık Dönemi-I", 'Büyük Millet Meclisinin Açılması-Sevr Antlaşması',
        'Doğu, Güney ve Batı Cepheleri', "Millî Mücadele'nin Sona Ermesi ve Lozan Barış Antlaşması",
        "Millî Mücadele'ye Hazırlık Dönemi-II",
      ]),
      Unit('Atatürkçülük ve Türk İnkılabı', <String>[
        'Atatürk İlkeleri, Siyasi ve Hukuk Alanındaki Gelişmeler', "Atatürk Dönemi'nde Yapılan İnkılaplar",
      ]),
    ],
    'Coğrafya': <Unit>[
      Unit('Coğrafya Bilimi, İnsan ve Doğa', <String>[
        'Doğa ve İnsan Etkileşimi', 'Coğrafyanın Konusu ve Bölümleri',
      ]),
      Unit("Dünya'nın Şekli ve Hareketleri", <String>[
        "Dünya'nın Şekli ve Günlük Hareketi",
        "Dünya'nın Yıllık Hareketi ve Eksen Eğikliği",
      ]),
      Unit('Yer ve Zaman, Koordinat Sistemi', <String>[
        'Koordinat Sistemi', 'Yerel Saat ve Ulusal Saat', "Türkiye'nin Konumu",
      ]),
      Unit('Harita Bilimi', <String>[
        'Harita Unsurları ve Harita Çeşitleri', 'Haritalarda Hesaplamalar',
        'Yeryüzü Şekillerinin Haritalara Aktarılması',
      ]),
      Unit('İklim Bilimi', <String>[
        'Atmosfer, Hava Durumu ve İklim', 'Sıcaklık', 'Basınç ve Rüzgârlar',
        'Nem ve Yağış', 'İklim Tipleri', 'Türkiye İklimi',
      ]),
      Unit("Dünya'nın Yapısı ve Oluşum Süreci", <String>[
        "Dünya'nın Tektonik Oluşumu ve Jeolojik Zamanlar",
        'İç Kuvvetler ve Kayaçlar',
        'Dış Kuvvetler (Çözülme, Kütle Hareketleri, Rüzgârlar, Buzullar)',
        'Dış Kuvvetler (Akarsular)',
        'Dış Kuvvetler (Karstik Şekiller, Dalgalar, Akıntılar)',
        "Türkiye'de Ana Yer Şekilleri, İç ve Dış Kuvvetler",
      ]),
      Unit('Su Kaynakları, Topraklar, Bitkiler', <String>[
        'Dünyada Su Kaynakları', "Türkiye'de Su Kaynakları",
        "Dünyada ve Türkiye'de Topraklar", "Dünyada ve Türkiye'de Bitkiler",
      ]),
      Unit('Yerleşmeler', <String>["Yerleşme ve Türkiye'de Yerleşmeler"]),
      Unit('Nüfus, Göç, Ekonomik Faaliyetler', <String>[
        'Nüfusun Özellikleri ve Gelişimi',
        'Nüfusun Dağılışı ve Nüfus Piramitleri', 'Türkiye Nüfusu', 'Göçler',
        'Ekonomik Faaliyetler',
      ]),
      Unit('Ulaşım', <String>['Uluslararası Ulaşım Hatları']),
      Unit('Bölgeler ve Ülkeler', <String>[
        'Bölge Sınıflandırılması ve Türleri',
      ]),
      Unit('İnsan ve Çevre', <String>['Doğal Çevrenin Kullanımı']),
      Unit('Afetler', <String>[
        'Afetlerin Genel Özellikleri ve Sınıflandırılması',
        'Deprem, Tsunami ve Volkanik Faaliyetler, Kütle Hareketleri, Erozyon',
        'Şiddetli Rüzgârlar, Sel ve Taşkın, Çığ, Orman Yangınları, Salgın Hastalıklar',
      ]),
    ],
    'Felsefe': <Unit>[
      Unit('Felsefeyi Tanıma', <String>[
        'Felsefenin Anlamı', 'Felsefi Düşüncenin Ortaya Çıkışı ve Özellikleri - Felsefe Sorusu Nedir?',
        'Felsefenin İnsan ve Toplum Hayatı Üzerindeki Rolü',
      ]),
      Unit('Felsefe ile Düşünme', <String>[
        'Düşünme ve Akıl Yürütmeye İlişkin Kavramlar', 'Düşünme ve Dil İlişkisi - Felsefi Bir Görüşü veya Argümanı Sorgulama',
      ]),
      Unit('Felsefi Okuma ve Yazma', <String>[
        'Felsefi Okuma ve Yazma',
      ]),
      Unit('Varlık Felsefesi', <String>[
        'Varlık Felsefesinin Konusu ve Problemleri', 'Varlık Felsefesi Alanındaki Çağdaş Yaklaşımlar',
        'Evrende Amaçlılık ve Düzenlilik-Varlık Türlerinin Sınıflandırılması-Bir konunun Varlık Felsefesi Açısından Değerlendirilmesi',
      ]),
      Unit('Bilgi Felsefesi', <String>[
        'Bilgi Felsefesinin Konusu ve Bilginin İmkânı Problemi', 'Bilginin Kaynağı İle İlgili Görüşler',
        'Bilginin Sınırları-Doğru Bilginin Ölçütü-Doğruluk ve Gerçeklik-Bilginin Değeri ve Güvenirliği',
      ]),
      Unit('Bilim Felsefesi', <String>[
        'Bilim Felsefesinin Konusu ve Problemleri', 'Bilimin Değeri-Bilim Felsefe İlişkisi-Bilim ve Hayat İlişkisi',
      ]),
      Unit('Ahlak Felsefesi', <String>[
        'Ahlak Felsefesinin Konusu ve Problemleri-İyi ve Kötünün Ölçütü', 'Özgürlük ve Sorumluluk',
        'Evrensel Bir Ahlak Yasasını Kabul Eden Görüşler', 'Evrensel Bir Ahlak Yasasını Reddeden Görüşler ve Filozoflar',
        'İyilik ve Mutluluk İlişkisi-Özgürlük, Sorumluluk ve Kural İlişkisi',
      ]),
      Unit('Din Felsefesi', <String>[
        "Din Felsefesinin Konusu ve Soruları Tanrı'nın Varlığı İle İlgili Görüşler", 'Din Felsefesinin Soruları-Teoloji ve Din Felsefesi-Felsefe, Bilim ve Din Açısından Ben Kimim?',
      ]),
      Unit('Siyaset Felsefesi', <String>[
        'Siyaset Felsefesinin Konusu ve Problemleri-Hak, Adalet, Özgürlük-İktidarın Kaynağı', 'İdeal Devlet Düzenine Yönelik Görüşler-Ütopya',
        'Egemenlik Sorunu-Toplumsal Sorunlara Felsefi Bakış',
      ]),
      Unit('Sanat Felsefesi', <String>[
        'Sanat Felsefesinin Konusu ve Problemleri-Güzellik-Sanat Nedir?', 'Sanat Kuramları-Sanat Eserinin Özellikleri-Sanat ve Duyarlılık-Şehir, İnsan ve Sanat',
      ]),
      Unit('MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi', <String>[
        "İlk Medeniyetlerin Felsefenin Doğuşuna Etkisi-Anadolu'da Yaşamış Filozoflar", 'İlk Neden (Arkhe) ve Değişim Problemi',
        "Sofistler ile Sokrates'in Bilgi ve Değer Anlayışları", "Platon'un Varlık, Bilgi ve Değer Anlayışı",
        "Aristoteles'in Varlık, Bilgi ve Değer Anlayışı", 'Görüş Analizi: Konfüçyüs, Sokrates, Platon ve Aristoteles',
      ]),
      Unit('MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi', <String>[
        'MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesinin Ortaya Çıkışı-Hristiyan Felsefesinin Özellikleri ve Problemleri', 'İslam Felsefesinin Özellikleri ve Problemleri',
        'İnanç-Akıl İlişkisi - Çeviri Faaliyetleri', 'Görüş Analizi (Augustinus, Fârâbî, İbn Sina, Gâzâlî ve İbn Rüşd)-Tasavvuf Düşüncesi',
      ]),
      Unit('15. Yüzyıl-17. Yüzyıl Felsefesi', <String>[
        '15. Yüzyıl-17. Yüzyıl Felsefesinin Ortaya Çıkışı', '15. Yüzyıl-17. Yüzyıl Felsefesinde Öne Çıkan Görüşler',
        'Bilimsel Çalışmaların 15. Yüzyıl-17. Yüzyıl Felsefesine Etkisi', 'Görüş Analizi: R. Descartes, B. Spinoza ve T. Hobbes',
      ]),
      Unit('18. Yüzyıl-19. Yüzyıl Felsefesi', <String>[
        '18. Yüzyıl-19. Yüzyıl Felsefesinin Ortaya Çıkışı-Genel Özellikleri - Dil ve Edebiyatla İlişkisi', '18. Yüzyıl-19. Yüzyıl Felsefesinin Öne Çıkan Problemleri-1',
        '18. Yüzyıl-19. Yüzyıl Felsefesinin Öne Çıkan Problemleri-2', 'Görüş Analizi: J. Locke, I. Kant ve F. Hegel',
      ]),
      Unit('20. Yüzyıl Felsefesi', <String>[
        '20. Yüzyıl Felsefesinin Ortaya Çıkışı', '20. Yüzyıl Felsefesi: Fenomenoloji, Hermeneutik, Varoluşçuluk',
        '20. Yüzyıl Felsefesi: Diyalektik Materyalizm, Mantıksal Pozitivizm, Yeni Ontoloji', "Türkiye'de Felsefi Düşünceye Katkıda Bulunan Felsefeciler-Çağımızın Felsefecileri-Yaşadıkları Yerler",
        'Görüş Analizi: F. Nietzsche, H. Bergson, J. P. Sartre ve T. Kuhn', "N. Topçu, T. Mengüşoğlu ve K. Popper'ın Görüşlerinin Tartışılması",
      ]),
    ],
    'Din Kültürü': <Unit>[
      Unit('Bilgi ve İnanç', <String>[
        "İslam'da Bilgi Kaynakları", 'İslam İnancında İmanın Mahiyeti',
        "Kur'an'dan Mesajlar: İsrâ Suresi 36. Ayet ve Mülk Suresi 23. Ayet",
      ]),
      Unit('Din ve İslam', <String>[
        'Dinin Tanımı ve Kaynağı', 'İnsanın Doğası ve Din',
        'İman ve İslam İlişkisi', 'İslam İnanç Esaslarının Özellikleri',
        "Kur'an'dan Mesajlar: Nisâ Suresi 136. Ayet",
      ]),
      Unit('Allah İnsan İlişkisi', <String>[
        'Allah İnancı ve İnsan', "Allah'ın Varlığı ve Birliği",
        "Allah'ın İsim ve Sıfatları", "Kur'an-ı Kerim'de İnsan ve Özellikleri",
        'İnsanın Allah İle İrtibatı', "Kur'an'dan Mesajlar: Rûm Suresi 18-27. Ayetler",
      ]),
      Unit('İslam Düşüncesinde İtikadi, Siyasi ve Fıkhi Yorumlar', <String>[
        'Dini Yorum Farklılıklarının Sebepleri', 'Dini Yorumlarla İlgili Bazı Kavramlar',
        'İslam Düşüncesinde İtikadi ve Siyasi Yorumlar', 'İslam Düşüncesinde Fıkhi Yorumlar',
        "Kur'an'dan Mesajlar: Nisâ Suresi 59. Ayet",
      ]),
      Unit('İslam ve İbadet', <String>[
        "İslam'da İbadet ve Kapsamı", "İslam'da İbadetin Amacı ve Önemi",
        "İslam'da İbadet Yükümlülüğü", "İslam'da İbadetlerin Temel İlkeleri",
        "İslam'da İbadet Ahlak İlişkisi", "Kur'an'dan Mesajlar: Bakara Suresi 177. Ayet",
      ]),
      Unit('Ahlaki Tutum Davranışlar', <String>[
        'İslam Ahlakının Konusu ve Gayesi - İslam Ahlakının Kaynakları', 'Ahlak ve Terbiye İlişkisi',
        'İslam Ahlakında Yerilen Bazı Davranışlar', 'Tutum ve Davranışlarda Ölçülü Olmak',
        "Kur'an'dan Mesajlar: Hucurât Suresi 11-12. Ayetler",
      ]),
      Unit('Din ve Hayat', <String>[
        'Din ve Aile', 'Din, Kültür ve Sanat',
        'Din ve Çevre', 'Din ve Sosyal Değişim',
        'Din ve Ekonomi', 'Din ve Sosyal Adalet',
        "Kur'an'dan Mesajlar: Âl-i İmrân Suresi 103-105. Ayetler",
      ]),
      Unit('Gençlik ve Değerler', <String>[
        'Değerler ve Değerlerin Kaynağı', 'Gençlerin Kişilik Gelişiminde Değerlerin Yeri ve Önemi',
        'Temel Değerler', "Kur'an'dan Mesajlar: İsrâ Suresi 23-29. Ayetler",
      ]),
      Unit('Gönül Coğrafyamız', <String>[
        'İslam Medeniyeti ve Özellikleri', 'İslam Medeniyetinin Farklı Coğrafyalardaki İzleri',
        "Kur'an'dan Mesajlar: Hucurât Suresi 13. Ayet",
      ]),
      Unit('Hz. Muhammed ve Gençlik', <String>[
        "Kur'an-ı Kerim'de Gençler", 'Bir Genç Olarak Hz. Muhammed',
        'Hz. Muhammed ve Gençler', 'Bazı Genç Sahabiler',
        "Kur'an'dan Mesajlar: Âl-i İmrân Suresi 159. Ayet",
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
      Unit('Giriş ve Genel Konular', <String>[
        'Edebiyata Giriş', 'Şiir Bilgisi', 'Edebî Sanatlar', 'Edebî Akımlar',
      ]),
      Unit('Şiir', <String>[
        'İslamiyet Öncesi Türk Şiiri', 'Geçiş Dönemi Türk Şiiri', 'Halk Şiiri',
        'Divan Şiiri', 'Tanzimat Dönemi Türk Şiiri',
        'Servetifünun Dönemi Türk Şiiri', 'Fecriati Dönemi Türk Şiiri',
        'Millî Edebiyat Dönemi Türk Şiiri', 'Cumhuriyet Dönemi Türk Şiiri',
      ]),
      Unit('Hikâye', <String>[
        'Hikâye Türleri ve Hikâyenin Yapı Unsurları',
        "Tanzimat Dönemi'ne Kadar Halk Hikâyesi ve Mesneviler",
        'Tanzimat ve Servetifünun Dönemi Türk Hikâyesi',
        'Millî Edebiyat Dönemi Türk Hikâyesi',
        'Cumhuriyet Dönemi Türk Hikâyesi',
      ]),
      Unit('Roman', <String>[
        'Roman Türü ve Yapı Unsurları', 'Tanzimat Dönemi Türk Romanı',
        'Servetifünun Dönemi Türk Romanı', 'Millî Edebiyat Dönemi Türk Romanı',
        'Cumhuriyet Dönemi Türk Romanı', 'Dünya Edebiyatında Roman',
      ]),
      Unit('Tiyatro', <String>[
        'Tiyatro Türü ve Yapı Unsurları', 'Geleneksel Türk Tiyatrosu',
        'Tanzimat, Servetifünun ve Millî Edebiyat Dönemi Türk Tiyatrosu',
        'Cumhuriyet Dönemi Türk Tiyatrosu',
      ]),
      Unit('Diğer Türler', <String>[
        'Masal/Fabl', 'Destan/Efsane', 'Öğretici Metinler',
        'Divan Edebiyatı Nesir Türleri',
      ]),
    ],
    'Tarih': <Unit>[
      Unit('Tarih ve Zaman', <String>[
        'İnsanlığın Hafızası Tarih', 'Zamanın Taksimi',
      ]),
      Unit('İlk ve Orta Çağlarda Türk Dünyası', <String>[
        "Avrasya'da İlk Türk İzleri, Coğrafya ile Oluşan Yaşam Tarzı", 'Boylardan Devlete-I',
        'Boylardan Devlete-II', 'Kavimler Göçü',
      ]),
      Unit('İslam Medeniyetinin Doğuşu', <String>[
        "İslamiyet'in Doğduğu Dönemde Dünya, İslamiyet Yayılıyor", 'Emeviler',
        'Abbasi Devleti ve Türkler-Bilim Medeniyeti',
      ]),
      Unit("Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet'i Kabulü", <String>[
        "Türklerin İslamiyet'i Kabulü", "İslamiyet'in Türk Devlet ve Toplum Yapısına Etkisi",
        'Büyük Selçuklu Devleti',
      ]),
      Unit('Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi', <String>[
        "Türklerin Anadolu'ya Yerleşme Süreci", "Anadolu'nun İlk Türk Siyasi Teşekkülleri",
        'Hilal ve Haç Mücadelesi', 'Moğol İstilası ve Anadolu',
      ]),
      Unit('Beylikten Devlete Osmanlı Siyaseti (1302-1453)', <String>[
        "Osmanlı Beyliği'nin Kuruluşu ve İlk Fetihleri", "Osmanlı Devleti'nin Rumeli'deki İskân ve İstimâlet Politikası",
        "Anadolu'da Türk Siyasi Birliğini Sağlama Çabaları",
      ]),
      Unit('Devletleşme Sürecinde Savaşçılar ve Askerler', <String>[
        'Devletleşme Sürecinde Savaşçılar ve Askerler',
      ]),
      Unit('Beylikten Devlete Osmanlı Medeniyeti', <String>[
        'Beylikten Devlete Osmanlı Medeniyeti',
      ]),
      Unit('Dünya Gücü Osmanlı (1453-1595)', <String>[
        "İstanbul'un Fethi ve Fethin Sonuçları", 'Türk İslam Dünyasında Birliği Sağlama Çabaları',
        'Dünyanın Muhteşem Gücü Osmanlı', 'Stratejik Siyaset ve Dünya Gücü Olan Osmanlı Devleti',
      ]),
      Unit('Sultan ve Osmanlı Merkez Teşkilatı', <String>[
        'Saray ve Şehir Kültürü, Gelenekler Işığında Devlet İdaresi',
      ]),
      Unit('Klasik Çağda Osmanlı Toplum Düzeni', <String>[
        "Osmanlı Devleti'nde Millet Sistemi, Fethettiği Yerlerdeki Kültürel Değişim", 'Osmanlı Toprak Sistemi, Lonca Teşkilatı, Vakıflar',
      ]),
      Unit('Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774)', <String>[
        'Uzun Savaşlardan Diplomasiye', 'Okyanusların Önem Kazanması ve Sömürgecilik Faaliyetleri',
        'Fetihlerden Savunmaya',
      ]),
      Unit('Değişim Çağında Avrupa ve Osmanlı', <String>[
        "Avrupa'da Değişim Çağı", "Osmanlı Devleti'nde Değişim",
        "Osmanlı Devleti'nde İsyanlar ve Düzeni Koruma Çabaları",
      ]),
      Unit('Devrimler Çağında Değişen Devlet-Toplum İlişkileri', <String>[
        'İhtilaller Çağı, Sömürgeciliğin Küresel Etkileri', "Osmanlı Devleti'nde Modern Orduya Geçiş",
        'XIX. Yüzyılda Sosyal Hayattaki Değişimler',
      ]),
      Unit('Uluslararası İlişkilerde Denge Stratejisi (1774-1914)', <String>[
        "Osmanlı Devleti'ne Yönelik Tehditler-I", "Osmanlı Devleti'nde Demokratikleşme Hareketleri",
        "Osmanlı Devleti'nde Darbeler", 'Osmanlı Devletine Yönelik Tehditler-II',
      ]),
      Unit('XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat', <String>[
        "Osmanlı Devleti'nde Sanayileşme Çabaları", 'XIX ve XX. Yüzyılda Osmanlı Nüfusu, Metropoller, Salgınlar ve Kamuoyu',
      ]),
      Unit('XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya', <String>[
        "Mustafa Kemal'in Lider Olarak Yetişmesinde Etkili Koşullar", '20. Yüzyıl Başlarında Osmanlı Devleti',
        'I. Dünya Savaşı Sürecinde Osmanlı Devleti', "I. Dünya Savaşı'nın Sonuçları",
      ]),
      Unit('Millî Mücadele', <String>[
        "Millî Mücadele'ye Hazırlık Dönemi-I", 'Büyük Millet Meclisinin Açılması-Sevr Antlaşması',
        'Doğu, Güney ve Batı Cepheleri', "Millî Mücadele'nin Sona Ermesi ve Lozan Barış Antlaşması",
        "Millî Mücadele'ye Hazırlık Dönemi-II",
      ]),
      Unit('Atatürkçülük ve Türk İnkılabı', <String>[
        'Atatürk İlkeleri, Siyasi ve Hukuk Alanındaki Gelişmeler', "Atatürk Dönemi'nde Yapılan İnkılaplar",
      ]),
      Unit('İki Savaş Arasındaki Dönemde Türkiye ve Dünya', <String>[
        'Atatürk Dönemi İç Politikadaki Gelişmeler',
        'İki Dünya Savaşı Arasındaki Dönemde Dünya',
        'Atatürk Dönemi Türk Dış Politikası',
      ]),
      Unit('II. Dünya Savaşı Sürecinde Türkiye ve Dünya', <String>[
        "II. Dünya Savaşı Sürecinde Türkiye ve Savaşı'nın Sonuçları",
      ]),
      Unit('II. Dünya Savaşı Sonrasında Türkiye ve Dünya', <String>[
        'II. Dünya Savaşı Sonrası Gelişmeler',
      ]),
      Unit('Toplumsal Devrim Çağında Dünya ve Türkiye', <String>[
        '1960 Sonrası Dünyada Yaşanan Siyasi Gelişmeler',
        '1960 Sonrasında Türk Dış Politikası',
        "Türkiye'deki Siyasi, Ekonomik, Sosyokültürel Hayat",
      ]),
      Unit('XXI. Yüzyılın Eşiğinde Türkiye ve Dünya', <String>[
        '1990 Sonrasında Türkiye',
        "1990 Sonrasında Meydana Gelen Siyasi Gelişmelerin Türkiye'ye Etkileri",
      ]),

    ],
    'Coğrafya': <Unit>[
      Unit('Ekosistemlerin İşleyişi ve Özellikleri', <String>[
        'Biyoçeşitlilik ve Biyomlar', 'Ekosistemler ve Madde Döngüleri',
      ]),
      Unit('Nüfus Politikaları ve Yerleşmeler', <String>[
        'Nüfus Politikaları ve Türkiye Nüfusunun Geleceği',
        'Yerleşme Özellikleri ve Şehirler',
      ]),
      Unit('Ekonomik Faaliyetler ve Doğal Kaynaklar', <String>[
        'Üretim, Dağıtım ve Tüketim', 'Doğal Kaynaklar ve Ekonomi',
      ]),
      Unit("Türkiye'de Ekonomi", <String>[
        'Türkiye\x27nin Ekonomi Politikaları ve Tarımı Etkileyen Faktörler',
        'Türkiye\x27de Tarım Ürünleri', 'Türkiye\x27de Ormancılık ve Hayvancılık',
        'Türkiye\x27de Madencilik ve Enerji Kaynakları', 'Türkiye\x27de Sanayi',
      ]),
      Unit('Kültür Bölgeleri', <String>[
        'İlk Kültür Merkezleri ve Kültür Bölgeleri',
        'Türk Kültürü ve Anadolu\x27nun Kültürel Özellikleri',
      ]),
      Unit('Küreselleşen Dünya', <String>[
        'Küresel Ticaret', 'Turizm',
        'Ülkelerin Sanayileşme Süreci ve Tarım-Ekonomi İlişkisi',
        'Uluslararası Örgütler',
      ]),
      Unit('Çevre Sorunları', <String>[
        'Çevre Sorunları ve Türleri',
        'Doğal Kaynaklar, Madenler ve Enerji Kaynakları Kullanımının Çevresel Etkileri',
        'Arazi Kullanımı, Küresel Çevre Sorunları ve Geri Dönüşüm',
      ]),
      Unit('Ekstrem Doğa Olayları ve Doğa Olaylarının Geleceği', <String>[
        'Ekstrem Doğa Olayları', 'Doğa Olaylarının Geleceği',
      ]),
      Unit('Ekonomi, Şehirleşme ve Göç', <String>[
        'Geçmişten Geleceğe Şehir ve Ekonomi', 'Geleceğin Dünyası',
      ]),
      Unit("Türkiye'nin İşlevsel Bölgeleri ve Kalkınma Projeleri", <String>[
        'Türkiye\x27nin İşlevsel Bölgeleri',
        'Türkiye\x27nin Bölgesel Kalkınma Projeleri',
      ]),
      Unit('Ulaşım, Ticaret, Turizm', <String>[
        'Hizmet Sektörü ve Ulaşım', 'Dünyada ve Türkiye\x27de Ticaret',
        'Türkiye Turizmi',
      ]),
      Unit('Jeopolitik Konum ve Ülkeler Arası Etkileşim', <String>[
        'Ülkelerin Konumunun Etkileri ve Türkiye\x27nin Jeopolitik Konumu',
        'Ülkelerin Gelişmişliği', 'Enerji Nakil Hatları', 'Çatışma Bölgeleri',
      ]),
      Unit('Doğal Çevrenin Sınırlılığı, Çevresel Örgüt ve Anlaşmalar', <String>[
        'Doğal Çevrenin Sınırlılığı, Çevresel Örgüt ve Anlaşmalar',
      ]),
    ],

    'Felsefe Grubu': <Unit>[
      Unit('Felsefeyi Tanıma', <String>[
        'Felsefenin Anlamı', 'Felsefi Düşüncenin Ortaya Çıkışı ve Özellikleri - Felsefe Sorusu Nedir?',
        'Felsefenin İnsan ve Toplum Hayatı Üzerindeki Rolü',
      ]),
      Unit('Felsefe ile Düşünme', <String>[
        'Düşünme ve Akıl Yürütmeye İlişkin Kavramlar', 'Düşünme ve Dil İlişkisi - Felsefi Bir Görüşü veya Argümanı Sorgulama',
      ]),
      Unit('Felsefi Okuma ve Yazma', <String>[
        'Felsefi Okuma ve Yazma',
      ]),
      Unit('Varlık Felsefesi', <String>[
        'Varlık Felsefesinin Konusu ve Problemleri', 'Varlık Felsefesi Alanındaki Çağdaş Yaklaşımlar',
        'Evrende Amaçlılık ve Düzenlilik-Varlık Türlerinin Sınıflandırılması-Bir konunun Varlık Felsefesi Açısından Değerlendirilmesi',
      ]),
      Unit('Bilgi Felsefesi', <String>[
        'Bilgi Felsefesinin Konusu ve Bilginin İmkânı Problemi', 'Bilginin Kaynağı İle İlgili Görüşler',
        'Bilginin Sınırları-Doğru Bilginin Ölçütü-Doğruluk ve Gerçeklik-Bilginin Değeri ve Güvenirliği',
      ]),
      Unit('Bilim Felsefesi', <String>[
        'Bilim Felsefesinin Konusu ve Problemleri', 'Bilimin Değeri-Bilim Felsefe İlişkisi-Bilim ve Hayat İlişkisi',
      ]),
      Unit('Ahlak Felsefesi', <String>[
        'Ahlak Felsefesinin Konusu ve Problemleri-İyi ve Kötünün Ölçütü', 'Özgürlük ve Sorumluluk',
        'Evrensel Bir Ahlak Yasasını Kabul Eden Görüşler', 'Evrensel Bir Ahlak Yasasını Reddeden Görüşler ve Filozoflar',
        'İyilik ve Mutluluk İlişkisi-Özgürlük, Sorumluluk ve Kural İlişkisi',
      ]),
      Unit('Din Felsefesi', <String>[
        "Din Felsefesinin Konusu ve Soruları Tanrı'nın Varlığı İle İlgili Görüşler", 'Din Felsefesinin Soruları-Teoloji ve Din Felsefesi-Felsefe, Bilim ve Din Açısından Ben Kimim?',
      ]),
      Unit('Siyaset Felsefesi', <String>[
        'Siyaset Felsefesinin Konusu ve Problemleri-Hak, Adalet, Özgürlük-İktidarın Kaynağı', 'İdeal Devlet Düzenine Yönelik Görüşler-Ütopya',
        'Egemenlik Sorunu-Toplumsal Sorunlara Felsefi Bakış',
      ]),
      Unit('Sanat Felsefesi', <String>[
        'Sanat Felsefesinin Konusu ve Problemleri-Güzellik-Sanat Nedir?', 'Sanat Kuramları-Sanat Eserinin Özellikleri-Sanat ve Duyarlılık-Şehir, İnsan ve Sanat',
      ]),
      Unit('MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi', <String>[
        "İlk Medeniyetlerin Felsefenin Doğuşuna Etkisi-Anadolu'da Yaşamış Filozoflar", 'İlk Neden (Arkhe) ve Değişim Problemi',
        "Sofistler ile Sokrates'in Bilgi ve Değer Anlayışları", "Platon'un Varlık, Bilgi ve Değer Anlayışı",
        "Aristoteles'in Varlık, Bilgi ve Değer Anlayışı", 'Görüş Analizi: Konfüçyüs, Sokrates, Platon ve Aristoteles',
      ]),
      Unit('MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi', <String>[
        'MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesinin Ortaya Çıkışı-Hristiyan Felsefesinin Özellikleri ve Problemleri', 'İslam Felsefesinin Özellikleri ve Problemleri',
        'İnanç-Akıl İlişkisi - Çeviri Faaliyetleri', 'Görüş Analizi (Augustinus, Fârâbî, İbn Sina, Gâzâlî ve İbn Rüşd)-Tasavvuf Düşüncesi',
      ]),
      Unit('15. Yüzyıl-17. Yüzyıl Felsefesi', <String>[
        '15. Yüzyıl-17. Yüzyıl Felsefesinin Ortaya Çıkışı', '15. Yüzyıl-17. Yüzyıl Felsefesinde Öne Çıkan Görüşler',
        'Bilimsel Çalışmaların 15. Yüzyıl-17. Yüzyıl Felsefesine Etkisi', 'Görüş Analizi: R. Descartes, B. Spinoza ve T. Hobbes',
      ]),
      Unit('18. Yüzyıl-19. Yüzyıl Felsefesi', <String>[
        '18. Yüzyıl-19. Yüzyıl Felsefesinin Ortaya Çıkışı-Genel Özellikleri - Dil ve Edebiyatla İlişkisi', '18. Yüzyıl-19. Yüzyıl Felsefesinin Öne Çıkan Problemleri-1',
        '18. Yüzyıl-19. Yüzyıl Felsefesinin Öne Çıkan Problemleri-2', 'Görüş Analizi: J. Locke, I. Kant ve F. Hegel',
      ]),
      Unit('20. Yüzyıl Felsefesi', <String>[
        '20. Yüzyıl Felsefesinin Ortaya Çıkışı', '20. Yüzyıl Felsefesi: Fenomenoloji, Hermeneutik, Varoluşçuluk',
        '20. Yüzyıl Felsefesi: Diyalektik Materyalizm, Mantıksal Pozitivizm, Yeni Ontoloji', "Türkiye'de Felsefi Düşünceye Katkıda Bulunan Felsefeciler-Çağımızın Felsefecileri-Yaşadıkları Yerler",
        'Görüş Analizi: F. Nietzsche, H. Bergson, J. P. Sartre ve T. Kuhn', "N. Topçu, T. Mengüşoğlu ve K. Popper'ın Görüşlerinin Tartışılması",
      ]),
      Unit('Mantığa Giriş', <String>[
        'Doğru Düşünme - Temel Kavramlar',
        'Akıl İlkeleri',
        'Akıl Yürütme Yöntemleri',
        'Mantığın Uygulama Alanları',
      ]),
      Unit('Klasik Mantık', <String>[
        'Aristoteles ve Mantık - Kavram ve Terim',
        'Nelik, Gerçeklik, Kimlik - İçlem ve Kaplam',
        'Kavram Çeşitleri',
        'Beş Tümel',
        'Kavramlar Arası İlişkiler - Tanım',
        'Önerme ve Önerme Çeşitleri',
        'Çıkarım - Karşı Olum Çıkarımları',
        'Eşdeğerlik Çıkarımları',
        'Dolaylı Çıkarım - Kıyas',
        'Kıyas Çeşitleri',
      ]),
      Unit('Mantık ve Dil', <String>[
        'Dil ve Düşünme İlişkisi - Dilin Görevleri',
        'Bilgi Aktarma ve Dil - Anlama ve Tanımlama',
      ]),
      Unit('Sembolik Mantık', <String>[
        'Sembolik Mantığa Geçiş - Önerme ve Yapısı - Basit ve Bileşik Önermeler - Çıkarım',
        'Sembolleştirme - Önerme Eklemleri',
        'Yorumlama - Önermelerin Doğruluk Değerleri - Doğruluk Çizelgesi',
        'Tutarlılık, Geçerlilik, Eşdeğerlik Denetlemesi',
        'Çözümleyici Çizelge Kuralları',
        'Çözümleyici Çizelge ile Tutarlılık, Geçerlilik ve Eşdeğerlik Denetlemesi',
        'Niceleme Mantığı - Temel Kurallar - Denetlemeler',
        'Çok Değerli Mantık',
      ]),
      Unit('Psikoloji Bilimini Tanıyalım', <String>[
        'Psikolojinin Konusu - Bir Bilim Dalı Olma Süreci',
        'Psikolojideki Yaklaşımlar-1: Yapısalcılık, İşlevselcilik, Gestalt, Davranışçılık, Psikoanalitik',
        'Psikolojideki Yaklaşımlar-2: İnsancıl, Varoluşçu, Bilişsel, Sosyokültürel',
        'Psikolojinin Bilim Dalı Olarak Ölçütleri, Amaçları - Araştırmalarda Uyulması Gereken Etik Kurallar',
        'Psikoloji Araştırmalarında Uygulanan Yöntem ve Teknikler',
        'Psikolojinin Alt Dalları - İş Alanları - Diğer Bilim Dallarıyla İlişkisi',
      ]),
      Unit('Psikolojinin Temel Süreçleri', <String>[
        'Davranışın Oluşumu - Kalıtım ve Çevrenin Davranışa Etkisi',
        'Yaşam Boyu Gelişim - Gelişim Dönemleri ve Temel Özellikleri',
        'Gelişim Kuramları',
        'Ergenlik Dönemi - Temel Özellikleri ve Bu Dönemi Etkileyen Faktörler',
        'Duyumun Özellikleri ve Temel Duyum Bilgileri',
        'Uyarılmanın Davranışlara Etkisi - Alışma ve Duyarlılaşma',
        'Algılama - Algı Yanılmaları',
        'Algıyı Etkileyen Faktörler - Duyum ve Algı Arasındaki Farklar',
        'Güdülenmeyi Ortaya Çıkaran Faktörler - Güdülenmiş Davranışın Özellikleri - İhtiyaçlar Hiyerarşisi',
        'Duygu ve Duygu Türleri - Duyguların Davranışlara Etkisi',
        'Bilinç - Dikkat - Bilinçlilik Türleri',
        'Sosyoloji ve Sosyal Psikoloji - Sosyal Biliş ve Sosyal Etki Türleri - Davranış ve Sosyal Etkenler',
      ]),
      Unit('Öğrenme, Bellek, Düşünme', <String>[
        'Öğrenme ve Öğrenme Türleri - Koşullanma Yoluyla Öğrenme',
        'Bilişsel Öğrenme',
        'Öğrenmeyi Etkileyen Faktörler',
        'Öğrenme Stratejileri ve Görevleri - Hayat Boyu Öğrenme',
        'Bellek ve Bellek Türleri',
        'Belleğin Temel İşlevleri - Unutmaya Sebep Olan Faktörler - Bellek Geliştirme Teknikleri',
        'Düşünmenin Yapı Taşları - Dilin Düşünmedeki Rolü - Doğru Karar Vermede İrdelemenin Önemi',
        'Zekâ - Kalıtım ve Çevrenin Zekâ Üzerindeki Etkileri - Zekâ Testleri',
        'Zekâ Türleri - Zekâ ve Yaratıcılık',
      ]),
      Unit('Ruh Sağlığının Temelleri', <String>[
        'Kişilik ve Kişiliğin Gelişimi - Kişilik Kuramları',
        'Bireysel Farklılıklar - Kişiliğin Ölçülmesi',
        'Stres ve Stresin Nedenleri - Stresin Günlük Yaşama Etkileri',
        'Stresle Başa Çıkma Yolları - Savunma Mekanizmaları',
        'Ruh Sağlığının Önemi ve Ölçütleri - Ruh Sağlığını Korumada Denge - Empati ve Hoşgörü',
        'Ruh Sağlığı Açısından Normal ve Normal Dışı Kavramları',
        'Normal Dışı Davranışlar - Kişilik Bozuklukları - Şizofreni',
        'Psikolojik Destek',
      ]),
      Unit('Sosyolojiye Giriş', <String>[
        'Sosyolojiyi Tanıyalım',
        'Sosyolojik Düşünmenin Bireye ve Topluma Katkısı - Sosyolojinin Diğer Sosyal Bilim Dallarıyla İlişkisi',
        'Toplum ve Toplumu Oluşturan Ögeler',
        'Sosyolojinin Doğuşunda Etkili Olan Olaylar - Sosyolojinin Kurucuları',
        'Sosyolojide Kullanılan Başlıca Yöntemler',
        'Sosyolojide Kullanılan Veri Toplama Teknikleri',
        "Türkiye'de Sosyoloji",
      ]),
      Unit('Toplumsal Yapı', <String>[
        'Toplumsal Yapı Nedir? Toplumsal Yapıya Etki Eden Faktörler - Toplumsal Yapıyı Oluşturan Unsurlar',
        'Toplumsal Etkileşim Tipleri',
        'Toplumsal Tabakalaşma - Toplumsal Hareketlilik',
      ]),
      Unit('Birey ve Toplum', <String>[
        'Sosyalleşme ve Sosyalleşmeyi Etkileyen Unsurlar',
        'Sosyalleşmenin Aşamaları ve Sosyalleşmenin Toplumsal İlişkiler Üzerindeki Etkisi',
        'Toplumsal Statü - Toplumsal Rol - Toplumsal Saygınlık',
        'Toplumsal Değer - Toplumsal Norm - Toplumsal Kontrol',
        'Toplumsal Sapma ve Suç, Hak ve Görev Dengesi',
      ]),
      Unit('Toplum ve Kültür', <String>[
        'Kültürün Anlamı',
        'Kültürün İşlevleri',
        'Kültüre İlişkin Kavramlar',
        'Toplumsal Kültürün Önemi',
        'Kültürel Tutumlar ve Kültürler Arası Etkileşim',
      ]),
      Unit('Toplumsal Kurumlar', <String>[
        'Kurum Kavramı ve Kurumların İşlevleri',
        'Aile Kurumu ve Evlilik',
        'Ailenin İşlevleri ve Aile Türleri',
        'Eğitim Kurumu - Önemi ve İşlevleri',
        'Din Kurumu - Önemi ve İşlevleri',
        'Ekonomi Kurumu - Önemi ve İşlevleri',
        'Ekonominin Toplumsal Yaşamdaki Önemi',
        'Toplumsal Yaşamda Ekonominin Temel Ögeleri',
        'Temel Ekonomik Sistemler',
        'Siyaset Kurumu ve Temel Kavramları',
        'Siyasal Yönetim Biçimleri',
      ]),
      Unit('Toplumsal Değişme ve Gelişme', <String>[
        'Toplumsal Değişme ve Toplumsal Değişmeyi Etkileyen Faktörler',
        'Toplumsal Değişme ve Kültür',
        'Modernleşme ve Küreselleşme',
        'Toplumsal Gelişme ve Toplumsal Gelişmenin Ögeleri - Toplumsal Bütünleşme - Toplumsal Çözülme',
      ]),

    ],
    'Din Kültürü': <Unit>[
      Unit('Dünya ve Ahiret', <String>[
        'Varoluşun ve Hayatın Anlamı',
        'Ahiret Âlemi',
        'Ahirete Uğurlama',
        "Kur'an'dan Mesajlar: Bakara Suresi 153-157. Ayetler",
      ]),
      Unit("Kur'an'a Göre Hz. Muhammed", <String>[
        "Hz. Muhammed'in Şahsiyeti",
        "Hz. Muhammed'in Peygamberlik Yönü",
        "Hz. Muhammed'e Bağlılık ve İtaat",
        "Kur'an'dan Mesajlar: Ahzâb Suresi 45-46. Ayetler",
      ]),
      Unit("Kur'an'da Bazı Kavramlar", <String>[
        "Kur'an'da Bazı Kavramlar",
        "Kur'an-ı Kerim'de Geçen Kavramları Bilmenin İslam'ı Doğru Anlamadaki Önemi",
        "Kur'an'dan Mesajlar: Kehf Suresi 107-110. Ayetler",
      ]),
      Unit('İnançla İlgili Meseleler', <String>[
        'İnançla İlgili Felsefi Yaklaşımlar',
        'Yeni Dinî Hareketler',
        "Kur'an'dan Mesajlar: En'âm Suresi 59. Ayet ve Lokman Suresi 27. Ayet",
      ]),
      Unit('Yahudilik ve Hristiyanlık', <String>[
        'Yahudilik',
        'Hristiyanlık',
      ]),
      Unit('İslam ve Bilim', <String>[
        'Din-Bilim İlişkisi',
        'İslam Medeniyetinde Bilim ve Düşüncenin Gelişimi',
        'İslam Medeniyetinde Öne Çıkan Eğitim Kurumları',
        'Müslümanların Bilim Alanında Yaptığı Öncü ve Özgün Çalışmalar',
        "Kur'an'dan Mesajlar: Fâtır Suresi 27-28. Ayetler",
      ]),
      Unit("Anadolu'da İslam", <String>[
        'Türklerin Müslüman Olmaları',
        'Milletimizin İslam Anlayışının Oluşmasında Etkili Olan Bazı Şahsiyetler',
        "Kur'an'dan Mesajlar: Nisâ Suresi 69. Ayet",
      ]),
      Unit('İslam Düşüncesinde Tasavvufi Yorumlar', <String>[
        'Tasavvufi Düşüncenin Oluşumu',
        'Tasavvufi Düşüncenin Ahlaki Boyutu',
        'Kültürümüzde Etkin Olan Tasavvufi Yorumlar',
        "Kur'an'dan Mesajlar: Hucurât Suresi 10. Ayet",
      ]),
      Unit('Güncel Dinî Meseleler', <String>[
        'Dinî Meselelerin Çözümünde Temel İlke ve Yöntemler',
        'İktisadi Hayatla İlgili Meseleler',
        'Gıda Maddeleri ve Bağımlılıkla İlgili Meseleler',
        'Sağlık ve Tıpla İlgili Meseleler',
        "Kur'an'dan Mesajlar: En'âm suresi 151-152. Ayetler",
      ]),
      Unit('Hint ve Çin Dinleri', <String>[
        'Hinduizm',
        'Budizm',
        'Konfüçyanizm',
        'Taoizm',
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
