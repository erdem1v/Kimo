# Task 18 — Yayın öncesi bütünsel denetim ve yayın adayı

Task 17 açık maddeleri kapatıp son turu attı; ama her tur **değişen
yüzeyleri** gezdi. Uygulamanın 23 tam ekranı ve 18 sayfası/diyaloğu hiçbir
zaman tek bir listede, tek tek doğrulanmamıştı ve 21 tam ekran + 18 sayfa hiç
widget testi taşımıyordu. Yayın yapılandırması da parça parça düzeltilmiş,
bütün olarak denetlenmemişti.

Bu task o denetimi yaptı, bulguları kapattı ve yayın adayını `main`e itti.

> **En ağır iki bulgu turdan değil, yapılandırma denetiminden ve üretim
> doğrulamasından çıktı:** (1) satın alma yolunun üç edge fonksiyonu
> (`verify-purchase`, `store-notify`, `reconcile-subscriptions`) üretime **hiç
> dağıtılmamıştı** ve IAP sırları hiç tanımlı değildi — ödeyen kullanıcı
> premium olamazdı; (2) `cleanup-anonymous` fonksiyonu **herkese açık anon
> anahtarıyla** çağrılabiliyordu ve gövdedeki `days` ile 1 güne kadar inen
> anonim hesap temizliğini herkes tetikleyebiliyordu.

---

## 0. Taban çizgisi (Task 18 başı, commit `d55b594`)

| Katman | Sayı | Nerede koştu |
|---|---|---|
| `flutter analyze` | temiz | yerel |
| `flutter test` | **449** yeşil → faz 3 sonunda **492** → tur düzeltmeleriyle **501** | yerel |
| Python kapıları (5) | selftest + gerçek, hepsi yeşil | yerel |
| pgTAP | 852 iddia / 38 dosya | yalnız CI (Docker yok) |
| Mutasyon | 61 | yalnız CI |
| Deno | 16 (2 dosya) | yalnız CI (deno yok) |
| CI (`d55b594`) | dört iş yeşil | GitHub |

**Üretim anlık görüntüsü (salt-okunur):** 24 `app_config` anahtarı;
`ff_ad_reward=true`, `ff_iap=true`, `ff_multi_capture=false`,
`ff_pair_streak=true`, `legal_version=1.3`; `iap_secret` ve
`ai_refund_secret` **yok**; 11 cron işi; edge sırları: `AD_REWARD_SECRET`,
`OPENAI_API_KEY` + platformun kendi altısı — `IAP_SECRET`, `AI_REFUND_SECRET`,
mağaza kimlikleri **yok**; dağıtılmış fonksiyon **7** (depoda 10); `auth.users`
9 hesap, 7'si test hesabı; `schema_migrations` 104 satır (depoda 110 göç —
Task 17'nin beşi API ile basıldı, kayda girmedi; 0103 basılmamış).

---

## 1. Denetim matrisi

Altı mercek: **S** sıra (girdisi kesinleşmeden eylem alan yol) · **K** kaynak
(sunucu kuralının istemci kopyası) · **U** UX (çıkmaz sokak, sebepsiz kilit,
sunucunun yapmadığını vaat eden metin) · **D** dört durum (yükleniyor / boş /
hata / çevrimdışı) · **A** erişilebilirlik · **Y** yayın kalıntısı. Kanıt:
`T:` test dosyası · `S:` ekran görüntüsü (`scratchpad/shots18/`, `A_` = Ada /
iPhone 16 Pro, `B_` = Bora / iPhone 16) · `K:` yalnız kod incelemesi, sebebiyle.
"—" = mercek bu yüzeyde bir şey bulmadı; bulunmama sebebi hücrede.

### 1.1 Tam ekranlar

