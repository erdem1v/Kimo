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
        'Paragrafta Yapı', 'Anlatım Teknikleri',
      ]),
      Unit('Dil Bilgisi', <String>[
        'Ses Bilgisi', 'Sözcükte Yapı (Ekler)', 'İsim (Ad)', 'Sıfat', 'Zamir',
        'Zarf', 'Edat-Bağlaç-Ünlem', 'Fiilde Anlam (Kip-Kişi)', 'Ek Fiil',
        'Fiilimsi', 'Cümlenin Ögeleri', 'Cümle Türleri',
      ]),
      Unit('Yazım ve Anlatım', <String>[
        'Yazım Kuralları', 'Noktalama İşaretleri', 'Anlatım Bozuklukları',
      ]),
    ],
    'Matematik': <Unit>[
      Unit('Sayılar ve İşlemler', <String>[
        'Temel Kavramlar', 'Sayı Basamakları', 'Bölme-Bölünebilme', 'OBEB-OKEK',
        'Rasyonel Sayılar',
      ]),
      Unit('Cebirsel İfadeler', <String>[
        'Basit Eşitsizlikler', 'Mutlak Değer', 'Üslü Sayılar', 'Köklü Sayılar',
        'Çarpanlara Ayırma', 'Oran-Orantı',
      ]),
      Unit('Problemler', <String>[
        'Sayı Problemleri', 'Kesir Problemleri', 'Yaş Problemleri',
        'İşçi-Havuz Problemleri', 'Hareket Problemleri', 'Yüzde Problemleri',
        'Kâr-Zarar Problemleri', 'Karışım Problemleri', 'Grafik Problemleri',
      ]),
      Unit('Kümeler ve Mantık', <String>['Kümeler', 'Mantık']),
      Unit('Fonksiyonlar ve Polinomlar', <String>[
        'Fonksiyonlar', 'Polinomlar', 'İkinci Dereceden Denklemler',
      ]),
      Unit('Veri ve Olasılık', <String>[
        'Permütasyon-Kombinasyon', 'İstatistik', 'Olasılık',
      ]),
    ],
    'Geometri': <Unit>[
      Unit('Açılar ve Üçgenler', <String>[
        'Doğruda Açılar', 'Üçgende Açılar', 'Üçgende Açı-Kenar Bağıntıları',
        'Dik Üçgen', 'İkizkenar ve Eşkenar Üçgen', 'Açıortay', 'Kenarortay',
        'Üçgende Alan', 'Üçgende Benzerlik',
      ]),
      Unit('Çokgenler ve Dörtgenler', <String>[
        'Çokgenler', 'Paralelkenar', 'Dikdörtgen ve Kare', 'Eşkenar Dörtgen',
        'Yamuk',
      ]),
      Unit('Çember ve Daire', <String>['Çember ve Daire']),
      Unit('Analitik Geometri', <String>['Analitik Geometri (Nokta-Doğru)']),
    ],
    'Fizik': <Unit>[
      Unit('Fizik Bilimine Giriş', <String>['Fizik Bilimine Giriş']),
      Unit('Madde ve Özellikleri', <String>[
        'Madde ve Özellikleri', 'Sıvıların Kaldırma Kuvveti', 'Basınç',
      ]),
      Unit('Isı ve Sıcaklık', <String>['Isı ve Sıcaklık', 'Genleşme']),
      Unit('Kuvvet ve Hareket', <String>[
        'Kuvvet ve Denge (Vektörler)', 'Basit Makineler', 'Doğrusal Hareket',
        'İş-Güç-Enerji',
      ]),
      Unit('Elektrik ve Manyetizma', <String>[
        'Elektrostatik', 'Elektrik Akımı ve Devreler',
        'Mıknatıslar ve Manyetik Alan',
      ]),
      Unit('Optik', <String>[
        'Işık ve Gölge', 'Düzlem Ayna', 'Küresel Aynalar', 'Kırılma ve Renkler',
        'Mercekler',
      ]),
      Unit('Dalgalar', <String>[
        'Dalgalar (Temel)', 'Yay ve Su Dalgaları', 'Ses ve Deprem Dalgaları',
      ]),
    ],
    'Kimya': <Unit>[
      Unit('Kimya Bilimi', <String>['Kimya Bilimine Giriş']),
      Unit('Atom ve Periyodik Sistem', <String>[
        'Atomun Yapısı', 'Periyodik Sistem',
      ]),
      Unit('Kimyasal Türler Arası Etkileşimler', <String>[
        'İyonik Bağ', 'Kovalent Bağ', 'Metalik Bağ ve Zayıf Etkileşimler',
      ]),
      Unit('Maddenin Halleri', <String>['Maddenin Halleri']),
      Unit('Kimyanın Temel Kanunları', <String>[
        'Kimyanın Temel Kanunları', 'Mol Kavramı ve Hesaplamalar',
      ]),
      Unit('Karışımlar', <String>['Karışımlar']),
      Unit('Asitler, Bazlar ve Tuzlar', <String>['Asit-Baz', 'Tuzlar']),
      Unit('Kimya Her Yerde', <String>[
        'Doğa ve Kimya', 'Endüstride ve Canlılarda Enerji', 'Kimya Her Yerde',
      ]),
    ],
    'Biyoloji': <Unit>[
      Unit('Yaşam Bilimi Biyoloji', <String>['Canlıların Ortak Özellikleri']),
      Unit('Canlıların Temel Bileşenleri', <String>[
        'İnorganik Bileşikler',
        'Organik Bileşikler (Karbonhidrat-Lipit-Protein)', 'Enzimler',
      ]),
      Unit('Hücre', <String>[
        'Nükleik Asitler',
        'Hücre ve Organelleri', 'Hücre Zarından Madde Geçişi',
      ]),
      Unit('Canlılar Dünyası', <String>['Canlıların Sınıflandırılması']),
      Unit('Hücre Bölünmeleri ve Üreme', <String>[
        'Mitoz ve Eşeysiz Üreme', 'Mayoz ve Eşeyli Üreme',
      ]),
      Unit('Kalıtım', <String>['Kalıtım']),
      Unit('Ekosistem Ekolojisi', <String>[
        'Ekosistem Ekolojisi', 'Madde Döngüleri', 'Güncel Çevre Sorunları',
      ]),
    ],
    'Tarih': <Unit>[
      Unit('Tarih Bilimi', <String>['Tarih ve Zaman']),
      Unit('İlk ve Orta Çağlar', <String>[
        'İnsanlığın İlk Dönemleri', "Orta Çağ'da Dünya",
        'İlk ve Orta Çağlarda Türk Dünyası',
      ]),
      Unit('İslam Tarihi ve Türk-İslam Devletleri', <String>[
        'İslam Medeniyetinin Doğuşu', "Türklerin İslamiyet'i Kabulü",
        'Selçuklu Türkiyesi',
      ]),
      Unit('Osmanlı: Kuruluş ve Yükseliş', <String>[
        'Beylikten Devlete Osmanlı (1302-1453)', 'Osmanlı Medeniyeti',
        'Dünya Gücü Osmanlı (1453-1595)', 'Osmanlı Merkez Teşkilatı',
        'Klasik Çağda Osmanlı Toplum Düzeni',
      ]),
      Unit('Değişim Çağı', <String>['Değişen Dünya Dengeleri (1595-1774)']),
    ],
    'Coğrafya': <Unit>[
      Unit('Doğal Sistemler', <String>[
        "Dünya'nın Şekli ve Hareketleri", 'Harita Bilgisi',
        'Atmosfer ve Sıcaklık', 'Basınç ve Rüzgârlar', 'Nem-Yağış-Buharlaşma',
        'İç Kuvvetler', 'Dış Kuvvetler', 'Su Kaynakları',
        'Toprak ve Bitki Örtüsü',
      ]),
      Unit('Beşerî Sistemler', <String>[
        'Nüfus', 'Göç', 'Yerleşme', 'Ekonomik Faaliyetler',
      ]),
      Unit('Küresel Ortam', <String>['Bölgeler']),
      Unit('Çevre ve Toplum', <String>[
        'Doğa ve İnsan', 'Çevre ve Toplum', 'Doğal Afetler',
      ]),
    ],
    'Felsefe': <Unit>[
      Unit('Felsefeye Giriş', <String>['Felsefenin Konusu']),
      Unit('Felsefenin Temel Konuları', <String>[
        'Bilgi Felsefesi', 'Varlık Felsefesi', 'Din Felsefesi',
        'Ahlak Felsefesi', 'Sanat Felsefesi', 'Bilim Felsefesi',
        'Siyaset Felsefesi',
      ]),
    ],
    'Din Kültürü': <Unit>[
      Unit('İnanç', <String>[
        'Bilgi ve İnanç', 'Din ve İslam', 'Allah-İnsan İlişkisi',
      ]),
      Unit('İbadet', <String>['İslam ve İbadet']),
      Unit('Ahlak ve Değerler', <String>[
        'Gençlik ve Değerler', 'Ahlaki Tutum ve Davranışlar', 'Din ve Hayat',
      ]),
      Unit('Hz. Muhammed', <String>['Hz. Muhammed ve Gençlik']),
      Unit('Din, Kültür ve Medeniyet', <String>[
        'Gönül Coğrafyamız', 'İslam Düşüncesinde Yorumlar',
      ]),
    ],
  };

  // ======================================================= ESKİ MÜFREDAT AYT
  static const Map<String, List<Unit>> _eskiAyt = <String, List<Unit>>{
    'Matematik': <Unit>[
      Unit('Fonksiyonlar', <String>[
        'Fonksiyonlarda Uygulamalar (Ters-Bileşke)',
        'Fonksiyonların Dönüşümleri',
      ]),
      Unit('Polinomlar ve Denklemler', <String>[
        'Polinomlar', 'İkinci Dereceden Denklemler', 'Parabol', 'Eşitsizlikler',
      ]),
      Unit('Trigonometri', <String>[
        'Trigonometri: Yönlü Açılar',
        'Kosinüs ve Sinüs Teoremi',
        'Sinüs ve Kosinüs Fonksiyonlarının Grafikleri',
        'Ters Trigonometrik Fonksiyonlar',
        'Trigonometri: Toplam-Fark ve İki Kat Açı', 'Trigonometrik Denklemler',
      ]),
      Unit('Logaritma', <String>['Logaritma']),
      Unit('Diziler', <String>['Diziler']),
      Unit('Limit ve Türev', <String>[
        'Limit ve Süreklilik', 'Türev', 'Türev Uygulamaları (Optimizasyon)',
      ]),
      Unit('İntegral', <String>['İntegral', 'İntegral ile Alan Hesabı']),
      Unit('Sayma ve Olasılık', <String>[
        'Permütasyon-Kombinasyon', 'Binom ve Olasılık',
      ]),
    ],
    'Geometri': <Unit>[
      Unit('Analitik Geometri', <String>[
        'Analitik Geometri (Doğru)', 'Analitik Düzlemde Temel Dönüşümler',
        'Çemberin Analitik İncelenmesi',
      ]),
      Unit('Katı Cisimler', <String>[
        'Katı Cisimler (Prizma-Silindir)', 'Katı Cisimler (Piramit-Koni-Küre)',
      ]),
      Unit('Vektörler', <String>['Vektörler']),
    ],
    'Fizik': <Unit>[
      Unit('Kuvvet ve Hareket', <String>[
        'Vektörler', 'Bağıl Hareket', "Newton'un Hareket Yasaları",
        'Bir Boyutta Sabit İvmeli Hareket',
        'İki Boyutta Sabit İvmeli Hareket', 'Enerji ve Hareket',
        'Kuvvet, Tork ve Denge', 'İtme ve Momentum',
        'Çembersel Hareket', 'Basit Harmonik Hareket',
        'Kütle Çekimi ve Kepler Yasaları',
      ]),
      Unit('Elektrik ve Manyetizma', <String>[
        'Elektrik Alan ve Potansiyel', 'Kondansatörler',
        'Manyetizma ve İndüksiyon', 'Alternatif Akım',
      ]),
      Unit('Dalgalar', <String>['Dalga Mekaniği (Girişim-Kırınım-Doppler)']),
      Unit('Modern Fizik', <String>[
        'Atom Fiziği ve Radyoaktivite', 'Özel Görelilik', 'Fotoelektrik Olay',
        'Modern Fiziğin Teknolojideki Uygulamaları',
        'Compton ve de Broglie',
      ]),
    ],
    'Kimya': <Unit>[
      Unit('Modern Atom Teorisi ve Gazlar', <String>[
        'Modern Atom Teorisi', 'Gazlar', 'Sıvı Çözeltiler ve Çözünürlük',
      ]),
      Unit('Tepkimelerde Enerji, Hız ve Denge', <String>[
        'Kimyasal Tepkimelerde Enerji', 'Kimyasal Tepkimelerde Hız',
        'Kimyasal Tepkimelerde Denge',
      ]),
      Unit('Çözeltilerde Denge', <String>[
        'Asit-Baz Dengesi', 'Çözünürlük Dengesi',
      ]),
      Unit('Kimya ve Elektrik', <String>[
        'Redoks Tepkimeleri', 'Elektrokimyasal Hücreler ve Piller',
        'Elektroliz', 'Korozyon',
      ]),
      Unit('Organik Kimya', <String>[
        'Karbon Kimyasına Giriş (Hibritleşme)', 'Hidrokarbonlar',
        'Alkoller ve Eterler', 'Aldehit ve Ketonlar',
        'Karboksilik Asitler ve Esterler',
      ]),
      Unit('Enerji Kaynakları', <String>['Enerji Kaynakları']),
    ],
    'Biyoloji': <Unit>[
      Unit('Hücre Bölünmeleri ve Kalıtım', <String>[
        'Hücre Bölünmeleri (Mitoz-Mayoz)', 'Kalıtım Kalıpları',
        'Soyağacı ve Akraba Evliliği', 'Modern Genetik Uygulamaları',
      ]),
      Unit('Genden Proteine', <String>[
        'Nükleik Asitler', 'DNA Replikasyonu', 'Protein Sentezi',
      ]),
      Unit('Canlılarda Enerji Dönüşümleri', <String>[
        'Fotosentez', 'Kemosentez', 'Hücresel Solunum',
      ]),
      Unit('Bitki Biyolojisi', <String>[
        'Bitkisel Hormonlar',
        'Bitkisel Dokular', 'Bitkilerde Taşıma-Beslenme-Terleme',
        'Bitkilerde Üreme',
      ]),
      Unit('İnsan Fizyolojisi', <String>[
        'Sinir Sistemi', 'Endokrin Sistem ve Hormonlar', 'Duyu Organları',
        'Destek ve Hareket Sistemi', 'Sindirim Sistemi', 'Dolaşım Sistemi',
        'Bağışıklık Sistemi', 'Solunum Sistemi', 'Boşaltım Sistemi',
        'Üreme Sistemi ve Embriyonik Gelişim',
      ]),
      Unit('Ekoloji', <String>[
        'Komünite Ekolojisi',
        'Ekosistem Ekolojisi', 'Madde Döngüleri', 'Popülasyon Ekolojisi',
      ]),
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
