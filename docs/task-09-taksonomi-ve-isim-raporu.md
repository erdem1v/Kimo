# Task 09 — Taksonomi tek kaynağa, uygulama adı "Kimo"

İki iş: (1) konu ağacının tek kaynağa indirilmesi, (2) kesinleşen uygulama
adının depoda eski adın geçtiği her yere işlenmesi.

**Doğrulama durumu.** Bu makinede Docker yok; pgTAP ve mutasyon süiti
**yalnızca CI'da** koşuyor. Yerelde koşan ve YEŞİL olanlar: `flutter analyze`,
`flutter test` (**200 test**), `tools/build_taxonomy.py --selftest` ve
`--check`, `tools/check_sql.py`, `check_symbols.py`, `check_imports.py`, ve
eski-ad tarama kapısı. Deno yerelde yok — edge function tip denetimi dağıtımda.

---

# BÖLÜM 1 — Taksonomi

## 1. Sorun: ağaç yedi yerdeydi, kaynağı yoktu

| # | Yer | Ne tutuyordu |
|---|---|---|
| 1 | `analyze-question/taxonomy.ts` | 434 konu (ünite katmanı YOK) |
| 2 | `lib/data/yks_curriculum.dart` | aynı 434 konu + **139 ünite** |
| 3 | `lib/data/yks_subjects.dart` | 4× ders adı listesi |
| 4 | `tools/bin/import_meb.dart` | 12 ders adı `Set` |
| 5 | `lib/widgets/mistake_style.dart` | 12 ders → renk |
| 6 | `tools/remap_konu.sql` | 265 MEB etiketi → 206 konu (elle çalıştırılan) |
| 7 | `tools/manifests/*.json` | aynı 265 MEB etiketi |
| — | **veritabanı** | **hiçbir şey** — `subject`/`concept` serbest `text` |

1 ve 2'nin içerik olarak senkron olduğunu programatik olarak doğruladım
(ders kümeleri ve konu kümeleri birebir; yalnız iki derste sıralama farkı).
Ama senkronu garanti eden tek şey `yks_curriculum.dart:5-7`'deki *"biri
değişirse diğeri de değişmeli"* yorumuydu.

`taxonomy.ts:2` kaynak olarak `YKS_TYT_AYT_Konulari.md` gösteriyordu.
**O dosya git geçmişinde hiç commit edilmemiş** (`git rev-list --all --objects`
ile doğrulandı) — ölü bir atıf, yani ağacın gerçek kaynağı doğrulanamıyordu.

## 2. Kullanıcının verdiği örnek bir içerik boşluğu ortaya çıkardı

"atışlar" ağaçta **hiç yok**. En ince Fizik kalemi `Kuvvet ve Hareket`; alt
konular parantez içine düzleştirilmiş (`Akışkanlar (Basınç)`). Arama motoru
ne kadar iyi olursa olsun o örnek bugünkü veriyle boş dönerdi.

**Karar: arama etiketleri.** Her konu kanonik adının yanında etiket taşıyor;
kullanıcı "atışlar" yazınca konu çıkıyor ama **kaydedilen değer kanonik ad
kalıyor**. Şema değişmiyor, istatistikler bölünmüyor, etiketler AI istemine
girmiyor (token maliyeti artmıyor). Aynı mekanizma yeniden adlandırmayı da
çözüyor.

**Reddedilen alternatifler.** (a) Gerçek üçüncü seviye (alt konu): şema,
istem, ilerleme görünümü ve 434 kalemin bölünmesi — çok daha büyük iş.
(b) Ağacı birkaç yüz kaleme çıkarmak: her analiz çağrısı pahalılaşırdı,
çünkü tüm liste istem metnine gömülüyor.

## 3. Mimari: iki katmanlı "tek kaynak"

