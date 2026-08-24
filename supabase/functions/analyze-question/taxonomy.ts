// YKS konu taksonomisi — AI sınıflandırması için referans ağacı.
// Kaynak: YKS_TYT_AYT_Konulari.md (Bölüm A: eski/2018, Bölüm B: maarif/2028+).
// AI, dersi ve konuyu BU listelerden seçer; parantez içi alt konular ayrı
// kalemlere açıldı ki "İnsan Fizyolojisi" yerine "Destek ve Hareket Sistemi"
// gibi SPESİFİK sonuç verebilsin. İsimlendirme böylece tutarlı kalır.

export type Curriculum = "eski" | "maarif";
export type Exam = "TYT" | "AYT";

type Subjects = Record<string, string[]>;
type ByExam = Record<Exam, Subjects>;

export const TAXONOMY: Record<Curriculum, ByExam> = {
  eski: {
    TYT: {
      "Türkçe": [
        "Sözcükte Anlam 1", "Sözcükte Anlam 2", "Sözcükte Anlam 3",
        "Sözcükte Anlam 4", "Cümlede Anlam 1", "Cümlede Anlam 2",
        "Cümlede Anlam 3", "Paragrafta Anlam 1", "Paragrafta Anlam 2",
        "Paragrafta Anlam 3", "Paragrafın Yapısı", "Ses Bilgisi-1",
        "Ses Bilgisi-2", "Biçim Bilgisi 1", "Biçim Bilgisi 2",
        "İsim", "Sıfat", "Zamir",
        "İsim ve Sıfat Tamlamaları", "Zarf", "Edat, Bağlaç ve Ünlem",
        "Fiilde Kip", "Ek-Fiil", "Fiilde Yapı",
        "Fiilimsiler", "Fiilde Çatı", "Cümlenin Ögeleri",
        "Cümle Türleri", "Yazım Kuralları-1", "Yazım Kuralları-2",
        "Yazım Kuralları-3", "Noktalama İşaretleri-1", "Noktalama İşaretleri-2",
        "Noktalama İşaretleri-3", "Anlama Dayalı Bozukluklar", "Yapıya Dayalı Bozukluklar",
      ],
      "Matematik": [
        "Önermeler", "Bileşik Önermeler", "Koşullu Önerme",
        "İki Yönlü Koşullu Önerme", "Niceleyiciler", "Tanım, Aksiyom, Teorem ve İspat Kavramları",
        "Kümelerde Temel Kavramlar", "Alt Küme", "Kümelerde Kesişim ve Birleşim İşlemleri",
        "Kümelerde Fark ve Tümleme İşlemleri", "Küme Problemleri", "Sıralı İkililer ve Kartezyen Çarpım",
        "Sayı Kümeleri", "Temel İşlemler", "Tek ve Çift Sayılar",
        "Pozitif ve Negatif Sayılar", "Ardışık Sayılar", "Sayı Basamakları",
        "Asal ve Aralarında Asal Sayılar", "Ondalık ve Devirli Ondalık Sayılar", "Rasyonel Sayılarda İşlemler",
        "Tamsayılarda Kalanlı Bölme İşlemi", "Bölünebilme Kuralları 1", "Bölünebilme Kuralları 2",
        "Asal Çarpanlar", "EBOB-EKOK Kavramı ve Özellikleri", "EBOB-EKOK Problemleri",
        "Periyodik Problemler", "Aralık Kavramı", "Birinci Dereceden Bir Bilinmeyenli Denklemler",
        "Basit Eşitsizlikler", "Birinci Dereceden İki Bilinmeyenli Denklemler", "Birinci Dereceden İki Bilinmeyenli Eşitsizlikler",
        "Birinci Dereceden İki Bilinmeyenli Eşitsizlik Sistemleri", "Mutlak Değer Kavramı ve Özellikleri", "Mutlak Değerli Denklemler ve Eşitsizlikler",
        "Üslü İfadeler ve Özellikleri", "Üslü İfade İçeren Denklem ve Eşitsizlikler", "Köklü İfadeler ve Özellikleri",
        "Köklü İfadeleri İçeren Denklem ve Eşitsizlikler", "Oran-Orantı Kavramları ve Özellikleri", "Oran-Orantı Problemleri",
        "Sayı Problemleri", "Kesir Problemleri", "Yaş Problemleri",
        "İşçi Problemleri", "Yüzde Problemleri", "Kar-Zarar Problemleri",
        "Karışım Problemleri", "Hareket Problemleri", "Rutin Olmayan Problemler",
        "Merkezi Eğilim Ölçüleri", "Merkezi Yayılım Ölçüleri", "Histogram",
        "Çizgi, Sütun ve Daire Grafikleri", "Saymanın Temel İlkesi", "Faktöriyel Kavramı",
        "Permütasyon", "Tekrarlı Permütasyon", "Kombinasyon Kavramı ve Özellikleri",
        "Kombinasyon Problemleri", "Kombinasyon ve Geometri", "Pascal Üçgeni ve Binom Açılımı",
        "Olasılıkta Temel Kavramlar", "Olasılık Kavramı İle İlgili Uygulamalar", "Fonksiyon Kavramı ve Gösterimi",
        "Fonksiyon Soruları", "İçine, Örten, Birebir ve Eşit Fonksiyonlar", "Birim ve Sabit Fonksiyon",
        "Doğrusal ve Parçalı Fonksiyonlar", "Tek-Çift Fonksiyonlar", "Fonksiyonlarda Dört İşlem",
        "Fonksiyon Grafikleri", "İki Fonksiyonun Bileşkesi", "Bir Fonksiyonun Tersi",
        "Fonksiyon Grafikleri ile İlgili Uygulamalar", "Polinom Kavramı", "Polinomlarda Toplama, Çıkarma ve Çarpma İşlemleri",
        "Polinomlarda Bölme İşlemi", "Polinomlarda Bölme İşlemi Yapmadan Kalan Bulma", "Ortak Çarpan Parantezine Alma",
        "Tam Kare veya İki Kare Farkı Özdeşliklerinde Faydalanarak Çarpanlara Ayırma", "Tam Küp, İki Küp Toplamı veya Farkı Özdeşliklerinden Faydalanarak Çarpanlara Ayırma", "Üç Terimli İfadelerin Çarpanlarına Ayrılması",
        "Rasyonel İfadelerin Sadeleştirilmesi", "İkinci Dereceden Bir Bilinmeyenli Denklemler", "İkinci Dereceden Bir Bilinmeyenli Denklemlerin Çözüm Kümesi",
        "Diskriminant Kavramı ve Diskriminantın Kullanılması", "İkinci Dereceden Denklemlerde Kök-Katsayı İlişkisi", "Karmaşık Sayılar",
      ],
      "Geometri": [
        "Açı Kavramı ve Çeşitleri", "Paralel İki Doğrunun Bir Kesenle Yaptığı Açılar", "Üçgende Açılar",
        "İkizkenar ve Eşkenar Üçgende Açı Özellikleri", "Üçgende Açı-Kenar Bağıntıları", "Üçgen Eşitsizliği",
        "Üçgenlerde Eşlik", "Üçgenlerde Benzerlik", "Üçgende Temel Orantı Teoremi",
        "Üçgenlerin Benzerliği İle İlgili Uygulamalar", "Üçgende Açıortay ve Özellikleri", "Üçgende Açıortay Teoremleri",
        "Üçgende Kenarortay", "Üçgende Yükseklik", "Üçgende Kenar Orta Dikme",
        "Dik Üçgende Pisagor Teoremi", "Dik Üçgende Öklid Teoremi", "Trigonometrik Oranlar",
        "30, 45 ve 60 Derecelerin Trigonometrik Oranları", "Birim Çember", "Üçgenin Alanı",
        "Üçgenin Alanıyla İlgili Uygulamalar", "Çokgenler", "Dörtgenler ve Özellikleri",
        "Yamukta Açı ve Uzunluk", "İkizkenar ve Dik Yamuk", "Yamuğun Alanı",
        "Paralelkenarda Açı ve Uzunluk", "Eşkenar Dörtgen", "Paralelkenarın Alanı",
        "Dikdörtgende Açı ve Uzunluk", "Kare", "Dikdörtgenin Alanı",
        "Deltoid", "Dik Prizmalar", "Küp",
        "Dik Piramitler", "Düzgün Dört Yüzlü",
      ],
      "Fizik": [
        "Fizik Bilimine Giriş", "Kütle ve Hacim", "Özkütle",
        "Dayanıklılık", "Adezyon, Kohezyon, Yüzey Gerilimi ve Kılcallık", "Hareket Kavramları",
        "İvme Kavramı", "Kuvvet Kavramı", "Newton'ın Hareket Yasaları",
        "Sürtünme Kuvveti", "İş, Enerji ve Güç Kavramı", "Enerji Çeşitleri ve Mekanik Enerji",
        "Enerji Korunumu", "Verim ve Enerji Kaynakları", "Isı ve Sıcaklık Kavramları, Termometreler",
        "Isı Alışverişi", "Hal Değişimi", "Isıl Denge",
        "Enerji İletim Yolları", "Genleşme", "Elektrik Yüklerinin Özellikleri ve Elektrikle Yüklenme Çeşitleri",
        "İletken ve Yalıtkanlarda Yük Dağılımı", "Elektriksel Kuvvet ve Elektrik Alan", "Elektrik Akımı ve Direnç",
        "Ohm Yasası ve Dirençlerin Bağlanması", "Üreteçler", "Elektrik Enerjisi, Elektriksel Güç ve Lamba Parlaklıkları",
        "Mıknatıslar ve Manyetik Alan", "Akım ve Manyetik Alan", "Basınç Kavramı, Katılarda Basınç ve Basınç Kuvveti",
        "Durgun Sıvılarda Basınç ve Basınç Kuvveti, Pascal Prensibi", "Gaz Basıncı, Atmosfer Basıncı ve Basınç Ölçen Aletler", "Akışkan Basıncı (Bernoulli İlkesi)",
        "Kaldırma Kuvveti", "Dalgalarda Temel Kavramlar ve Özellikleri", "Yay Dalgalarının Hızı ve Yansıması",
        "Yay Dalgalarının Farklı Ortamlara Geçişi ve Yay Dalgalarının Girişimi", "Su Dalgalarının Özellikleri ve Yansıması", "Su Dalgalarının Hızı ve Kırılması",
        "Ses Dalgaları", "Deprem Dalgaları", "Işık, Işık Şiddeti, Işık Akısı ve Aydınlanma Şiddeti",
        "Gölge", "Işığın Yansıması ve Düzlem Aynalar", "Küresel Aynaların Özellikleri ve Küresel Aynalarda Özel Işınlar",
        "Küresel Aynalarda Görüntü Oluşumu", "Işığın Kırılması", "Tam Yansıma, Sınır Açısı ve Görünür Uzaklık",
        "Merceklerin Özellikleri ve Merceklerde Özel Işınlar", "Merceklerde Görüntü Oluşumu", "Işık Prizmaları",
        "Renk",
      ],
      "Kimya": [
        "Simyadan Kimyaya", "Kimya Disiplinleri ve Kimyacıların Çalışma Alanları", "Kimyanın Sembolik Dili",
        "Kimya Uygulamalarında İş Sağlığı ve Güvenliği", "Atom Modelleri", "Atomun Yapısı",
        "Elementlerin Periyodik Sistemdeki Yerleşim Esasları", "Elementlerin Sınıflandırılması", "Periyodik Özelliklerin Değişme Eğilimleri",
        "Kimyasal Tür ve Kimyasal Türler Arası Etkileşimlerin Sınıflandırılması", "Güçlü Etkileşimler", "Zayıf Etkileşimler",
        "Fiziksel ve Kimyasal Değişimler", "Maddenin Fiziksel Hâlleri", "Katılar ve Sıvılar",
        "Gazlar ve Plazma", "Kimyanın Temel Kanunları", "Mol Kavramı",
        "Kimyasal Tepkimeler ve Denklemler", "Kimyasal Tepkimelerde Hesaplamalar", "Homojen-Heterojen Karışımlar (I)",
        "Homojen-Heterojen Karışımlar (II)", "Ayırma ve Saflaştırma Teknikleri", "Asitlerin ve Bazların Özellikleri",
        "Asitlerin ve Bazların Tepkimeleri", "Asitler ve Bazlar - Tuzlar", "Yaygın Günlük Hayat Kimyasalları",
        "Kozmetikler-İlaçlar-Gıdalar", "Su ve Hayat", "Çevre Kimyası",
      ],
      "Biyoloji": [
        "Canlıların Ortak Özellikleri", "İnorganik Bileşiklerin Genel Özellikleri ve Canlılar İçin Önemi", "Organik Bileşiklerin Genel Özellikleri, Karbonhidratlar",
        "Lipitler", "Proteinler", "Enzimler",
        "Vitaminler ve Hormonlar", "Nükleik Asitler", "ATP (Adenozin trifosfat)",
        "Sağlıklı Beslenme", "Hücre Teorisi, Prokaryot ve Ökaryot Hücre Yapısı", "Hücre Zarı, Hücre Duvarı, Sitoplazma, Çekirdek",
        "Ribozom, Endoplazmik Retikulum, Golgi Aygıtı, Lizozom, Koful", "Peroksizom, Sentrozom, Hücre İskeleti", "Mitokondri ve Plastitler",
        "Hücre Zarından Madde Geçişleri, Basit Difüzyon, Kolaylaştırılmış Difüzyon", "Osmoz", "Aktif Taşıma",
        "Endositoz, Ekzositoz", "Bilimsel Yöntem ve Basamakları", "Canlıların Sınıflandırılmasının Amacı ve Önemi, Sınıflandırmada Kullanılan Kategoriler",
        "Bakteriler Âlemi, Arkeler Âlemi", "Protista Âlemi", "Bitkiler Âlemi",
        "Mantarlar Âlemi", "Hayvanlar Âlemi-Omurgasız Hayvanlar", "Hayvanlar Âlemi-Omurgalı Hayvanlar",
        "Virüsler", "Hücre Bölünmesinin Gerekliliği, Hücre Döngüsü ve İnterfaz", "Mitozun Genel Özellikleri ve Evreleri",
        "Hücre Döngüsünün Kontrolü", "Eşeysiz Üremenin Genel Özellikleri ve Çeşitleri", "Mayozun Genel Özellikleri ve Evreleri",
        "Eşeyli Üremenin Genel Özellikleri ve Örnekleri", "Kalıtımla İlgili Kavramlar, Olasılık İlkeleri ve Gamet Çeşitlerinin Bulunması", "Mendel İlkeleri ve Çaprazlamalar",
        "Eş Baskınlık, Çok Alellilik, Kan Gruplarının Kalıtımı", "Eşeye Bağlı Kalıtım, Akraba Evliliği", "Soyağacı Analizi ve Örnekleri",
        "Genetik Varyasyonların Kaynakları ve Biyolojik Çeşitlilik", "Ekolojik Kavramlar, Ekosistemin Canlı ve Cansız Bileşenleri", "Canlılardaki Beslenme Şekilleri",
        "Ekosistemde Madde ve Enerji Akışı", "Madde Döngüleri", "Güncel Çevre Sorunlarının Sebepleri, Hava Kirliliği, Asit Yağmurları, Küresel İklim Değişikliği",
        "Su Kirliliği, Toprak Kirliliği, Radyoaktif Kirlilik, Ses Kirliliği", "Erozyon, Doğal Hayat Alanlarının Tahribi ve Orman Yangınları, Biyolojik Çeşitliliğin Azalması", "Çevre Sorunlarının Ortaya Çıkmasında Bireylerin Rolü ve Çözüm Önerileri",
        "Doğal Kaynakların Sürdürülebilirliğinin Önemi", "Biyolojik Çeşitliliğin Yaşam İçin Önemi ve Korunması",
      ],
      "Tarih": [
        "İnsanlığın Hafızası Tarih", "Zamanın Taksimi", "Avrasya'da İlk Türk İzleri, Coğrafya ile Oluşan Yaşam Tarzı",
        "Boylardan Devlete-I", "Boylardan Devlete-II", "Kavimler Göçü",
        "İslamiyet'in Doğduğu Dönemde Dünya, İslamiyet Yayılıyor", "Emeviler", "Abbasi Devleti ve Türkler-Bilim Medeniyeti",
        "Türklerin İslamiyet'i Kabulü", "İslamiyet'in Türk Devlet ve Toplum Yapısına Etkisi", "Büyük Selçuklu Devleti",
        "Türklerin Anadolu'ya Yerleşme Süreci", "Anadolu'nun İlk Türk Siyasi Teşekkülleri", "Hilal ve Haç Mücadelesi",
        "Moğol İstilası ve Anadolu", "Osmanlı Beyliği'nin Kuruluşu ve İlk Fetihleri", "Osmanlı Devleti'nin Rumeli'deki İskân ve İstimâlet Politikası",
        "Anadolu'da Türk Siyasi Birliğini Sağlama Çabaları", "Devletleşme Sürecinde Savaşçılar ve Askerler", "Beylikten Devlete Osmanlı Medeniyeti",
        "İstanbul'un Fethi ve Fethin Sonuçları", "Türk İslam Dünyasında Birliği Sağlama Çabaları", "Dünyanın Muhteşem Gücü Osmanlı",
        "Stratejik Siyaset ve Dünya Gücü Olan Osmanlı Devleti", "Saray ve Şehir Kültürü, Gelenekler Işığında Devlet İdaresi", "Osmanlı Devleti'nde Millet Sistemi, Fethettiği Yerlerdeki Kültürel Değişim",
        "Osmanlı Toprak Sistemi, Lonca Teşkilatı, Vakıflar", "Uzun Savaşlardan Diplomasiye", "Okyanusların Önem Kazanması ve Sömürgecilik Faaliyetleri",
        "Fetihlerden Savunmaya", "Avrupa'da Değişim Çağı", "Osmanlı Devleti'nde Değişim",
        "Osmanlı Devleti'nde İsyanlar ve Düzeni Koruma Çabaları", "İhtilaller Çağı, Sömürgeciliğin Küresel Etkileri", "Osmanlı Devleti'nde Modern Orduya Geçiş",
        "XIX. Yüzyılda Sosyal Hayattaki Değişimler", "Osmanlı Devleti'ne Yönelik Tehditler-I", "Osmanlı Devleti'nde Demokratikleşme Hareketleri",
        "Osmanlı Devleti'nde Darbeler", "Osmanlı Devletine Yönelik Tehditler-II", "Osmanlı Devleti'nde Sanayileşme Çabaları",
        "XIX ve XX. Yüzyılda Osmanlı Nüfusu, Metropoller, Salgınlar ve Kamuoyu", "Mustafa Kemal'in Lider Olarak Yetişmesinde Etkili Koşullar", "20. Yüzyıl Başlarında Osmanlı Devleti",
        "I. Dünya Savaşı Sürecinde Osmanlı Devleti", "I. Dünya Savaşı'nın Sonuçları", "Millî Mücadele'ye Hazırlık Dönemi-I",
        "Büyük Millet Meclisinin Açılması-Sevr Antlaşması", "Doğu, Güney ve Batı Cepheleri", "Millî Mücadele'nin Sona Ermesi ve Lozan Barış Antlaşması",
        "Millî Mücadele'ye Hazırlık Dönemi-II", "Atatürk İlkeleri, Siyasi ve Hukuk Alanındaki Gelişmeler", "Atatürk Dönemi'nde Yapılan İnkılaplar",
      ],
      "Coğrafya": [
        "Doğa ve İnsan Etkileşimi", "Coğrafyanın Konusu ve Bölümleri", "Dünya'nın Şekli ve Günlük Hareketi",
        "Dünya'nın Yıllık Hareketi ve Eksen Eğikliği", "Koordinat Sistemi", "Yerel Saat ve Ulusal Saat",
        "Türkiye'nin Konumu", "Harita Unsurları ve Harita Çeşitleri", "Haritalarda Hesaplamalar",
        "Yeryüzü Şekillerinin Haritalara Aktarılması", "Atmosfer, Hava Durumu ve İklim", "Sıcaklık",
        "Basınç ve Rüzgârlar", "Nem ve Yağış", "İklim Tipleri",
        "Türkiye İklimi", "Dünya'nın Tektonik Oluşumu ve Jeolojik Zamanlar", "İç Kuvvetler ve Kayaçlar",
        "Dış Kuvvetler (Çözülme, Kütle Hareketleri, Rüzgârlar, Buzullar)", "Dış Kuvvetler (Akarsular)", "Dış Kuvvetler (Karstik Şekiller, Dalgalar, Akıntılar)",
        "Türkiye'de Ana Yer Şekilleri, İç ve Dış Kuvvetler", "Dünyada Su Kaynakları", "Türkiye'de Su Kaynakları",
        "Dünyada ve Türkiye'de Topraklar", "Dünyada ve Türkiye'de Bitkiler", "Yerleşme ve Türkiye'de Yerleşmeler",
        "Nüfusun Özellikleri ve Gelişimi", "Nüfusun Dağılışı ve Nüfus Piramitleri", "Türkiye Nüfusu",
        "Göçler", "Ekonomik Faaliyetler", "Uluslararası Ulaşım Hatları",
        "Bölge Sınıflandırılması ve Türleri", "Doğal Çevrenin Kullanımı", "Afetlerin Genel Özellikleri ve Sınıflandırılması",
        "Deprem, Tsunami ve Volkanik Faaliyetler, Kütle Hareketleri, Erozyon", "Şiddetli Rüzgârlar, Sel ve Taşkın, Çığ, Orman Yangınları, Salgın Hastalıklar",
      ],
      "Felsefe": [
        "Felsefenin Anlamı", "Felsefi Düşüncenin Ortaya Çıkışı ve Özellikleri - Felsefe Sorusu Nedir?", "Felsefenin İnsan ve Toplum Hayatı Üzerindeki Rolü",
        "Düşünme ve Akıl Yürütmeye İlişkin Kavramlar", "Düşünme ve Dil İlişkisi - Felsefi Bir Görüşü veya Argümanı Sorgulama", "Felsefi Okuma ve Yazma",
        "Varlık Felsefesinin Konusu ve Problemleri", "Varlık Felsefesi Alanındaki Çağdaş Yaklaşımlar", "Evrende Amaçlılık ve Düzenlilik-Varlık Türlerinin Sınıflandırılması-Bir konunun Varlık Felsefesi Açısından Değerlendirilmesi",
        "Bilgi Felsefesinin Konusu ve Bilginin İmkânı Problemi", "Bilginin Kaynağı İle İlgili Görüşler", "Bilginin Sınırları-Doğru Bilginin Ölçütü-Doğruluk ve Gerçeklik-Bilginin Değeri ve Güvenirliği",
        "Bilim Felsefesinin Konusu ve Problemleri", "Bilimin Değeri-Bilim Felsefe İlişkisi-Bilim ve Hayat İlişkisi", "Ahlak Felsefesinin Konusu ve Problemleri-İyi ve Kötünün Ölçütü",
        "Özgürlük ve Sorumluluk", "Evrensel Bir Ahlak Yasasını Kabul Eden Görüşler", "Evrensel Bir Ahlak Yasasını Reddeden Görüşler ve Filozoflar",
        "İyilik ve Mutluluk İlişkisi-Özgürlük, Sorumluluk ve Kural İlişkisi", "Din Felsefesinin Konusu ve Soruları Tanrı'nın Varlığı İle İlgili Görüşler", "Din Felsefesinin Soruları-Teoloji ve Din Felsefesi-Felsefe, Bilim ve Din Açısından Ben Kimim?",
        "Siyaset Felsefesinin Konusu ve Problemleri-Hak, Adalet, Özgürlük-İktidarın Kaynağı", "İdeal Devlet Düzenine Yönelik Görüşler-Ütopya", "Egemenlik Sorunu-Toplumsal Sorunlara Felsefi Bakış",
        "Sanat Felsefesinin Konusu ve Problemleri-Güzellik-Sanat Nedir?", "Sanat Kuramları-Sanat Eserinin Özellikleri-Sanat ve Duyarlılık-Şehir, İnsan ve Sanat", "İlk Medeniyetlerin Felsefenin Doğuşuna Etkisi-Anadolu'da Yaşamış Filozoflar",
        "İlk Neden (Arkhe) ve Değişim Problemi", "Sofistler ile Sokrates'in Bilgi ve Değer Anlayışları", "Platon'un Varlık, Bilgi ve Değer Anlayışı",
        "Aristoteles'in Varlık, Bilgi ve Değer Anlayışı", "Görüş Analizi: Konfüçyüs, Sokrates, Platon ve Aristoteles", "MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesinin Ortaya Çıkışı-Hristiyan Felsefesinin Özellikleri ve Problemleri",
        "İslam Felsefesinin Özellikleri ve Problemleri", "İnanç-Akıl İlişkisi - Çeviri Faaliyetleri", "Görüş Analizi (Augustinus, Fârâbî, İbn Sina, Gâzâlî ve İbn Rüşd)-Tasavvuf Düşüncesi",
        "15. Yüzyıl-17. Yüzyıl Felsefesinin Ortaya Çıkışı", "15. Yüzyıl-17. Yüzyıl Felsefesinde Öne Çıkan Görüşler", "Bilimsel Çalışmaların 15. Yüzyıl-17. Yüzyıl Felsefesine Etkisi",
        "Görüş Analizi: R. Descartes, B. Spinoza ve T. Hobbes", "18. Yüzyıl-19. Yüzyıl Felsefesinin Ortaya Çıkışı-Genel Özellikleri - Dil ve Edebiyatla İlişkisi", "18. Yüzyıl-19. Yüzyıl Felsefesinin Öne Çıkan Problemleri-1",
        "18. Yüzyıl-19. Yüzyıl Felsefesinin Öne Çıkan Problemleri-2", "Görüş Analizi: J. Locke, I. Kant ve F. Hegel", "20. Yüzyıl Felsefesinin Ortaya Çıkışı",
        "20. Yüzyıl Felsefesi: Fenomenoloji, Hermeneutik, Varoluşçuluk", "20. Yüzyıl Felsefesi: Diyalektik Materyalizm, Mantıksal Pozitivizm, Yeni Ontoloji", "Türkiye'de Felsefi Düşünceye Katkıda Bulunan Felsefeciler-Çağımızın Felsefecileri-Yaşadıkları Yerler",
        "Görüş Analizi: F. Nietzsche, H. Bergson, J. P. Sartre ve T. Kuhn", "N. Topçu, T. Mengüşoğlu ve K. Popper'ın Görüşlerinin Tartışılması",
      ],
      "Din Kültürü": [
        "İslam'da Bilgi Kaynakları", "İslam İnancında İmanın Mahiyeti", "Kur'an'dan Mesajlar: İsrâ Suresi 36. Ayet ve Mülk Suresi 23. Ayet",
        "Dinin Tanımı ve Kaynağı", "İnsanın Doğası ve Din", "İman ve İslam İlişkisi",
        "İslam İnanç Esaslarının Özellikleri", "Kur'an'dan Mesajlar: Nisâ Suresi 136. Ayet", "Allah İnancı ve İnsan",
        "Allah'ın Varlığı ve Birliği", "Allah'ın İsim ve Sıfatları", "Kur'an-ı Kerim'de İnsan ve Özellikleri",
        "İnsanın Allah İle İrtibatı", "Kur'an'dan Mesajlar: Rûm Suresi 18-27. Ayetler", "Dini Yorum Farklılıklarının Sebepleri",
        "Dini Yorumlarla İlgili Bazı Kavramlar", "İslam Düşüncesinde İtikadi ve Siyasi Yorumlar", "İslam Düşüncesinde Fıkhi Yorumlar",
        "Kur'an'dan Mesajlar: Nisâ Suresi 59. Ayet", "İslam'da İbadet ve Kapsamı", "İslam'da İbadetin Amacı ve Önemi",
        "İslam'da İbadet Yükümlülüğü", "İslam'da İbadetlerin Temel İlkeleri", "İslam'da İbadet Ahlak İlişkisi",
        "Kur'an'dan Mesajlar: Bakara Suresi 177. Ayet", "İslam Ahlakının Konusu ve Gayesi - İslam Ahlakının Kaynakları", "Ahlak ve Terbiye İlişkisi",
        "İslam Ahlakında Yerilen Bazı Davranışlar", "Tutum ve Davranışlarda Ölçülü Olmak", "Kur'an'dan Mesajlar: Hucurât Suresi 11-12. Ayetler",
        "Din ve Aile", "Din, Kültür ve Sanat", "Din ve Çevre",
        "Din ve Sosyal Değişim", "Din ve Ekonomi", "Din ve Sosyal Adalet",
        "Kur'an'dan Mesajlar: Âl-i İmrân Suresi 103-105. Ayetler", "Değerler ve Değerlerin Kaynağı", "Gençlerin Kişilik Gelişiminde Değerlerin Yeri ve Önemi",
        "Temel Değerler", "Kur'an'dan Mesajlar: İsrâ Suresi 23-29. Ayetler", "İslam Medeniyeti ve Özellikleri",
        "İslam Medeniyetinin Farklı Coğrafyalardaki İzleri", "Kur'an'dan Mesajlar: Hucurât Suresi 13. Ayet", "Kur'an-ı Kerim'de Gençler",
        "Bir Genç Olarak Hz. Muhammed", "Hz. Muhammed ve Gençler", "Bazı Genç Sahabiler",
        "Kur'an'dan Mesajlar: Âl-i İmrân Suresi 159. Ayet",
      ],
    },
    AYT: {
      "Matematik": [
        "Yönlü Açılar", "Trigonometrik Fonksiyonlar",
        "Toplam-Fark ve İki Kat Açı Formülleri", "Trigonometrik Denklemler",
        "Fonksiyonların Grafik ve Problemleri",
        "İkinci Dereceden Fonksiyonlar ve Grafikleri",
        "Fonksiyonların Dönüşümleri",
        "İkinci Dereceden İki Bilinmeyenli Denklem Sistemleri",
        "İkinci Dereceden Eşitsizlikler",
        "Üstel Fonksiyon", "Logaritma Fonksiyonu",
        "Üstel ve Logaritmik Denklem ve Eşitsizlikler",
        "Diziler", "Limit ve Süreklilik", "Türev", "Türev Uygulamaları",
        "Belirsiz İntegral", "Belirli İntegral ve Alan Hesabı",
        "Koşullu Olasılık", "Deneysel ve Teorik Olasılık",
      ],
      "Geometri": [
        "Doğrunun Analitik İncelenmesi", "Çemberin Analitik İncelenmesi",
        "Analitik Düzlemde Temel Dönüşümler", "Çemberde Temel Kavramlar",
        "Çemberde Açılar", "Çemberde Teğet", "Dairenin Çevresi ve Alanı",
        "Katı Cisimler (Küre, Silindir, Koni)",
      ],
      "Fizik": [
        "Vektörler", "Bağıl Hareket", "Newton'un Hareket Yasaları",
        "Bir Boyutta Sabit İvmeli Hareket", "İki Boyutta Hareket (Atışlar)",
        "İş ve Enerji", "İtme ve Momentum", "Tork", "Denge", "Basit Makineler",
        "Elektriksel Kuvvet ve Alan", "Elektriksel Potansiyel", "Kondansatörler",
        "Manyetizma ve İndüksiyon", "Alternatif Akım", "Transformatörler",
        "Düzgün Çembersel Hareket", "Dönme Hareketi", "Açısal Momentum",
        "Kütle Çekimi", "Kepler Kanunları", "Basit Harmonik Hareket",
        "Su Dalgalarında Kırınım ve Girişim", "Elektromanyetik Dalgalar",
        "Atom Modelleri", "Büyük Patlama", "Radyoaktivite", "Özel Görelilik",
        "Siyah Cisim Işıması", "Fotoelektrik Olay", "Compton Olayı",
        "Görüntüleme Teknolojileri", "Yarı İletkenler", "Süper İletkenler",
        "Nanoteknoloji", "LASER",
      ],
      "Kimya": [
        "Atomun Kuantum Modeli", "Elektron Dizilimi", "Periyodik Özellikler",
        "Elementlerin Sınıflandırılması", "Yükseltgenme Basamakları",
        "Gazların Özellikleri", "Gaz Yasaları", "Kinetik Teori",
        "Kısmi Basınçlar", "Gerçek Gazlar", "Çözücü-Çözünen Etkileşimleri",
        "Derişim", "Koligatif Özellikler", "Çözünürlük",
        "Çözünürlüğe Etki Eden Faktörler", "Tepkime Entalpisi",
        "Oluşum Entalpisi", "Bağ Enerjileri", "Hess Yasası", "Tepkime Hızı",
        "Hıza Etki Eden Faktörler", "Kimyasal Denge",
        "Dengeyi Etkileyen Faktörler", "Asit-Baz Dengesi (pH-pOH)",
        "Redoks Tepkimeleri", "Elektrokimyasal Hücreler", "İstemlilik",
        "Galvanik Piller", "Elektroliz", "Korozyon",
        "Organik ve Anorganik Bileşikler", "Basit ve Molekül Formülleri",
        "Karbon Allotropları", "Lewis Formülleri", "Hibritleşme",
        "Hidrokarbonlar", "Fonksiyonel Gruplar", "Alkoller", "Eterler",
        "Karbonil Bileşikleri (Aldehit-Keton)", "Karboksilik Asitler",
        "Esterler", "Fosil Yakıtlar", "Alternatif Enerji Kaynakları",
        "Sürdürülebilirlik", "Nanoteknoloji",
      ],
      "Biyoloji": [
        "Sinir Sistemi", "Destek ve Hareket Sistemi", "Sindirim Sistemi",
        "Dolaşım Sistemi", "Solunum Sistemi", "Üriner Sistem (Boşaltım)",
        "Üreme Sistemi", "Komünite Ekolojisi", "Popülasyon Ekolojisi",
        "Nükleik Asitler", "Protein Sentezi", "Canlılık ve Enerji (ATP)",
        "Fotosentez", "Kemosentez", "Hücresel Solunum", "Bitkilerin Yapısı",
        "Bitkilerde Taşıma ve Beslenme", "Bitkilerde Üreme", "Canlılar ve Çevre",
      ],
      "Edebiyat": [
        "Edebiyata Giriş", "Şiir Bilgisi", "Edebî Sanatlar", "Edebî Akımlar",
        "İslamiyet Öncesi Türk Şiiri", "Geçiş Dönemi Türk Şiiri", "Halk Şiiri",
        "Divan Şiiri", "Tanzimat Dönemi Türk Şiiri",
        "Servetifünun Dönemi Türk Şiiri", "Fecriati Dönemi Türk Şiiri",
        "Millî Edebiyat Dönemi Türk Şiiri", "Cumhuriyet Dönemi Türk Şiiri",
        "Hikâye Türleri ve Hikâyenin Yapı Unsurları",
        "Tanzimat Dönemi'ne Kadar Halk Hikâyesi ve Mesneviler",
        "Tanzimat ve Servetifünun Dönemi Türk Hikâyesi",
        "Millî Edebiyat Dönemi Türk Hikâyesi", "Cumhuriyet Dönemi Türk Hikâyesi",
        "Roman Türü ve Yapı Unsurları", "Tanzimat Dönemi Türk Romanı",
        "Servetifünun Dönemi Türk Romanı", "Millî Edebiyat Dönemi Türk Romanı",
        "Cumhuriyet Dönemi Türk Romanı", "Dünya Edebiyatında Roman",
        "Tiyatro Türü ve Yapı Unsurları", "Geleneksel Türk Tiyatrosu",
        "Tanzimat, Servetifünun ve Millî Edebiyat Dönemi Türk Tiyatrosu",
        "Cumhuriyet Dönemi Türk Tiyatrosu", "Masal/Fabl", "Destan/Efsane",
        "Öğretici Metinler", "Divan Edebiyatı Nesir Türleri",
      ],
      "Tarih": [
        "İnsanlığın Hafızası Tarih", "Zamanın Taksimi", "Avrasya'da İlk Türk İzleri, Coğrafya ile Oluşan Yaşam Tarzı",
        "Boylardan Devlete-I", "Boylardan Devlete-II", "Kavimler Göçü",
        "İslamiyet'in Doğduğu Dönemde Dünya, İslamiyet Yayılıyor", "Emeviler", "Abbasi Devleti ve Türkler-Bilim Medeniyeti",
        "Türklerin İslamiyet'i Kabulü", "İslamiyet'in Türk Devlet ve Toplum Yapısına Etkisi", "Büyük Selçuklu Devleti",
        "Türklerin Anadolu'ya Yerleşme Süreci", "Anadolu'nun İlk Türk Siyasi Teşekkülleri", "Hilal ve Haç Mücadelesi",
        "Moğol İstilası ve Anadolu", "Osmanlı Beyliği'nin Kuruluşu ve İlk Fetihleri", "Osmanlı Devleti'nin Rumeli'deki İskân ve İstimâlet Politikası",
        "Anadolu'da Türk Siyasi Birliğini Sağlama Çabaları", "Devletleşme Sürecinde Savaşçılar ve Askerler", "Beylikten Devlete Osmanlı Medeniyeti",
        "İstanbul'un Fethi ve Fethin Sonuçları", "Türk İslam Dünyasında Birliği Sağlama Çabaları", "Dünyanın Muhteşem Gücü Osmanlı",
        "Stratejik Siyaset ve Dünya Gücü Olan Osmanlı Devleti", "Saray ve Şehir Kültürü, Gelenekler Işığında Devlet İdaresi", "Osmanlı Devleti'nde Millet Sistemi, Fethettiği Yerlerdeki Kültürel Değişim",
        "Osmanlı Toprak Sistemi, Lonca Teşkilatı, Vakıflar", "Uzun Savaşlardan Diplomasiye", "Okyanusların Önem Kazanması ve Sömürgecilik Faaliyetleri",
        "Fetihlerden Savunmaya", "Avrupa'da Değişim Çağı", "Osmanlı Devleti'nde Değişim",
        "Osmanlı Devleti'nde İsyanlar ve Düzeni Koruma Çabaları", "İhtilaller Çağı, Sömürgeciliğin Küresel Etkileri", "Osmanlı Devleti'nde Modern Orduya Geçiş",
        "XIX. Yüzyılda Sosyal Hayattaki Değişimler", "Osmanlı Devleti'ne Yönelik Tehditler-I", "Osmanlı Devleti'nde Demokratikleşme Hareketleri",
        "Osmanlı Devleti'nde Darbeler", "Osmanlı Devletine Yönelik Tehditler-II", "Osmanlı Devleti'nde Sanayileşme Çabaları",
        "XIX ve XX. Yüzyılda Osmanlı Nüfusu, Metropoller, Salgınlar ve Kamuoyu", "Mustafa Kemal'in Lider Olarak Yetişmesinde Etkili Koşullar", "20. Yüzyıl Başlarında Osmanlı Devleti",
        "I. Dünya Savaşı Sürecinde Osmanlı Devleti", "I. Dünya Savaşı'nın Sonuçları", "Millî Mücadele'ye Hazırlık Dönemi-I",
        "Büyük Millet Meclisinin Açılması-Sevr Antlaşması", "Doğu, Güney ve Batı Cepheleri", "Millî Mücadele'nin Sona Ermesi ve Lozan Barış Antlaşması",
        "Millî Mücadele'ye Hazırlık Dönemi-II", "Atatürk İlkeleri, Siyasi ve Hukuk Alanındaki Gelişmeler", "Atatürk Dönemi'nde Yapılan İnkılaplar",
        "Atatürk Dönemi İç Politikadaki Gelişmeler", "İki Dünya Savaşı Arasındaki Dönemde Dünya", "Atatürk Dönemi Türk Dış Politikası",
        "II. Dünya Savaşı Sürecinde Türkiye ve Savaşı'nın Sonuçları", "II. Dünya Savaşı Sonrası Gelişmeler", "1960 Sonrası Dünyada Yaşanan Siyasi Gelişmeler",
        "1960 Sonrasında Türk Dış Politikası", "Türkiye'deki Siyasi, Ekonomik, Sosyokültürel Hayat", "1990 Sonrasında Türkiye",
        "1990 Sonrasında Meydana Gelen Siyasi Gelişmelerin Türkiye'ye Etkileri",

      
      ],
      "Coğrafya": [
        "Biyoçeşitlilik ve Biyomlar", "Ekosistemler ve Madde Döngüleri", "Nüfus Politikaları ve Türkiye Nüfusunun Geleceği",
        "Yerleşme Özellikleri ve Şehirler", "Üretim, Dağıtım ve Tüketim", "Doğal Kaynaklar ve Ekonomi",
        "Türkiye\x27nin Ekonomi Politikaları ve Tarımı Etkileyen Faktörler", "Türkiye\x27de Tarım Ürünleri", "Türkiye\x27de Ormancılık ve Hayvancılık",
        "Türkiye\x27de Madencilik ve Enerji Kaynakları", "Türkiye\x27de Sanayi", "İlk Kültür Merkezleri ve Kültür Bölgeleri",
        "Türk Kültürü ve Anadolu\x27nun Kültürel Özellikleri", "Küresel Ticaret", "Turizm",
        "Ülkelerin Sanayileşme Süreci ve Tarım-Ekonomi İlişkisi", "Uluslararası Örgütler", "Çevre Sorunları ve Türleri",
        "Doğal Kaynaklar, Madenler ve Enerji Kaynakları Kullanımının Çevresel Etkileri", "Arazi Kullanımı, Küresel Çevre Sorunları ve Geri Dönüşüm", "Ekstrem Doğa Olayları",
        "Doğa Olaylarının Geleceği", "Geçmişten Geleceğe Şehir ve Ekonomi", "Geleceğin Dünyası",
        "Türkiye\x27nin İşlevsel Bölgeleri", "Türkiye\x27nin Bölgesel Kalkınma Projeleri", "Hizmet Sektörü ve Ulaşım",
        "Dünyada ve Türkiye\x27de Ticaret", "Türkiye Turizmi", "Ülkelerin Konumunun Etkileri ve Türkiye\x27nin Jeopolitik Konumu",
        "Ülkelerin Gelişmişliği", "Enerji Nakil Hatları", "Çatışma Bölgeleri",
        "Doğal Çevrenin Sınırlılığı, Çevresel Örgüt ve Anlaşmalar",

      ],
      "Felsefe Grubu": [
        "İlk Çağ Felsefesi", "Ortaçağ Felsefesi", "Yeni Çağ Felsefesi",
        "19. Yüzyıl Felsefesi", "20. Yüzyıl Felsefesi", "Psikolojiye Giriş",
        "Öğrenme-Bellek-Düşünme", "Kişilik ve Ruh Sağlığı",
        "Sosyoloji: Toplum ve Kültür", "Sosyoloji: Toplumsal Kurumlar",
        "Sosyoloji: Toplumsal Değişme ve Küreselleşme", "Klasik Mantık",
        "Önermeler ve Çıkarım", "Sembolik Mantık",
      ],
      "Din Kültürü": [
        "Dünya ve Ahiret", "Kur'an'a Göre Hz. Muhammed", "Kur'an'da Kavramlar",
        "İnançla İlgili Meseleler", "Yahudilik ve Hristiyanlık", "İslam ve Bilim",
        "Anadolu'da İslam", "Tasavvufi Yorumlar", "Güncel Dinî Meseleler",
        "Hint ve Çin Dinleri",
      ],
    },
  },
  maarif: {
    TYT: {
      "Türkçe": [
        "Şiir", "Öyküleyici Metin", "Tiyatro", "Öğretici Metin", "Ses Bilgisi",
        "Yapı Bilgisi (Ekler)", "İsim ve Sıfat", "Zamir-Zarf-Edat",
        "Fiil ve Fiilimsi", "Cümlenin Ögeleri", "Anlatım Bozuklukları",
      ],
      "Matematik": [
        "Üslü İfadeler", "Köklü İfadeler", "Sayı Kümeleri",
        "Özdeşlikler (İki Kare Farkı-Tam Kare)", "Doğrusal Fonksiyonlar",
        "Mutlak Değer", "Denklem-Eşitsizlik", "Mantıksal Çıkarım",
        "Algoritma ve Bilişim", "Fonksiyonlar ve Denklemler",
        "Trigonometriye Giriş", "Veriden Olasılığa",
      ],
      // Geometri, Maarif'te matematik programının içinde geçse de uygulamada
      // AYRI DERS olarak tutulur (eski müfredatla tutarlı olsun diye).
      "Geometri": [
        "Üçgende Eşlik ve Benzerlik", "Çokgenler", "Dörtgenler", "Çember",
        "Analitik Geometriye Giriş",
      ],
      "Fizik": [
        "Fizik Bilimi ve Kariyer", "Kuvvet ve Hareket", "Akışkanlar (Basınç)",
        "Akışkanlar (Kaldırma Kuvveti-Bernoulli)", "Enerji (Isı-Hâl Değişimi)",
        "Elektrik", "Dalgalar",
      ],
      "Kimya": [
        "Kimya Hayattır", "Atomdan Periyodik Tabloya",
        "Kimyasal Türler Arası Etkileşimler", "Kimyasal Tepkimeler", "Gazlar",
        "Çözeltiler", "Redoks (Etkileşim)", "Sürdürülebilirlik",
      ],
      "Biyoloji": [
        "Canlıların Ortak Özellikleri", "Üç Âlem/Domain Sistemi", "Hücre",
        "Organik Moleküller", "Fotosentez", "Hücresel Solunum",
        "Ekosistem Ekolojisi",
      ],
      "Tarih": [
        "Geçmişin İnşa Sürecinde Tarih", "Medeniyet/Uygarlık Tarihi",
        "Türkistan'dan Türkiye'ye", "Beylikten Devlete Osmanlı",
        "Cihan Devleti Osmanlı (İstanbul'un Fethi)",
      ],
      "Coğrafya": [
        "Coğrafyanın Doğası", "Mekânsal Bilgi Teknolojileri",
        "Doğal Sistemler ve Süreçler (İklim)", "Beşerî Sistemler ve Süreçler",
        "Ekonomik Faaliyetler ve Etkileri", "Afetler ve Sürdürülebilir Çevre",
        "Bölgesel/Küresel Bağlantılar",
      ],
      "Felsefe": [
        "Felsefeye Giriş", "Felsefe ile Düşünme (Argümantasyon)",
        "Bilgi Felsefesi", "Bilim Felsefesi", "Ahlak Felsefesi",
      ],
      "Din Kültürü": [
        "Allah-İnsan İlişkisi", "İslam'da İnanç Esasları", "İslam'da İbadetler",
        "İslam'da Ahlak İlkeleri", "Kur'an'a Göre Hz. Muhammed",
        "İslam'da Varlık ve Bilgi", "Din, Çevre ve Teknoloji",
      ],
    },
    AYT: {
      "Matematik": [
        "Nicelikler ve Değişimler", "İstatistiksel Araştırma Süreci", "Türev",
        "İntegral", "Logaritma",
      ],
      "Geometri": ["Geometrik Şekiller"],
      "Fizik": [
        "Kuvvet ve Hareket (Newton Yasaları)", "Çembersel Hareket",
        "Elektriksel ve Manyetik Alan", "İndüksiyon ve Transformatörler",
        "Madde ve Doğası (Yarı İletkenler)", "Optik", "Enerji", "Dalgalar",
      ],
      "Kimya": [
        "Kimyasal Tepkimeler ve Enerji", "Tepkime Hızı", "Kimyasal Denge",
        "Asit-Baz Dengeleri", "Sürdürülebilirlik (Yeşil Kimya)",
      ],
      "Biyoloji": [
        "Sinir Sistemi ve Refleks", "İskelet-Kas-Eklem Sistemi",
        "Bağışıklık ve Alerji", "Endokrin Sistem", "Dolaşım Sistemi",
        "Solunum Sistemi", "Boşaltım Sistemi",
        "Denge Bozuklukları (Diyabet-Hipertansiyon-Obezite)",
      ],
      "Edebiyat": [
        "Mektup-Dilekçe-E-posta", "Geleneksel Türk Tiyatrosu",
        "Orhun Abideleri ve Geçiş Dönemi", "Âşık Tarzı Halk Şiiri",
        "Halk Hikâyesi", "Roman", "Biyografi ve Tezkire", "Radyo Tiyatrosu",
        "Modern Türk Tiyatrosu", "Küçürek Hikâye", "Belgesel",
      ],
      "Tarih": [
        "Osmanlı'da Gerileme ve Değişim", "Fransız İhtilali ve Milliyetçilik",
        "Balkan Savaşları", "I. Dünya Savaşı'na Giden Süreç",
      ],
      "Coğrafya": [
        "İleri Nüfus", "İleri Yerleşme", "Ekonomik Coğrafya",
      ],
    },
  },
};

