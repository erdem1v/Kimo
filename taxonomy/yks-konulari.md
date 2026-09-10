# YKS konu ağacı — TEK KAYNAK

Uygulamadaki ders/ünite/konu ağacının **yazım kaynağı** budur. Buradan üretilen
üç çıktı elle düzenlenmez:

| Çıktı | Kim okur |
|---|---|
| `supabase/migrations/…_curriculum_seed.sql` | veritabanı (çalışma zamanı kaynağı) |
| `assets/curriculum/tree.json` | istemcinin gömülü yedeği (ilk açılış / çevrimdışı) |

Üretici: `python3 tools/build_taxonomy.py` · Denetim: `--check` · Kendi sınaması: `--selftest`

## Biçim

```
## <müfredat>          eski | maarif
### <sınav>            TYT | AYT
#### <ders>
##### <ünite>
- <konu> | ara: <etiket, etiket> | eski: <eski ad, [SINAV/]eski ad>
```

- **`ara:`** — arama etiketleri. Yalnızca konu seçicide eşleşir; kaydedilen
  değer her zaman kanonik konu adıdır. Öğrencinin kafasındaki adı ("atışlar")
  ağaçtaki ada ("Kuvvet ve Hareket") bağlar. **AI istemine girmez.**
- **`eski:`** — konunun eski adları. Hem arama etiketi olur hem de üretici
  mevcut satırları yeniden eşleyen `UPDATE`'leri yazar; yeniden adlandırma
  böylece geçmiş ilerlemeyi öksüz bırakmaz. `SINAV/` öneki, kaydın sınavının
  da değiştiğini söyler.

Bir konuyu yeniden adlandırırken eski adını `eski:` listesine EKLEYİN — silmeyin.

## Kurallar (üretici zorluyor)

1. Aynı ders altında iki konu aynı ada sahip olamaz.
2. Bir etiket, aynı ders altındaki bir konu adıyla aynı olamaz.
3. Bir etiket aynı ders altında iki farklı konuya işaret edemez.
4. Her dersin `lib/widgets/mistake_style.dart` içinde bir rengi olmalı.
5. Boş ünite olamaz.

---

<!-- AGAC BASLANGICI -->
<!-- Bu isaretin ustundeki her sey ACIKLAMA metnidir; uretici yalnizca
     altini okur. Isaret olmadan `## Bicim` gibi bir baslik mufredat
     sanilirdi — ayristiricinin sessizce yanlis okumasindansa hata vermesi
     icin isaret ZORUNLU. -->

## eski

<!-- eski müfredat (2018) — 2026-2027 sınavları -->

### TYT

#### Türkçe

##### Anlam Bilgisi

- Sözcükte Anlam
- Cümlede Anlam
- Paragrafta Anlam

##### Dil Bilgisi

- Ses Bilgisi
- Biçim Bilgisi
- Sözcük Türleri | eski: Edat-Bağlaç-Ünlem, Sıfat, Zamir, Zarf, İsim (Ad)
- Fiiller | eski: Fiilde Anlam (Kip-Kişi), Fiilimsi
- Cümlenin Ögeleri
- Cümle Türleri

##### Yazım ve Anlatım

- Yazım Kuralları
- Noktalama İşaretleri
- Anlatım Bozuklukları

#### Matematik

##### Mantık

- Önermeler ve Bileşik Önermeler | eski: Mantık

##### Kümeler

- Kümelerde Temel Kavramlar | eski: Kümeler
- Kümelerde İşlemler

##### Sayılar ve Denklemler

- Sayı Kümeleri | ara: rasyonel sayılar, irrasyonel sayılar, tam sayılar, mutlak değer | eski: Temel Kavramlar
- Bölünebilme Kuralları | ara: asal çarpan, ebob, ekok, kalan bulma | eski: Bölme-Bölünebilme
- Birinci Dereceden Denklemler ve Eşitsizlikler | eski: Basit Eşitsizlikler
- Üslü İfadeler ve Denklemler | ara: üs, köklü ifadeler | eski: Üslü Sayılar
- Denklemler ve Eşitsizlikler ile İlgili Uygulamalar | ara: problemler, yaş problemi, hız problemi, işçi problemi, yüzde, oran orantı, kâr zarar, karışım | eski: Sayı Problemleri

##### Veri

- Merkezi Eğilim ve Yayılım Ölçüleri | ara: ortalama, medyan, mod, standart sapma, açıklık | eski: İstatistik
- Verilerin Grafikle Gösterilmesi

##### Sayma ve Olasılık

- Sıralama ve Seçme | ara: permütasyon, kombinasyon, faktöriyel | eski: Permütasyon-Kombinasyon
- Basit Olayların Olasılıkları | ara: olasılık, zar, madeni para | eski: Olasılık

##### Fonksiyonlar

- Fonksiyon Kavramı ve Gösterimi | eski: Fonksiyonlar
- İki Fonksiyonun Bileşkesi ve Bir Fonksiyonun Tersi

