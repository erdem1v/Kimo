# Task 15 — Kapsamlı UX denetimi ve düzeltme

Uygulama simülatörde ilk kez uçtan uca kullanıldı ve **ilk soru kaydedilmeden
önce sekiz sorun** çıktı. Teşhis doğruydu: *"her akış ayrı ayrı yazılmış ama
hiçbiri birleşik olarak yaşanmamış."*

Bu tur iki iş yaptı: bildirilen sekizi düzeltti ve aynı sınıftan olan her şeyi
aradı. **Aramanın sonucu bildirilen listeden ağırdı.** Onay ekranının kayıt
yolunda, kimsenin bildirmediği iki ayrı bloke edici vardı ve ikisi birlikte şu
anlama geliyordu:

> **Sınav yılı 2028 ve sonrasını seçen her yeni kullanıcı ilk sorusunu hiç
> kaydedemiyordu.**

Sekiz bildirilen sorunun beşincisi ("Arşive kaydet kilitli kalıyor") bunun
görünen yüzüydü.

---

## 1. Bulgu listesi — kullanıcının gördüğü sırayla

Önem: **BLOKE** ilerlenemiyor · **BOZUK** görünürde bozuk · **küçük** rapora.
"Kanıt" sütunundaki satır numaraları düzeltmeden ÖNCEKİ hâle ait.

### Karşılama ve onboarding

| # | Ekran · ne oluyordu | Ne olmalıydı | Önem | Durum |
|---|---|---|---|---|
| **B1** | Karşılama → 1. adım → çekim ekranı, **üç ekran üst üste aynı şeyi söylüyordu**. 1. adım (`onboarding_flow.dart:381-415`) ile `CaptureScreen`in boş hâli (`capture_screen.dart:567-604`) *aynı ARB anahtarlarını* kullanıyordu: `captureEmptyTitle`, `captureEmptyBody`, aynı 130px Kimo. Düğme etiketi `welcomePrimary` ("İlk yanlışını çek") karşılama ekranında da aynıydı | Karşılama düğmesi doğrudan çekim ekranını açar — Task 02 §7.1'in yazdığı davranış zaten buydu | BOZUK | ✅ adım silindi |
| **B2** | Yaş adımı, kaydettikten sonra **boşalıyordu**: `_yearSet` true olunca çark/not/Kaydet dalının tamamı kayboluyor, geriye başlık + yeşil rozet kalıyordu. Yapılacak hiçbir şey yokken ikinci bir "Devam et" isteniyordu; kaydedilen yıl hiç gösterilmiyordu (`age_gate_step.dart:131-136`) | Kayıt başarılı olunca adım kendiliğinden ilerler | BOZUK | ✅ otomatik ilerliyor |
| **B3** | Çarkın `FixedExtentScrollController`'ı `build()` içinde yaratılıyordu (her karede yeni, hiç `dispose` edilmiyordu) ve `_year ??=` build sırasında durum değiştiriyordu | Denetleyici `initState`'te kurulur, `dispose`'ta kapanır | BOZUK | ✅ |
| **B4** | Persona adımı **hiçbir şey sormuyordu**: `_canContinue` sabit `true`, seçim `initState`'te önceden yapılmış. Gövde metni ("Hatırlatmaların hep Kimo'dan gelir") zaten bir sonraki adımın konusunu anlatıyordu | Bildirim adımıyla tek ekran | BOZUK | ✅ birleşti |
| **B5** | Bildirim adımı **her kullanıcıya en az iki dokunuşa** mal oluyordu (`_notify` `null` başlıyor, footer kilitli). Seçim düğme *türüyle* taşınıyordu: "Evet" seçili değilken ikincil, "hayır" seçiliyken ikincil — aynı ağırlık | Varsayılan açık gelir, tek anahtarla taşınır | BOZUK | ✅ anahtar, varsayılan açık |
| **B6** | İlk adımda geri oku `onPressed: null` ile **kalıcı ölü bir kontrol** olarak duruyordu | Çizilmez | küçük | ✅ |
| **B7** | Profil adımında "Devam et" iki koşulla kapalıydı (takma ad ≥2 harf, sınav yılı) ama ekranda bunu söyleyen **hiçbir metin yoktu** | Engel yazılır | BOZUK | ✅ |
| **B8** | **Sınav yılı çipleri tam genişlik olup alt alta diziliyordu**: beş yıl beş satır, altında yarım ekran boşluk. `KimoChip`in `AnimatedContainer`'ı `alignment` taşıyordu ve `Container` hizalama verilince gelen *sınırlı* kısıtın tamamına yayılıyor. `Wrap` sınırlı genişlik verdiği için **depodaki bütün çip satırları aslında dikey listelerdi** (14 kullanım yeri) | İçerik kadar yer kaplar, satıra dizilir | BOZUK | ✅ |

