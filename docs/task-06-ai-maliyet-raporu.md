# Task 06 — AI maliyet kontrolü raporu

Durum: **P1b, P5 ve P7 yazıldı ve commit edildi. P1, P2, P3 ÖLÇÜME BAĞLI ve
başlamadı.**

Bu paket iki parçaya ayrıldı çünkü ortada ölçülmemiş bir sayı var: çağrı başına
birim maliyet. Kota rakamları (pencere, aylık cap, premium cap) doğrudan o sayıdan
türüyor ve tahminle sabitlenirse yanlış yere kilitlenir. Ölçüme bağlı olmayan her
şey bu turda yapıldı; ölçüm gelince kalanı tek hamlede tamamlanacak.

**Doğrulama durumu.** Yerelde koşan: `flutter analyze` (yalnızca Task 04'ten
kalan bir deprecation `info`), `flutter test` (146/146), `check_sql` (67 göç,
`plan(n)` sayıları iddia sayılarıyla birebir), `check_imports`, `check_symbols`,
ve edge fonksiyonu için `node --check`. **Yerelde KOŞMAYAN: pgTAP süiti ve
mutasyon kontrolü** — bu makinede Docker ve Supabase CLI yok
(`docker` → bulunamadı). İki yeni test dosyası (42 iddia) ve dört yeni mutasyon
ilk CI koşusunda doğrulanacak. Aşağıda her başlığın altında hangi kontrolün
gerçekten koştuğu tek tek yazıyor.

---

## Özet

| | Önce | Sonra |
|---|---|---|
| İptal edildiğinde | Hak yanıyor, sonuç çöpe gidiyor, ekranda kaydetme düğmesi YOK | Sonuç saklanıyor, "Devam et" düğmesi duruyor |
| Aynı fotoğraf ikinci kez | İkinci kez ödeniyor | Önbellekten geliyor, kota bile düşmüyor |
| Sahte kayıt (IP/gün) | 8.640 hesap | **300 hesap** |
| IP kaydı | Uygulamaya hiç ulaşmıyor | `sha256(tuz ‖ ip)`, 7 gün saklanıyor |
| E-posta doğrulaması | Akışta bir adım, SMTP bekliyor | Kaldırıldı; katman ayrımı tek bayrakta |
| Başarısız analizde kalan hak | Arayüzde eski sayı kalıyor | Güncelleniyor |
| Birim maliyet | Ölçülmemiş | **Hâlâ ölçülmemiş** — araçlar hazır |

---

## Ne yapıldı

### 1. İptal çıkmazı — "kaydetme yolu asla kapanmaz" değişmezi delikti

**Bulgu.** Kullanıcı analiz sırasında "Vazgeç"e bastığında istek **iptal
edilmiyor**: `supabase_flutter`'ın `functions.invoke` API'si iptal kabul etmiyor,
yani istek sunucuda tamamlanıyor, `consume_ai_use` hakkı çoktan yemiş oluyor ve
OpenAI faturası kesiliyor. Kod bunu biliyordu (`_cancelled` bayrağı) ve gelen
sonucu **sessizce atıyordu**. Dahası: `_bytes != null` olduğu için `_pickActions`
artık çizilmiyordu ve ekranda kaydetmeye/elle girişe götüren **hiçbir düğme**
kalmıyordu — tek çıkış "Yeniden çek", yani ikinci bir can.

**Ne yapıldı.** `_pendingAnalysis` alanı: sonuç artık **her zaman** saklanıyor
(iptalde de, onay ekranından geri dönüşte de). Fotoğraf ekranda duruyorken
"Devam et" düğmesi çiziliyor ve saklanan sonuçla onay ekranına gidiyor. Yeni
fotoğraf saklanan sonucu geçersiz kılıyor.

**Neden bu yaklaşım.** Sonucu atmak yerine saklamak, hakkın zaten harcandığı
gerçeğiyle uyumlu tek davranış. Yeni bir l10n dizesi gerekmedi — mevcut
`actionContinue` semantik olarak doğru.

**Nasıl doğrulandı.** `flutter analyze` temiz. Bu dalın widget testi YOK; uçtan
uca elle doğrulama listesi aşağıda.

### 2. Fotoğraf hash'i sonuç önbelleği — sunucuda, kotadan önce