##### Polinomlar

- Polinom Kavramı ve Polinomlarda İşlemler | eski: Polinomlar
- Polinomların Çarpanlara Ayrılması | ara: özdeşlikler, iki kare farkı, tam kare, çarpanlara ayırma

##### İkinci Dereceden Denklemler

- İkinci Dereceden Bir Bilinmeyenli Denklemler | ara: diskriminant, kökler toplamı, parabol | eski: İkinci Dereceden Denklemler

#### Geometri

##### Üçgenler

- Üçgenlerde Temel Kavramlar | eski: Üçgende Açılar
- Üçgenlerde Eşlik ve Benzerlik | ara: benzerlik, thales, eşlik | eski: Üçgende Benzerlik
- Üçgenin Yardımcı Elemanları | ara: açıortay, kenarortay, yükseklik, iç teğet çember | eski: Açıortay, Kenarortay
- Dik Üçgen ve Trigonometri | ara: pisagor, öklid, özel üçgenler, 30-60-90 | eski: Dik Üçgen
- Üçgenin Alanı | eski: Üçgende Alan

##### Dörtgenler ve Çokgenler

- Çokgenler | ara: beşgen, altıgen, iç açılar toplamı, düzgün çokgen
- Dörtgenler ve Özellikleri
- Özel Dörtgenler | ara: paralelkenar, eşkenar dörtgen, yamuk, dikdörtgen, kare, deltoid | eski: Dikdörtgen ve Kare, Paralelkenar

##### Katı Cisimler

- Katı Cisimler | ara: prizma, piramit, küp, silindir, koni, küre

#### Fizik

##### Mekanik

- Fizik Bilimine Giriş
- Madde ve Özellikleri | ara: özkütle, yoğunluk, adezyon, kohezyon, yüzey gerilimi
- Hareket ve Kuvvet | ara: atışlar, eğik atış, dikey atış, yatay atış, newton yasaları, ivme, sürtünme kuvveti, hız-zaman grafiği | eski: Basit Makineler, Doğrusal Hareket, Kuvvet ve Denge (Vektörler)
- Enerji | ara: iş, güç, kinetik enerji, potansiyel enerji, verim | eski: İş-Güç-Enerji
- Basınç ve Kaldırma Kuvveti | ara: arşimet, akışkanlar, bernoulli, sıvı basıncı, gaz basıncı | eski: Basınç, Sıvıların Kaldırma Kuvveti

##### Isı, Elektrik ve Manyetizma

- Isı ve Sıcaklık | ara: genleşme, hâl değişimi, kalorimetre, öz ısı
- Elektrostatik | ara: yük, coulomb, elektroskop, topraklama
- Elektrik ve Manyetizma | ara: devre, direnç, ohm kanunu, kondansatör, mıknatıs, ampul | eski: Elektrik Akımı ve Devreler, Mıknatıslar ve Manyetik Alan

##### Dalgalar ve Optik

- Dalgalar | ara: ses dalgası, su dalgası, yay dalgası, deprem dalgası | eski: Dalgalar (Temel), Yay ve Su Dalgaları
- Optik | ara: mercek, ayna, kırılma, yansıma, gölge, prizma, renk | eski: Düzlem Ayna, Işık ve Gölge, Küresel Aynalar, Kırılma ve Renkler, Mercekler

#### Kimya

##### Kimyanın Temelleri

- Kimya Bilimi | eski: Kimya Bilimine Giriş
- Atom ve Periyodik Sistem | eski: Atomun Yapısı, Periyodik Sistem
- Kimyasal Türler Arası Etkileşimler | eski: Kovalent Bağ, Metalik Bağ ve Zayıf Etkileşimler, İyonik Bağ

##### Maddenin Hâlleri ve Karışımlar

- Maddenin Hâlleri | eski: Maddenin Halleri
- Kimyanın Temel Kanunları ve Kimyasal Hesaplamalar | eski: Kimyanın Temel Kanunları, Mol Kavramı ve Hesaplamalar
- Karışımlar

##### Asitler, Bazlar ve Günlük Kimya

- Asitler, Bazlar ve Tuzlar | eski: Asit-Baz
- Kimya Her Yerde
- Doğa ve Kimya

#### Biyoloji

##### Canlıların Temel Bileşenleri

- Canlıların Ortak Özellikleri
- Canlıların Yapısında Bulunan İnorganik Bileşikler | eski: İnorganik Bileşikler
- Canlıların Yapısında Bulunan Organik Bileşikler | eski: Enzimler, Nükleik Asitler, Organik Bileşikler (Karbonhidrat-Lipit-Protein)

##### Hücre