### Çekim → onay → kayıt

| # | Ekran · ne oluyordu | Ne olmalıydı | Önem | Durum |
|---|---|---|---|---|
| **C0** | **İlk fotoğraf yanlış müfredat ağacına soruluyordu.** Fotoğraf yaş adımında (1. adım) analiz ediliyor, müfredat ise sınav yılından türüyor ve profil adımında (2. adım) belirleniyor. Analiz anında `userProfile.curriculum` varsayılana (`eski`) düşüyor; 2028+ seçen kullanıcı (`maarif`) geri dönen konuyu kendi ağacında bulamıyor, konu **sessizce düşüyor** ve "Arşive kaydet" hiç açılmıyordu. Canlı kanıt: kuyruk `Birinci Dereceden Denklemler ve Eşitsizlikler` (eski/TYT/Matematik, 17 konu) yazıyor, kullanıcının ağacında (maarif, 12 konu) yok | Analiz kullanıcının gerçek müfredatına sorar | **BLOKE** | ✅ müfredat bilinene kadar analiz erteleniyor |
| **C0b** | **Sunucu, istemcinin yazdığı müfredatı görmüyordu.** `my_curriculum()` müfredatı `auth.jwt() -> user_metadata ->> 'curriculum'` ile okuyor ve `mistakes.curriculum` varsayılanı ondan geliyor. `auth.updateUser` kullanıcı kaydını güncelliyor ama **erişim jetonunu yeniden üretmiyor**: canlı kanıt olarak jetonun `user_metadata`'sı `{}` iken saklanan kullanıcı nesnesi `{"curriculum":"maarif",…}` gösteriyordu. Sonuç: her maarif konusu `KM022 Konu müfredat ağacında yok` ile reddediliyordu | Metadata yazıldıktan sonra jeton tazelenir | **BLOKE** | ✅ `refreshSession()` |
| **C1** | Onay ekranının **X düğmesi hiçbir şey yapmıyordu**. Ekran `pop(false)` dönüyor, çekim ve parti akışları onu `MaterialPageRoute<String>` olarak itiyordu; `Route<T>.didPop` eşdeğişken tip denetiminde patlıyor ve hata jest işleyicisinde yutuluyordu. Yan etkisi: `capture_screen.dart:419-423`'teki "vazgeçti, fotoğrafı koru" dalı hiç koşmuyordu | X ekranı kapatır | **BLOKE** | ✅ |
| **C2** | Yapay zekâ şıkları saymışken **"Kaç şık vardı?" yine soruluyordu** — cevabı önceden işaretli bir soru. Üstelik çipe dokunmak AI'ın etiketlerini `A–E` ile değiştirip doğru şık işaretini sessizce düşürüyordu (`confirm_screen.dart:183-186`) | Yalnızca sayı gerçekten bilinmiyorsa sorulur | BOZUK | ✅ iki yolda da |
| **C3** | Kayıt sürerken yardım metni **"Doğru şıkkı işaretle"** diyordu — kullanıcı az önce işaretlemişken. Merdivende `_saving` dalı yoktu ve kayıt boyunca görünen tek geri bildirim buydu. `KimoButton`'ın meşgul hâli de yoktu | "Kaydediliyor…" der, düğme çalıştığını gösterir | **BLOKE** | ✅ |
| **C4** | `_saving` **hiç sıfırlanmıyordu**: `_save` ve `_waitForAnalysis` `finally` taşımıyordu, sıfırlama üç ayrı dalın içindeydi. `catch` gövdesinden kaçan bir hata `_saving`i sonsuza dek `true` bırakıyor, **ekrandaki her kontrol** (kaydet, vazgeç, analizi bekle) aynı anda ölüyordu | Her çıkışta sıfırlanır | **BLOKE** | ✅ |
| **C5** | **Çevrimdışı tuzağı.** Ekran `String` dönüyordu ama iki rota `push<bool>` idi (`pending_photos_screen.dart:83`, `today_screen.dart:455`). Sonucu: (a) "Sıraya alındı" bildirimi görünüyor, `pop` patlıyor, C4 ile birleşip ekran donuyordu; (b) **çevrimiçi kayıt da** aynı yerden patlıyor, `catch (e)` bunu ağ hatası sanıyor ve satır kaydedilmişken kullanıcıya "Kaydedilemedi. Tekrar dene." deniyordu → tekrar dokunmak **mükerrer satır** üretiyordu | Tek tip sözleşme; pop hatası ağ hatası sanılmaz | **BLOKE** | ✅ dört rota `String?` |
| **C6** | **Konu satırı derse kilitliydi** (`enabled: _subject != null`). Oysa hemen üstündeki yorum "Ders ARTIK ZORUNLU DEĞİL: seçici tüm derslerde arıyor" diyor ve `showTopicPicker`'ın `subject`i zaten opsiyonel. Dersler arası arama vardı, kapısı kapalıydı | Konu doğrudan seçilir, ders ondan türer | BOZUK | ✅ |
| **C7** | Kuyruktan tamamlanan kayıtta **her şey dolu gelirken** ekran "Sınavı, dersi ve konuyu seç" diyordu (`analysis` o yolda `null`) | Dolu geldiğini söyler | küçük | ✅ |
| **C8** | Kayıt sonrası **"Bu soru yarın karşına çıkacak"** deniyordu. Sunucu tetikleyicisi (`mistakes_review_timing`, 0033) yeni kayda `now() + interval '3 hours'` yazıyor: ilk tekrar **aynı gün** | Tuttuğu sözü söyler | küçük | ✅ "birkaç saat sonra" |
| **C9** | Kapalı düğmenin yardım metni tek cümleydi ("Önce ders ve konu seç"); ders satırında koca bir "Matematik" dururken o cümle okunmuyordu | Eksik olan ne ise o yazar | BOZUK | ✅ ders/konu ayrıldı |

