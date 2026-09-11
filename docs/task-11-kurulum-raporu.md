# Task 11 — Kurulum raporu

Yeni Supabase projesi sıfırdan kuruldu, üretim modeli değiştirildi, Sentry
bağlandı, AdMob ve Firebase yerleştirildi. Bu rapor **gerçekten koşturulan**
şeyleri yazar; koşturulamayanlar §7'de sebebiyle birlikte duruyor.

**Proje:** `trlmenjuzvlgglsxohph` · Frankfurt (`eu-central-1`) · 11 Eylül 2026
**Dal:** `task-11-kurulum` · **Eski proje `xsngxfmwlnsyoayfplgc`'ye hiçbir yazma yapılmadı.**

---

# 1. Kurulum sonucu — her hedef tam isabet

| Kontrol | Beklenen | Gerçek |
|---|---|---|
| Göç | 84 | **84** |
| `app_config` anahtarı | 15 | **15** |
| Cron işi | 7 | **7** |
| Depolama kovası | 2 | **2** (`avatars` 4 MB, `mistake-photos` 8 MB, üçer mime türü) |
| Vault `service_role_key` | 1 | **1** |
| `pg_cron` + `pg_net` | 2 | **2** |
| RLS'siz public tablo | 0 | **0** |
| Müfredat konusu | 434 | **434** (+538 takma ad) |
| `legal_version` | 1.3 | **1.3** |

Uygulanan sıra: eklentiler → 84 göç → Vault → 7 fonksiyon → gizliler →
`app_config` → auth ayarları + kanca → cron → `legal_version` (en son).

## 1.1 Bağlantı: doğrudan host çalışmıyor, havuzlayıcı çalışıyor

`db.<ref>.supabase.co:5432` bu projede bağlantıyı **reddediyor** (yalnızca IPv6
çözümleniyor ve doğrudan bağlantı kapalı). Çalışan tek adres oturum
havuzlayıcısı:

```
postgresql://postgres.trlmenjuzvlgglsxohph:<şifre>@aws-0-eu-central-1.pooler.supabase.com:5432/postgres
```

`aws-1` havuzlayıcısı "tenant/user not found" veriyor — yanlış havuzlayıcı.
Bu satır bir daha kurulum yapılırsa zaman kazandırır.

## 1.2 Auth: üç ayar ve neden atlanamazlar

`external_anonymous_users_enabled`, `mailer_autoconfirm`,
`hook_before_user_created_enabled` — üçü de `false`'tan `true`'ya alındı.

**`mailer_autoconfirm` kritik.** Açık kalmasaydı `convertToPermanent` e-postayı
`email_change`'te askıya alacak, `profiles.is_anonymous` düşmeyecek,
`user_tier()` ömür boyu `anonymous` dönecek (3 analiz, reklam ödülü yok) ve
uygulamada gösterilecek bir doğrulama ekranı artık olmadığı için kullanıcı
**hiçbir hata görmeyecekti** — sadece her açılışta karşılama akışına düşecekti.

> `docs/task-03-yayin-hazirlik-raporu.md:475-476, 507-508` bunun **tersini**
> söylüyor ("istemci yayını sonrası `enable_confirmations` aç"). O runbook
> bayat; kod Task 06-08'de doğrulama dallarını tamamen sildi.

---

# 2. Model geçişi — ölçüm kararı dayattı, üretimde doğrulandı

`gpt-4o-mini` → **`gpt-5.6-luna`** (`detail: "high"`, `reasoning_effort: "none"`,
`max_completion_tokens: 800`).

## 2.1 Maliyet: eski model cap tablosunu çözmüyordu

Aynı fotoğraf, önbelleksiz, gerçekçi 4:3 dikey, 1600px:

| model | $/çağrı | yıllık planda başabaş cap |
|---|---|---|
| `gpt-4o-mini` | $0.00452 | **236 analiz/ay** |
| `gpt-5.6-luna` | **$0.00146** | **732** (%70 dolulukta 1046) |

