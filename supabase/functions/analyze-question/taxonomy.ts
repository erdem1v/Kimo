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
        "Önermeler ve Bileşik Önermeler", "Kümelerde Temel Kavramlar",
        "Kümelerde İşlemler", "Sayı Kümeleri", "Bölünebilme Kuralları",
        "Birinci Dereceden Denklemler ve Eşitsizlikler",
        "Üslü İfadeler ve Denklemler",
        "Denklemler ve Eşitsizlikler ile İlgili Uygulamalar",
        "Merkezi Eğilim ve Yayılım Ölçüleri", "Verilerin Grafikle Gösterilmesi",
        "Sıralama ve Seçme", "Basit Olayların Olasılıkları",
        "Fonksiyon Kavramı ve Gösterimi",
        "İki Fonksiyonun Bileşkesi ve Bir Fonksiyonun Tersi",
        "Polinom Kavramı ve Polinomlarda İşlemler",
        "Polinomların Çarpanlara Ayrılması",
        "İkinci Dereceden Bir Bilinmeyenli Denklemler",
      ],
      "Geometri": [
        "Üçgenlerde Temel Kavramlar", "Üçgenlerde Eşlik ve Benzerlik",
        "Üçgenin Yardımcı Elemanları", "Dik Üçgen ve Trigonometri",
        "Üçgenin Alanı", "Çokgenler", "Dörtgenler ve Özellikleri",
        "Özel Dörtgenler", "Katı Cisimler",
      ],
      "Fizik": [
        "Fizik Bilimine Giriş", "Madde ve Özellikleri", "Hareket ve Kuvvet",
        "Enerji", "Basınç ve Kaldırma Kuvveti", "Isı ve Sıcaklık",
        "Elektrostatik", "Elektrik ve Manyetizma", "Dalgalar",
        "Optik",

      ],
      "Kimya": [
        "Kimya Bilimi", "Atom ve Periyodik Sistem", "Kimyasal Türler Arası Etkileşimler",
        "Maddenin Hâlleri", "Kimyanın Temel Kanunları ve Kimyasal Hesaplamalar", "Karışımlar",
        "Asitler, Bazlar ve Tuzlar", "Kimya Her Yerde", "Doğa ve Kimya",

      ],
      "Biyoloji": [
        "Canlıların Ortak Özellikleri", "Canlıların Yapısında Bulunan İnorganik Bileşikler", "Canlıların Yapısında Bulunan Organik Bileşikler",
        "Hücresel Yapılar ve Görevleri", "Hücre Zarından Madde Geçişleri", "Hücre Döngüsü ve Mitoz",
        "Eşeysiz Üreme", "Mayoz", "Eşeyli Üreme",
        "Canlıların Sınıflandırılması", "Canlı Âlemleri", "Kalıtım",
        "Genetik Varyasyonlar", "Ekosistem Ekolojisi", "Güncel Çevre Sorunları",
        "Doğal Kaynakların Sürdürülebilirliği", "Biyolojik Çeşitliliğin Korunması",

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
        "Kuvvet ve Hareket", "Çembersel Hareket", "Basit Harmonik Hareket",
        "Elektrik ve Manyetizma", "Dalga Mekaniği", "Atom Fiziğine Giriş ve Radyoaktivite",
        "Modern Fizik", "Modern Fiziğin Teknolojideki Uygulamaları",

      ],
      "Kimya": [
        "Modern Atom Teorisi", "Gazlar", "Sıvı Çözeltiler ve Çözünürlük",
        "Kimyasal Tepkimelerde Enerji", "Kimyasal Tepkimelerde Hız", "Kimyasal Tepkimelerde Denge",
        "Kimya ve Elektrik", "Karbon Kimyasına Giriş", "Organik Bileşikler",
        "Enerji Kaynakları ve Bilimsel Gelişmeler",

      ],
      "Biyoloji": [
        "Sinir Sistemi", "Endokrin Sistem", "İskelet Sistemi",
        "Kas Sistemi", "Duyu Organları", "Kan Dolaşımı",
        "Lenf Dolaşımı", "Sindirim Sistemi", "Solunum Sistemi",
        "Üriner Sistem", "Üreme Sistemi", "Bağışıklık Sistemi",
        "Embriyonik Gelişim", "Komünite Ekolojisi", "Popülasyon Ekolojisi",
        "Nükleik Asitler", "Genetik Şifre ve Protein Sentezi", "Genetik Mühendisliği ve Biyoteknoloji",
        "Canlılık ve Enerji", "Fotosentez", "Kemosentez",
        "Hücresel Solunum", "Fermantasyon", "Bitkisel Dokular",
        "Bitkisel Organlar", "Bitkilerde Madde Taşınması", "Bitkilerde Hareket",
        "Bitki Hormonları", "Bitkilerde Eşeyli Üreme", "Canlılar ve Çevre",

      ],
      "Edebiyat": [
        "Edebiyata Giriş", "Şiir Bilgisi", "Edebî Sanatlar",
        "Edebî Akımlar", "İslamiyet Öncesi Türk Şiiri", "Geçiş Dönemi Türk Şiiri",
        "Halk Şiiri", "Divan Şiiri", "Tanzimat Dönemi Türk Şiiri",
        "Servetifünun Dönemi Türk Şiiri", "Fecriati Dönemi Türk Şiiri", "Millî Edebiyat Dönemi Türk Şiiri",
        "Cumhuriyet Dönemi Türk Şiiri", "Hikâye Türleri ve Hikâyenin Yapı Unsurları", "Tanzimat Dönemi'ne Kadar Halk Hikâyesi ve Mesneviler",
        "Tanzimat ve Servetifünun Dönemi Türk Hikâyesi", "Millî Edebiyat Dönemi Türk Hikâyesi", "Cumhuriyet Dönemi Türk Hikâyesi",
        "Roman Türü ve Yapı Unsurları", "Tanzimat Dönemi Türk Romanı", "Servetifünun Dönemi Türk Romanı",
        "Millî Edebiyat Dönemi Türk Romanı", "Cumhuriyet Dönemi Türk Romanı", "Dünya Edebiyatında Roman",
        "Tiyatro Türü ve Yapı Unsurları", "Geleneksel Türk Tiyatrosu", "Tanzimat, Servetifünun ve Millî Edebiyat Dönemi Türk Tiyatrosu",
        "Cumhuriyet Dönemi Türk Tiyatrosu", "Masal/Fabl", "Destan/Efsane",
        "Öğretici Metinler", "Divan Edebiyatı Nesir Türleri",

      ],
      "Tarih": [
        "Tarih ve Zaman", "İlk ve Orta Çağlarda Türk Dünyası", "İslam Medeniyetinin Doğuşu",
        "Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet'i Kabulü", "Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi", "Beylikten Devlete Osmanlı Siyaseti (1302-1453)",
        "Devletleşme Sürecinde Savaşçılar ve Askerler", "Beylikten Devlete Osmanlı Medeniyeti", "Dünya Gücü Osmanlı (1453-1595)",
        "Sultan ve Osmanlı Merkez Teşkilatı", "Klasik Çağda Osmanlı Toplum Düzeni", "Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774)",
        "Değişim Çağında Avrupa ve Osmanlı", "Uluslararası İlişkilerde Denge Stratejisi (1774-1914)", "Devrimler Çağında Değişen Devlet-Toplum İlişkileri",
        "XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat", "XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya", "Millî Mücadele",
        "Atatürkçülük ve Türk İnkılabı", "İki Savaş Arasındaki Dönemde Türkiye ve Dünya", "II. Dünya Savaşı Sürecinde Türkiye ve Dünya",
        "II. Dünya Savaşı Sonrasında Türkiye ve Dünya", "Toplumsal Devrim Çağında Dünya ve Türkiye", "XXI. Yüzyılın Eşiğinde Türkiye ve Dünya",

      ],
      "Coğrafya": [
        "Ekosistemlerin İşleyişi ve Özellikleri", "Ekstrem Doğa Olayları ve Doğa Olaylarının Geleceği", "Nüfus Politikaları ve Yerleşmeler",
        "Ekonomik Faaliyetler ve Doğal Kaynaklar", "Türkiye'de Ekonomi", "Ekonomi, Şehirleşme ve Göç",
        "Ulaşım, Ticaret, Turizm", "Türkiye'nin İşlevsel Bölgeleri ve Kalkınma Projeleri", "Kültür Bölgeleri",
        "Küreselleşen Dünya", "Jeopolitik Konum ve Ülkeler Arası Etkileşim", "Çevre Sorunları",
        "Doğal Çevrenin Sınırlılığı, Çevresel Örgüt ve Anlaşmalar",

      ],
      "Felsefe Grubu": [
        "Felsefeyi Tanıma", "Felsefe ile Düşünme", "Felsefi Okuma ve Yazma",
        "Varlık Felsefesi", "Bilgi Felsefesi", "Bilim Felsefesi",
        "Ahlak Felsefesi", "Din Felsefesi", "Siyaset Felsefesi",
        "Sanat Felsefesi", "MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi", "MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi",
        "15. Yüzyıl-17. Yüzyıl Felsefesi", "18. Yüzyıl-19. Yüzyıl Felsefesi", "20. Yüzyıl Felsefesi",
        "Mantığa Giriş", "Klasik Mantık", "Mantık ve Dil",
        "Sembolik Mantık", "Psikoloji Bilimini Tanıyalım", "Psikolojinin Temel Süreçleri",
        "Öğrenme, Bellek, Düşünme", "Ruh Sağlığının Temelleri", "Sosyolojiye Giriş",
        "Toplumsal Yapı", "Birey ve Toplum", "Toplum ve Kültür",
        "Toplumsal Kurumlar", "Toplumsal Değişme ve Gelişme",

      ],
      "Din Kültürü": [
        "Dünya ve Ahiret", "İnançla İlgili Meseleler", "Kur'an'a Göre Hz. Muhammed",
        "Kur'an'da Bazı Kavramlar", "Yahudilik ve Hristiyanlık", "Hint ve Çin Dinleri",
        "Anadolu'da İslam", "İslam ve Bilim", "İslam Düşüncesinde Tasavvufi Yorumlar",
        "Güncel Dinî Meseleler",

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
