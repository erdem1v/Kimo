-- 0072 — Konu agaci tohumu (URETILEN DOSYA — ELLE DUZENLEMEYIN)
--
-- Kaynak: taxonomy/yks-konulari.md
-- Uretici: python3 tools/build_taxonomy.py
-- Surum: 7d00385d45b1  ·  kaynak sha256: 22815bcc7731a514
--
-- Surum ICERIKTEN turuyor (kanonik serilestirmenin sha256'si), yani
-- guncellenmesi UNUTULAMAZ. Istemci bu degeri onbellegiyle karsilastirip
-- agaci ne zaman tazeleyecegine karar veriyor.
--
-- SIRA ONEMLI: once agac yazilir, SONRA eski adlarin remap'i calisir.
-- Tersi olsaydi remap'in yazdigi kanonik ad henuz agacta olmaz ve 0071'in
-- dogrulama tetikleyicisi kendi tohumunu reddederdi.

delete from public.curriculum_aliases;
delete from public.curriculum_topics;

insert into public.curriculum_topics
  (curriculum, exam, subject, unit, topic, subject_ord, unit_ord, topic_ord)
values
  ('eski', 'TYT', 'Türkçe', 'Anlam Bilgisi', 'Sözcükte Anlam', 0, 0, 0),
  ('eski', 'TYT', 'Türkçe', 'Anlam Bilgisi', 'Cümlede Anlam', 0, 0, 1),
  ('eski', 'TYT', 'Türkçe', 'Anlam Bilgisi', 'Paragrafta Anlam', 0, 0, 2),
  ('eski', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Ses Bilgisi', 0, 1, 0),
  ('eski', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Biçim Bilgisi', 0, 1, 1),
  ('eski', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Sözcük Türleri', 0, 1, 2),
  ('eski', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Fiiller', 0, 1, 3),
  ('eski', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Cümlenin Ögeleri', 0, 1, 4),
  ('eski', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Cümle Türleri', 0, 1, 5),
  ('eski', 'TYT', 'Türkçe', 'Yazım ve Anlatım', 'Yazım Kuralları', 0, 2, 0),
  ('eski', 'TYT', 'Türkçe', 'Yazım ve Anlatım', 'Noktalama İşaretleri', 0, 2, 1),
  ('eski', 'TYT', 'Türkçe', 'Yazım ve Anlatım', 'Anlatım Bozuklukları', 0, 2, 2),
  ('eski', 'TYT', 'Matematik', 'Mantık', 'Önermeler ve Bileşik Önermeler', 1, 0, 0),
  ('eski', 'TYT', 'Matematik', 'Kümeler', 'Kümelerde Temel Kavramlar', 1, 1, 0),
  ('eski', 'TYT', 'Matematik', 'Kümeler', 'Kümelerde İşlemler', 1, 1, 1),
  ('eski', 'TYT', 'Matematik', 'Sayılar ve Denklemler', 'Sayı Kümeleri', 1, 2, 0),
  ('eski', 'TYT', 'Matematik', 'Sayılar ve Denklemler', 'Bölünebilme Kuralları', 1, 2, 1),
  ('eski', 'TYT', 'Matematik', 'Sayılar ve Denklemler', 'Birinci Dereceden Denklemler ve Eşitsizlikler', 1, 2, 2),
  ('eski', 'TYT', 'Matematik', 'Sayılar ve Denklemler', 'Üslü İfadeler ve Denklemler', 1, 2, 3),
  ('eski', 'TYT', 'Matematik', 'Sayılar ve Denklemler', 'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar', 1, 2, 4),
  ('eski', 'TYT', 'Matematik', 'Veri', 'Merkezi Eğilim ve Yayılım Ölçüleri', 1, 3, 0),
  ('eski', 'TYT', 'Matematik', 'Veri', 'Verilerin Grafikle Gösterilmesi', 1, 3, 1),
  ('eski', 'TYT', 'Matematik', 'Sayma ve Olasılık', 'Sıralama ve Seçme', 1, 4, 0),
  ('eski', 'TYT', 'Matematik', 'Sayma ve Olasılık', 'Basit Olayların Olasılıkları', 1, 4, 1),
  ('eski', 'TYT', 'Matematik', 'Fonksiyonlar', 'Fonksiyon Kavramı ve Gösterimi', 1, 5, 0),
  ('eski', 'TYT', 'Matematik', 'Fonksiyonlar', 'İki Fonksiyonun Bileşkesi ve Bir Fonksiyonun Tersi', 1, 5, 1),
  ('eski', 'TYT', 'Matematik', 'Polinomlar', 'Polinom Kavramı ve Polinomlarda İşlemler', 1, 6, 0),
  ('eski', 'TYT', 'Matematik', 'Polinomlar', 'Polinomların Çarpanlara Ayrılması', 1, 6, 1),
  ('eski', 'TYT', 'Matematik', 'İkinci Dereceden Denklemler', 'İkinci Dereceden Bir Bilinmeyenli Denklemler', 1, 7, 0),
  ('eski', 'TYT', 'Geometri', 'Üçgenler', 'Üçgenlerde Temel Kavramlar', 2, 0, 0),
  ('eski', 'TYT', 'Geometri', 'Üçgenler', 'Üçgenlerde Eşlik ve Benzerlik', 2, 0, 1),
  ('eski', 'TYT', 'Geometri', 'Üçgenler', 'Üçgenin Yardımcı Elemanları', 2, 0, 2),
  ('eski', 'TYT', 'Geometri', 'Üçgenler', 'Dik Üçgen ve Trigonometri', 2, 0, 3),
  ('eski', 'TYT', 'Geometri', 'Üçgenler', 'Üçgenin Alanı', 2, 0, 4),
  ('eski', 'TYT', 'Geometri', 'Dörtgenler ve Çokgenler', 'Çokgenler', 2, 1, 0),
  ('eski', 'TYT', 'Geometri', 'Dörtgenler ve Çokgenler', 'Dörtgenler ve Özellikleri', 2, 1, 1),
  ('eski', 'TYT', 'Geometri', 'Dörtgenler ve Çokgenler', 'Özel Dörtgenler', 2, 1, 2),
  ('eski', 'TYT', 'Geometri', 'Katı Cisimler', 'Katı Cisimler', 2, 2, 0),
  ('eski', 'TYT', 'Fizik', 'Mekanik', 'Fizik Bilimine Giriş', 3, 0, 0),
  ('eski', 'TYT', 'Fizik', 'Mekanik', 'Madde ve Özellikleri', 3, 0, 1),
  ('eski', 'TYT', 'Fizik', 'Mekanik', 'Hareket ve Kuvvet', 3, 0, 2),
  ('eski', 'TYT', 'Fizik', 'Mekanik', 'Enerji', 3, 0, 3),
  ('eski', 'TYT', 'Fizik', 'Mekanik', 'Basınç ve Kaldırma Kuvveti', 3, 0, 4),
  ('eski', 'TYT', 'Fizik', 'Isı, Elektrik ve Manyetizma', 'Isı ve Sıcaklık', 3, 1, 0),
  ('eski', 'TYT', 'Fizik', 'Isı, Elektrik ve Manyetizma', 'Elektrostatik', 3, 1, 1),
  ('eski', 'TYT', 'Fizik', 'Isı, Elektrik ve Manyetizma', 'Elektrik ve Manyetizma', 3, 1, 2),
  ('eski', 'TYT', 'Fizik', 'Dalgalar ve Optik', 'Dalgalar', 3, 2, 0),
  ('eski', 'TYT', 'Fizik', 'Dalgalar ve Optik', 'Optik', 3, 2, 1),
  ('eski', 'TYT', 'Kimya', 'Kimyanın Temelleri', 'Kimya Bilimi', 4, 0, 0),
  ('eski', 'TYT', 'Kimya', 'Kimyanın Temelleri', 'Atom ve Periyodik Sistem', 4, 0, 1),
  ('eski', 'TYT', 'Kimya', 'Kimyanın Temelleri', 'Kimyasal Türler Arası Etkileşimler', 4, 0, 2),
  ('eski', 'TYT', 'Kimya', 'Maddenin Hâlleri ve Karışımlar', 'Maddenin Hâlleri', 4, 1, 0),
  ('eski', 'TYT', 'Kimya', 'Maddenin Hâlleri ve Karışımlar', 'Kimyanın Temel Kanunları ve Kimyasal Hesaplamalar', 4, 1, 1),
  ('eski', 'TYT', 'Kimya', 'Maddenin Hâlleri ve Karışımlar', 'Karışımlar', 4, 1, 2),
  ('eski', 'TYT', 'Kimya', 'Asitler, Bazlar ve Günlük Kimya', 'Asitler, Bazlar ve Tuzlar', 4, 2, 0),
  ('eski', 'TYT', 'Kimya', 'Asitler, Bazlar ve Günlük Kimya', 'Kimya Her Yerde', 4, 2, 1),
  ('eski', 'TYT', 'Kimya', 'Asitler, Bazlar ve Günlük Kimya', 'Doğa ve Kimya', 4, 2, 2),
  ('eski', 'TYT', 'Biyoloji', 'Canlıların Temel Bileşenleri', 'Canlıların Ortak Özellikleri', 5, 0, 0),
  ('eski', 'TYT', 'Biyoloji', 'Canlıların Temel Bileşenleri', 'Canlıların Yapısında Bulunan İnorganik Bileşikler', 5, 0, 1),
  ('eski', 'TYT', 'Biyoloji', 'Canlıların Temel Bileşenleri', 'Canlıların Yapısında Bulunan Organik Bileşikler', 5, 0, 2),
  ('eski', 'TYT', 'Biyoloji', 'Hücre', 'Hücresel Yapılar ve Görevleri', 5, 1, 0),
  ('eski', 'TYT', 'Biyoloji', 'Hücre', 'Hücre Zarından Madde Geçişleri', 5, 1, 1),
  ('eski', 'TYT', 'Biyoloji', 'Hücre', 'Hücre Döngüsü ve Mitoz', 5, 1, 2),
  ('eski', 'TYT', 'Biyoloji', 'Hücre', 'Eşeysiz Üreme', 5, 1, 3),
  ('eski', 'TYT', 'Biyoloji', 'Hücre', 'Mayoz', 5, 1, 4),
  ('eski', 'TYT', 'Biyoloji', 'Hücre', 'Eşeyli Üreme', 5, 1, 5),
  ('eski', 'TYT', 'Biyoloji', 'Canlılar Dünyası ve Kalıtım', 'Canlıların Sınıflandırılması', 5, 2, 0),
  ('eski', 'TYT', 'Biyoloji', 'Canlılar Dünyası ve Kalıtım', 'Canlı Âlemleri', 5, 2, 1),
  ('eski', 'TYT', 'Biyoloji', 'Canlılar Dünyası ve Kalıtım', 'Kalıtım', 5, 2, 2),
  ('eski', 'TYT', 'Biyoloji', 'Canlılar Dünyası ve Kalıtım', 'Genetik Varyasyonlar', 5, 2, 3),
  ('eski', 'TYT', 'Biyoloji', 'Ekoloji', 'Ekosistem Ekolojisi', 5, 3, 0),
  ('eski', 'TYT', 'Biyoloji', 'Ekoloji', 'Güncel Çevre Sorunları', 5, 3, 1),
  ('eski', 'TYT', 'Biyoloji', 'Ekoloji', 'Doğal Kaynakların Sürdürülebilirliği', 5, 3, 2),
  ('eski', 'TYT', 'Biyoloji', 'Ekoloji', 'Biyolojik Çeşitliliğin Korunması', 5, 3, 3),
  ('eski', 'TYT', 'Tarih', 'Tarih Bilimi', 'Tarih ve Zaman', 6, 0, 0),
  ('eski', 'TYT', 'Tarih', 'İlk Çağlardan Türk-İslam Dünyasına', 'İlk ve Orta Çağlarda Türk Dünyası', 6, 1, 0),
  ('eski', 'TYT', 'Tarih', 'İlk Çağlardan Türk-İslam Dünyasına', 'İslam Medeniyetinin Doğuşu', 6, 1, 1),
  ('eski', 'TYT', 'Tarih', 'İlk Çağlardan Türk-İslam Dünyasına', 'Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet''i Kabulü', 6, 1, 2),
  ('eski', 'TYT', 'Tarih', 'İlk Çağlardan Türk-İslam Dünyasına', 'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi', 6, 1, 3),
  ('eski', 'TYT', 'Tarih', 'Osmanlı Tarihi', 'Beylikten Devlete Osmanlı Siyaseti (1302-1453)', 6, 2, 0),
  ('eski', 'TYT', 'Tarih', 'Osmanlı Tarihi', 'Devletleşme Sürecinde Savaşçılar ve Askerler', 6, 2, 1),
  ('eski', 'TYT', 'Tarih', 'Osmanlı Tarihi', 'Beylikten Devlete Osmanlı Medeniyeti', 6, 2, 2),
  ('eski', 'TYT', 'Tarih', 'Osmanlı Tarihi', 'Dünya Gücü Osmanlı (1453-1595)', 6, 2, 3),
  ('eski', 'TYT', 'Tarih', 'Osmanlı Tarihi', 'Sultan ve Osmanlı Merkez Teşkilatı', 6, 2, 4),
  ('eski', 'TYT', 'Tarih', 'Osmanlı Tarihi', 'Klasik Çağda Osmanlı Toplum Düzeni', 6, 2, 5),
  ('eski', 'TYT', 'Tarih', 'Osmanlı Tarihi', 'Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774)', 6, 2, 6),
  ('eski', 'TYT', 'Tarih', 'Osmanlı Tarihi', 'Değişim Çağında Avrupa ve Osmanlı', 6, 2, 7),
  ('eski', 'TYT', 'Tarih', 'Osmanlı Tarihi', 'Uluslararası İlişkilerde Denge Stratejisi (1774-1914)', 6, 2, 8),
  ('eski', 'TYT', 'Tarih', 'Yakın Çağ ve Cumhuriyet', 'Devrimler Çağında Değişen Devlet-Toplum İlişkileri', 6, 3, 0),
  ('eski', 'TYT', 'Tarih', 'Yakın Çağ ve Cumhuriyet', 'XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat', 6, 3, 1),
  ('eski', 'TYT', 'Tarih', 'Yakın Çağ ve Cumhuriyet', 'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya', 6, 3, 2),
  ('eski', 'TYT', 'Tarih', 'Yakın Çağ ve Cumhuriyet', 'Millî Mücadele', 6, 3, 3),
  ('eski', 'TYT', 'Tarih', 'Yakın Çağ ve Cumhuriyet', 'Atatürkçülük ve Türk İnkılabı', 6, 3, 4),
  ('eski', 'TYT', 'Coğrafya', 'Doğal Sistemler', 'Coğrafya Bilimi, İnsan ve Doğa', 7, 0, 0),
  ('eski', 'TYT', 'Coğrafya', 'Doğal Sistemler', 'Dünya''nın Şekli ve Hareketleri', 7, 0, 1),
  ('eski', 'TYT', 'Coğrafya', 'Doğal Sistemler', 'Yer ve Zaman, Koordinat Sistemi', 7, 0, 2),
  ('eski', 'TYT', 'Coğrafya', 'Doğal Sistemler', 'Harita Bilimi', 7, 0, 3),
  ('eski', 'TYT', 'Coğrafya', 'Doğal Sistemler', 'İklim Bilimi', 7, 0, 4),
  ('eski', 'TYT', 'Coğrafya', 'Doğal Sistemler', 'Dünya''nın Yapısı ve Oluşum Süreci', 7, 0, 5),
  ('eski', 'TYT', 'Coğrafya', 'Doğal Sistemler', 'Su Kaynakları, Topraklar, Bitkiler', 7, 0, 6),
  ('eski', 'TYT', 'Coğrafya', 'Beşerî Sistemler', 'Yerleşmeler', 7, 1, 0),
  ('eski', 'TYT', 'Coğrafya', 'Beşerî Sistemler', 'Nüfus, Göç, Ekonomik Faaliyetler', 7, 1, 1),
  ('eski', 'TYT', 'Coğrafya', 'Beşerî Sistemler', 'Ulaşım', 7, 1, 2),
  ('eski', 'TYT', 'Coğrafya', 'Küresel Ortam', 'Bölgeler ve Ülkeler', 7, 2, 0),
  ('eski', 'TYT', 'Coğrafya', 'Çevre ve Toplum', 'İnsan ve Çevre', 7, 3, 0),
  ('eski', 'TYT', 'Coğrafya', 'Çevre ve Toplum', 'Afetler', 7, 3, 1),
  ('eski', 'TYT', 'Felsefe', 'Felsefeye Giriş', 'Felsefeyi Tanıma', 8, 0, 0),
  ('eski', 'TYT', 'Felsefe', 'Felsefeye Giriş', 'Felsefe ile Düşünme', 8, 0, 1),
  ('eski', 'TYT', 'Felsefe', 'Felsefeye Giriş', 'Felsefi Okuma ve Yazma', 8, 0, 2),
  ('eski', 'TYT', 'Felsefe', 'Felsefenin Temel Konuları', 'Varlık Felsefesi', 8, 1, 0),
  ('eski', 'TYT', 'Felsefe', 'Felsefenin Temel Konuları', 'Bilgi Felsefesi', 8, 1, 1),
  ('eski', 'TYT', 'Felsefe', 'Felsefenin Temel Konuları', 'Bilim Felsefesi', 8, 1, 2),
  ('eski', 'TYT', 'Felsefe', 'Felsefenin Temel Konuları', 'Ahlak Felsefesi', 8, 1, 3),
  ('eski', 'TYT', 'Felsefe', 'Felsefenin Temel Konuları', 'Din Felsefesi', 8, 1, 4),
  ('eski', 'TYT', 'Felsefe', 'Felsefenin Temel Konuları', 'Siyaset Felsefesi', 8, 1, 5),
  ('eski', 'TYT', 'Felsefe', 'Felsefenin Temel Konuları', 'Sanat Felsefesi', 8, 1, 6),
  ('eski', 'TYT', 'Felsefe', 'Felsefe Tarihi', 'MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi', 8, 2, 0),
  ('eski', 'TYT', 'Felsefe', 'Felsefe Tarihi', 'MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi', 8, 2, 1),
  ('eski', 'TYT', 'Felsefe', 'Felsefe Tarihi', '15. Yüzyıl-17. Yüzyıl Felsefesi', 8, 2, 2),
  ('eski', 'TYT', 'Felsefe', 'Felsefe Tarihi', '18. Yüzyıl-19. Yüzyıl Felsefesi', 8, 2, 3),
  ('eski', 'TYT', 'Felsefe', 'Felsefe Tarihi', '20. Yüzyıl Felsefesi', 8, 2, 4),
  ('eski', 'TYT', 'Din Kültürü', 'İnanç', 'Bilgi ve İnanç', 9, 0, 0),
  ('eski', 'TYT', 'Din Kültürü', 'İnanç', 'Din ve İslam', 9, 0, 1),
  ('eski', 'TYT', 'Din Kültürü', 'İnanç', 'Allah İnsan İlişkisi', 9, 0, 2),
  ('eski', 'TYT', 'Din Kültürü', 'İnanç', 'İslam Düşüncesinde İtikadi, Siyasi ve Fıkhi Yorumlar', 9, 0, 3),
  ('eski', 'TYT', 'Din Kültürü', 'İbadet ve Ahlak', 'İslam ve İbadet', 9, 1, 0),
  ('eski', 'TYT', 'Din Kültürü', 'İbadet ve Ahlak', 'Ahlaki Tutum Davranışlar', 9, 1, 1),
  ('eski', 'TYT', 'Din Kültürü', 'İbadet ve Ahlak', 'Din ve Hayat', 9, 1, 2),
  ('eski', 'TYT', 'Din Kültürü', 'Değerler ve Kültür', 'Gençlik ve Değerler', 9, 2, 0),
  ('eski', 'TYT', 'Din Kültürü', 'Değerler ve Kültür', 'Gönül Coğrafyamız', 9, 2, 1),
  ('eski', 'TYT', 'Din Kültürü', 'Değerler ve Kültür', 'Hz. Muhammed ve Gençlik', 9, 2, 2),
  ('eski', 'AYT', 'Matematik', 'Trigonometri', 'Yönlü Açılar', 0, 0, 0),
  ('eski', 'AYT', 'Matematik', 'Trigonometri', 'Trigonometrik Fonksiyonlar', 0, 0, 1),
  ('eski', 'AYT', 'Matematik', 'Trigonometri', 'Toplam-Fark ve İki Kat Açı Formülleri', 0, 0, 2),
  ('eski', 'AYT', 'Matematik', 'Trigonometri', 'Trigonometrik Denklemler', 0, 0, 3),
  ('eski', 'AYT', 'Matematik', 'Fonksiyonlarda Uygulamalar', 'Fonksiyonların Grafik ve Problemleri', 0, 1, 0),
  ('eski', 'AYT', 'Matematik', 'Fonksiyonlarda Uygulamalar', 'İkinci Dereceden Fonksiyonlar ve Grafikleri', 0, 1, 1),
  ('eski', 'AYT', 'Matematik', 'Fonksiyonlarda Uygulamalar', 'Fonksiyonların Dönüşümleri', 0, 1, 2),
  ('eski', 'AYT', 'Matematik', 'Denklem ve Eşitsizlik Sistemleri', 'İkinci Dereceden İki Bilinmeyenli Denklem Sistemleri', 0, 2, 0),
  ('eski', 'AYT', 'Matematik', 'Denklem ve Eşitsizlik Sistemleri', 'İkinci Dereceden Eşitsizlikler', 0, 2, 1),
  ('eski', 'AYT', 'Matematik', 'Üstel ve Logaritmik Fonksiyonlar', 'Üstel Fonksiyon', 0, 3, 0),
  ('eski', 'AYT', 'Matematik', 'Üstel ve Logaritmik Fonksiyonlar', 'Logaritma Fonksiyonu', 0, 3, 1),
  ('eski', 'AYT', 'Matematik', 'Üstel ve Logaritmik Fonksiyonlar', 'Üstel ve Logaritmik Denklem ve Eşitsizlikler', 0, 3, 2),
  ('eski', 'AYT', 'Matematik', 'Diziler', 'Diziler', 0, 4, 0),
  ('eski', 'AYT', 'Matematik', 'Türev', 'Limit ve Süreklilik', 0, 5, 0),
  ('eski', 'AYT', 'Matematik', 'Türev', 'Türev', 0, 5, 1),
  ('eski', 'AYT', 'Matematik', 'Türev', 'Türev Uygulamaları', 0, 5, 2),
  ('eski', 'AYT', 'Matematik', 'İntegral', 'Belirsiz İntegral', 0, 6, 0),
  ('eski', 'AYT', 'Matematik', 'İntegral', 'Belirli İntegral ve Alan Hesabı', 0, 6, 1),
  ('eski', 'AYT', 'Matematik', 'Olasılık', 'Koşullu Olasılık', 0, 7, 0),
  ('eski', 'AYT', 'Matematik', 'Olasılık', 'Deneysel ve Teorik Olasılık', 0, 7, 1),
  ('eski', 'AYT', 'Geometri', 'Analitik Geometri', 'Doğrunun Analitik İncelenmesi', 1, 0, 0),
  ('eski', 'AYT', 'Geometri', 'Analitik Geometri', 'Çemberin Analitik İncelenmesi', 1, 0, 1),
  ('eski', 'AYT', 'Geometri', 'Dönüşümler', 'Analitik Düzlemde Temel Dönüşümler', 1, 1, 0),
  ('eski', 'AYT', 'Geometri', 'Çember ve Daire', 'Çemberde Temel Kavramlar', 1, 2, 0),
  ('eski', 'AYT', 'Geometri', 'Çember ve Daire', 'Çemberde Açılar', 1, 2, 1),
  ('eski', 'AYT', 'Geometri', 'Çember ve Daire', 'Çemberde Teğet', 1, 2, 2),
  ('eski', 'AYT', 'Geometri', 'Çember ve Daire', 'Dairenin Çevresi ve Alanı', 1, 2, 3),
  ('eski', 'AYT', 'Geometri', 'Uzay Geometri', 'Katı Cisimler (Küre, Silindir, Koni)', 1, 3, 0),
  ('eski', 'AYT', 'Fizik', 'Mekanik', 'Kuvvet ve Hareket', 2, 0, 0),
  ('eski', 'AYT', 'Fizik', 'Mekanik', 'Çembersel Hareket', 2, 0, 1),
  ('eski', 'AYT', 'Fizik', 'Mekanik', 'Basit Harmonik Hareket', 2, 0, 2),
  ('eski', 'AYT', 'Fizik', 'Elektromanyetizma ve Dalgalar', 'Elektrik ve Manyetizma', 2, 1, 0),
  ('eski', 'AYT', 'Fizik', 'Elektromanyetizma ve Dalgalar', 'Dalga Mekaniği', 2, 1, 1),
  ('eski', 'AYT', 'Fizik', 'Modern Fizik', 'Atom Fiziğine Giriş ve Radyoaktivite', 2, 2, 0),
  ('eski', 'AYT', 'Fizik', 'Modern Fizik', 'Modern Fizik', 2, 2, 1),
  ('eski', 'AYT', 'Fizik', 'Modern Fizik', 'Modern Fiziğin Teknolojideki Uygulamaları', 2, 2, 2),
  ('eski', 'AYT', 'Kimya', 'Atom, Gazlar ve Çözeltiler', 'Modern Atom Teorisi', 3, 0, 0),
  ('eski', 'AYT', 'Kimya', 'Atom, Gazlar ve Çözeltiler', 'Gazlar', 3, 0, 1),
  ('eski', 'AYT', 'Kimya', 'Atom, Gazlar ve Çözeltiler', 'Sıvı Çözeltiler ve Çözünürlük', 3, 0, 2),
  ('eski', 'AYT', 'Kimya', 'Tepkimelerde Enerji, Hız ve Denge', 'Kimyasal Tepkimelerde Enerji', 3, 1, 0),
  ('eski', 'AYT', 'Kimya', 'Tepkimelerde Enerji, Hız ve Denge', 'Kimyasal Tepkimelerde Hız', 3, 1, 1),
  ('eski', 'AYT', 'Kimya', 'Tepkimelerde Enerji, Hız ve Denge', 'Kimyasal Tepkimelerde Denge', 3, 1, 2),
  ('eski', 'AYT', 'Kimya', 'Elektrokimya ve Organik Kimya', 'Kimya ve Elektrik', 3, 2, 0),
  ('eski', 'AYT', 'Kimya', 'Elektrokimya ve Organik Kimya', 'Karbon Kimyasına Giriş', 3, 2, 1),
  ('eski', 'AYT', 'Kimya', 'Elektrokimya ve Organik Kimya', 'Organik Bileşikler', 3, 2, 2),
  ('eski', 'AYT', 'Kimya', 'Elektrokimya ve Organik Kimya', 'Enerji Kaynakları ve Bilimsel Gelişmeler', 3, 2, 3),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Sinir Sistemi', 4, 0, 0),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Endokrin Sistem', 4, 0, 1),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'İskelet Sistemi', 4, 0, 2),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Kas Sistemi', 4, 0, 3),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Duyu Organları', 4, 0, 4),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Kan Dolaşımı', 4, 0, 5),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Lenf Dolaşımı', 4, 0, 6),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Sindirim Sistemi', 4, 0, 7),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Solunum Sistemi', 4, 0, 8),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Üriner Sistem', 4, 0, 9),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Üreme Sistemi', 4, 0, 10),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Bağışıklık Sistemi', 4, 0, 11),
  ('eski', 'AYT', 'Biyoloji', 'İnsan Fizyolojisi', 'Embriyonik Gelişim', 4, 0, 12),
  ('eski', 'AYT', 'Biyoloji', 'Ekoloji', 'Komünite Ekolojisi', 4, 1, 0),
  ('eski', 'AYT', 'Biyoloji', 'Ekoloji', 'Popülasyon Ekolojisi', 4, 1, 1),
  ('eski', 'AYT', 'Biyoloji', 'Genetik ve Enerji Dönüşümleri', 'Nükleik Asitler', 4, 2, 0),
  ('eski', 'AYT', 'Biyoloji', 'Genetik ve Enerji Dönüşümleri', 'Genetik Şifre ve Protein Sentezi', 4, 2, 1),
  ('eski', 'AYT', 'Biyoloji', 'Genetik ve Enerji Dönüşümleri', 'Genetik Mühendisliği ve Biyoteknoloji', 4, 2, 2),
  ('eski', 'AYT', 'Biyoloji', 'Genetik ve Enerji Dönüşümleri', 'Canlılık ve Enerji', 4, 2, 3),
  ('eski', 'AYT', 'Biyoloji', 'Genetik ve Enerji Dönüşümleri', 'Fotosentez', 4, 2, 4),
  ('eski', 'AYT', 'Biyoloji', 'Genetik ve Enerji Dönüşümleri', 'Kemosentez', 4, 2, 5),
  ('eski', 'AYT', 'Biyoloji', 'Genetik ve Enerji Dönüşümleri', 'Hücresel Solunum', 4, 2, 6),
  ('eski', 'AYT', 'Biyoloji', 'Genetik ve Enerji Dönüşümleri', 'Fermantasyon', 4, 2, 7),
  ('eski', 'AYT', 'Biyoloji', 'Bitki Biyolojisi', 'Bitkisel Dokular', 4, 3, 0),
  ('eski', 'AYT', 'Biyoloji', 'Bitki Biyolojisi', 'Bitkisel Organlar', 4, 3, 1),
  ('eski', 'AYT', 'Biyoloji', 'Bitki Biyolojisi', 'Bitkilerde Madde Taşınması', 4, 3, 2),
  ('eski', 'AYT', 'Biyoloji', 'Bitki Biyolojisi', 'Bitkilerde Hareket', 4, 3, 3),
  ('eski', 'AYT', 'Biyoloji', 'Bitki Biyolojisi', 'Bitki Hormonları', 4, 3, 4),
  ('eski', 'AYT', 'Biyoloji', 'Bitki Biyolojisi', 'Bitkilerde Eşeyli Üreme', 4, 3, 5),
  ('eski', 'AYT', 'Biyoloji', 'Bitki Biyolojisi', 'Canlılar ve Çevre', 4, 3, 6),
  ('eski', 'AYT', 'Edebiyat', 'Giriş ve Genel Konular', 'Edebiyata Giriş', 5, 0, 0),
  ('eski', 'AYT', 'Edebiyat', 'Giriş ve Genel Konular', 'Şiir Bilgisi', 5, 0, 1),
  ('eski', 'AYT', 'Edebiyat', 'Giriş ve Genel Konular', 'Edebî Sanatlar', 5, 0, 2),
  ('eski', 'AYT', 'Edebiyat', 'Giriş ve Genel Konular', 'Edebî Akımlar', 5, 0, 3),
  ('eski', 'AYT', 'Edebiyat', 'Şiir', 'İslamiyet Öncesi Türk Şiiri', 5, 1, 0),
  ('eski', 'AYT', 'Edebiyat', 'Şiir', 'Geçiş Dönemi Türk Şiiri', 5, 1, 1),
  ('eski', 'AYT', 'Edebiyat', 'Şiir', 'Halk Şiiri', 5, 1, 2),
  ('eski', 'AYT', 'Edebiyat', 'Şiir', 'Divan Şiiri', 5, 1, 3),
  ('eski', 'AYT', 'Edebiyat', 'Şiir', 'Tanzimat Dönemi Türk Şiiri', 5, 1, 4),
  ('eski', 'AYT', 'Edebiyat', 'Şiir', 'Servetifünun Dönemi Türk Şiiri', 5, 1, 5),
  ('eski', 'AYT', 'Edebiyat', 'Şiir', 'Fecriati Dönemi Türk Şiiri', 5, 1, 6),
  ('eski', 'AYT', 'Edebiyat', 'Şiir', 'Millî Edebiyat Dönemi Türk Şiiri', 5, 1, 7),
  ('eski', 'AYT', 'Edebiyat', 'Şiir', 'Cumhuriyet Dönemi Türk Şiiri', 5, 1, 8),
  ('eski', 'AYT', 'Edebiyat', 'Hikâye', 'Hikâye Türleri ve Hikâyenin Yapı Unsurları', 5, 2, 0),
  ('eski', 'AYT', 'Edebiyat', 'Hikâye', 'Tanzimat Dönemi''ne Kadar Halk Hikâyesi ve Mesneviler', 5, 2, 1),
  ('eski', 'AYT', 'Edebiyat', 'Hikâye', 'Tanzimat ve Servetifünun Dönemi Türk Hikâyesi', 5, 2, 2),
  ('eski', 'AYT', 'Edebiyat', 'Hikâye', 'Millî Edebiyat Dönemi Türk Hikâyesi', 5, 2, 3),
  ('eski', 'AYT', 'Edebiyat', 'Hikâye', 'Cumhuriyet Dönemi Türk Hikâyesi', 5, 2, 4),
  ('eski', 'AYT', 'Edebiyat', 'Roman', 'Roman Türü ve Yapı Unsurları', 5, 3, 0),
  ('eski', 'AYT', 'Edebiyat', 'Roman', 'Tanzimat Dönemi Türk Romanı', 5, 3, 1),
  ('eski', 'AYT', 'Edebiyat', 'Roman', 'Servetifünun Dönemi Türk Romanı', 5, 3, 2),
  ('eski', 'AYT', 'Edebiyat', 'Roman', 'Millî Edebiyat Dönemi Türk Romanı', 5, 3, 3),
  ('eski', 'AYT', 'Edebiyat', 'Roman', 'Cumhuriyet Dönemi Türk Romanı', 5, 3, 4),
  ('eski', 'AYT', 'Edebiyat', 'Roman', 'Dünya Edebiyatında Roman', 5, 3, 5),
  ('eski', 'AYT', 'Edebiyat', 'Tiyatro', 'Tiyatro Türü ve Yapı Unsurları', 5, 4, 0),
  ('eski', 'AYT', 'Edebiyat', 'Tiyatro', 'Geleneksel Türk Tiyatrosu', 5, 4, 1),
  ('eski', 'AYT', 'Edebiyat', 'Tiyatro', 'Tanzimat, Servetifünun ve Millî Edebiyat Dönemi Türk Tiyatrosu', 5, 4, 2),
  ('eski', 'AYT', 'Edebiyat', 'Tiyatro', 'Cumhuriyet Dönemi Türk Tiyatrosu', 5, 4, 3),
  ('eski', 'AYT', 'Edebiyat', 'Diğer Türler', 'Masal/Fabl', 5, 5, 0),
  ('eski', 'AYT', 'Edebiyat', 'Diğer Türler', 'Destan/Efsane', 5, 5, 1),
  ('eski', 'AYT', 'Edebiyat', 'Diğer Türler', 'Öğretici Metinler', 5, 5, 2),
  ('eski', 'AYT', 'Edebiyat', 'Diğer Türler', 'Divan Edebiyatı Nesir Türleri', 5, 5, 3),
  ('eski', 'AYT', 'Tarih', 'Tarih Bilimi', 'Tarih ve Zaman', 6, 0, 0),
  ('eski', 'AYT', 'Tarih', 'İlk Çağlardan Türk-İslam Dünyasına', 'İlk ve Orta Çağlarda Türk Dünyası', 6, 1, 0),
  ('eski', 'AYT', 'Tarih', 'İlk Çağlardan Türk-İslam Dünyasına', 'İslam Medeniyetinin Doğuşu', 6, 1, 1),
  ('eski', 'AYT', 'Tarih', 'İlk Çağlardan Türk-İslam Dünyasına', 'Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet''i Kabulü', 6, 1, 2),
  ('eski', 'AYT', 'Tarih', 'İlk Çağlardan Türk-İslam Dünyasına', 'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi', 6, 1, 3),
  ('eski', 'AYT', 'Tarih', 'Osmanlı Tarihi', 'Beylikten Devlete Osmanlı Siyaseti (1302-1453)', 6, 2, 0),
  ('eski', 'AYT', 'Tarih', 'Osmanlı Tarihi', 'Devletleşme Sürecinde Savaşçılar ve Askerler', 6, 2, 1),
  ('eski', 'AYT', 'Tarih', 'Osmanlı Tarihi', 'Beylikten Devlete Osmanlı Medeniyeti', 6, 2, 2),
  ('eski', 'AYT', 'Tarih', 'Osmanlı Tarihi', 'Dünya Gücü Osmanlı (1453-1595)', 6, 2, 3),
  ('eski', 'AYT', 'Tarih', 'Osmanlı Tarihi', 'Sultan ve Osmanlı Merkez Teşkilatı', 6, 2, 4),
  ('eski', 'AYT', 'Tarih', 'Osmanlı Tarihi', 'Klasik Çağda Osmanlı Toplum Düzeni', 6, 2, 5),
  ('eski', 'AYT', 'Tarih', 'Osmanlı Tarihi', 'Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774)', 6, 2, 6),
  ('eski', 'AYT', 'Tarih', 'Osmanlı Tarihi', 'Değişim Çağında Avrupa ve Osmanlı', 6, 2, 7),
  ('eski', 'AYT', 'Tarih', 'Osmanlı Tarihi', 'Uluslararası İlişkilerde Denge Stratejisi (1774-1914)', 6, 2, 8),
  ('eski', 'AYT', 'Tarih', 'Yakın Çağ ve Cumhuriyet', 'Devrimler Çağında Değişen Devlet-Toplum İlişkileri', 6, 3, 0),
  ('eski', 'AYT', 'Tarih', 'Yakın Çağ ve Cumhuriyet', 'XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat', 6, 3, 1),
  ('eski', 'AYT', 'Tarih', 'Yakın Çağ ve Cumhuriyet', 'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya', 6, 3, 2),
  ('eski', 'AYT', 'Tarih', 'Yakın Çağ ve Cumhuriyet', 'Millî Mücadele', 6, 3, 3),
  ('eski', 'AYT', 'Tarih', 'Yakın Çağ ve Cumhuriyet', 'Atatürkçülük ve Türk İnkılabı', 6, 3, 4),
  ('eski', 'AYT', 'Tarih', 'Çağdaş Türkiye ve Dünya', 'İki Savaş Arasındaki Dönemde Türkiye ve Dünya', 6, 4, 0),
  ('eski', 'AYT', 'Tarih', 'Çağdaş Türkiye ve Dünya', 'II. Dünya Savaşı Sürecinde Türkiye ve Dünya', 6, 4, 1),
  ('eski', 'AYT', 'Tarih', 'Çağdaş Türkiye ve Dünya', 'II. Dünya Savaşı Sonrasında Türkiye ve Dünya', 6, 4, 2),
  ('eski', 'AYT', 'Tarih', 'Çağdaş Türkiye ve Dünya', 'Toplumsal Devrim Çağında Dünya ve Türkiye', 6, 4, 3),
  ('eski', 'AYT', 'Tarih', 'Çağdaş Türkiye ve Dünya', 'XXI. Yüzyılın Eşiğinde Türkiye ve Dünya', 6, 4, 4),
  ('eski', 'AYT', 'Coğrafya', 'Ekosistem ve Doğa', 'Ekosistemlerin İşleyişi ve Özellikleri', 7, 0, 0),
  ('eski', 'AYT', 'Coğrafya', 'Ekosistem ve Doğa', 'Ekstrem Doğa Olayları ve Doğa Olaylarının Geleceği', 7, 0, 1),
  ('eski', 'AYT', 'Coğrafya', 'Beşerî ve Ekonomik Sistemler', 'Nüfus Politikaları ve Yerleşmeler', 7, 1, 0),
  ('eski', 'AYT', 'Coğrafya', 'Beşerî ve Ekonomik Sistemler', 'Ekonomik Faaliyetler ve Doğal Kaynaklar', 7, 1, 1),
  ('eski', 'AYT', 'Coğrafya', 'Beşerî ve Ekonomik Sistemler', 'Türkiye''de Ekonomi', 7, 1, 2),
  ('eski', 'AYT', 'Coğrafya', 'Beşerî ve Ekonomik Sistemler', 'Ekonomi, Şehirleşme ve Göç', 7, 1, 3),
  ('eski', 'AYT', 'Coğrafya', 'Beşerî ve Ekonomik Sistemler', 'Ulaşım, Ticaret, Turizm', 7, 1, 4),
  ('eski', 'AYT', 'Coğrafya', 'Beşerî ve Ekonomik Sistemler', 'Türkiye''nin İşlevsel Bölgeleri ve Kalkınma Projeleri', 7, 1, 5),
  ('eski', 'AYT', 'Coğrafya', 'Kültür ve Küresel Ortam', 'Kültür Bölgeleri', 7, 2, 0),
  ('eski', 'AYT', 'Coğrafya', 'Kültür ve Küresel Ortam', 'Küreselleşen Dünya', 7, 2, 1),
  ('eski', 'AYT', 'Coğrafya', 'Kültür ve Küresel Ortam', 'Jeopolitik Konum ve Ülkeler Arası Etkileşim', 7, 2, 2),
  ('eski', 'AYT', 'Coğrafya', 'Çevre ve Toplum', 'Çevre Sorunları', 7, 3, 0),
  ('eski', 'AYT', 'Coğrafya', 'Çevre ve Toplum', 'Doğal Çevrenin Sınırlılığı, Çevresel Örgüt ve Anlaşmalar', 7, 3, 1),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'Felsefeyi Tanıma', 8, 0, 0),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'Felsefe ile Düşünme', 8, 0, 1),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'Felsefi Okuma ve Yazma', 8, 0, 2),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'Varlık Felsefesi', 8, 0, 3),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'Bilgi Felsefesi', 8, 0, 4),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'Bilim Felsefesi', 8, 0, 5),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'Ahlak Felsefesi', 8, 0, 6),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'Din Felsefesi', 8, 0, 7),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'Siyaset Felsefesi', 8, 0, 8),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'Sanat Felsefesi', 8, 0, 9),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi', 8, 0, 10),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', 'MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi', 8, 0, 11),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', '15. Yüzyıl-17. Yüzyıl Felsefesi', 8, 0, 12),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', '18. Yüzyıl-19. Yüzyıl Felsefesi', 8, 0, 13),
  ('eski', 'AYT', 'Felsefe Grubu', 'Felsefe', '20. Yüzyıl Felsefesi', 8, 0, 14),
  ('eski', 'AYT', 'Felsefe Grubu', 'Mantık', 'Mantığa Giriş', 8, 1, 0),
  ('eski', 'AYT', 'Felsefe Grubu', 'Mantık', 'Klasik Mantık', 8, 1, 1),
  ('eski', 'AYT', 'Felsefe Grubu', 'Mantık', 'Mantık ve Dil', 8, 1, 2),
  ('eski', 'AYT', 'Felsefe Grubu', 'Mantık', 'Sembolik Mantık', 8, 1, 3),
  ('eski', 'AYT', 'Felsefe Grubu', 'Psikoloji', 'Psikoloji Bilimini Tanıyalım', 8, 2, 0),
  ('eski', 'AYT', 'Felsefe Grubu', 'Psikoloji', 'Psikolojinin Temel Süreçleri', 8, 2, 1),
  ('eski', 'AYT', 'Felsefe Grubu', 'Psikoloji', 'Öğrenme, Bellek, Düşünme', 8, 2, 2),
  ('eski', 'AYT', 'Felsefe Grubu', 'Psikoloji', 'Ruh Sağlığının Temelleri', 8, 2, 3),
  ('eski', 'AYT', 'Felsefe Grubu', 'Sosyoloji', 'Sosyolojiye Giriş', 8, 3, 0),
  ('eski', 'AYT', 'Felsefe Grubu', 'Sosyoloji', 'Toplumsal Yapı', 8, 3, 1),
  ('eski', 'AYT', 'Felsefe Grubu', 'Sosyoloji', 'Birey ve Toplum', 8, 3, 2),
  ('eski', 'AYT', 'Felsefe Grubu', 'Sosyoloji', 'Toplum ve Kültür', 8, 3, 3),
  ('eski', 'AYT', 'Felsefe Grubu', 'Sosyoloji', 'Toplumsal Kurumlar', 8, 3, 4),
  ('eski', 'AYT', 'Felsefe Grubu', 'Sosyoloji', 'Toplumsal Değişme ve Gelişme', 8, 3, 5),
  ('eski', 'AYT', 'Din Kültürü', 'İnanç ve İbadet', 'Dünya ve Ahiret', 9, 0, 0),
  ('eski', 'AYT', 'Din Kültürü', 'İnanç ve İbadet', 'İnançla İlgili Meseleler', 9, 0, 1),
  ('eski', 'AYT', 'Din Kültürü', 'Kur''an ve Hz. Muhammed', 'Kur''an''a Göre Hz. Muhammed', 9, 1, 0),
  ('eski', 'AYT', 'Din Kültürü', 'Kur''an ve Hz. Muhammed', 'Kur''an''da Bazı Kavramlar', 9, 1, 1),
  ('eski', 'AYT', 'Din Kültürü', 'Dinler ve Kültür', 'Yahudilik ve Hristiyanlık', 9, 2, 0),
  ('eski', 'AYT', 'Din Kültürü', 'Dinler ve Kültür', 'Hint ve Çin Dinleri', 9, 2, 1),
  ('eski', 'AYT', 'Din Kültürü', 'Dinler ve Kültür', 'Anadolu''da İslam', 9, 2, 2),
  ('eski', 'AYT', 'Din Kültürü', 'İslam Düşüncesi', 'İslam ve Bilim', 9, 3, 0),
  ('eski', 'AYT', 'Din Kültürü', 'İslam Düşüncesi', 'İslam Düşüncesinde Tasavvufi Yorumlar', 9, 3, 1),
  ('eski', 'AYT', 'Din Kültürü', 'İslam Düşüncesi', 'Güncel Dinî Meseleler', 9, 3, 2),
  ('maarif', 'TYT', 'Türkçe', 'Metin Türleri', 'Şiir', 0, 0, 0),
  ('maarif', 'TYT', 'Türkçe', 'Metin Türleri', 'Öyküleyici Metin', 0, 0, 1),
  ('maarif', 'TYT', 'Türkçe', 'Metin Türleri', 'Tiyatro', 0, 0, 2),
  ('maarif', 'TYT', 'Türkçe', 'Metin Türleri', 'Öğretici Metin', 0, 0, 3),
  ('maarif', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Ses Bilgisi', 0, 1, 0),
  ('maarif', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Yapı Bilgisi (Ekler)', 0, 1, 1),
  ('maarif', 'TYT', 'Türkçe', 'Dil Bilgisi', 'İsim ve Sıfat', 0, 1, 2),
  ('maarif', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Zamir-Zarf-Edat', 0, 1, 3),
  ('maarif', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Fiil ve Fiilimsi', 0, 1, 4),
  ('maarif', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Cümlenin Ögeleri', 0, 1, 5),
  ('maarif', 'TYT', 'Türkçe', 'Dil Bilgisi', 'Anlatım Bozuklukları', 0, 1, 6),
  ('maarif', 'TYT', 'Matematik', 'Sayılar', 'Üslü İfadeler', 1, 0, 0),
  ('maarif', 'TYT', 'Matematik', 'Sayılar', 'Köklü İfadeler', 1, 0, 1),
  ('maarif', 'TYT', 'Matematik', 'Sayılar', 'Sayı Kümeleri', 1, 0, 2),
  ('maarif', 'TYT', 'Matematik', 'Sayılar', 'Özdeşlikler (İki Kare Farkı-Tam Kare)', 1, 0, 3),
  ('maarif', 'TYT', 'Matematik', 'Nicelikler ve Değişimler', 'Doğrusal Fonksiyonlar', 1, 1, 0),
  ('maarif', 'TYT', 'Matematik', 'Nicelikler ve Değişimler', 'Mutlak Değer', 1, 1, 1),
  ('maarif', 'TYT', 'Matematik', 'Nicelikler ve Değişimler', 'Denklem-Eşitsizlik', 1, 1, 2),
  ('maarif', 'TYT', 'Matematik', 'Nicelikler ve Değişimler', 'Fonksiyonlar ve Denklemler', 1, 1, 3),
  ('maarif', 'TYT', 'Matematik', 'Mantıksal Çıkarım', 'Mantıksal Çıkarım', 1, 2, 0),
  ('maarif', 'TYT', 'Matematik', 'Mantıksal Çıkarım', 'Algoritma ve Bilişim', 1, 2, 1),
  ('maarif', 'TYT', 'Matematik', 'Trigonometri', 'Trigonometriye Giriş', 1, 3, 0),
  ('maarif', 'TYT', 'Matematik', 'Veriden Olasılığa', 'Veriden Olasılığa', 1, 4, 0),
  ('maarif', 'TYT', 'Geometri', 'Üçgenler', 'Üçgende Eşlik ve Benzerlik', 2, 0, 0),
  ('maarif', 'TYT', 'Geometri', 'Çokgenler ve Dörtgenler', 'Çokgenler', 2, 1, 0),
  ('maarif', 'TYT', 'Geometri', 'Çokgenler ve Dörtgenler', 'Dörtgenler', 2, 1, 1),
  ('maarif', 'TYT', 'Geometri', 'Çember', 'Çember', 2, 2, 0),
  ('maarif', 'TYT', 'Geometri', 'Analitik Geometri', 'Analitik Geometriye Giriş', 2, 3, 0),
  ('maarif', 'TYT', 'Fizik', 'Fizik Bilimi', 'Fizik Bilimi ve Kariyer', 3, 0, 0),
  ('maarif', 'TYT', 'Fizik', 'Kuvvet ve Hareket', 'Kuvvet ve Hareket', 3, 1, 0),
  ('maarif', 'TYT', 'Fizik', 'Akışkanlar', 'Akışkanlar (Basınç)', 3, 2, 0),
  ('maarif', 'TYT', 'Fizik', 'Akışkanlar', 'Akışkanlar (Kaldırma Kuvveti-Bernoulli)', 3, 2, 1),
  ('maarif', 'TYT', 'Fizik', 'Enerji', 'Enerji (Isı-Hâl Değişimi)', 3, 3, 0),
  ('maarif', 'TYT', 'Fizik', 'Elektrik', 'Elektrik', 3, 4, 0),
  ('maarif', 'TYT', 'Fizik', 'Dalgalar', 'Dalgalar', 3, 5, 0),
  ('maarif', 'TYT', 'Kimya', 'Etkileşim', 'Kimya Hayattır', 4, 0, 0),
  ('maarif', 'TYT', 'Kimya', 'Etkileşim', 'Atomdan Periyodik Tabloya', 4, 0, 1),
  ('maarif', 'TYT', 'Kimya', 'Etkileşim', 'Kimyasal Türler Arası Etkileşimler', 4, 0, 2),
  ('maarif', 'TYT', 'Kimya', 'Çeşitlilik', 'Kimyasal Tepkimeler', 4, 1, 0),
  ('maarif', 'TYT', 'Kimya', 'Çeşitlilik', 'Gazlar', 4, 1, 1),
  ('maarif', 'TYT', 'Kimya', 'Çeşitlilik', 'Çözeltiler', 4, 1, 2),
  ('maarif', 'TYT', 'Kimya', 'Çeşitlilik', 'Redoks (Etkileşim)', 4, 1, 3),
  ('maarif', 'TYT', 'Kimya', 'Sürdürülebilirlik', 'Sürdürülebilirlik', 4, 2, 0),
  ('maarif', 'TYT', 'Biyoloji', 'Yaşam', 'Canlıların Ortak Özellikleri', 5, 0, 0),
  ('maarif', 'TYT', 'Biyoloji', 'Yaşam', 'Üç Âlem/Domain Sistemi', 5, 0, 1),
  ('maarif', 'TYT', 'Biyoloji', 'Organizasyon', 'Hücre', 5, 1, 0),
  ('maarif', 'TYT', 'Biyoloji', 'Organizasyon', 'Organik Moleküller', 5, 1, 1),
  ('maarif', 'TYT', 'Biyoloji', 'Enerji', 'Fotosentez', 5, 2, 0),
  ('maarif', 'TYT', 'Biyoloji', 'Enerji', 'Hücresel Solunum', 5, 2, 1),
  ('maarif', 'TYT', 'Biyoloji', 'Ekoloji', 'Ekosistem Ekolojisi', 5, 3, 0),
  ('maarif', 'TYT', 'Tarih', 'Tarih Bilimi', 'Geçmişin İnşa Sürecinde Tarih', 6, 0, 0),
  ('maarif', 'TYT', 'Tarih', 'Tarih Bilimi', 'Medeniyet/Uygarlık Tarihi', 6, 0, 1),
  ('maarif', 'TYT', 'Tarih', 'Türk Tarihi', 'Türkistan''dan Türkiye''ye', 6, 1, 0),
  ('maarif', 'TYT', 'Tarih', 'Türk Tarihi', 'Beylikten Devlete Osmanlı', 6, 1, 1),
  ('maarif', 'TYT', 'Tarih', 'Türk Tarihi', 'Cihan Devleti Osmanlı (İstanbul''un Fethi)', 6, 1, 2),
  ('maarif', 'TYT', 'Coğrafya', 'Coğrafi Beceriler', 'Coğrafyanın Doğası', 7, 0, 0),
  ('maarif', 'TYT', 'Coğrafya', 'Coğrafi Beceriler', 'Mekânsal Bilgi Teknolojileri', 7, 0, 1),
  ('maarif', 'TYT', 'Coğrafya', 'Doğal Sistemler', 'Doğal Sistemler ve Süreçler (İklim)', 7, 1, 0),
  ('maarif', 'TYT', 'Coğrafya', 'Beşerî Sistemler', 'Beşerî Sistemler ve Süreçler', 7, 2, 0),
  ('maarif', 'TYT', 'Coğrafya', 'Beşerî Sistemler', 'Ekonomik Faaliyetler ve Etkileri', 7, 2, 1),
  ('maarif', 'TYT', 'Coğrafya', 'Çevre ve Küresel Bağlantılar', 'Afetler ve Sürdürülebilir Çevre', 7, 3, 0),
  ('maarif', 'TYT', 'Coğrafya', 'Çevre ve Küresel Bağlantılar', 'Bölgesel/Küresel Bağlantılar', 7, 3, 1),
  ('maarif', 'TYT', 'Felsefe', 'Felsefeye Giriş', 'Felsefeye Giriş', 8, 0, 0),
  ('maarif', 'TYT', 'Felsefe', 'Felsefeye Giriş', 'Felsefe ile Düşünme (Argümantasyon)', 8, 0, 1),
  ('maarif', 'TYT', 'Felsefe', 'Felsefenin Temel Konuları', 'Bilgi Felsefesi', 8, 1, 0),
  ('maarif', 'TYT', 'Felsefe', 'Felsefenin Temel Konuları', 'Bilim Felsefesi', 8, 1, 1),
  ('maarif', 'TYT', 'Felsefe', 'Felsefenin Temel Konuları', 'Ahlak Felsefesi', 8, 1, 2),
  ('maarif', 'TYT', 'Din Kültürü', 'İnanç', 'Allah-İnsan İlişkisi', 9, 0, 0),
  ('maarif', 'TYT', 'Din Kültürü', 'İnanç', 'İslam''da İnanç Esasları', 9, 0, 1),
  ('maarif', 'TYT', 'Din Kültürü', 'İnanç', 'İslam''da Varlık ve Bilgi', 9, 0, 2),
  ('maarif', 'TYT', 'Din Kültürü', 'İbadet ve Ahlak', 'İslam''da İbadetler', 9, 1, 0),
  ('maarif', 'TYT', 'Din Kültürü', 'İbadet ve Ahlak', 'İslam''da Ahlak İlkeleri', 9, 1, 1),
  ('maarif', 'TYT', 'Din Kültürü', 'Hz. Muhammed ve Güncel Konular', 'Kur''an''a Göre Hz. Muhammed', 9, 2, 0),
  ('maarif', 'TYT', 'Din Kültürü', 'Hz. Muhammed ve Güncel Konular', 'Din, Çevre ve Teknoloji', 9, 2, 1),
  ('maarif', 'AYT', 'Matematik', 'Nicelikler ve Değişimler', 'Nicelikler ve Değişimler', 0, 0, 0),
  ('maarif', 'AYT', 'Matematik', 'İstatistiksel Araştırma', 'İstatistiksel Araştırma Süreci', 0, 1, 0),
  ('maarif', 'AYT', 'Matematik', 'Analiz', 'Türev', 0, 2, 0),
  ('maarif', 'AYT', 'Matematik', 'Analiz', 'İntegral', 0, 2, 1),
  ('maarif', 'AYT', 'Matematik', 'Analiz', 'Logaritma', 0, 2, 2),
  ('maarif', 'AYT', 'Geometri', 'Geometrik Şekiller', 'Geometrik Şekiller', 1, 0, 0),
  ('maarif', 'AYT', 'Fizik', 'Kuvvet ve Hareket', 'Kuvvet ve Hareket (Newton Yasaları)', 2, 0, 0),
  ('maarif', 'AYT', 'Fizik', 'Kuvvet ve Hareket', 'Çembersel Hareket', 2, 0, 1),
  ('maarif', 'AYT', 'Fizik', 'Elektrik ve Manyetizma', 'Elektriksel ve Manyetik Alan', 2, 1, 0),
  ('maarif', 'AYT', 'Fizik', 'Elektrik ve Manyetizma', 'İndüksiyon ve Transformatörler', 2, 1, 1),
  ('maarif', 'AYT', 'Fizik', 'Madde ve Doğası', 'Madde ve Doğası (Yarı İletkenler)', 2, 2, 0),
  ('maarif', 'AYT', 'Fizik', 'Optik, Enerji ve Dalgalar', 'Optik', 2, 3, 0),
  ('maarif', 'AYT', 'Fizik', 'Optik, Enerji ve Dalgalar', 'Enerji', 2, 3, 1),
  ('maarif', 'AYT', 'Fizik', 'Optik, Enerji ve Dalgalar', 'Dalgalar', 2, 3, 2),
  ('maarif', 'AYT', 'Kimya', 'Tepkimeler', 'Kimyasal Tepkimeler ve Enerji', 3, 0, 0),
  ('maarif', 'AYT', 'Kimya', 'Tepkimeler', 'Tepkime Hızı', 3, 0, 1),
  ('maarif', 'AYT', 'Kimya', 'Tepkimeler', 'Kimyasal Denge', 3, 0, 2),
  ('maarif', 'AYT', 'Kimya', 'Çözeltilerde Denge', 'Asit-Baz Dengeleri', 3, 1, 0),
  ('maarif', 'AYT', 'Kimya', 'Sürdürülebilirlik', 'Sürdürülebilirlik (Yeşil Kimya)', 3, 2, 0),
  ('maarif', 'AYT', 'Biyoloji', 'Tepki', 'Sinir Sistemi ve Refleks', 4, 0, 0),
  ('maarif', 'AYT', 'Biyoloji', 'Tepki', 'İskelet-Kas-Eklem Sistemi', 4, 0, 1),
  ('maarif', 'AYT', 'Biyoloji', 'Tepki', 'Bağışıklık ve Alerji', 4, 0, 2),
  ('maarif', 'AYT', 'Biyoloji', 'Homeostazi', 'Endokrin Sistem', 4, 1, 0),
  ('maarif', 'AYT', 'Biyoloji', 'Homeostazi', 'Dolaşım Sistemi', 4, 1, 1),
  ('maarif', 'AYT', 'Biyoloji', 'Homeostazi', 'Solunum Sistemi', 4, 1, 2),
  ('maarif', 'AYT', 'Biyoloji', 'Homeostazi', 'Boşaltım Sistemi', 4, 1, 3),
  ('maarif', 'AYT', 'Biyoloji', 'Homeostazi', 'Denge Bozuklukları (Diyabet-Hipertansiyon-Obezite)', 4, 1, 4),
  ('maarif', 'AYT', 'Edebiyat', 'Bir Diyeceğim Var!', 'Mektup-Dilekçe-E-posta', 5, 0, 0),
  ('maarif', 'AYT', 'Edebiyat', 'Bir Diyeceğim Var!', 'Geleneksel Türk Tiyatrosu', 5, 0, 1),
  ('maarif', 'AYT', 'Edebiyat', 'Kültür Yolculuğu', 'Orhun Abideleri ve Geçiş Dönemi', 5, 1, 0),
  ('maarif', 'AYT', 'Edebiyat', 'Kültür Yolculuğu', 'Âşık Tarzı Halk Şiiri', 5, 1, 1),
  ('maarif', 'AYT', 'Edebiyat', 'Kültür Yolculuğu', 'Halk Hikâyesi', 5, 1, 2),
  ('maarif', 'AYT', 'Edebiyat', 'Yaşamın İzinde', 'Roman', 5, 2, 0),
  ('maarif', 'AYT', 'Edebiyat', 'Yaşamın İzinde', 'Biyografi ve Tezkire', 5, 2, 1),
  ('maarif', 'AYT', 'Edebiyat', 'Yaşamın İzinde', 'Radyo Tiyatrosu', 5, 2, 2),
  ('maarif', 'AYT', 'Edebiyat', 'Hayatın Aynası', 'Modern Türk Tiyatrosu', 5, 3, 0),
  ('maarif', 'AYT', 'Edebiyat', 'Hayatın Aynası', 'Küçürek Hikâye', 5, 3, 1),
  ('maarif', 'AYT', 'Edebiyat', 'Hayatın Aynası', 'Belgesel', 5, 3, 2),
  ('maarif', 'AYT', 'Tarih', 'Osmanlı ve Değişim', 'Osmanlı''da Gerileme ve Değişim', 6, 0, 0),
  ('maarif', 'AYT', 'Tarih', 'Osmanlı ve Değişim', 'Fransız İhtilali ve Milliyetçilik', 6, 0, 1),
  ('maarif', 'AYT', 'Tarih', 'Savaşlar Çağı', 'Balkan Savaşları', 6, 1, 0),
  ('maarif', 'AYT', 'Tarih', 'Savaşlar Çağı', 'I. Dünya Savaşı''na Giden Süreç', 6, 1, 1),
  ('maarif', 'AYT', 'Coğrafya', 'Beşerî Coğrafya', 'İleri Nüfus', 7, 0, 0),
  ('maarif', 'AYT', 'Coğrafya', 'Beşerî Coğrafya', 'İleri Yerleşme', 7, 0, 1),
  ('maarif', 'AYT', 'Coğrafya', 'Ekonomik Coğrafya', 'Ekonomik Coğrafya', 7, 1, 0);

insert into public.curriculum_aliases
  (curriculum, exam, subject, alias, topic, kind, src_exam)
values
  ('eski', 'TYT', 'Türkçe', 'Edat-Bağlaç-Ünlem', 'Sözcük Türleri', 'eski', null),
  ('eski', 'TYT', 'Türkçe', 'Sıfat', 'Sözcük Türleri', 'eski', null),
  ('eski', 'TYT', 'Türkçe', 'Zamir', 'Sözcük Türleri', 'eski', null),
  ('eski', 'TYT', 'Türkçe', 'Zarf', 'Sözcük Türleri', 'eski', null),
  ('eski', 'TYT', 'Türkçe', 'İsim (Ad)', 'Sözcük Türleri', 'eski', null),
  ('eski', 'TYT', 'Türkçe', 'Fiilde Anlam (Kip-Kişi)', 'Fiiller', 'eski', null),
  ('eski', 'TYT', 'Türkçe', 'Fiilimsi', 'Fiiller', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'Mantık', 'Önermeler ve Bileşik Önermeler', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'Kümeler', 'Kümelerde Temel Kavramlar', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'rasyonel sayılar', 'Sayı Kümeleri', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'irrasyonel sayılar', 'Sayı Kümeleri', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'tam sayılar', 'Sayı Kümeleri', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'mutlak değer', 'Sayı Kümeleri', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'Temel Kavramlar', 'Sayı Kümeleri', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'asal çarpan', 'Bölünebilme Kuralları', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'ebob', 'Bölünebilme Kuralları', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'ekok', 'Bölünebilme Kuralları', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'kalan bulma', 'Bölünebilme Kuralları', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'Bölme-Bölünebilme', 'Bölünebilme Kuralları', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'Basit Eşitsizlikler', 'Birinci Dereceden Denklemler ve Eşitsizlikler', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'üs', 'Üslü İfadeler ve Denklemler', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'köklü ifadeler', 'Üslü İfadeler ve Denklemler', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'Üslü Sayılar', 'Üslü İfadeler ve Denklemler', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'problemler', 'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'yaş problemi', 'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'hız problemi', 'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'işçi problemi', 'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'yüzde', 'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'oran orantı', 'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'kâr zarar', 'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'karışım', 'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'Sayı Problemleri', 'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'ortalama', 'Merkezi Eğilim ve Yayılım Ölçüleri', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'medyan', 'Merkezi Eğilim ve Yayılım Ölçüleri', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'mod', 'Merkezi Eğilim ve Yayılım Ölçüleri', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'standart sapma', 'Merkezi Eğilim ve Yayılım Ölçüleri', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'açıklık', 'Merkezi Eğilim ve Yayılım Ölçüleri', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'İstatistik', 'Merkezi Eğilim ve Yayılım Ölçüleri', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'permütasyon', 'Sıralama ve Seçme', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'kombinasyon', 'Sıralama ve Seçme', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'faktöriyel', 'Sıralama ve Seçme', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'Permütasyon-Kombinasyon', 'Sıralama ve Seçme', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'olasılık', 'Basit Olayların Olasılıkları', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'zar', 'Basit Olayların Olasılıkları', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'madeni para', 'Basit Olayların Olasılıkları', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'Olasılık', 'Basit Olayların Olasılıkları', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'Fonksiyonlar', 'Fonksiyon Kavramı ve Gösterimi', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'Polinomlar', 'Polinom Kavramı ve Polinomlarda İşlemler', 'eski', null),
  ('eski', 'TYT', 'Matematik', 'özdeşlikler', 'Polinomların Çarpanlara Ayrılması', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'iki kare farkı', 'Polinomların Çarpanlara Ayrılması', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'tam kare', 'Polinomların Çarpanlara Ayrılması', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'çarpanlara ayırma', 'Polinomların Çarpanlara Ayrılması', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'diskriminant', 'İkinci Dereceden Bir Bilinmeyenli Denklemler', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'kökler toplamı', 'İkinci Dereceden Bir Bilinmeyenli Denklemler', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'parabol', 'İkinci Dereceden Bir Bilinmeyenli Denklemler', 'ara', null),
  ('eski', 'TYT', 'Matematik', 'İkinci Dereceden Denklemler', 'İkinci Dereceden Bir Bilinmeyenli Denklemler', 'eski', null),
  ('eski', 'TYT', 'Geometri', 'Üçgende Açılar', 'Üçgenlerde Temel Kavramlar', 'eski', null),
  ('eski', 'TYT', 'Geometri', 'benzerlik', 'Üçgenlerde Eşlik ve Benzerlik', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'thales', 'Üçgenlerde Eşlik ve Benzerlik', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'eşlik', 'Üçgenlerde Eşlik ve Benzerlik', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'Üçgende Benzerlik', 'Üçgenlerde Eşlik ve Benzerlik', 'eski', null),
  ('eski', 'TYT', 'Geometri', 'açıortay', 'Üçgenin Yardımcı Elemanları', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'kenarortay', 'Üçgenin Yardımcı Elemanları', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'yükseklik', 'Üçgenin Yardımcı Elemanları', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'iç teğet çember', 'Üçgenin Yardımcı Elemanları', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'Açıortay', 'Üçgenin Yardımcı Elemanları', 'eski', null),
  ('eski', 'TYT', 'Geometri', 'Kenarortay', 'Üçgenin Yardımcı Elemanları', 'eski', null),
  ('eski', 'TYT', 'Geometri', 'pisagor', 'Dik Üçgen ve Trigonometri', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'öklid', 'Dik Üçgen ve Trigonometri', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'özel üçgenler', 'Dik Üçgen ve Trigonometri', 'ara', null),
  ('eski', 'TYT', 'Geometri', '30-60-90', 'Dik Üçgen ve Trigonometri', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'Dik Üçgen', 'Dik Üçgen ve Trigonometri', 'eski', null),
  ('eski', 'TYT', 'Geometri', 'Üçgende Alan', 'Üçgenin Alanı', 'eski', null),
  ('eski', 'TYT', 'Geometri', 'beşgen', 'Çokgenler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'altıgen', 'Çokgenler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'iç açılar toplamı', 'Çokgenler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'düzgün çokgen', 'Çokgenler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'paralelkenar', 'Özel Dörtgenler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'eşkenar dörtgen', 'Özel Dörtgenler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'yamuk', 'Özel Dörtgenler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'dikdörtgen', 'Özel Dörtgenler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'kare', 'Özel Dörtgenler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'deltoid', 'Özel Dörtgenler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'Dikdörtgen ve Kare', 'Özel Dörtgenler', 'eski', null),
  ('eski', 'TYT', 'Geometri', 'Paralelkenar', 'Özel Dörtgenler', 'eski', null),
  ('eski', 'TYT', 'Geometri', 'prizma', 'Katı Cisimler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'piramit', 'Katı Cisimler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'küp', 'Katı Cisimler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'silindir', 'Katı Cisimler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'koni', 'Katı Cisimler', 'ara', null),
  ('eski', 'TYT', 'Geometri', 'küre', 'Katı Cisimler', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'özkütle', 'Madde ve Özellikleri', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'yoğunluk', 'Madde ve Özellikleri', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'adezyon', 'Madde ve Özellikleri', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'kohezyon', 'Madde ve Özellikleri', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'yüzey gerilimi', 'Madde ve Özellikleri', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'atışlar', 'Hareket ve Kuvvet', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'eğik atış', 'Hareket ve Kuvvet', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'dikey atış', 'Hareket ve Kuvvet', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'yatay atış', 'Hareket ve Kuvvet', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'newton yasaları', 'Hareket ve Kuvvet', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'ivme', 'Hareket ve Kuvvet', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'sürtünme kuvveti', 'Hareket ve Kuvvet', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'hız-zaman grafiği', 'Hareket ve Kuvvet', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'Basit Makineler', 'Hareket ve Kuvvet', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'Doğrusal Hareket', 'Hareket ve Kuvvet', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'Kuvvet ve Denge (Vektörler)', 'Hareket ve Kuvvet', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'iş', 'Enerji', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'güç', 'Enerji', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'kinetik enerji', 'Enerji', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'potansiyel enerji', 'Enerji', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'verim', 'Enerji', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'İş-Güç-Enerji', 'Enerji', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'arşimet', 'Basınç ve Kaldırma Kuvveti', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'akışkanlar', 'Basınç ve Kaldırma Kuvveti', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'bernoulli', 'Basınç ve Kaldırma Kuvveti', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'sıvı basıncı', 'Basınç ve Kaldırma Kuvveti', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'gaz basıncı', 'Basınç ve Kaldırma Kuvveti', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'Basınç', 'Basınç ve Kaldırma Kuvveti', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'Sıvıların Kaldırma Kuvveti', 'Basınç ve Kaldırma Kuvveti', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'genleşme', 'Isı ve Sıcaklık', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'hâl değişimi', 'Isı ve Sıcaklık', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'kalorimetre', 'Isı ve Sıcaklık', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'öz ısı', 'Isı ve Sıcaklık', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'yük', 'Elektrostatik', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'coulomb', 'Elektrostatik', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'elektroskop', 'Elektrostatik', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'topraklama', 'Elektrostatik', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'devre', 'Elektrik ve Manyetizma', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'direnç', 'Elektrik ve Manyetizma', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'ohm kanunu', 'Elektrik ve Manyetizma', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'kondansatör', 'Elektrik ve Manyetizma', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'mıknatıs', 'Elektrik ve Manyetizma', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'ampul', 'Elektrik ve Manyetizma', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'Elektrik Akımı ve Devreler', 'Elektrik ve Manyetizma', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'Mıknatıslar ve Manyetik Alan', 'Elektrik ve Manyetizma', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'ses dalgası', 'Dalgalar', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'su dalgası', 'Dalgalar', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'yay dalgası', 'Dalgalar', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'deprem dalgası', 'Dalgalar', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'Dalgalar (Temel)', 'Dalgalar', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'Yay ve Su Dalgaları', 'Dalgalar', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'mercek', 'Optik', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'ayna', 'Optik', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'kırılma', 'Optik', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'yansıma', 'Optik', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'gölge', 'Optik', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'prizma', 'Optik', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'renk', 'Optik', 'ara', null),
  ('eski', 'TYT', 'Fizik', 'Düzlem Ayna', 'Optik', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'Işık ve Gölge', 'Optik', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'Küresel Aynalar', 'Optik', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'Kırılma ve Renkler', 'Optik', 'eski', null),
  ('eski', 'TYT', 'Fizik', 'Mercekler', 'Optik', 'eski', null),
  ('eski', 'TYT', 'Kimya', 'Kimya Bilimine Giriş', 'Kimya Bilimi', 'eski', null),
  ('eski', 'TYT', 'Kimya', 'Atomun Yapısı', 'Atom ve Periyodik Sistem', 'eski', null),
  ('eski', 'TYT', 'Kimya', 'Periyodik Sistem', 'Atom ve Periyodik Sistem', 'eski', null),
  ('eski', 'TYT', 'Kimya', 'Kovalent Bağ', 'Kimyasal Türler Arası Etkileşimler', 'eski', null),
  ('eski', 'TYT', 'Kimya', 'Metalik Bağ ve Zayıf Etkileşimler', 'Kimyasal Türler Arası Etkileşimler', 'eski', null),
  ('eski', 'TYT', 'Kimya', 'İyonik Bağ', 'Kimyasal Türler Arası Etkileşimler', 'eski', null),
  ('eski', 'TYT', 'Kimya', 'Maddenin Halleri', 'Maddenin Hâlleri', 'eski', null),
  ('eski', 'TYT', 'Kimya', 'Kimyanın Temel Kanunları', 'Kimyanın Temel Kanunları ve Kimyasal Hesaplamalar', 'eski', null),
  ('eski', 'TYT', 'Kimya', 'Mol Kavramı ve Hesaplamalar', 'Kimyanın Temel Kanunları ve Kimyasal Hesaplamalar', 'eski', null),
  ('eski', 'TYT', 'Kimya', 'Asit-Baz', 'Asitler, Bazlar ve Tuzlar', 'eski', null),
  ('eski', 'TYT', 'Biyoloji', 'İnorganik Bileşikler', 'Canlıların Yapısında Bulunan İnorganik Bileşikler', 'eski', null),
  ('eski', 'TYT', 'Biyoloji', 'Enzimler', 'Canlıların Yapısında Bulunan Organik Bileşikler', 'eski', null),
  ('eski', 'TYT', 'Biyoloji', 'Nükleik Asitler', 'Canlıların Yapısında Bulunan Organik Bileşikler', 'eski', null),
  ('eski', 'TYT', 'Biyoloji', 'Organik Bileşikler (Karbonhidrat-Lipit-Protein)', 'Canlıların Yapısında Bulunan Organik Bileşikler', 'eski', null),
  ('eski', 'TYT', 'Biyoloji', 'organel', 'Hücresel Yapılar ve Görevleri', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'mitokondri', 'Hücresel Yapılar ve Görevleri', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'ribozom', 'Hücresel Yapılar ve Görevleri', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'çekirdek', 'Hücresel Yapılar ve Görevleri', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'Hücre ve Organelleri', 'Hücresel Yapılar ve Görevleri', 'eski', null),
  ('eski', 'TYT', 'Biyoloji', 'difüzyon', 'Hücre Zarından Madde Geçişleri', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'osmoz', 'Hücre Zarından Madde Geçişleri', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'aktif taşıma', 'Hücre Zarından Madde Geçişleri', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'endositoz', 'Hücre Zarından Madde Geçişleri', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'Hücre Zarından Madde Geçişi', 'Hücre Zarından Madde Geçişleri', 'eski', null),
  ('eski', 'TYT', 'Biyoloji', 'mitoz', 'Hücre Döngüsü ve Mitoz', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'hücre bölünmesi', 'Hücre Döngüsü ve Mitoz', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'Mitoz ve Eşeysiz Üreme', 'Hücre Döngüsü ve Mitoz', 'eski', null),
  ('eski', 'TYT', 'Biyoloji', 'krossing over', 'Mayoz', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'mayoz bölünme', 'Mayoz', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'Mayoz ve Eşeyli Üreme', 'Mayoz', 'eski', null),
  ('eski', 'TYT', 'Biyoloji', 'sınıflandırma', 'Canlıların Sınıflandırılması', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'taksonomi', 'Canlıların Sınıflandırılması', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'mendel', 'Kalıtım', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'genetik', 'Kalıtım', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'çaprazlama', 'Kalıtım', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'kan grupları', 'Kalıtım', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'besin zinciri', 'Ekosistem Ekolojisi', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'madde döngüsü', 'Ekosistem Ekolojisi', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'enerji piramidi', 'Ekosistem Ekolojisi', 'ara', null),
  ('eski', 'TYT', 'Biyoloji', 'Madde Döngüleri', 'Ekosistem Ekolojisi', 'eski', null),
  ('eski', 'TYT', 'Tarih', 'İnsanlığın İlk Dönemleri', 'Tarih ve Zaman', 'eski', null),
  ('eski', 'TYT', 'Tarih', 'Orta Çağ''da Dünya', 'İlk ve Orta Çağlarda Türk Dünyası', 'eski', null),
  ('eski', 'TYT', 'Tarih', 'Türklerin İslamiyet''i Kabulü', 'Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet''i Kabulü', 'eski', null),
  ('eski', 'TYT', 'Tarih', 'Selçuklu Türkiyesi', 'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi', 'eski', null),
  ('eski', 'TYT', 'Tarih', 'Beylikten Devlete Osmanlı (1302-1453)', 'Beylikten Devlete Osmanlı Siyaseti (1302-1453)', 'eski', null),
  ('eski', 'TYT', 'Tarih', 'Osmanlı Medeniyeti', 'Beylikten Devlete Osmanlı Medeniyeti', 'eski', null),
  ('eski', 'TYT', 'Tarih', 'Osmanlı Merkez Teşkilatı', 'Sultan ve Osmanlı Merkez Teşkilatı', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Doğa ve İnsan', 'Coğrafya Bilimi, İnsan ve Doğa', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Harita Bilgisi', 'Harita Bilimi', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Atmosfer ve Sıcaklık', 'İklim Bilimi', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Basınç ve Rüzgârlar', 'İklim Bilimi', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Nem-Yağış-Buharlaşma', 'İklim Bilimi', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Dış Kuvvetler', 'Dünya''nın Yapısı ve Oluşum Süreci', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'İç Kuvvetler', 'Dünya''nın Yapısı ve Oluşum Süreci', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Su Kaynakları', 'Su Kaynakları, Topraklar, Bitkiler', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Toprak ve Bitki Örtüsü', 'Su Kaynakları, Topraklar, Bitkiler', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Yerleşme', 'Yerleşmeler', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Ekonomik Faaliyetler', 'Nüfus, Göç, Ekonomik Faaliyetler', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Göç', 'Nüfus, Göç, Ekonomik Faaliyetler', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Nüfus', 'Nüfus, Göç, Ekonomik Faaliyetler', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Bölgeler', 'Bölgeler ve Ülkeler', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Çevre ve Toplum', 'İnsan ve Çevre', 'eski', null),
  ('eski', 'TYT', 'Coğrafya', 'Doğal Afetler', 'Afetler', 'eski', null),
  ('eski', 'TYT', 'Felsefe', 'Felsefenin Konusu', 'Felsefeyi Tanıma', 'eski', null),
  ('eski', 'TYT', 'Din Kültürü', 'Allah-İnsan İlişkisi', 'Allah İnsan İlişkisi', 'eski', null),
  ('eski', 'TYT', 'Din Kültürü', 'İslam Düşüncesinde Yorumlar', 'İslam Düşüncesinde İtikadi, Siyasi ve Fıkhi Yorumlar', 'eski', null),
  ('eski', 'TYT', 'Din Kültürü', 'Ahlaki Tutum ve Davranışlar', 'Ahlaki Tutum Davranışlar', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'Trigonometri: Yönlü Açılar', 'Yönlü Açılar', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'sinüs', 'Trigonometrik Fonksiyonlar', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'kosinüs', 'Trigonometrik Fonksiyonlar', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'tanjant', 'Trigonometrik Fonksiyonlar', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'birim çember', 'Trigonometrik Fonksiyonlar', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'Kosinüs ve Sinüs Teoremi', 'Trigonometrik Fonksiyonlar', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'Sinüs ve Kosinüs Fonksiyonlarının Grafikleri', 'Trigonometrik Fonksiyonlar', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'Ters Trigonometrik Fonksiyonlar', 'Trigonometrik Fonksiyonlar', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'Trigonometri: Toplam-Fark ve İki Kat Açı', 'Toplam-Fark ve İki Kat Açı Formülleri', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'Fonksiyonlarda Uygulamalar (Ters-Bileşke)', 'Fonksiyonların Grafik ve Problemleri', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'Parabol', 'İkinci Dereceden Fonksiyonlar ve Grafikleri', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'İkinci Dereceden Denklemler', 'İkinci Dereceden Fonksiyonlar ve Grafikleri', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'Eşitsizlikler', 'İkinci Dereceden Eşitsizlikler', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'logaritma', 'Logaritma Fonksiyonu', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'log', 'Logaritma Fonksiyonu', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'Logaritma', 'Logaritma Fonksiyonu', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'aritmetik dizi', 'Diziler', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'geometrik dizi', 'Diziler', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'limit dizi', 'Diziler', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'limit', 'Limit ve Süreklilik', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'süreklilik', 'Limit ve Süreklilik', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'belirsizlik', 'Limit ve Süreklilik', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'türev alma', 'Türev', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'teğet eğimi', 'Türev', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'maksimum minimum', 'Türev Uygulamaları', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'artan azalan', 'Türev Uygulamaları', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'ekstremum', 'Türev Uygulamaları', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'asimptot', 'Türev Uygulamaları', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'Türev Uygulamaları (Optimizasyon)', 'Türev Uygulamaları', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'integral', 'Belirsiz İntegral', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'ilkel fonksiyon', 'Belirsiz İntegral', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'İntegral', 'Belirsiz İntegral', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'alan hesabı', 'Belirli İntegral ve Alan Hesabı', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'hacim hesabı', 'Belirli İntegral ve Alan Hesabı', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'İntegral ile Alan Hesabı', 'Belirli İntegral ve Alan Hesabı', 'eski', null),
  ('eski', 'AYT', 'Matematik', 'bağımlı olay', 'Koşullu Olasılık', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'bayes', 'Koşullu Olasılık', 'ara', null),
  ('eski', 'AYT', 'Matematik', 'Binom ve Olasılık', 'Deneysel ve Teorik Olasılık', 'eski', null),
  ('eski', 'AYT', 'Geometri', 'eğim', 'Doğrunun Analitik İncelenmesi', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'doğru denklemi', 'Doğrunun Analitik İncelenmesi', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'analitik düzlem', 'Doğrunun Analitik İncelenmesi', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'Analitik Geometri (Doğru)', 'Doğrunun Analitik İncelenmesi', 'eski', null),
  ('eski', 'AYT', 'Geometri', 'çember denklemi', 'Çemberin Analitik İncelenmesi', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'öteleme', 'Analitik Düzlemde Temel Dönüşümler', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'dönme', 'Analitik Düzlemde Temel Dönüşümler', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'simetri', 'Analitik Düzlemde Temel Dönüşümler', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'yansıma', 'Analitik Düzlemde Temel Dönüşümler', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'Çember ve Daire', 'Çemberde Temel Kavramlar', 'eski', 'TYT'),
  ('eski', 'AYT', 'Geometri', 'çevre açı', 'Çemberde Açılar', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'merkez açı', 'Çemberde Açılar', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'teğet-kiriş açı', 'Çemberde Açılar', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'teğet', 'Çemberde Teğet', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'kuvvet', 'Çemberde Teğet', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'daire alanı', 'Dairenin Çevresi ve Alanı', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'daire dilimi', 'Dairenin Çevresi ve Alanı', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'yay uzunluğu', 'Dairenin Çevresi ve Alanı', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'küre', 'Katı Cisimler (Küre, Silindir, Koni)', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'silindir', 'Katı Cisimler (Küre, Silindir, Koni)', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'koni', 'Katı Cisimler (Küre, Silindir, Koni)', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'hacim', 'Katı Cisimler (Küre, Silindir, Koni)', 'ara', null),
  ('eski', 'AYT', 'Geometri', 'Katı Cisimler (Piramit-Koni-Küre)', 'Katı Cisimler (Küre, Silindir, Koni)', 'eski', null),
  ('eski', 'AYT', 'Geometri', 'Katı Cisimler (Prizma-Silindir)', 'Katı Cisimler (Küre, Silindir, Koni)', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'atışlar', 'Kuvvet ve Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'eğik atış', 'Kuvvet ve Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'dikey atış', 'Kuvvet ve Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'yatay atış', 'Kuvvet ve Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'newton yasaları', 'Kuvvet ve Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'momentum', 'Kuvvet ve Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'itme', 'Kuvvet ve Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'tork', 'Kuvvet ve Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'denge', 'Kuvvet ve Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'Bağıl Hareket', 'Kuvvet ve Hareket', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'Bir Boyutta Sabit İvmeli Hareket', 'Kuvvet ve Hareket', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'Enerji ve Hareket', 'Kuvvet ve Hareket', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'Kuvvet', 'Kuvvet ve Hareket', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'Tork ve Denge', 'Kuvvet ve Hareket', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'Newton''un Hareket Yasaları', 'Kuvvet ve Hareket', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'Vektörler', 'Kuvvet ve Hareket', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'İki Boyutta Sabit İvmeli Hareket', 'Kuvvet ve Hareket', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'İtme ve Momentum', 'Kuvvet ve Hareket', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'merkezcil kuvvet', 'Çembersel Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'açısal hız', 'Çembersel Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'dönme', 'Çembersel Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'eylemsizlik momenti', 'Çembersel Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'sarkaç', 'Basit Harmonik Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'yay sarkacı', 'Basit Harmonik Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'periyot', 'Basit Harmonik Hareket', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'indüksiyon', 'Elektrik ve Manyetizma', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'transformatör', 'Elektrik ve Manyetizma', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'manyetik alan', 'Elektrik ve Manyetizma', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'alternatif akım', 'Elektrik ve Manyetizma', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'Elektrik Alan ve Potansiyel', 'Elektrik ve Manyetizma', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'Kondansatörler', 'Elektrik ve Manyetizma', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'Manyetizma ve İndüksiyon', 'Elektrik ve Manyetizma', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'girişim', 'Dalga Mekaniği', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'kırınım', 'Dalga Mekaniği', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'doppler', 'Dalga Mekaniği', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'elektromanyetik dalga', 'Dalga Mekaniği', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'Dalga Mekaniği (Girişim-Kırınım-Doppler)', 'Dalga Mekaniği', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'radyoaktivite', 'Atom Fiziğine Giriş ve Radyoaktivite', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'yarılanma süresi', 'Atom Fiziğine Giriş ve Radyoaktivite', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'atom modelleri', 'Atom Fiziğine Giriş ve Radyoaktivite', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'fisyon', 'Atom Fiziğine Giriş ve Radyoaktivite', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'füzyon', 'Atom Fiziğine Giriş ve Radyoaktivite', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'Atom Fiziği ve Radyoaktivite', 'Atom Fiziğine Giriş ve Radyoaktivite', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'özel görelilik', 'Modern Fizik', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'fotoelektrik', 'Modern Fizik', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'compton', 'Modern Fizik', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'kara cisim ışıması', 'Modern Fizik', 'ara', null),
  ('eski', 'AYT', 'Fizik', 'Compton ve de Broglie', 'Modern Fizik', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'Fotoelektrik Olay', 'Modern Fizik', 'eski', null),
  ('eski', 'AYT', 'Fizik', 'Özel Görelilik', 'Modern Fizik', 'eski', null),
  ('eski', 'AYT', 'Kimya', 'Elektrokimyasal Hücreler ve Piller', 'Kimya ve Elektrik', 'eski', null),
  ('eski', 'AYT', 'Kimya', 'Elektroliz', 'Kimya ve Elektrik', 'eski', null),
  ('eski', 'AYT', 'Kimya', 'Redoks Tepkimeleri', 'Kimya ve Elektrik', 'eski', null),
  ('eski', 'AYT', 'Kimya', 'Karbon Kimyasına Giriş (Hibritleşme)', 'Karbon Kimyasına Giriş', 'eski', null),
  ('eski', 'AYT', 'Kimya', 'Aldehit ve Ketonlar', 'Organik Bileşikler', 'eski', null),
  ('eski', 'AYT', 'Kimya', 'Alkoller ve Eterler', 'Organik Bileşikler', 'eski', null),
  ('eski', 'AYT', 'Kimya', 'Hidrokarbonlar', 'Organik Bileşikler', 'eski', null),
  ('eski', 'AYT', 'Kimya', 'Karboksilik Asitler ve Esterler', 'Organik Bileşikler', 'eski', null),
  ('eski', 'AYT', 'Kimya', 'Enerji Kaynakları', 'Enerji Kaynakları ve Bilimsel Gelişmeler', 'eski', null),
  ('eski', 'AYT', 'Biyoloji', 'nöron', 'Sinir Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'refleks', 'Sinir Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'merkezi sinir sistemi', 'Sinir Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'hormon', 'Endokrin Sistem', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'hipofiz', 'Endokrin Sistem', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'tiroit', 'Endokrin Sistem', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'Endokrin Sistem ve Hormonlar', 'Endokrin Sistem', 'eski', null),
  ('eski', 'AYT', 'Biyoloji', 'Destek ve Hareket Sistemi', 'İskelet Sistemi', 'eski', null),
  ('eski', 'AYT', 'Biyoloji', 'kas', 'Kas Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'kas kasılması', 'Kas Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'göz', 'Duyu Organları', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'kulak', 'Duyu Organları', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'deri', 'Duyu Organları', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'kalp', 'Kan Dolaşımı', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'damar', 'Kan Dolaşımı', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'kan', 'Kan Dolaşımı', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'Dolaşım Sistemi', 'Kan Dolaşımı', 'eski', null),
  ('eski', 'AYT', 'Biyoloji', 'mide', 'Sindirim Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'karaciğer', 'Sindirim Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'sindirim enzimleri', 'Sindirim Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'akciğer', 'Solunum Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'soluk alıp verme', 'Solunum Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'böbrek', 'Üriner Sistem', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'nefron', 'Üriner Sistem', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'boşaltım', 'Üriner Sistem', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'Boşaltım Sistemi', 'Üriner Sistem', 'eski', null),
  ('eski', 'AYT', 'Biyoloji', 'Üreme Sistemi ve Embriyonik Gelişim', 'Üreme Sistemi', 'eski', null),
  ('eski', 'AYT', 'Biyoloji', 'antikor', 'Bağışıklık Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'aşı', 'Bağışıklık Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'savunma', 'Bağışıklık Sistemi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'popülasyon', 'Popülasyon Ekolojisi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'büyüme eğrisi', 'Popülasyon Ekolojisi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'dna', 'Nükleik Asitler', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'rna', 'Nükleik Asitler', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'replikasyon', 'Nükleik Asitler', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'DNA Replikasyonu', 'Nükleik Asitler', 'eski', null),
  ('eski', 'AYT', 'Biyoloji', 'transkripsiyon', 'Genetik Şifre ve Protein Sentezi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'translasyon', 'Genetik Şifre ve Protein Sentezi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'protein sentezi', 'Genetik Şifre ve Protein Sentezi', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'Protein Sentezi', 'Genetik Şifre ve Protein Sentezi', 'eski', null),
  ('eski', 'AYT', 'Biyoloji', 'Modern Genetik Uygulamaları', 'Genetik Mühendisliği ve Biyoteknoloji', 'eski', null),
  ('eski', 'AYT', 'Biyoloji', 'kloroplast', 'Fotosentez', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'ışık reaksiyonları', 'Fotosentez', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'calvin', 'Fotosentez', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'glikoliz', 'Hücresel Solunum', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'krebs', 'Hücresel Solunum', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'etaş', 'Hücresel Solunum', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'laktik asit', 'Fermantasyon', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'etil alkol', 'Fermantasyon', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'kök', 'Bitkisel Organlar', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'gövde', 'Bitkisel Organlar', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'yaprak', 'Bitkisel Organlar', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'terleme', 'Bitkilerde Madde Taşınması', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'ksilem', 'Bitkilerde Madde Taşınması', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'floem', 'Bitkilerde Madde Taşınması', 'ara', null),
  ('eski', 'AYT', 'Biyoloji', 'Bitkilerde Taşıma-Beslenme-Terleme', 'Bitkilerde Madde Taşınması', 'eski', null),
  ('eski', 'AYT', 'Biyoloji', 'Bitkisel Hormonlar', 'Bitki Hormonları', 'eski', null),
  ('eski', 'AYT', 'Biyoloji', 'Bitkilerde Üreme', 'Bitkilerde Eşeyli Üreme', 'eski', null),
  ('eski', 'AYT', 'Edebiyat', 'Edebiyat Bilgisi ve Metin Türleri', 'Edebiyata Giriş', 'eski', null),
  ('eski', 'AYT', 'Edebiyat', 'İslamiyet Öncesi Türk Edebiyatı', 'İslamiyet Öncesi Türk Şiiri', 'eski', null),
  ('eski', 'AYT', 'Edebiyat', 'Geçiş Dönemi Eserleri', 'Geçiş Dönemi Türk Şiiri', 'eski', null),
  ('eski', 'AYT', 'Edebiyat', 'Halk Edebiyatı (Âşık-Anonim)', 'Halk Şiiri', 'eski', null),
  ('eski', 'AYT', 'Edebiyat', 'Divan Edebiyatı', 'Divan Şiiri', 'eski', null),
  ('eski', 'AYT', 'Edebiyat', 'Tanzimat Edebiyatı', 'Tanzimat Dönemi Türk Şiiri', 'eski', null),
  ('eski', 'AYT', 'Edebiyat', 'Servet-i Fünun Edebiyatı', 'Servetifünun Dönemi Türk Şiiri', 'eski', null),
  ('eski', 'AYT', 'Edebiyat', 'Millî Edebiyat', 'Millî Edebiyat Dönemi Türk Şiiri', 'eski', null),
  ('eski', 'AYT', 'Edebiyat', 'Hikâye', 'Hikâye Türleri ve Hikâyenin Yapı Unsurları', 'eski', null),
  ('eski', 'AYT', 'Edebiyat', 'Roman', 'Roman Türü ve Yapı Unsurları', 'eski', null),
  ('eski', 'AYT', 'Edebiyat', 'Tiyatro', 'Tiyatro Türü ve Yapı Unsurları', 'eski', null),
  ('eski', 'AYT', 'Tarih', 'Değişen Dünya Dengeleri ve Osmanlı Siyaseti (1595-1774)', 'Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774)', 'eski', null),
  ('eski', 'AYT', 'Tarih', 'Uluslararası İlişkilerde Denge (1774-1914)', 'Uluslararası İlişkilerde Denge Stratejisi (1774-1914)', 'eski', null),
  ('eski', 'AYT', 'Tarih', 'Devrimler Çağı', 'Devrimler Çağında Değişen Devlet-Toplum İlişkileri', 'eski', null),
  ('eski', 'AYT', 'Tarih', 'Sermaye ve Emek', 'XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat', 'eski', null),
  ('eski', 'AYT', 'Tarih', 'XIX-XX. Yüzyılda Gündelik Hayat', 'XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat', 'eski', null),
  ('eski', 'AYT', 'Tarih', 'XX. Yüzyıl Başlarında Osmanlı', 'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya', 'eski', null),
  ('eski', 'AYT', 'Tarih', 'İki Savaş Arası Dönem', 'İki Savaş Arasındaki Dönemde Türkiye ve Dünya', 'eski', null),
  ('eski', 'AYT', 'Tarih', 'II. Dünya Savaşı', 'II. Dünya Savaşı Sürecinde Türkiye ve Dünya', 'eski', null),
  ('eski', 'AYT', 'Tarih', 'Soğuk Savaş Dönemi', 'II. Dünya Savaşı Sonrasında Türkiye ve Dünya', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Doğal Sistemler (Biyoçeşitlilik)', 'Ekosistemlerin İşleyişi ve Özellikleri', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Ekosistem ve Madde Döngüsü', 'Ekosistemlerin İşleyişi ve Özellikleri', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Doğal Afetler ve Toplum', 'Ekstrem Doğa Olayları ve Doğa Olaylarının Geleceği', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Beşerî Sistemler', 'Nüfus Politikaları ve Yerleşmeler', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Nüfus Politikaları', 'Nüfus Politikaları ve Yerleşmeler', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Türkiye''de Nüfus ve Yerleşme', 'Nüfus Politikaları ve Yerleşmeler', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Doğal Kaynaklar', 'Ekonomik Faaliyetler ve Doğal Kaynaklar', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Türkiye Ekonomisinin Sektörel Dağılımı', 'Türkiye''de Ekonomi', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Türkiye''de Madenler ve Enerji Kaynakları', 'Türkiye''de Ekonomi', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Türkiye''de Sanayi', 'Türkiye''de Ekonomi', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Türkiye''de Tarım', 'Türkiye''de Ekonomi', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Göç ve Şehirleşme', 'Ekonomi, Şehirleşme ve Göç', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Türkiye''de Ticaret-Ulaşım-Turizm', 'Ulaşım, Ticaret, Turizm', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Bölgesel Kalkınma Projeleri', 'Türkiye''nin İşlevsel Bölgeleri ve Kalkınma Projeleri', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Küresel Ortam: Bölgeler ve Ülkeler', 'Küreselleşen Dünya', 'eski', null),
  ('eski', 'AYT', 'Coğrafya', 'Çevre ve Toplum', 'Çevre Sorunları', 'eski', null),
  ('eski', 'AYT', 'Felsefe Grubu', 'İlk Çağ Felsefesi', 'MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi', 'eski', null),
  ('eski', 'AYT', 'Felsefe Grubu', 'Ortaçağ Felsefesi', 'MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi', 'eski', null),
  ('eski', 'AYT', 'Felsefe Grubu', 'Yeni Çağ Felsefesi', '15. Yüzyıl-17. Yüzyıl Felsefesi', 'eski', null),
  ('eski', 'AYT', 'Felsefe Grubu', '19. Yüzyıl Felsefesi', '18. Yüzyıl-19. Yüzyıl Felsefesi', 'eski', null),
  ('eski', 'AYT', 'Din Kültürü', 'Kur''an''da Kavramlar', 'Kur''an''da Bazı Kavramlar', 'eski', null),
  ('eski', 'AYT', 'Din Kültürü', 'Tasavvufi Yorumlar', 'İslam Düşüncesinde Tasavvufi Yorumlar', 'eski', null),
  ('maarif', 'TYT', 'Geometri', 'benzerlik', 'Üçgende Eşlik ve Benzerlik', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'thales', 'Üçgende Eşlik ve Benzerlik', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'pisagor', 'Üçgende Eşlik ve Benzerlik', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'açıortay', 'Üçgende Eşlik ve Benzerlik', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'kenarortay', 'Üçgende Eşlik ve Benzerlik', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'beşgen', 'Çokgenler', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'altıgen', 'Çokgenler', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'iç açılar toplamı', 'Çokgenler', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'paralelkenar', 'Dörtgenler', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'yamuk', 'Dörtgenler', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'dikdörtgen', 'Dörtgenler', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'kare', 'Dörtgenler', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'eşkenar dörtgen', 'Dörtgenler', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'çevre açı', 'Çember', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'merkez açı', 'Çember', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'teğet', 'Çember', 'ara', null),
  ('maarif', 'TYT', 'Geometri', 'daire alanı', 'Çember', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'atışlar', 'Kuvvet ve Hareket', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'eğik atış', 'Kuvvet ve Hareket', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'dikey atış', 'Kuvvet ve Hareket', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'yatay atış', 'Kuvvet ve Hareket', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'newton yasaları', 'Kuvvet ve Hareket', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'ivme', 'Kuvvet ve Hareket', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'sürtünme kuvveti', 'Kuvvet ve Hareket', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'basınç', 'Akışkanlar (Basınç)', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'sıvı basıncı', 'Akışkanlar (Basınç)', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'gaz basıncı', 'Akışkanlar (Basınç)', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'arşimet', 'Akışkanlar (Kaldırma Kuvveti-Bernoulli)', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'kaldırma kuvveti', 'Akışkanlar (Kaldırma Kuvveti-Bernoulli)', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'bernoulli', 'Akışkanlar (Kaldırma Kuvveti-Bernoulli)', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'ısı', 'Enerji (Isı-Hâl Değişimi)', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'hâl değişimi', 'Enerji (Isı-Hâl Değişimi)', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'öz ısı', 'Enerji (Isı-Hâl Değişimi)', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'genleşme', 'Enerji (Isı-Hâl Değişimi)', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'devre', 'Elektrik', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'direnç', 'Elektrik', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'ohm kanunu', 'Elektrik', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'yük', 'Elektrik', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'ses dalgası', 'Dalgalar', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'su dalgası', 'Dalgalar', 'ara', null),
  ('maarif', 'TYT', 'Fizik', 'girişim', 'Dalgalar', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'organel', 'Hücre', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'mitokondri', 'Hücre', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'ribozom', 'Hücre', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'hücre zarı', 'Hücre', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'difüzyon', 'Hücre', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'osmoz', 'Hücre', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'kloroplast', 'Fotosentez', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'ışık reaksiyonları', 'Fotosentez', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'glikoliz', 'Hücresel Solunum', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'krebs', 'Hücresel Solunum', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'fermantasyon', 'Hücresel Solunum', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'besin zinciri', 'Ekosistem Ekolojisi', 'ara', null),
  ('maarif', 'TYT', 'Biyoloji', 'madde döngüsü', 'Ekosistem Ekolojisi', 'ara', null),
  ('maarif', 'AYT', 'Matematik', 'türev alma', 'Türev', 'ara', null),
  ('maarif', 'AYT', 'Matematik', 'limit', 'Türev', 'ara', null),
  ('maarif', 'AYT', 'Matematik', 'maksimum minimum', 'Türev', 'ara', null),
  ('maarif', 'AYT', 'Matematik', 'alan hesabı', 'İntegral', 'ara', null),
  ('maarif', 'AYT', 'Matematik', 'belirli integral', 'İntegral', 'ara', null),
  ('maarif', 'AYT', 'Matematik', 'log', 'Logaritma', 'ara', null),
  ('maarif', 'AYT', 'Matematik', 'üslü ifade', 'Logaritma', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'atışlar', 'Kuvvet ve Hareket (Newton Yasaları)', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'eğik atış', 'Kuvvet ve Hareket (Newton Yasaları)', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'dikey atış', 'Kuvvet ve Hareket (Newton Yasaları)', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'yatay atış', 'Kuvvet ve Hareket (Newton Yasaları)', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'momentum', 'Kuvvet ve Hareket (Newton Yasaları)', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'tork', 'Kuvvet ve Hareket (Newton Yasaları)', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'denge', 'Kuvvet ve Hareket (Newton Yasaları)', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'merkezcil kuvvet', 'Çembersel Hareket', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'açısal hız', 'Çembersel Hareket', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'dönme', 'Çembersel Hareket', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'manyetik alan', 'Elektriksel ve Manyetik Alan', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'elektrik alan', 'Elektriksel ve Manyetik Alan', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'coulomb', 'Elektriksel ve Manyetik Alan', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'indüksiyon', 'İndüksiyon ve Transformatörler', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'transformatör', 'İndüksiyon ve Transformatörler', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'alternatif akım', 'İndüksiyon ve Transformatörler', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'mercek', 'Optik', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'ayna', 'Optik', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'kırılma', 'Optik', 'ara', null),
  ('maarif', 'AYT', 'Fizik', 'yansıma', 'Optik', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'nöron', 'Sinir Sistemi ve Refleks', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'refleks', 'Sinir Sistemi ve Refleks', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'sinir', 'Sinir Sistemi ve Refleks', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'kemik', 'İskelet-Kas-Eklem Sistemi', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'kas', 'İskelet-Kas-Eklem Sistemi', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'eklem', 'İskelet-Kas-Eklem Sistemi', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'antikor', 'Bağışıklık ve Alerji', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'aşı', 'Bağışıklık ve Alerji', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'alerji', 'Bağışıklık ve Alerji', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'hormon', 'Endokrin Sistem', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'hipofiz', 'Endokrin Sistem', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'tiroit', 'Endokrin Sistem', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'kalp', 'Dolaşım Sistemi', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'damar', 'Dolaşım Sistemi', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'kan', 'Dolaşım Sistemi', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'akciğer', 'Solunum Sistemi', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'soluk alıp verme', 'Solunum Sistemi', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'böbrek', 'Boşaltım Sistemi', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'nefron', 'Boşaltım Sistemi', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'diyabet', 'Denge Bozuklukları (Diyabet-Hipertansiyon-Obezite)', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'hipertansiyon', 'Denge Bozuklukları (Diyabet-Hipertansiyon-Obezite)', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'obezite', 'Denge Bozuklukları (Diyabet-Hipertansiyon-Obezite)', 'ara', null),
  ('maarif', 'AYT', 'Biyoloji', 'şeker hastalığı', 'Denge Bozuklukları (Diyabet-Hipertansiyon-Obezite)', 'ara', null);

-- ------------------------------------------------- eski adlarin remap'i
-- Bir konu yeniden adlandirildiginda gecmis kayitlar oksuz kalmasin diye.
-- Idempotent: ikinci calistirmada eslesen satir kalmaz.
--
-- `curriculum = 'eski'` SUZGECI SART: eski adlar yalnizca o agacin
-- tarihinden geliyor. Suzgec olmasaydi ayni (sinav, ders, konu) uclusune
-- sahip bir maarif satiri eski agacin konusuna cevrilir ve dogrulama
-- tetikleyicisi gocun kendisini reddederdi.
--
-- `tools/remap_konu.sql` bu blokta eridi: 265 satirlik, elle calistirilan,
-- 80'i no-op olan ve hicbir yerden referans verilmeyen bir betikti.
update public.mistakes set concept = 'Sözcük Türleri'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Türkçe' and concept = 'Edat-Bağlaç-Ünlem';
update public.mistakes set concept = 'Sözcük Türleri'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Türkçe' and concept = 'Sıfat';
update public.mistakes set concept = 'Sözcük Türleri'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Türkçe' and concept = 'Zamir';
update public.mistakes set concept = 'Sözcük Türleri'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Türkçe' and concept = 'Zarf';
update public.mistakes set concept = 'Sözcük Türleri'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Türkçe' and concept = 'İsim (Ad)';
update public.mistakes set concept = 'Fiiller'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Türkçe' and concept = 'Fiilde Anlam (Kip-Kişi)';
update public.mistakes set concept = 'Fiiller'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Türkçe' and concept = 'Fiilimsi';
update public.mistakes set concept = 'Önermeler ve Bileşik Önermeler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'Mantık';
update public.mistakes set concept = 'Kümelerde Temel Kavramlar'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'Kümeler';
update public.mistakes set concept = 'Sayı Kümeleri'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'Temel Kavramlar';
update public.mistakes set concept = 'Bölünebilme Kuralları'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'Bölme-Bölünebilme';
update public.mistakes set concept = 'Birinci Dereceden Denklemler ve Eşitsizlikler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'Basit Eşitsizlikler';
update public.mistakes set concept = 'Üslü İfadeler ve Denklemler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'Üslü Sayılar';
update public.mistakes set concept = 'Denklemler ve Eşitsizlikler ile İlgili Uygulamalar'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'Sayı Problemleri';
update public.mistakes set concept = 'Merkezi Eğilim ve Yayılım Ölçüleri'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'İstatistik';
update public.mistakes set concept = 'Sıralama ve Seçme'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'Permütasyon-Kombinasyon';
update public.mistakes set concept = 'Basit Olayların Olasılıkları'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'Olasılık';
update public.mistakes set concept = 'Fonksiyon Kavramı ve Gösterimi'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'Fonksiyonlar';
update public.mistakes set concept = 'Polinom Kavramı ve Polinomlarda İşlemler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'Polinomlar';
update public.mistakes set concept = 'İkinci Dereceden Bir Bilinmeyenli Denklemler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Matematik' and concept = 'İkinci Dereceden Denklemler';
update public.mistakes set concept = 'Üçgenlerde Temel Kavramlar'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Geometri' and concept = 'Üçgende Açılar';
update public.mistakes set concept = 'Üçgenlerde Eşlik ve Benzerlik'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Geometri' and concept = 'Üçgende Benzerlik';
update public.mistakes set concept = 'Üçgenin Yardımcı Elemanları'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Geometri' and concept = 'Açıortay';
update public.mistakes set concept = 'Üçgenin Yardımcı Elemanları'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Geometri' and concept = 'Kenarortay';
update public.mistakes set concept = 'Dik Üçgen ve Trigonometri'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Geometri' and concept = 'Dik Üçgen';
update public.mistakes set concept = 'Üçgenin Alanı'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Geometri' and concept = 'Üçgende Alan';
update public.mistakes set concept = 'Özel Dörtgenler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Geometri' and concept = 'Dikdörtgen ve Kare';
update public.mistakes set concept = 'Özel Dörtgenler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Geometri' and concept = 'Paralelkenar';
update public.mistakes set concept = 'Hareket ve Kuvvet'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Basit Makineler';
update public.mistakes set concept = 'Hareket ve Kuvvet'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Doğrusal Hareket';
update public.mistakes set concept = 'Hareket ve Kuvvet'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Kuvvet ve Denge (Vektörler)';
update public.mistakes set concept = 'Enerji'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'İş-Güç-Enerji';
update public.mistakes set concept = 'Basınç ve Kaldırma Kuvveti'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Basınç';
update public.mistakes set concept = 'Basınç ve Kaldırma Kuvveti'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Sıvıların Kaldırma Kuvveti';
update public.mistakes set concept = 'Elektrik ve Manyetizma'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Elektrik Akımı ve Devreler';
update public.mistakes set concept = 'Elektrik ve Manyetizma'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Mıknatıslar ve Manyetik Alan';
update public.mistakes set concept = 'Dalgalar'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Dalgalar (Temel)';
update public.mistakes set concept = 'Dalgalar'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Yay ve Su Dalgaları';
update public.mistakes set concept = 'Optik'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Düzlem Ayna';
update public.mistakes set concept = 'Optik'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Işık ve Gölge';
update public.mistakes set concept = 'Optik'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Küresel Aynalar';
update public.mistakes set concept = 'Optik'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Kırılma ve Renkler';
update public.mistakes set concept = 'Optik'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Fizik' and concept = 'Mercekler';
update public.mistakes set concept = 'Kimya Bilimi'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Kimya' and concept = 'Kimya Bilimine Giriş';
update public.mistakes set concept = 'Atom ve Periyodik Sistem'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Kimya' and concept = 'Atomun Yapısı';
update public.mistakes set concept = 'Atom ve Periyodik Sistem'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Kimya' and concept = 'Periyodik Sistem';
update public.mistakes set concept = 'Kimyasal Türler Arası Etkileşimler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Kimya' and concept = 'Kovalent Bağ';
update public.mistakes set concept = 'Kimyasal Türler Arası Etkileşimler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Kimya' and concept = 'Metalik Bağ ve Zayıf Etkileşimler';
update public.mistakes set concept = 'Kimyasal Türler Arası Etkileşimler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Kimya' and concept = 'İyonik Bağ';
update public.mistakes set concept = 'Maddenin Hâlleri'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Kimya' and concept = 'Maddenin Halleri';
update public.mistakes set concept = 'Kimyanın Temel Kanunları ve Kimyasal Hesaplamalar'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Kimya' and concept = 'Kimyanın Temel Kanunları';
update public.mistakes set concept = 'Kimyanın Temel Kanunları ve Kimyasal Hesaplamalar'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Kimya' and concept = 'Mol Kavramı ve Hesaplamalar';
update public.mistakes set concept = 'Asitler, Bazlar ve Tuzlar'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Kimya' and concept = 'Asit-Baz';
update public.mistakes set concept = 'Canlıların Yapısında Bulunan İnorganik Bileşikler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Biyoloji' and concept = 'İnorganik Bileşikler';
update public.mistakes set concept = 'Canlıların Yapısında Bulunan Organik Bileşikler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Biyoloji' and concept = 'Enzimler';
update public.mistakes set concept = 'Canlıların Yapısında Bulunan Organik Bileşikler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Biyoloji' and concept = 'Nükleik Asitler';
update public.mistakes set concept = 'Canlıların Yapısında Bulunan Organik Bileşikler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Biyoloji' and concept = 'Organik Bileşikler (Karbonhidrat-Lipit-Protein)';
update public.mistakes set concept = 'Hücresel Yapılar ve Görevleri'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Biyoloji' and concept = 'Hücre ve Organelleri';
update public.mistakes set concept = 'Hücre Zarından Madde Geçişleri'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Biyoloji' and concept = 'Hücre Zarından Madde Geçişi';
update public.mistakes set concept = 'Hücre Döngüsü ve Mitoz'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Biyoloji' and concept = 'Mitoz ve Eşeysiz Üreme';
update public.mistakes set concept = 'Mayoz'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Biyoloji' and concept = 'Mayoz ve Eşeyli Üreme';
update public.mistakes set concept = 'Ekosistem Ekolojisi'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Biyoloji' and concept = 'Madde Döngüleri';
update public.mistakes set concept = 'Tarih ve Zaman'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Tarih' and concept = 'İnsanlığın İlk Dönemleri';
update public.mistakes set concept = 'İlk ve Orta Çağlarda Türk Dünyası'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Tarih' and concept = 'Orta Çağ''da Dünya';
update public.mistakes set concept = 'Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet''i Kabulü'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Tarih' and concept = 'Türklerin İslamiyet''i Kabulü';
update public.mistakes set concept = 'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Tarih' and concept = 'Selçuklu Türkiyesi';
update public.mistakes set concept = 'Beylikten Devlete Osmanlı Siyaseti (1302-1453)'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Tarih' and concept = 'Beylikten Devlete Osmanlı (1302-1453)';
update public.mistakes set concept = 'Beylikten Devlete Osmanlı Medeniyeti'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Tarih' and concept = 'Osmanlı Medeniyeti';
update public.mistakes set concept = 'Sultan ve Osmanlı Merkez Teşkilatı'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Tarih' and concept = 'Osmanlı Merkez Teşkilatı';
update public.mistakes set concept = 'Coğrafya Bilimi, İnsan ve Doğa'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Doğa ve İnsan';
update public.mistakes set concept = 'Harita Bilimi'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Harita Bilgisi';
update public.mistakes set concept = 'İklim Bilimi'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Atmosfer ve Sıcaklık';
update public.mistakes set concept = 'İklim Bilimi'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Basınç ve Rüzgârlar';
update public.mistakes set concept = 'İklim Bilimi'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Nem-Yağış-Buharlaşma';
update public.mistakes set concept = 'Dünya''nın Yapısı ve Oluşum Süreci'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Dış Kuvvetler';
update public.mistakes set concept = 'Dünya''nın Yapısı ve Oluşum Süreci'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'İç Kuvvetler';
update public.mistakes set concept = 'Su Kaynakları, Topraklar, Bitkiler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Su Kaynakları';
update public.mistakes set concept = 'Su Kaynakları, Topraklar, Bitkiler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Toprak ve Bitki Örtüsü';
update public.mistakes set concept = 'Yerleşmeler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Yerleşme';
update public.mistakes set concept = 'Nüfus, Göç, Ekonomik Faaliyetler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Ekonomik Faaliyetler';
update public.mistakes set concept = 'Nüfus, Göç, Ekonomik Faaliyetler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Göç';
update public.mistakes set concept = 'Nüfus, Göç, Ekonomik Faaliyetler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Nüfus';
update public.mistakes set concept = 'Bölgeler ve Ülkeler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Bölgeler';
update public.mistakes set concept = 'İnsan ve Çevre'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Çevre ve Toplum';
update public.mistakes set concept = 'Afetler'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Coğrafya' and concept = 'Doğal Afetler';
update public.mistakes set concept = 'Felsefeyi Tanıma'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Felsefe' and concept = 'Felsefenin Konusu';
update public.mistakes set concept = 'Allah İnsan İlişkisi'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Din Kültürü' and concept = 'Allah-İnsan İlişkisi';
update public.mistakes set concept = 'İslam Düşüncesinde İtikadi, Siyasi ve Fıkhi Yorumlar'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Din Kültürü' and concept = 'İslam Düşüncesinde Yorumlar';
update public.mistakes set concept = 'Ahlaki Tutum Davranışlar'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Din Kültürü' and concept = 'Ahlaki Tutum ve Davranışlar';
update public.mistakes set concept = 'Yönlü Açılar'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'Trigonometri: Yönlü Açılar';
update public.mistakes set concept = 'Trigonometrik Fonksiyonlar'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'Kosinüs ve Sinüs Teoremi';
update public.mistakes set concept = 'Trigonometrik Fonksiyonlar'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'Sinüs ve Kosinüs Fonksiyonlarının Grafikleri';
update public.mistakes set concept = 'Trigonometrik Fonksiyonlar'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'Ters Trigonometrik Fonksiyonlar';
update public.mistakes set concept = 'Toplam-Fark ve İki Kat Açı Formülleri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'Trigonometri: Toplam-Fark ve İki Kat Açı';
update public.mistakes set concept = 'Fonksiyonların Grafik ve Problemleri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'Fonksiyonlarda Uygulamalar (Ters-Bileşke)';
update public.mistakes set concept = 'İkinci Dereceden Fonksiyonlar ve Grafikleri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'Parabol';
update public.mistakes set concept = 'İkinci Dereceden Fonksiyonlar ve Grafikleri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'İkinci Dereceden Denklemler';
update public.mistakes set concept = 'İkinci Dereceden Eşitsizlikler'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'Eşitsizlikler';
update public.mistakes set concept = 'Logaritma Fonksiyonu'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'Logaritma';
update public.mistakes set concept = 'Türev Uygulamaları'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'Türev Uygulamaları (Optimizasyon)';
update public.mistakes set concept = 'Belirsiz İntegral'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'İntegral';
update public.mistakes set concept = 'Belirli İntegral ve Alan Hesabı'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'İntegral ile Alan Hesabı';
update public.mistakes set concept = 'Deneysel ve Teorik Olasılık'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Matematik' and concept = 'Binom ve Olasılık';
update public.mistakes set concept = 'Doğrunun Analitik İncelenmesi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Geometri' and concept = 'Analitik Geometri (Doğru)';
update public.mistakes set exam = 'AYT', concept = 'Çemberde Temel Kavramlar'
  where curriculum = 'eski'
    and exam = 'TYT' and subject = 'Geometri' and concept = 'Çember ve Daire';
update public.mistakes set concept = 'Katı Cisimler (Küre, Silindir, Koni)'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Geometri' and concept = 'Katı Cisimler (Piramit-Koni-Küre)';
update public.mistakes set concept = 'Katı Cisimler (Küre, Silindir, Koni)'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Geometri' and concept = 'Katı Cisimler (Prizma-Silindir)';
update public.mistakes set concept = 'Kuvvet ve Hareket'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Bağıl Hareket';
update public.mistakes set concept = 'Kuvvet ve Hareket'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Bir Boyutta Sabit İvmeli Hareket';
update public.mistakes set concept = 'Kuvvet ve Hareket'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Enerji ve Hareket';
update public.mistakes set concept = 'Kuvvet ve Hareket'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Kuvvet';
update public.mistakes set concept = 'Kuvvet ve Hareket'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Tork ve Denge';
update public.mistakes set concept = 'Kuvvet ve Hareket'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Newton''un Hareket Yasaları';
update public.mistakes set concept = 'Kuvvet ve Hareket'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Vektörler';
update public.mistakes set concept = 'Kuvvet ve Hareket'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'İki Boyutta Sabit İvmeli Hareket';
update public.mistakes set concept = 'Kuvvet ve Hareket'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'İtme ve Momentum';
update public.mistakes set concept = 'Elektrik ve Manyetizma'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Elektrik Alan ve Potansiyel';
update public.mistakes set concept = 'Elektrik ve Manyetizma'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Kondansatörler';
update public.mistakes set concept = 'Elektrik ve Manyetizma'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Manyetizma ve İndüksiyon';
update public.mistakes set concept = 'Dalga Mekaniği'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Dalga Mekaniği (Girişim-Kırınım-Doppler)';
update public.mistakes set concept = 'Atom Fiziğine Giriş ve Radyoaktivite'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Atom Fiziği ve Radyoaktivite';
update public.mistakes set concept = 'Modern Fizik'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Compton ve de Broglie';
update public.mistakes set concept = 'Modern Fizik'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Fotoelektrik Olay';
update public.mistakes set concept = 'Modern Fizik'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Fizik' and concept = 'Özel Görelilik';
update public.mistakes set concept = 'Kimya ve Elektrik'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Kimya' and concept = 'Elektrokimyasal Hücreler ve Piller';
update public.mistakes set concept = 'Kimya ve Elektrik'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Kimya' and concept = 'Elektroliz';
update public.mistakes set concept = 'Kimya ve Elektrik'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Kimya' and concept = 'Redoks Tepkimeleri';
update public.mistakes set concept = 'Karbon Kimyasına Giriş'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Kimya' and concept = 'Karbon Kimyasına Giriş (Hibritleşme)';
update public.mistakes set concept = 'Organik Bileşikler'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Kimya' and concept = 'Aldehit ve Ketonlar';
update public.mistakes set concept = 'Organik Bileşikler'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Kimya' and concept = 'Alkoller ve Eterler';
update public.mistakes set concept = 'Organik Bileşikler'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Kimya' and concept = 'Hidrokarbonlar';
update public.mistakes set concept = 'Organik Bileşikler'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Kimya' and concept = 'Karboksilik Asitler ve Esterler';
update public.mistakes set concept = 'Enerji Kaynakları ve Bilimsel Gelişmeler'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Kimya' and concept = 'Enerji Kaynakları';
update public.mistakes set concept = 'Endokrin Sistem'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Biyoloji' and concept = 'Endokrin Sistem ve Hormonlar';
update public.mistakes set concept = 'İskelet Sistemi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Biyoloji' and concept = 'Destek ve Hareket Sistemi';
update public.mistakes set concept = 'Kan Dolaşımı'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Biyoloji' and concept = 'Dolaşım Sistemi';
update public.mistakes set concept = 'Üriner Sistem'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Biyoloji' and concept = 'Boşaltım Sistemi';
update public.mistakes set concept = 'Üreme Sistemi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Biyoloji' and concept = 'Üreme Sistemi ve Embriyonik Gelişim';
update public.mistakes set concept = 'Nükleik Asitler'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Biyoloji' and concept = 'DNA Replikasyonu';
update public.mistakes set concept = 'Genetik Şifre ve Protein Sentezi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Biyoloji' and concept = 'Protein Sentezi';
update public.mistakes set concept = 'Genetik Mühendisliği ve Biyoteknoloji'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Biyoloji' and concept = 'Modern Genetik Uygulamaları';
update public.mistakes set concept = 'Bitkilerde Madde Taşınması'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Biyoloji' and concept = 'Bitkilerde Taşıma-Beslenme-Terleme';
update public.mistakes set concept = 'Bitki Hormonları'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Biyoloji' and concept = 'Bitkisel Hormonlar';
update public.mistakes set concept = 'Bitkilerde Eşeyli Üreme'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Biyoloji' and concept = 'Bitkilerde Üreme';
update public.mistakes set concept = 'Edebiyata Giriş'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Edebiyat' and concept = 'Edebiyat Bilgisi ve Metin Türleri';
update public.mistakes set concept = 'İslamiyet Öncesi Türk Şiiri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Edebiyat' and concept = 'İslamiyet Öncesi Türk Edebiyatı';
update public.mistakes set concept = 'Geçiş Dönemi Türk Şiiri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Edebiyat' and concept = 'Geçiş Dönemi Eserleri';
update public.mistakes set concept = 'Halk Şiiri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Edebiyat' and concept = 'Halk Edebiyatı (Âşık-Anonim)';
update public.mistakes set concept = 'Divan Şiiri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Edebiyat' and concept = 'Divan Edebiyatı';
update public.mistakes set concept = 'Tanzimat Dönemi Türk Şiiri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Edebiyat' and concept = 'Tanzimat Edebiyatı';
update public.mistakes set concept = 'Servetifünun Dönemi Türk Şiiri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Edebiyat' and concept = 'Servet-i Fünun Edebiyatı';
update public.mistakes set concept = 'Millî Edebiyat Dönemi Türk Şiiri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Edebiyat' and concept = 'Millî Edebiyat';
update public.mistakes set concept = 'Hikâye Türleri ve Hikâyenin Yapı Unsurları'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Edebiyat' and concept = 'Hikâye';
update public.mistakes set concept = 'Roman Türü ve Yapı Unsurları'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Edebiyat' and concept = 'Roman';
update public.mistakes set concept = 'Tiyatro Türü ve Yapı Unsurları'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Edebiyat' and concept = 'Tiyatro';
update public.mistakes set concept = 'Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774)'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Tarih' and concept = 'Değişen Dünya Dengeleri ve Osmanlı Siyaseti (1595-1774)';
update public.mistakes set concept = 'Uluslararası İlişkilerde Denge Stratejisi (1774-1914)'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Tarih' and concept = 'Uluslararası İlişkilerde Denge (1774-1914)';
update public.mistakes set concept = 'Devrimler Çağında Değişen Devlet-Toplum İlişkileri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Tarih' and concept = 'Devrimler Çağı';
update public.mistakes set concept = 'XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Tarih' and concept = 'Sermaye ve Emek';
update public.mistakes set concept = 'XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Tarih' and concept = 'XIX-XX. Yüzyılda Gündelik Hayat';
update public.mistakes set concept = 'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Tarih' and concept = 'XX. Yüzyıl Başlarında Osmanlı';
update public.mistakes set concept = 'İki Savaş Arasındaki Dönemde Türkiye ve Dünya'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Tarih' and concept = 'İki Savaş Arası Dönem';
update public.mistakes set concept = 'II. Dünya Savaşı Sürecinde Türkiye ve Dünya'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Tarih' and concept = 'II. Dünya Savaşı';
update public.mistakes set concept = 'II. Dünya Savaşı Sonrasında Türkiye ve Dünya'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Tarih' and concept = 'Soğuk Savaş Dönemi';
update public.mistakes set concept = 'Ekosistemlerin İşleyişi ve Özellikleri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Doğal Sistemler (Biyoçeşitlilik)';
update public.mistakes set concept = 'Ekosistemlerin İşleyişi ve Özellikleri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Ekosistem ve Madde Döngüsü';
update public.mistakes set concept = 'Ekstrem Doğa Olayları ve Doğa Olaylarının Geleceği'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Doğal Afetler ve Toplum';
update public.mistakes set concept = 'Nüfus Politikaları ve Yerleşmeler'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Beşerî Sistemler';
update public.mistakes set concept = 'Nüfus Politikaları ve Yerleşmeler'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Nüfus Politikaları';
update public.mistakes set concept = 'Nüfus Politikaları ve Yerleşmeler'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Türkiye''de Nüfus ve Yerleşme';
update public.mistakes set concept = 'Ekonomik Faaliyetler ve Doğal Kaynaklar'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Doğal Kaynaklar';
update public.mistakes set concept = 'Türkiye''de Ekonomi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Türkiye Ekonomisinin Sektörel Dağılımı';
update public.mistakes set concept = 'Türkiye''de Ekonomi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Türkiye''de Madenler ve Enerji Kaynakları';
update public.mistakes set concept = 'Türkiye''de Ekonomi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Türkiye''de Sanayi';
update public.mistakes set concept = 'Türkiye''de Ekonomi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Türkiye''de Tarım';
update public.mistakes set concept = 'Ekonomi, Şehirleşme ve Göç'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Göç ve Şehirleşme';
update public.mistakes set concept = 'Ulaşım, Ticaret, Turizm'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Türkiye''de Ticaret-Ulaşım-Turizm';
update public.mistakes set concept = 'Türkiye''nin İşlevsel Bölgeleri ve Kalkınma Projeleri'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Bölgesel Kalkınma Projeleri';
update public.mistakes set concept = 'Küreselleşen Dünya'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Küresel Ortam: Bölgeler ve Ülkeler';
update public.mistakes set concept = 'Çevre Sorunları'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Coğrafya' and concept = 'Çevre ve Toplum';
update public.mistakes set concept = 'MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Felsefe Grubu' and concept = 'İlk Çağ Felsefesi';
update public.mistakes set concept = 'MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Felsefe Grubu' and concept = 'Ortaçağ Felsefesi';
update public.mistakes set concept = '15. Yüzyıl-17. Yüzyıl Felsefesi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Felsefe Grubu' and concept = 'Yeni Çağ Felsefesi';
update public.mistakes set concept = '18. Yüzyıl-19. Yüzyıl Felsefesi'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Felsefe Grubu' and concept = '19. Yüzyıl Felsefesi';
update public.mistakes set concept = 'Kur''an''da Bazı Kavramlar'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Din Kültürü' and concept = 'Kur''an''da Kavramlar';
update public.mistakes set concept = 'İslam Düşüncesinde Tasavvufi Yorumlar'
  where curriculum = 'eski'
    and exam = 'AYT' and subject = 'Din Kültürü' and concept = 'Tasavvufi Yorumlar';

insert into public.curriculum_meta (only_row, version, source_sha)
values (true, '7d00385d45b1', '22815bcc7731a5145b2eb81e5ec98e24bae992a0251162060bd9bc6bb30afe8f')
on conflict (only_row) do update
   set version = excluded.version,
       source_sha = excluded.source_sha,
       generated_at = now();