```
taxonomy/yks-konulari.md          ← YAZIM kaynağı (insan düzenler, PR'da okunur)
        │  tools/build_taxonomy.py
        ├──► supabase/migrations/…_curriculum_seed.sql   (üretilen)
        └──► assets/curriculum/tree.json                 (üretilen)

VERİTABANI = ÇALIŞMA ZAMANI kaynağı
        ├──► analyze-question   (istem metni + doğrulama)
        ├──► istemci            (curriculum_tree RPC → disk önbelleği)
        └──► import_meb.dart    (ders + konu doğrulama, etiket çözümü)
```

İki katmanı ayırmak şart: istemci sunucudan çekmeli **ama** ilk açılışta ve
çevrimdışıyken konu seçemezse **soru kaydedilemez**. Gömülü yedek o yüzden
var ve o da aynı kaynaktan üretiliyor — "eski bir ağaç" değil, "o sürümdeki
ağaç".

## 4. Kaynak dosya ve üretici

`taxonomy/yks-konulari.md`: **434 konu, 139 ünite, 360 arama etiketi, 186 eski
ad.** Ağaç mevcut iki kopyadan programatik olarak çıkarıldı; etiket havuzu
`remap_konu.sql`'in 265 satırından türedi (80'i kimlik dönüşümüydü, atıldı) ve
üstüne Fizik/Matematik/Geometri/Biyoloji için öğrenci dilinde bir başlangıç
seti eklendi.

Biçim:
```
- Kuvvet ve Hareket | ara: atışlar, eğik atış, newton yasaları | eski: Vektörler, İtme ve Momentum
```

`tools/build_taxonomy.py` beş kuralı zorluyor: yinelenen konu; etiketin
**başka** bir konunun adıyla çakışması; bir etiketin iki konuya işaret etmesi;
rengi olmayan ders; boş ünite.

**Sürüm içerikten türüyor** — kanonik serileştirmenin SHA-256'sının ilk 12
hanesi. Elle yazılan bir sürüm numarası, güncellenmesi unutulduğunda sessizce
yanlış olurdu; burada **ayrışması mümkün değil**.

**İki şey uygulama sırasında yakalandı ve düzeltildi:**

- Kural ilk yazımda "etiket HİÇBİR konu adıyla çakışamaz" idi ve
  `Maddenin Hâlleri | eski: Maddenin Halleri` satırını reddetti. O satır
  şapkasız eski yazımı remap eden şeydi; silmek eski kayıtları geçersiz
  konuda bırakırdı. Kural "**başka** bir konunun adı" olarak daraltıldı ve
  selftest'e bir yanlış-pozitif karşı-iddiası eklendi.
- Etiket eşsizliği **normalize** biçimde denetlenmeli: "İvme" ile "ivme"
  veritabanında aynı satırı hedefliyor. Denetim eklenmeseydi tohum INSERT'i
  üretimde patlardı.

`--check` üretilen dosyaların kaynakla eş olduğunu doğruluyor (pubspec.lock
kapısının aynısı); `--selftest` bozuk girdiyi gerçekten yakaladığını her
koşuda kanıtlıyor — bu depoda bir denetleyici bir kez sessizce hiçbir şey
bulmama hatasına düştüğü için zorunlu bir alışkanlık.

## 5. Veritabanı (göç 0071/0072)

Üç **yalnızca-sunucu** tablo (`push_kinds` deseni: RLS açık, politika yok,
`revoke all`): `curriculum_topics`, `curriculum_aliases`, `curriculum_meta`.

| Fonksiyon | İş |
|---|---|
| `curriculum_tree(cur, known_version)` | **Tek çağrı, tek tur.** Sürüm eşleşirse ağaç GÖNDERİLMİYOR |
| `is_valid_topic(...)` | Doğrulama tetikleyicisinin kapısı |
| `resolve_topic_alias(...)` | Etiket/eski ad → kanonik konu |
| `tr_norm(text)` | Türkçe duyarlı normalizasyon (`immutable`) |
| `my_curriculum()` | JWT metadata'sından `eski`/`maarif` |

