# Task 16 — Onboarding sonrası tur, sunucu sıra hatası avı

Task 15 onboarding'i ve kayıt yolunu kullanılabilir hâle getirdi; en ağır iki
bulgusu bildirilen listede yoktu ve ancak gerçek bir tur ortaya çıkardı. Bu
tur aynı soruyu **onboarding sonrasına** sordu: *aynı sınıftan başka ne var?*

Cevap: **var, ve en ağırı yine bildirilmemişti.**

> Arkadaşa "yeni soru çek ve gönder" yolu, fotoğraf taraması bitmeden
> gönderiyordu. Gönderim sessizce düşüyor, kullanıcıya hiç göndermediği bir
> soru için "yakında göndermiş olabilirsin" deniyordu.

---

## 0. Yöntem

Üç mercekli statik denetim (sıra hataları · kaynak ayrışması ve söz tutmama ·
UX) **22 aday** bulgu çıkardı. Her aday, bulguyu **çürütmeye çalışan** bağımsız
bir ajanla sınandı: **19 doğrulandı, 3 çürütüldü.**

Ardından **iki simülatör** (iPhone 16 Pro + iPhone 16) üzerinde üç hesapla
gerçek tur atıldı: arkadaşlık, gönderim, gelen kutusu, ortak seri, lig, profil,
ayarlar ve hesap silme. Turda iki bulgu **üretimde ölçümle** kanıtlandı.

Çürütülenler rapora girmedi: hak duvarının reklam yolunun kilitlenmesi
(`finally` zaten var), arkadaş sorusu sonrası "bir şeyler ters gitti"
(gösterilmiyor), ayarlarda Plus satırının sessizce kaybolması (sebebi yazıyor).

---

## 1. Bloke eden — ve nasıl ölçüldü

### C0-1 · Gönderim, fotoğraf taraması bitmeden yapılıyordu

**Mekanizma.** Fotoğraflı bir kayıt eklenince `mistakes_photo_scan_reset`
tetikleyicisi `photo_scan`i `'pending'` yapıyor ve tarama edge fonksiyonu
**ateşle-unut** çağrılıyor. `send_question_to_friends` ise
`photo_scan = 'clear'` istiyor (`question_send_guard.sql:138-147`). Onay ekranı
kaydedip pop ediyor ve `capture_screen.dart:431` **aynı karede** gönderiyordu.
Sunucu `not_sendable` dönüyor; istemci bunu `blocked` sayıp
**"Bu soru ona gitmedi — yakında göndermiş olabilirsin."** diyordu. Yeniden
deneme yok: gönderim niyeti kayboluyor, soru arşivde kalıyor.

**Üretimde ölçüldü (düzeltmeden önce):**

| An | Olay |
|---|---|
| `00:06:41.022` | soru yazıldı |
| `00:06:43.444` | tarama bitti — **2,4 saniye sonra** |
| — | `question_sends`'te satır **hiç oluşmadı** |

İstemci sıfır saniye bekliyordu. Bu bir yarış değil, tek yönlü bir sıra hatası.

**Düzeltme.** Bekleme `QuestionSendRepository.sendToFriends` içinde — çekimden
gönderme, arşivden gönderme ve ortak seri davetinin **üçünün de geçtiği tek
nokta**. `not_sendable` gelirse `mistakes.photo_scan` okunuyor; hâlâ `pending`
ise 1+2+3+5 saniyelik merdivenle yeniden deneniyor. Tarama bitmişse ya da
damgalanmışsa beklenmiyor. `not_sendable` artık `blocked`a karışmıyor ve kendi
cümlesini taşıyor.

**Üretimde doğrulandı (düzeltmeden sonra):**

| An | Olay |
|---|---|
| `00:44:27.769` | soru yazıldı |
| `00:44:29.922` | tarama bitti (2,15 s) |
| `00:44:31.531` | **gönderim gerçekleşti** |

Alıcının Bugün ekranında "Arkadaşından 1 soru geldi" göründü.

---

## 2. Görünürde bozuk