| # | Yüzey | S | K | U | D | A | Y | Kanıt |
|---|---|---|---|---|---|---|---|---|
| 1 | Welcome | — tek eylem, ağ yok | — | — | — (statik) | düğmeler etiketli | — | S:B_01 |
| 2 | Onboarding 1–4 (çekim · yaş · profil · hatırlatma · kayıt) | yaş adımı `set_birth_year` dönmeden ilerlemiyor (auto-advance görüldü); kayıt düğmesi onay kutusuz kapalı | müfredat sınav yılından **sunucuda** türüyor (Task 15), istemci kopyası yok | geri tuşu adım geri (PopScope), kökte akışa dokunmuyor; koşul metninin dört parçası dört ayrı "Link" düğümü — VoiceOver dört kez "bağlantı" okuyor, **karar:** parça düzeyi dokunma hedefi (K1) bunu gerektiriyor | kayıt hatası snack (B_10 "e-posta denemesi") | onay kutusu + metin ayrı hedef | — | T:onboarding_flow_test (4) · S:B_02…B_14 |
| 3 | Login | başarısız giriş → sebep + düğme serbest (`finally`) | — | — | hata dalı testte | — | — | T:login_screen_test (3) · **K:** form turda gezilmedi — Türkçe klavye `@` yazamıyor; e2e `auth_claims` sunucu tarafını kapatıyor; Bora ile gerçek giriş §6.4 |
| 4 | Bugün (Today) | gelen soru kartı `unsolvedReceivedCount` sunucudan; bekleyen fotoğraf şeridi kuyruk dosyasından | hedef 4/4, hak sayısı, seri: hepsi `my_daily_state` | boş gün / dolu gün / gelen soru / bekleyen şerit dört hâli görüldü | boş (A_01), dolu (B_20), gelen soru (B_31) | seri düğmesi etiketli | — | S:A_01 B_19 B_20 B_31 |
| 5 | Hatalarım | silme onayı diyalogla; gönder sayfası arkadaş listesini bekliyor | filtreler yerel, veri sunucudan | silme geri alınamaz uyarısı var | boş durum (B_21 önce), dolu (A_08) | — | — | S:A_08 A_09 A_10 B_21 |
| 6 | Çekim (Capture) | hak yoksa ekran daha kamerayı açmadan duvara yönlendiriyor (A_31→A_32) | hak sayısı sunucudan (`aiState`) | **U5** çoklu anahtarı premium+bayrakta ekranı boş bırakıyordu — düzeltildi | hak yok / normal / çoklu anahtar | anahtar kilit ikonu `Semantics` | — | T:capture_screen_test (3) · S:A_31 A_35 A_39 |
| 7 | Onay (ConfirmMistake) | "Arşive kaydet" konu + şık gelmeden kapalı (B_16→B_18) | konu ağacı sunucudan (`my_curriculum`) | — | — | şık düğmeleri etiketli | — | E:confirm_screen_test · S:B_16 B_18 |
| 8 | Bekleyen fotoğraflar | — liste diskten | — | — | boş / dolu | — | — | T:pending_photos_screen_test (3) · S:B_15 |
| 9 | Çoklu çekim | "Analiz et" 0 karede kapalı; hak maliyeti yazılı ("2 hak kullanacak") | hak sayısı sunucudan | 10 kare üst sınırı metinde | — | — | — | S:A_41 A_43 |
| 10 | Çoklu sonuç | satırlar `flush` ilerledikçe akıyor; "Hepsini onayla" hazır satır yokken kapalı | — | **U6** yalnız şıkkı eksik satır "okunamadı" sayılıyordu — düzeltildi ("şık bekliyor") | kota ortada biterse kart var (kod; turda tetiklenmedi) | — | — | T:batch_result_screen_test (2) · S:A_44…A_49 |
| 11 | Tekrar (Practice) | cevap sunucuya yazılmadan sonraki soruya geçilmiyor | aralık merdiveni **sunucuda**; istemci yalnız "N gün sonra" yazıyor | **U1** çelişkili söz düzeltildi | son soru etiketi (A_06) | tam ekran düğmesi etiketli | — | T:answer_reveal_test (5) · S:A_03 A_04 A_05 A_06 |
| 12 | Oturum sonu | "bir tur daha" yalnız izin + kalan soru varsa | — | kapatma hedefi var | — | — | — | T:session_end_screen_test (4) · S:A_07 |
| 13 | Gelen kutusu | çöz → sonuç sunucudan (`solve`), sonra "Bunu çözdün" | — | bildir → içerik saklanıyor (B_32 metni sunucuyla uyumlu: `moderation=hidden` doğrulandı) | boş / dolu / çözülmüş | tam ekran görsel düğmesi etiketli | — | T:report_sheet_test (3) · S:B_32 B_34 B_35 B_30 |
| 14 | Gönderim arşivi | arşivden seçim tek dokunuş (B_37→B_38) | — | — | — | — | — | S:B_36 B_37 B_38 B_39 |
| 15 | Lig tahtası | — salt okunur | eşikler sunucudan (Task 17) | — | — | — | — | S:A_13 B_22 |
| 16 | Arkadaşlar | ekle düğmesi boş kodda kapalı; işlem süren satır kilitli (`_busy`) | — | **U7** "Kabul et" iki satıra kırılıyordu — düzeltildi (iki sıra) | hata dalı "Tekrar dene" (kod) | — | — | T:friend_request_tile_test (4) · S:A_14 A_16 A_27 A_29 B_23 B_29 B_30_kod_yenile B_40 |
| 17 | Herkese açık profil | gönder düğmesi yalnız kabul edilmiş arkadaşta (kod) | — | — | — | — | — | S:A_15 · **ertelenen** widget testi (üç depo çağrısı) |
| 18 | Profil | — | XP/seri/lig sunucudan | — | — | avatar düğmesi etiketli | — | S:A_17 B_24 |
| 19 | Ayarlar | çıkış: jeton silme → `signOut` sırası (kod yorumu) | — | yönetim bölümü yalnız `is_admin` | — | — | — | S:A_19 A_50 B_26 |
| 20 | Engellenenler | — | — | — | boş / dolu | — | — | S:A_23 |
| 21 | Hesabı sil | takma ad eşleşene kadar kapalı; hata → ekran açık | — | — | — | — | — | T:delete_account_screen_test (4) · S:A_28 · uçtan uca §6.4 |
| 22 | Gizlilik | — | — | adres yoksa satır yok | — | — | — | T:privacy_screen_test (1) · S:A_25 |
| 23 | Lisanslar | — | — | — | — | — | — | S:A_26 |
| 24 | Kimo Plus | ürün sorgusu StoreKit'ten (simülatörde `storekit_no_response`, ekran "henüz açılmadı" diyor) | fiyat/limit sunucudan | abone/abone değil iki hâl | — | — | — | E:plus_screen_test · S:A_24 A_24a–c A_33 A_34 |
| 25 | Hak duvarı | — | pencere/aylık tavan sunucudan | ödüllü reklam düğmesi (simülatörde "Publisher data not found" → yükleme hatası sessiz değil, `debugPrint`) | — | — | — | E:credit_wall_test · S:A_32 |
| 26 | Askı (Suspended) | — | süre/sebep sunucudan (`my_sanction`) | itiraz düğmesi yalnız `SUPPORT_EMAIL` varsa | — | — | — | T:suspended_screen_test (6) · S:A_61 |
| 27 | Moderasyon | karar düğmeleri işlem sürerken kilitli | — | kendi hesabına yaptırım sunucuda **reddediliyor** (`geçersiz hedef`), istemci genel "İşlem tamamlanamadı" diyor — **karar:** yönetici yüzeyi, sunucu kuralı yeterli | boş / bekleyen şikâyet / şüpheli fotoğraf üç hâli | — | — | S:A_51 A_55 A_56 A_57 A_58 A_59 A_60 |
| 28 | Tüm sorular + editör | silme diyalogla; kaydet meşgulken kilitli | — | — | filtre sekmeleri (Tümü/Hatalı/Gizli) | — | — | S:A_52 A_53 A_53e A_54 |
| 29 | ConfigErrorApp | — | — | — | — | — | — | **K:** yalnız `supabase.json` eksik derlemede çıkıyor; `check_dart_defines` kapısı CI'da (Task 17) |

