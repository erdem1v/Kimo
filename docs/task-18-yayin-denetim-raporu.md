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
| `flutter test` | **449** yeşil → faz 3 sonunda **492** | yerel |
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

*(Faz 6 turunda doldurulacak — 41 satır × S/K/U/D/A/Y + kanıt.)*

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
| `_shared/auth_test.ts` (Deno) | 4 | anon ≠ servis rolü | CI'da koşar (yerelde deno yok) |

Test dikişleri (`@visibleForTesting`): `AuthRepository.signInOverride`,
`.isAnonymousOverride`, `AccountRepository.deleteOverride`,
`UserProfile.setNicknameForTest`, `DailyStateRepository.ageStatusOverride`,
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

---

## 6. Tur

*(Faz 6)*

## 7. Doğrulanmayanlar

*(Faz 9'da tamamlanacak)*

## 8. Mağaza kontrol listesi

*(Faz 9'da tamamlanacak)*
