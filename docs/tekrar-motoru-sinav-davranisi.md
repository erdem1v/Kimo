# Tekrar motoru: sınav tarihine yaklaşırken bugünkü davranış

Ekiple değerlendirilecek ürün notu — **kod değişikliği yok**, mevcut çalışma
prensibinin açık anlatımı. Kaynak: `lib/features/reviews/domain/
review_scheduler.dart` (Task 03 sonrası hâli).

## Kurallar (bugünkü hâliyle)

- **Merdiven:** 1 → 3 → 7 → 30 gün. Yanlış cevap her yerden 0. adıma (1 güne)
  döndürür; 4+ sıfırlanma "inatçı" işareti ve 3 günlük bekleme.
- **Bakım basamağı:** 30'luk adımı doğru geçen soru kuyruğu TERK ETMEZ;
  45 günde bir dönmeye başlar.
- **Sınav tarihi:** kullanıcının sınav yılından türetilir — o yılın
  **20 Haziran'ı** (`ReviewScheduler.examCutoffFor`). YKS haziran ortasında;
  20'si güvenli üst sınır olarak seçildi.
- **"Öğrenildi" (kuyruktan kalıcı çıkış) TEK durumda yazılır:** soru bakım
  basamağındayken doğru cevaplanır VE bir sonraki 45 günlük tekrar sınav
  tarihinden SONRAYA düşerse. O anda `mastered = true` olur ve soru bir daha
  sorulmaz.
- Sınav yılı bilinmiyorsa (metadata boş) soru hiç emekli olmaz — süresiz
  bakımda döner. Yanlış "öğrenildi" demektense sormaya devam etmeyi seçtik.

## Kritik ayrıntı: merdiven adımları sınav tarihine BAKMAZ

Sınav-kesme kontrolü yalnızca bakım basamağında yapılır. Merdivendeki bir
soru, vadesi sınav sonrasına düşecek olsa bile normal aralığına planlanır.

**Sonuç:** sınava 10 gün kala 7-günlük adımı doğru geçen soru +30 güne
planlanır; vade sınavdan sonraya düşer. Soru kuyruktan ÇIKMAZ (`mastered`
olmaz) ama sınavdan önce bir daha da GÖRÜNMEZ. Kullanıcı açısından ikisi
aynı şeydir; tek fark istatistikte "öğrenildi" sayılmaması ve sınav
geçtikten sonra (uygulama hâlâ kullanılıyorsa) sorunun geri gelmesi.

## Sınava az kala eklenen sorular

Yeni soru **aynı gün, kayıttan ~3 saat sonra** ilk kez sorulur (0049).
Sonrası kısa adımlar: +1, +3, +7. Yani sınava örneğin 15 gün kala eklenen
bir soru sınavdan önce **4-5 kez** görülür; 30'luk adım artık sığmaz ve o
tekrar sınav sonrasına taşar (yukarıdaki durumla aynı). Sınava 2-3 gün kala
eklenen soru 2-3 kez görülür. Ekleme hiçbir zaman reddedilmez.

## Pratik sonuç özeti

| Durum | Bugünkü davranış |
|---|---|
| Eylülde eklenen, hep doğru giden soru | ~41 günde bakıma çıkar; sınava kadar 45 günde bir döner; son bakım tekrarı sınavı aşınca "öğrenildi" |
| Sınava 15 gün kala eklenen soru | Aynı gün + 1/3/7 adımlarıyla 4-5 tekrar; 30'luk adım sınav sonrasına taşar, "öğrenildi" sayılmaz |
| Sınava 10 gün kala merdiven ortasında doğru | Sonraki vade sınav sonrasına taşabilir; sorulmaz ama "öğrenildi" de sayılmaz |
| Bakımda yanlış | Merdiven başına döner (1 gün) |
| Sınav yılı seçilmemiş | Hiçbir soru asla "öğrenildi" olmaz |
| Sınav geçtikten sonra uygulamayı açan kullanıcı | Taşmış vadeli tüm sorular birikmiş olarak düşer (yeni sınav yılı seçilirse döngü normal sürer) |

## Ekip için açık soru

Merdiven adımları da sınav-kesmeli olmalı mı? İki seçenek:
(a) **bugünkü hâli** — basit; "sorulmayacak soru" ile "öğrenilmiş soru"
istatistikte ayrışır ama kullanıcı deneyiminde ayrışmaz;
(b) sınava sığmayan merdiven adımını kalan süreye sıkıştırmak (ör. +30
yerine "sınavdan 2 gün önce") — sınav öncesi son bir tur kazandırır,
karşılığında sınav haftasında tekrar yükünü artırır. Karar ekibin;
uygulaması `ReviewScheduler.review` içinde tek noktadır.
