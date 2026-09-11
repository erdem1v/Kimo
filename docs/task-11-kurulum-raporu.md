# Task 11 — Kurulum raporu (ARA DURUM)

> **Bu rapor TAMAMLANMADI.** Kurulum, eksik iki kimlik bilgisi ve bulunan bir
> engel yüzünden başlayamadı. Aşağıdakiler bugüne kadar gerçekten yapılan ve
> gerçekten ölçülen şeyler; yapılamayanlar açıkça işaretli.

**Doğrulama durumu.** Yerelde koşan ve YEŞİL olanlar: Supabase CLI kurulumu
(2.117.0), `flutter build web` (63 sn, çıkış 0), OpenAI anahtar ve model
erişimi, dört gerçek A/B ölçüm koşumu (toplam ~$0.10 OpenAI harcaması).
**Koşmayanlar:** göçler, edge fonksiyonları, auth ayarları, uçtan uca testlerin
TAMAMI — hiçbiri başlayamadı.

---

# 1. Kimlik bilgileri: ne çalışıyor, ne eksik

`.env.kurulum` oluşturuldu (157 satır, her değerin üstünde panel yolu).
Gitignore **üç yolla** doğrulandı:

```
git check-ignore -v .env.kurulum
  .gitignore:58:.env.kurulum	.env.kurulum
git status            → dosyayı görmüyor
git add -A --dry-run  → stage'lemiyor
```