/** Prompt'a gömmek için dersleri ve konuları kompakt metin bloğu olarak üretir. */
export function taxonomyText(curriculum: Curriculum): string {
  const byExam = TAXONOMY[curriculum];
  const lines: string[] = [];
  for (const exam of ["TYT", "AYT"] as Exam[]) {
    lines.push(`${exam}:`);
    const subjects = byExam[exam];
    for (const ders of Object.keys(subjects)) {
      lines.push(`- ${ders}: ${subjects[ders].join("; ")}`);
    }
  }
  return lines.join("\n");
}

/** AI'nın döndürdüğü ders/konu'yu taksonomiye göre doğrular (birebir eşleşme). */
export function isValidPair(
  curriculum: Curriculum,
  exam: string,
  ders: string,
  konu: string,
): boolean {
  const byExam = TAXONOMY[curriculum];
  const subjects = exam === "AYT" ? byExam.AYT : exam === "TYT" ? byExam.TYT : null;
  if (!subjects) {
    // Sınav bilinmiyorsa TYT+AYT birleşiminde ara.
    return hasKonu(byExam.TYT[ders], konu) || hasKonu(byExam.AYT[ders], konu);
  }
  return hasKonu(subjects[ders], konu);
}

function hasKonu(konular: string[] | undefined, konu: string): boolean {
  if (!konular) return false;
  return konular.some((k) => k.toLowerCase() === konu.toLowerCase());
}