**Neden tablo açılmadı:** ağaç herkes için aynı ve statik, satır düzeyi bir
kural yok. Açık tablo yalnızca sürüm pazarlığını ve gruplamayı istemciye
bırakırdı; tek RPC ikisini de tek turda veriyor.

### `mistakes.curriculum`

Bir satır hangi ağaçtan geldiğini kaydetmiyordu. Somut sonucu:
`('Matematik','Kuvvet ve Hareket')` hem eski AYT'de hem maarif TYT'de var ve
`all_questions_screen.dart:63` bu yüzden **moderatörün kendi** müfredatına
göre doğruluyordu — maarif öğrencisinin DOĞRU kaydı, eski müfredatlı bir
moderatöre "müfredatta karşılığı yok" görünüyordu. Sütun sunucu-yazımlı
(`my_curriculum()` varsayılanı), istemciye kapalı (`lockdown_v6`).

### Yazma doğrulaması

`before insert or update` tetikleyicisi, ağaç dışı konuyu `KM022` ile
reddediyor. **Yalnızca `exam`/`subject`/`concept`/`extra_concepts` GERÇEKTEN
değişince** ateşliyor — aksi hâlde henüz temizlenmemiş eski bir satıra dokunan
her `admin_update_question` çağrısı, yani onları düzeltmek için var olan araç,
reddedilirdi.

`is_valid_topic` sınav bilinmiyorsa TYT+AYT birleşiminde arıyor: `exam`
nullable ve eski satırların çoğunda boş. Sıkı davranmak onları düzeltmeyi
imkânsız kılardı; yüzey yine kapalı (konu o dersin ağacında bir yerde olmak
zorunda) ve edge function'daki `isValidPair` zaten aynı kuralı uyguluyordu.

### AI önbelleği

`ai_cache_get/put` anahtarına taksonomi sürümü girdi. Ağaç değişince
önbellekteki eski yanıt **artık var olmayan bir konu adı** döndürüp yeni
doğrulamaya takılırdı — üstelik kullanıcı hiçbir şey yapmadan.

## 6. Edge function

`taxonomy.ts`'ten 299 satırlık veri gövdesi kalktı. Ağaç `curriculum_tree`
RPC'sinden geliyor ve isolate kapsamında **5 dakika** önbelleğe alınıyor.
Süresiz önbellek yanlış olurdu: müfredat değiştiğinde sıcak bir isolate eski
ağaçla doğrulamaya devam eder ve istemci yeni ağacı gösterirken sunucu
eskisine göre karar verir — tam da kapatılmaya çalışılan ayrışma.

Ağaç okunamazsa analiz **yapılmıyor** (503). Açık taraf sınıflandırmayı
doğrulamasız bırakırdı.

Yanıt artık `taxonomy_version` taşıyor.

## 7. İstemci

`yks_curriculum.dart` (687 satır) ve `yks_subjects.dart` silindi. Yerine
`CurriculumRepository` — `notification_lines.dart` deseninin kopyası
(depodaki tek "sunucudan çek + diske önbellekle" örneği): sürümlü prefs
anahtarı, `load()` açılışta await (ucuz, ağsız), `refresh()` ateşle-unut,
hata sessiz, boş yanıt önbelleği ezmiyor, `resetForTest()`.

**İki bilinçli fark:** sürüm pazarlığı (o desen her tazelemede tüm satırları
çekiyor; ağaç 434 konu + 546 etiket olduğu için burada "değişmedi" cevabı
alınıyor) ve `ChangeNotifier` (ağaç tazelenince açık ekranlar yenilenmeli).

### Bayat istemci — dört katman

1. `main.dart` açılışta `load()` + `unawaited(refresh())`
2. `home_shell` oturum kesinleştikten sonra ikinci `refresh()`
3. `analyzeQuestion` yanıtındaki `taxonomy_version` farklıysa **onay ekranı
   açılmadan önce** tazeliyor