- Hücresel Yapılar ve Görevleri | ara: organel, mitokondri, ribozom, çekirdek | eski: Hücre ve Organelleri
- Hücre Zarından Madde Geçişleri | ara: difüzyon, osmoz, aktif taşıma, endositoz | eski: Hücre Zarından Madde Geçişi
- Hücre Döngüsü ve Mitoz | ara: mitoz, hücre bölünmesi | eski: Mitoz ve Eşeysiz Üreme
- Eşeysiz Üreme
- Mayoz | ara: krossing over, mayoz bölünme | eski: Mayoz ve Eşeyli Üreme
- Eşeyli Üreme

##### Canlılar Dünyası ve Kalıtım

- Canlıların Sınıflandırılması | ara: sınıflandırma, taksonomi
- Canlı Âlemleri
- Kalıtım | ara: mendel, genetik, çaprazlama, kan grupları
- Genetik Varyasyonlar

##### Ekoloji

- Ekosistem Ekolojisi | ara: besin zinciri, madde döngüsü, enerji piramidi | eski: Madde Döngüleri
- Güncel Çevre Sorunları
- Doğal Kaynakların Sürdürülebilirliği
- Biyolojik Çeşitliliğin Korunması

#### Tarih

##### Tarih Bilimi

- Tarih ve Zaman | eski: İnsanlığın İlk Dönemleri

##### İlk Çağlardan Türk-İslam Dünyasına

- İlk ve Orta Çağlarda Türk Dünyası | eski: Orta Çağ'da Dünya
- İslam Medeniyetinin Doğuşu
- Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet'i Kabulü | eski: Türklerin İslamiyet'i Kabulü
- Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi | eski: Selçuklu Türkiyesi

##### Osmanlı Tarihi

- Beylikten Devlete Osmanlı Siyaseti (1302-1453) | eski: Beylikten Devlete Osmanlı (1302-1453)
- Devletleşme Sürecinde Savaşçılar ve Askerler
- Beylikten Devlete Osmanlı Medeniyeti | eski: Osmanlı Medeniyeti
- Dünya Gücü Osmanlı (1453-1595)
- Sultan ve Osmanlı Merkez Teşkilatı | eski: Osmanlı Merkez Teşkilatı
- Klasik Çağda Osmanlı Toplum Düzeni
- Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774)
- Değişim Çağında Avrupa ve Osmanlı
- Uluslararası İlişkilerde Denge Stratejisi (1774-1914)

##### Yakın Çağ ve Cumhuriyet

- Devrimler Çağında Değişen Devlet-Toplum İlişkileri
- XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat
- XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya
- Millî Mücadele
- Atatürkçülük ve Türk İnkılabı

#### Coğrafya

##### Doğal Sistemler

- Coğrafya Bilimi, İnsan ve Doğa | eski: Doğa ve İnsan
- Dünya'nın Şekli ve Hareketleri
- Yer ve Zaman, Koordinat Sistemi
- Harita Bilimi | eski: Harita Bilgisi
- İklim Bilimi | eski: Atmosfer ve Sıcaklık, Basınç ve Rüzgârlar, Nem-Yağış-Buharlaşma
- Dünya'nın Yapısı ve Oluşum Süreci | eski: Dış Kuvvetler, İç Kuvvetler
- Su Kaynakları, Topraklar, Bitkiler | eski: Su Kaynakları, Toprak ve Bitki Örtüsü

##### Beşerî Sistemler

- Yerleşmeler | eski: Yerleşme
- Nüfus, Göç, Ekonomik Faaliyetler | eski: Ekonomik Faaliyetler, Göç, Nüfus
- Ulaşım

##### Küresel Ortam

- Bölgeler ve Ülkeler | eski: Bölgeler

##### Çevre ve Toplum

- İnsan ve Çevre | eski: Çevre ve Toplum
- Afetler | eski: Doğal Afetler

#### Felsefe

##### Felsefeye Giriş

- Felsefeyi Tanıma | eski: Felsefenin Konusu
- Felsefe ile Düşünme
- Felsefi Okuma ve Yazma

##### Felsefenin Temel Konuları

- Varlık Felsefesi
- Bilgi Felsefesi
- Bilim Felsefesi
- Ahlak Felsefesi
- Din Felsefesi
- Siyaset Felsefesi
- Sanat Felsefesi

##### Felsefe Tarihi

- MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi
- MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi
- 15. Yüzyıl-17. Yüzyıl Felsefesi
- 18. Yüzyıl-19. Yüzyıl Felsefesi
- 20. Yüzyıl Felsefesi

#### Din Kültürü

##### İnanç

- Bilgi ve İnanç
- Din ve İslam
- Allah İnsan İlişkisi | eski: Allah-İnsan İlişkisi
- İslam Düşüncesinde İtikadi, Siyasi ve Fıkhi Yorumlar | eski: İslam Düşüncesinde Yorumlar

##### İbadet ve Ahlak

- İslam ve İbadet
- Ahlaki Tutum Davranışlar | eski: Ahlaki Tutum ve Davranışlar
- Din ve Hayat

##### Değerler ve Kültür

- Gençlik ve Değerler
- Gönül Coğrafyamız
- Hz. Muhammed ve Gençlik

### AYT

#### Matematik