**Bulgu.** Aynı fotoğraf iki kez gönderilirse iki kez ödeniyordu. Ne bellekte ne
veritabanında hiçbir önbellek yoktu.

**Ne yapıldı** (`0060`). `ai_result_cache` tablosu + `ai_cache_get` /
`ai_cache_put` definer fonksiyonları + 48 saatlik budama cron'u. Edge fonksiyonu
artık fotoğrafın SHA-256'sını hesaplayıp **kotadan önce** önbelleğe bakıyor;
isabet varsa `consume_ai_use` **hiç çağrılmıyor** ve OpenAI'ya gidilmiyor.

**Neden bu yaklaşım — üç karar:**

1. **Kontrol kotadan önce.** Amaç ücretin *çıkmaması*, sonradan iade edilmesi
   değil. Kotadan sonra kontrol etmek hakkı yine yakardı.
2. **Hash sunucuda.** İstemciye `crypto` bağımlılığı eklemekten kaçınmak ikincil
   gerekçe (depo tek kullanım için bağımlılık eklemiyor; `submission_queue`'daki
   elle UUID üretimi emsal). Asıl gerekçe: istemcinin bildirdiği bir hash'e
   güvenmek, başkasının sonucunu çekmeye çalışmak için yüzey açardı. Deno'nun
   `crypto.subtle`'ı zaten var.
3. **Kapsam kullanıcıya kilitli.** Küresel bir önbellek çok daha fazla tasarruf
   ederdi — aynı test kitabı sorusu binlerce kez çekiliyor olabilir. *Reddedildi:*
   bir kullanıcı, elindeki fotoğrafın başkası tarafından analiz edilip
   edilmediğini ölçebilirdi. Tasarruf o yüzeye değmez.

Okunamayan fotoğraflar da önbelleğe giriyor (aynı bulanık kare ikinci kez
ücretlenmesin). Önbellek hatası analizi **durdurmuyor** — normal yola düşülüyor —
ama sessiz de değil, teşhis sunucu günlüğüne yazılıyor.

**Nasıl doğrulandı.** `check_sql` temiz, `node --check` ile edge sözdizimi.
pgTAP `260_ai_cache.sql` (18 iddia) **CI'da koşacak**: yapı (tablo hiçbir
uygulama rolüne açık değil), isabet, **kapsam sızmıyor**, TTL, bozuk hash
gürültüyle reddediliyor. Mutasyon `16` yapıyı, `17` TTL davranışını hedefliyor.

### 3. Kayıt hız sınırı — doğrulama kalkınca açılan deliğin karşılığı

**Bulgu.** E-posta doğrulaması, sahte hesabın maliyetini "gerçek bir posta
kutusu"na bağlayan tek şeydi. Kalkınca e-posta alanı bir metin kutusundan ibaret
kalıyor ve Supabase'in kendi tabanı IP başına 5 dakikada 30 kayda izin veriyor
(**günde 8.640**).

Bugünkü canlı yapılandırmayla (kota 5/gün, `gpt-4o-mini` ≈ $0,0044/çağrı) tek
IP'nin **birinci** günündeki değeri: 8.640 × 5 × $0,0044 ≈ **$190**. Hesaplar
kalıcı olduğu için stok her gün 8.640 artıyordu.

**Ne yapıldı** (`0058`). `before_user_created` auth kancası. IP başına **saatte
60, günde 300** (ayrı kovalar: `anon` / `signup`). Aynı hesapla yeni kimlik
üretme hızı **29 kat** düşüyor: 8.640 → 300/gün/IP.

**Neden bu yaklaşım:**

- **IP'ye buradan ulaşılıyor, başka hiçbir yerden.** Kancanın payload'ı
  `metadata.ip_address` taşıyor; depoda IP'ye erişen başka tek bir satır yok.
- **IP ham saklanmıyor:** `sha256(app_config.signup_ip_salt ‖ ip)`, 7 günde
  budanıyor. KVKK gerekçesi göç yorumunda.
- **Cömert, çünkü CGNAT.** Kota tarafında IP boyutunu *reddetmiştik*: TR'de
  mobil operatörler ve okul/yurt ağları tek IP'nin arkasında olabiliyor. Kayıt
  tarafında kabul ediyoruz çünkü alternatif yok ve 300/gün bir sınıfın tamamını
  karşılar. Rakamlar `app_config`'te — göç gerekmeden gevşetilebilir.
