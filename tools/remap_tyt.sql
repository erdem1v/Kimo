-- MEB TYT sorularını yeni MEBİ alt konularına dağıtır.
-- source='meb' ve exam='TYT' olanlar; AYT ekranlar gelince ayrıca yapılacak.
begin;
update public.mistakes set concept = 'Canlıların Ortak Özellikleri'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Canlıların Ortak Özellikleri';
update public.mistakes set concept = 'Canlıların Sınıflandırılmasının Amacı ve Önemi, Sınıflandırmada Kullanılan Kategoriler'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Canlıların Sınıflandırılması';
update public.mistakes set concept = 'Ekolojik Kavramlar, Ekosistemin Canlı ve Cansız Bileşenleri'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Ekosistem Ekolojisi';
update public.mistakes set concept = 'Enzimler'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Enzimler';
update public.mistakes set concept = 'Güncel Çevre Sorunlarının Sebepleri, Hava Kirliliği, Asit Yağmurları, Küresel İklim Değişikliği'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Güncel Çevre Sorunları';
update public.mistakes set concept = 'Hücre Teorisi, Prokaryot ve Ökaryot Hücre Yapısı'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Hücre ve Organelleri';
update public.mistakes set concept = 'Hücre Zarından Madde Geçişleri, Basit Difüzyon, Kolaylaştırılmış Difüzyon'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Hücre Zarından Madde Geçişi';
update public.mistakes set concept = 'İnorganik Bileşiklerin Genel Özellikleri ve Canlılar İçin Önemi'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='İnorganik Bileşikler';
update public.mistakes set concept = 'Kalıtımla İlgili Kavramlar, Olasılık İlkeleri ve Gamet Çeşitlerinin Bulunması'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Kalıtım';
update public.mistakes set concept = 'Madde Döngüleri'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Madde Döngüleri';
update public.mistakes set concept = 'Mayozun Genel Özellikleri ve Evreleri'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Mayoz ve Eşeyli Üreme';
update public.mistakes set concept = 'Mitozun Genel Özellikleri ve Evreleri'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Mitoz ve Eşeysiz Üreme';
update public.mistakes set concept = 'Nükleik Asitler'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Nükleik Asitler';
update public.mistakes set concept = 'Organik Bileşiklerin Genel Özellikleri, Karbonhidratlar'
 where source='meb' and exam='TYT' and subject='Biyoloji' and concept='Organik Bileşikler (Karbonhidrat-Lipit-Protein)';
update public.mistakes set concept = 'Atmosfer, Hava Durumu ve İklim'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Atmosfer ve Sıcaklık';
update public.mistakes set concept = 'Basınç ve Rüzgârlar'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Basınç ve Rüzgârlar';
update public.mistakes set concept = 'Bölge Sınıflandırılması ve Türleri'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Bölgeler';
update public.mistakes set concept = 'Doğal Çevrenin Kullanımı'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Çevre ve Toplum';
update public.mistakes set concept = 'Dış Kuvvetler (Akarsular)'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Dış Kuvvetler';
update public.mistakes set concept = 'Doğa ve İnsan Etkileşimi'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Doğa ve İnsan';
update public.mistakes set concept = 'Afetlerin Genel Özellikleri ve Sınıflandırılması'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Doğal Afetler';
update public.mistakes set concept = 'Dünya''nın Şekli ve Günlük Hareketi'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Dünya''nın Şekli ve Hareketleri';
update public.mistakes set concept = 'Ekonomik Faaliyetler'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Ekonomik Faaliyetler';
update public.mistakes set concept = 'Göçler'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Göç';
update public.mistakes set concept = 'Harita Unsurları ve Harita Çeşitleri'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Harita Bilgisi';
update public.mistakes set concept = 'İç Kuvvetler ve Kayaçlar'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='İç Kuvvetler';
update public.mistakes set concept = 'Nem ve Yağış'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Nem-Yağış-Buharlaşma';
update public.mistakes set concept = 'Nüfusun Özellikleri ve Gelişimi'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Nüfus';
update public.mistakes set concept = 'Dünyada Su Kaynakları'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Su Kaynakları';
update public.mistakes set concept = 'Dünyada ve Türkiye''de Topraklar'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Toprak ve Bitki Örtüsü';
update public.mistakes set concept = 'Yerleşme ve Türkiye''de Yerleşmeler'
 where source='meb' and exam='TYT' and subject='Coğrafya' and concept='Yerleşme';
update public.mistakes set concept = 'İslam Ahlakının Konusu ve Gayesi - İslam Ahlakının Kaynakları'
 where source='meb' and exam='TYT' and subject='Din Kültürü' and concept='Ahlaki Tutum ve Davranışlar';
