# Task 13 — Kod tarafının kapanışı

**Dayanak:** `d451e4b` (Task 11 raporu) · **Paketler:** Task 12 onarımı + Task 13 (1-6)
**Yeni göç:** 8 (0088-0096) · **pgTAP:** 37 dosya / 831 iddia · **Mutasyon:** 55
**Değişen:** 115 dosya, +16.638 / −509 satır

---

## 0. Önce şunu söylemek gerekiyor: CI ölüydü

Task 13'ün ön koşulu "Task 12'nin yedi paketi commit edilmiş ve **CI yeşil**"
idi. **İkisi de doğru değildi** ve ikincisinin sebebi tek bir satırdı.

`.github/workflows/ci.yml`, Task 10'un `5feeb02` commit'inden beri **geçersiz
YAML**:

```yaml
- name: "Sınırsız" vaadi kullanıcıya verilmemiş mi
```

YAML'de çift tırnakla **başlayan** bir skalerden sonra düz metin gelemez.
Bozuk bir iş akışı dosyasını GitHub Actions **hiç koşturmaz**. Commit başına
doğrulandı: `2b84ac0` geçerli, `5feeb02` geçersiz.

**Sonuç:** pgTAP süiti, mutasyon kontrolü, statik kapılar ve
`flutter analyze/test` **Task 10'dan Task 13'e kadar hiç çalışmadı.** Task
10'un o commit'te eklediği üç yeni kapı da dâhil — kapıları ekleyen commit,
kapıların tamamını kapattı.

Bu, Task 12'nin yedi kırık noktasının (biri `supabase db reset`i patlatan bir
göç, biri RLS'i atlayan bir RPC) fark edilmeden "commit'e hazır" hâle
gelmesinin **kök nedeni**. Onarıldı ve `tools/check_workflows.py` ile
kalıcı bir kapıya bağlandı; kapı, bozuk tarihsel dosyaya karşı koşturularak
hatayı **yakaladığı doğrulandı**.

> Tavuk-yumurta: bozuk bir `ci.yml` kendi içindeki kontrolü de koşturamaz.
> Betiğin **asıl yeri geliştirme makinesi** (bu depoda Flutter ve Docker yok,
> statik kapılar zaten oradaki tek geri bildirim yolu); `ci.yml`'deki kopya
> yalnızca bir SONRAKİ bozulmayı yakalar.

---

## 1. Task 12'nin yedi kırık noktası (kapsam dışıydı, zorunlu oldu)

Task 12 commit edilmemişti **ve içindeki yedi hata CI'ı kırmızıya düşürürdü** —
üçü `supabase db reset`i tümden durdururdu. Task 13'ün hiçbir testi onlar
düzelmeden koşamazdı, bu yüzden Paket 0 olarak onarıldı ve ayrı commit edildi
(`2ed6e8a`), yanına `docs/task-12-tur7-raporu.md` yazıldı.

Dördü **tek bir fonksiyon yeniden yazımından** çıkıyor ve o dosya kendi
hakkında şunu yazıyordu: *"Gövde 0075'ten **BİREBİR kopyalandı**; başka hiçbir
satır değişmedi."* Bu cümle doğru değildi.

| # | Sorun | Sonuç |
|---|---|---|
| 1 | `ai_state()` OUT sütun sırası değişmiş (`create or replace` ile) | **`db reset` patlıyor** |
| 2 | `ad_rewards_left` ücretsiz/premium dalında hiç atanmıyor | **Ödüllü reklam yolu arayüzde tümüyle ölü** |
| 3 | `ai_next_at` sıfırlama bloğu düşmüş | Ay doluyken yanıltıcı saat |
| 4 | `refund_ai_use`'un `p_capped`'i **istemci kontrolünde** | **Kota ve OpenAI maliyet tavanı deliniyor** |
| 5 | `send_question_to_friends` **RLS'i atlıyor** | **Başkasının sorusu arkadaşlara gönderilebiliyor** |
| 6 | `received_questions` görünümü sütunu **ortaya** ekliyor | **`db reset` patlıyor** |
| 7 | `mutations/36` bayat | Mutasyon koşusu `exit 1` ile duruyor |

İkisi özellikle ağır:

**#4 — maliyet tavanı deliniyordu.** `refund_ai_use(p_call_id, p_capped)`
`authenticated`'a açıktı ve `p_capped` tamamen istemcideydi. PostgREST'e
`{"p_capped": false}` gönderen bir istemci günlük iade tavanını atlayıp kendi
**bütün** çağrılarını iade edebiliyordu; iade edilen satır hem kayan pencereden
hem **aylık cap**'ten düştüğü için sonuç "OpenAI çağrısı yapıldı, kota geri
verildi" oluyordu — yani sert maliyet tavanı diye bir şey kalmıyordu.
Çözüm iki ayrı yüzey (`grant_ad_reward` deseni): tavanlı yol
`authenticated`'a, **tavansız** yol yalnızca `anon` + paylaşılan sır.

**#5 — RLS atlanıyordu.** Fonksiyon `security definer` ve yorumu *"RLS BURADA
ATLANMIYOR"* diyordu. Depo bunun tersini **iki yerde** yazıyor
(`sanctions.sql:517`, `guardian_removal.sql:79-81`) ve hiçbir yerde
`force row level security` yok. Politikanın altı koşulu (arkadaşlık, engel,
askı, anonimlik, **satırın sahipliği**, moderasyon/tarama) hiç
değerlendirilmiyordu ve `p_mistake` keyfi bir uuid olduğu için kullanıcı
**başkasının** sorusunu arkadaşlarına gönderebiliyordu.

---

## 2. Uygulama içi satın alma

### Mimari

**`subscriptions` = defter, `profiles.premium_until` = izdüşüm, tek yazar.**
`user_tier()` → `ai_state()` → `my_daily_state` zinciri kota motorunun sıcak
yolu ve Task 12'de tam orada bir `create or replace` tuzağına düşüldü; abonelik
için o zincire dokunmak bu paketin en riskli hamlesi olurdu. Bu yüzden
`user_tier()`, `ai_state()` ve `consume_ai_use()` **hiç değişmedi**; abonelik
durumu ayrı bir `subscription_state()` fonksiyonundan geliyor ve görünüme
üçüncü kaynak olarak giriyor. Defter ile izdüşümün ayrışamayacağı pgTAP'te
iddia ediliyor.

**Yetkilendirme `grant_ad_reward` (0076) deseninin aynısı.** `apply_subscription`
yalnızca `anon`'a açık, `authenticated`'a **kapalı**; sır `app_config.iap_secret`
(tohumlanmıyor, yoksa abonelik **yazılmıyor**). Hiçbir doğrulamasız fonksiyon
servis rolü istemcisi kurmuyor.

| Konu | Apple | Google Play |
|---|---|---|
| Doğrulama | App Store Server API (`.p8` ES256 JWT) | Play Developer API (servis hesabı, RS256) |
| Bildirim | App Store Server Notifications V2 | RTDN → Pub/Sub → HTTPS push |
| Özel şart | — | **3 gün içinde `acknowledge`**, yoksa Google parayı iade eder |

### Yenileme, iptal, iade — iki katman

Soru "kurulacak mı?" idi. **Kuruldu, ve iki katman olarak:**