- **FAIL-OPEN, sessiz değil.** Tuz girilmemişse ya da beklenmedik bir hata
  olursa kayıt **geçiyor** ve sunucu günlüğüne uyarı yazılıyor. Bu kanca kayıt
  akışının önünde duruyor; yanlış yapılandırılmış bir ortamda kaydı tamamen
  kesmek, sınırın önlediği her şeyden pahalı.
- **`SECURITY DEFINER`.** Supabase'in örneği kullanmıyor ama orada kanca kendi
  tablosunu okuyor ve o tabloya `supabase_auth_admin` yetkisi veriliyor. Bizde
  okunanlardan biri `app_config` — servis rolü anahtarı orada duruyor. Auth
  yöneticisine o tabloyu açmaktansa erişimi fonksiyonun içinde tuttuk.
- **Tek kullanımlık alan adı reddi duruyor ama zayıf.** Doğrulama olmadığı için
  posta kutusu gerekmiyor; asıl işi hız sınırı yapıyor. Ucuz olduğu için kaldı.

**Kararlı durumu bağlamıyor.** Saldırgan hesapları biriktirip bekleyebilir; onu
bağlayan tek şey cihaz sınırı ve o bilinçle ertelendi (tetiği ölçüm). Bu kancanın
işi, ölçeklenen fren devreye girene kadar geçen süreyi ucuzlatmak.

**Nasıl doğrulandı.** `check_sql` temiz. pgTAP `250_signup_throttle.sql`
(24 iddia) **CI'da**: sayaç ve kanca hiçbir uygulama rolüne kapalı, kanca
`supabase_auth_admin`'e açık, limit gerçekten kesiyor, kovalar ayrı, tuz yokken
fail-open, IP 32 baytlık özet. Mutasyon `14` yetki, `15` davranış iddialarını
hedefliyor.

### 4. E-posta doğrulaması kaldırıldı

**Ne yapıldı.** Karşılama akışından `_Step.verify` çıkarıldı,
`email_verify_step.dart` silindi, "kaldığı yerden doğrulama" dalı kalktı,
`auth_repository`'de yalnız o adımın kullandığı dört üye silindi, 11 ARB anahtarı
kaldırıldı. `config.toml`'a kararın gerekçesi yazıldı. `0057` göçü
`stale_anonymous_users`'ın "askıdaki dönüşümü esirge" dalının artık hiç
tetiklenmediğini kayda geçiriyor.

**Neden bu yaklaşım.** Katman ayrımı böylece tek bayrağa iniyor: onay kapalıyken
`updateUser` anında tamamlanıyor ve `profiles.is_anonymous` kayıt anında düşüyor.
Yeni sütun gerekmiyor.

**KORUNAN — bilinçli.** Giriş ekranındaki `email_not_confirmed` dalı ve
`resendSignUp` **duruyor**. Üretim Dashboard'ında doğrulamanın kapalı olduğu
henüz teyit edilmedi (`config.toml` yalnızca yerel geliştirmeyi yapılandırır);
o dal, hesabı doğrulanmamış durumda kalmış birinin tek kaçış yolu. Teyit gelince
ayrıca kaldırılabilir.

**Nasıl doğrulandı.** `flutter analyze` + 146 test yeşil, `check_sql` temiz.

### 5. Kalan hak başarısız analizde de güncelleniyor

**Bulgu.** `analyzeQuestion` `remaining` alanını yalnızca `ok == true` dalında
parse ediyordu. Okunamayan bir fotoğrafta hak harcanıyor ama arayüzdeki sayı eski
kalıyordu — kullanıcı harcadığı hakkı göremiyordu.

**Ne yapıldı.** Parse ortak dala alındı; hem başarılı hem başarısız yanıt
`creditRemaining` taşıyor.

### 6. Ölü kod silindi

`DailyStateRepository.hasAiCredit()` (sıfır çağrı) ve `DailyState.unknown`
(sıfır çağrı). Gerekçe kodda: istemcide kota kapısı **yok ve olmayacak** —
sınırı sunucu uyguluyor; istemcinin önden dallanması kotanın iki yerde yaşadığı
yanılsamasını üretirdi.