##### Trigonometri

- Yönlü Açılar | eski: Trigonometri: Yönlü Açılar
- Trigonometrik Fonksiyonlar | ara: sinüs, kosinüs, tanjant, birim çember | eski: Kosinüs ve Sinüs Teoremi, Sinüs ve Kosinüs Fonksiyonlarının Grafikleri, Ters Trigonometrik Fonksiyonlar
- Toplam-Fark ve İki Kat Açı Formülleri | eski: Trigonometri: Toplam-Fark ve İki Kat Açı
- Trigonometrik Denklemler

##### Fonksiyonlarda Uygulamalar

- Fonksiyonların Grafik ve Problemleri | eski: Fonksiyonlarda Uygulamalar (Ters-Bileşke)
- İkinci Dereceden Fonksiyonlar ve Grafikleri | eski: Parabol, İkinci Dereceden Denklemler
- Fonksiyonların Dönüşümleri

##### Denklem ve Eşitsizlik Sistemleri

- İkinci Dereceden İki Bilinmeyenli Denklem Sistemleri
- İkinci Dereceden Eşitsizlikler | eski: Eşitsizlikler

##### Üstel ve Logaritmik Fonksiyonlar

- Üstel Fonksiyon
- Logaritma Fonksiyonu | ara: logaritma, log | eski: Logaritma
- Üstel ve Logaritmik Denklem ve Eşitsizlikler

##### Diziler

- Diziler | ara: aritmetik dizi, geometrik dizi, limit dizi

##### Türev

- Limit ve Süreklilik | ara: limit, süreklilik, belirsizlik
- Türev | ara: türev alma, teğet eğimi
- Türev Uygulamaları | ara: maksimum minimum, artan azalan, ekstremum, asimptot | eski: Türev Uygulamaları (Optimizasyon)

##### İntegral

- Belirsiz İntegral | ara: integral, ilkel fonksiyon | eski: İntegral
- Belirli İntegral ve Alan Hesabı | ara: alan hesabı, hacim hesabı | eski: İntegral ile Alan Hesabı

##### Olasılık

- Koşullu Olasılık | ara: bağımlı olay, bayes
- Deneysel ve Teorik Olasılık | eski: Binom ve Olasılık

#### Geometri

##### Analitik Geometri

- Doğrunun Analitik İncelenmesi | ara: eğim, doğru denklemi, analitik düzlem | eski: Analitik Geometri (Doğru)
- Çemberin Analitik İncelenmesi | ara: çember denklemi

##### Dönüşümler

- Analitik Düzlemde Temel Dönüşümler | ara: öteleme, dönme, simetri, yansıma

##### Çember ve Daire

- Çemberde Temel Kavramlar | eski: TYT/Çember ve Daire
- Çemberde Açılar | ara: çevre açı, merkez açı, teğet-kiriş açı
- Çemberde Teğet | ara: teğet, kuvvet
- Dairenin Çevresi ve Alanı | ara: daire alanı, daire dilimi, yay uzunluğu

##### Uzay Geometri

- Katı Cisimler (Küre, Silindir, Koni) | ara: küre, silindir, koni, hacim | eski: Katı Cisimler (Piramit-Koni-Küre), Katı Cisimler (Prizma-Silindir)

#### Fizik

##### Mekanik

- Kuvvet ve Hareket | ara: atışlar, eğik atış, dikey atış, yatay atış, newton yasaları, momentum, itme, tork, denge | eski: Bağıl Hareket, Bir Boyutta Sabit İvmeli Hareket, Enerji ve Hareket, Kuvvet, Tork ve Denge, Newton'un Hareket Yasaları, Vektörler, İki Boyutta Sabit İvmeli Hareket, İtme ve Momentum
- Çembersel Hareket | ara: merkezcil kuvvet, açısal hız, dönme, eylemsizlik momenti
- Basit Harmonik Hareket | ara: sarkaç, yay sarkacı, periyot

##### Elektromanyetizma ve Dalgalar

- Elektrik ve Manyetizma | ara: indüksiyon, transformatör, manyetik alan, alternatif akım | eski: Elektrik Alan ve Potansiyel, Kondansatörler, Manyetizma ve İndüksiyon
- Dalga Mekaniği | ara: girişim, kırınım, doppler, elektromanyetik dalga | eski: Dalga Mekaniği (Girişim-Kırınım-Doppler)

##### Modern Fizik

- Atom Fiziğine Giriş ve Radyoaktivite | ara: radyoaktivite, yarılanma süresi, atom modelleri, fisyon, füzyon | eski: Atom Fiziği ve Radyoaktivite
- Modern Fizik | ara: özel görelilik, fotoelektrik, compton, kara cisim ışıması | eski: Compton ve de Broglie, Fotoelektrik Olay, Özel Görelilik
- Modern Fiziğin Teknolojideki Uygulamaları

#### Kimya

##### Atom, Gazlar ve Çözeltiler