update public.mistakes set concept = 'Allah İnancı ve İnsan'
 where source='meb' and exam='TYT' and subject='Din Kültürü' and concept='Allah-İnsan İlişkisi';
update public.mistakes set concept = 'İslam''da Bilgi Kaynakları'
 where source='meb' and exam='TYT' and subject='Din Kültürü' and concept='Bilgi ve İnanç';
update public.mistakes set concept = 'Din ve Aile'
 where source='meb' and exam='TYT' and subject='Din Kültürü' and concept='Din ve Hayat';
update public.mistakes set concept = 'Dinin Tanımı ve Kaynağı'
 where source='meb' and exam='TYT' and subject='Din Kültürü' and concept='Din ve İslam';
update public.mistakes set concept = 'Değerler ve Değerlerin Kaynağı'
 where source='meb' and exam='TYT' and subject='Din Kültürü' and concept='Gençlik ve Değerler';
update public.mistakes set concept = 'İslam Medeniyeti ve Özellikleri'
 where source='meb' and exam='TYT' and subject='Din Kültürü' and concept='Gönül Coğrafyamız';
update public.mistakes set concept = 'Bir Genç Olarak Hz. Muhammed'
 where source='meb' and exam='TYT' and subject='Din Kültürü' and concept='Hz. Muhammed ve Gençlik';
update public.mistakes set concept = 'Dini Yorum Farklılıklarının Sebepleri'
 where source='meb' and exam='TYT' and subject='Din Kültürü' and concept='İslam Düşüncesinde Yorumlar';
update public.mistakes set concept = 'İslam''da İbadet ve Kapsamı'
 where source='meb' and exam='TYT' and subject='Din Kültürü' and concept='İslam ve İbadet';
update public.mistakes set concept = 'Ahlak Felsefesinin Konusu ve Problemleri-İyi ve Kötünün Ölçütü'
 where source='meb' and exam='TYT' and subject='Felsefe' and concept='Ahlak Felsefesi';
update public.mistakes set concept = 'Bilgi Felsefesinin Konusu ve Bilginin İmkânı Problemi'
 where source='meb' and exam='TYT' and subject='Felsefe' and concept='Bilgi Felsefesi';
update public.mistakes set concept = 'Bilim Felsefesinin Konusu ve Problemleri'
 where source='meb' and exam='TYT' and subject='Felsefe' and concept='Bilim Felsefesi';
update public.mistakes set concept = 'Din Felsefesinin Konusu ve Soruları Tanrı''nın Varlığı İle İlgili Görüşler'
 where source='meb' and exam='TYT' and subject='Felsefe' and concept='Din Felsefesi';
update public.mistakes set concept = 'Felsefenin Anlamı'
 where source='meb' and exam='TYT' and subject='Felsefe' and concept='Felsefenin Konusu';
update public.mistakes set concept = 'Sanat Felsefesinin Konusu ve Problemleri-Güzellik-Sanat Nedir?'
 where source='meb' and exam='TYT' and subject='Felsefe' and concept='Sanat Felsefesi';
update public.mistakes set concept = 'Siyaset Felsefesinin Konusu ve Problemleri-Hak, Adalet, Özgürlük-İktidarın Kaynağı'
 where source='meb' and exam='TYT' and subject='Felsefe' and concept='Siyaset Felsefesi';
update public.mistakes set concept = 'Varlık Felsefesinin Konusu ve Problemleri'
 where source='meb' and exam='TYT' and subject='Felsefe' and concept='Varlık Felsefesi';