### 1.2 Sayfalar ve diyaloglar

| # | Yüzey | S / K / U / D / A / Y | Kanıt |
|---|---|---|---|
| 30 | AI aktarım onayı (ömürde bir kez) | onay verilmeden analiz çağrılmıyor (`aiConsent` iki kapı: ekran + kuyruk) | S:B_05 |
| 31 | Bildirim izni adımı | reddedilirse akış duruyor değil, devam ediyor | S:B_08 |
| 32 | Konu seçici | ders seçmeden arama iki dersten sonuç (C6) | T:topic_picker_sheet_test (3) · S:B_17 |
| 33 | Silme onayı (Hatalarım) | geri alınamaz uyarısı | S:A_09 |
| 34 | Soru gönder sayfası | arkadaş listesi hata dalında Kapat çizili | T:send_question_sheet_test (1) · S:A_10 A_11 A_12 |
| 35 | Gönder giriş sayfası | — | E:send_entry_sheet_test · S:B_36 |
| 36 | Bildir sayfası | sebepsiz Gönder kapalı | T:report_sheet_test · S:B_31 B_31b |
| 37 | Saat seçici | — | S:A_20 |
| 38 | Maskot sayfası | — | S:A_21 |
| 39 | Sınav yılı sayfası | — | S:A_22 |
| 40 | Avatar sayfası | kamera DOĞRULANAMADI (simülatör) | S:A_18 A_63 B_25 |
| 41 | Arkadaş menüsü + engelleme onayı | — | S:A_16 |
| 42 | Ortak seri davet + kutlama | bayrak kapalıysa çağrı yok | S:A_37 A_38 B_40 |
| 43 | Fotoğraf uyarısı sayfası | "Anladım" → `ack_photo_warnings` (sunucuda `acknowledged_at` doğrulandı) | S:A_62 |
| 44 | Yaptırım sayfası (yönetici) | sicil özeti sunucudan | S:A_58 |
| 45 | Soru silme diyaloğu (yönetici) | Vazgeç yolu | S:A_54 |
| 46 | Tam ekran görsel (photo_viewer) | — | S:A_04 |
| 47 | Push afişi → yönlendirme | afiş görüldü; **yönlendirme DOĞRULANAMADI** (simülatörde APNS jetonu yok), tablo birim testte | T:notification_router_test (6) · S:B_27 B_28 |
| 48 | Hak göstergesi | — | E:credit_indicator_test · S:A_02 |

Plan 41 yüzey saymıştı; sayım 48 çıktı (yönetici sayfaları ve fotoğraf
uyarısı ayrı satır oldu). **Boş hücre yok; DOĞRULANAMADI olanlar §7'de.**

---

## 2. Bulgular

### 2.1 Yayını engelleyen — kapatıldı