4. Yine de `KM022` gelirse sebebi söyleniyor, ağaç tazeleniyor ve konu seçimi
   sıfırlanıyor

### Arama önce, menü sonra

Seçici artık ders istemiyor ve `(ders, konu)` çifti döndürüyor. Sorgu o
sınavın **tüm derslerinde**, konu adı + ünite adı + etiketlerde çalışıyor.
Türkçe normalizasyon: "ucgen" → `Üçgenler`, "atislar" → `Kuvvet ve Hareket`.
Sıralama: tam eşleşme > kelime başı > içerir; her kademede konu adı etiketten
önce, eşitlikte seçili ders önce, sonra ağaç sırası.

Eşleşme etiketten geldiyse satırda gösteriliyor — kullanıcı hem neden bu
sonucu gördüğünü hem de **kaydedilecek adın farklı olduğunu** şaşırmadan
görüyor. Sorgu boşken gezinme yolu duruyor, sadece varsayılan değil.

## 8. Araçlar

`import_meb.dart`'taki elle yazılmış 12 ders adı `Set`'i (dördüncü kopya)
gitti; araç ağacı üretilen varlıktan okuyor. **Konu da artık doğrulanıyor** —
eskiden yalnızca `subject` bakılıyordu ve MEB etiketi ham hâliyle veritabanına
girip `remap_konu.sql` elle çalıştırılana kadar haritada hiçbir konuya
düşmüyordu. Çözemezse **duruyor**.

`tools/remap_konu.sql` silindi (269 satır): 265 eşlemesi ağacın `eski:`
etiketlerine taşındı ve remap `UPDATE`'lerini artık üretici yazıyor.

`mistake_style.dart` ders→renk tablosu **kaldı** (tasarım token'ı veriye
taşınmaz); üretici her dersin bir rengi olduğunu doğruluyor.

## 9. Testler

**Dart (16 yeni):** gömülü yedeğe düşme (ilk açılış + çevrimdışı, kaydetme
yolunun kapanmadığı iddiası), bozuk önbelleğin seçiciyi kilitlememesi,
önbelleğin yedeğin önüne geçmesi, `trNorm`'un SQL ile aynı sonucu vermesi,
"atislar"/"ucgen" aramaları, sıralama, seçili dersin öne alınması, ve **aranan
her sonucun geçerli bir konu olması**.

**pgTAP `290_curriculum.sql` (25 iddia):** tablolar kapalı; tohum yüklü ve
hiçbir (müfredat, sınav) hücresi boş değil; sürüm eşleşince ağaç
gönderilmiyor; etiket çözümü; `KM022` reddi; **aşırı kilitleme
karşı-iddiaları** — geçerli konu hâlâ ekleniyor, konusuna dokunulmayan eski
satır güncellenebiliyor ama konuyu DEĞİŞTİRMEK geçerli bir konuya inmek
zorunda.

**Mutasyonlar:** `28_curriculum_open` (tabloları açar), `29_topic_check_off`
(tetikleyiciyi düşürür — Task 09 öncesi davranışın ta kendisi; hiçbir şey
patlamaz, ayırt eden tek şey 290).

**Fikstür yan etkisi.** Doğrulama, 12 test dosyasındaki 28 uydurma konuyu
(`'Tarih'/'a1'`, `'Fizik'/'Kuvvet'`) reddediyordu. Onları gerçek adlara
çevirmek testleri okunmaz yapardı; `seed.sql`'e `tests.skip_topic_check()`
eklendi. **Kritik neden:** `270_sanctions` askıdaki kullanıcının INSERT'inin
`42501` ile reddedildiğini iddia ediyor; BEFORE tetikleyicisi RLS'ten önce
çalıştığı için doğrulama açıkken o satır `KM022` ile düşer ve test **askıyı
değil konuyu ölçmeye başlar** — sessizce yanlış bir şeyi kanıtlayan bir test.
`290` bu yardımcıyı çağırmıyor.