- Modern Atom Teorisi
- Gazlar
- Sıvı Çözeltiler ve Çözünürlük

##### Tepkimelerde Enerji, Hız ve Denge

- Kimyasal Tepkimelerde Enerji
- Kimyasal Tepkimelerde Hız
- Kimyasal Tepkimelerde Denge

##### Elektrokimya ve Organik Kimya

- Kimya ve Elektrik | eski: Elektrokimyasal Hücreler ve Piller, Elektroliz, Redoks Tepkimeleri
- Karbon Kimyasına Giriş | eski: Karbon Kimyasına Giriş (Hibritleşme)
- Organik Bileşikler | eski: Aldehit ve Ketonlar, Alkoller ve Eterler, Hidrokarbonlar, Karboksilik Asitler ve Esterler
- Enerji Kaynakları ve Bilimsel Gelişmeler | eski: Enerji Kaynakları

#### Biyoloji

##### İnsan Fizyolojisi

- Sinir Sistemi | ara: nöron, refleks, merkezi sinir sistemi
- Endokrin Sistem | ara: hormon, hipofiz, tiroit | eski: Endokrin Sistem ve Hormonlar
- İskelet Sistemi | eski: Destek ve Hareket Sistemi
- Kas Sistemi | ara: kas, kas kasılması
- Duyu Organları | ara: göz, kulak, deri
- Kan Dolaşımı | ara: kalp, damar, kan | eski: Dolaşım Sistemi
- Lenf Dolaşımı
- Sindirim Sistemi | ara: mide, karaciğer, sindirim enzimleri
- Solunum Sistemi | ara: akciğer, soluk alıp verme
- Üriner Sistem | ara: böbrek, nefron, boşaltım | eski: Boşaltım Sistemi
- Üreme Sistemi | eski: Üreme Sistemi ve Embriyonik Gelişim
- Bağışıklık Sistemi | ara: antikor, aşı, savunma
- Embriyonik Gelişim

##### Ekoloji

- Komünite Ekolojisi
- Popülasyon Ekolojisi | ara: popülasyon, büyüme eğrisi

##### Genetik ve Enerji Dönüşümleri

- Nükleik Asitler | ara: dna, rna, replikasyon | eski: DNA Replikasyonu
- Genetik Şifre ve Protein Sentezi | ara: transkripsiyon, translasyon, protein sentezi | eski: Protein Sentezi
- Genetik Mühendisliği ve Biyoteknoloji | eski: Modern Genetik Uygulamaları
- Canlılık ve Enerji
- Fotosentez | ara: kloroplast, ışık reaksiyonları, calvin
- Kemosentez
- Hücresel Solunum | ara: glikoliz, krebs, etaş
- Fermantasyon | ara: laktik asit, etil alkol

##### Bitki Biyolojisi

- Bitkisel Dokular
- Bitkisel Organlar | ara: kök, gövde, yaprak
- Bitkilerde Madde Taşınması | ara: terleme, ksilem, floem | eski: Bitkilerde Taşıma-Beslenme-Terleme
- Bitkilerde Hareket
- Bitki Hormonları | eski: Bitkisel Hormonlar
- Bitkilerde Eşeyli Üreme | eski: Bitkilerde Üreme
- Canlılar ve Çevre

#### Edebiyat

##### Giriş ve Genel Konular

- Edebiyata Giriş | eski: Edebiyat Bilgisi ve Metin Türleri
- Şiir Bilgisi
- Edebî Sanatlar
- Edebî Akımlar

##### Şiir

- İslamiyet Öncesi Türk Şiiri | eski: İslamiyet Öncesi Türk Edebiyatı
- Geçiş Dönemi Türk Şiiri | eski: Geçiş Dönemi Eserleri
- Halk Şiiri | eski: Halk Edebiyatı (Âşık-Anonim)
- Divan Şiiri | eski: Divan Edebiyatı
- Tanzimat Dönemi Türk Şiiri | eski: Tanzimat Edebiyatı
- Servetifünun Dönemi Türk Şiiri | eski: Servet-i Fünun Edebiyatı
- Fecriati Dönemi Türk Şiiri
- Millî Edebiyat Dönemi Türk Şiiri | eski: Millî Edebiyat
- Cumhuriyet Dönemi Türk Şiiri

##### Hikâye

- Hikâye Türleri ve Hikâyenin Yapı Unsurları | eski: Hikâye
- Tanzimat Dönemi'ne Kadar Halk Hikâyesi ve Mesneviler
- Tanzimat ve Servetifünun Dönemi Türk Hikâyesi
- Millî Edebiyat Dönemi Türk Hikâyesi
- Cumhuriyet Dönemi Türk Hikâyesi

##### Roman

- Roman Türü ve Yapı Unsurları | eski: Roman
- Tanzimat Dönemi Türk Romanı
- Servetifünun Dönemi Türk Romanı
- Millî Edebiyat Dönemi Türk Romanı
- Cumhuriyet Dönemi Türk Romanı
- Dünya Edebiyatında Roman