| # | Bulgu | Ne yapıldı |
|---|---|---|
| Y1 | Android imza anahtarı yok; yayın yapısı debug imzalı | PKCS12 keystore `~/.kimo-release/kimo-release.jks` (JDK yok → `openssl`; AGP'de `storeType = "PKCS12"`), `android/key.properties` (gitignore), CI sırları `ANDROID_KEYSTORE_BASE64` + `ANDROID_KEY_PROPERTIES`. **Yedekleme:** iki dosya da sizde; keystore kaybı = uygulamayı bir daha güncelleyememek. SHA-256 parmak izi: `09:8A:B5:6F:DB:65:83:ED:5F:6B:64:9A:2D:B2:88:6C:7B:D1:47:52:AB:BB:49:89:AD:BE:03:03:C5:83:02:B0` (Play Console → uygulama imzalama → yükleme anahtarı) |
| Y2 | `app-ads.txt` yer tutucu yayıncı kimliği | `pub-3524308481275678` (yayın AdMob app id'sinden), başlık güncel; CI kapısı xcconfig ile eşitlik zorluyor |
| Y3 | IAP sırları üretimde yok; **üç IAP fonksiyonu hiç dağıtılmamış** | `iap_secret` + `ai_refund_secret` üretildi, `app_config` + edge sırlarına yazıldı; 10 fonksiyon dağıtıldı; **`ff_iap = 'false'`** (mağaza kimlikleri gelene kadar) |
| Y4 | 0103 üretimde değil | Basıldı; `apply_subscription` gövdesinde `unique_violation` dalı doğrulandı, anon çağırabiliyor, authenticated çağıramıyor |
| Y6 | SKAdNetwork tek girdi | Google'ın listesi, 50 kimlik (2026-09-18); CI kapısı ≥30 + `cstr6suwn9` |
| **Y8** | **`cleanup-anonymous` herkese açıktı.** `verify_jwt = true` anon anahtarını da geçiriyor; fonksiyonda rol kontrolü yoktu. Anon anahtarla `{"days":1}` göndermek 1 günden eski anonim hesapları (kurulumu bitirmemiş kullanıcılar) ve fotoğraflarını siliyordu | `_shared/auth.ts` (`isServiceRole`, 4 Deno testi); `cleanup-anonymous` korumaya alındı; `send-push` ve `reconcile-subscriptions`in yerel kopyaları ortak modüle bağlandı; üçü yeniden dağıtıldı. **Doğrulama:** anon anahtarla POST → önce **200**, sonra **403** |

### 2.2 Sessizce yanlış çalışacak — kapatıldı

| # | Bulgu | Ne yapıldı |
|---|---|---|
| S1 | Sentry `environment` yok | `production`/`development` (`release`/`dist` zaten otomatik) |
| S2 | Android release `ADMOB_APP_ID` yoksa test kimliğiyle çıkıyordu | `android.yml`: release'te sır yoksa **kırmızı**; `admob_test_ok` girdisiyle yalnız doğrulama derlemesi |
| S6 | `confetti` yalnız arşivde | Bağımlılık kaldırıldı; arşiv README'sine geri taşıma notu |
| S7 | Bayat yorumlar | `build.gradle.kts` şablon `TODO`su, `Info.plist` AdMob yorumu |
| S8 | Eski `v1.0.0` Release "Latest" | `--prerelease` + "aşıldı" notu |
| **U1** | **Cevap paneli çelişkili söz:** plan yazılamadığında hem "3 gün sonra yeniden soracağım" hem "tekrar planı kaydedilemedi" yazıyordu | Plan yazılamadıysa gün sözü çizilmiyor; `answer_reveal_test` sabitliyor |
| **U2** | Bildirim yönlendirici: kabuk boştayken gelen dokunuş çerçeve planlanmadığı için bir sonraki dokunuşa kadar bekliyordu | `ensureVisualUpdate()`; `notification_router_test` tamponu sabitliyor |
| **U5** (tur) | **Çekim ekranı boş:** `ff_multi_capture` açık + premium hesapta Tekli/Çoklu anahtarı `Row` içinde sınırsız genişlik alıyor (`SegmentedTabs` kendi içinde `Expanded` taşıyor) → RenderFlex hatası, ekranın ortası çizilmiyordu. Bayrak üretimde kapalı olduğu için hiçbir turda görülmemişti | `Expanded` + kilit ikonu sağda; `capture_screen_test` (3) — `Expanded` kaldırılınca 2/3 kırmızı; canlıda yeniden gezildi (A_39) |
| **U6** (tur) | **Çoklu sonuç özeti yalan söylüyordu:** sunucu konuyu ve şıkları çıkarmış, yalnız doğru şık eksikken özet "2 okunamadı" yazıyordu — satırın kendisi şık seçiciyi gösterirken | `_failed` yalnız gerçekten okunamayanı sayıyor; yeni `batchAwaiting` ("N şık bekliyor") yalnız >0 iken ekleniyor; halka analizi bitmiş bütün satırları sayıyor; `batch_result_screen_test` (2) — sayaç eski hâline dönünce kırmızı |
| **U7** (tur) | **"Kabul et" iki satıra kırılıyordu:** gelen istek satırında üç düğme tek `Row`da eşit bölüşüyor, 393pt'te her birine ~105pt düşüyordu | `FriendRequestTile` ayrı widget, iki sıra (ana eylem tam genişlik, Reddet/Engelle altta); `friend_request_tile_test` (4) **gerçek yazı tipleriyle** ölçüyor (Ahem'le "Reddet" bile taşıyor, sahte kırmızı) — üç-düğme düzenine dönünce 375 ve 393'te kırmızı |

### 2.3 Ürün kararı olarak kapalı

K6 tek taban ayı · anonim temizliği `created_at` ölçütü · `SendResult.message`
ARB dışı · onboarding'de atlama yok · askı ekranı istemcide kapatılabilir ·
`personaTone` çizilmiyor · `legal_version` 1.3 (mağaza metinleriyle 1.4).

---

## 3. Yeni testler

| Dosya | n | Sabitlediği | Ayırt etme kanıtı |
|---|---|---|---|
| `auth/login_screen_test` | 3 | reddedilen girişte sebep + düğme serbest | `finally` kaldırıldı → kırmızı |
| `settings/delete_account_screen_test` | 4 | takma ad kapısı (harf/boşluk duyarsız), hata dalında ekran açık, tek çağrı | eşleşme büyük/küçük harfe duyarlı yapıldı → kırmızı |
| `settings/suspended_screen_test` | 6 | kalıcı/süreli, tarih uydurulmuyor, `onContinue`, itiraz adresi yok, uyarı tonu kayıt anından | `_permanent` dalı kapatıldı → kırmızı |
| `settings/privacy_screen_test` | 1 | adres yokken satır yok, "hazırlanıyor" yok | koşulsuz çizime dönüldü → kırmızı |
| `services/notification_router_test` | 6 | tablo + tampon + boş tür | tablo satırı bozuldu → kırmızı; `ensureVisualUpdate` kaldırıldı → kırmızı |
| `practice/session_end_screen_test` | 4 | "bir tur daha" yalnız izin + kalan; kapatma hedefi | `canContinue` koşulu kaldırıldı → kırmızı |
| `practice/answer_reveal_test` | 5 | plan yoksa gün sözü yok; rozetler sunucudan | gün sözü koşulsuz çizildi → kırmızı |
| `capture/pending_photos_screen_test` | 3 | boş/dolu, başka kullanıcının kaydı görünmez | tek satırlık koruma yok (süzgeç `_load` içinde) — turda S kanıtı |
| `onboarding/onboarding_flow_test` | 4 | 3/4 adım, geri tuşu bir adım geri, kökte akışa dokunmuyor | `canPop: true` yapıldı → kırmızı |
| `mistakes/topic_picker_sheet_test` | 3 | ders seçmeden arama (C6), `TopicPick`, boş durum | ders kilidi sunucu ağacında değil, arayüzde yok; C6 kanıtı arama sonuçlarının iki dersten gelmesi |
| `inbox/report_sheet_test` | 3 | sebepsiz Gönder kapalı, tek çağrı, hata dalı | sebep kapısı kaldırıldı → kırmızı |
| `inbox/send_question_sheet_test` | 1 | hata dalında tekrar dene + kapat | hata dalı sayfanın tek kapatma yolu; kapatma `IconButton`ı ortak |
| `capture/capture_screen_test` | 3 | çoklu anahtarı: bayrak + ücretsiz → kilit ikonu ama içerik yerinde; premium → kilit yok; bayrak kapalı → anahtar yok | `Expanded` kaldırıldı → 2/3 kırmızı (RenderFlex) |
| `capture/batch_result_screen_test` | 2 | yalnız şıkkı eksik satır "şık bekliyor", okunamayan "okunamadı"; parça yalnız >0 iken; başka parti görünmez; hazır satır yokken onay kapalı | `_failed` eski sayıma döndü → kırmızı |
| `league/friend_request_tile_test` | 4 | 375/393pt'te üç etiket tek satır (1000pt referansına eşit yükseklik); `busy` üçünü kilitler; üç geri çağrı | üç-düğme `Row`una dönüldü → 375 ve 393 kırmızı |
| `_shared/auth_test.ts` (Deno) | 4 | anon ≠ servis rolü | CI'da koşar (yerelde deno yok) |

Test dikişleri (`@visibleForTesting`): `AuthRepository.signInOverride`,
`.isAnonymousOverride`, `AccountRepository.deleteOverride`,
`UserProfile.setNicknameForTest`, `DailyStateRepository.ageStatusOverride`, `.readOverride`,
`FriendRepository.reportOverride`, `SocialRepository.relationsOverride`,
`NotificationRouter.resetForTest`. Öğrenilen: `testWidgets` sahte-zaman
bölgesinde **gerçek dosya G/Ç'si hiç bitmiyor** (iki test sonsuza kadar
asıldı) — `tester.runAsync` şart.