---

# BÖLÜM 2 — Uygulama adı "Kimo"

Mağaza listelemesi **"Kimo: AI YKS"**, uygulamanın adı **"Kimo"**.

## Değişen her yer

### 1. Görünen ad

| Dosya | Eski → Yeni |
|---|---|
| `lib/l10n/app_tr.arb` | `appTitle`: "AI YKS Coach" → **Kimo** |
| `android/…/AndroidManifest.xml:21` | `android:label` → **Kimo** |
| `ios/Runner/Info.plist:10,18` | `CFBundleDisplayName` → **Kimo**, `CFBundleName` → **kimo** |
| `web/index.html` (3), `web/manifest.json` (3) | başlık / açıklama / kısa ad |
| `supabase/functions/send-push/index.ts:224` | yedek bildirim başlığı → **Kimo** |
| `lib/app.dart`, `lib/main.dart` | `AiYksCoachApp` → `KimoApp` |

**Sunucu tarafı zaten doğruydu:** `persona_lines.sql:388` başlığı
`coalesce(v_title, 'Kimo')` ile veriyor. Yalnız edge function yedeği eski adı
taşıyordu — yani gerçekten görülen tek durum, veritabanı başlığının
okunamadığı hâl.

### 2. Paket kimliği

İki platform **birbirinden farklıydı**: Android `com.stratejico.ai_yks_coach`,
iOS `com.stratejico.aiYksCoach`. İkisi **`com.stratejico.kimo`** oldu.
`build.gradle.kts` (namespace + applicationId), Kotlin paketi ve dizini,
`project.pbxproj` (6 yer), `docs/ios-kurulum.md`.

### 3. Dart paket adı

`pubspec.yaml` `name: kimo`; 24 dosyadaki `package:ai_yks_coach/…` importları
ve `tools/check_imports.py`'deki `PACKAGE` sabiti.

### 4. Belgeler

`docs/hukuki-metinler.md` **1.1 → 1.2**: yedi `[uygulama adı]` yer tutucusu
dolduruldu, **B-12 bayrağı kapandı**. Hükümlerde değişiklik yok — bu bir
*tamamlama*. `README.md`, `.env.example`.

**`docs/task-01..08` raporlarına dokunulmadı**: tarihli kayıtlar, geçmişi
yeniden yazmak yanlış olur.

## Doğrulama: iddia değil kapı

CI'ya bir tarama adımı eklendi (`ci.yml`, `static` işi). İki muafiyeti var:

- `docs/task-*.md` — tarihli raporlar
- `supabase/migrations/*.sql` — **uygulanmış** göçler: `send_push` üç kez
  `create or replace` edildi ve eski gövdeler geçmişte eski adı yazıyor;
  grep hangisinin YÜRÜRLÜKTE olduğunu bilemez

O soru katalogdan soruluyor: `240_persona.sql` artık **canlı fonksiyon
gövdelerinde ve `push_kinds` başlıklarında** eski adın geçmediğini iddia
ediyor — grep'ten güçlü bir kontrol.

Kapının deseni kendi satırını yakalamıyor: ayırıcı isteğe bağlı olduğu için
tek desen üç varyantı da kapsıyor ve ayrı bir "bitişik" alternatif (literal
olurdu) gereksiz.

---

# Dağıtımda atlanırsa sessizce çalışmayacak adımlar

1. **Firebase'de İKİ uygulamayı yeni paket kimliğiyle (`com.stratejico.kimo`)
   yeniden kaydedin** ve `google-services.json` / `GoogleService-Info.plist`
   dosyalarını yenileyin; CI'nın `GOOGLE_SERVICES_JSON` sırrı da güncellenmeli.
   Atlanırsa **push bildirimleri HATA VERMEDEN gelmez** — listenin en sessiz
   maddesi.