update public.mistakes set concept = 'Kuvvet Kavramı'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Basit Makineler';
update public.mistakes set concept = 'Basınç Kavramı, Katılarda Basınç ve Basınç Kuvveti'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Basınç';
update public.mistakes set concept = 'Dalgalarda Temel Kavramlar ve Özellikleri'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Dalgalar (Temel)';
update public.mistakes set concept = 'Hareket Kavramları'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Doğrusal Hareket';
update public.mistakes set concept = 'Işığın Yansıması ve Düzlem Aynalar'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Düzlem Ayna';
update public.mistakes set concept = 'Elektrik Akımı ve Direnç'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Elektrik Akımı ve Devreler';
update public.mistakes set concept = 'Elektrik Yüklerinin Özellikleri ve Elektrikle Yüklenme Çeşitleri'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Elektrostatik';
update public.mistakes set concept = 'Fizik Bilimine Giriş'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Fizik Bilimine Giriş';
update public.mistakes set concept = 'İş, Enerji ve Güç Kavramı'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='İş-Güç-Enerji';
update public.mistakes set concept = 'Isı ve Sıcaklık Kavramları, Termometreler'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Isı ve Sıcaklık';
update public.mistakes set concept = 'Gölge'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Işık ve Gölge';
update public.mistakes set concept = 'Işığın Kırılması'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Kırılma ve Renkler';
update public.mistakes set concept = 'Küresel Aynaların Özellikleri ve Küresel Aynalarda Özel Işınlar'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Küresel Aynalar';
update public.mistakes set concept = 'Kuvvet Kavramı'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Kuvvet ve Denge (Vektörler)';
update public.mistakes set concept = 'Kütle ve Hacim'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Madde ve Özellikleri';
update public.mistakes set concept = 'Merceklerin Özellikleri ve Merceklerde Özel Işınlar'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Mercekler';
update public.mistakes set concept = 'Mıknatıslar ve Manyetik Alan'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Mıknatıslar ve Manyetik Alan';
update public.mistakes set concept = 'Kaldırma Kuvveti'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Sıvıların Kaldırma Kuvveti';
update public.mistakes set concept = 'Yay Dalgalarının Hızı ve Yansıması'
 where source='meb' and exam='TYT' and subject='Fizik' and concept='Yay ve Su Dalgaları';
update public.mistakes set concept = 'Üçgende Açıortay ve Özellikleri'
 where source='meb' and exam='TYT' and subject='Geometri' and concept='Açıortay';
update public.mistakes set concept = 'Çokgenler'
 where source='meb' and exam='TYT' and subject='Geometri' and concept='Çokgenler';
update public.mistakes set concept = 'Dik Üçgende Pisagor Teoremi'
 where source='meb' and exam='TYT' and subject='Geometri' and concept='Dik Üçgen';
update public.mistakes set concept = 'Kare'
 where source='meb' and exam='TYT' and subject='Geometri' and concept='Dikdörtgen ve Kare';
update public.mistakes set concept = 'Üçgende Kenarortay'
 where source='meb' and exam='TYT' and subject='Geometri' and concept='Kenarortay';
update public.mistakes set concept = 'Paralelkenarda Açı ve Uzunluk'
 where source='meb' and exam='TYT' and subject='Geometri' and concept='Paralelkenar';
update public.mistakes set concept = 'Üçgende Açılar'
 where source='meb' and exam='TYT' and subject='Geometri' and concept='Üçgende Açılar';
update public.mistakes set concept = 'Üçgenin Alanı'
 where source='meb' and exam='TYT' and subject='Geometri' and concept='Üçgende Alan';
update public.mistakes set concept = 'Üçgenlerde Benzerlik'
 where source='meb' and exam='TYT' and subject='Geometri' and concept='Üçgende Benzerlik';
update public.mistakes set concept = 'Asitlerin ve Bazların Özellikleri'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Asit-Baz';
update public.mistakes set concept = 'Atomun Yapısı'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Atomun Yapısı';
update public.mistakes set concept = 'Su ve Hayat'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Doğa ve Kimya';
update public.mistakes set concept = 'Güçlü Etkileşimler'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='İyonik Bağ';
update public.mistakes set concept = 'Homojen-Heterojen Karışımlar (I)'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Karışımlar';
update public.mistakes set concept = 'Simyadan Kimyaya'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Kimya Bilimine Giriş';
update public.mistakes set concept = 'Yaygın Günlük Hayat Kimyasalları'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Kimya Her Yerde';
update public.mistakes set concept = 'Kimyanın Temel Kanunları'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Kimyanın Temel Kanunları';
update public.mistakes set concept = 'Güçlü Etkileşimler'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Kovalent Bağ';
update public.mistakes set concept = 'Maddenin Fiziksel Hâlleri'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Maddenin Halleri';
update public.mistakes set concept = 'Zayıf Etkileşimler'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Metalik Bağ ve Zayıf Etkileşimler';
update public.mistakes set concept = 'Mol Kavramı'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Mol Kavramı ve Hesaplamalar';
update public.mistakes set concept = 'Elementlerin Periyodik Sistemdeki Yerleşim Esasları'
 where source='meb' and exam='TYT' and subject='Kimya' and concept='Periyodik Sistem';