**Ertelenen:** `PublicProfileScreen` (üç depo çağrısı, yalnız biri dikişli —
turda `S` kanıtı alacak).

---

## 4. CI kapıları

| Kapı | Kendi sınaması |
|---|---|
| `app-ads.txt` yer tutucu + xcconfig eşitliği | dört bozuk girdi yakalanıyor, düzgün ikiz geçiyor |
| SKAdNetwork ≥30 + Google kimliği | üç uydurma plist |
| İkon Flutter varsayılanı değil | `shasum` mekanizması bilinen girdiyle |
| `android.yml` `ADMOB_APP_ID` | release + sır yok → `exit 1` |

---

## 5. Üretim işlemleri

| Adım | Sonuç | Doğrulama |
|---|---|---|
| 0103 | basıldı | `unique_violation` dalı var; anon ✓ authenticated ✗ |
| IAP sırları | iki anahtar, iki yer | `app_config` 64 karakter; `secrets list`te `IAP_SECRET`, `AI_REFUND_SECRET` |
| `ff_iap` | `'false'` | sorgu |
| Edge dağıtımı | 10 fonksiyon | `functions list`; JWT'siz smoke: 401/403 beklendiği gibi, `cleanup-anonymous` 200 → **Y8** |
| Y8 yaması | 3 fonksiyon yeniden | anon anahtarla POST → 403 |
| Eski Release | prerelease | `isPrerelease = true` |