2. **`app_config.legal_version` = `1.2`.** `accept_legal_terms()` onay
   defterine sürümü SUNUCUDAN yazıyor; atlanırsa yeni onaylar 1.1 damgasıyla
   kaydedilir.
3. **Taksonomi göçleri sırayla uygulanmalı:** `0071` (şema) → `0072` (tohum) →
   `0073` (lockdown v6) → `0074` (kapı). Tohum ÜRETİLEN bir dosya; müfredat
   değişince yerinde güncelleniyor ve **üretime yeniden yapıştırılması
   gerekiyor** (göçler elle uygulanıyor — README).
4. **`supabase functions deploy analyze-question`** — ağacı artık
   veritabanından okuyor. Eski sürüm ayakta kalırsa gömülü eski ağaçla
   doğrulamaya devam eder ve hiçbir hata görünmez.
5. **Mağaza listeleme adı "Kimo: AI YKS"** — Play Console ve App Store
   Connect'e elle yazılan bir alan, kodda karşılığı yok.
6. **Göç öncesi kontrol:**
   `select count(*) from public.mistakes where concept not in (select topic from public.curriculum_topics);`
   Tohumun remap'i çoğunu çözüyor; kalan satırlar geçersiz konuda kalır
   (yerinde durur, ama düzenlenmeleri geçerli bir konuya inmelerini gerektirir).

# Kapsam dışında değiştirmek zorunda kaldıklarım

- **`admin_all_questions` yeniden tanımlandı** — listeye `curriculum` eklendi;
  yönetici doğrulamasının doğru ağaca bakması buna bağlıydı.
- **`seed.sql`'e iki test yardımcısı** (`skip_topic_check`; `age_all_users`
  Task 08'den) ve 13 test dosyasına birer çağrı.
- **`lib/_archive/map/curriculum_map_screen.dart`** — silinen `YksCurriculum`'a
  bakıyordu; arşiv derlemeye girmiyor ama içe aktarmaları çalışır tutuldu ki
  geri taşıma saf bir dosya taşıması olarak kalsın.
- **`tools/README.md`** — "concept `yks_curriculum.dart` ile birebir aynı
  olmalı" iddiası zaten yanlıştı (manifestlerin çoğu ağaçta yoktu); düzeltildi.

# Açık iş olarak kalanlar

- **İlerleme anahtarı hâlâ ham metin** (`'$subject|$concept'`,
  `progress_repository.dart:115`). `eski:` remap'i yeniden adlandırmayı
  çözüyor ama kararlı bir konu kimliği (slug) getirmiyor.
- **Etiket havuzu büyütülebilir.** Mekanizma bitti; 546 etiket var (265'i MEB
  adlarından, kalanı dört dersin başlangıç seti). Kalanı **veri** — kod
  değişikliği gerektirmiyor.
- **`due_count` üç kopya** (Task 08'den devreden).
- **Alt konu seviyesi yok** — parantezli adlarla düzleştirilmiş durumda.

# Emin olmadıklarım / karar vermeniz gerekenler

| Konu | Bugünkü hâli | Not |
|---|---|---|
| **`auth.jwt()`** | `my_curriculum()` onun üstünde | Bu depoda ilk kez kullanılıyor. Çalışmazsa `mistakes.curriculum` hep `eski` olur ve maarif satırları yanlış ağaca karşı doğrulanır. CI'da `290`'ın "satır kendi müfredatını taşıyor" iddiası bunu yakalar |
| **`curriculum_tree`'nin iç içe jsonb sorgusu** | Yerelde çalıştırılamadı | Yapısal olarak gözden geçirildi; ilk gerçek koşusu CI'da |
| **Isolate önbelleği 5 dk** | Ölçüm yok | Müfredat değişiminden sonra en fazla 5 dakika bayat doğrulama; kısaltmak her istekte bir RPC demek |
| **`profiles_by_ids` 60 sınırı** | Task 08'den | Değişmedi |
