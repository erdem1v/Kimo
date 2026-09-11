# Task 10 — Ödüllü reklam, hak gösterimi, kota revizyonu

Dört iş: (1) "can" metaforunun kaldırılması ve hak göstergesi, (2) ödüllü
reklam altyapısı, (3) elmasın v1'de gizlenmesi, (4) kota rakamlarının
revizyonu.

**Doğrulama durumu.** Bu makinede Docker YOK; pgTAP ve mutasyon süiti
**yalnızca CI'da** koşuyor. Deno da yok — `ad-reward` fonksiyonunun tip
denetimi dağıtımda. Yerelde koşan ve YEŞİL olanlar:

| Kapı | Sonuç |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **318 test** (paket öncesi 200) |
| `tools/check_sql.py` | 84 göç · **0 sorun** (plan sayıları dahil) |
| `tools/check_symbols.py` + `--selftest` | 0 sorun · 4 uydurma sembol yakalandı |
| `tools/check_imports.py` + `--selftest` | 0 sorun |
| `tools/build_taxonomy.py --check` | çıktılar güncel |
| Eski uygulama adı kapısı | temiz |
| **Üç yeni CI kapısı** (metafor / "sınırsız" / sabit fiyat) | üçü de **ilk koşuda yeşil**, ve metafor kapısı **kendini sınıyor** |

SSV kriptografisi yerelde **gerçekten koşturuldu**: `ssv.ts`'in DER
ayrıştırıcısı Node'a taşınıp 200 gerçek ECDSA imzasına karşı sınandı
(**402 iddia, 0 hata**); imzaların 150'sinde 33 baytlık bileşen vardı, yani
tuzaklı dal kapsandı. Kurcalanmış metin reddedildi — doğrulayıcının gerçekten
ayırt ettiği kanıtlandı. Bu geçici bir taşıma; kalıcı test
`supabase/functions/ad-reward/ssv_test.ts` (`deno test`).

CI'da koşacaklar: `supabase db reset` (atlanan göç kontrolü), `supabase test db`
(**691 pgTAP iddiası**), `tools/mutation_check.sh` (**36 mutasyon**).

---

# 1. Kapsamı değiştiren bulgu: değişecek rakam yoktu

Brief "kota rakamları değişiyor" diyordu — ücretsiz 15→10, premium 40→50.
**Depoda o rakamlar yoktu.** Bugünkü gerçek:

- `20260902000200_ai_quota.sql:56` → `daily_ai_quota()` gövdesi `select 5`,
  `immutable`. Tek kova (`rate_limits` bucket `ai`), pencere anahtarı Istanbul
  **günü**.
- Katman kavramı sıfır sonuç: `premium`, `abonelik`, `subscription`,
  `entitlement` depo genelinde geçmiyordu.
- Aylık cap yok, kayan pencere yok, `app_config`'te tek bir kota anahtarı yok.
- Task 06 raporu bunu zaten yazmış (`docs/task-06-ai-maliyet-raporu.md:180`):
  *"Kayan pencere, aylık cap, katman fonksiyonu ve rampa yazılmadı."* Hedef
  rakamlar yalnızca `tools/cap_model.mjs:196-197`'deki modelleme betiğindeydi.