### 5.1 Üretim işlemleri 2 (faz 8)

| Adım | Karar / sonuç | Doğrulama |
|---|---|---|
| Test hesapları (8) | **Silinmedi** (karar) | `auth.users` 10; liste §8 |
| DB parolası | **Döndürüldü** (Management API `PATCH …/database/password`, 200); yeni parola yalnız `~/.kimo-release/db.env` (0600) | Yeni parolayla pooler üzerinden (5432 ve 6543) `supabase migration list` bağlandı |
| `sbp_` kişisel jeton | **Bekliyor — yalnız hesap sahibi üretebilir.** Yeni jeton `~/.kimo-release/sbp.env`e (`export SUPABASE_ACCESS_TOKEN=…`), eskisi Dashboard → Account → Access Tokens'tan iptal; ben yenisiyle API'yi, eskisiyle 401'i doğrularım | — |
| `service_role` (eski tip HS256 JWT) | **Ayrı adım** (karar): önce yayın adayı, sonra göç — runbook §8 | — |
| `schema_migrations` | API ile basılan 6 göç (0917 ×5, 0918 ×1) kayda geçirildi | `supabase migration list`: yerel 110 / uzak 110, eksik 0 |
| `ADMOB_TEST_DEVICE_IDS` | Simülatör SDK'da otomatik test cihazı; kimlik yalnız gerçek cihazda loga düşer → o gün yerel `supabase.json`a | — |

---

## 6. Tur

### 6.1 Düzenek

İki simülatör: **A** iPhone 16 Pro (Ada, `ada@kimo.test`, tur boyunca
premium/yönetici/askı tohumları aldı) ve **B** iPhone 16 (Bora,
`bora@kimo.test`, **kayıt adımından** başlayarak turda açıldı). Yapı:
`flutter build ios --simulator --dart-define-from-file=supabase.json`
(turun ortasında U5 için, sonunda U6+U7 için iki kez yeniden kuruldu ve
düzeltilen yüzeyler yeniden gezildi). Araçlar: `idb ui tap/swipe/text`,
`axtree` (erişilebilirlik ağacı), `simctl io screenshot`, `simctl push`,
`simctl addmedia` (fizik sorusu görseli). Tohumlar Management API ile;
her tohum turdan sonra geri alındı (§6.3).

