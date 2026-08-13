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
        "Sözcükte Anlam", "Cümlede Anlam", "Paragrafta Anlam", "Paragrafta Yapı",
        "Anlatım Teknikleri", "Ses Bilgisi", "Yazım Kuralları",
        "Noktalama İşaretleri", "Sözcükte Yapı (Ekler)", "İsim (Ad)", "Sıfat",
        "Zamir", "Zarf", "Edat-Bağlaç-Ünlem", "Fiilde Anlam (Kip-Kişi)",
        "Ek Fiil", "Fiilimsi", "Cümlenin Ögeleri", "Cümle Türleri",
        "Anlatım Bozuklukları",
      ],
      "Matematik": [
        "Temel Kavramlar", "Sayı Basamakları", "Bölme-Bölünebilme", "OBEB-OKEK",
        "Rasyonel Sayılar", "Basit Eşitsizlikler", "Mutlak Değer", "Üslü Sayılar",
        "Köklü Sayılar", "Çarpanlara Ayırma", "Oran-Orantı", "Sayı Problemleri",
        "Kesir Problemleri", "Yaş Problemleri", "İşçi-Havuz Problemleri",
        "Hareket Problemleri", "Yüzde Problemleri", "Kâr-Zarar Problemleri",
        "Karışım Problemleri", "Grafik Problemleri", "Kümeler", "Mantık",
        "Fonksiyonlar", "Polinomlar", "İkinci Dereceden Denklemler", "İstatistik",
        "Olasılık",
      ],
      "Geometri": [
        "Doğruda Açılar", "Üçgende Açılar", "Üçgende Açı-Kenar Bağıntıları",
        "Dik Üçgen", "İkizkenar ve Eşkenar Üçgen", "Açıortay", "Kenarortay",
        "Üçgende Alan", "Üçgende Benzerlik", "Çokgenler", "Paralelkenar",
        "Dikdörtgen ve Kare", "Eşkenar Dörtgen", "Yamuk", "Çember ve Daire",
        "Analitik Geometri (Nokta-Doğru)",
      ],
      "Fizik": [
        "Fizik Bilimine Giriş", "Madde ve Özellikleri",
        "Sıvıların Kaldırma Kuvveti", "Basınç", "Isı ve Sıcaklık", "Genleşme",
        "Kuvvet ve Denge (Vektörler)", "Basit Makineler", "Doğrusal Hareket",
        "İş-Güç-Enerji", "Elektrostatik", "Elektrik Akımı ve Devreler",
        "Mıknatıslar ve Manyetik Alan",
        "Işık ve Gölge", "Düzlem Ayna", "Küresel Aynalar", "Kırılma ve Renkler",
        "Mercekler", "Dalgalar (Temel)", "Yay ve Su Dalgaları",
        "Ses ve Deprem Dalgaları",
      ],
      "Kimya": [
        "Kimya Bilimine Giriş", "Atomun Yapısı", "Periyodik Sistem", "İyonik Bağ",
        "Kovalent Bağ", "Metalik Bağ ve Zayıf Etkileşimler", "Maddenin Halleri",
        "Doğa ve Kimya", "Kimyanın Temel Kanunları",
        "Mol Kavramı ve Hesaplamalar", "Karışımlar", "Asit-Baz", "Tuzlar",
        "Endüstride ve Canlılarda Enerji", "Kimya Her Yerde",
      ],
      "Biyoloji": [
        "Canlıların Ortak Özellikleri", "İnorganik Bileşikler",
        "Organik Bileşikler (Karbonhidrat-Lipit-Protein)", "Enzimler",
        "Hücre ve Organelleri", "Hücre Zarından Madde Geçişi",
        "Canlıların Sınıflandırılması", "Mitoz ve Eşeysiz Üreme",
        "Mayoz ve Eşeyli Üreme", "Kalıtım", "Ekosistem Ekolojisi",
        "Güncel Çevre Sorunları",
      ],
      "Tarih": [
        "Tarih ve Zaman", "İnsanlığın İlk Dönemleri", "Orta Çağ'da Dünya",
        "İlk ve Orta Çağlarda Türk Dünyası", "İslam Medeniyetinin Doğuşu",
        "Türklerin İslamiyet'i Kabulü", "Selçuklu Türkiyesi",
        "Beylikten Devlete Osmanlı (1302-1453)", "Osmanlı Medeniyeti",
        "Dünya Gücü Osmanlı (1453-1595)", "Osmanlı Merkez Teşkilatı",
        "Klasik Çağda Osmanlı Toplum Düzeni", "Değişen Dünya Dengeleri (1595-1774)",
      ],
      "Coğrafya": [
        "Dünya'nın Şekli ve Hareketleri", "Harita Bilgisi", "Atmosfer ve Sıcaklık",
        "Basınç ve Rüzgârlar", "Nem-Yağış-Buharlaşma", "İç Kuvvetler",
        "Dış Kuvvetler", "Toprak ve Bitki Örtüsü", "Nüfus", "Göç", "Yerleşme",
        "Ekonomik Faaliyetler", "Bölgeler", "Doğa ve İnsan", "Çevre ve Toplum",
        "Doğal Afetler",
      ],
      "Felsefe": [
        "Felsefenin Konusu", "Bilgi Felsefesi", "Varlık Felsefesi",
        "Din Felsefesi", "Ahlak Felsefesi", "Sanat Felsefesi", "Bilim Felsefesi",
        "Siyaset Felsefesi",
      ],
      "Din Kültürü": [
        "Bilgi ve İnanç", "Din ve İslam", "İslam ve İbadet", "Gençlik ve Değerler",
        "Gönül Coğrafyamız", "Allah-İnsan İlişkisi", "Hz. Muhammed ve Gençlik",
        "Din ve Hayat", "Ahlaki Tutum ve Davranışlar",
        "İslam Düşüncesinde Yorumlar",
      ],
    },
    AYT: {
      "Matematik": [
        "Fonksiyonlarda Uygulamalar (Ters-Bileşke)", "Polinomlar",
        "İkinci Dereceden Denklemler", "Parabol", "Eşitsizlikler",
        "Trigonometri: Yönlü Açılar",
        "Trigonometri: Toplam-Fark ve İki Kat Açı", "Trigonometrik Denklemler",
        "Logaritma", "Diziler", "Limit ve Süreklilik", "Türev",
        "Türev Uygulamaları (Optimizasyon)", "İntegral",
        "İntegral ile Alan Hesabı", "Permütasyon-Kombinasyon",
        "Binom ve Olasılık",
      ],
      "Geometri": [
        "Analitik Geometri (Doğru)", "Çemberin Analitik İncelenmesi",
        "Katı Cisimler (Prizma-Silindir)", "Katı Cisimler (Piramit-Koni-Küre)",
        "Vektörler",
      ],
      "Fizik": [
        "Vektörler", "Kuvvet, Tork ve Denge", "İtme ve Momentum",
        "Çembersel Hareket", "Basit Harmonik Hareket",
        "Kütle Çekimi ve Kepler Yasaları", "Elektrik Alan ve Potansiyel",
        "Kondansatörler", "Manyetizma ve İndüksiyon", "Alternatif Akım",
        "Dalga Mekaniği (Girişim-Kırınım-Doppler)",
        "Atom Fiziği ve Radyoaktivite", "Özel Görelilik", "Fotoelektrik Olay",
        "Compton ve de Broglie",
      ],
      "Kimya": [
        "Kimyasal Tepkimelerde Enerji", "Kimyasal Tepkimelerde Hız",
        "Kimyasal Tepkimelerde Denge", "Asit-Baz Dengesi", "Çözünürlük Dengesi",
        "Redoks Tepkimeleri", "Elektrokimyasal Hücreler ve Piller", "Elektroliz",
        "Korozyon", "Karbon Kimyasına Giriş (Hibritleşme)", "Hidrokarbonlar",
        "Alkoller ve Eterler", "Aldehit ve Ketonlar",
        "Karboksilik Asitler ve Esterler", "Enerji Kaynakları",
      ],
      "Biyoloji": [
        "Hücre Bölünmeleri (Mitoz-Mayoz)", "Kalıtım Kalıpları",
        "Soyağacı ve Akraba Evliliği", "Modern Genetik Uygulamaları",
        "Ekosistem Ekolojisi", "Madde Döngüleri", "Popülasyon Ekolojisi",
        "Fotosentez", "Kemosentez", "Hücresel Solunum", "Bitkisel Dokular",
        "Bitkilerde Taşıma-Beslenme-Terleme", "Bitkilerde Üreme",
        "Nükleik Asitler", "DNA Replikasyonu", "Protein Sentezi", "Sinir Sistemi",
        "Endokrin Sistem ve Hormonlar", "Duyu Organları",
        "Destek ve Hareket Sistemi", "Sindirim Sistemi", "Dolaşım Sistemi",
        "Bağışıklık Sistemi", "Solunum Sistemi", "Boşaltım Sistemi",
        "Üreme Sistemi ve Embriyonik Gelişim",
      ],
      "Edebiyat": [
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
        "Değişim Çağında Avrupa ve Osmanlı",
        "Uluslararası İlişkilerde Denge (1774-1914)", "Devrimler Çağı",
        "Sermaye ve Emek", "XIX-XX. Yüzyılda Gündelik Hayat", "Nüfus Politikaları",
        "XX. Yüzyıl Başlarında Osmanlı", "Millî Mücadele",
        "Atatürkçülük ve Türk İnkılabı", "Atatürk İlkeleri", "İki Savaş Arası Dönem",
        "II. Dünya Savaşı", "Soğuk Savaş Dönemi",
      ],
      "Coğrafya": [
        "Ekosistem ve Madde Döngüsü", "Nüfus Politikaları", "Göç ve Şehirleşme",
        "Türkiye'de Nüfus ve Yerleşme", "Türkiye'de Tarım", "Türkiye'de Sanayi",
        "Türkiye'de Ticaret-Ulaşım-Turizm", "Bölgesel Kalkınma Projeleri",
        "Doğal Sistemler (Biyoçeşitlilik)", "Beşerî Sistemler",
        "Küresel Ortam: Bölgeler ve Ülkeler", "Çevre ve Toplum",
        "Doğal Afetler ve Toplum",
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
