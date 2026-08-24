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
        "Sözcükte Anlam", "Cümlede Anlam", "Paragrafta Anlam", "Ses Bilgisi",
        "Biçim Bilgisi", "Sözcük Türleri", "Fiiller", "Cümlenin Ögeleri",
        "Cümle Türleri", "Yazım Kuralları", "Noktalama İşaretleri",
        "Anlatım Bozuklukları",
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
        "Tarih ve Zaman", "İlk ve Orta Çağlarda Türk Dünyası",
        "İslam Medeniyetinin Doğuşu",
        "Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet'i Kabulü",
        "Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi",
        "Beylikten Devlete Osmanlı Siyaseti (1302-1453)",
        "Devletleşme Sürecinde Savaşçılar ve Askerler",
        "Beylikten Devlete Osmanlı Medeniyeti", "Dünya Gücü Osmanlı (1453-1595)",
        "Sultan ve Osmanlı Merkez Teşkilatı",
        "Klasik Çağda Osmanlı Toplum Düzeni",
        "Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774)",
        "Değişim Çağında Avrupa ve Osmanlı",
        "Uluslararası İlişkilerde Denge Stratejisi (1774-1914)",
        "Devrimler Çağında Değişen Devlet-Toplum İlişkileri",
        "XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat",
        "XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya", "Millî Mücadele",
        "Atatürkçülük ve Türk İnkılabı",
      ],
      "Coğrafya": [
        "Coğrafya Bilimi, İnsan ve Doğa", "Dünya'nın Şekli ve Hareketleri",
        "Yer ve Zaman, Koordinat Sistemi", "Harita Bilimi", "İklim Bilimi",
        "Dünya'nın Yapısı ve Oluşum Süreci", "Su Kaynakları, Topraklar, Bitkiler",
        "Yerleşmeler", "Nüfus, Göç, Ekonomik Faaliyetler", "Ulaşım",
        "Bölgeler ve Ülkeler", "İnsan ve Çevre", "Afetler",
      ],
      "Felsefe": [
        "Felsefeyi Tanıma", "Felsefe ile Düşünme", "Felsefi Okuma ve Yazma",
        "Varlık Felsefesi", "Bilgi Felsefesi", "Bilim Felsefesi",
        "Ahlak Felsefesi", "Din Felsefesi", "Siyaset Felsefesi", "Sanat Felsefesi",
        "MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi",
        "MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi",
        "15. Yüzyıl-17. Yüzyıl Felsefesi", "18. Yüzyıl-19. Yüzyıl Felsefesi",
        "20. Yüzyıl Felsefesi",
      ],
      "Din Kültürü": [
        "Bilgi ve İnanç", "Din ve İslam", "Allah İnsan İlişkisi",
        "İslam Düşüncesinde İtikadi, Siyasi ve Fıkhi Yorumlar", "İslam ve İbadet",
        "Ahlaki Tutum Davranışlar", "Din ve Hayat", "Gençlik ve Değerler",
        "Gönül Coğrafyamız", "Hz. Muhammed ve Gençlik",
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
        "Edebiyat Bilgisi ve Metin Türleri", "Hikâye", "Şiir Bilgisi",
        "Roman", "Tiyatro",
        "İslamiyet Öncesi Türk Edebiyatı", "Geçiş Dönemi Eserleri",
        "Halk Edebiyatı (Âşık-Anonim)", "Dini-Tasavvufi Halk Edebiyatı",
        "Divan Edebiyatı", "Tanzimat Edebiyatı", "Servet-i Fünun Edebiyatı",
        "Fecr-i Ati", "Millî Edebiyat", "Cumhuriyet Dönemi Şiiri (Garip)",
        "Cumhuriyet Dönemi Şiiri (İkinci Yeni)",
        "Cumhuriyet Dönemi Roman-Hikâye", "Cumhuriyet Dönemi Tiyatro",
        "Öğretici Metinler", "Edebî Akımlar", "Edebî Sanatlar",
        "Şiir Bilgisi (Nazım Biçimleri-Ölçü)",
      ],
      "Tarih": [
        "Değişen Dünya Dengeleri ve Osmanlı Siyaseti (1595-1774)",
        "Değişim Çağında Avrupa ve Osmanlı",
        "Uluslararası İlişkilerde Denge (1774-1914)", "Devrimler Çağı",
        "Sermaye ve Emek", "XIX-XX. Yüzyılda Gündelik Hayat", "Nüfus Politikaları",
        "XX. Yüzyıl Başlarında Osmanlı", "Millî Mücadele",
        "Atatürkçülük ve Türk İnkılabı", "Atatürk İlkeleri", "İki Savaş Arası Dönem",
        "II. Dünya Savaşı", "Soğuk Savaş Dönemi",
        "Toplumsal Devrim Çağında Dünya ve Türkiye",
        "XXI. Yüzyılın Eşiğinde Türkiye ve Dünya",
      ],
      "Coğrafya": [
        "Ekosistem ve Madde Döngüsü", "Nüfus Politikaları", "Göç ve Şehirleşme",
        "Türkiye'de Nüfus ve Yerleşme", "Türkiye'de Tarım", "Türkiye'de Sanayi",
        "Türkiye'de Ticaret-Ulaşım-Turizm", "Bölgesel Kalkınma Projeleri",
        "Doğal Sistemler (Biyoçeşitlilik)", "Beşerî Sistemler",
        "Küresel Ortam: Bölgeler ve Ülkeler", "Çevre ve Toplum",
        "Doğal Afetler ve Toplum",
        "Doğal Kaynaklar", "Türkiye Ekonomisinin Sektörel Dağılımı",
        "Türkiye'de Madenler ve Enerji Kaynakları",
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