---

## Ne DEĞİŞMEDİ

- **Kota rejimi.** Hâlâ günde 5, sabit gün anahtarı, `consume_ai_use` v1. Kayan
  pencere, aylık cap, katman fonksiyonu ve rampa **yazılmadı** (P1, ölçüme bağlı).
- **Model.** Hâlâ `gpt-4o-mini`, `detail` verilmemiş, `max_completion_tokens`
  yok, zaman aşımı yok (P2, ölçüme bağlı).
- **Ölçüm, fren ve yönetici ekranı** yazılmadı (P3, ölçüme bağlı). `usage` bloğu
  hâlâ atılıyor.
- **Cihaz doğrulaması** ertelendi (karar).
- **Paywall / abonelik** kapsam dışı.
- **Veli onayı ve kullanım koşulları** ayrı task.
- **`analyze-question`'ın CORS'suz duruşu, hata gövdesi tekliği ve kota
  kontrolünün OpenAI'dan önce olması** korundu.

---

## Ölçülen birim maliyet ve güncellenmiş cap tablosu

**Ölçüm YAPILMADI — bu bölüm bilerek boş.** OpenAI anahtarı ve örnek fotoğraflar
temin edilmedi. Araçlar hazır ve duman testinden geçti:

```
OPENAI_API_KEY=sk-… node tools/ab_model_bench.mjs ./ornek-fotograflar
node tools/cap_model.mjs --unit <ölçülen ortalama>
```

`ab_model_bench.mjs` taksonomiyi **üretim kaynağından** içe aktarıyor (prompt
birebir aynı), `reasoning_effort` reddedilirse yeniden deneyip bunu kaydediyor,
ve yanıttaki gerçek `usage` bloğundan maliyeti hesaplıyor — tahmin etmiyor.
`cap_model.mjs` bütün cap tablolarını formülden üretiyor; `--unit` verilmediğinde
çıktının başına **"TAHMİN — A/B koşulmadı"** uyarısı basıyor.

Gereken: luna erişimi olan bir anahtar + ~40 gerçek soru fotoğrafı (basılı test
kitabı, el yazısı, grafik/şekil içeren soru, kötü ışık, eğik çekim karışımı).
Koşum maliyeti ~$0,30.

**Ölçüm tahminden belirgin saparsa cap'ler kendi başıma değiştirilmeyecek;**
`cap_model.mjs` çıktısı sunulacak.

---

## Yönetici kartından izlenecek sinyaller

**Kart yazılmadı (P3).** Ama üç sinyalden **biri şimdiden birikmeye başladı**:

| Sinyal | Kaynak | Durum |
|---|---|---|
| Aynı IP'den açılan kimlik sayısı | `signup_throttle` (ip_hash × gün) | **Bugünden itibaren birikiyor** |
| Tekrar eden fotoğraf hash'i | `ai_calls.photo_sha256` | P1 bekliyor — `ai_result_cache` kısmi veri veriyor |
| İnsan dışı zamanlama | `ai_calls.at` | P1 bekliyor |

Yani kayıt kancası canlıya çıktığı andan itibaren "bir IP'den kaç kimlik açıldı"
sorusu yanıtlanabilir hâle geliyor; diğer ikisi çağrı defterine bağlı.

---

## Kalibrasyon için ölçüm modunda izlenecek metrikler

P1 canlıya çıktığında iki hafta boyunca:

1. **Pencereye çarpma oranı** (`rate_limits`, kova `ai_window_hit`). Ücretsiz
   kullanıcıların %10'undan fazlası haftada bir kereden sık çarpıyorsa pencere
   15 → 20.
2. **Aylık kova dağılımı** (`ai_month`). İlk iki hafta **artsın ama reddetmesin**;
   p95 250'nin üstündeyse cap 300 → 350.
3. **Yeni kimlik başına ortalama çağrı.** Frenin ikinci koşulunun eşiği (%60)
   uydurma bir sayı; ilk ay yalnızca **loglanmalı**, frene bağlanmadan önce
   gerçek organik dalgayla karşılaştırılmalı.