Sevk edilen premium cap **1000**. Yani eski modelde tablo matematiksel olarak
çözülmüyordu; luna'da ayakta. Ücretsiz 300 geniş payla altında.
**`app_config` cap değerlerine dokunulmadı** (ekip kararı).

## 2.2 Asıl sebep: eski model okunamayan fotoğrafta uyduruyordu

Kasten bulanıklaştırılmış, gözle okunamayan bir soru fotoğrafı, **aynı dosya**:

| | `gpt-4o-mini` (eski) | `gpt-5.6-luna` (yeni, üretimde doğrulandı) |
|---|---|---|
| `is_readable` | `true` | **`false`** |
| `reason_code` | `ok` | **`unreadable`** |
| şıklar | beş şık **uydurdu** (kaynakla sıfır örtüşme) | yok |
| ders/konu | "TYT/Türkçe/Anlatım Bozuklukları" | boş |

Sonuç: `AnalysisFailure.unreadable` dalı ve ona bağlı elle-giriş yolu pratikte
hiç tetiklenmiyordu. Kullanıcı bulanık fotoğraf çektiğinde hata görmüyor,
arşivine **uydurma beş şık** giriyor ve aralıklı tekrar motoru onu o uydurma
içerikle çalıştırıyordu.

## 2.3 Üretimde uçtan uca doğrulama

Dağıtılmış fonksiyona gerçek istek:

| Fotoğraf | Sonuç |
|---|---|
| Okunur TYT Matematik | HTTP 200, 4.3 sn · `is_readable=true` · **TYT / Matematik / Birinci Dereceden Denklemler ve Eşitsizlikler** · beş şık (12, 15, 18, 20, 24) |
| Bulanık | HTTP 200, 2.9 sn · `is_readable=false` · `reason_code=unreadable` · şık yok |
| Aynı fotoğraf tekrar | HTTP 200, **1.0 sn** · hak **düşmedi** (8→8) — önbellek isabeti, OpenAI'a hiç gitmedi |

Konu adı göç 0072'nin tohumladığı ağaçtan geldi, yani taksonomi zinciri de
çalışıyor.

## 2.4 İstek şekli — tuzaklar

Ölçümün referans uygulaması `tools/ab_model_bench.mjs:164-181`. Üç ayrıntı
sezgiye ters ve yanlış yazılırsa sessizce bozulur:

- `detail` **görsel nesnesinin içine** konur, payload köküne değil.
- `reasoning_effort` **düz kök alanı**; iç içe `reasoning: { effort }` DEĞİL.
- `detail: "high"`, `auto`'dan **ucuz** (6.658 vs 7.737 istem token'ı).

Üretim payload'ında `temperature`/`max_tokens` gibi luna'nın reddedeceği eski
nesil alan yoktu, geçiş bu yönden temizdi.

> ⚠️ **Model adını sınayan hiçbir test ya da CI kapısı yok** ve CI'da edge
> fonksiyonlarına dokunan hiçbir iş yok. Tek gerçek kapı §2.3'teki canlı çağrı.

---

# 3. Göç 0072'de gerçek bir kusur — boş veritabanında patlıyordu

`curriculum_seed` temiz bir veritabanında **23505** ile düştü; göçler 77'de
durdu.

```
duplicate key value violates unique constraint "curriculum_aliases_norm_key"
Key (curriculum, exam, subject, alias_norm)=(eski, TYT, Matematik, olasilik)
```

**Kök neden.** `alias_norm` üretilmiş bir sütun (`tr_norm(alias)`) ve benzersiz
indeks onun üzerinde. Taksonomi üreticisi, normalize edildiğinde çakışan takma
adları SQL'e iki kez yazıyordu — **8 çift**, hepsi aynı şeklin: aynı takma ad
bir kez küçük bir kez büyük harfle, **ikisi de aynı konuya** gidiyor.

Doğrulayıcı bu çakışmayı yalnızca *farklı konuya* gittiğinde hata sayıyor
(`prev[1] != topic`); aynı konuya gidince geçiriyor — ama yazıcı yine de ham
listeyi gezip iki satırı da basıyordu. Doğrulayıcının kendi yorumu bunu
öngörmüştü: *"yakalanmazsa tohum INSERT'i üretimde patlardı."*