1. **`store-notify`** (webhook) — anında yakalıyor. Deponun **ikinci**
   `verify_jwt = false` fonksiyonu; gerekçe `ad-reward`ın aynısı (bildirim
   mağazanın sunucusundan geliyor, kullanıcı JWT'si yok). Yanıt politikası da
   aynı: karara bağlanmış → 200, bağlanmamış → 503.
2. **`reconcile-subscriptions`** (gecelik cron) — webhook'un **sessizce**
   çalışmamasına karşı. Konsolda geri çağrı adresi yanlış girilmiş olabilir,
   Pub/Sub aboneliği silinmiş olabilir, bir bildirim kaybolmuş olabilir;
   hiçbirinde bir hata görünmez. Mutabakat iadeyi en geç 24 saatte kapatıyor.

**Kurulmasaydı riski:** iptal eden kullanıcı süre sonuna kadar premium kalırdı
(kabul edilebilir); **iade alan kullanıcı premium kalmaya devam ederdi**
(kabul edilemez).

**Bir tasarım kararı daha:** `store-notify` bildirimin **içeriğine güvenmiyor**.
Yükten yalnızca makbuz kimliği okunuyor, durum mağazanın kendi API'sinden
yeniden soruluyor. Böylece Apple'ın `x5c` zincir doğrulaması **yazılmadan** da
sahte bir bildirim abonelik **değiştiremiyor**. Zincir doğrulaması bilinçli
olarak yazılmadı: `ad-reward/ssv.ts` 200 gerçek imzayla sınanmıştı, burada
sınayacak imza yok çünkü hesap yok — ve sınanmamış kriptografiye güvenmek bu
depoda kabul edilmiyor.

### Sabit fiyat kaldırıldı — yayın engeli eklenti gelmeden kapandı

`plus_plans.dart` Task 10'dan beri sabit TL yer tutucuları taşıyordu ve dosyanın
kendi yorumu bunu **"YAYIN ENGELİ"** ilan ediyordu — ama o fiyatlar hem
paywall'da hem **hak duvarında canlı çiziliyordu**. Artık fiyatın tek kaynağı
mağaza yanıtı; yanıt yoksa fiyat içeren **hiçbir** metin çizilmiyor.

CI kapısı da sertleşti: `plus_plans.dart` muafiyeti **kalktı**, `lib/` içinde
hiçbir dosyada sabit para birimi yazamaz. Kapı kendini sınıyor.

### Ne yapılamadı: `in_app_purchase` paketi

**Eklenemedi.** `pubspec.lock` pub.dev'den gelen sha256 özetlerini taşıyor ve
bu makinede Flutter/Dart **yok**; kilit dosyası üretilemiyor. CI'da
`git diff --exit-code pubspec.lock` kapısı olduğu için bağımlılığı kilitsiz
eklemek işi **kesin** kırmızıya düşürürdü.

Bunun yerine katmanın **tamamı** yazıldı (`lib/services/purchase_service.dart`)
ve mağazaya bağlanan tek parça `PurchaseService` gerçeklemesi bırakıldı.
Bugünkü davranış dürüst: ürün yok → `isConfigured` false → düğme görünür
biçimde devre dışı, "geri yükle"/"yönet" satırları hiç çizilmiyor, fiyat yok.

**Eklenti gelince yapılacaklar (§8.1)** sırayla yazıldı.

---

## 3. Lig — dört bulgunun dördü de kapandı

**Kohort çakışması ilk tahminden kötüydü.** Kohort *tavanı* 30; kademe
nüfusunun 30'a bölümünden **artan grup** düzenli olarak 6-9 kişilik oluyor ve o
aralıkta terfi (ilk 5) ile düşme (son 5) kesişiyor. Üç ayrı zarar:

* İki **ayrı** UPDATE'ti ve ikincisi birincinin yazdığı değeri okuyordu → orta
  kademelerde hak edilmiş terfi **sessizce iptal** oluyordu.
* Terfi `elmas`ta tavanlı ama düşme `elmas→zumrut`: 6 kişilik elmas kohortunda
  **2. sıradaki oyuncu düşüyordu**.
* `on_friend_milestone` terfi UPDATE'inde ateşlenip arkadaşlara "yükseldi"
  push'u yolluyor, sonra aynı işlemde kullanıcı geri iniyordu.

**Ve arayüz sunucuyla çelişiyordu:** `league_screen.dart` düşme çizgisini
yalnızca `total >= 11` iken çiziyordu. 7 kişilik kohortta kullanıcı "düşme
bölgesinde değilim" görüp hafta sonunda düşüyordu. Yeni kural (`>= 11`) iki
tarafı **aynı** kurala getiriyor.

Diğer üçü: tek advisory kilit anahtarı + `unique (user_id, week_start)` (çift
kohort), engel maskelemesi (satır kalıyor, kimlik gidiyor — düşürmek sıralamayı
bozar ve **engeli ele verir**), ve `league_result` diriltildi. O tür **iki
yerde birden** ölüydü: tetikleyici yoktu **ve** `send-push`in beyaz listesinde
değildi.

**Sonuç bildirimi settle'dan ayrıldı — gerekçe saat.** Haftalık devir Pazartesi
00:05 Istanbul'da koşuyor ve `send_push`te sessiz aralık yok; sonucu settle
içinde göndermek 13-18 yaş kitlesine **gece yarısı** bildirim atmak olurdu.
Ayrı bir iş 09:00'da gönderiyor.

---

## 4. Bakım, kapatılan yüzeyler, zorlanan yaptırımlar

| Ne | Durum |
|---|---|
| `prune_ai_calls` / `prune_ad_rewards` cron'u | ✅ kuruldu (`ledger-prune-daily`). **Bu bir metin-kod uyuşmazlığıydı:** hukuki metin 92 günlük saklama *beyan ediyordu*, defterler süresiz büyüyordu |
| `question_sends` DELETE | ✅ kapatıldı. "Dismiss ile moderasyon izini koru" kararı veri katmanında aşılıyordu |
| Havuz sunucu yüzeyi | ✅ kapatıldı (§4.1) |
| `are_friends` engel körü | ✅ kök düzeltme yapıldı |
| `istanbul_week()` | ✅ eklendi; **yürürlükteki** kopyalar indirildi |
| Yeni kullanıcı düşme koruması | ✅ ilk iki hafta |
| Anonim tespitinin yedek ölçütü | ✅ `phone` de soruluyor, uyarı sertleşti |
| `ff_ad_reward` | ✅ **ölü bayraktı**, iki katmanda bağlandı |
| `ff_pair_streak` | ✅ sunucuya indi (RPC + cron) |
| "`app_config`'e 0 yaz, kapansın" | ✅ **yanlıştı**, düzeltildi |
| Askı ↔ AI tüketimi | ✅ askı artık tüketimi durduruyor |

### 4.1 Havuz: arayüzsüz bir gizlilik ve XP açığı

Havuz Task 02'de arşive alındı ama **sunucu kullanıcıya açık kaldı**:

* `mistakes.is_public` INSERT ile yazılabiliyordu ve `public_questions` görünümü
  `is_public and moderation='ok' and photo_scan='clear'` koşullarıyla **tüm
  oturumlu kullanıcılara** açık; `moderation` varsayılanı `'ok'`. Yani tek bir
  PostgREST INSERT'i, kullanıcının kendi soru **fotoğrafını** takma adıyla
  yayınlamaya yetiyordu — ve bunu yapan bir arayüz olmadığı için **hiçbir onay
  defteri kaydı oluşmuyordu** (`setShareConsent`'in istemcide tek çağıranı yok).
* `submit_pool_answer` doğru cevapta **10 XP + seri** veriyordu. İki hesapla
  (biri paylaşır, diğeri çözer) sıralama şişirilebiliyordu — Kullanım Koşulları
  §6'nın "oyunlaştırma mekanizmalarını hile ile manipüle etmek" yasağı **veri
  katmanında zorlanmıyordu**.

Kapatıldı; fonksiyonlar düşürülmedi (havuz v2'de dönerse geri açma tek göç).
Hukuki metinlerdeki **A-10 bayrağı kapandı**.

### 4.2 Tersine çevrilen üç iddia

Yeşil yanan ama artık var olmayan bir dünyayı doğrulayan üç test düzeltildi:

* `020`: *"`is_public` insert edilebilir (paylaşım opt-in'i **ekleme
  ekranında**)"* — o ekran yok.
* `060`: `set_question_sharing` çağrılabiliyor iddiaları.
* `140`: *"kohort ilk 5 ile son 5'i birlikte barındıracak kadar büyük"* —
  kohortun **tavanını** ölçüyordu, üye sayısını değil; yani çakışmanın
  kapandığına dair **yanlış güvence** veriyordu.

---

## 5. Bütünlük denetimi

**Yöntem:** on dört kollu paralel keşif (IAP istemci/sunucu/platform, lig
çekirdek/okuma, bildirim, pgTAP-mutasyon, bakım, dokümantasyon, hukuki metin ve
dört bütünlük ekseni). Her bulgu `dosya:satır` ile geri doğrulandı.

### 5.1 Düzeltilenler

CI'ın ölü olması · Task 12'nin yedi kırık noktası · lig dört bulgu ·
havuz sunucu yüzeyi · `question_sends` DELETE · budama cron'u ·
`are_friends` engel körlüğü · `ff_ad_reward` ölü bayrak · `ff_pair_streak`
yalnızca istemcide · sıfır limitin kapatmaması · askının AI tüketimini
durdurmaması · `start_pair_streak`in askıyı sormaması ·
`BatchCaptureScreen`in kendi kapısının olmaması · iadenin kullanıcıya hiç
gösterilmemesi · ölü `resets_at` alanı · ölü `inPool` getter'ı ·
paywall'ın üçüncü girişinin uydurma rakamlarla açılması · sabit fiyat ·
LICENSE yokluğu · lisans ekranı yokluğu · README'nin %70'i · `.env.example` ·
beş yerdeki "demo modu" · `android.yml`'in koşulsuz imza notu · `.aab`
yokluğu · iOS CI yokluğu · bayat yorumlar (`ci.yml` kalp gerekçesi,
`supabase_config`, `social_repository` "15 kişilik grup", `submission_queue`
kapsamı, `kimo_pose.chestOpen`, `features.gemsVisible` gerekçesi,
`cleanup-anonymous` "zamanlayıcı yok") · `task-03` runbook'u ·
hukuki metinlerdeki sekiz bayat madde.

### 5.2 Elenen iki iddia (ajan yanılgısı)

* *"`ensure_league_membership` anonim/sistem kontrolü yapmıyor"* — **yanlış.**
  Ajan **tarihsel** bir gövdeye bakmış; yürürlükteki tanım süzgeci taşıyor.
* *"Persona matrisinde `akademisyen` boşluğu var"* — **yanlış.** Persona Task
  04'te dörde indi, matris **tam**: 10 tür × 4 persona × 5 varyant = 200 satır.

### 5.3 Karar bekleyenler

1. **Havuz v2'de gerçekten dönecek mi?** Dönmeyecekse `lib/_archive/`,
   `submit_pool_answer` ve `question_attempts` tümden düşürülebilir.
2. **Elmas v2'de sunucu bayrağıyla mı açılacak?** Şimdilik derleme-zamanı
   bayrağı olarak bırakıldı ve gerekçesi koda yazıldı (kill switch değil, ürün
   kararı).
3. **`push_kinds` ↔ `ALLOWED_KINDS` ayrışması makineyle korunsun mu?** Tür
   listesi veritabanında 10, Edge Function'da 6. Yeni bir tür eklenirken ikinci
   yer unutulursa tek iz fonksiyon günlüğü.
4. **Bildirim metinlerinin iki kopyası** (`push_lines` + `notification_lines.dart`)
   — kasıtlı yedek, ama hiçbir yerde yazılı değil.
5. **`received_questions`'ın engel süzgeci tek yönlü.** Çift yönlü yapmak
   engellenenin kutusunu aniden boşaltır ve **engeli ele verebilir** — yani
   mevcut hâl bilinçli olabilir. Ne gerekçe ne test var.
6. **Engelleme ortak seri satırını silsin mi?** Bugün gizleniyor ama
   `pair_streak_max` kotasını tüketiyor: 3 partnerini engellemiş kullanıcı yeni
   seri **başlatamıyor ve sebebini göremiyor**.
7. **Sosyal yüzey ve lig için de bayrak isteniyor mu?** Sekiz riskli yüzeyden
   dördünde bayrak var. Bunlar küçüklere açık ve moderasyon riski en yüksek
   yüzeyler.
8. **Küçük kohortta terfi enflasyonu.** `n < 11`'de kimse düşmüyor ama terfi
   sürüyor; dört kişilik iç testte herkes ~5 haftada elmasa çıkar.
9. **`ff_pair_streak` varsayılanı `false`** — Tur 7 · n6'nın bütün istemci
   yüzeyi ilk sürümde hiç görünmeyecek. Kasıtlı mı?
10. **Askıdaki kullanıcı AI analizi yapabilmeli mi?** Artık **yapamıyor**;
    "okuma açık kalır, üretim kapanır" kuralının bu yorumu onaylanmalı. Ayrıca
    askı ekranı istemcide **kapatılabiliyor** — bu bilinçli mi?
11. **Persona ton tarifi** (`personaTone` + dört `mascotTone*`) hiçbir ekranda
    çizilmiyor; karta eklensin mi, silinsin mi? Ve arkadaş yüzeylerinde
    arkadaşın personası gösterilsin mi (`my_pair_streaks()` `mascot`
    döndürüyor, istemci okumuyor)?
12. **`confetti` bağımlılığının tek kullanıcısı `lib/_archive/`.**
    Kaldırılması `pubspec.lock`u değiştiriyor, yani bu makinede yapılamıyor.

---

## 6. Yeni kalıcı kapılar

Bu task'ta üç kapı eklendi ve **üçü de bozuk girdiye karşı koşturularak
doğrulandı**:

| Kapı | Ne yakalıyor | Kanıt |
|---|---|---|
| `check_workflows.py` | Ayrıştırılamayan iş akışı dosyası | Tarihsel `ci.yml`'e karşı koştu, **yakaladı** |
| `check_sql.py` #5/#6 | `create or replace` ile OUT sütunu / görünüm sütunu değiştirme | Düzeltme öncesi ağaca karşı koştu, **ikisini de yakaladı** |
| `check_sql.py` #7 | Bayat mutasyon `@UNDO` gövdeleri | Elle bozulan bir `@UNDO`'ya karşı koştu, **yakaladı** |

**#5 ve #7 bu task'ın içinde üç kez iş gördü:** `feature_flags()`e `ff_iap`
eklerken `create or replace` yazdığımı, mutasyon 39 ve 40'ın Paket 0'da
bayatladığını, mutasyon 36'nın Paket 5'te bayatladığını yakaladılar.

> **Ve bir dürüstlük kaydı:** Paket 5'te `consume_ai_use`, `ai_state` ve
> `start_pair_streak` gövdelerini **elle yeniden yazdım** ve üçü de sessizce
> farklı çıktı — `start_pair_streak`ten "iki yönde çözülmüş gönderim" şartı ve
> ilk seri değerleri, `consume_ai_use`tan `photo_sha256` ile `from_reward`
> düşmüştü. Yani Task 12'nin tam olarak yaptığı hatayı tekrarladım. Üçü de
> göçteki **orijinal gövdeden yeniden üretildi** ve diff'leri yalnızca
> amaçlanan satırları gösteriyor. Bu sınıf hata için hâlâ otomatik bir kapı
> yok — göç gövdeleri arası karşılaştırma yazılabilir, karar bekleyenlere
> eklenmedi çünkü `check_sql.py` #7 mutasyon tarafını zaten kapatıyor.

---

## 7. Hukuki metinler ve mağaza formları

**Sürüm 1.3 → 1.4.** Değişenler:

* **Kullanım Koşulları §13 yeniden yazıldı.** "Satın alma ŞU AN YOKTUR"
  kalktı; yenileme, iptal, **iade**, deneme ve cayma hakkı gerçek kurallarıyla
  yazıldı. **Fiyat metne yazılmadı, bilinçli** — Apple 3.1.2 ve Play politikası
  fiyatın mağazanın yerelleştirilmiş fiyatı olmasını şart koşuyor.
  "Soru kaydetme, **tekli çekim** ve tekrar yapma her zaman ücretsiz" taahhüdü
  ARB'deki cümleyle hizalandı.
* **§1.1 envanteri:** `subscriptions` ve `pair_streaks` satırları. **Ödeme
  aracı bilgisi toplanmıyor** notu.
* **§1.11:** "ödeme yok" iddiası **düştü**.
* **§2:** A-10 (havuz) **kapandı**.
* **`hesap-silme-sayfasi.md`:** `[uygulama adı]` yer tutucusu dolduruldu ve
  **Gizlilik §8 ile çelişen** "tek tek silme yok" ifadesi düzeltildi. Bu sayfa
  Play Console'a giriliyor ve mağaza beyan-gerçek karşılaştırması tam olarak bu
  tür çelişkiyi arıyor.

### Mağaza formlarında değişen cevaplar

| Form | Alan | Eski | Yeni |
|---|---|---|---|
| App Store Connect · App Privacy | **Purchases → Purchase History** | ❌ Hayır | ✅ **Evet** · kimliğe bağlı · App Functionality |
| Google Play · Veri Güvenliği | **Satın alma geçmişi** | ❌ | ✅ Toplanıyor · paylaşılmıyor · Uygulama işlevselliği |
| İkisi | **Finansal bilgiler** | ❌ | ❌ **değişmedi** — kart bilgisi bize hiç ulaşmıyor |

---

## 8. Dağıtım: atlanırsa **sessizce** çalışmayacak adımlar

Hepsi fail-closed ya da no-op — yani hata vermiyorlar, sadece çalışmıyorlar.

| Adım | Atlanırsa |
|---|---|
| `app_config.iap_secret` + edge gizlisi `IAP_SECRET` | **Abonelik hiç yazılmaz.** Kullanıcı öder, premium olmaz |
| `app_config.ai_refund_secret` + `AI_REFUND_SECRET` | Altyapı kaynaklı iadeler hiç verilmez (kullanıcı hakkını kaybeder) |
| `APPLE_IAP_KEY` / `_KEY_ID` / `_ISSUER_ID` / `APPLE_BUNDLE_ID` | iOS doğrulaması 503 döner |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` + `ANDROID_PACKAGE_NAME` | Android doğrulaması 503 döner; **Play 3 gün sonra parayı iade eder** (acknowledge yapılamaz) |
| ASSN V2 adresi (App Store Connect) | İade **yakalanmaz** — yalnızca gecelik mutabakat kurtarır |
| Play RTDN → Pub/Sub → `store-notify` | Aynı |
| `app_config.edge_base_url` + Vault `service_role_key` | `subscriptions-reconcile`, `scan-photos-sweep`, `cleanup-anonymous-daily` **sessizce no-op** |
| Yeni cron'lar (`db reset` ile gelir) | `ledger-prune-daily` yoksa 92 gün saklama beyanı karşılanmaz |
| **Görünüm + istemci BİRLİKTE** dağıtılmalı | `my_daily_state` yeni sütunlar kazandı |
| `app_config.legal_version` = `1.4` | **EN SONA.** Onay defteri düzeltilemez (Task 11 §5.1) |
| `ff_multi_capture` | IAP yayına yetişmezse **kapalı bırakılmalı** — satılamayan bir özelliğin kilidi gösterilmemeli |

Cron işleri (9): `league-weekly-rollover`, `league-results-push`,
`scan-photos-sweep`, `cleanup-anonymous-daily`, `signup-throttle-prune`,
`ai-cache-prune`, `pair-streak-daily`, `ledger-prune-daily`,
`subscriptions-reconcile`.

### 8.1 `in_app_purchase` eklenirken (tek oturumluk iş)

1. `flutter pub add in_app_purchase` → `pubspec.lock` **aynı commit'te**.
2. `android/app/src/main/AndroidManifest.xml`'e
   `<uses-permission android:name="com.android.vending.BILLING"/>` —
   eklenti merge etse de **açıkça beyan** (depo kuralı, Task 03 bulgu 7.2).
3. `android/app/build.gradle.kts`'te `minSdk`/`targetSdk` **açık sayılarla**
   sabitlensin (bugün Flutter varsayılanına bırakılmış).
4. Xcode → Runner hedefine `+ Capability → In-App Purchase`; entitlements
   dosyasını **Xcode üretsin** (push reçetesiyle aynı).
5. `ios/Runner/Configuration.storekit` + Runner şemasına bağlama — hesap
   beklerken bile simülatörde akış koşulur.
6. `StoreKitPurchaseService implements PurchaseService` yazılsın ve
   `Purchases.instance` `main.dart`'ta ona çevrilsin. **Değişecek tek satır.**
7. `flutter build apk --release` ile **gerçek** bir satın alma akışı denensin
   (R8/proguard kırılması `flutter_local_notifications`'ta bir kez yaşandı).

---

## 9. Mağaza taraflarında bizim yapmamız gerekenler — sırayla

**Apple**
1. Apple Developer Program üyeliği (yıllık ücretli).
2. **Anlaşmalar, Vergi ve Bankacılık** → *Paid Apps* sözleşmesi; banka hesabı
   ve vergi formları. **Bu tamamlanmadan IAP ürünü oluşturulamaz.**
3. App Store Connect → uygulama kaydı (bundle `com.stratejico.kimo`).
4. **Abonelik grubu** oluştur → içine iki ürün: `kimo_plus_yearly`,
   `kimo_plus_monthly`. **Aynı grupta olmaları şart**, aksi hâlde kullanıcı iki
   aboneliğe birden sahip olabilir.
5. Türkiye fiyat kademesi; **7 günlük Introductory Offer → Free Trial**,
   "yeni aboneler" için.
6. App Store Server API anahtarı (`.p8`) + Key ID + Issuer ID → edge gizlisi.
7. **App Store Server Notifications V2** → URL: `<edge_base_url>/store-notify`.
8. App Privacy formu (§7) · yaş derecelendirmesi · hukuki metin adresleri.

**Google**
1. Play Console hesabı (tek seferlik ücret).
2. **Ödeme profili** + vergi bilgileri. Bunsuz abonelik ürünü oluşturulamaz.
3. Uygulama kaydı; **`.aab` yükle** (APK kabul edilmiyor).
4. Abonelik ürünü + **iki base plan** (aylık/yıllık) + `oneTimeOnly` 7 günlük
   deneme teklifi.
5. Servis hesabı (Play Developer API yetkisiyle) → JSON → edge gizlisi.
6. **RTDN** → Pub/Sub konusu → HTTPS push aboneliği:
   `<edge_base_url>/store-notify`.
7. Veri Güvenliği formu (§7) · "App content → Ads" beyanı · hesap silme adresi.

**Ortak:** hukuki metinlerin bir alan adında yayınlanması ve
`supabase.json`'daki `LEGAL_*` / `SUPPORT_EMAIL` alanlarının doldurulması.

---

## 10. Hesap bekleyen işler

| Hesap | Gelince yapılacak |
|---|---|
| **Apple Developer** | IAP capability · abonelik grubu ve iki ürün · deneme teklifi · `.p8` anahtarı · ASSN V2 adresi · APNs anahtarı · **iOS'un ilk kez derlenmesi** |
| **Play Console** | Ödeme profili · abonelik + iki base plan · servis hesabı · RTDN/Pub/Sub · `.aab` yükleme · Veri Güvenliği formu |
| **AdMob** | SSV geri çağrı adresi · test cihazı · `app-ads.txt` (alan adının **kökünde**) |
| **Firebase** | `FIREBASE_SERVICE_ACCOUNT` gizlisi |
| **Alan adı** | `LEGAL_*` ve `SUPPORT_EMAIL` → `supabase.json`; hukuki metinlerin yayını |

---

## 11. Kapsam dışında değiştirmek zorunda kaldıklarım

1. **Task 12'nin yedi kırık noktası** (§1). Ön koşul yeşil olmadığı için
   zorunluydu; Task 13'ün hiçbir testi onlar düzelmeden koşamazdı.
2. **`ci.yml`'in YAML hatası** (§0). Bu düzeltilmeden Task 13'ün yazdığı
   hiçbir kapı, test ve mutasyon **hiç çalışmayacaktı**.
3. **`docs/task-12-tur7-raporu.md`** yazıldı — depo her task için bir rapor
   tutuyor ve o halka eksikti.
4. **Üç bayat mutasyon** (36, 39, 40) yeniden üretildi.

---

## 12. Emin olmadıklarım

1. **IAP kodunun tamamı çalıştırılmadı.** Ücretli Apple Developer ve Play
   Console hesapları yok; ne sandbox satın alma ne gerçek bir mağaza API yanıtı
   görüldü. `_shared/stores.ts`'in alan adları **belgelerden** yazıldı. Bu,
   deponun en çok kaçındığı durum ve açıkça söylüyorum.
2. **Apple `x5c` zincir doğrulaması yazılmadı** (§2). Tasarım buna
   dayanmıyor — durum mağaza API'sinden yeniden sorulıyor — ama bir sonraki
   turda yazılmalı.
3. **pgTAP ve mutasyon süiti bu makinede koşmadı.** Docker/psql/Supabase CLI
   yok. 831 iddianın **hiçbiri** yerel olarak çalıştırılmadı; yalnızca statik
   kapılar (plan sayısı, dolar-tırnak dengesi, yetki, OUT sütunu, bayat
   `@UNDO`) yerelde temiz.
4. **`flutter analyze` ve `flutter test` koşmadı.** Flutter yok. Dart
   değişiklikleri `check_symbols.py` + `check_imports.py` ile sınırlı biçimde
   doğrulandı; tip hataları ancak CI'da görünür.
5. **`settle_past_leagues`'in eşzamanlı çift çağrısı** tek işlemli pgTAP ile
   kanıtlanamıyor; kilit doğrudan savunma amaçlı eklendi.
6. **`istanbul_week()` görünümlerde `stable` fonksiyon çağrısı** — sorgu
   planına etkisi ölçülemedi (Docker yok).
7. **`are_friends` değişikliğinin yüzeyi geniş.** RLS politikalarında ve altı
   fonksiyonda kullanılıyor; `profiles_public.avatar_path` ve `my_pair_streaks`
   davranışını da (istenen yönde) değiştiriyor.
8. **`subscriptions` defteri ile `premium_until` izdüşümü** arasındaki ayrım
   (§2) risk temelli bir seçim. Alternatif — `user_tier()`'ı doğrudan defterden
   okutmak — daha "tek kaynak" ama kota motorunun sıcak yoluna dokunuyor.
   Karşı görüş varsa şimdi söylenmeli.