4. **Kayıt reddi oranı** (`signup_throttle` 429'ları). Meşru bir okul ağı
   kesiliyorsa `signup_day_limit` gevşetilir — göç gerekmez.
5. **Önbellek isabet oranı** (`ai_result_cache`). Beklenenden yüksekse iptal
   akışında hâlâ bir sorun var demektir.

---

## Dağıtım adımları

1. **Göçler.** `0057`–`0061` uygulanmalı. README'ye göre üretimde göçler elle
   SQL Editor'a yapıştırılıyor ve `supabase db push` **çalıştırılmamalı**.
2. **Edge fonksiyonu.** `supabase functions deploy analyze-question` — önbellek
   bağlantısı bu dağıtımla geliyor. Dağıtılmazsa göçler zararsız (fonksiyonlar
   çağrılmaz), yalnızca önbellek çalışmaz.
3. **`app_config`.** Tuz girilmezse hız sınırı **atlanır**:
   ```sql
   insert into public.app_config (key, value)
   values ('signup_ip_salt', '<rastgele 32+ karakter>')
   on conflict (key) do update set value = excluded.value;
   ```
   İsteğe bağlı: `signup_hour_limit`, `signup_day_limit`,
   `signup_blocked_domains`.
4. **Auth kancası Dashboard'da da açılmalı.** `config.toml` **yalnızca yerel
   geliştirmeyi** yapılandırır. Üretimde: Authentication → Hooks →
   *Before User Created* → `public.hook_before_user_created`. Bu adım atlanırsa
   kanca hiç çalışmaz ve hız sınırı yoktur — sessizce.
5. **P0 hâlâ sizde.** Dashboard'da gerçek `[auth.rate_limit]` değerlerinin ve
   `enable_confirmations = false` durumunun teyidi; OpenAI'da e-posta uyarısı.

---

## Uçtan uca elle doğrulama (dağıtımdan sonra)

1. Analiz sırasında **Vazgeç** → ekranda "Devam et" düğmesi **var**; basınca
   onay ekranı **saklanan sonuçla** açılıyor.
2. Aynı fotoğrafı ikinci kez gönder → sonuç anında geliyor, **kalan hak
   düşmüyor**, sunucu günlüğünde OpenAI çağrısı yok.
3. Okunamayan bir fotoğraf gönder → elle giriş formu açılıyor **ve** kalan hak
   rozeti bir azalmış görünüyor.
4. Yeni kayıt akışı: doğrulama adımı **yok**, kayıt sonrası doğrudan uygulamaya
   giriliyor.
5. Aynı IP'den arka arkaya 61 kayıt → 61.'si "biraz sonra yeniden dene" alıyor,
   **kalıcı engel değil**.
6. `app_config`'ten `signup_ip_salt` silinip kayıt denenirse → kayıt **geçiyor**
   (fail-open) ve sunucu günlüğünde uyarı var.

---

## Kapsam dışında değiştirmek zorunda kaldıklarım

1. **`build 2` hem `.gitignore`'a hem analiz dışına alındı.** Finder/iCloud
   çakışma kopyası; içindeki iOS SourcePackages test dosyaları `flutter analyze`
   çıktısını **91 yabancı hatayla** dolduruyordu ve kendi doğrulama döngümü
   kullanılamaz hâle getiriyordu. `/build [0-9]*` deseni ileriki kopyaları da
   yakalar.
2. **Çalışma ağacındaki Task 04 işi commit edildi** (kararınız gereği), ve
   hukuki metin taslakları ayrı bir commit'e alındı — üç task'ın diff'i
   karışmasın diye.
3. **`analyze-question`'daki `consumeCredit` genel bir `rpc()` yardımcısına
   çevrildi.** Üç RPC çağrısı için aynı fetch bloğunu üç kez yazmamak gerekiyordu;
   davranış aynı.

---

## Emin olmadıklarım / karar vermeniz gerekenler

1. **pgTAP ve mutasyon bu makinede koşmadı.** 42 yeni iddia ve 4 yeni mutasyon
   yazıldı ama hiçbiri çalıştırılmadı. `check_sql` yalnızca biçimsel: dolar-tırnak
   ve ayraç dengesi, `plan(n)` sayımı, revoke/grant yazılmamış fonksiyon. **Bir
   mantık hatası ilk CI koşusuna kadar görünmez.** Özellikle şüpheli iki nokta:
   `has_function_privilege('supabase_auth_admin', …)` çağrısı o rolün varlığına
   bağlı, ve kancanın `exception when others` dalı testte hiç tetiklenmiyor.
2. **Auth kancası üretim davranışını değiştiriyor.** Fazla sıkı bir limit ya da
   Dashboard'da yanlış yapılandırma **kayıtları kapatır**. Fail-open ve
   `app_config` ayarlanabilirliği bunu hafifletiyor ama sıfırlamıyor. İlk gün
   kayıt sayısı izlenmeli.
3. **Önbellekte kapsam kararı gözden geçirilebilir.** Kullanıcıya kilitli
   tutmak tasarrufun büyük kısmını bırakıyor. Küresel önbellek, "bu fotoğrafı
   başkası da analiz etti mi" ölçümünü mümkün kılar — bunu kabul edilebilir
   bulursanız tasarruf birkaç kat artar. Ben etmedim.
4. **Cihaz doğrulaması ertelendi ama açık pencere gerçek.** Kayıt hız sınırı
   kimlik üretme *hızını* 29 kat düşürüyor; *stoku* bağlamıyor. Ölçeklenen fren
   (P3) yazılana kadar bu pencerede tek savunma kancadır.
5. **Mutasyonlarda bir boşluk bıraktım.** Önbelleğin **kapsam** iddiası
   (`c.user_id = v_uid`) mutasyona sokulmadı: bunu bozmak fonksiyonu yeniden
   yazmayı gerektiriyordu ve mutasyon dosyasının fonksiyon gövdesinin eski bir
   kopyasını taşıması, fonksiyon değiştiğinde UNDO'nun sessizce eski sürümü geri
   kurması riskini getiriyordu. Aynı boşluk kayıt kancasının limit mantığı için
   yok (tetikleyiciyle çözüldü). Kabul edilebilir bulmazsanız gövde kopyalayan
   bir mutasyon yazılabilir.
6. **Login ekranındaki `email_not_confirmed` dalı duruyor.** P0 teyidi gelince
   kaldırılabilir; şimdilik ölü olduğunu varsayıp silmek, üretimde doğrulama
   açıksa kullanıcıyı kilitlerdi.
7. **A/B'nin fiyat tablosu elle yazıldı** (`tools/ab_model_bench.mjs` içindeki
   `PRICES`). Fiyat değişirse betik sessizce yanlış maliyet üretir. Koşumdan
   önce OpenAI fiyat sayfasıyla karşılaştırın.