### Uygulama içi

| # | Ekran · ne oluyordu | Ne olmalıydı | Önem | Durum |
|---|---|---|---|---|
| **D1** | Gelen kutusunda `inboxSolve` "Çöz" **her kart için birincil**: beş gelen soruda beş mercan düğme. `KimoButton`ın kendi kuralı "ekranda en fazla bir tane" | Kart eylemi ikincil | BOZUK | ✅ |
| **D2** | Arkadaşlar'da "Ekle" + her bekleyen istek için "Kabul et" birincil → üç istekte **dört birincil**. Ayrıca "Ekle" **boş kodda etkin görünüyor**, dokunuş `_addByCode`ın ilk satırında sessizce dönüyordu | Tek birincil; boş kodda kapalı | BOZUK | ✅ |
| **D3** | "Bildir" ve "Gönder" yapraklarında **kapatma hedefi yoktu** — üstelik yükleme/hata/"arkadaşın yok" hâllerinde ekranda dokunulabilir hiçbir kontrol kalmıyordu. `send_flow.dart:35-39`'un kendi yorumu Apple HIG ve WCAG 2.5.1/2.5.7'ye atıfla bunu zorunlu kılıyor | Her yaprakta kapatma | BOZUK | ✅ |
| **D4** | Oturum sonu ekranında **AppBar da kapatma da yoktu**; çıkış yalnızca uzun bir özetin altındaki düğmelerdeydi | Kapatma | BOZUK | ✅ |
| **D5** | Kapalı düğmenin yanlış koşulu anlatan üç yer: arşivden gönderme ("Gönder" kapalıyken metin not gizliliğini anlatıyordu) · paywall (üç koşuldan biri anlatılıyor, satın alma sürerken hiçbir gösterge yok) · ayarlardaki bildirim yaprağı (**işletim sistemi izni** reddedilince açılıyor ama gövdesi uygulama içi anahtarı tarif ediyordu) | Metin gerçek engeli anlatır | BOZUK | ✅ |
| **D6** | Ortak seri risk kartı durumu bildiriyor ama hiçbir kontrol taşımıyor; hemen altındaki kırık kartında düğme var | — | küçük | ⏸ tasarım |
| **D7** | Kozmetik tekrarlar: `plusCta` "7 gün ücretsiz dene" hak duvarında ve paywall'da aynı etiket · tema kartı Profil ve Ayarlar'da birebir aynı · `settingsBirthYear` satırı tıklanamaz ama chevron'suz · "Engelle" üç ekranda üst üste · "Veri ve gizlilik" → "Veri ve Gizlilik" · sessiz saatlerin iki düğmesi hangisinin başlangıç olduğunu söylemiyor | — | küçük | ⏸ kapsam dışı (karar) |