| Alan | Durum |
|---|---|
| `SUPABASE_PUBLISHABLE_KEY` | ✅ Geçerli — `/auth/v1/settings` 200 |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ Geçerli — JWT `role=service_role`, `ref` projeyle eşleşiyor, `/auth/v1/admin/users` 200 |
| Karışma kontrolü | ✅ Publishable ile yönetici ucu denendi → **401**. Yalnız öneke değil, yetkiye de bakıldı |
| `OPENAI_API_KEY` | ✅ 132 model. `gpt-5.6-luna` ✓ · `gpt-4o-mini` ✓ · `omni-moderation-latest` ✓ |
| `SUPABASE_PROJECT_REF` | ⚠️ Tam URL yapıştırılmıştı; referans çıkarılıp düzeltildi (JWT'nin `ref` alanıyla çapraz doğrulandı) |
| `SUPABASE_DB_PASSWORD` | ❌ Şifre değil, **`sb_secret_…` API anahtarı** girilmiş (geçerli bir yönetici anahtarı, ama şifre değil) |
| `SUPABASE_ACCESS_TOKEN` | ❌ **BOŞ** |

Supabase artık iki nesil anahtar veriyor (eski JWT `eyJ…`, yeni
`sb_publishable_`/`sb_secret_`) ve ikisi aynı ekranda duruyor. Karışması
beklenen bir şey; projede her iki nesil de mevcut ve ikisi de çalışıyor.

---

# 2. EN ÖNEMLİ BULGU — hedef proje beklenen proje değil

Kurulum "yepyeni ve boş proje" varsayımıyla planlanmıştı. **Salt-okunur
envanter bunu çürüttü.** Hiçbir yazma yapılmadan durduruldu.

`xsngxfmwlnsyoayfplgc`, README'nin uyardığı **eski üretim veritabanı** —
göçlerin elle SQL Editor'a yapıştırıldığı, `db push`'un yasaklandığı o
veritabanı.

| Bulgu | Değer |
|---|---|
| Şema seviyesi | **~göç 0025** (`set_osym_account` var, 0026'nın `admins` tablosu yok) → **~59 göç eksik** |
| Hesap | 11 (e-postalı, Ağustos 2026) |
| Soru | 15.924 — **15.922'si içe aktarılmış banka** (15.843 MEB), yalnızca **2'si kullanıcı içeriği** |
| Storage | 15.924 fotoğraf, iki kova (boyut/mime sınırı **YOK** — göç 0066 koyuyor) |
| `app_config` | 3 anahtar: `push_url`, `osym_user_id`, ve README'nin "ölü, silin" dediği **`push_secret`** |

**Uygulamanın ihtiyaç duyduğu çekirdek nesnelerin HİÇBİRİ yok:**
`my_daily_state`, `user_consents`, `rate_limits`, `ai_calls`, `ad_rewards`,
`user_sanctions`, `curriculum_*`, `admins`, `user_blocks`, `signup_throttle`,
`ai_result_cache`.

→ **Mevcut uygulama bu sunucuya karşı kısmen değil, hiç çalışamaz.**

## 2.1 İstenen `birth_year` kontrolünün cevabı: sıfır değil

Göç öncesi kontrol olarak `profiles where birth_year is null` istenmişti.
**Sütun henüz yok.** Göç 0043 onu nullable ekleyecek, göç 0067 ise RLS'e
`has_birth_year()` şartı koyacak — yani göçlerden sonra **11 hesabın hepsi
soru ekleyemez ve fotoğraf yükleyemez** hâle gelecekti
(`docs/task-08-kapanis-raporu.md:480-484`'ün uyardığı senaryo).

## 2.2 Alınan karar

**Yeni proje açılacak; eskisine dokunulmayacak; soru bankası taşınmayacak.**
11 hesap ekibin test hesapları. Eski projeye bu task boyunca **hiçbir yazma
yapılmadı**.

---

# 3. Yapılan hazırlık

| İş | Sonuç |
|---|---|
| Supabase CLI | **2.117.0**, depo DIŞINA (scratchpad) kuruldu — `package.json`/`node_modules` ağaca girmedi |
| `flutter build web` | ✅ 63 sn, çıkış 0, 40 MB. `google_mobile_ads` web derlemesini bozmadı (koşullu import çalıştı) |
| Test görselleri | 4 sentetik soru görseli, uygulamanın kendi çekim profiliyle (1600px, JPEG 85): okunur TYT Matematik, AYT Fizik, kasten okunamaz bulanık kare, ve gerçekçi 4:3 dikey tam sayfa |
| `PRICES` tablosu denetimi | ✅ **Güncel** — `ab_model_bench.mjs:61-64` iki modelin altı değerini de doğru taşıyor |

## 3.1 `--db-url` bulgusu: iki eksik anahtar eşit değerde değil

`supabase db push` **`--db-url` bayrağını kabul ediyor.** Bu, veritabanı
katmanının **erişim jetonu olmadan** kurulabileceği anlamına geliyor:

| Katman | Gereken | Onsuz |
|---|---|---|
| Veritabanı (84 göç, eklentiler, `app_config`, Vault, cron) | **DB bağlantı dizesi** | Şema yok |
| Auth (anonim oturum, kayıt kancası) | **PAT** ya da panelde iki anahtar | Kayıt akışı ilk adımda ölür |
| Edge fonksiyonları (7) + gizlileri | **PAT** | AI analizi, hesap silme, moderasyon yok |

---

# 4. AI ölçümü — beklenenden çok daha fazlası çıktı

Gerçek soru fotoğrafı olmadığı için istenen 40-fotoğraflık ölçüm
**yapılmadı**. Ama sentetik görsellerle koşulan dört gerçek ölçüm, iki tanesi
ürünü doğrudan ilgilendiren üç bulgu verdi.

## 4.1 Görsel maliyet modeli — tahmin değil, doğrulandı

gpt-4o-mini görsel token'ını **içeriğe değil boyuta** göre sayıyor:
`2833 + 5667 × döşeme`, kısa kenar 768'e ölçeklendikten sonra 512'lik
döşemelerle. Üç ölçümün üçünü de **tam isabetle** öngörüyor:

| Görsel | Döşeme | Tahmin | Ölçülen | Fark |
|---|---|---|---|---|
| 1600×683 | 8 | 51.888 | 51.888 | **0** |
| 1600×931 | 6 | 40.554 | 40.554 | **0** |
| 1600×2133 | 4 | 29.220 | 29.220 | **0** |

**Ters sezgi:** uzun (gerçekçi telefon oranı) fotoğraf, kısa/geniş kareden
**daha ucuz** — çünkü "kısa kenar 768" kuralı geniş ama kısa bir kareyi yatayda
uzatıp döşeme sayısını artırıyor.

**İkinci sonuç: `maxWidth`'i 1600'den 1200'e düşürmek hiçbir şey kazandırmıyor.**
Dikey bir fotoğrafta ikisi de 4 döşemeye düşüyor, token sayısı birebir aynı.
Maliyet kaldıracı çözünürlük değil.

## 4.2 Üretim modelinin birim maliyeti, cap varsayımının ~4 katı

**Önbelleksiz** (üretimde her fotoğraf benzersiz, önbellek yok), gerçekçi 4:3
dikey fotoğraf, 1600px:

| Yapılandırma | prompt | çıktı | $/çağrı |
|---|---|---|---|
| **`gpt-4o-mini` (ÜRETİMDEKİ model)** | 29.220 | 236 | **$0.00452** |
| `gpt-5.6-luna` (detail:high) | 6.658 | 103 | **$0.00146** |
| `gpt-5.6-luna` (detail:auto) | 7.737 | 103 | $0.00167 |

`cap_model.mjs` varsayılanı **`--unit 0.0011`**.

- Üretim modeli o varsayımın **~4,1 katı**
- **luna neredeyse tam olarak varsayımı tutturuyor** ($0.00146 ≈ $0.0011)

Yani cap tablosunun dayandığı birim maliyet, üretimde kullanılan modelin
ulaşamadığı bir sayı. **`app_config`'e DOKUNULMADI** ve cap tablosu yeniden
hesaplanmadı — Task 06'nın kuralı gereği bu bir ekip kararı.

> ⚠️ İlk koşumda önbellek yüzünden $0.00409 gibi düşük bir sayı çıkmıştı;
> 51.888 token'ın 46.336'sı önbellekten geliyordu çünkü aynı görselleri tekrar
> gönderdim. Üretimde her fotoğraf benzersiz. Yukarıdaki tablo önbelleksiz.

## 4.3 ⚠️ Ürün bulgusu: üretim modeli okunamayan fotoğrafta UYDURUYOR

Kasten bulanıklaştırılmış (gözle okunamaz) bir soru görseli gönderildi.

**`gpt-4o-mini` (üretimdeki model):** `is_readable: true`, `reason_code: "ok"`,
beş şıkkı da doldurdu, dersi ve konuyu "doğru" bildi. Ama döndürdüğü şık
metinleri kaynakla **sıfır örtüşüyor**:

| | Gerçek | gpt-4o-mini |
|---|---|---|
| A | Toplantıya katılanlara teşekkür etti. | "Yapılmasını istediğim madde -dir" |
| B | Hiç kimseyi kırmak istemiyordu. | "Bu konuda bir örnek vermemiştir." |
| C | Ona olan güvenini bir daha kaybetti. | "Hayvanlar arasında bir dile sahip." |
| D | Sorunu çözmek için çok uğraştı. | "Konuya dikkatimi çek." |
| E | Yazıyı dikkatle okudu ve düzeltti. | "Tüm açıklamalar -dür -dır." |

Ders/konuyu doğru bilmesi okuduğu için değil; beş şıklı düzen + başlık
deseninden en olası tahmini yapmış.

**`gpt-5.6-luna`:** `is_readable: false`, `reason_code: "unreadable"`, şık yok.
**Doğru davranış.**

**Ürün sonucu:** uygulamanın `AnalysisFailure.unreadable` dalı ve ona bağlı
"elle giriş" yolu, üretim modeliyle **büyük olasılıkla nadiren tetikleniyor.**
Kullanıcı bulanık bir fotoğraf çektiğinde hata görmüyor — arşivine **uydurma
beş şık** giriyor ve aralıklı tekrar motoru onu o uydurma içerikle çalıştırıyor.

**Sınır:** tek bir örnek. Oranı ölçmek için gerçek fotoğraflar gerekiyor. Ama o
tek örnekte sonuç tartışmasız.

---

# 5. Çalışmayanlar / yapılamayanlar

| İş | Sebep |
|---|---|
| Eklentiler, 84 göç, `app_config`, Vault, cron | DB bağlantı dizesi yok |
| Auth ayarları, kayıt kancası | Erişim jetonu yok |
| 7 edge fonksiyonunun dağıtımı ve gizlileri | Erişim jetonu yok |
| **Uçtan uca testlerin TAMAMI** | Yukarıdakiler olmadan uygulama açılmıyor |
| 40 fotoğraflık birim maliyet ölçümü | Gerçek fotoğraf yok |

Test maddelerinden ikisi (**elmasın görünmemesi**, **yasal satırların
çizilmemesi**) Task 10'da widget testleriyle zaten kanıtlanmıştı; canlı
doğrulama onları tekrarlayacak.

---

# 6. Eksik hesap yüzünden test edilemeyenler

| Hesap | Ne çalışmıyor | Ne sessizce devre dışı | Hesap gelince |
|---|---|---|---|
| **AdMob** | Ödüllü reklamın uçtan uca ödül yolu (gerçek SSV imzası üretilemiyor) | `ADMOB_REWARDED_*` boş → duvarda reklam satırı **hiç çizilmiyor** | Uygulama kimliklerini manifest/plist'e, birim kimliklerini `supabase.json`'a; AdMob konsolunda **SSV geri çağrı adresini** `ad-reward`'a ayarla; `app-ads.txt`'i yayınla |
| **Firebase** | Push bildirimi, `device_tokens` kaydı | `Firebase.initializeApp()` sessizce düşüyor; yerel bildirimler çalışmaya devam ediyor | `google-services.json` + `GoogleService-Info.plist`, `FIREBASE_SERVICE_ACCOUNT` gizlisi, `app_config.push_url`/`push_service_key` |
| **Apple Developer** | Gerçek cihazda çalıştırma, iOS push (`aps-environment` ücretli hesap istiyor) | Simülatör imza istemiyor | Ücretli hesap + APNs anahtarı |
| **Play Console** | — | — | "App content → Ads" beyanı, Veri Güvenliği formu |
| **Sentry** | Çökme raporlama | `SENTRY_DSN` boş → hatalar yalnızca konsola | DSN'i `--dart-define` ile ver |

---

# 7. Bulduğum ama düzeltmediğim şeyler

1. **`README.md` ciddi biçimde bayat** — Riverpod, Freezed, drift, "Backend
   şimdilik yok — tamamen yerel" ve bir `build_runner` adımı anlatıyor.
   Hiçbiri bugünkü kodu yansıtmıyor (Supabase + `ChangeNotifier`, codegen yok).
2. **`docs/ios-kurulum.md:95-97` yanlış** — "supabase.json yoksa uygulama demo
   modunda açılır: yerel mock veri" diyor. Mock mod Task 03'te kaldırıldı;
   `main.dart:23-27` `ConfigErrorApp` gösterip duruyor. Bu satır kuruluma yeni
   başlayan birini doğrudan yanıltır.
3. **`docs/task-03-yayin-hazirlik-raporu.md:509`** "3 iş görünmeli" diyor;
   göçler artık **5** cron işi kuruyor (elle eklenecek iki budayıcıyla 7).
4. **Eski projede ölü `push_secret` anahtarı** duruyor — README:135 silinmesini
   söylüyor. Eski projeye dokunmama kararı gereği silinmedi.
5. ~~`tools/ab-results.json` gitignore'da değil.~~ **DÜZELTİLDİ** — bu task'ın
   kendi ölçümlerinin ürettiği dosyaydı, `.gitignore:63`'e eklendi.

---

# 8. Kurulumda gereken ama listede olmayan adımlar

1. **Eklentiler göçlerden ÖNCE açılmalı** — 21. göç `pg_net`, 55. göç `pg_cron`
   istiyor; yoksa o noktada ve sonrasında her şey düşer.
2. **Vault'a `service_role_key` sırrı yazılmalı.** Hiçbir göç yaratmıyor.
   Yoksa `scan-photos-sweep` ve `cleanup-anonymous-daily` cron işleri
   `and exists (…vault…)` koruması yüzünden **sıfır satır eşleştirip BAŞARILI
   raporluyor** ve hiç çalışmıyor.
3. **`app_config.edge_base_url`** — aynı sessiz no-op şekli.
4. **`prune_ai_calls` ve `prune_ad_rewards` için cron işi elle kurulmalı.**
   Task 10'da fonksiyonlar yazıldı, zamanlama hiçbir göçte yok.
5. **`legal_version` ilk kayıttan ÖNCE `1.3` yapılmalı** — yoksa
   `accept_legal_terms()` sessizce `1.0` damgalıyor ve onay defteri değişmez
   olduğu için o damga düzeltilemiyor.
6. **`ad_reward_secret` ile `AD_REWARD_SECRET` gizlisi aynı olmalı** —
   uyuşmazsa her reklam izlenir, hiç hak verilmez, yalnızca Postgres logunda
   bir `warning` kalır.

---

# 9. Erişim jetonunun iptali

| Anahtar | Nereden |
|---|---|
| **Erişim jetonu (PAT)** | Dashboard → sağ üst avatar → **Account Preferences → Access Tokens** → ilgili satır → **Revoke** |
| OpenAI anahtarı | platform.openai.com → API keys → **Revoke** |
| `service_role` anahtarı | Project Settings → API Keys → **Rotate** (döndürülürse `app_config.push_service_key` ve Vault'taki `service_role_key` de güncellenmeli) |
| Veritabanı şifresi | Project Settings → Database → **Reset database password** |

> **Not:** kurulum anahtarları bu görüşme sırasında sohbete de yapıştırıldı.
> İş bitince `service_role` anahtarının ve OpenAI anahtarının döndürülmesi
> yerinde olur.

---

# 10. Devam etmek için gerekenler

1. **Yeni Supabase projesi** (bölge: Frankfurt `eu-central-1` önerilir — hem
   gecikme hem KVKK metnindeki `[Supabase bölge/ülke]` alanı için).
   **Veritabanı şifresi kurulum ekranında belirleniyor, sonradan
   görüntülenemiyor — o an not alınmalı.**
2. Yeni projenin **ref**, **publishable**, **service_role** anahtarları.
3. **Erişim jetonu** — auth ayarları ve edge fonksiyonları için başka yol yok.
4. (İsteğe bağlı) **40 gerçek soru fotoğrafı** — birim maliyet ölçümü ve
   §4.3'teki uydurma oranının ölçülmesi için.