**Düzeltme.** Yazıcı artık `tr_norm` anahtarıyla eliyor. Eleme kayıpsız: arama
zaten `alias_norm` üzerinden (`20260907000100_curriculum.sql:259`), tek satır
her iki yazımı da çözüyor. **Remap satırları elenmiyor** — orası
`mistakes.concept` ile ham string karşılaştırıyor, iki yazım iki ayrı eski
kayıt kümesi demek.

Tohum yeniden üretildi: **546 → 538** takma ad, 434 konu aynı, **sürüm dizesi
değişmedi** (`7d00385d45b1`) → istemci önbelleği etkilenmiyor.

Ayırt ettiğini kanıtlayan bir öz-test eklendi: düzeltme geri alınınca kırmızı
yanıyor. Bu göç bugüne kadar hiçbir temiz veritabanında hiç çalışmamıştı.

---

# 4. Sentry — temizleyicide iki delik vardı, kapandı

İstenen şart: fotoğraf, e-posta, takma ad ve kullanıcı kimliği rapora
düşmemeli. **Bugüne kadar sağlanmıyordu.**

1. Temizleyici e-postayı `event.message` içinde maskeliyordu. Ama uygulamanın
   **tek** raporlama yolu `reportError → captureException` ve o, metni
   `exceptions[].value` alanına yazıyor. **Orası hiç temizlenmiyordu** — yani
   mesaj maskesi pratikte hiç çalışmıyordu.
2. Breadcrumb süzgeci yalnızca `b.message`'a bakıyordu. HTTP breadcrumb'ında o
   alan **null** ve adres `b.data['url']` içinde — imzalı fotoğraf adresi
   süzgeçten hiç geçmeden gidiyordu.

Artık e-posta, JWT, kullanıcı kimliği (UUID) ve imzalı depolama adresi hem
istisna gövdesinden hem breadcrumb `data` haritasından temizleniyor.

**Kanıt.** 9 yeni test; düzeltme geri alınınca **7'si düşüyor**. Mevcut dört
test de zaten çalışan yolları sınıyordu — deliklerin hayatta kalma sebebi buydu.

**Canlı kanıt.** Panele iki olay gönderildi:

| olay | etiket | istisna gövdesi |
|---|---|---|
| `3ec456c1…` | `temizleyici: UYGULANMADI-ham-ornek` | e-posta ve uid **açıkta** |
| `bf5e11ee…` | `temizleyici: UYGULANDI-scrubEvent` | `<e-posta> <kimlik> <jeton> <fotoğraf-adresi>` |

İkinci olayın metni gerçek `CrashService.scrub` çıktısı, elle yazılmadı.

> **Yan sonuç:** hukuki metindeki *"kullanıcı kimliğiniz ve e-postanız
> gönderilmeden önce silinir"* iddiası bugüne kadar **doğru değildi**. Şimdi
> doğru — ve metin, jeton ile fotoğraf adreslerini de kapsayacak şekilde
> güncellendi.

**Not:** `flutter test` içinden Sentry'nin kendi taşıma katmanı olay
göndermiyor (kimlik sıfır dönüyor). DSN'in kendisi sağlam: zarf ucu HTTP 200
veriyor.

---

# 5. Uçtan uca doğrulanan akışlar

Hepsi sıfırdan kurulan projede, gerçek çağrılarla:

| Akış | Sonuç |
|---|---|
| Anonim oturum + kayıt kancası | uid alındı · `ai_tier=anonymous` · ömür boyu 3 · **reklam teklifi kapalı** |
| Anonim kota | 3 hak → 4'üncü ret · `ok → low → lifetime_full` |
| **13 altı reddi** | `KM013` "Kimo 13 yaş ve üzeri için" |
| **Ret tek-yazım hakkını harcamıyor** | `birth_year_set=false` — Task 08 tasarımı doğrulandı |
| Geçerli yaş | kabul · `ai_age_ok=true` · ikinci yazım `22023` ile ret |
| Yaş kapısı AI'da | `birth_year` yokken `analyze-question` → **403 `age_required`** |
| Kalıcı hesaba geçiş | e-posta **anında onaylandı**, askıya alınmadı · `is_anonymous` düştü · katman **free** |
| Free kayan pencere | 10 hak → 11'inci duvar · `ai_next_at_hm=06:34` (UTC 03:34 → İstanbul, sunucu hesaplıyor) |
| Aylık cap | 300 → 290, pencereden ayrı sayıyor |
| Onay defteri | iki satır (`terms`, `privacy`) · `text_version=1.3` |
| Fotoğraf analizi | §2.3 |
| Önbellek isabeti | aynı fotoğraf → **hak düşmüyor**, 1.0 sn |
| **Ödül: istemci kendine verebilir mi** | **`permission denied for function grant_ad_reward`** |
| Ödül: yanlış sır | `false` (fail-closed) |
| Ödül: doğru sır | `true` · pencere 0→1 · **aylık cap 290'da kaldı** |
| Ödül: 5 kez tekrar oynatma | tek `granted` satır, sayaçlar kıpırdamadı — idempotent |
| Fonksiyon duman testleri | `ad-reward` JWT'siz **200** · `analyze-question` bozuk gövde **400** · `scan-photos` anon **401** · `delete-account`/`delete-question` **405** · `send-push` anon **403** |

## 5.1 `legal_version` sıralaması — somut olarak gösterildi

Değer yazılmadan önce onay alan bir test hesabı **`1.0`** damgalandı. Onay
defteri `UPDATE`/`DELETE`'e kapalı olduğu için o satır **artık düzeltilemiyor**.
Sonra `1.3` yazıldı; yeni hesap iki satırı da doğru damgaladı.

Bu yüzden `legal_version` kurulumun **en son** adımı olmalı — ve metinler
yayına çıkmadan yazılmamalı.

## 5.2 Ödül tasarımı canlıda doğrulandı

Reklam ödülü **yalnızca kayan pencereyi** açıyor; aylık cap'e dokunmuyor. Ödülle
açılan çağrı yine `ai_calls`'a yazıldığı için aylık cap'i tüketiyor. İstemci
kendine hak veremiyor: `grant_ad_reward` `authenticated` rolüne kapalı, yalnızca
JWT'siz edge fonksiyonu çağırabiliyor.

---

# 6. AdMob, Firebase ve site

## 6.1 iOS'ta bulunan hata: yayın derlemesi TEST kimliğiyle çıkıyordu

`ios/Runner/Info.plist` Google'ın **test** AdMob uygulama kimliğini sabit
yazıyordu ve yanındaki yorumun atıfta bulunduğu `$(ADMOB_APP_ID)` değişkeni
**hiçbir yerde tanımlı değildi**. Android'de Gradle bunun için uyarı basıyor
(`build.gradle.kts:92-96`), iOS'ta karşılığı yoktu — yani sessizce yanlış.

xcconfig bağı kuruldu: `Debug` test kimliği, `Release` gerçek kimlik. Profile
yapılandırması da `Release.xcconfig` kullanıyor, üçü de kapsandı.

## 6.2 Yerleştirilen değerler

| Değer | Nerede |
|---|---|
| `…~1926382184` (Android uyg.) | Gradle `ADMOB_APP_ID` |
| `…~8300218845` (iOS uyg.) | `Release.xcconfig` → `Info.plist` |
| `…/9665271400` · `…/4360973833` | `supabase.json` (izlenmeyen) |
| `pub-3524308481275678` | site `app-ads.txt` |
| `google-services.json` | `android/app/` |
| `GoogleService-Info.plist` | `ios/Runner/` |