---

## 2. Onboarding — öncesi ve sonrası

```
ÖNCE (6 adım, ~13 dokunuş)          SONRA (4 adım, 8 dokunuş)
 Karşıla  "İlk yanlışını çek"        Karşıla  "İlk yanlışını çek"
 1 Çekim  ── aynı maskot, aynı           └──► ÇEKİM EKRANI doğrudan
           başlık, aynı düğme
 2 Yaş    çark + Kaydet               1 Doğum yılı   çark + Kaydet → OTOMATİK ilerler
          → boş yeşil rozet
          → ikinci "Devam et"
 3 Profil takma ad + sınav yılı       2 Seni tanıyalım  takma ad · sınav yılı
 4 Persona önceden seçili,            3 Hatırlatıcı & ses
           hiç engellemiyor              anahtar (açık) + Kimo'nun sesi + önizleme
 5 Bildirim ikili, varsayılan null
           → hep 2 dokunuş
 6 Kayıt  e-posta + parola + onay     4 Hesabını aç   e-posta · parola · onay
```

* **Kameraya 3 dokunuş → 2.**
* **Adım 6 → 4**, giriş yapmış kullanıcıda 4 → 3.
* Hukuki yüzeyin üçü de **aynen duruyor**: 13 yaş kapısı, kullanım koşulu onayı,
  OpenAI aktarım bildirimi (ömürde bir kez, `capture_screen.dart:166`).
* İlk analiz artık **profil adımından sonra** çalışıyor (bkz. C0). Bu bir
  gecikme değil düzeltme: önceki sıra analizi yanlış müfredata soruyordu.

---

## 3. Bildirim ve ses

**Ölçüm.** `sound.tap()` **85 çağrı yerinde** (her çip, her satır, her düğme),
50 ms'lik sentetik bir bip; `correct` 7, `wrong` 2, `levelUp` 2 yerde.
`soundEnabled` varsayılan **açık**. `HapticFeedback` yalnızca iki yerdeydi.

**İki bulgu.**

1. **Bildirimler zaten doğruydu.** `notification_service.dart:37-48` sistem
   varsayılan sesini kullanıyor. Sektör normu da bu; kendi bildirim sesini
   üreten uygulama azınlıkta ve genellikle sevilmiyor. **Değişiklik yok.**
2. **Rahatsız eden dokunuş bip'iydi.** Her dokunuşta ses çalmak yaygın bir
   kalıp değil — mobil normu dokunuşta titreşim, sesi yalnızca sonuç anlarına
   saklamak. Üstelik `audioplayers` varsayılanı `respectSilence: false`, yani
   iOS'ta kategori `playback` oluyordu: **ses telefon sessizdeyken bile
   çıkıyordu.** Sınıfta ya da kütüphanede çalışan bir öğrenci için bu tek
   başına yeterli bir kusur.