update public.mistakes set concept = 'Basit Eşitsizlikler'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='Basit Eşitsizlikler';
update public.mistakes set concept = 'Bölünebilme Kuralları 1'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='Bölme-Bölünebilme';
update public.mistakes set concept = 'Fonksiyon Kavramı ve Gösterimi'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='Fonksiyonlar';
update public.mistakes set concept = 'İkinci Dereceden Bir Bilinmeyenli Denklemler'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='İkinci Dereceden Denklemler';
update public.mistakes set concept = 'Merkezi Eğilim Ölçüleri'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='İstatistik';
update public.mistakes set concept = 'Kümelerde Temel Kavramlar'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='Kümeler';
update public.mistakes set concept = 'Önermeler'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='Mantık';
update public.mistakes set concept = 'Olasılıkta Temel Kavramlar'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='Olasılık';
update public.mistakes set concept = 'Permütasyon'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='Permütasyon-Kombinasyon';
update public.mistakes set concept = 'Polinom Kavramı'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='Polinomlar';
update public.mistakes set concept = 'Sayı Problemleri'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='Sayı Problemleri';
update public.mistakes set concept = 'Sayı Kümeleri'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='Temel Kavramlar';
update public.mistakes set concept = 'Üslü İfadeler ve Özellikleri'
 where source='meb' and exam='TYT' and subject='Matematik' and concept='Üslü Sayılar';
update public.mistakes set concept = 'Cümle Türleri'
 where source='meb' and exam='TYT' and subject='Türkçe' and concept='Cümle Türleri';
update public.mistakes set concept = 'Edat, Bağlaç ve Ünlem'
 where source='meb' and exam='TYT' and subject='Türkçe' and concept='Edat-Bağlaç-Ünlem';
update public.mistakes set concept = 'Fiilde Kip'
 where source='meb' and exam='TYT' and subject='Türkçe' and concept='Fiilde Anlam (Kip-Kişi)';
update public.mistakes set concept = 'Fiilimsiler'
 where source='meb' and exam='TYT' and subject='Türkçe' and concept='Fiilimsi';
update public.mistakes set concept = 'İsim'
 where source='meb' and exam='TYT' and subject='Türkçe' and concept='İsim (Ad)';
update public.mistakes set concept = 'Noktalama İşaretleri-1'
 where source='meb' and exam='TYT' and subject='Türkçe' and concept='Noktalama İşaretleri';
update public.mistakes set concept = 'Sıfat'
 where source='meb' and exam='TYT' and subject='Türkçe' and concept='Sıfat';
update public.mistakes set concept = 'Yazım Kuralları-1'
 where source='meb' and exam='TYT' and subject='Türkçe' and concept='Yazım Kuralları';
update public.mistakes set concept = 'Zamir'
 where source='meb' and exam='TYT' and subject='Türkçe' and concept='Zamir';
update public.mistakes set concept = 'Zarf'
 where source='meb' and exam='TYT' and subject='Türkçe' and concept='Zarf';
update public.mistakes set concept = 'Osmanlı Beyliği''nin Kuruluşu ve İlk Fetihleri'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='Beylikten Devlete Osmanlı (1302-1453)';
update public.mistakes set concept = 'İstanbul''un Fethi ve Fethin Sonuçları'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='Dünya Gücü Osmanlı (1453-1595)';
update public.mistakes set concept = 'Avrasya''da İlk Türk İzleri, Coğrafya ile Oluşan Yaşam Tarzı'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='İlk ve Orta Çağlarda Türk Dünyası';
update public.mistakes set concept = 'İnsanlığın Hafızası Tarih'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='İnsanlığın İlk Dönemleri';
update public.mistakes set concept = 'İslamiyet''in Doğduğu Dönemde Dünya, İslamiyet Yayılıyor'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='İslam Medeniyetinin Doğuşu';
update public.mistakes set concept = 'Osmanlı Devleti''nde Millet Sistemi, Fethettiği Yerlerdeki Kültürel Değişim'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='Klasik Çağda Osmanlı Toplum Düzeni';
update public.mistakes set concept = 'Kavimler Göçü'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='Orta Çağ''da Dünya';
update public.mistakes set concept = 'Beylikten Devlete Osmanlı Medeniyeti'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='Osmanlı Medeniyeti';
update public.mistakes set concept = 'Saray ve Şehir Kültürü, Gelenekler Işığında Devlet İdaresi'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='Osmanlı Merkez Teşkilatı';
update public.mistakes set concept = 'Türklerin Anadolu''ya Yerleşme Süreci'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='Selçuklu Türkiyesi';
update public.mistakes set concept = 'İnsanlığın Hafızası Tarih'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='Tarih ve Zaman';
update public.mistakes set concept = 'Türklerin İslamiyet''i Kabulü'
 where source='meb' and exam='TYT' and subject='Tarih' and concept='Türklerin İslamiyet''i Kabulü';
commit;