Paket/bundle kimliği ikisinde de `com.stratejico.kimo` — eşleşiyor.
(`google-services.json`'daki ikinci istemci `…ai_yks_coach` eski, zararsız.)

**SSV geri çağrı adresi:**
`https://trlmenjuzvlgglsxohph.supabase.co/functions/v1/ad-reward`
(`ad-reward` JWT'siz **200** dönüyor — SSV geçitten geçebilir.)

## 6.3 Test cihazı desteği eklendi

`ADMOB_TEST_DEVICE_IDS`. Test **birimi** yedeğinden farklı bir şey: gerçek birim
kimliğiyle ama sahte reklam dolduran cihaz. Kayıtlı test cihazı olmadan gerçek
birimle reklam istemek geçersiz trafik sayılabiliyor. Boş bırakılırsa hiçbir şey
değişmiyor.

Reklam yükleme hatasındaki sessizlik de kapatıldı: **"doluluk yok" (code 3)
sessiz kalır, geri kalan her şey raporlanır.** İkisi kullanıcıya aynı görünüyordu
(duvarda reklam satırı yok) ve ekibi yanlış yerde hata aramaya götürüyordu.

## 6.4 Firebase iOS: plist projeye ekli değildi

`GoogleService-Info.plist` Xcode projesinde **hiç yoktu**, yani
`Firebase.initializeApp()` iOS'ta çalışamazdı. Koşullu bir betik adımıyla
eklendi — doğrudan kaynak olarak eklemek, dosya gitignore'lu olduğu için temiz
bir klonda iOS derlemesini kırardı. Bu yol Android'deki Gradle davranışının
aynısı: dosya varsa kopyalanır, yoksa uyarı basıp devam eder.

## 6.5 Site (`erdem1v/kimo.work`)

**Düzeltme:** site zaten **1.3 damgalı**; bayat olan kimo deposundaki kaynak
belgeydi (üç metin 1.2'de kalmıştı). O hizalandı.

Doğrulanmış 5 alan dolduruldu (yer tutucu 64 → 59):

| Alan | Değer | Dayanak |
|---|---|---|
| Supabase bölgesi | Almanya (Frankfurt) | yönetim API: `eu-central-1` |
| Sentry bölgesi | Almanya | DSN `ingest.de.sentry.io` |
| AdMob yayıncı kimliği | `pub-3524308481275678` | uygulama kimliklerinden |
| OpenAI veri işleme adresi | `developers.openai.com/api/docs/guides/your-data` | sayfa açılıp içeriği teyit edildi: API verisi eğitimde kullanılmıyor, kötüye kullanım kayıtları **30 güne kadar** |

`DOLDURULACAKLAR.md` §5'teki "birim maliyet ölçümü henüz yapılmadı" maddesi
kapatıldı: ölçüm yapıldı ve sitedeki kota rakamları ayakta.

Şirket bilgileri, hukukçu kararı bekleyenler ve `[Sentry saklama süresi]`
**ellenmedi**. Değişiklikler yerelde hazır, **push edilmedi**.

---

# 7. Koşturulamayanlar ve sebebi

| İş | Sebep |
|---|---|
| Tarayıcı arayüz akışları | **Chrome eklentisi bağlı değil** (`Browser extension is not connected`). Web derlemesi gerçek yapılandırmayla hazır ve `127.0.0.1:8787`'de sunuluyor |
| iOS simülatör derlemesi | **Bellek yetersizliği** — makinede 8 GB, derleme sırasında 0.4 GB boşta, 3.9 GB takas, Xcode açık |
| Android derlemesi ve emülatör | Bu makinede **JDK yok, Android SDK yok, `gradlew` yok** |
| Gerçek AdMob reklamı | Google Play Hizmetli gerçek cihaz gerekiyor. Ödül *mantığı* SQL'den doğrulandı; **SSV imzası doğrulanmadı** |
| FCM push | Aynı sebep + `FIREBASE_SERVICE_ACCOUNT` girilmedi |
| iOS push | APNs anahtarı ücretli Apple Developer hesabı istiyor |
| Sosyal akışlar (iki hesap) | Arayüz gerektiriyor; tarayıcı katmanı açılınca koşulacak |
| `ssv_test.ts` | `deno` kurulu değil. Task 10'da DER ayrıştırıcısı Node'da 200 gerçek imzayla doğrulanmıştı |

---

# 8. Eksik hesap yüzünden bekleyenler

| Hesap | Gelince yapılacak |
|---|---|
| **AdMob** | Konsolda **SSV geri çağrı adresini** §6.2'deki adrese ayarla · test cihazını kaydet · `app-ads.txt`'i alan adının **kökünde** yayınla (AdMob alt dizinde aramıyor) |
| **Firebase** | `FIREBASE_SERVICE_ACCOUNT` gizlisi (push'un sunucu tarafı) |
| **Apple Developer** | APNs anahtarı · gerçek cihazda çalıştırma |
| **Play Console** | "App content → Ads" beyanı · Veri Güvenliği formu · hesap silme adresi |
| **Alan adı** | `LEGAL_*` ve `SUPPORT_EMAIL` değerleri `supabase.json`'a. Girilmezse ilgili satır uygulamada **hiç çizilmiyor** |

---

# 9. Bulduğum ama düzeltmediğim şeyler

1. **Paywall tablosu cap değişirse yalan söyler.** Ürün metninde hiçbir cap
   rakamı sabit kodlu değil — hepsi sunucudan geliyor. **Ama**
   `plus_screen.dart:53-57` sunucu değeri verilmezse 8/10/300/50/1000'e düşüyor
   ve `credit_wall_screen.dart:544` ile `settings_screen.dart:176` ekranı
   parametresiz `const PlusScreen()` açıyor. `app_config` değişirse paywall eski
   rakamı göstermeye devam eder.
2. **Bayat "demo modu" iddiası 6 yerde.** `README.md:25`, `README.md:173`,
   `docs/ios-kurulum.md:95-97`, `lib/services/supabase_config.dart:4`,
   ve **`.github/workflows/android.yml:92, :173`** — sonuncusu test APK'sını
   üreten iş akışı. Mock mod Task 03'te kaldırıldı; `main.dart:20-27` artık
   `ConfigErrorApp` gösterip çıkıyor.
3. **`android.yml:171` koşulsuz "debug anahtarıyla imzalı" diyor**, oysa
   imzalama koşullu — gerçek anahtarla imzalanan APK yanlış notla yayınlanıyor.
4. **`.env.example` tümüyle ölü ve yanlış sağlayıcıyı anlatıyor**
   (Claude/`ANTHROPIC_API_KEY`); gerçek sağlayıcı OpenAI. `flutter_dotenv`
   bağımlılığı yok, dosyayı okuyan tek satır kod yok.
5. **`docs/task-03-yayin-hazirlik-raporu.md:475-476, 507-508` kodla çelişiyor**
   (§1.2). O runbook'a "geçersiz" notu düşülmeli.
6. **`grant_ad_reward` yaş kontrolü yapmıyor.** `20260908000200_ad_reward.sql:257`
   yorumu "süresi geçmiş" diyor ama `created_at` kontrolü yok; 5 dakikalık TTL
   yalnızca kullanıcının bir sonraki `start_ad_reward` çağrısında tembel silme
   olarak uygulanıyor. Gerçek zaman sınırı `ssv.ts:40`'taki 1 saatlik damga
   tazeliği. Ya kontrol eklensin ya yorum düzeltilsin.
7. **`docs/task-03-…:509` "3 cron işi" diyor**; göçler 5 kuruyor, elle eklenen
   iki budayıcıyla 7.

---

# 10. İptal — iş bitince

| Anahtar | Nereden |
|---|---|
| **Erişim jetonu (PAT)** | Dashboard → avatar → Account Preferences → Access Tokens → **Revoke** |
| OpenAI anahtarı | platform.openai.com → API keys → **Revoke** |
| `service_role` | Project Settings → API Keys → **Rotate** (döndürülürse Vault'taki `service_role_key` ve `app_config.push_service_key` de güncellenmeli) |
| Veritabanı şifresi | Project Settings → Database → **Reset database password** |

> Kurulum anahtarları bu görüşme sırasında sohbete de yapıştırıldı. İş bitince
> `service_role` ve OpenAI anahtarının döndürülmesi yerinde olur.

**Test hesapları:** projede 3 test hesabı duruyor
(`kimo-test-1@example.com`, `kimo-model-test@example.com`, bir anonim).
Tarayıcı testleri bitince uygulamanın kendi "Hesabımı sil" akışıyla
silinecekler.