##### Tiyatro

- Tiyatro Türü ve Yapı Unsurları | eski: Tiyatro
- Geleneksel Türk Tiyatrosu
- Tanzimat, Servetifünun ve Millî Edebiyat Dönemi Türk Tiyatrosu
- Cumhuriyet Dönemi Türk Tiyatrosu

##### Diğer Türler

- Masal/Fabl
- Destan/Efsane
- Öğretici Metinler
- Divan Edebiyatı Nesir Türleri

#### Tarih

##### Tarih Bilimi

- Tarih ve Zaman

##### İlk Çağlardan Türk-İslam Dünyasına

- İlk ve Orta Çağlarda Türk Dünyası
- İslam Medeniyetinin Doğuşu
- Türk İslam Tarihindeki Siyasi Gelişmeler, Türklerin İslamiyet'i Kabulü
- Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi

##### Osmanlı Tarihi

- Beylikten Devlete Osmanlı Siyaseti (1302-1453)
- Devletleşme Sürecinde Savaşçılar ve Askerler
- Beylikten Devlete Osmanlı Medeniyeti
- Dünya Gücü Osmanlı (1453-1595)
- Sultan ve Osmanlı Merkez Teşkilatı
- Klasik Çağda Osmanlı Toplum Düzeni
- Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti (1595-1774) | eski: Değişen Dünya Dengeleri ve Osmanlı Siyaseti (1595-1774)
- Değişim Çağında Avrupa ve Osmanlı
- Uluslararası İlişkilerde Denge Stratejisi (1774-1914) | eski: Uluslararası İlişkilerde Denge (1774-1914)

##### Yakın Çağ ve Cumhuriyet

- Devrimler Çağında Değişen Devlet-Toplum İlişkileri | eski: Devrimler Çağı
- XIX. ve XX. Yüzyılda Değişen Sosyo-Ekonomik Hayat | eski: Sermaye ve Emek, XIX-XX. Yüzyılda Gündelik Hayat
- XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya | eski: XX. Yüzyıl Başlarında Osmanlı
- Millî Mücadele
- Atatürkçülük ve Türk İnkılabı

##### Çağdaş Türkiye ve Dünya

- İki Savaş Arasındaki Dönemde Türkiye ve Dünya | eski: İki Savaş Arası Dönem
- II. Dünya Savaşı Sürecinde Türkiye ve Dünya | eski: II. Dünya Savaşı
- II. Dünya Savaşı Sonrasında Türkiye ve Dünya | eski: Soğuk Savaş Dönemi
- Toplumsal Devrim Çağında Dünya ve Türkiye
- XXI. Yüzyılın Eşiğinde Türkiye ve Dünya

#### Coğrafya

##### Ekosistem ve Doğa

- Ekosistemlerin İşleyişi ve Özellikleri | eski: Doğal Sistemler (Biyoçeşitlilik), Ekosistem ve Madde Döngüsü
- Ekstrem Doğa Olayları ve Doğa Olaylarının Geleceği | eski: Doğal Afetler ve Toplum

##### Beşerî ve Ekonomik Sistemler

- Nüfus Politikaları ve Yerleşmeler | eski: Beşerî Sistemler, Nüfus Politikaları, Türkiye'de Nüfus ve Yerleşme
- Ekonomik Faaliyetler ve Doğal Kaynaklar | eski: Doğal Kaynaklar
- Türkiye'de Ekonomi | eski: Türkiye Ekonomisinin Sektörel Dağılımı, Türkiye'de Madenler ve Enerji Kaynakları, Türkiye'de Sanayi, Türkiye'de Tarım
- Ekonomi, Şehirleşme ve Göç | eski: Göç ve Şehirleşme
- Ulaşım, Ticaret, Turizm | eski: Türkiye'de Ticaret-Ulaşım-Turizm
- Türkiye'nin İşlevsel Bölgeleri ve Kalkınma Projeleri | eski: Bölgesel Kalkınma Projeleri

##### Kültür ve Küresel Ortam

- Kültür Bölgeleri
- Küreselleşen Dünya | eski: Küresel Ortam: Bölgeler ve Ülkeler
- Jeopolitik Konum ve Ülkeler Arası Etkileşim

##### Çevre ve Toplum

- Çevre Sorunları | eski: Çevre ve Toplum
- Doğal Çevrenin Sınırlılığı, Çevresel Örgüt ve Anlaşmalar

#### Felsefe Grubu

##### Felsefe

- Felsefeyi Tanıma
- Felsefe ile Düşünme
- Felsefi Okuma ve Yazma
- Varlık Felsefesi
- Bilgi Felsefesi
- Bilim Felsefesi
- Ahlak Felsefesi
- Din Felsefesi
- Siyaset Felsefesi
- Sanat Felsefesi
- MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi | eski: İlk Çağ Felsefesi
- MS 2. Yüzyıl-MS 15. Yüzyıl Felsefesi | eski: Ortaçağ Felsefesi
- 15. Yüzyıl-17. Yüzyıl Felsefesi | eski: Yeni Çağ Felsefesi
- 18. Yüzyıl-19. Yüzyıl Felsefesi | eski: 19. Yüzyıl Felsefesi
- 20. Yüzyıl Felsefesi