**Yapılan.** `SoundService.tap()` gövdesi `HapticFeedback.selectionClick()`
oldu — **85 çağrı yeri aynen kaldı**, tek dosya değişti, geri almak tek satır.
`correct/wrong/levelUp` sesleri duruyor ve ses oturumu `respectSilence: true`
ile kuruluyor: iOS'ta kategori `ambient`, yani sessiz düğmesi susturuyor ve
arka planda çalan müzik kesilmiyor. `assets/sounds/tap.wav` yerinde bırakıldı.

---

## 4. Kök nedenler — bildirilen listede olmayan iki blokaj

Turun en önemli sonucu bu. İkisi de **kimsenin bildirmediği** ama ilk kaydı
imkânsız kılan hatalardı ve ancak gerçek bir turda görülebilirlerdi.

**C0 — sıra hatası.** Fotoğraf yaş adımında analiz ediliyordu; müfredat bir
adım sonra belirleniyor. Analiz, kullanıcının ağacını bilmeden konu seçiyordu.
Düzeltme: `PhotoQueue.flush` müfredat belirsizken analizi **erteliyor**, profil
adımı müfredatı yazınca yeni bir flush tetikliyor. Kayıt düşmüyor, sırada
bekliyor.

**C0b — jeton hatası.** `auth.updateUser` metadata'yı yazıyor ama erişim
jetonunu yeniden üretmiyor. Sunucu müfredatı jetondan okuduğu için istemci
"maarif" derken sunucu "eski" varsayıyor ve her maarif konusunu `KM022` ile
reddediyordu. Düzeltme: müfredat yazıldıktan sonra `refreshSession()`. Hata
yutuluyor — metadata zaten yazıldı, jeton en geç kendi yenilenmesinde doğru
claim'i taşır.

İkisi birlikte şu anlama geliyordu: **sınav yılı 2028+ seçen her yeni kullanıcı
ilk sorusunu hiç kaydedemiyordu.** Bildirilen "Arşive kaydet kilitli kalıyor"
maddesi bunun görünen yüzüydü; yardım metni düzeltmesi (C3, C9) semptomu
okunur kıldı, asıl kapanış C0 ve C0b'de.

---

## 5. Doğrulama

**Simülatör turu** (iPhone 16 Pro, erişilebilirlik ağacı + gerçek dokunuşlar,
temiz kurulumdan üç kez):

| Doğrulanan | Kanıt |
|---|---|
| Karşılamadan tek dokunuşla çekim ekranı | araya giren kopya adım yok (B1) |
| "Adım 1 / 4" | akış altıdan dörde indi |
| Çark çizili, orta yıl seçili, "Kaydet" hemen etkin | B3/K4 |
| "Kaydet" → **kendiliğinden** 2. adım | B2 |
| İlk adımda geri oku yok | B6 |
| Kapalı düğmenin altında "Doğum yılını seçip Kaydet'e dokun" | B7 |
| Sınav yılı çipleri **tek satırda** (x=51…337, hepsi y=297) | B8 |
| Birleşik 3. adım: anahtar açık + persona + canlı kilit ekranı önizlemesi | B4/B5 |
| Profil adımından sonra JWT `{"curriculum":"maarif",…}` | C0b |
| Kuyruktaki konu `Denklem-Eşitsizlik` — maarif ağacında **geçerli** | C0 |
| Onay ekranı: Konu **dolu**, "Kaç şık vardı?" **yok** | C0/C2 |
| Kayıt geçti, ekran kapandı, kuyruk boşaldı | C1/C4/C5 |
| Sunucuda satır `curriculum: maarif` | C0b uçtan uca |
| Tekrar → "Yakaladın!" → oturum sonu → **"Kapat"** | D4 |
| Arkadaşlar'da boş kodda "Ekle" **kapalı** | D2 |
| **Çevrimdışı:** konu seçici ders olmadan açılıyor, kayıt sıraya giriyor, ekran **kapanıyor** | C5/C6 |
| Arka plana atıp dönünce kuyruk boşalıyor, **mükerrer satır yok** (sunucuda 2 satır, 2 farklı konu) | C5 |