---

## Değişen dosyalar

**Yeni göçler**
`20260904000300_no_email_verification.sql` (0057) ·
`20260904000400_signup_throttle.sql` (0058) ·
`20260904000500_function_grants_recheck6.sql` (0059) ·
`20260904000600_ai_result_cache.sql` (0060) ·
`20260904000700_function_grants_recheck7.sql` (0061)

**Yeni testler / mutasyonlar**
`supabase/tests/250_signup_throttle.sql` (24 iddia) ·
`supabase/tests/260_ai_cache.sql` (18 iddia) ·
`supabase/mutations/14_signup_throttle_open.sql` ·
`15_signup_limit_never_bites.sql` · `16_ai_cache_open.sql` ·
`17_ai_cache_no_ttl.sql`

**Edge fonksiyonu**
`supabase/functions/analyze-question/index.ts` — `rpc()` yardımcısı,
`sha256Hex()`, kotadan önce önbellek kontrolü, başarıdan sonra önbelleğe yazma

**İstemci**
`lib/features/capture/capture_screen.dart` (iptal çıkmazı) ·
`lib/data/mistake_repository.dart` (kalan hak parse'ı) ·
`lib/data/daily_state_repository.dart` (ölü kod) ·
`lib/data/auth_repository.dart` (doğrulama üyeleri) ·
`lib/features/onboarding/onboarding_flow.dart` (verify adımı) ·
`lib/l10n/app_tr.arb` (11 anahtar) ·
**silindi:** `lib/features/auth/email_verify_step.dart`

**Araçlar / yapılandırma**
`tools/ab_model_bench.mjs` (yeni) · `tools/cap_model.mjs` (yeni) ·
`supabase/config.toml` (kanca açıldı, doğrulama kararı belgelendi) ·
`.gitignore` + `analysis_options.yaml` (`build 2`)