##### Mantık

- Mantığa Giriş
- Klasik Mantık
- Mantık ve Dil
- Sembolik Mantık

##### Psikoloji

- Psikoloji Bilimini Tanıyalım
- Psikolojinin Temel Süreçleri
- Öğrenme, Bellek, Düşünme
- Ruh Sağlığının Temelleri

##### Sosyoloji

- Sosyolojiye Giriş
- Toplumsal Yapı
- Birey ve Toplum
- Toplum ve Kültür
- Toplumsal Kurumlar
- Toplumsal Değişme ve Gelişme

#### Din Kültürü

##### İnanç ve İbadet

- Dünya ve Ahiret
- İnançla İlgili Meseleler

##### Kur'an ve Hz. Muhammed

- Kur'an'a Göre Hz. Muhammed
- Kur'an'da Bazı Kavramlar | eski: Kur'an'da Kavramlar

##### Dinler ve Kültür

- Yahudilik ve Hristiyanlık
- Hint ve Çin Dinleri
- Anadolu'da İslam

##### İslam Düşüncesi

- İslam ve Bilim
- İslam Düşüncesinde Tasavvufi Yorumlar | eski: Tasavvufi Yorumlar
- Güncel Dinî Meseleler

## maarif

<!-- Maarif Modeli — 2028 ve sonrası -->

### TYT

#### Türkçe

##### Metin Türleri

- Şiir
- Öyküleyici Metin
- Tiyatro
- Öğretici Metin

##### Dil Bilgisi

- Ses Bilgisi
- Yapı Bilgisi (Ekler)
- İsim ve Sıfat
- Zamir-Zarf-Edat
- Fiil ve Fiilimsi
- Cümlenin Ögeleri
- Anlatım Bozuklukları

#### Matematik

##### Sayılar

- Üslü İfadeler
- Köklü İfadeler
- Sayı Kümeleri
- Özdeşlikler (İki Kare Farkı-Tam Kare)

##### Nicelikler ve Değişimler

- Doğrusal Fonksiyonlar
- Mutlak Değer
- Denklem-Eşitsizlik
- Fonksiyonlar ve Denklemler

##### Mantıksal Çıkarım

- Mantıksal Çıkarım
- Algoritma ve Bilişim

##### Trigonometri

- Trigonometriye Giriş

##### Veriden Olasılığa

- Veriden Olasılığa

#### Geometri

##### Üçgenler

- Üçgende Eşlik ve Benzerlik | ara: benzerlik, thales, pisagor, açıortay, kenarortay

##### Çokgenler ve Dörtgenler

- Çokgenler | ara: beşgen, altıgen, iç açılar toplamı
- Dörtgenler | ara: paralelkenar, yamuk, dikdörtgen, kare, eşkenar dörtgen

##### Çember

- Çember | ara: çevre açı, merkez açı, teğet, daire alanı

##### Analitik Geometri

- Analitik Geometriye Giriş

#### Fizik

##### Fizik Bilimi

- Fizik Bilimi ve Kariyer

##### Kuvvet ve Hareket

- Kuvvet ve Hareket | ara: atışlar, eğik atış, dikey atış, yatay atış, newton yasaları, ivme, sürtünme kuvveti

##### Akışkanlar

- Akışkanlar (Basınç) | ara: basınç, sıvı basıncı, gaz basıncı
- Akışkanlar (Kaldırma Kuvveti-Bernoulli) | ara: arşimet, kaldırma kuvveti, bernoulli

##### Enerji

- Enerji (Isı-Hâl Değişimi) | ara: ısı, hâl değişimi, öz ısı, genleşme

##### Elektrik

- Elektrik | ara: devre, direnç, ohm kanunu, yük

##### Dalgalar

- Dalgalar | ara: ses dalgası, su dalgası, girişim

#### Kimya

##### Etkileşim

- Kimya Hayattır
- Atomdan Periyodik Tabloya
- Kimyasal Türler Arası Etkileşimler

##### Çeşitlilik

- Kimyasal Tepkimeler
- Gazlar
- Çözeltiler
- Redoks (Etkileşim)

##### Sürdürülebilirlik

- Sürdürülebilirlik

#### Biyoloji

##### Yaşam

- Canlıların Ortak Özellikleri
- Üç Âlem/Domain Sistemi

##### Organizasyon

- Hücre | ara: organel, mitokondri, ribozom, hücre zarı, difüzyon, osmoz
- Organik Moleküller

##### Enerji

- Fotosentez | ara: kloroplast, ışık reaksiyonları
- Hücresel Solunum | ara: glikoliz, krebs, fermantasyon

##### Ekoloji