**Otomatik:** `flutter analyze` temiz · **402 test yeşil** (9 yeni) · beş statik
kapı yeşil (`check_workflows`, `check_symbols`, `check_imports`, `check_sql`,
`build_taxonomy`).

**Yeni testler ve mutasyonla ayırt edildiler:**

* `test/features/capture/confirm_screen_test.dart` — şık sayısı kapısı (iki
  yönde), vazgeç düğmesinin rotayı gerçekten kapatması, konu satırının derse
  bağlı olmaması. `pop()` → `pop(false)` ve kapının devre dışı bırakılması
  mutasyonlarının ikisi de testi kırdı.
* `test/features/onboarding/age_gate_step_test.dart` — açılışta seçili yıl,
  yeniden çizimde bozulmayan seçim, kayıtlı yılın gösterilmesi.
* `test/widgets/kimo_chip_test.dart` — çipin içerik kadar yer kaplaması.
  `alignment`ı geri koyan mutasyon testi kırdı.
* `test/data/photo_queue_test.dart` — müfredat belirsizken analizin
  çağrılmaması. **İlk yazımı ayırt etmiyordu**: `flush` analiz hatalarını
  bilerek yutuyor, bu yüzden istisna atan bir sahte kapı kalksa da aynı durumu
  bırakıyordu; test çağrı sayan hâle çevrildi ve mutasyonu yakaladı.

**pgTAP ve mutasyon takımı koşulmadı** — Docker bu makinede yok, ikisi de
yalnızca CI'da çalışıyor. Bu turda SQL değişmedi.

---

## 6. Ne düzeltilmedi, neden

* **D6 — ortak seri risk kartı.** Karta eylem eklemek mi, kartı kaldırmak mı
  olduğu ürün kararı.
* **D7 — kozmetik tekrarlar.** Kapsam "bloke eder + görünürde bozuk" olarak
  belirlendi; liste yukarıda duruyor.
* **Onboarding'den çıkış yolu.** `lib/features/onboarding/` içinde ne atla ne
  "daha sonra" var; `OnboardingFlow` `AuthGate`'in kök widget'ı ve `PopScope`
  taşımıyor, yani Android geri tuşu uygulamadan çıkıyor. "Daha sonra" yolu
  eklemek ürün kararı: kurulumu atlayan anonim kullanıcı nereye düşecek? Bu
  turda yalnızca ölü geri oku kaldırıldı.
* **Dört personanın taban ayısı** birebir aynı (`kimo_painter.dart:73-75`) —
  Task 14'ten devreden tasarım kararı.

---

## 7. Devir notları

1. **Üç test hesabı üretimde kaldı**: `task15tur@kimo.test`,
   `task15b@kimo.test`, `task15c@kimo.test` (parola hepsinde aynı test
   parolası). Sonuncusunda iki kayıtlı soru var. Silinmeleri gerekiyor.
2. **Turda bir satırın vadesi elle öne çekildi** (yönetim API'si ile
   `next_review_at = now() - 1 minute`), yalnızca tekrar akışını görebilmek
   için. Şema ya da yapılandırma değişmedi.
3. **Müfredat belirsizken analiz erteleniyor.** Onboarding müfredatı her zaman
   yazdığı için bu kapı pratikte yalnızca karşılama akışının içinde etkili.
   Müfredatı hiç yazılmamış bir hesap oluşabilirse (bugün oluşamıyor) kuyruğu
   süresiz bekletirdi; kapının orada bir kurtarma yolu yok.
4. **Eski kurulumlar.** Bu düzeltmeden önce onboarding'i bitirmiş bir
   kullanıcının jetonu, kendi yenilenmesine kadar (en fazla bir saat) eski
   claim'i taşımaya devam eder; bir sonraki açılışta sorun kendiliğinden geçer.
5. **Servis rolü anahtarı, `sbp_…` erişim jetonu ve veritabanı parolası hâlâ
   döndürülmeyi bekliyor** (Task 14 devir notlarının 1. maddesi).