Öğrenilen tuzaklar (bir sonraki tur için): `idb ui tap` anlık ve 0,15 sn'lik
iki kipte de deneniyor, hangi widget'ın hangisine yanıt verdiği değişiyor —
her dokunuş ağaç ya da sunucu sorgusuyla doğrulandı; **`axtree` sorgusu
kaydırılmış `ListView`'ı başa alıyor** (Soruyu düzelt ekranı: A_53c vs
A_53e) — kaydırdıktan sonra ağaç sormadan koordinattan dokunmak gerekiyor;
Türkçe klavye `@`/`.` yazamıyor → B'nin klavyesi US'e alındı; A'da e-posta
girişi yok (Login formu B'de gezildi).

### 6.2 Sıra ve kanıt

Sıra §1'deki S listesi: B'de sıfırdan kayıt (B_01…B_14) → ilk fotoğraf,
bekleyen kuyruk, onay, konu seçici (B_15…B_19) → Bugün dolu (B_20) →
Hatalarım/Lig/Profil/Ayarlar (B_21…B_26) → push afişi (B_27, B_28) → A'da
Bugün, hak sayfası, tekrar oturumu uçtan uca (A_01…A_07) → Hatalarım, silme
onayı, gönder sayfası A→B (A_08…A_12) → Lig, Arkadaşlar, profil, menü
(A_13…A_16) → Profil, avatar, Ayarlar ve her alt sayfası (A_17…A_26) →
istek/kabul (A_27, A_29, B_23) → Hesabı sil ekranı (A_28) → hak tükenmiş
çekim + duvar + paywall (A_31…A_34, `ai_calls` tohumu) → Plus abone
(A_34, `subscriptions` + `premium_until` tohumu) → çoklu çekim + sonuç
(A_39…A_49, `ff_multi_capture` geçici açık) → gelen kutusu, çöz, bildir
(B_30…B_35) → gönder giriş + arşiv (B_36…B_39) → ortak seri davet + kutlama
(A_37, A_38, B_40) → yönetim: şikâyet kuyruğu, tüm sorular, editör, silme
diyaloğu, şüpheli fotoğraf, yaptırım sayfası (A_50…A_60, `admins` +
`photo_scan='flagged'` tohumu, gerçek şikâyet B'den) → askı ekranı ve
fotoğraf uyarısı (A_61, A_62; `user_sanctions` tohumu + "Kaldır" kararının
ürettiği gerçek `photo_violations` satırı) → avatar sayfası (A_63) →
**düzeltmelerin yeniden turu:** çekim kilit ikonu (A_64), iki sıralı istek
satırı + kabul (B_41), çoklu sonuç "şık bekliyor" (A_65) → çıkış, giriş,
hesap silme (§6.4).

Her adımda sunucu tarafı ayrıca sorgulandı: gönderim satırı, `solved_at`,
`question_reports.status` (pending → dismissed), `mistakes.moderation`
(hidden → ok; removed), depolama nesnesi silindi (0), `photo_violations.
acknowledged_at`, `is_suspended()` true → false, `mistakes` sayısı 4 → 6 →
8 → 10 (iki çoklu parti).

### 6.3 Turda görülen, düzeltilen ve karar verilen

| Gözlem | Sonuç |
|---|---|
| Çekim ekranı premium + bayrakta boş | **U5**, düzeltildi, yeniden gezildi |
| Çoklu sonuç "2 okunamadı" derken şık seçici gösteriyor | **U6**, düzeltildi, yeniden gezildi |
| "Kabul et" iki satır | **U7**, düzeltildi, yeniden gezildi |
| İlk çoklu partide "Hepsini onayla" dokunuşu tutmadı (üç deneme, ekran değişmedi, kuyruk `ready` kaldı); uygulama yeniden açılınca **soğuk-başlangıç `flush`'ı iki kaydı da yükledi**, kayıp yok; ikinci partide düğme tek dokunuşla çalıştı (A_49) | Yeniden üretilemedi; kuyruğun var olma gerekçesi tam bu: hiçbir fotoğraf kaybolmadı. İzleniyor |
| Yönetici kendi hesabına yaptırım: sunucu `geçersiz hedef` (22023) ile reddediyor, istemci "İşlem tamamlanamadı" | Karar: sunucu kuralı doğru ve bilinçli (dört kişilik ekipte tek moderatörün kendini kilitlemesi); yönetici yüzeyinde genel mesaj yeterli |
| Ödüllü reklam simülatörde `Publisher data not found` (AdMob code 1) | Beklenen: uygulama mağazaya bağlanana kadar AdMob gerçek envanter vermiyor; hata sessiz değil (`debugPrint`), duvar yine çiziliyor |
| StoreKit `storekit_no_response`, ürün bulunamadı | Beklenen: simülatörde mağaza yok; Plus "henüz açılmadı" diyor, `ff_iap=false` ile tutarlı |
| Push afişi geliyor, dokunuş uygulamayı açıyor ama rota yok | Simülatörde APNS jetonu yok (`apns-token-not-set`); yönlendirme tablosu birim testte — §7 |
| Kayıt adımında koşul metni dört ayrı "Link" düğümü | Karar: parça düzeyinde dokunma hedefi (K1) bunu gerektiriyor; VoiceOver sırayla okuyor |
| Yönetici hesabı: `admins` tablosu turdan sonra **boş** (0) | §8 — yayın öncesi gerçek yönetici hesabı eklenmeli |

**Geri alınan tohumlar (sorguyla doğrulandı):** `ff_multi_capture='false'` ·
Ada `subscriptions` satırı silindi, `premium_until=null` · `admins` 0 ·
`user_sanctions` ve `photo_violations` tur satırları `voided_at` ·
`is_suspended(ada)=false` · `ai_calls` tohumu (Task 17 deseni) · Bora'nın
parolası tur için sıfırlandı (hesap §6.4'te siliniyor).

### 6.4 Çıkış, giriş, hesap silme

B'de Ayarlar → "Çıkış yap" → Welcome (B_42) → "Hesabım var" → Login boş
(B_44) → e-posta + parola (B_45; parola tur için sıfırlanmıştı) → "Giriş
yap" → Bugün "9 hakkın kaldı" (B_46): giriş uçtan uca gerçek sunucuyla.
Login formunun hata dalı `login_screen_test`te.

**Hesap silme: karar — üretimdeki test hesapları SİLİNMEDİ** (faz 8.1
sorusuna yanıt: "Hiçbirini silme"). `auth.users`: 10 hesap — 8 test
(`kimo-test-1@`, `kimo-model-test@`, `task14a@`, `kimo-t14-a@`,
`kimo-t14-c@`, `ada@`, `efe@`, `bora@`), 2 gerçek. DeleteAccount ekranı
görüldü (A_28) ve `delete_account_screen_test` (4) davranışı sabitliyor;
uçtan uca silme §7'de. Liste §8'e "yayın öncesi temizlik" olarak girdi.

---

## 7. Doğrulanmayanlar

| Ne | Neden | Nerede kapanıyor |
|---|---|---|
| Kamera ile çekim | Simülatörde kamera yok | Galeri yolu aynı `PhotoQueue` girişini kullanıyor; cihaz turu |
| Gerçek satın alma (IAP) | Apple/Google hesabı ve ürün yok | `ff_iap=false`; Task 10 e2e'si `verify-purchase`ı sahte makbuzla kapatıyor |
| Gerçek ödüllü reklam | AdMob uygulaması mağazaya bağlı değil | SSV yolu Task 10'da test kimlikleriyle doğrulandı |
| Push dokunuşu → rota | Simülatörde APNS jetonu yok | `notification_router_test` (6) |
| Android geri tuşu | Cihaz/emülatör yok (SDK yok) | `onboarding_flow_test` PopScope'u sabitliyor |
| Mail compose (askı itirazı) | Simülatörde Mail yok | `openLegalUrl` false dönüşünde snack (kod) |
| Android'de çalışma | Yerelde SDK yok | CI `android.yml` derleme + imza; cihaz turu yok |
| Yayın imzalı iOS | Ücretli hesap yok | `--no-codesign` derleme CI'da |
| pgTAP / mutasyon / Deno yerelde | Docker, deno yok | CI (sayılar §0) |
| Login formu A'da | Türkçe klavye | B'de gerçek giriş (§6.4) + `login_screen_test` |
| Hesap silme uçtan uca | Karar: test hesapları silinmedi (§6.4) | `delete_account_screen_test`; `delete-account` fonksiyonu Task 13 e2e'sinde |

---

## 8. Mağaza kontrol listesi

**Apple:** ücretli geliştirici hesabı → takım kimliği (`ios/Runner.xcodeproj`
`DEVELOPMENT_TEAM`) → Push Notifications capability + APNs anahtarı Firebase'e
→ App Store Connect'te uygulama, abonelik ürünleri `kimo_plus_monthly` /
`kimo_plus_yearly` (P1M/P1Y), paylaşılan sır → `APPLE_IAP_*` edge sırları →
gizlilik formu (PrivacyInfo ile tutarlı: veri toplanıyor, izleme yok) → yaş
13+ → mağaza metinleri + `Marketing URL = https://kimo.work` (app-ads.txt
için) → TestFlight → `ios.yml` arşiv (şu an `--no-codesign`).

**Google Play:** geliştirici hesabı → uygulama → `.aab` (`android.yml
bundle=true`, yükleme anahtarı SHA-256 §2.1 Y1) → abonelik ürünleri →
servis hesabı JSON → `GOOGLE_PLAY_SERVICE_ACCOUNT`, `ANDROID_PACKAGE_NAME`
→ veri güvenliği formu → hesap silme sayfası adresi (`kimo.work` altında,
uygulama içi yol zaten var) → **AdMob'da Android uygulaması** →
`ADMOB_APP_ID` GitHub sırrı (yoksa yayın yapısı kırmızı, S2).

**AdMob:** `app-ads.txt` `https://kimo.work/app-ads.txt` kökünde (dosya
`web/app-ads.txt`, yayıncı kimliği konsoldan teyit) → SSV geri çağrı adresi
`ad-reward` fonksiyonu → uygulama mağazaya bağlanınca "Publisher data not
found" kalkar → test cihazı kimlikleri `ADMOB_TEST_DEVICE_IDS`.

**Sır göçü (service_role) — mağazaya göndermeden ÖNCE, ayrı task:**
Sızan `service_role` **eski tip** (legacy HS256) anahtar. Projede imzalama
anahtarları zaten yeni düzende (ES256 `in_use`, HS256 `previously_used`),
uygulama **zaten publishable anahtarla** çalışıyor (`supabase.json` →
`SUPABASE_PUBLISHABLE_KEY`), yeni tip `secret` anahtar da tanımlı. Eski
anahtarı geçersiz kılmak = HS256 anahtarını **revoke** etmek; bundan önce
eski anahtara bağımlı iki yer taşınmalı: (1) `vault.decrypted_secrets`
`service_role_key` (üç cron işi `net.http_post` başlığında kullanıyor) →
`sb_secret_…`; (2) altı edge fonksiyonunun `isServiceRole` kapısı (JWT
`role` alanına bakıyor) → yeni anahtar şemasına (Deno testi + yeniden
dağıtım) ve platformun enjekte ettiği `SUPABASE_SERVICE_ROLE_KEY` yerine
`sb_secret` ile `createClient`. Sıra: kod + test → 10 fonksiyon dağıt →
vault güncelle → cron'ları elle bir kez çalıştırıp 200 gör → HS256 revoke
→ eski anahtarla çağrı 401. Yan etki: iki gerçek hesabın oturumu düşer
(yeniden giriş).

**Yayın öncesi temizlik:** üretimdeki 8 test hesabı (`kimo-test-1@`,
`kimo-model-test@`, `task14a@`, `kimo-t14-a@`, `kimo-t14-c@`, `ada@`,
`efe@`, `bora@`; Bora'nın parolası tur için sıfırlandı) silinmeli —
`delete-account` yolu ya da yönetim API'si (depolama → auth). `sbp_`
jetonu döndürülmeli (§5.1).

**Sunucu, mağaza kimlikleri girildiğinde:** `ff_iap='true'` · `legal_version
= '1.4'` **en son** (metin 1.4 mağaza metinleriyle) · `admins` tablosuna
gerçek yönetici · Sentry `production` ortamında ilk olayın görülmesi.

**Depo:** keystore + `key.properties` yedeği (kayıp = güncelleme
yapamamak) · `supabase.json` sırları yalnız CI/yerelde.