| # | Ne oluyordu | Düzeltme |
|---|---|---|
| **"Bugün" ayrışması** | `due_count` 0096'dan beri **zaman** bazlı, `MistakeStats.dueToday` ise **gün** bazlı kalmıştı — yorumu hâlâ "`dueReviews()` ile BİREBİR aynı kural" diyordu. Aynı kullanıcı, aynı an: Bugün ekranı "Bugün tekrar yok", Hatalarım "**Bugün 1**" (vade 05:53, saat 03:11). Turda görüldü | `MistakeEntry` artık `next_review_at` taşıyor; kural sunucununkiyle birleşti. Turda "Bugün 0" olarak doğrulandı |
| **C0-2 · Günlük hedef ödülü** | `claim_daily_goal` o günkü `study_attempts` sayısını okuyor; satır süren `submit_review` çağrısında yazılıyor. Kullanıcı "Devam"a iki ağ turu bitmeden basarsa sunucu `42501 'bugün hiç çalışılmamış'` fırlatıyor, istemci yutuyor, **50 XP + 5 elmas sessizce kayboluyor** ve `_lastGoalDate` yazıldığı için o gün bir daha istenmiyordu | `_advance` süren cevabı bekliyor; sunucu vermezse iyimser `+50` **geri alınıyor** (`revertDailyGoal`) ve ödül yeniden istenebilir hâle geliyor |
| **C0-3 · Yabancıya gönderme** | Lig kohortu arkadaşlıktan bağımsız kuruluyor, yani tahtadaki satır çoğunlukla bir yabancı. Açılan profil **koşulsuz** "Arkadaşına gönder" çiziyordu; kullanıcı üç ekran sonra sebebi söylenmeyen bir redde varıyordu | Düğme yalnızca kabul edilmiş arkadaşta çiziliyor; yabancıda sebep yazıyor. Turda doğrulandı |
| **B5 · Lig kuralı** | Cümle sabit `League.cohortSize` (30) yazıyordu. Turda aynı kartta "**30** kişilik grubunda ilk 5 yükselir, son 5 düşer" ve hemen yanında "4. / **10**" duruyordu | Gerçek grup boyutu yazılıyor. Düşme cümlesi yalnızca grup beş kişiden büyükken — sunucu `settle_league` düşmeyi o koşulla uyguluyor |
| **Türkçe ek + `''`** | `sendEntryTitle` / `sendArchiveTitle` ARB'de `{name}''e` yazıyordu. Flutter basit yer tutuculu mesajlarda ICU kaçışı çözmediği için ekranda **"Ayla''e soru gönder"** çıkıyordu — hem fazladan kesme hem yanlış ek | Ek artık `trDative` ile üretiliyor: `Berk'e`, `Ayla'ya`, `Ece'ye`. Turda doğrulandı |
| **Boş arşiv çıkmazı** | "Arşivinden seç" satırı alt satırında "Arşivin boş" yazdığı hâlde **dokunulabiliyordu** ve hiçbir eylemi olmayan boş bir ekrana götürüyordu; oradan soru da eklenemiyordu | Satır arşiv boşken kapalı. Turda doğrulandı |
| **İsteği reddetme yok** | Gelen arkadaş isteğinde yalnızca "Kabul et" ve "Engelle" vardı: **hayır demenin tek yolu engellemekti.** Engelleme lig tahtasında maskeliyor, bütün sosyal yüzeyleri kapatıyor ve kullanıcının engellenenler listesini şişiriyor | **"Reddet"** eklendi. Turda doğrulandı |
| **U3 · Yanlış onay** | `_blockFlow` eylemin sonucuna bakmadan "Engellendi" diyordu; hata durumunda kullanıcı önce "işlem başarısız", hemen ardından "Engellendi" görüyordu — son söz olmamış bir şeyi olmuş gösteriyordu | `_act` sonucunu döndürüyor; onay yalnızca gerçekten olduysa |
| **U4 · Çevrimdışı çift kayıt** | Kuyruğa alınan cevap yolunda `_result` null kalıyor ve `_answering` sıfırlanıyordu: şıklara her dokunuşta **aynı soru için kuyruğa bir kayıt daha** yazılıyordu | `_queued` bayrağı; şıklar kilitleniyor ve sebebi yazıyor |
| **B4 · Paywall "Ücretsiz" sütunu** | `ai_state()` iki sınır sütununu da **çağıranın katmanına** göre dolduruyor. Abone "Ücretsiz 50 \| Plus 50", anonim "Ücretsiz 3 \| Plus 50" görüyordu — ikincisi ömür boyu deneme tavanını ücretsiz katman diye gösteriyordu | Kıyas tablosu yalnızca rakamların gerçekten ücretsiz katmana eşit olduğu durumda (giriş yapmış, abone olmayan) çiziliyor |
| **B6 · Sessiz saatler** | "Bu aralıkta bildirim gönderilmez" koşulsuz söyleniyordu. Sessiz aralık yalnızca cihazda duruyor, sunucuya hiç gitmiyor ve `send_push` saat kontrolü yapmıyor: arkadaş bildirimleri aralığın ortasında da gidiyor | Vaat gerçek kapsamına daraltıldı: hatırlatmalar kayar, arkadaş bildirimleri etkilenmez |
| **U7 · Ters chevron** | Satır sonu chevron'ları `back` ikonunu kullanıyordu, yani **sola** bakıyordu. `kimo_icons.dart` sorunu adıyla yazıp `forward`ı eklemiş ama yalnızca iki yere uygulamıştı | Altı yerde düzeltildi |
| **U8 · Ham hata** | Gönderim hatasında `PostgrestException.message` doğrudan ekrana basılıyordu — SQL hata gövdesi şema sızdırabilir | Günlüğe yazılıyor, ekrana sabit cümle gidiyor |

---

## 3. Hesap silme — uçtan uca

`delete-account` sırası **depolama → auth kullanıcısı → cascade**. Bir tur
hesabı uygulamanın kendi ekranından silindi (takma ad doğrulaması, "Siliniyor…",
karşılama ekranına dönüş) ve sunucu denetlendi:

| Yüzey | Kalan |
|---|---|
| `auth.users` · `profiles` · `mistakes` | 0 · 0 · 0 |
| `friendships` · `league_members` | 0 · 0 |
| `study_attempts` · `question_sends` | 0 · 0 |
| Depolama (`<uid>/`) | 0 |

**Karşı taraf temiz:** arkadaş listesi boşaldı, lig 10 → 9 kişiye indi ve sıra
4. → 3. oldu. Hayalet satır yok.

**Silerken çıkan yapısal not:** `storage.objects`'in `auth.users`'a **FK'si
yok** (yalnızca `bucket_id`). Yani kullanıcıyı silmek fotoğraflarını silmiyor —
edge fonksiyonunun "önce depolama" sırası tam bu yüzden gerekli ve yönetim
API'siyle yapılan her temizlik de aynı sırayı izlemek zorunda. Bu turdaki beş
silme öyle yapıldı; sıfır yetim dosya kaldı.

---

## 4. Düzeltilmeyenler

**Ürün/tasarım kararı bekleyenler**

* **C0-5 · Ortak seri çağrısı zaten başlamış ikiliye de çıkıyor.**
  `start_pair_streak` `false`'u üç farklı anlamda döndürüyor ("ön koşul yok",
  "üst sınır doldu", "zaten var") ve istemci üçünü de çağrıya çeviriyor.
  Sunucunun ayrım yapması gerekiyor.
* **C0-6 · Çağrı metni "gönder, başlasın" diyor**, sunucu ise arkadaşın o soruyu
  **çözmüş** olmasını arıyor. Kullanıcı gönderiyor ve seri başlamıyor.
* **B2 · Profil fotoğrafı iki kaynakta:** kendi ekranı `user_metadata`'dan,
  arkadaş listesi/lig/gelen kutusu `profiles.avatar_path`'ten okuyor. Aynı
  C0b sınıfı; yükleme iki ayrı yere yazıyor.
* **B3 · Günün tanımı ikiye bölünmüş:** `_today` sunucudan (Istanbul) ama
  `registerActivity` cihaz gününü yazıyor.
* **B7 · "Günde en fazla iki kez" vaadi:** lig son-gün hatırlatması üçüncü
  yerel bildirim. Ya metin kapsamını söylemeli ya da lig hatırlatması iki
  yuvadan birini kullanmalı.
* **B8 · Persona kartındaki örnek cümleler** üründe hiç gönderilen cümleler
  değil; "Bugünkü tekrarın 6 dakika" havuzun hiçbir satırında geçmiyor.

**Sunucu değişikliği gerektirenler**

* **B4'ün kalıcı çözümü:** `ai_state()` ücretsiz katman sınırlarını ayrı
  sütunlar olarak yayınlamalı. Bu turda istemci tarafı kapatıldı (yanlış rakam
  gösterilmiyor), ama abone kullanıcı kıyas tablosunu hiç göremiyor.
* **B6'nın kalıcı çözümü:** sessiz aralık sunucuya yazılıp `send_push`'ta
  uygulanmalı. Bu turda yalnızca vaat daraltıldı.
* **C0-4'ün kalanı:** arşiv listesinin "gönderilebilir" ölçütü `moderation`
  ve `photo_scan` durumunu hâlâ okumuyor (`MistakeEntry` bu alanları
  taşımıyor). Tarama yarışı C0-1 düzeltmesiyle kendiliğinden çözülüyor;
  `moderation = 'removed'` durumu hâlâ listede gönderilebilir görünüyor.

**Rapora yazılan, düzeltilmeyen**

* **U6 · Hatalarım** her tazelemede tam ekran çemberle sıfırlanıyor ve kaydırma
  konumu kayboluyor — `refreshBus.ping()` sekme değişiminde de tetikleniyor.
* **Lig kuralının örtüşmesi:** dokuz kişilik bir grupta "ilk 5 yükselir, son 5
  düşer" beşinci sırayı her iki kümeye birden koyuyor. Metin artık gerçek grup
  boyutunu yazıyor ama kuralın kendisi sunucuda böyle; ürün kararı.
* **Gelen kutusunda tam ekran yok:** tekrar ekranında fotoğrafı büyütme yolu
  var, gelen soruda yok — çok soruluk bir sayfada hangi soru olduğunu görmek
  zorlaşıyor.

---

## 5. Doğrulama

**CI, `main` üzerinde — üç iş de yeşil (commit `1537041`):**

| İş | Sonuç |
|---|---|
| pgTAP | **37 dosya, 836 iddia** |
| Mutasyon | **58 ayırt edildi, 0 sorun** |
| Statik kapılar | beş kapı; taksonomi 434 konu |
| analyze + test | **402 test** |

Task 16 düzeltmelerinden sonra yerelde **414 test** yeşil, `flutter analyze`
temiz, `check_symbols`/`check_imports` sıfır sorun.

**Yeni testler (12) ve mutasyonla ayırt edilenler:**

* `trDative` — ünlü/ünsüz sonu, kalın/ince uyum, çift kesme yokluğu
* `MistakeStats.dueToday` — üretimde görülen hâl (vade bugün ama gelmemiş)
  doğrudan sınanıyor; kuralı gün bazlıya geri çeviren mutasyon testi kırdı
* `SendResult` — `not_sendable` ayrı anlatılıyor, `duplicate`a karışmıyor;
  ayrımı kaldıran mutasyon iki testi birden kırdı

**Tur, ekran görüntüleriyle** (erişilebilirlik ağacı + gerçek dokunuşlar, üç
hesap, iki simülatör): arkadaş ekleme/kabul/reddetme, gönderim, gelen kutusu,
ortak seri daveti, lig, profil, ayarlar, hesap silme.

**Üretim durumu:** yedi hesap kaldı (ikisi gerçek, beşi Task 14'ten), sıfır
yetim satır, sıfır yetim dosya. `ff_pair_streak` tur için açılıp **kapatıldı**;
`ff_multi_capture` kapalı.

---

## 6. Devir notları

1. **Servis rolü anahtarı, `sbp_…` erişim jetonu ve veritabanı parolası hâlâ
   döndürülmeyi bekliyor** (Task 14 devir notlarının 1. maddesi). Bu turda
   servis rolü anahtarı yönetim API'sinden okundu ve yalnızca ortam
   değişkeninde tutuldu; hiçbir dosyaya yazılmadı.
2. **`ff_pair_streak` tur boyunca açıktı** (yaklaşık kırk dakika) ve kapatıldığı
   sunucudan doğrulandı. O sırada üretimde yalnızca test hesapları aktifti.
3. **Gönderim beklemesi bir istemci merdiveni.** Tarama on bir saniyede
   bitmezse kullanıcı "kontrol hâlâ sürüyor" mesajını görüyor ve tekrar
   deneyebiliyor. Kalıcı çözüm sunucuda bir "tarama bitince gönder" niyet
   kaydı olurdu; gerekliliği taramanın gerçek süre dağılımına bakılarak
   kararlaştırılmalı (ölçülen iki örnek 2,15 ve 2,4 saniye).
4. **Bir derleme iki kez geçici olarak düştü** ("Encountered error while
   building for simulator", hata satırı üretmeden) ve ikinci denemede sorunsuz
   derledi. Kod tarafında karşılığı bulunamadı.