- Ekosistem Ekolojisi | ara: besin zinciri, madde döngüsü

#### Tarih

##### Tarih Bilimi

- Geçmişin İnşa Sürecinde Tarih
- Medeniyet/Uygarlık Tarihi

##### Türk Tarihi

- Türkistan'dan Türkiye'ye
- Beylikten Devlete Osmanlı
- Cihan Devleti Osmanlı (İstanbul'un Fethi)

#### Coğrafya

##### Coğrafi Beceriler

- Coğrafyanın Doğası
- Mekânsal Bilgi Teknolojileri

##### Doğal Sistemler

- Doğal Sistemler ve Süreçler (İklim)

##### Beşerî Sistemler

- Beşerî Sistemler ve Süreçler
- Ekonomik Faaliyetler ve Etkileri

##### Çevre ve Küresel Bağlantılar

- Afetler ve Sürdürülebilir Çevre
- Bölgesel/Küresel Bağlantılar

#### Felsefe

##### Felsefeye Giriş

- Felsefeye Giriş
- Felsefe ile Düşünme (Argümantasyon)

##### Felsefenin Temel Konuları

- Bilgi Felsefesi
- Bilim Felsefesi
- Ahlak Felsefesi

#### Din Kültürü

##### İnanç

- Allah-İnsan İlişkisi
- İslam'da İnanç Esasları
- İslam'da Varlık ve Bilgi

##### İbadet ve Ahlak

- İslam'da İbadetler
- İslam'da Ahlak İlkeleri

##### Hz. Muhammed ve Güncel Konular

- Kur'an'a Göre Hz. Muhammed
- Din, Çevre ve Teknoloji

### AYT

#### Matematik

##### Nicelikler ve Değişimler

- Nicelikler ve Değişimler

##### İstatistiksel Araştırma

- İstatistiksel Araştırma Süreci

##### Analiz

- Türev | ara: türev alma, limit, maksimum minimum
- İntegral | ara: alan hesabı, belirli integral
- Logaritma | ara: log, üslü ifade

#### Geometri

##### Geometrik Şekiller

- Geometrik Şekiller

#### Fizik

##### Kuvvet ve Hareket

- Kuvvet ve Hareket (Newton Yasaları) | ara: atışlar, eğik atış, dikey atış, yatay atış, momentum, tork, denge
- Çembersel Hareket | ara: merkezcil kuvvet, açısal hız, dönme

##### Elektrik ve Manyetizma

- Elektriksel ve Manyetik Alan | ara: manyetik alan, elektrik alan, coulomb
- İndüksiyon ve Transformatörler | ara: indüksiyon, transformatör, alternatif akım

##### Madde ve Doğası

- Madde ve Doğası (Yarı İletkenler)

##### Optik, Enerji ve Dalgalar

- Optik | ara: mercek, ayna, kırılma, yansıma
- Enerji
- Dalgalar

#### Kimya

##### Tepkimeler

- Kimyasal Tepkimeler ve Enerji
- Tepkime Hızı
- Kimyasal Denge

##### Çözeltilerde Denge

- Asit-Baz Dengeleri

##### Sürdürülebilirlik

- Sürdürülebilirlik (Yeşil Kimya)

#### Biyoloji

##### Tepki

- Sinir Sistemi ve Refleks | ara: nöron, refleks, sinir
- İskelet-Kas-Eklem Sistemi | ara: kemik, kas, eklem
- Bağışıklık ve Alerji | ara: antikor, aşı, alerji

##### Homeostazi

- Endokrin Sistem | ara: hormon, hipofiz, tiroit
- Dolaşım Sistemi | ara: kalp, damar, kan
- Solunum Sistemi | ara: akciğer, soluk alıp verme
- Boşaltım Sistemi | ara: böbrek, nefron
- Denge Bozuklukları (Diyabet-Hipertansiyon-Obezite) | ara: diyabet, hipertansiyon, obezite, şeker hastalığı

#### Edebiyat

##### Bir Diyeceğim Var!

- Mektup-Dilekçe-E-posta
- Geleneksel Türk Tiyatrosu

##### Kültür Yolculuğu

- Orhun Abideleri ve Geçiş Dönemi
- Âşık Tarzı Halk Şiiri
- Halk Hikâyesi

##### Yaşamın İzinde

- Roman
- Biyografi ve Tezkire
- Radyo Tiyatrosu

##### Hayatın Aynası

- Modern Türk Tiyatrosu
- Küçürek Hikâye
- Belgesel

#### Tarih

##### Osmanlı ve Değişim

- Osmanlı'da Gerileme ve Değişim
- Fransız İhtilali ve Milliyetçilik

##### Savaşlar Çağı

- Balkan Savaşları
- I. Dünya Savaşı'na Giden Süreç

#### Coğrafya

##### Beşerî Coğrafya

- İleri Nüfus
- İleri Yerleşme

##### Ekonomik Coğrafya

- Ekonomik Coğrafya