Brief'in bölüm 3'te istediği dört gösterim durumu ("pencere doldu", "aylık cap
doldu") ancak pencere ve cap gerçekten varsa anlamlı. Bu yüzden bu task rakam
değiştirmedi, **rejimi kurdu**. Karar onayla alındı.

---

# 2. Kayan pencere: sayaç değil DEFTER

`rate_limits(user_id, bucket, window_key, n)` sabit kova yapabiliyor, kayan
pencere yapamıyor: "son 8 saatte kaç çağrı" sorusu tek tek çağrı zamanlarını
gerektiriyor. Tasarımın istediği **"sonraki hakkın 14:30'da"** değeri de zaten
o zamanlardan türüyor.

`ai` kovası append-only bir deftere dönüştü (`public.ai_calls`). `rate_limits`
**kaldı**: `scan`, `friend_code`, `friend_code_rotate` ve yeni `ad_start`
kovaları ona bağlı.

| Katman | 8 saatlik pencere | Aylık cap |
|---|---|---|
| anonim | — | **3, ömür boyu** |
| ücretsiz | 10 | 300 |
| premium | 50 | 1.000 |

Sayılar `app_config`'te, fail-open varsayılanlarla. **Yoruma yazılan asimetri:
kota sayıları fail-open, kimlik doğrulama sırrı fail-closed.** Yanlış
yapılandırılmış bir ortam analizi kapatmasın; ama `ad_reward_secret` yoksa ödül
VERİLMEZ — orada açık kalmak bedava hak basmak olurdu.

## 2.1 `ai_month` ve `ai_window_hit` kovaları YAZILMADI

Task 06 ikisini planlamıştı. İkisi de defterden türetilebiliyor ve ikinci bir
sayaç tutmak 0040'ın kendi yorumunda (`:78-81`) reddedilen **"sayı iki yerde"**
hatasını geri getirirdi — arayüz "2 hakkın kaldı" derken sunucu reddedebilirdi.

`ai_window_hit` ayrıca **reddetme yoluna yazma** koyardı; hiçbir maliyeti
olmaması gereken tek yol orası. **Bedeli açıkça: "duvara çarptıktan sonra kaç
kez daha denedi" sinyalini kaybettik.** Pencereye çarpma oranı defterdeki
zaman damgalarından pencere fonksiyonuyla türetilebilir; "kaç kez daha
denedi" türetilemez.

## 2.2 Atomiklik: advisory kilit, ve neden başka yol yok

0040'ın tek ifadelik `on conflict … where` idiomu yarışsızdı **çünkü çakışan
satırı INSERT kilitliyordu**. Defterde öyle bir satır yok: "pencerede say,
sonra ekle" bir hayalet okuma ve READ COMMITTED'da iki eşzamanlı işlem de
`sınır-1` görüp ikisi de commit eder.

```sql
perform pg_advisory_xact_lock(hashtext('ai_quota'), hashtext(v_uid::text));
```

- **`_xact_` zorunlu.** Oturum ömürlü `pg_advisory_lock` Supavisor'ın işlem
  kipinde havuzlanmış bağlantılar arasında sızar ve havuzu kilitler.
- Kilit **OpenAI çağrısı sırasında tutulmuyor**: RPC commit'inde bırakılıyor.
- `grant_ad_reward` **aynı** kilidi alıyor → ödül verme ile tüketim araya
  girmiyor.
- **Reddedilen iyimser yol yoruma yazıldı** (ekle-say-gerekirse geri al): doğru
  *görünüyor* ama değil — eşzamanlı, commit edilmemiş bir ekleme sayımda
  görünmez, ikisi de geçer. Gelecekte biri "sadeleştirmeye" kalkmasın diye
  gerekçesi dosyada duruyor.

## 2.3 `next_at` — `min(at) + 8sa` YANLIŞ

O formül yalnızca `kullanılan == etkin sınır` tam tutuyorsa doğru. Genel biçim
pencerenin *k*'ıncı en eski çağrısı (`k = kullanılan − etkin + 1`):

```sql
order by c.at offset greatest(v_used - v_effective, 0) limit 1
```

Yapılandırma sınırı daralttığında ve harcanmamış bir ödül gece yarısı süresi
dolup etkin sınır düştüğünde de doğru kalıyor; naif `min()` ikisinde de
**sessizce eksik bildirir**.

## 2.4 Yazdığım kapı sessizce yeşil yanıyordu — üçüncü kez

Eski metaforun arayüz metinlerine geri sızmasını engellemek için bir CI kapısı
yazdım ve ilk koşuda "yeşil" dedi. **Yeşil değildi, hiçbir şey aramıyordu.**

```
git grep -E "\bcan\b"  -- lib/l10n/app_tr.arb   → 0 eşleşme   (YANLIŞ)
git grep    -e can        -- lib/l10n/app_tr.arb   → 7 satır
grep     -E "\bcan\b"   lib/l10n/app_tr.arb      → 1 satır
```

`git grep -E` POSIX ERE kullanıyor ve orada `\b` **tanımsız** — kelime sınırı
diye bir şey yok, desen hiçbir şeye uymuyor ve çıkış kodu 0 dönüyor. Yani kapı
her koşuda "temiz" diyecekti.

Bu bu depoda **üçüncü** kez: `check_symbols.py`'nin ilk sürümünde `\b` bir
yazım kazasıyla düşmüştü, `check_imports.py`'de kaçış karakteri yerine 0x08
yazılmıştı. İkisi de bu yüzden `--selftest` taşıyor. Yeni kapı da taşıyor:
**uydurma bir ihlal ekleyip yakalandığını kanıtlıyor**, yakalamazsa iş kırmızı
dönüyor. Sınama GEÇİCİ BİR KOPYA üzerinde — ilk yazımda gerçek dosyaya
dokunup `git checkout` ile geri alıyordum ve o komut dosyadaki **işlenmemiş
ARB değişikliklerinin tamamını sildi** (yeniden yazıldı; o yüzden kapı artık
gerçek dosyaya hiç dokunmuyor).

Sınır sınıflarına `_` da eklendi: `can_read_mistake_photo` gibi kod
tanımlayıcıları yanlış alarm üretiyordu.

---

# 3. Hak gösterimi: "can" kalktı

Kalp silindi — `KimoIcons.heart` **tamamen kaldırıldı** (`all` listesinden ve
sınıf yorumundan da). Silinmiş olması bir **kapı**: `check_symbols.py`
`KimoIcons.heart`a yapılan her başvuruyu "yok" diye düşürüyor, yani metaforun
geri sızması sessizce olamıyor.

Beş durum, hepsi `public.ai_state()`'in söylediği `ai_state` değerinden:

| Durum | Metin |
|---|---|
| `ok` | `7 hakkın kaldı` |
| `low` | `2 hakkın kaldı · sonraki 14:30'da` |
| `window_full` | `Hakların doldu · sonraki 14:30'da` |
| `month_full` | `Bu ay hakkın doldu · 1 Ekim'de yenilenir` |
| okunamadı | **hiçbir şey çizilmiyor** |

`month_full` dalı `ai_next_at_hm`i **hiç okumuyor**; fonksiyonun şekli bunu
garanti ediyor ve test alanı DOLU verip metinde geçmediğini iddia ediyor.

## 3.1 Türkçe bulunma eki — tasarımın göremediği hata sınıfı

Tasarım "sonraki hakkın **14:30'da** açılır" yazıyor. O örnek doğru ama
değerler keyfî ve ek, sayının **okunuşuna** göre değişiyor:

```
14:30'da   15:00'te   16:00'da   13:00'te   14:05'te   14:20'de   09:40'ta
Ekim'de    Kasım'da   Ağustos'ta  Aralık'ta  Mart'ta
```

Sabit bir `'da` yazmak üretilen zamanların kabaca yarısını Türkçe bilen bir 16
yaşındakine bozuk gösterirdi — **ve bu hiçbir derleyici hatası vermeden
olurdu.** İkisi de kapalı küme (saat 0-23, dakika 0-59, 12 ay), yani tabloyla
tam çözülüyor: `lib/models/tr_suffix.dart` + 65 birim testi (24 tam saatin
hepsi, 12 ayın hepsi).

Aynı dosyada `trOrdinal()` var: tasarımın "Bu hafta **üçüncü** kez
karşılaştık" cümlesi ICU çoğul biçimiyle **yazılamıyor** — ICU yalnızca `=0`,
`=1`, `=2` ve adlandırılmış kategorileri kabul ediyor, `=3` sözdizimi hatası
veriyor (gen_l10n bunu derlemede reddetti).

## 3.2 Biçimlendirme bölüşümü

Sunucu `ai_next_at_hm` (`HH:MM`, Istanbul duvar saati) ve `ai_month_resets_on`
(Istanbul takvim günü) veriyor. Ay ADI sunucuda ÜRETİLMİYOR: Postgres'in `TM`
ay adları `lc_time`'a bağlı ve Supabase'de `tr_TR` olduğu varsayılamaz. Ay adı
ve ek istemcide. **Cihaz saati hiçbir yere girmiyor** — deponun
`today`/`week_start` kararının aynısı.

---

# 4. Ödüllü reklam

## 4.1 Ağ seçimi: AdMob

- Tek entegrasyonla iki platform (`google_mobile_ads` 9.1.0, Google'ın kendi
  Flutter eklentisi); Firebase zaten kurulu.
- **SSV yerleşik ve belgeli** — bu task'ın kilit şartı. Diğer ağlarda
  sunucudan-sunucuya geri çağrı ya yok ya mediation'a bağlı.
- Yaş/içerik anahtarları yerleşik.
- Doluluk yetersiz çıkarsa mediation sonradan AdMob'un ÜSTÜNE eklenir; ters
  yönde göç etmek daha pahalı olurdu.

Geçişli olarak **üç yeni yerli eklenti** geliyor: `webview_flutter`,
`webview_flutter_android`, `webview_flutter_wkwebview` (reklam içeriği
WebView'de çiziliyor). `pubspec.lock` kapısı bunu görünür kıldı.

## 4.2 "İzledim" diyemiyor — SSV akışı

```
istemci                      sunucu                            AdMob
  │ start_ad_reward() ─────────►│  pending satır + nonce
  │◄──────────── nonce (uuid)   │
  │ customData = nonce          │
  │ reklamı göster ──────────────────────────────────────────────►│
  │                             │◄── GET /ad-reward?…&signature=…&key_id=…
  │                             │    ECDSA doğrula → grant_ad_reward(...)
  │ my_daily_state'i yokla ────►│
```

`onUserEarnedReward` **kanıt değil** ve kodda öyle yazıyor: o geri çağrıda
hiçbir sayaç artırılmıyor. İstemci hakkı ancak görünümü yeniden okuyarak
görüyor (immediate, 1s, 2s, 3s, 5s, 8s ≈ 20 saniye).

**Supabase kullanıcı kimliği reklam ağına HİÇ gönderilmiyor.** AdMob'un
`userId` ve `customData` alanlarına sunucunun ürettiği tek kullanımlık belirteç
yazılıyor. Ham bir uid, hukuki metinlerde sayılması gereken yeni bir veri
paylaşımı olurdu; nonce zaten takma.

## 4.3 Servis rolü kullanılmadı — ve öncül düzeltildi

`delete-account/index.ts:18`'deki *"Bu depodaki TEK servis rolü yüzeyi
burasıdır"* yorumu **bayattı**: `delete-question`, `cleanup-anonymous`,
`scan-photos` ve `send-push` de servis rolü anahtarını okuyor — **beş
fonksiyon** (grep ile doğrulandı). Korunmaya değer değişmez "tek servis rolü
yüzeyi" değil:

> **Hiçbir DOĞRULAMASIZ (`verify_jwt = false`) fonksiyon servis rolü istemcisi
> kurmaz.**

`ad-reward` depodaki ilk doğrulamasız fonksiyon. Orada bir hata (loglanan bir
yapılandırma, kopyalanmış bir yardımcı, başlık ileten bir SSRF) servis rolü
anahtarıyla **tüm veritabanına** dönüşürdü. Bu yüzden ödül verme yolu
`anon`-çağrılabilir **tek** bir RPC ve paylaşılan bir sır:

- sır sızarsa hasar: **bedava reklam hakkı**
- anahtar sızarsa: **her satır + `auth.admin.deleteUser`**

**Dürüst kayıt (hem kodda hem burada):** Supabase servis rolü anahtarını HER
edge fonksiyonunun ortamına enjekte ediyor ve bu kapatılamıyor. "Anahtarı
taşımıyor" ifadesi yalnızca *hiçbir kod yolu onu okumuyor* anlamında doğru —
isolate içinde rastgele kod yürütmeye karşı **yalıtım değil**. Kazanç kazara
yolları kaldırmak. Bu yüzden `ad-reward` `createClient` import etmiyor, çıplak
`fetch` kullanıyor.

**Bedeli:** `function_grants_recheck`'in tek şekli var ("listede yoksa revoke,
listedeyse `authenticated` çağırabilmeli") ve `grant_ad_reward` anon-only olmak
zorunda. `v_keep`'e konsaydı `v_miss` kontrolü patlardı; hiç konmasaydı revoke
döngüsü anon grant'ını **sessizce geri alırdı** ve ödüller bir daha hiç
verilmezdi. 0078 bu yüzden ikinci bir dizi taşıyor (`v_anon_only`) ve kendi
**pozitif** iddiasını yazıyor: anon çağırabiliyor, authenticated
çağıramıyor.

## 4.4 Üç kodlama tuzağı

Hepsi *aralıklı* hata üretir — "reklam bazen çalışmıyor" gibi görünür:

1. **DER → IEEE P1363.** AdMob imzası base64url kodlu bir DER
   `SEQUENCE { INTEGER r, INTEGER s }`; WebCrypto ham 64 baytlık `r‖s`
   bekliyor. Her INTEGER'da baştaki `0x00` işaret baytı atılıp **32 bayta sola
   doldurulmalı**. İki yön de oluyor: imzaların ~yarısında bir bileşen 33 bayt
   (ölçtüm: 200 imzanın 150'si), ~1/256'sında 32'den kısa. Tek dalı doğru
   yazmak callback'lerin birkaç yüzdesini KALICI olarak düşürür.
2. **İmza HAM sorgu dizesi üzerinde.** `&signature=` öncesi, olduğu gibi.
   `new URLSearchParams(...).toString()` yüzde-kodlamayı normalleştirir ve
   doğrulamayı **kesin** bozar. `key_id` imzalanan kısmın DIŞINDA (AdMob onu
   `signature`dan sonra gönderiyor).
3. **Anahtar döndürme.** Bilinmeyen `key_id` yeniden çekmeyi tetikliyor ama
   **5 dakikalık alt sınırla**: uydurma key_id gönderen biri gstatic'i bizim
   üzerinden dövmesin.

## 4.5 Yanıt politikası — "her zaman 200" yanlıştı

- **Karara bağlanmış** sonuçlar (bozuk imza, bilinmeyen nonce, eski damga,
  tekrar, tavan aşımı) → **200 + log**. 2xx olmayan yanıt AdMob'u asla
  başarılı olmayacak bir istekte sonsuza kadar denemeye iter.
- **Karara bağlanmamış** (RPC'nin kendisi ağ hatası / 5xx) → **503**, ki
  AdMob'un yeniden denemesi veritabanı kısa süre düştüğünde gerçek bir emniyet
  ağı olsun. Hepsine 200 demek o ağı sessizce çöpe atardı.

## 4.6 Ödül pencereyi açıyor, aylık cap'i AÇMIYOR

```
window_left = greatest(window_limit - window_used, 0)
            + (BUGÜN verilmiş ve henüz harcanmamış ödül)
```

**"Pencere-göreli ödül" (verildiği andan 8 saat sonra buharlaşan) bilerek
reddedildi:** kullanıcı ekrana bakarken sayı kendi kendine düşerdi. Tüm
önermesi "sunucu hesaplıyor, sayı güvenilir" olan bir ekran için en kötü
özellik. `consumed_at` + **Istanbul günü** sona erme: sayı yalnızca kullanıcı
bir şey yapınca ya da gece yarısı değişiyor — 3/gün tavanının zaten kullandığı
saat, yani **yeni bir zaman ekseni girmedi**.

**Sonuç: reklam özelliğinin azami ek OpenAI maliyeti SIFIR.** Ödül ücretsiz
kullanıcıya 8 saatlik pencere içinde öne yükleme imkânı veriyor, toplam aylık
harcamayı asla artırmıyor.

Ay doluyken ödül işe yaramayacağı için reklam **iki katmanda** engelleniyor:
`ad_offer` düğmeyi çizmiyor VE `start_ad_reward` `month_full` diye reddediyor.
Bir düğmenin çizilmemesi tek başına güvenlik kontrolü değil.

## 4.7 Bekleyen satırlar 3/gün bütçesini tüketmiyor

Reklamı açıp vazgeçmek **bedava** — slot yakmıyor. Suistimal üç katmanda:

1. **Kısmi tekil indeks** `ad_rewards_one_pending` → "kullanıcı başına en fazla
   bir canlı bekleyen satır" bir **şema** değişmezi, fonksiyon mantığı değil.
   Taze bekleyen varsa AYNI nonce dönüyor (ağ kesintisine karşı idempotent).
2. Başlangıç hız sınırı deponun **mevcut** primitifiyle (`bump_rate_limit`) —
   yeni sayaç icat edilmedi.
3. İşe yaramayacaksa reddetme (`not_free_tier`, `month_full`,
   `no_rewards_left`, `not_needed`, `suspended`).

---

# 5. Hak bitti ekranı — üç yol birlikte

Tasarımın verdiği tam ekran rota (`lib/features/credit/credit_wall_screen.dart`).

**İKİ BAĞIMSIZ EKSEN.** Tasarım w1/w2'yi tek eksen gibi gösteriyor ama değil:
w2'ye verilen tek başlık ("Bu ay analiz hakkın doldu") üç tetikleyicisinden
birinde **yalan** olurdu — bu hafta üçüncü kez **pencereye** çarpan kullanıcı
ayını bitirmemiştir, ve aynı tasarımın kendi kuralı "ay doluyken pencere saati
gösterilmez" diyor. Ayrıştırma:

- **başlık + gövde** ← `ai_state`
- **Plus'ın ağırlığı** ← tekrar sayısı / reklam tavanı

Dört birleşim, yanlış başlık yok. Test bunu ayrıca iddia ediyor.

**Buton ağırlığı.** `kimo_button.dart:22` "ekranda en fazla bir primary" diyor.
w1'de primary **Kaydet**; w2'de brief açıkça *"tekrar çarpanda Plus öne
çıksın"* diyor ve tasarım da Plus CTA'yı dolu mercan gösteriyor → w2'de primary
Plus, Kaydet `secondary` ama **`expand: true` ve aynı `minHeight`**.
Tasarımın şartı ("aynı boyutta, küçültülmedi") boyutla karşılandı, dolguyla
değil.

**Anonim dalı** (tasarımda yok, yorum): reklam ve Plus çizilmiyor — anonim
oturum bedava açıldığı için reklam hakkı vermek sıfırlama yolu olurdu ve Plus
kalıcı hesap gerektiriyor. Yerine "Hesabını oluştur" + kaydetme yolu.

## 5.1 Kaydetme yolu: dört giriş yolu izlendi

| Yol | `manualEntry` | `creditGranted` | `dismissed` |
|---|---|---|---|
| A · `_analyze` `outOfCredit` görür | `_openConfirm(bytes, result)` | aynı fotoğrafla yeniden analiz | `_photoArea` hâlâ "Devam et" çiziyor ✅ |
| B · boş durumda duvar | `_openConfirm(null, null)` | gösterge yenilenir | `_pickActions` + `captureManualEntry` çizili ✅ |
| C · `today_screen` açıklama sayfası | `ConfirmMistakeScreen()` | `refreshBus.ping()` | nav bar kamerası yerinde ✅ |
| D · `pending_photos_screen` | duvara hiç gelmiyor (`photo_queue.flush` `outOfCredit`'i `needsUser`'a yutuyor) ✅ | | |

A yolu karakter değiştirdi: satır içi blok formun İÇİNDEYDİ, artık bir `pop`
uzakta. **`capture_screen.dart`'taki "Devam et" satırı bu yüzden taşıyıcı hâle
geldi ve öyle yorumlandı** — kaldırılırsa duvarı kapatan kullanıcı çıkmazda
kalır.

---

# 6. Elmas gizlendi, silinmedi

Mekanizma tek satır: `lib/state/features.dart` →
`bool.fromEnvironment('SHOW_GEMS')`. `kDebugMode` ile aynı şekil, analyzer
temiz, sürümde ağaç budanıyor; ayrıca ekip `--dart-define=SHOW_GEMS=true` ile
kod değiştirmeden göz kontrolü yapabiliyor.

**Sunucu tarafı HİÇ DEĞİŞMEDİ**: `claim_daily_goal` elmas vermeye devam
ediyor, `my_daily_state.gems` hâlâ okunuyor. Bakiyeler v1 boyunca birikiyor —
v2'yi göç değil **tek satır** yapan şey bu.

Kapılanan üç yer ve gerekçeleri §"Yarım kalan bir şey yok" bölümünde.

---

# 7. Seviye sistemi — doğrulandı, dokunulmadı

Şemada seviye **yok** ve gerekmiyor: `grep -i 'level\|seviye'` göçlerde yalnızca
`enable row level security` satırlarına düşüyor. Seviye XP'den saf fonksiyonla
türetiliyor (`daily_state_repository.dart`, 1000 XP = 1 seviye) ve iki yerde
gösteriliyor (HUD, oturum sonu kartı). Brief "varsa dokunma" diyordu;
dokunulmadı.

İki küçük not: aynı formül `session_result.dart`'ta ikinci kez yazılmış
(çoğaltma, bu task'ta düzeltilmedi); `game_progress.dart`'taki "seviye sistemi
kaldırıldı" yorumu **bayattı ve düzeltildi**.

---

# Ne DEĞİŞMEDİ

- **Kaydetme yolu.** Hiçbir koşulda kapanmıyor; sekiz dalda testle kanıtlı.
- **Sütun ayrıcalıkları ve sunucu sahipliği.** Eklenen her sayaç sunucu
  sahipli, `lockdown_v7`'de sınıflandırılmış, pgTAP negatif testi yazılmış.
- **`analyze-question`'ın sırası**: yaş kapısı → taksonomi → önbellek → kota →
  OpenAI. Önbellek isabeti kotayı atlamaya **ve deftere yazmamaya** devam
  ediyor, yani aylık cap'i de tüketmiyor.
- **Hak bitmesi istisna değil**: `allowed = false` dönüyor.
- **Geri sayım yok** — yalnızca saat/tarih.
- **Yeni push bildirim türü YOK.** `240_persona.sql` her `(kind, mascot)`
  hücresi için 5 satır şart koşuyor; "hakkın geri geldi" bildirimi cazipti ve
  tam bu kural yüzünden kapsam dışı bırakıldı.
- **Elmasın sunucu tarafı.** `claim_daily_goal` ve `20260902000400` el
  değmedi.
- **Seviye sistemi.**
- **Abonelik satın alma, makbuz doğrulama, AI koç, elmas satın alma,
  interstitial/banner reklam.** Kapsam dışı.
- **Birim AI maliyeti hâlâ ÖLÇÜLMEDİ.** 10/50/300/1.000 tahmin.

---

# Yarım kalan bir şey yok

Genel kural: **bir şeyi bir taraftan kaldırırken diğer tarafta boşluk
bırakmamak.** Her kaldırma için yerine ne geldiği:

| Kaldırılan | Yerine ne geldi / neden boşluk yok |
|---|---|
| `KimoIcons.heart` | Metin tabanlı gösterge (`CreditIndicator`). Silinmiş olması bir kapı: `check_symbols.py` geri dönüşü yakalıyor |
| ARB `creditLeft`, `creditExhaustedTitle`, `creditExhaustedBody`, `creditExplain` | Dört durum anahtarı + `creditExplainBody` (kota sayısı TAŞIMIYOR) + beşinci durum olarak bilinçli sessizlik |
| `DailyState.hasAi` | Tek çağıranı (`today_screen` açıklama sayfası) `aiState`e geçti. O satır silinen iki ARB anahtarını da kullanıyordu, yani derleyici kaçırma şansı bırakmadı |
| `DailyState.aiQuota` (ve `?? 5` uydurması) | `aiWindowLimit` + `aiMonthLimit`, sunucudan |
| `DailyState.aiResetsAt` | `aiNextAtHm` + `aiMonthResetsOn` |
| `QuestionAnalysis.creditResetsAt` | Sıfır okuyucusu vardı; duvar değerleri görünümden geliyor |
| `confirm_screen._creditNotice` | Tam ekran duvar. Onay ekranı yine elle giriş formu ve `confirmIntroManual` doğru talimatı zaten basıyor |
| `daily_ai_quota()`, `istanbul_day_reset()` | `config_int` + `ai_state()`. 0078'de **ölü-nesne kapısı** diriltilmelerini göç zamanında engelliyor |
| `my_daily_state.ai_quota` / `ai_resets_at` | 18 yeni sütun. İstemci ve göç **birlikte** dağıtılmak zorunda |
| `rate_limits` `ai` kovası | `ai_calls` defteri. Tablo ve diğer üç kova yerinde; yeni `ad_start` kovası da ona bindi |
| Elmas HUD hapı | Seri ve seviye hapları yerinde; HUD boşalmıyor |
| Elmas profil rozeti | **Her iki dal** kapılandı. Yalnızca rozeti gizlemek, durum okunamadığında `else` dalındaki **çıplak elmas ikonunu** lig satırında bırakırdı |
| Elmas sandığı | Kartın içeriğinin **tamamı** elmas (ikon + "+N elmas" + "sandığı aç"), o yüzden kart bütün olarak çizilmiyor — kullanıcı boş bir sandık açmıyor, açacak sandık GÖRMÜYOR. Ödül kaybolmuyor: `sessionGoalReached` duyurusu ve `+{xpGained}` karosu yerinde, ve `claim_daily_goal` hem XP hem elmas veriyor. Testle kanıtlı |
| `deleteItemProgress`'ten "elmasların" | Elmas sunucuda hâlâ siliniyor; cümle örnek sayıyor, şema saymıyor. Görünmeyen bir para biriminin adını silme listesinde saymak kafa karıştırırdı |
| "can" terminolojisi | **ARB'de sıfır geçiş** (kapı yeşil) + kendini sınayan CI kapısı. `lib/` içinde kelimeyi taşıyan 13 eski yorum ve bir ARB açıklaması yeniden yazıldı. Geriye BİLEREK üç yorum kaldı (`ai_credit.dart`, `kimo_icons.dart`): kararın NEDENİNİ belgeliyorlar ve kullanıcıya basılan metin değiller. ARB açıklamaları kelimeyi LİTERAL yazmıyor — eski-ad kapısının aynı kuralı, yazsaydı kapı kendi satırını yakalardı |

**Tek gerçek davranış kaybı, açıkça:** sandık kartı çizilmediği için
`KimoReaction.chestOpen` ve `sound.levelUp()` artık oturum sonunda oynamıyor.
Enum değeri `kimo_pose.dart`'ta duruyor ve `kimo_pose_test` onu geziyor — ölü
sembol yok, v2'de kart geri gelince kutlama da geri geliyor.

**Eklerken boşluk bırakmama tarafı** da testle kapalı: reklam yolunun üç sessiz
başarısızlık nedeni (doluluk yok / desteklenmeyen platform / yapılandırma
eksik) hiçbirinde hata göstermiyor; tavan dolunca satır **bilgiye dönüyor**,
kaybolmuyor; Kaydet düğmesi **sekiz dalda da var, etkin ve tam genişlik**.

---

# Güncellenmiş hukuki metinler

`docs/hukuki-metinler.md` **sürüm 1.2 → 1.3** (+256 / −46 satır). Değişen her yer:

| Bölüm | Ne değişti |
|---|---|
| Başlık + sürüm notu | 1.3'te ne değiştiği üç maddede |
| §1.5 Teknik veriler | `ai_calls`, `ad_rewards` ve AdMob satırları; "AdMob'a ne gidiyor, ne GİTMİYOR" tablosu |
| §1.10 Yurt dışına aktarım | **6. alıcı: Google / AdMob (ABD)** |
| §1.11 Toplanmadığı doğrulananlar | **Baştan yazıldı.** DÜŞEN ve KORUNAN iddialar ayrı ayrı listeli; izin tablosuna `AD_ID` (kaldırıldı) satırı |
| §2 | **Yeni bayrak A-12** (ödüllü reklam + 13-18 kitle) ve depo dışında kalan 7 adım; A-8/A-9 `KAPANDI` işaretlendi |
| §3.1 Ortak kararlar | "Tracking: HAYIR" KORUNDU (gerekçesiyle); "reklam/pazarlama" satırı yeniden yazıldı; yeni "reklam içeriyor mu: EVET" satırı |
| §3.2 ASC etiketleri | `Usage Data → Advertising Data` ✅ (Third-Party Advertising, Linked: Hayır, Track: Hayır); Google'ın önerilen listesiyle karşılaştırma uyarısı |
| §3.3 Play Veri Güvenliği | "Reklam kimliği: Hayır" KORUNDU (koşuluyla); Ads beyanı; Families doğrulama notu |
| §4 KVKK §6 | "reklam amacıyla kimseyle paylaşmıyoruz" cümlesi yeniden yazıldı; AdMob satırı; AdMob'un veri İŞLEYEN olmadığı ayrıca belirtildi; "reklamları kapatmak" paragrafı |
| §4 KVKK §11 | Tek soru silme bayat iddiası düzeltildi |
| §5 Gizlilik "Bir bakışta" | "Reklam yok, takip yok" satırı ikiye bölündü ve doğrulandı |
| §5 Gizlilik §1 | "Reklamlar hakkında" paragrafı |
| §5 Gizlilik §6 | AdMob satırı + "ödüllü reklam nasıl çalışıyor" paragrafı |
| §5 Gizlilik §8 | Tek soru silme bayat iddiası düzeltildi |
| §6 Koşullar §13 | **"Ücretli hizmetler (şu an mevcut değil)" → "Reklamlar ve ücretli hizmetler".** Reklam biçimi, izlemenin isteğe bağlılığı, kişiselleştirme yokluğu, uygunsuz reklam bildirimi, Plus'ın henüz açık olmadığı |

**`app_config.legal_version` → `1.3` yapılmalı**; onay kayıtları o değeri
damgalıyor.

---

# `app-ads.txt` içeriği

Dosya `web/app-ads.txt`'te, açıklamalarıyla. İçeriğin özü:

```
google.com, pub-<YAYINCI-KIMLIGI>, DIRECT, f08c47fec0942fa0
```

- **Yayıncı kimliği YER TUTUCU.** Gerçek değer AdMob konsolunda
  Settings → Account information → Publisher ID (`pub-` + 16 hane).
  **Yer tutucuyla yayınlamak dosyayı hiç yayınlamamaktan kötüdür**: AdMob
  doğrulamayı BAŞARISIZ sayar.
- Dosya **geliştirici web sitesinin kökünde** olmalı (`https://<alan>/app-ads.txt`)
  ve aynı alan adı **her iki mağaza listelemesinde** tanımlı olmalı
  (Play Console → Store listing → Website; ASC → App Information → Marketing
  URL). Adres girilmezse dosya yayında olsa bile OKUNMAZ.
- **Alan adı henüz yok** — hukuki metin adresleri de aynı durumda
  (`supabase.example.json` içinde `ornek.com` yer tutucuları).

---

# Mağaza formlarında değişmesi gereken cevaplar

## App Store Connect — App Privacy

| Satır | Eski | Yeni |
|---|---|---|
| `Usage Data → Advertising Data` | ❌ Toplanmıyor | ✅ **Toplanıyor** · Linked: **Hayır** · Used to Track: **Hayır** · Amaç: **Third-Party Advertising** |
| `Usage Data → Other Usage Data` | — | ❌ Hayır (ayrıştırıldı) |
| `Identifiers → Device ID` | ✅ (FCM) | ✅ **yalnızca FCM** — reklam amacı YOK, AdMob'a reklam kimliği gitmiyor |
| `Purchases` | ❌ | ❌ **değişmedi** — uygulama içi satın alma yok, Plus ekranı tanıtım |
| Tracking sorusu | HAYIR | **HAYIR (değişmedi)** |
| Privacy Choices URL | Gerekmiyor | Gerekmiyor — **ama kişiselleştirme açılırsa gerekli olur** |

## Google Play — Veri Güvenliği ve App content

| Soru | Eski | Yeni |
|---|---|---|
| Reklam kimliği kullanılıyor mu? | Hayır | **Hayır (değişmedi)** — `AD_ID` izni manifest'ten kaldırıldı. İzin geri gelirse EVET olur |
| `Uygulama etkinliği → Diğer kullanıcı eylemleri` | — | ✅ **Toplanıyor** · İsteğe bağlı · Amaç: **Reklamcılık veya pazarlama** |
| `Cihaz veya diğer kimlikler` | ✅ (push) | ✅ **yalnızca push** — reklam kimliği değil |
| Veriler paylaşılıyor mu? | Hayır | **Hayır (değişmedi)** — reklam verisi ayrı satırda beyan ediliyor |
| **App content → Ads** | — | **"Uygulamam reklam içeriyor"** işaretlenmeli; listelemede "Contains ads" etiketi görünür |
| Hedef kitle | 13-15, 16-17, 18+ | **değişmedi** — ama Families reklam SDK'sı şartı doğrulanmalı |

> ⚠️ ASC tablosu **benim çıkarımım**. Google, AdMob için önerilen App Privacy
> etiketlerini kendi belgelerinde yayımlıyor; yayından önce karşılaştırılmalı
> ve sapma varsa Google'ın listesi esas alınmalı — veriyi toplayan SDK onların.

---

# Elmas geri açma adımları

```
1. Göz kontrolü (kod değişikliği GEREKMEZ):
   flutter run --dart-define-from-file=supabase.json --dart-define=SHOW_GEMS=true

2. v2'ye almak için lib/state/features.dart — TEK SATIR:
     bool.fromEnvironment('SHOW_GEMS')
   → bool.fromEnvironment('SHOW_GEMS', defaultValue: true)

3. test/features/gems_hidden_test.dart tersine çevrilir: şu an GÖRÜNMEZ
   iddia ediyor; v2'de aynı üç iddia findsOneWidget ile.

4. deleteItemProgress metnine elmas ibaresi geri eklenir (l10n).

5. Başka hiçbir şey. GÖÇ YOK, GERİ DOLUM YOK — bakiyeler v1 boyunca
   birikti, çünkü claim_daily_goal hiç durdurulmadı.
```

Kapılanan üç çizim yeri: `today_screen.dart` (HUD hapı),
`profile_screen.dart` (rozet — **her iki dal**), `session_end_screen.dart`
(sandık kartı). `_openChest`/`_chest`/`_chestOpen` ve tüm l10n anahtarları
duruyor.

---

# Dağıtımda atlanırsa sessizce çalışmayacak adımlar

1. **Göçler `0075`–`0078` uygulanmalı.** README'ye göre üretimde göçler elle
   SQL Editor'a yapıştırılıyor; `supabase db push` **çalıştırılmamalı**.
   Sıra önemli: 0075 → 0076 → 0077 → 0078.
2. **İstemci ve göç BİRLİKTE dağıtılmalı.** `my_daily_state` `ai_quota` ve
   `ai_resets_at` sütunlarını kaybetti; eski istemci yeni görünümle HUD'u boş
   gösterir.
3. **`app_config.ad_reward_secret` girilmeli** ve aynı değer edge fonksiyonuna
   `AD_REWARD_SECRET` gizlisi olarak verilmeli. **Girilmezse ödül HİÇ
   verilmez** (fail-closed, bilinçli). Kota anahtarları girilmezse varsayılanlar
   çalışır (fail-open).
4. **`supabase functions deploy ad-reward`** ve `analyze-question`'ın yeniden
   dağıtımı. `ad-reward` dağıtılmazsa kullanıcı reklamı izler, hak gelmez.
5. **AdMob hesabı + iki platform için uygulama kaydı.** Uygulama kimliği
   manifest/plist'e girmezse **uygulama açılışta ÇÖKER**. Şu an Google'ın açık
   TEST kimliği duruyor ve Gradle bunu derleme çıktısına yazıyor.
   Gerçek değer: `-Padmob.appId=...` ya da CI'da `ADMOB_APP_ID` sırrı; iOS'ta
   xcconfig'ten `$(ADMOB_APP_ID)`.
6. **Ödüllü reklam birimi kimlikleri** `supabase.json`'a
   (`ADMOB_REWARDED_ANDROID`, `ADMOB_REWARDED_IOS`). Verilmezse reklam yolu
   arayüzde **hiç çizilmez** (sessizce, bilinçli).
7. **AdMob konsolu → ödüllü reklam birimi → sunucu tarafı doğrulama (SSV) geri
   çağrı adresi** `ad-reward` fonksiyonuna ayarlanmalı. **Ayarlanmazsa
   kullanıcı reklamı izler ama hak GELMEZ** ve hiçbir hata görünmez.
8. **AdMob konsolu → uygulama ayarları:** çocuğa yönelik muamele ve rıza yaşı
   altı ayarları, içerik derecesi `G`, hassas kategori engelleri. Koddaki
   `ageRestrictedTreatment: teen` konsol ayarının yerine GEÇMEZ.
9. **`app-ads.txt` yayınlanmalı** (geliştirici sitesi kökü) ve alan adı iki
   mağaza listelemesinde tanımlı olmalı.
10. **Play Console → App content → Ads** beyanı; **ASC → App Privacy**
    güncellemesi.
11. **`app_config.legal_version` → `1.3`.**
12. `prune_ai_calls()` ve `prune_ad_rewards()` için **zamanlanmış iş kurulmadı**
    (depoda `cleanup-anonymous` da aynı durumda). Kurulmazsa defter büyür;
    dört test kullanıcısında sorun değil.

---

# Kapsam dışında değiştirmek zorunda kaldıklarım

- **`docs/hukuki-metinler.md`'deki iki bayat iddia.** Task 08 A-8 ve A-9'u
  kapattı ama belge güncellenmedi: yayına hazır **Gizlilik §8** ve **KVKK §11**
  hâlâ *"tek bir soruyu uygulama içinden silemiyorsunuz"* diyordu, oysa
  `delete-question` ve arayüzü var. Aynı belgeyi yeniden yazarken düzeltildi
  ve iki bayrak `KAPANDI` işaretlendi.
- **`delete-account/index.ts:18` yorumu.** *"Bu depodaki TEK servis rolü
  yüzeyi"* — beş fonksiyon servis rolü anahtarını okuyor. Yorum düzeltilmedi
  (kod değişmiyor) ama 0076'nın başında gerçek durum yazılı, çünkü o paketin
  güvenlik argümanı bu öncüle dayanıyor.
- **`lib/state/game_progress.dart`** yorumları: "seviye sistemi kaldırıldı"
  bayattı (sistem var, XP'den türetiliyor) ve "can" terminolojisi geçiyordu.
- **`lib/state/app_settings.dart`, `lib/theme/app_colors.dart`** yorumlarında
  "can" geçiyordu.
- **`supabase/tests/098_function_grants.sql`** `plan(31)` → `plan(35)`: yeni
  fonksiyonların yetki iddiaları o dosyanın kanonik işi.
- **`lib/features/plus/plus_screen.dart`'ta bir layout çökmesi düzeltildi** —
  bu aslında kendi kodumdu ama widget testi yakaladı: `ListView` içindeki
  `Row(crossAxisAlignment: stretch)` "BoxConstraints forces an infinite height"
  ile ekranı çökertiyordu. `IntrinsicHeight` ile sarıldı.

**Kendi kodumda testlerin yakaladığı iki hata** (kapsam dışı değil ama
raporlanması gerekiyor): yukarıdaki layout çökmesi ve §2.4'teki sessizce yeşil
yanan CI kapısı. İkisi de yalnızca "yazdım, derlendi" ile geçerdi.

---

# Emin olmadıklarım / karar vermeniz gerekenler

| Konu | Bugünkü hâli | Not |
|---|---|---|
| **Birim AI maliyeti** | Ölçülmedi (Task 06'dan beri) | 10/50/300/1.000 tahmin. `tools/cap_model.mjs --unit <ölçüm>` ile kalibre edilmeli. Rakamlar `app_config`'te, göç gerekmiyor |
| **Anonim ömür cap'i** `auth.users` satırı başına | Çıkış yapıp yeni anonim oturum 3 hak daha veriyor | Kayıt freni sınırlıyor (IP başına 300/gün + saatte 30) → IP başına ~900 analiz/gün. **Çözülmedi, adlandırıldı.** Gerçek çözüm cihaz doğrulaması; Task 06 onu bilerek erteledi |
| **AdMob doluluk ve gelir** | Bilinmiyor | 13-18 kitlesi + `G` derecesi + kişiselleştirme kapalı + AD_ID yok → eCPM düşük. Reklamın işi gelir değil, duvara bir kapı açmak. Doluluk sorun olursa mediation eklenir |
| **Servis rolü anahtarı her edge ortamında** | Kapatılamıyor | §4.3'teki savunma kod yollarıyla ilgili, isolate yalıtımıyla değil. Raporda ve kodda olduğu gibi yazılı |
| **SSV gecikmesi** | 20 saniye yoklanıyor | Gelmezse "birazdan hesabına geçecek" deniyor. Yoklama "gelmedi" ile "reddedildi"yi **ayırt edemiyor**; istersek `ad_reward_status(nonce)` RPC'si eklenebilir |
| **Play Families reklam SDK'sı sertifikasyonu** | Doğrulanmadı | Hedef kitleye 13-15 dahil. AdMob sertifikalı ama beyan bizde (§2 A-12, madde 7) |
| **ASC "Advertising Data" etiketi** | Çıkarım | Google'ın AdMob için yayımladığı önerilen liste ile karşılaştırılmalı |
| **`SKAdNetworkItems`** | Yalnızca Google'ın kendi kimliği yazıldı | Tam liste Google'ın yayımladığı listeden kopyalanmalı. Uydurma kimlik yazmamak için liste bilinçli olarak kısa |
| **Plus fiyatları** | ₺150 / ₺1.200 **sabit** | Apple 3.1.2 ve Play yerelleştirilmiş mağaza fiyatını şart koşuyor → **abonelik task'ında yayın engeli.** Tek dosyada (`plus_plans.dart`) ve CI'da `₺` kapısı var |
| **Anonim duvarı ve `suspended` durumu** | Yazıldı | İkisi de brief/tasarımda yoktu; benim yorumum. Anonim: reklam/Plus yok, "Hesabını oluştur" var. Askılı kullanıcı sonucu kaydedemediği için hak da harcatılmıyor |
| **w2'de Kaydet düğmesinin dolgusu** | `secondary` (tam genişlik) | Brief "tekrar çarpanda Plus öne çıksın" diyor ve tasarım da öyle gösteriyor. Kaydet'in primary kalmasını tercih ederseniz tek satırlık değişiklik |
| **Ödül ve aylık cap** | Ödül yalnızca pencereyi açıyor | Onayla alınan karar. Ay doluyken reklam iki katmanda engelleniyor |
| **Defter büyümesi** | 92 gün saklama | 10.000 tam dolu ücretsiz kullanıcıda ~9M satır / ~1 GB. Şimdi sorun değil |
| **`ai_state()` görünümün sütun sırasını sabitliyor** | Kabul edildi | İleride alan eklemek yine `drop view` + `create` + `grant` gerektiriyor |
