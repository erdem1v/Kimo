# Task 02 — Yeni arayüz ve ürün yapısı

**Durum: sekiz dalganın hepsi yazıldı. Hiçbiri çalıştırılmadı.**

Planda sekiz dalga ve 40–50 mühendis-günlük bir tahmin vardı. Sekizi de
yazıldı: tasarım sistemi ve bileşen iskelesi (§1), kabuk/navigasyon ve havuzun
arşive alınması (§2), sunucu (§3), çekirdek döngü (§4), Bugün ve Hatalarım
(§5), Lig/Arkadaşlar/Gelen kutusu (§6), onboarding ve yaş kapısı (§7), profil
ve ayarlar (§8), kapanış (§9).

**Ama "yazıldı" ile "çalışıyor" aynı şey değil.** Bu makinede Flutter, Supabase
CLI, Docker ve Deno yok; hiçbir satır derlenmedi, hiçbir göç uygulanmadı,
hiçbir test koşmadı. §0 bunun ne anlama geldiğini ve yerelde ne
doğrulanabildiğini yazıyor; §14 dalgaların içinde yarım kalanları sayıyor.

**Hiçbir şey commit edilmedi, hiçbir şey GitHub'a gönderilmedi** (talimatınız).

---

## 0. Doğrulama durumu — önce bu

Bu makinede `flutter`, `dart`, `supabase`, `docker`, `psql`, `deno` **yok** ve
kurulmaması sizin kararınızdı. Dolayısıyla:

- **Hiçbir Dart kodu derlenmedi.** `flutter analyze` ve `flutter test`
  çalıştırılmadı.
- **Hiçbir göç uygulanmadı.** `supabase db reset` ve `supabase test db`
  çalıştırılmadı.
- **Hiçbir edge fonksiyon çalıştırılmadı.** TypeScript derlenmedi.
- Aşağıda hiçbir yerde "doğrulandı" demiyorum; "hangi test neyi iddia ediyor"
  ve "yerelde ne kontrol edilebildi" diyorum.

Yerelde gerçekten çalıştırılabilenler:

| Araç | Ne yapıyor | Sonuç |
|---|---|---|
| `tools/check_imports.py` | Dart için kullanılmayan/kırık import + ayraç dengesi. Metin ve yorumları gerçek bir sözcük tarayıcısıyla ayıklıyor (dize interpolasyonu dâhil). | 77 dosya, **0 sorun** |
| `tools/check_symbols.py` | Var olmayan tasarım token'ı / ikon / enum değeri erişimi (`Gap.*`, `Radii.*`, `Sizes.*`, `Motion.*`, `KimoIcons.*`, `BadgeTone`, `KimoReaction`, `KimoMood`, `MistakeType`, `League`, `context.c`, `context.t`). | 77 dosya, **0 sorun** |
| `tools/check_sql.py` | Göçlerde dolar-tırnak ve ayraç dengesi, beyaz listedeki her fonksiyonun yaratılmış olması, **kapıdan sonra yaratılan fonksiyon**, pgTAP `plan(n)` ile gerçek iddia sayısının eşleşmesi. | 51 göç + 21 test dosyası, **0 sorun** |
| ARB çapraz kontrolü | Her `l.<anahtar>` çağrısının `app_tr.arb`'de karşılığı var mı, arite (getter/fonksiyon) tutuyor mu, yetim `@meta` ya da ölü anahtar kaldı mı. | 285 mesaj, **0 uyuşmazlık** |
| SVG yol ayrıştırıcısının Python portu | 29 ikon yolunu birebir aynı matematikle çözüp sınırlarını ölçüyor. | 29/29 geçti, ızgara dışına taşma 0,0000 birim |

### Bu araçların kendisi de yanıldı — iki kez, aynı şekilde

Bir kabuk here-doc'u Python kaynağındaki ters eğik çizgiyi yiyip yerine `0x08`
(backspace) koydu. Sonuç iki denetleyicide de **sessiz başarısızlık**:

- `check_symbols.py`: `\b%s\.` deseni bozuldu; denetleyici **hiçbir şey
  bulamıyor ama "sorun: 0" diyordu**. Kasıtlı olarak uydurma bir token
  yerleştirilip yakalamadığı görüldü.
- `check_imports.py`: `r'^extension\b'` bozuldu; uzantı dosyalarını tanıyan kod
  hiç çalışmadı ve `context.c` için gereken bir import "kullanılmıyor" diye
  işaretlendi — az kalsın silinecekti.

İkisi de düzeltildi ve artık **`--selftest`** taşıyorlar; CI'da ana taramadan
**önce** koşuyorlar. `check_imports.py`'ın selftest'i ayrıca `tools/*.py`
dosyalarını kontrol karakteri için tarıyor, yani bozulmanın örneğini değil
**sınıfını** yakalıyor. Bir denetleyicinin sessizce hiçbir şey yapmaması,
denetleyicinin hiç olmamasından kötüdür.

Üç betik de CI'da ayrı bir `static` işinde koşuyor
(`.github/workflows/ci.yml`) — Flutter SDK indirmeden, saniyeler içinde.

### Yine de analiz yerine geçmiyorlar

Ne yakalayamayacaklarını biliyorum: tip hataları, null güvenliği, Flutter API
imzaları, SQL anlambilimi, RLS davranışı, TypeScript. Kabul kriteri hâlâ
**CI'ın yeşil olması** ve CI bugüne kadar hiç koşmadı.

Buna karşılık iki tur **çekişmeli kod incelemesi** yapıldı (çok ajanlı; her
bulgu bağımsız bir ajan tarafından çürütülmeye çalışıldı). İlk tur 22, ikinci
tur 2 doğrulanmış bulgu üretti; hepsi düzeltildi. Ayrıntı §13'te.

---

## 1. Dalga 0 — tasarım sistemi ve bileşen iskelesi

### 1.1 Tasarım token'ları

**Ne yapıldı.** `lib/theme/tokens.dart` içinde `KimoColors` adlı bir
`ThemeExtension` kuruldu: 30 semantik rol (zemin, kart, oyuk, mürekkep,
mercan/bal/nane üçlüsü ve tint'leri, sekme çubuğu, kamera düğmesi) açık ve
koyu tema için ayrı ayrı tanımlı. Renk değerleri onaylanan Tur 4 tasarımının
HTML'inden birebir çıkarıldı. Yanında `Gap` (4 tabanlı aralık), `Radii`
(13/16/18/20/22/24), `Sizes` (buton 58, satır 52, ikon 44, kabartma 5/4) ve
`Motion` (süreler ve eğriler). Erişim `context.c` / `context.t` uzantılarıyla.

**Neden bu yaklaşım.** Alanlar `required`: bir rolün koyu tema karşılığı
unutulursa **derleme hatası** alınıyor. Reddedilen alternatif, `AppColors`
gibi düz bir sabit sınıfıydı — mevcut palet öyle ve tam da bu yüzden koyu tema
hiç eklenememişti: hangi sabitin koyu karşılığının olmadığını söyleyen bir
mekanizma yoktu.

**Değişen dosyalar.** `lib/theme/tokens.dart` (yeni),
`lib/theme/typography.dart` (yeni), `lib/theme/app_theme.dart` (yeniden).

**Nasıl doğrulandı.** `test/theme/tokens_test.dart` — her rolün açık/koyu
değerini tasarımdaki HEX'e karşı sabitliyor; zemin ile kartın, oyuk ile kartın
ayrıştığını; `lerp`in iki paleti karıştırabildiğini; her iki temanın da
uzantıları taşıdığını iddia ediyor.

**Ne değişmedi.** `lib/theme/app_colors.dart` duruyor. Henüz yeniden
yazılmamış ekranlar onu kullanıyor; son dalgada silinecek.

### 1.2 Tipografi ve yazı tipleri

**Ne yapıldı.** Baloo 2 (500/600/700) ve DM Sans (400/500/600/700)
`assets/fonts/` altına gömüldü ve `KimoTypography` uzantısıyla 17 semantik role
bağlandı. Bütün sayaç rolleri `FontFeature.tabularFigures()` taşıyor.

**Neden bu yaklaşım.** Fontlar Google Fonts'un **latin + latin-ext**
altkümesinden alındı: tam sürüm 1,4 MB, altküme **444 KB**. `google_fonts`
paketi reddedildi — çalışma anında indirme yapıyor ve hedef kitle düşük
donanımlı, bağlantısı zayıf Android'de.

**Nasıl doğrulandı.** İndirilen yedi TTF'in `cmap` tablosu Python'la
ayrıştırıldı ve 12 Türkçe glifin (ğĞşŞıİçÇöÖüÜ) **her ağırlıkta** var olduğu
tek tek ölçüldü. `tools/check_imports.py` bir kardeş kontrolle pubspec'teki
aile adlarının (`Baloo2`, `DMSans`) kodda kullanılanlarla aynı olduğunu
doğruluyor.

**Ne değişmedi — ve bu bilinçli.** `ThemeData.fontFamily` **atanmadı**. Atansa
henüz yeniden yazılmamış ekranlardaki çıplak `TextStyle`'lar da DM Sans'a
düşerdi ve o ekranlarda 96 yerde kullanılan `FontWeight.w800` ailede olmayan
bir ağırlığa denk gelirdi. Küresel atama son dalgada, bütün ekranlar
taşındıktan sonra.

### 1.3 Koyu tema ve tema tercihi

**Ne yapıldı.** `AppTheme.dark()` eklendi; `MaterialApp` artık `theme`,
`darkTheme` ve `themeMode` taşıyor. Varsayılan **`ThemeMode.system`**: cihaz
koyu moddaysa uygulama koyu açılıyor. Tercih `lib/state/app_settings.dart`
içinde `SharedPreferences`e yazılıyor ve `main()` içinde **ilk kareden önce**
okunuyor.

**Neden bu yaklaşım.** Tercih `main()`de okunmasaydı koyu mod seçmiş kullanıcı
bir kare beyaz görürdü. `AppTheme.light()/dark()` **static final** olarak bir
kez kuruluyor: her çağrıda yeni bir `ThemeData` üretmek, `AppSettings`in her
bildiriminde (ör. ses anahtarı) `AnimatedTheme`in 200 ms'lik bir geçiş
başlatmasına yol açıyordu — bunu inceleme turu yakaladı.

**Nasıl doğrulandı.** `test/state/app_settings_test.dart` (10 iddia) ve
`test/widget_test.dart` — varsayılanın `system` olduğunu, seçimin diske
yazıldığını, bozuk değerin sisteme düştüğünü, aynı değeri yeniden atamanın
gereksiz yeniden çizim üretmediğini iddia ediyor.

**Yan kazanç.** `sound.enabled` artık kalıcı. Önceden yalnızca bellekteydi,
yani her açılışta kendiliğinden açılıyordu — bir ayar anahtarının yapmaması
gereken tam olarak buydu.

### 1.4 Bileşen kütüphanesi ve ikon dili

**Ne yapıldı.** `lib/widgets/kit/` altında: `KimoButton` (5px sert kabartma,
basınca 4px iniş, üç tür), `KimoCard`/`SectionHeader`/`EmptyState`/`SizedPhoto`,
`KimoChip`/`StatusBadge`/`SegmentedTabs`, `SegmentRing`/`KimoProgressBar`/
`HudPill`, `KimoNavBar`, ve **kendi SVG yol ayrıştırıcısı** üzerine kurulu
15 ikonluk bir katalog.

**Neden kendi ayrıştırıcı.** Tasarımın ikon dili "1,8–2px kontur, yuvarlak uç,
dolgusuz, 24px ızgara" diye tanımlı ve her ikonun yol verisi tasarım
dosyasında birebir mevcut. Material ikonları o geometriye uymuyor. Bir SVG
paketi eklemek `pubspec.lock`u değiştirir ve çalışma anı ayrıştırma maliyeti
getirir; yollar bir kez `Path`e çevrilip önbelleğe alınıyor.

**Nasıl doğrulandı.** `test/widgets/svg_path_test.dart` — sayı dilbilgisi
(`1.2.8` iki sayıdır, `0-7.2` iki sayıdır, üstel gösterim), örtük komut
tekrarı, göreli komutlar, yay→Bézier dönüşümü ve **katalogdaki 29 yolun
tamamının** 24 birimlik ızgarada kaldığı. Ayrıştırıcı Python'a birebir
portlandı ve gerçek veriyle çalıştırıldı.

**Bu sırada bulunan iki gerçek hata:**
1. Sayı okuyucu açgözlüydü: SVG'de `1.2.8` **iki** sayıdır (`1.2` ve `.8`) ve
   alev ikonu tam olarak bu yüzden hiç çizilmiyordu.
2. Yay parçalama bıçak sırtındaydı: tam yarım çemberde `acos` π'yi 2·10⁻⁸
   kadar aşıyor, oran 2,00000002 çıkıyor ve `ceil` 2 yerine **3** parça
   üretiyordu. Sonuç yalnızca fazladan bir parça değil: 60'ar derecelik
   parçaların kontrol noktaları eksenlerle hizalanmadığı için çemberin sınır
   kutusu her yönde ~%4 büyüyordu. `1e-6` toleransla düzeltildi (`1e-9`
   yetmiyordu — inceleme turu bunu ayrıca ölçtü).

**Bilinçli bir kısıt.** `HudPill` `Expanded` DÖNDÜRMÜYOR; satırdaki payı
çağıran belirliyor. Widget'ın kendini `Flex`e mecbur bırakması onu `Row`
dışında kullanılamaz hâle getirirdi.

### 1.5 Maskot Kimo

**Ne yapıldı.** Tasarımın iki katmanlı animasyon sözleşmesi kod olarak kuruldu:
- `lib/widgets/kimo/kimo_pose.dart` — **saf** poz çözücü. Girdi geçen süre,
  çıktı tek karelik poz. Katman A (nefes 3,4 sn · göz kırpma 90 ms/5 sn ·
  kulak seğirmesi 260 ms/6 sn · bakış 2,2 sn/7 sn) ve Katman B (6 tepki,
  tasarımdaki sürelerle), 80 ms giriş / 160 ms çıkış karışımı, öncelik
  `levelUp > chestOpen > streakUp > correct|wrong > tap`, gece modu, tarama
  durumu, `reduceMotion` ve 40px eşiği.
- `lib/widgets/kimo/kimo_painter.dart` — tasarımın SVG geometrisiyle birebir
  (kulak `r30/r15` @ (96,44)/(204,44), kafa `rx88 ry78` @ (150,118), ağız
  bölgesi `rx50 ry37` @ (150,150), gözler `r11` @ (112,106)/(188,106),
  parlama `r3.6`, burun `rx15 ry11`).
- `lib/widgets/kimo/kimo.dart` — `Ticker` sürücüsü ve `KimoController`.

**Neden bu yaklaşım.** Tasarım üretim varlığı olarak tek bir `.riv` öngörüyor
(≤60 KB, 300×330 artboard) **ama o varlık henüz üretilmedi**. Kimo şimdilik
kodla çiziliyor; widget'ın dış yüzeyi (`mood`, tetikler, `reduceMotion`)
bilerek Rive sözleşmesiyle aynı, böylece varlık geldiğinde yalnızca bu
dosyanın içi değişecek, çağıran ekranlar değişmeyecek.

Zaman mantığının saf bir çözücüye ayrılması, animasyonun **cihaz olmadan test
edilebilmesi** için. Reddedilen alternatif, `AnimationController` zincirleriydi:
davranış widget ağacına gömülü kalır ve sözleşmenin (öncelik, karışım süreleri)
doğruluğu ancak gözle kontrol edilebilirdi.

**Nasıl doğrulandı.** `test/widgets/kimo_pose_test.dart` (21 iddia) — tepki
süreleri, öncelik sırası, **düşük öncelikli tetiğin kuyruğa alınmayıp
atıldığı**, eski sıra numarasıyla bitirmenin yok sayıldığı, nefesin periyodu,
gecede yavaşladığı, 40px altında zıplamanın kapandığı ama nefesin sürdüğü,
`reduceMotion` açıkken pozun zamanla değişmediği, tepkinin başında ve sonunda
boşta pozuna eşit olduğu (sert kesme yok) ve **yanlış cevapta sarsıntı/dönüş
üretilmediği**.

**İnceleme turunun yakaladığı iki yaşam döngüsü hatası:**
1. `reduceMotion` açıkken `Ticker` durduğu için `endReaction` hiç
   çağrılmıyordu; tetiklenen tepki **sonsuza kadar takılı** kalıyordu. Artık
   o durumda bir `Timer` bitiriyor.
2. `initState` dışarıdan gelen bir denetleyicinin sıra numarasını
   senkronlamıyordu; mount anında uçuşta olan bir tepki hiç bitmiyordu.

### 1.6 Yerelleştirme altyapısı

**Ne yapıldı.** `l10n.yaml` + `lib/l10n/app_tr.arb` + `pubspec.yaml`'a
`generate: true`. Üretilen sınıf `L10n`, çıktı `lib/l10n/generated/`
(gitignore'lu — `flutter pub get` her seferinde üretiyor).
`supportedLocales` artık **yalnızca `tr`**.

**Neden.** İngilizce hiç çevrilmemişti ama `supportedLocales`te ilan
ediliyordu: İngilizce bir cihazda kullanıcı yine Türkçe görüyordu. Bu bir
hataydı, ilan kaldırıldı.

**Ne değişmedi.** ~1.300 gömülü Türkçe metnin büyük çoğunluğu hâlâ kodda.
`.arb` şu an yalnızca kabuk ve ortak eylem metinlerini taşıyor (20 anahtar).
Taşıma her ekranın yeniden yazımıyla birlikte yapılacak — plan bunu böyle
kuruyordu ve o dalgalar yapılmadı.

---

## 2. Dalga 1 — kabuk, navigasyon ve havuzun arşivlenmesi

### 2.1 Navigasyon

**Ne yapıldı.** Sekmeler **Bugün · Hatalarım · (kamera) · Lig · Profil**.
Kamera bir sekme değil, ortada duran kalıcı eylem: 58×58, `radius 22`, çubuğun
12px üstüne taşıyor ve bastığında bulunduğun sekmeyi değiştirmeden fotoğraf
ekranını açıyor.

**Neden bu yaklaşım.** Taşan 12px `Transform` ile DEĞİL, satır yüksekliği
12px artırılıp sekmeler alta hizalanarak elde edildi. Kaydırma yaklaşımında
düğmenin üst 12px'i isabet testine girmiyordu — görünüyor ama tıklanmıyordu.

**Değişen dosyalar.** `lib/features/home/home_shell.dart` (yeniden),
`lib/widgets/kit/kimo_nav_bar.dart` (yeni),
`lib/services/notification_router.dart` (`tabSocial` → `tabLeague`).

**Nasıl doğrulandı.** `test/widget_test.dart` yeniden yazıldı: sekme
etiketlerinin tam listesi, sekmeler arası geçiş, kaldırılan sekmelerin geri
gelmemesi, varsayılan temanın sistem olması ve `supportedLocales`in tek dil
taşıması.

### 2.2 Sahte "Koç" sekmesi silindi

**Ne yapıldı.** `lib/features/chat/chat_screen.dart` **silindi** (arşivlenmedi).
Yanında `MockData.coachReplies` / `quickReplies` / `initialChat` ve artık
kullanılmayan `ChatMessage`, `PracticeQuestion`, `AchievementBadge`,
`TopicCard` modelleri de gitti.

**Neden.** Ekran anahtar kelime eşleşmesiyle dört hazır cevaptan birini
seçiyor ve 950 ms sahte gecikme koyup "yazıyor" animasyonu gösteriyordu. Hiçbir
ağ çağrısı yoktu. Task "sahte bir sekme, yeniden tasarlanmış hâliyle bile
kalmasın" diyor.

**Ne değişmedi.** Maskot adı zaten koddaki tek yerde (`Koç Baykuş`, 🦉) o
ekrandaydı ve onunla birlikte gitti. Kod tabanındaki maskot adı **Kimo** ve
öyle kalıyor; tasarımda geçen "Kestane" hiçbir yerde kullanılmadı.

### 2.3 Havuz arşive alındı

**Ne yapıldı.** Beş dosya `lib/_archive/` altına taşındı, rotalar kesildi,
`analysis_options.yaml`'a `lib/_archive/**` istisnası eklendi. İçe aktarmalar
`package:ai_yks_coach/...` biçimine çevrildi ki geri taşıma saf bir dosya
taşımasına insin. Geri açma adımları `lib/_archive/README.md`'de.

**Arşivlenen dosyalar:**

| Yeni yer | Eski yer |
|---|---|
| `lib/_archive/pool/solve_pool_screen.dart` | `lib/features/pool/solve_pool_screen.dart` |
| `lib/_archive/pool/report_question_sheet.dart` | `lib/features/pool/report_question_sheet.dart` |
| `lib/_archive/pool/public_question.dart` | `lib/models/public_question.dart` |
| `lib/_archive/pool/pool_repository.dart` | `lib/data/question_pool_repository.dart`'ın havuz yarısı |
| `lib/_archive/map/curriculum_map_screen.dart` | `lib/features/map/curriculum_map_screen.dart` |

**Konu haritası neden arşivde.** Yeni beş sekmede yeri yok (tasarımda
"Kapsama/Harita" ekranı bulunmuyor) ve rozetleriyle "Soru çöz" butonları
doğrudan havuza bağlıydı. Kararı siz verdiniz.

**Depo ikiye ayrıldı.** `question_pool_repository.dart` tek dosyada hem havuzu
hem arkadaşa göndermeyi taşıyordu ve bu yüzden "havuz kalkınca gönderim de
kalkar" sanılıyordu. Arkadaşa gönderme
`lib/data/question_send_repository.dart` olarak **üründe kaldı**; ekranları da
yanıltıcı `features/pool/` klasöründen `features/inbox/`e taşındı.

**SQL'e dokunulmadı.** `public_questions`, `random_public_questions`,
`random_questions_by_topic`, `available_question_counts`, `submit_pool_answer`,
`question_attempts`, `mistakes.is_public`, `set_question_sharing` yerinde.
İstemci çağırmadığı sürece zararsızlar. Bunları düşürmek `public_questions`
görünümüne bağlı üç fonksiyonu da düşürürdü (bkz. göç `20260901001000`).

**11.000 kurumsal soru silinmedi**, yalnızca erişim kesildi. Veriler,
fotoğrafları, sistem hesabı ve `tools/` altındaki içe aktarma aracı olduğu gibi
duruyor.

**Havuz arayüzden şu yerlerden de çıkarıldı:** ayarlardaki "Sorularımı havuzda
paylaş" anahtarı, karşılama akışındaki paylaşım onayı adımı, yönetici
ekranındaki "Havuzda"/"Özel" süzgeçleri ve "Havuza geri al"/"Havuzdan çıkar"
düğmelerinin metinleri (aksiyonlar kaldı, artık "Yayına geri al"/"Yayından
kaldır"), `mistakeRepository.add(isPublic:)` çağrısı (sabit `false`).

### 2.4 Ölü göstergeler kaldırıldı

**Ne yapıldı.** `GameProgress.hearts` (hep 5) ve `gems` (hep 0) alanları ve
`TopStatsBar`daki karşılıkları kaldırıldı; çağrısız `HeartsRow` ve profildeki
`MockData.badges` ızgarası (3 kazanılmış / 3 kilitli, tamamı uydurma) da.

**Neden şimdi.** Bu göstergelerin gerçek karşılıkları Dalga 2'de kuruldu ve
yeni HUD Dalga 4'te gelecek. Aradaki iki dalga boyunca çalışmayan bir sayaç
göstermek, task'ın "ürünün geçmişteki hatası" dediği şeyin ta kendisiydi.
Ara durumların her birinde dürüst olmak için şimdi kaldırıldılar.

---

## 3. Dalga 2 — sunucu

Onbir yeni göç (`20260902000100`–`20260902001100`), altı yeni tablo/görünüm,
otuza yakın yeni fonksiyon. Hepsi Task 01'in güvenlik modeline oturuyor:
`user_id` parametresi alan RPC yok, yeni sütun kilitli doğuyor, yeni tablo
RLS'siz doğmuyor, her paket kendi `EXECUTE` beyaz listesi kapısını yazıyor.

### 3.1 Can — günlük yapay zekâ okutma hakkı

**Ne yapıldı.** `rate_limits` tablosu (kullanıcı × kova × pencere → sayaç,
sunucu-özel), `consume_ai_use()` RPC'si ve `my_daily_state` görünümü. Günde 5
hak, **Europe/Istanbul** gün anahtarıyla.

**Neden bu yaklaşım.** Kalan hak **saklanmıyor, türetiliyor**: gün değişince
o günün satırı yok demek ve sayaç kendiliğinden sıfırdan başlıyor. Cihaz
saatini ileri alan kullanıcı ek hak alamıyor ve istemcide hiçbir zamanlayıcı
yok. Yarış koşulu tek ifadede kapatıldı
(`on conflict do update ... where n < kota`): önce-oku-sonra-yaz yapılsaydı iki
eşzamanlı çağrı aynı değeri okuyup ikisi de hak alırdı.

Hak bitince **istisna atılmıyor**, `allowed = false` dönüyor. Hak bitmesi bir
hata değil, beklenen bir ürün durumu; istisna atılsaydı edge fonksiyonun onu
ayırt etmesi ve istemcinin hata mesajı ayrıştırması gerekirdi.

**Reddedilen alternatif:** `profiles.hearts` sütununu canlandırmak. Sütun
"kalan hak" semantiğiyle duruyordu ama gün dönümünde sıfırlanması için ya bir
zamanlanmış iş ya da her okumada bir tarih karşılaştırması gerekiyordu; sayaç
+ gün anahtarı ikisini de gereksiz kılıyor. Sütun düşürüldü.

**Yan kazanç.** Task 01'in açık bulgusu #7 kapandı: `analyze-question` edge
fonksiyonunun kişi başı sınırı yoktu ve OpenAI maliyeti doğrudan bize
yazılıyordu. Artık her çağrı önce bu sayaçtan geçiyor.

**Nasıl doğrulandı.** `supabase/tests/100_ai_quota.sql` (20 iddia): sayacın
okunamadığı/yazılamadığı, üzerinde hiç politika olmadığı, gün başında 5 hak
olduğu, her kullanımda azaldığı, **altıncı çağrının reddedildiği**, görünümün
sayaçla aynı sayıyı gösterdiği, yarının anahtarında satır olmadığı ve başka
kullanıcının harcamasının benim hakkımı etkilemediği.

### 3.2 Kombo — seri çarpanı

**Ne yapıldı.** `profiles.combo` / `combo_at` sütunları ve `apply_progress`in
yeniden yazımı. Kombo her doğru cevapta artıyor, yanlışta sıfırlanıyor, son
doğrudan 30 dakika sonra yeniden 1'den başlıyor. Çarpan `min(max(kombo,1), 5)`,
XP `10 × çarpan`. Günlük tavan **1500 → 3000**.

**Neden yapıldı.** Tasarım pratik ekranında ×3, oturum sonunda ×5 gösteriyor.
Task'ın kuralı net: "gösterilen çarpan sunucuda gerçekten uygulanacak;
uygulanmayacaksa gösterilmeyecek." Kararı siz "gerçekten uygula" olarak
verdiniz.

**Neden bu yaklaşım.** Kombo `apply_progress` içinde, **tek UPDATE** içinde
hesaplanıyor (Task 01'in 2. kuralı: ikiye bölünürse `sync_league_member_xp` ve
`on_friend_milestone` AFTER trigger'ları iki kez çalışır). Oturumun en uzun
kombosu **istemcide** türetiliyor — her yanıtta dönen `combo` değerinin
maksimumu; bunun için yeni bir sunucu durumu yok.

**Beraberinde gelen bir sıkılaştırma.** `submit_review` artık `p_choice`
alıyor: sorunun şıkları varsa doğruluğu **sunucu** hesaplıyor ve `p_correct`
yok sayılıyor. Çarpan kullanıcı beyanının değerini beş katına çıkardığı için,
doğrulanabilir yerde doğrulamak şart oldu.

**Artık risk, açıkça.** Şıkkı olmayan (kendi kendine notlanan) tekrarlarda
doğruluk hâlâ beyan ve çarpan onu da beşle çarpıyor. Günlük tavan bunu
**sınırlıyor, sıfırlamıyor**. Ayrıca 3000 de ölçülmüş bir sayı değil — Task 01
aynı uyarıyı 1500 için yapmıştı; gerçek p99 günlük XP ölçülüp güncellenmeli.

**Nasıl doğrulandı.** `supabase/tests/110_combo_xp.sql` (13 iddia): ilk doğru
10 XP, ikinci ardışık doğru 20 XP (çarpan gerçekten uygulanıyor), üçüncüde
çarpan 3, yanlışta kombo sıfırlanıyor ve XP verilmiyor, çarpan 5'te duruyor,
`p_choice` verildiğinde "doğru yaptım" beyanı yok sayılıyor, şıkkı olmayan
soruda beyan korunuyor, ve sütunların ikisi de istemciye kapalı.

### 3.3 Elmas

**Ne yapıldı.** `claim_daily_goal()` artık XP bonusunun yanında **+5 elmas**
veriyor ve dönüşünde `gems` / `gems_awarded` taşıyor.

**Neden bu yaklaşım.** `gems` ölü bir sütundu ve tasarım göstergeyi koruyor
ama satın alma bu sürümde yok — yani kazanma yolu olmadan gösterge sahte
olurdu. Kaynak olarak günlük sandık seçildi (kararınız): `claim_daily_goal`
zaten günde en fazla bir kez çalışıyor, satırı kilitliyor ve gerçekten
çalışılmış olmasını arıyor. Ayrı bir sayaç, ayrı bir tavan ve ayrı bir kötüye
kullanım yüzeyi açmaya gerek kalmadı.

**Ne değişmedi.** Harcama yolu YOK. Uygulama içi satın alma ve reklam ayrı bir
task; elmas şimdilik biriken bir ödül.

### 3.4 Lig — altı kademe, 30 kişilik kohort

**Ne yapıldı.** `bronz · gumus · altin · platin · zumrut · elmas`. Kohort 12 →
30. `settle_past_leagues` ve `assign_week_cohorts` yeni zincire göre yeniden
yazıldı; `league_rank`/`league_label` genişletildi; Dart tarafında `League`
enum'u yeniden yazıldı.

**Neden bu eşleme.** Sıra korunuyor (kararınız): 4.→4. (`elmas`→`platin`),
5.→5. (`efsane`→`zumrut`). Kimse yükselmiyor, kimse düşmüyor.

**Buradaki asıl tuzak.** `elmas` adı iki yapıda da var ama **anlamı
değişiyor**: eskiden 4., şimdi 6. kademe. Bu yüzden eşleme sıraya göre ve tek
yönde yapılmak zorunda — önce `elmas`→`platin`, sonra `efsane`→`zumrut`. Ters
sırada yapılsaydı `efsane`den gelenler bir sonraki ifadede yeniden taşınırdı.
CHECK kısıtı da üç adımda değiştiriliyor: genişlet → eşle → daralt.

**Kohort geçişi.** 30 yalnızca yeni açılan kohortlara uygulanıyor. Açık
haftanın 12'lik kohortları eski hâlleriyle kapanıyor; `settle_past_leagues`
zaten kohort başına ilk 5 / son 5 hesaplıyor ve "6'dan küçük kohortta kimse
düşmez" koşulunu taşıyor.

**Nasıl doğrulandı.** `supabase/tests/140_league.sql` (19 iddia): altı değerin
geçerli, `efsane`nin **geçersiz** olduğu; sıra numaraları; kohort boyutunun 30
ve ilk5+son5'i barındıracak kadar büyük olduğu; ve 12 kişilik geçmiş bir
kohort kurulup `settle_past_leagues` çağrılarak **tam 5 kişinin platine
çıktığı, tam 5 kişinin gümüşe düştüğü** ve kohortun kapatıldığı.
Dart tarafında `test/models/league_test.dart` yeniden yazıldı (10 test).

### 3.5 Yaş kapısı ve veli onayı

**Ne yapıldı.**
- `profiles.birth_year` (yalnızca **yıl**, tam tarih değil) ve
  `guardian_email`; ikisi de kilitli, `set_birth_year` RPC'si **tek yazımlık**.
- `is_minor_now(uid)` — reşitlik **saklanmıyor, türetiliyor**; yıl bilinmiyorsa
  **true** (kapalı taraf).
- `guardian_requests` tablosu (sunucu-özel), token **hash'li**, tek
  kullanımlık, 7 gün.
- `request_guardian_consent(email)` — günde 3 deneme sınırlı.
- `send_guardian_email(...)` — `send_push` ile birebir aynı desen:
  sağlayıcı anahtarı `app_config`te, gönderim `net.http_post` ile.
- `confirm_guardian_consent(token)` — **`user_id` parametresi almıyor**,
  kullanıcıyı token'dan çözüyor.
- `can_add_friends(uid)` ve `friendships` INSERT politikasına bağlanması.

**Bu, Task 01'in açık bıraktığı bir cümleyi kapatıyor.** Task 01 raporu
"defter onayın denetlenebilir kaydı, paylaşımın zorlayıcısı değil. Bunu 'onay
artık zorunlu tutuluyor' diye okumayın" diyordu. Artık **bir özellik için**
zorlanıyor: arkadaş ekleme. Başka hiçbir özellik onaya bağlanmadı — kullanıcı
onay beklerken uygulamayı tam kullanabiliyor (tasarımın kuralı bu).

**Reddedilen alternatifler.** (a) Onayı auth metadata'sında tutmak: Task 01
onun tamamen kullanıcı-yazılabilir ve zaman damgasız olduğunu ölçmüştü.
(b) `pgcrypto` (`gen_random_bytes`/`digest`): Supabase onu `extensions`
şemasına kuruyor ve definer fonksiyonlar `search_path = public` ile çalışıyor;
şemayı genişletmek gereksiz bir yüzey açardı. Yerine çekirdekteki
`gen_random_uuid` (iki tane = 244 bit) ve `sha256` kullanıldı — uzantı
bağımlılığı yok.

**Nasıl doğrulandı.** `supabase/tests/130_guardian.sql` (21 iddia): yaş
bilinmiyorken kapının kapalı olduğu, doğum yılının **ikinci kez
yazılamadığı** (kısıt yılı değiştirerek aşılamıyor), onaysız reşit olmayan
hesabın arkadaş isteği gönderemediği (**42501, sunucudan**), onay deftere
düşünce kapının açıldığı, **onay geri alınınca yeniden kapandığı**, reşit
kullanıcıya hiç sorulmadığı ve defterin hâlâ değiştirilemez olduğu.

### 3.6 Arkadaş kodu

**Ne yapıldı.** `profiles.friend_code` (6 karakter, alfabe
`ABCDEFGHJKMNPQRSTUVWXYZ23456789` — I, L, O, 0, 1 yok), kayıt anında
üretiliyor, mevcut satırlar için geri dolduruldu. `add_friend_by_code`,
`rotate_friend_code` (günde 1), `mutual_friend_count`.

**Neden bu yaklaşım.** Task 01 dizinin toplu dökülebilirliğini açık risk olarak
bırakmıştı ("sosyal/UX pass'ine ertelendi"). Kod tabanlı ekleme o riski
"dökülebilir ama **eklenebilir değil**"e indiriyor: kodu bilmeden istek
gönderilemiyor. 31⁶ ≈ 887 milyonluk uzay + saatte 20 deneme sınırı tarama
yolunu kapatıyor.

**Test yazarken bulunan gerçek tasarım hatası.** İlk sürüm "kod bulunamadı"
durumunda `raise` ediyordu. PostgreSQL'de istisna işlemi geri alır — **ve geri
alma oran sınırı sayacını da siler**. Yani geçersiz denemeler hiç sayılmaz,
sınır yalnızca başarılı eklemeleri sınırlar ve 887 milyonluk uzayı taramak
**bedava** olurdu. Fonksiyon artık başarısızlığı dönüş değeri olarak veriyor
(`ok=false`, `reason`), istisna yalnızca sayaç artışından ÖNCEKİ yapısal
hatalarda ve sınır aşımında atılıyor.

**Hata mesajları bilerek aynı.** "kod yok", "kendi kodun", "engellisin" ve
"anonim hesap" hepsi `bulunamadi` dönüyor; ayrım yapılsaydı kod uzayını
taramak için bir sızıntı kanalı olurdu.

**Nasıl doğrulandı.** `supabase/tests/120_friend_code.sql` (16 iddia): kodun
kayıt anında üretildiği, 6 karakter olduğu, karışan karakterleri
içermediği, tekil olduğu, istemciden yazılamadığı; tireli/küçük harfli yazımın
normalize edildiği; kendi kodunu ve bilinmeyen kodu **aynı cevapla**
reddettiği; ve **saatlik sınır aşılınca reddettiği**.

**Ne değişmedi — ve bu bir eksik.** `socialRepository.search()` (takma ad
`ilike` araması) **hâlâ duruyor**. Kaldırılması Arkadaşlar ekranının yeniden
yazımıyla (Dalga 5) birlikte yapılmalı; şimdi kaldırılsaydı yeni arayüz
gelene kadar kullanıcı hiç arkadaş ekleyemezdi.

### 3.7 Engelleme ve şikâyet

**Ne yapıldı.** `user_blocks` tablosu, `block_user`/`unblock_user`,
`report_received_question` (şikâyet + isteğe bağlı engelleme tek çağrıda),
`question_reports.reason` CHECK'ine `spam`/`harassment`/`copyright` eklendi ve
`received_questions` görünümü iki yeni süzgeç aldı.

**Neden bu yaklaşım.** Engel, arkadaşlıktan **sonra** gelen bir karar:
arkadaşlığı silmeden de gönderim durdurulabilmeli. Engel **geriye de bakıyor**
— engellenen kişinin daha önce gönderdikleri de gizleniyor; yalnızca geleceğe
bakan bir engel taciz senaryosunda yetersiz kalırdı. Engellenen kişi
engellendiğini **göremiyor** (satır ona kapalı, bildirim yok).

Şikâyet ve engelleme tek RPC'de: iki ayrı istemci çağrısı olsaydı ikincisi
düştüğünde kullanıcı "engelledim" sanıp engellememiş olurdu.

**Şikâyet süresi.** Arayüzde "24 saat içinde incelenir" **yazmayacak** (task
kararı) ve veritabanında da bir SLA alanı yok; yalnızca "incelenene kadar
senden gizli" durumu var.

**Nasıl doğrulandı.** `supabase/tests/150_blocks_anonymous.sql` (17 iddia).

### 3.8 Anonim oturum — kayıt öncesi ilk fotoğraf

Bu, task'ın §6'daki en büyük mimari sorusunun cevabı.

**Seçilen yaklaşım.** Kullanıcı "İlk yanlışını çek"e bastığı anda
`signInAnonymously()` çağrılıyor. O andan itibaren gerçek bir `auth.uid()` var:
fotoğraf `<uid>/...` altına yükleniyor, `mistakes` satırı normal yoldan
yazılıyor, yaş kapısındaki onay deftere düşüyor, AI çağrısı JWT'li yapılıyor.
Kayıt adımında `auth.updateUser(email, password)` anonim kullanıcıyı kalıcı
hesaba çeviriyor ve **uid değişmiyor** — taşınacak hiçbir şey yok.

**Reddedilen alternatif — yerel evreleme.** Fotoğraf ve analiz cihazda tutulup
kayıttan sonra yüklenecekti. Üç nedenle reddedildi: (a) AI çağrısı yine kimlik
istiyor, yani asıl sorunu çözmüyor; (b) "yerelden sunucuya taşıma" ikinci ve
kırılgan bir yol açıyor — yükleme yarıda kalırsa kullanıcı fotoğrafını
kaybediyor; (c) yaş kapısında verilen onayın yazılacağı bir kimlik yok.

**AI'nın hesapsız kullanıcıya verilmesi (§6'nın ikinci sorusu).**
`analyze-question` `verify_jwt = true` **kalıyor** (Task 01'in H7 düzeltmesi
gevşetilmiyor). Kimlik anonim oturumdan geliyor, sınır ise **can mekaniğinin
kendisi**: edge fonksiyon OpenAI'ya gitmeden önce `consume_ai_use()` çağırıyor.
Reddedilen alternatif `verify_jwt = false` + captcha'ydı: ücretli bir uç
noktayı kimliksiz açmak Task 01'in kapattığı sınıfı geri getirirdi.

**Sosyal yüzeyden tam dışlama.** `profiles.is_anonymous` (auth.users'tan
tetikleyiciyle senkron, istemciye kapalı) `profiles_public`te, kohort
atamasında, `friendships` ve `question_sends` INSERT politikalarında
filtreleniyor. Kalıcı hesaba dönüşünce hepsi kendiliğinden açılıyor —
dönüşümü yakalamak için `auth.users` üzerinde AFTER UPDATE tetikleyicisi var
(INSERT tetikleyicisi o anı hiç görmez).

**Savunmacı bir ayrıntı.** `auth.users.is_anonymous` sütununun varlığı göç
zamanında katalogdan kontrol ediliyor ve tetikleyici gövdesi ona göre
üretiliyor; sütun yoksa ölçüt `new.email is null`a düşüyor ve `raise warning`
veriliyor. Doğrudan `new.is_anonymous` yazmak, sütunun olmadığı bir sürümde
**kullanıcı oluşturmayı tamamen kırardı**.

**Bedeli, açıkça.** Anonim kullanıcılar Supabase MAU'suna sayılır. Denemede
vazgeçen her kullanıcı bir MAU'dur. Dashboard'da anonim oturum için captcha ve
oran sınırı **açılmalı**.

**Nasıl doğrulandı.** `150_blocks_anonymous.sql`: anonim kullanıcının
`profiles_public`te görünmediği, arkadaş isteği gönderemediği (**42501**), lig
kohortuna atanmadığı — ama **kendi hatasını kaydedebildiği** (kayıt öncesi
akışın çalışması bu).

### 3.9 Sütun kilidi ve kapılar

**Ne yapıldı.** `20260902000900_lockdown_v2.sql`: **on tabloyu** kapsayan yeni
bir katalog doğrulama bloğu, ve üç ölü sütunun düşürülmesi (`hearts`,
`is_minor`, `guardian_consent`).

**Neden yeni bir göç.** Task 01'in bloğu yalnızca kendi göçü çalışırken
katalogla karşılaştırma yapıyor. Sonraki bir göçte eklenen sütun o an henüz
yok — yani "sınıflandırılmamış kolon" hatası hiç çıkmıyor. Kilit yine geçerli
(varsayılan reddet) ama hata göç zamanında değil **çalışma anında sessiz bir
42501** olarak beliriyor. Task bunu "baştan doğru yaz" diye işaretlemişti.

Blok Task 01'in beş tablosuna beş tane daha ekliyor: üç yeni tablo
(`user_blocks`, `rate_limits`, `guardian_requests`) ve Task 01'in "sütun kilidi
olmayan" listesinden ikisi (`friendships`, `question_reports`).
`question_reports` özellikle önemli hâle geldi: gelen kutusu artık bekleyen bir
şikâyeti olan içeriği gizliyor, yani `status` bir ürün davranışını sürüyor.

**Diğer kapılar.** `20260902001000_cascade_audit.sql` hesap silmenin gerçekten
silmesini garantiliyor: `auth.users`'a bakan her yabancı anahtarın cascade
olduğunu **ve** kullanıcı verisi tutan 15 tablonun böyle bir anahtarı
olduğunu doğruluyor (ikincisi olmadan `user_id` sütununu FK'siz eklemek
kontrolü atlatırdı). `20260902001100_function_grants_recheck3.sql` beyaz
listeyi 23'ten 38'e çıkarıyor, RLS kapısını ve sunucu-özel tablo kapısını
yeniliyor, ve düşürülen üç ölü sütunun geri gelmediğini kontrol ediyor.

**Nasıl doğrulandı.** `supabase/tests/180_lockdown_v2.sql` (28 iddia) — her
yeni sütun için **ayrı bir negatif test**, hem katalog (`has_column_privilege`)
hem davranış (`throws_ok 42501`) katmanında; artı aşırı kilitleme kontrolleri
(`avatar_path` hâlâ yazılabilir, `upsert_my_profile` hâlâ çalışıyor).

---

## 4. Dalga 3 — çekirdek döngü

Ürünün tek gerçek döngüsü: **çek → onayla → çöz → sonuç**. Beş ekran yazıldı
(3e, 3f, 3g, 3h, 3i), `add_mistake_screen.dart` (816 satır) silindi, can
tüketimi ve kombo arayüze bağlandı.

### 4.1 Yakalama (3e) — `lib/features/capture/capture_screen.dart`

**Ne yapıldı.** Kamera/galeriden fotoğraf alınıyor, en-boy oranı `dart:ui`
codec'iyle çözülüp alan ona göre boyutlanıyor, `analyze-question` çağrılıyor ve
sonuç onay ekranına aktarılıyor. Analiz sırasında fotoğrafın **altında** bir
tarama paneli duruyor; panelde Kimo `scanning` durumunda ve **Vazgeç** düğmesi
var. Vazgeçildiğinde gelen sonuç açılmıyor (`_cancelled`), fotoğraf ekranda
kalıyor. Üçüncü bir yol daha var: **Fotoğrafsız devam et** — doğrudan onay
formunu boş açıyor.

**Neden bu yaklaşım.** Reddedilen alternatif: mockup'taki adım adım tarama
kontrol listesi ("Metin çıkarıldı ✓ · 5 şık bulundu ✓ · Konu eşleştiriliyor…").
Analiz **tek bir HTTP çağrısı** ve ara durum yayınlamıyor; o listeyi bir
zamanlayıcıyla doldurmak, olmayan bir ilerlemeyi varmış gibi göstermek olurdu —
task'ın yasakladığı şeyin tam tanımı. Yerine tek ve dürüst bir "okuyorum"
durumu kondu. Panelin fotoğrafın üstünde değil altında olması da bilinçli:
mockup'taki yerleşimde dikey sorularda soru metni panelin arkasında kalıyor.

**Değişen dosyalar.** `lib/features/capture/capture_screen.dart` (yeni),
`lib/features/home/home_shell.dart` (kamera düğmesi artık `CaptureScreen`),
`lib/features/mistakes/mistakes_screen.dart` (FAB aynı ekrana),
`lib/features/mistakes/add_mistake_screen.dart` (**silindi**).

**Nasıl doğrulandı.** `tools/check_symbols.py` her token/ikon erişimini,
`tools/check_imports.py` import grafiğini doğruluyor. Akışın kendisi (kamera
izni, gerçek analiz) **çalıştırılmadı** — bu makinede Flutter yok.

### 4.2 Onaylama ve elle giriş (3f) — `lib/features/capture/confirm_screen.dart`

**Ne yapıldı.** Tek bir ekran iki yolu birden karşılıyor. Yapay zekâ çalıştıysa
sınav/ders/konu ve şıklar dolu geliyor, kullanıcıya iki dokunuş kalıyor (doğru
şık + kaydet). Yapay zekâ çalışmadıysa — hak bitti, çevrimdışı, iptal edildi,
"fotoğrafsız devam et" — **aynı ekran** boş alanlarla açılıyor. Yapay zekânın
önerdiği ders/konu yalnızca müfredatta birebir karşılığı varsa kabul ediliyor;
uydurma bir konu arşivi ve istatistikleri kirletirdi. Hata sebebi alanı
**isteğe bağlı** ve ikinci dokunuşla geri alınabiliyor. Hak bittiyse üstte
"yarın yenilenecek" kartı var — **geri sayım yok**.

**Neden bu yaklaşım.** Task açıkça istiyordu: "Elle giriş yolu zaten çevrimdışı
kayıt için de gerekiyor — aynı formu iki durum da kullansın." Reddedilen
alternatif: ayrı bir `manual_entry_form.dart`. İki form, iki doğrulama kuralı
seti ve iki kaydetme yolu demekti; ikisi zamanla ayrışırdı ve çevrimdışı yol
(daha az test edilen) bozuk kalırdı.

**Sunucu tarafında karşılığı olan değişiklik.**
`supabase/migrations/20260902001200_mistake_type_optional.sql`: `mistake_type`
enum'una `sure_yetmedi` ve `yanlis_okudum` eklendi ve sütun `not null`
olmaktan çıkarıldı. Sütun zorunluyken istemci bir değer **uydurmak**
zorundaydı; ölçülmemiş bir veriyi ölçülmüş gibi göstermek olurdu. Eski
`islem_hatasi` değeri KALDI — taşıyan satırlar var ve onları yeniden
anlamlandırmak veriyi bozardı; arayüzde seçenek olarak görünmüyor, yalnızca
eski kayıtlarda okunuyor.

**Değişen dosyalar.** `lib/features/capture/confirm_screen.dart` (yeni),
`lib/models/models.dart` (`MistakeType` dört sebebe çıktı + `islemHatasi`
eski değer olarak duruyor; `MistakeEntry.type` **nullable** oldu),
`lib/data/mistake_repository.dart` (`add(type:)` isteğe bağlı, `fromDb`
bilinmeyen değerde `null`), `lib/widgets/mistake_style.dart`,
`lib/data/mock_data.dart`, `lib/features/mistakes/mistakes_screen.dart`.

**Deliberately unchanged.** `topic_picker_sheet.dart` olduğu gibi kullanılıyor;
konu seçimi zaten müfredat ağacından geliyordu ve yeniden yazmak Dalga 8'in
temalama işi.

### 4.3 Pratik (3g) — `lib/features/practice/practice_screen.dart`

**Ne yapıldı.** Çizim tuvali (`DrawingCanvas`) korundu ve fotoğrafın üstünde
duruyor. Şıklı sorularda harfe dokunuluyor ve **doğruyu sunucu belirliyor**
(`submit_review(p_choice:)`); şıksız eski kayıtlarda öz-değerlendirme yolu
duruyor. Üst şeritte günün ilerlemesi, kalan sayaç ve — **yalnızca sunucu
gerçekten >1 döndürdüyse** — kombo rozeti var. Çevrimdışı kuyruk şeridi
korundu ve artık sayı gösteriyor.

**Neden bu yaklaşım.** Cevaptan sonra ekran değişmiyor: soru yerinde kalıyor ve
altından cevap paneli açılıyor. Reddedilen alternatif: mockup'un ayrı tam ekran
"doğru cevap" sayfası. Soruyu ekrandan kaldırmak, kullanıcının "neden yanlış
yaptım" sorusunu cevaplamasını imkânsız kılıyordu — üründeki tekrar
mekaniğinin bütün amacı bu.

**Sessiz yutma kaldırıldı.** `mistakeRepository.submitReview` eskiden `catch (_)`
ile ağ hatasını yutuyordu: plan yazılamadığında soru bugünün kuyruğunda
sessizce kalıyor ve kullanıcı sebebini hiç öğrenmiyordu. Artık `ReviewOutcome`
döndürüyor ve hatayı yükseltiyor; ekran paneli "Tekrar planı kaydedilemedi.
Bu soru yarın yine karşına çıkabilir." satırıyla gösteriyor.

### 4.4 Cevap açılışı (3h) — `lib/features/practice/answer_reveal.dart`

**Ne yapıldı.** Doğruda ve yanlışta **aynı düzen**: Kimo tepkisi, başlık, bir
sonraki tekrarın ne zaman olduğu, varsa ödül rozetleri, devam düğmesi. Renk
farkı yalnızca ton (nane / bal); kırmızı uyarı, sarsıntı ve "kaybettin" dili
yok. Seçilen yanlış şık bile mercanla değil bal rengiyle işaretleniyor.

**Ödül rozetleri gerçek.** `+XP` yalnızca sunucunun döndürdüğü `xp_awarded`
sıfırdan büyükse, `×N` yalnızca sunucunun döndürdüğü `multiplier` 1'den
büyükse görünüyor. Çevrimdışında cevap kuyruğa girdiği için ikisi de yok.
Panel **hemen** açılıyor (ağı beklemeden), sunucu yanıtı gelince rozetler
ekleniyor: ağı beklemek çevrimdışında ekranı süresiz kilitlerdi, ödülü tahmin
etmek ise günlük tavan yüzünden verilmemiş olabilecek bir XP'yi verilmiş gibi
göstermek olurdu.

**Tekrar merdiveni metinleri koddan geliyor.** Panel "yarın yeniden soracağım"
diyor çünkü `ReviewScheduler.defaultSteps.first == 1`. Mockup'taki "3 gün sonra
karşına çıkacak" ve "3, 7, 14. günde tekrar" ifadeleri koddaki **1 → 3 → 7 →
30** merdiveniyle çelişiyordu; task'ın kararı gereği kod kazandı.

### 4.5 Oturum sonu (3i) — `lib/features/practice/session_end_screen.dart`

**Ne yapıldı.** Üç sayı (ilk denemede bilinen · en uzun seri · kazanılan XP),
sandık, seviye şeridi ve kalan soru varsa "ekstra tur" teklifi.
`SessionResult` (`session_result.dart`) saf veri: her alanı sunucunun döndürdüğü
bir değerden türüyor.

**Sandık zaten açılmış geliyor.** Ödülü veren `claim_daily_goal()` çağrısı
pratik ekranında, hedefe ulaşıldığı anda yapılıyor; oturum sonundaki dokunuş
yalnızca sonucu açıyor. Reddedilen alternatif: sandığa basınca RPC çağırmak —
kullanıcı ekranı kapatırsa kazandığı ödül hiç yazılmamış olurdu.

**Seviye yeni bir sütun değil.** `SessionResult.level = totalXp ~/ 1000 + 1`.
Tasarımdaki "Seviye 7 · 860/1000" göstergesi bu formülün okunuşu; sunucuda
ayrı bir sayaç yok.

**Kutlama da dürüst.** Maskot yalnızca seri gerçekten büyüdüyse tepki
oynatıyor. İlk yazımda her oturum sonunda `levelUp` tetikleniyordu — olmayan
bir seviye atlamasını kutluyordu; kaldırıldı.

### 4.6 Can arayüze bağlandı

`analyze-question` edge fonksiyonu **OpenAI'ya gitmeden önce**
`consume_ai_use()` çağırıyor (Dalga 2'de kurulan RPC). Hak bitince 200 ile
`{allowed:false, resets_at}` dönüyor — hata değil, ürün durumu. İstemci
tarafında: `QuestionAnalysis.outOfCredit` yolu onay formunu açıyor, yakalama
ekranı kalan hakkı rozet olarak gösteriyor ve sayıyı **her yanıtta sunucudan**
tazeliyor (istemcide ayrı bir sayaç tutulmuyor). Hak `null` ise — okunamadıysa —
rozet hiç gösterilmiyor; yanlış bir sayı göstermektense hiç göstermemek doğru.

Bu aynı zamanda Task 01'in açık bulgusu #7'yi (AI uç noktasında kişi başı
sınır yok) kapatıyor.

---

## 5. Dalga 4 — Bugün ve Hatalarım

İki ekran yeniden yazıldı. Ortak ilke: **gösterilen her sayı ya sunucudan
geliyor ya da mevcut bir alandan türüyor; hiçbiri için yeni sayaç açılmadı.**

### 5.1 Bugün (3c + 3d) — `lib/features/home/today_screen.dart`

**Ne yapıldı.** Tek ekran iki durumu karşılıyor: arşiv hiç açılmamışsa (3c)
Kimo + tek bir davet, doluysa (3d) HUD + günün çemberi + ders listesi. HUD üç
hap taşıyor — seri · can · elmas — ve **can/elmas yalnızca `my_daily_state`
okunabildiyse** görünüyor. Çemberin göbeğinde Kimo duruyor ve dokunulunca
tepki veriyor. Seri uyarısı yalnızca gerçekten risk varken (`streakAtRisk`)
çıkıyor; gelen soru kartı yalnızca çözülmemiş soru varken.

**Neden bu yaklaşım.** 3c ve 3d'yi ayrı ekran yapmak, ilk soru kaydedildiği
anda navigasyonu değiştirmek demekti (aynı sekme, farklı rota). Reddedilen
alternatif buydu; tek `State` içinde iki gövde daha az yüzey.

**Sıfır-veri ölçüsü ayrı bir sorguya bağlandı.** `_due` boş olması ile arşivin
boş olması FARKLI iki durum: bugün tekrarı olmayan dolu bir arşiv de `_due`'yu
boş bırakıyor. Bunun için `mistakeRepository.totalCount()` eklendi
(`count(CountOption.exact)` — satırlar indirilmiyor, yalnızca sayı geliyor).
Aksi hâlde düzenli çalışan bir kullanıcıya "arşivin henüz boş" derdik.

**Havuz kartı yok.** Mockup'un sıfır-veri ekranında "Havuzdan 5 soru çöz" diye
ikinci bir yol vardı; havuz arayüzden çıktığı için tek yol kaldı.

**Beş sorgu paralelleştirildi.** Eski panoda `dueReviews`, `reviewedTodayCount`
ve `unsolvedCount` sırayla bekleniyordu; can/elmas ve arşiv sayısıyla birlikte
beş gidiş-dönüş olacaktı. Aralarında bağımlılık yok, `Future.wait` ile aynı
anda gidiyorlar. Elle zincirlenmiş `await`lerde ilki patlarsa kalanlar sahipsiz
kalır ve yakalanmamış hataya dönüşürdü; `Future.wait` hepsini bekliyor.

**Yükleme hatası artık görünür.** Eski panoda `catch (_)` vardı ve hata
durumunda ekran boş bir panoya düşüyordu — "bugün tekrarın yok" ile "veri
gelmedi" ayırt edilemiyordu. Artık `_failed` durumu ve yeniden deneme düğmesi
var.

**Değişen dosyalar.** `lib/features/home/today_screen.dart` (yeni),
`lib/features/home/home_dashboard.dart` (**silindi**, 627 satır),
`lib/features/home/home_shell.dart`, `lib/data/mistake_repository.dart`
(`totalCount`), `lib/widgets/game_widgets.dart` (**silindi** — `TopStatsBar`,
`StatPill`, `RoundedProgressBar`, `SectionTitle`'ın dördü de artık çağrılmıyor).

### 5.2 Hatalarım (3j) — `lib/features/mistakes/mistakes_screen.dart`

**Ne yapıldı.** Üç kat: (1) hâkim oranı halkası ve üç sayı, (2) İnatçılar,
(3) son 7 günün çubukları ve ders filtresiyle arşiv listesi.

**Sayıların kaynağı.** Halka `mastered`'dan, İnatçılar `is_leech`/`lapses`'ten,
son 7 gün `created_at`'ten, "Bugün" `next_review_date`'ten türüyor — dördü de
Task 01'den beri yazılan alanlar. Tek eklenen şey `MistakeEntry.nextReviewDate`
(sütun zaten vardı, istemci taşımıyordu).

**"Bugün" sayısı için `step` kullanılmadı — ve bu bilinçli bir düzeltmedir.**
İlk yazımda `step == 0` sayılıyordu, çünkü ucuzdu. Yanlıştı: bugün eklenmiş bir
soru da `step == 0` taşıyor ve tekrarı **yarın**. O sayı, etiketinin söylediği
şey olmazdı. Şimdi `dueReviews()` sorgusuyla birebir aynı kural uygulanıyor
(hâkim değil **ve** planlanan gün bugün ya da geçmiş); planı bilinmeyen yerel
kayıtlar sayılmıyor.

**Halka tasarımdan bilinçli sapma.** Mockup üç dilimli bir donut gösteriyor.
`SegmentRing` tek renkli dilimli bir halka çiziyor; üç renkli dilim için ayrı
bir boyayıcı gerekiyordu. Halka **hâkim oranını** taşıyor (sabit 20 dilim —
arşiv boyutu kadar dilim çizmek 200 soruluk bir arşivde okunmaz bir yüzük
olurdu), üç sayı yanında satır satır okunuyor. Kaybedilen: üç oranın görsel
karşılaştırması. Raporda böyle duruyor, "yapıldı" demiyorum.

**İnatçılar metni koddan.** "Seni **en az dört kez** yenen sorular" —
`ReviewScheduler.leechThreshold = 4`. Mockup "en az üç kez" yazıyordu.

**Nasıl doğrulandı.** `test/features/mistakes/mistake_stats_test.dart` — **10 test**, ekranın
gösterdiği her sayı için:
- boş listede sıfıra bölme yok, yüzde 0;
- hâkim/öğreniyorum ayrımı ve yüzde yuvarlaması (2/3 → %67);
- "Bugün" sayısının plana baktığı, adıma bakmadığı (yarın planlı `step == 0`
  kaydın sayılmadığı, gecikmiş kaydın sayıldığı, hâkim olanın sayılmadığı);
- inatçı eşiği (`lapses` 3 girmiyor, 4 giriyor; `is_leech` bayrağı tek başına
  yetiyor) ve **eşiğin zamanlayıcınınkiyle aynı olduğu**;
- son 7 gün penceresinin sınırları (6 gün önce içeride, 7 gün önce dışarıda),
  gün etiketlerinin pencereyle aynı sırada olduğu, günün saatinin pencereyi
  kaydırmadığı, ileri tarihli bozuk kaydın diziyi taşırmadığı;
- ders dağılımının çoktan aza sıralı olduğu.

Sayılar `MistakeStats` adlı ayrı ve saf bir sınıfta hesaplanıyor
(`lib/features/mistakes/mistake_stats.dart`) — widget içinde kalsalardı ancak
cihazda doğrulanabilirlerdi. `now` dışarıdan veriliyor, bu yüzden testler
saate bağlı değil.

**Deliberately unchanged.** Arkadaşa gönderme yolu (`showSendQuestionSheet`) ve
`MistakePhoto`'nun imzalı URL mantığı olduğu gibi duruyor. Depodaki fotoğraflar
imza gerektirdiği için kit'in `SizedPhoto`'su (yalnızca `ImageProvider` alıyor)
onların yerine geçemiyor; yerel baytlar `SizedPhoto` ile `cacheWidth`'e
indiriliyor, depodakiler `MistakePhoto`'dan geçiyor.

---

## 6. Dalga 5 — Lig, Arkadaşlar, Gelen kutusu

Üç ekran ve **bir yeni göç**: tasarımın "Sil" düğmesinin sunucuda karşılığı yoktu.

### 6.1 Lig (3l) — `lib/features/league/league_screen.dart`

**Ne yapıldı.** Haftalık tahta: kademe rozeti, kalan gün, kendi sıran, ve
üyeler. Yükselme/düşme bölgeleri liste içinde çizgiyle ayrılıyor. Sekme üstte
bir segment taşıyor (Lig | Arkadaşlar); alt navigasyonda ayrı sekme açmak
tasarımın sabit beş sekmesini altıya çıkarırdı.

**Bölge çizgileri sabit değil.** İlk 5 / son 5 çizgileri **gerçek üye sayısına**
göre yerleşiyor, 30'a göre değil: hafta başında kohort dolmamış olabiliyor ve
sunucu (`settle_past_leagues`) da kuralı gerçek üye sayısına uyguluyor. Sabit
konumda çizilen bir çizgi, 12 kişilik bir grupta yanlış yeri gösterirdi.
Alt bilgide "30 kişilik grubunda ilk 5 yükselir, son 5 düşer" cümlesi
`League.cohortSize` / `promotionCount` / `demotionCount` sabitlerinden
üretiliyor — sunucudaki `league_cohort_size()` ile aynı olmak zorunda.

### 6.2 Arkadaşlar (3m) — `lib/features/league/friends_view.dart`

**Ne yapıldı.** Kendi arkadaş kodun (kopyalanabilir, yenilenebilir), kodla
ekleme alanı, gelen istekler (ortak arkadaş sayısıyla) ve arkadaş listesi.
Her arkadaş satırında çıkarma ve engelleme; ikisi de onay soruyor.

**Takma ad araması TAMAMEN KALDIRILDI.** `socialRepository.search()` silindi.
Neden: `profiles_public` üzerinde `ilike '%q%'` yapıp `xp`'ye göre sıralı ilk
20'yi döndürüyordu. İki sonucu vardı — (a) "ar", "el" gibi yaygın bir harf
dizisiyle bütün kullanıcı tabanı sayfa sayfa dökülebiliyordu, (b) `xp`
sıralaması en aktif kullanıcıları listenin başına koyarak hedef seçmeyi
kolaylaştırıyordu. Task 01 bunu "sosyal/UX pass'ine ertelendi" diye açık
bırakmıştı; burası o pass. Görünüm duruyor (kimliğe göre okuma hâlâ gerekli),
giden yalnızca serbest metin araması.

**Reddedilen alternatif:** aramayı tam eşleşmeye indirmek (`eq('nickname', q)`).
Dökülebilirliği azaltırdı ama bitirmezdi (yaygın takma adlar sözlükten
denenebilir) ve kullanıcıya "tam olarak yaz" demek arkadaş kodundan daha kötü
bir deneyim.

**Ortak arkadaş sayısı yalnızca GELEN İSTEKLER için isteniyor.** Kabul edilmiş
arkadaşlarda anlamı yok ve satır başına bir RPC listeyi yavaşlatırdı. Sunucu
yalnızca **sayı** döndürüyor, kimlik değil — ortak arkadaşların listesi
istenmeyen bir sosyal grafik sızıntısı olurdu.

**Kod yenileme sınırı arayüzde de doğru anlatılıyor.** Sunucu günde bir kez
sınırını `54000` ile reddediyor; istemci bunu genel bir hata gibi göstermek
yerine "kodunu bugün zaten yeniledin" diyor — bu bir arıza değil, kuralın
kendisi.

**Bilinmeyen kod tek mesaj alıyor.** `add_friend_by_code` kod yok / kendi kodun
/ engelli / anonim ayrımı yapmıyor; istemci de yapmıyor. Bir kodun var olup
olmadığını sızdırmak 887 milyonluk uzayı taramayı ucuzlatırdı.

### 6.3 Gelen kutusu (3n) — `lib/features/inbox/inbox_screen.dart`

**Ne yapıldı.** Kart başına fotoğraf, gönderen, ve üç eylem: **Çöz · Sil ·
Bildir**. Çözmede şıklar yerinde açılıyor, doğruluğu sunucu belirliyor, Kimo
tepki veriyor. Şikâyet sayfasında tasarımın beş sebebi, isteğe bağlı not ve
"bu kişiyi de engelle" kutusu var; ikisi **tek çağrıda** gidiyor
(`report_received_question`) — iki ayrı istek olsaydı ikincisi düştüğünde
kullanıcı engellediğini sanıp engellememiş olurdu.

**Şikâyet metninde süre taahhüdü yok.** Tasarım "Bildirimler 24 saat içinde
incelenir" diyordu; tutulacağının garantisi olmayan bir söz. Metin şu:
"Bildirimin alındı. Ekibimiz inceleyecek; incelenene kadar bu içerik senden
gizlendi." İkinci cümle **doğru**: `received_questions` görünümü bekleyen
şikâyeti olan gönderimi zaten filtreliyor.

**"Sil" için yeni göç yazıldı** — `20260902001050_inbox_dismiss.sql`.
Tasarımdaki düğmenin sunucuda hiçbir karşılığı yoktu; yalnızca istemcide
gizlemek, uygulama yeniden açıldığında sorunun geri gelmesi demekti. Task'ın
kuralı açık: arayüzde gösterilen her mekanik sunucuda gerçekten çalışmalı.

- `question_sends.dismissed_at` — **kilitli doğuyor** (INSERT ve UPDATE
  ayrıcalıkları `authenticated`'tan alınmış), tek yazma yolu RPC.
- `dismiss_received_question(p_send uuid)` — **`user_id` parametresi yok**,
  alıcı `auth.uid()`'den geliyor. Satırı bulamazsa **sessiz geçiyor**: "senin
  değil" ile "zaten gizli"yi ayıran bir hata mesajı, başkasının gönderim
  kimliklerini yoklamaya yarardı.
- Satır **SİLİNMİYOR**. Gerçekten silmek iki şeyi bozardı: gönderenin kaydı yok
  olurdu ve şikâyet edilmiş bir gönderim moderasyon kuyruğundan da kaybolurdu —
  yani rahatsız edici bir gönderimi silmek onu incelenemez kılardı.
- `received_questions` görünümü yeniden yazıldı; **beş eski filtrenin hepsi
  korundu** (çözülebilirlik üçlüsü, moderasyon, bekleyen şikâyet, engel) ve
  altıncı olarak `dismissed_at is null` eklendi.
- Kısmi indeks: `(receiver_id, created_at desc) where dismissed_at is null`.

**Göç sırası bilinçli.** Dosya `001050` numarasını taşıyor, yani fonksiyon
yetkisi kapısından (`001100`) **önce** çalışıyor ve `dismiss_received_question`
o kapının beyaz listesinde. Kapıdan sonra eklenseydi hiç süpürülmezdi — "yeni
fonksiyon PUBLIC'e açık doğar" kuralı onun için hiç sınanmazdı. Bu ilk yazımda
gerçekten yanlış yapıldı ve düzeltildi; tekrarlamaması için
`tools/check_sql.py`'a **kapıdan sonra yaratılan fonksiyon** kontrolü eklendi
(kasıtlı bozup doğrulandı).

**Nasıl doğrulandı.** `supabase/tests/190_inbox_dismiss.sql` — **12 iddia**:
sütun var ve INSERT/UPDATE'e kapalı; fonksiyon PUBLIC'e kapalı,
`authenticated`'a açık; gönderim kutuda görünüyor; **yabancının çağrısı hata
vermiyor ama hiçbir şey de gizlemiyor**; alıcı kendi sorusunu gizleyebiliyor;
gizlenen soru kutuda görünmüyor; satır silinmemiş ve `dismissed_at`
damgalanmış.

**Silinen dosyalar.** `lib/features/social/social_screen.dart` (1.092 satır) ve
`lib/features/inbox/received_questions_screen.dart` (507 satır) yerlerini
`league_screen.dart` + `friends_view.dart` + `inbox_screen.dart`'a bıraktı.
`notification_router.dart` yeni ekrana bağlandı.

---

## 7. Dalga 6 — Onboarding, yaş kapısı, veli onayı, anonim oturum

Kayıt akışın **sonuna** alındı, onboarding **on bir adımdan beşe** indi, yaş
kapısı geldi ve üç edge fonksiyon yazıldı.

### 7.1 Karşılama (3a) ve anonim oturum

**Ne yapıldı.** `welcome_screen.dart` yeniden yazıldı: Kimo, tek cümlelik
tanıtım ve birincil düğme olarak **"İlk yanlışını çek"**. Dokunulduğu anda
`signInAnonymously()` çağrılıyor; oturum açılınca `AuthGate` karşılama akışını
gösteriyor ve akışın ilk adımı doğrudan çekim ekranını açıyor. İkincil yol
"Hesabım var" → giriş ekranı.

**Neden bu yaklaşım.** Yönlendirme karşılama ekranından değil, oturum
durumundan sürülüyor: düğmeye basınca hem rota itmek hem oturum açmak, oturum
olayı ile rota itmesini yarıştırırdı. Anonim oturum **uygulama açılışında
değil**, tam bu düğmeye basıldığında açılıyor — her açılışta açmak, uygulamayı
yalnızca açıp kapatan herkes için bir çöp hesap (ve faturaya yazılan bir MAU)
üretirdi.

**Reddedilen alternatif: yerel evreleme** (fotoğrafı cihazda tutup kayıttan
sonra yüklemek). Üç nedenle reddedildi: (a) yapay zekâ çağrısı yine de bir
kimlik istiyor, yani asıl sorunu çözmüyor; (b) kayıt anındaki "yerelden
sunucuya taşıma" ikinci ve kırılgan bir yol açıyor — yükleme yarıda kalırsa
kullanıcı ilk fotoğrafını kaybeder; (c) yaş kapısında verilen onayın
yazılacağı bir kimlik olmuyor.

**Bedeli, açıkça:** anonim kullanıcılar Supabase MAU'suna sayılıyor.
`config.toml`'da `enable_anonymous_sign_ins = true` yapıldı ve yorumda
**üretimde CAPTCHA'nın da açılması gerektiği** yazıldı; `anonymous_users = 30`
oran sınırı tek başına yeterli değil.

**Kayıt kalıcı hesaba DÖNÜŞÜM, yeni hesap değil.**
`authRepository.convertToPermanent()` `updateUser(email, password)` çağırıyor;
`uid` DEĞİŞMİYOR. Bu yüzden `<uid>/` altındaki fotoğraflar, `mistakes`
satırları ve onay defteri kayıtları olduğu yerde kalıyor — taşınacak hiçbir şey
yok. `AuthGate` anonim oturumda **her zaman** akışa giriyor
(`!onboardingComplete || isAnonymous`): tercihleri doldurup kaydı atlayan bir
kullanıcı `onboardingComplete` ölçüsünü geçerdi ama hesabı olmazdı ve cihaz
değişince her şeyi kaybederdi.

### 7.2 Yaş kapısı (3b) — `lib/features/onboarding/age_gate_step.dart`

**Yalnızca doğum YILI toplanıyor.** Tam doğum tarihi gereğinden fazla kişisel
veri ve yaş sınırını uygulamak için gerekmiyor. Yıl bir kez yazılıyor —
`set_birth_year` ikinci çağrıyı `22023` ile reddediyor, yani 18 altı bir
kullanıcı kısıtı aşmak için yılı sonradan değiştiremiyor. Reşitlik
saklanmıyor, `is_minor_now` ile türetiliyor: bir sonraki doğum gününde kimsenin
bir alanı güncellemesi gerekmiyor.

**Onay YALNIZCA arkadaş eklemeyi kapatıyor.** Kaydetme, tekrar, lig, gelen
kutusu — hepsi açık. Ekran metni bunu açıkça söylüyor. Mockup "arkadaş ekleme
**ve havuza paylaşım** kapalı" diyordu; havuz zaten yok.

**Yaş kapısı akışı KİLİTLEMİYOR.** Durum okunamadıysa (ağ hatası, ilk yükleme
sürüyor) ilerlemeye izin veriliyor. Bu bir boşluk değil: `is_minor_now`
bilinmeyen doğum yılını **reşit olmayan** sayıyor (fail-closed), yani atlayan
kullanıcıda arkadaş ekleme sunucuda kapalı kalıyor. Kilitlenmek gerçekten zarar
verirdi — veliye ulaşamayan bir öğrenci uygulamaya hiç giremezdi.

### 7.3 Karşılama akışı — 11 adımdan 5'e

Yeni adımlar: **yaş kapısı · takma ad + sınav yılı · maskot · bildirim ·
kayıt**. (Anonim gelmeyen, yani "Hesabım var" ile girenlerde ilk çekim ve kayıt
adımları düşüyor.)

**Kaldırılanlar:** üç "nasıl çalışır" anlatım sayfası — ürünün kendisi zaten
anlatıyor: çekim ekranı ne yapacağını, cevap paneli tekrarın ne zaman
geleceğini söylüyor — ve "merhaba" sayfası (karşılama ekranına taşındı).
Takma ad ile sınav yılı **tek sayfada** birleştirildi; ikisi de tek dokunuşluk.

**Bildirim izni adımı KORUNDU.** Task "bildirim çekirdeği korunur, yalnızca
sunum ve kullanıcı denetimi değişir" diyordu. İzin hâlâ maskot seçiminden
sonra soruluyor (kullanıcı karakterine yeni yatırım yapmışken) ve reddedilirse
görünür bir bilgi veriliyor.

### 7.4 Giriş ekranından kayıt kaldırıldı

`login_screen.dart` artık **yalnızca giriş**. İki kayıt yolu tutmak ikisinin
zamanla ayrışması demekti — ve buradaki yol yaş kapısından geçmiyordu.
Ekrandaki **"veli onayı" onay kutusu da silindi**: Task 01 onun tamamen
kullanıcı-yazılabilir ve zaman damgasız olduğunu ölçmüştü. Yerini yaş kapısı,
`user_consents` defteri ve `can_add_friends` kısıtı aldı. `authRepository.signUp`
artık `guardianConsent` parametresi almıyor.

### 7.5 Üç edge fonksiyon

| Fonksiyon | `verify_jwt` | Ne yapıyor |
|---|---|---|
| `guardian-confirm` | **false** | Velinin tıkladığı bağlantı; token'ı `confirm_guardian_consent`'e taşır ve HTML bir sonuç sayfası döner |
| `delete-account` | true | Depolamayı boşaltır, sonra `auth.admin.deleteUser` |
| `cleanup-anonymous` | true | Süresi dolmuş anonim hesapları siler |

**`guardian-confirm` kimliksiz ve bu zorunlu** — velinin hesabı yok. Task 01'in
kapattığı sınıfa komşu bir yüzey olduğu için sıkılaştırmalar açık: token 64 hex
karakter (iki UUID), veritabanında yalnızca SHA-256 hash'i duruyor, tek
kullanımlık, 7 gün geçerli. **Biçim kontrolü veritabanından önce**: 64 hex
dışındaki her şey sorgu maliyeti üretmeden reddediliyor. Sonuç sayfası
`Content-Security-Policy: default-src 'none'` taşıyor ve **başarısızlıkta tek
mesaj** veriyor — token yok / süresi dolmuş / zaten kullanılmış ayrımı
yapılmıyor, çünkü ayırmak geçerli bir token'ı yoklamayı kolaylaştırırdı.

**`delete-account` — `uid` GÖVDEDEN DEĞİL JWT'DEN.** Gövdeden alsaydık servis
rolüyle çalışan bu fonksiyon "herkesin herkesi silmesi" primitifi olurdu. Sıra:
depolama (`mistake-photos`, sonra `avatars`; sayfalı) → **yalnızca hepsi
silindiyse** `auth.admin.deleteUser` → cascade. Depolama yarıda kalırsa
`purgeFolder` hata fırlatıyor ve `deleteUser` satırı **hiç çalışmıyor**;
kullanıcı görünür bir hata alıyor. Sessizce "silindi" demek, silinmemiş
fotoğrafları silinmiş göstermek olurdu. Bu, depodaki **tek servis rolü
yüzeyi**. Silme izi bırakılmıyor (varsayılan karar; §12'de açık madde).

**`cleanup-anonymous`** `stale_anonymous_users(p_days)` ile adayları alıyor,
tur başına en fazla 200 hesap siliyor ve **takılan bir hesap turu
durdurmuyor** — atlanıyor, sonraki turda yeniden deneniyor.

### 7.6 Nasıl doğrulandı

Sunucu tarafı zaten Dalga 2'de yazılmış pgTAP dosyalarıyla iddia ediliyor
(`130_guardian.sql` 21 iddia, `150_blocks_anonymous.sql` 17 iddia): doğum yılı
iki kez yazılamıyor, 18 altı + onaysız `friendships` INSERT'i **42501**,
onaydan sonra çalışıyor, defter `source='guardian_email'` alıyor, anonim
kullanıcı `profiles_public`'te ve kohortta yok.

**Edge fonksiyonların hiçbiri çalıştırılmadı.** Deno bu makinede yok; TypeScript
derlenmedi. Bu üç dosya için elimde yalnızca gözden geçirme var, çalıştırma
kanıtı yok.

---

## 8. Dalga 7 — Profil, Ayarlar, hesap silme

### 8.1 Profil — `lib/features/profile/profile_screen.dart`

**Ne yapıldı.** Kimliğe ayrılmış bir ekran: fotoğraf, takma ad, seviye şeridi,
üç sayı (toplam XP · seri · arkadaş), lig şeridi ve tema anahtarı. Ayarlara
**tek giriş** var: sağ üstteki simge.

**Tema anahtarı burada da var** (tasarım kararı): en sık değiştirilen tercih ve
onun için ayrı bir ekrana girmek gereksiz. Aynı `appSettings` durumunu
yazıyorlar, iki ayrı kopya yok.

**Sayılar sunucudan.** `my_daily_state` okunabildiyse XP, seri ve elmas oradan;
okunamadıysa yerel (iyimser) `GameProgress` değerleri. Seviye ayrı bir sayaç
değil, aynı formülün okunuşu (`xp ~/ 1000 + 1`) — hem burada hem oturum sonunda
hem HUD'da.

**Sahte rozet ızgarası kaldırıldı.** Eski profilde altı rozet vardı (üçü
"kazanılmış", üçü "kilitli") ve hepsi `MockData.badges` sabitiydi — hiçbiri
gerçek bir başarıya bağlı değildi. Yerine bir şey konmadı: gerçek bir rozet
sistemi ayrı bir iş ve §13'te açık madde.

### 8.2 Ayarlar — `lib/features/profile/settings_screen.dart`

Üç bölüm: **Görünüm** (tema, ses) · **Bildirimler** (açma/kapama, tekrar saati,
seri saati, sessiz aralık) · **Hesap** (Kimo'nun karakteri, sınav yılı, doğum
yılı/veli onayı durumu, yönetim girişleri, çıkış, hesap silme).

**Havuza paylaşım anahtarı kaldırıldı** (havuz arayüzden çıktı).

**Saat seçici 24 çip, `showTimePicker` DEĞİL.** Sistem seçicisi dakika da
soruyor ama bütün zamanlama saat başına yuvarlanıyor; dakikayı sormak,
uygulanmayacak bir hassasiyeti varmış gibi göstermekti.

**Saat satırları yalnızca bildirimler açıkken görünüyor.** Kapalıyken
gösterilmeleri, hiçbir şeyi etkilemeyen bir ayarı ayarlanabilir göstermekti.

**Bildirim izni reddedilirse** sistem penceresi bir daha açılmıyor; kullanıcı
telefonun ayarına yönlendiriliyor (mevcut davranış korundu, yalnızca sunum
değişti).

### 8.3 Hesap silme — `lib/features/settings/delete_account_screen.dart`

**Ne yapıldı.** Uyarı, ne silineceğinin dört maddelik listesi, onay için takma
adı yazma ve tek düğme. Silme `delete-account` edge fonksiyonuna gidiyor
(§7.5); başarılıysa oturum kapanıyor ve yığın temizleniyor.

**Neden takma ad yazdırıyoruz.** Tek dokunuşluk bir "Sil" düğmesi, listeyi
okumadan basılabilecek kadar kolaydı. Yazma eylemi kullanıcıyı ne sileceğini
okumaya zorluyor. Reddedilen alternatif: "emin misin?" diyen ikinci bir onay
penceresi — iki dokunuş, aynı dikkatsizlik.

**Yumuşak silme yok, 30 günlük bekleme yok.** KVKK Md. 7 / GDPR Md. 17
"gerçekten sil" diyor; "sonra geri alabilirsin" diyen bir akış aslında
silmiyor demektir.

**Hata mesajı "hiçbir şey silinmedi" diyebiliyor** çünkü sunucu tarafı gerçekten
öyle: depolama boşaltılamazsa `auth.admin.deleteUser` satırı hiç çalışmıyor.
`accountRepository.deleteAccount()` hatayı **yutmuyor**.

---

## 9. Dalga 8 — Kapanış

### 9.1 Kalan ekranlar yeni tasarım diline taşındı

`topic_picker_sheet` (çekirdek döngüde), `exam_year_sheet`, `mascot_sheet`,
`send_question_sheet`, `public_profile_screen` ve üç paylaşılan widget
(`drawing_canvas`, `mistake_photo`, `user_avatar`) eski `AppColors` paletinden
tasarım token'larına geçti. Koyu temada yanlış renk gösteren son yüzeyler
bunlardı.

**İki bilinçli düzeltme yapıldı:**
- `LeagueBanner` artık **XP göstermiyor**. Lig ile XP'yi yan yana koymak "XP
  biriktirince lig atlanır" izlenimi veriyordu; ligi belirleyen şey haftalık
  sıralama.
- `subjectEmoji()` silindi — çağıran kalmadı (yeni tasarım dilinde ders emojisi
  yok, renk şeridi var).

**Taşınmayanlar, açıkça:** `admin/moderation_screen.dart` ve
`admin/all_questions_screen.dart` hâlâ eski palette. İkisi de yalnızca
yöneticiye görünüyor, tasarımda artboard'ları yok ve `GameButton`'ın son
kullanıcısı onlar. Bilerek dokunulmadı.

### 9.2 Yerelleştirme

`app_tr.arb` **285 mesaj**. Her `l.<anahtar>` çağrısının karşılığı var, arite
(getter/fonksiyon) tutuyor, yetim `@meta` yok, ölü anahtar yok — kapanışta
tasarım değişikliğiyle karşılığı kalmayan **18 anahtar silindi**.

Kalan gömülü Türkçe metinler taranıp sınıflandırıldı; kalanlar bilerek kalıyor:
`debugPrint` teşhis satırları, `assert` mesajları, `Exception` metinleri (hepsi
geliştiriciye), ve `mascot_lines.dart` (bildirim metinleri — task "bildirim
çekirdeği korunur" diyor).

### 9.3 Sessiz yutma taraması

Yeni yazılan 20 dosyada **tek** `catch (_)` var ve o da belgeli:
`capture_screen.dart` fotoğrafın en-boy oranını çözemezse varsayılana düşüyor —
görsel bir ayrıntı, akışı durdurmuyor. Bunun dışında kaldırılan iki tanesi:
`mistakeRepository.submitReview` (§4.3) ve eski panonun yükleme hatası (§5.1).

### 9.4 Testler

**11 Dart test dosyası.** `widget_test.dart` yeniden yazıldı ve bu bir hata
düzeltmesidir: eski hâli sekme geçişini **metinle** iddia ediyordu
(`find.text('Günlük Tekrar Hedefi')`), ama sekmeler `IndexedStack` içinde canlı
tutulduğu için görünmeyen sekmenin metinleri de ağaçta duruyor — yani o iddia
yanlış geçerdi. Artık `KimoNavBar.selectedIndex` üzerinden yapıya bakıyor ve
dört ekranın da hata vermeden kurulduğunu ayrıca doğruluyor.

**349 pgTAP iddiası**, 21 dosya (yeni: `190_inbox_dismiss.sql`, 12 iddia).

### 9.5 Denetleyiciler CI'ya bağlandı — ve kendi kendilerini sınıyorlar

`.github/workflows/ci.yml` içinde ayrı bir `static` işi: `check_symbols.py`,
`check_imports.py`, `check_sql.py` ve **ikisinin selftest'i**.

Bu bölüm bir hata düzeltmesinin sonucu. **Aynı sınıf hata iki kez oldu:** bir
kabuk here-doc'u Python kaynağındaki ters eğik çizgiyi yiyip yerine `0x08`
(backspace) koydu.
- `check_symbols.py`'da `\b%s\.` deseni bozuldu → denetleyici **hiçbir şey
  bulamıyor ama "sorun: 0" diyordu**. Kasıtlı bozuk sembol koyup yakalamadığı
  görüldü.
- `check_imports.py`'da `r'^extension\b'` bozuldu → uzantı dosyalarını tanıyan
  kod hiç çalışmadı; `context.c` için gereken `tokens.dart` importu
  "kullanılmıyor" diye işaretlendi ve az kalsın silinecekti.

İkisi de düzeltildi ve artık `--selftest` taşıyorlar. `check_imports.py`'ın
selftest'i ayrıca **`tools/*.py` dosyalarını kontrol karakteri için tarıyor** —
yani bozulmanın sınıfını, tek tek örneklerini değil.

`check_sql.py`'a da yeni bir kapı eklendi: **fonksiyon yetkisi kapısından SONRA
yaratılan fonksiyon**. Bu da yaşanmış bir hata — `dismiss_received_question`
önce `001300` numarasıyla yazılmıştı, yani `001100`'deki beyaz liste kapısı onu
hiç süpürmüyordu. Göç elle öne alındı ve kontrol eklendi (kasıtlı bozup
doğrulandı).

---

## 10. Arşivlenen havuz dosyaları ve geri açma adımları

Tam liste ve adım adım yönerge `lib/_archive/README.md` içinde. Özet:

1. Beş dosyayı `git mv` ile eski yerlerine taşı.
2. `analysis_options.yaml`'daki `lib/_archive/**` satırını kaldır.
3. Bir giriş noktası bağla — bugün hiçbir sekme havuza gitmiyor ve tasarımda
   "Kapsama/Harita" ekranı yok; yeni yeri bir ürün kararı.
4. **Onayı geri getir.** `shareConsent` defterden okunmaya devam ediyor ama
   artık hiçbir yerde sorulmuyor. Havuz geri gelirse karşılama akışındaki onay
   adımı ve ayarlardaki anahtar da geri gelmeli — aksi hâlde kullanıcıya
   sorulmadan paylaşım açılır.
5. `mistakeRepository.add(...)` çağrısında `isPublic` yeniden
   `userProfile.shareConsent` olmalı; şu an sabit `false`.

Arşiv **çalışır kod garantisi vermiyor**: analizden hariç olduğu için değişen
token'lar, yerelleştirme ve bileşen kütüphanesiyle uyumu bozulacak. Amacı ekran
tasarımını ve iş mantığını korumak.

---

## 11. Kapsam dışında değiştirmek zorunda kaldıklarım

1. **`pubspec.lock`** — Task 01 `shared_preferences`'ı doğrudan bağımlılığa
   terfi etmişti ama kilit dosyasında girdi hâlâ `dependency: transitive`
   yazıyordu. `flutter pub get` bunu `"direct main"` yapar ve CI'daki
   `git diff --exit-code pubspec.lock` adımı **ilk koşuda kırmızı olurdu**.
   Satır elle düzeltildi; `pubspec.yaml` ve `ci.yml`'daki "bu adım kilidi
   değiştirmemeli" diyen yanlış yorumlar da düzeltildi.

2. **`supabase/tests/085_question_sends.sql`** — Task 01'in göç 0036'sı
   `question_sends` UPDATE'ini tamamen kapatmıştı ama bu test hâlâ
   `solved_at`/`correct` yazılabilir diye iddia ediyordu. Üç iddia terse
   çevrildi. Task 01'in süiti bu düzeltme olmadan yeşil olamazdı.

3. **`supabase/tests/010_profiles_column_lockdown.sql`** — düşürülen üç ölü
   sütunun "yazılamaz" iddiaları "hiç yok" iddiasına çevrildi (aksi hâlde
   testler var olmayan sütuna sorup hata verirdi).

4. **`supabase/tests/060_answers_xp.sql`** — `apply_progress`in imzası
   değiştiği için iddiadaki imza güncellendi.

5. **`lib/services/notification_service.dart`** — sabit saatler (17:00/20:00)
   ve sabit sessiz aralık (22:00–08:00) `AppSettings`e bağlandı. Kapsamdaydı
   ama Dalga 7'ye planlanmıştı; `AppSettings`in doküman yorumu "bildirim
   servisi bunu çağırır" diyordu ve çağırmıyordu — yani belge yalan
   söylüyordu. İki kaynak bırakmak yerine şimdi bağlandı. Kullanıcının saat
   seçtiği **arayüz** hâlâ yok (Dalga 7).

6. **`lib/features/social/social_screen.dart` ve `public_profile_screen.dart`**
   — `League.emoji` kaldırıldığı için üç emoji rozeti kademe rengiyle dolu bir
   diske ve kısa ada çevrildi. Bu ekranlar Dalga 5'te yeniden yazılacak; araya
   emoji bırakmamak için şimdi değiştirildi.

7. **`lib/data/moderation_repository.dart`** — `ReportReason` eşlemesi iki
   yerde tutuluyordu; modele taşındı. İki yerde kalsaydı yeni bir sebep
   eklendiğinde moderasyon ekranı onu sessizce "diğer" gösterirdi.

8. **`tools/check_imports.py` ve `tools/check_sql.py`** — depoda olmayan iki
   yerel denetim aracı. Gerekçe §0'da.

---

## 12. Tasarımda eksik veya çelişkili bulduklarım

1. **Profil ve Ayarlar artboard'ları elde edilemedi.** Tasarım dosyası
   (`AI YKS Coach Ekranlar.dc.html`) 256 KiB sınırında kesildi: **3k artboard'ı
   hiç yok** ve **3n'den sonrası gelmedi**. Elde edilenler 3a–3n arası
   (3k hariç). Bu iki ekranı yazmadan önce eksik artboard'ların okunması
   gerekiyor; sizin de "Chrome ile oku" dediğiniz iş bu — plan modunda
   yapılmadı, Dalga 7'nin ilk adımı.

2. **Mockup'taki can tanımı ürün kararıyla çelişiyor.** Tasarım "4 saatte bir
   yenilenir" ve "+1 can 1s 20dk" geri sayımı gösteriyor; task "günlük 5 hak,
   gün dönümünde tazelenir, geri sayım yok" diyor. Task uygulandı.

3. **Elmas tanımı çelişiyor.** Tasarım "satın alınır, AI koç kullanımına
   harcanır" diyor; task "satın alma yok, AI koç yok" diyor. Task uygulandı,
   elmas ödül olarak kazanılıyor.

4. **Tekrar aralıkları çelişiyor.** Mockup "3, 7 ve 14. günde" ve "3 gün sonra
   karşına çıkacak" diyor; kod `1 → 3 → 7 → 30`. Kod kazandı (task kuralı).
   Arayüz metinleri yazılırken bu esas alınacak.

5. **"İnatçılar" tanımı çelişiyor.** Mockup "en az **üç** kez seni yenen"
   diyor; koddaki `leechThreshold = 4`. Metin "en az dört kez" olacak.

6. **3h ekranının metni yanlış.** "Bu soruyu 3. denemede çözdün. Artık hâkim
   sayılıyor — 30 gün sonra bir kez daha soracağım." Kodda `mastered` yalnızca
   **30 günlük adımda** doğru cevaplayınca oluyor ve o an kuyruktan çıkıyor.
   Metin yeniden yazılmalı.

7. **3b'deki metin havuza atıf yapıyor** ("arkadaş ekleme ve havuza paylaşım
   kapalı kalır"). Havuz kalktı; yalnızca arkadaş ekleme kapalı.

8. **3c'deki ikinci yol havuza bağlı** ("Havuzdan 5 soru çöz"). Kararınızla
   kart tamamen kalkıyor, tek yol "İlk hatanı ekle" kalıyor.

9. **Maskot adı.** Tasarım "Kestane", kod "Koç Baykuş" diyordu; ikisi de
   kullanılmadı, tek isim **Kimo**.

10. **Rive varlığı yok.** Maskot animasyon dokümanı üretim varlığı olarak tek
    bir `.riv` öngörüyor (≤60 KB, 300×330) ama o varlık teslim edilmedi.
    Kimo şimdilik kodla çiziliyor.

---

## 13. Nasıl doğrulandı — inceleme turları

Derleyici olmadığı için iki tur çok ajanlı çekişmeli inceleme yapıldı. Her
bulgu, onu **çürütmekle görevli** bağımsız bir ajana verildi; yalnızca
çürütülemeyenler düzeltildi.

**Tur 1 — 22 doğrulanmış bulgu.** Öne çıkanlar:
- `pubspec.lock`un CI'ı kıracak olması (bkz. §11, kapsam dışı değişiklikler).
- `prefer_const_constructors`, `unnecessary_non_null_assertion`,
  `unnecessary_string_interpolations`, `avoid_renaming_method_parameters` —
  `flutter analyze` bunların her birinde çıkış kodu 1 veriyor.
- `setState` geri çağrısının `Future` döndürmesi (debug'da assert patlar).
- Maskotun `reduceMotion` açıkken tepkiyi sonsuza kadar takılı bırakması.
- Ticker yeniden başlatıldığında `elapsed`in sıfırlanıp `_reactionStart`in
  eskimesi.
- Her `AppSettings` bildiriminde tüm temanın yeniden kurulması.
- DM Sans'ta 800 ağırlığın olmaması (küresel `fontFamily` bu yüzden atanmadı).
- `AppSettings`in bildirim saatlerinin o an ölü kod olması — tercih
  yazılıyordu ama hiçbir ekran okumuyordu. Dalga 7'de ayarlar ekranına
  bağlandı (§8.2).

**Tur 2 — 2 doğrulanmış bulgu.** İkisi de düzeltildi:
- Yay parçalama toleransı (§1.4).
- `initState`in dış denetleyiciyle senkronlanmaması (§1.5).

**Test yazarken bulunan üçüncü sınıf hata.** `add_friend_by_code`'un istisna
atması oran sınırını işlevsiz bırakıyordu (§3.6). Bunu ne inceleme turu ne de
statik denetim yakaladı — testi yazarken çıktı.

---

## 14. Yarım kalanlar

**Sekiz dalganın hepsi yazıldı.** Aşağıdakiler o dalgaların İÇİNDE eksik kalan
parçalar — süsleme yok, yarım kalan yarım yazılıyor.

### 14.1 Ürün eksikleri

**Çevrimdışı komboyu geri okuma yok.** Oturum sonundaki "en uzun seri",
çevrimdışı oynanan turlarda `×1` kalıyor: kombo sunucudan geliyor, kuyruğa
giren cevap sunucu değerini geri getirmiyor. Gösterilen sayı yanlış değil
(uydurma bir çarpan göstermiyoruz) ama eksik.

**Hatalarım'daki halka üç oranı ayrı ayrı göstermiyor.** Tasarımda üç dilimli
bir donut var; `SegmentRing` tek renkli ve üç renkli dilim için ayrı bir
boyayıcı gerekiyordu. Halka hâkim oranını taşıyor, üç sayı yanında satır satır
okunuyor. Kaybedilen: üç oranın görsel karşılaştırması.

**"Bekleyen dersler" kartında ders başına ilerleme çubuğu yok.** Mockup'ta
vardı; çubuğun göstereceği "o dersin ne kadarı hâkim" oranı `study_attempts`
üzerinden fazladan bir sorgu istiyordu ve o sorgu yazılmadı. Yerine bekleyen
soru sayısı rozeti var.

**Gerçek rozet sistemi yok.** Profildeki altı sahte rozet kaldırıldı, yerine
bir şey konmadı. Rozetler ayrı bir iş (§15).

**Yönetim ekranları eski palette.** `admin/moderation_screen.dart` ve
`admin/all_questions_screen.dart` yeniden temalanmadı: yalnızca yöneticiye
görünüyorlar ve tasarımda artboard'ları yok. `GameButton`'ın son kullanıcısı
onlar; ikisi taşınırsa o widget da silinebilir.

### 14.2 Dış bağımlılık bekleyenler

**E-posta sağlayıcısı yok — veli onayı uçtan uca ÇALIŞMIYOR.** `app_config`'e
`email_api_url` / `email_api_key` / `email_from` / `guardian_confirm_url`
girilmeden `send_guardian_email` bir uyarı yazıp hiçbir şey yapmadan dönüyor.
Yani arayüz "e-posta gönderildi" diyene kadar her şey hazır, ama e-posta
gitmiyor. Sağlayıcı hesabı, doğrulanmış alan adı ve anahtarlar bu depoda yok.

**Anonim temizliği için zamanlayıcı yok.** `cleanup-anonymous` yazıldı ama onu
düzenli çağıran bir şey yok: `pg_cron` ya da Supabase Scheduled Functions
kurulumu depoda bulunmuyor. Kurulana kadar anonim hesaplar birikiyor ve
MAU'ya sayılmaya devam ediyor.

**Rive varlığı yok.** Kimo kodla çizildi. Widget'ın dış yüzeyi (`mood`,
tetikler, `reduceMotion`) bilerek Rive sözleşmesiyle aynı; varlık gelince
yalnızca `kimo_painter.dart` değişir.

### 14.3 Doğrulama boşlukları

**Hiçbir Dart kodu derlenmedi, hiçbir göç uygulanmadı.** Bu makinede
`flutter`, `dart`, `supabase`, `docker`, `psql`, `deno` yok — kurulmaması sizin
kararınızdı. 349 pgTAP iddiası ve 11 Dart test dosyası hiç koşmadı;
`flutter analyze` hiç koşmadı.

**Dört edge fonksiyonun hiçbiri çalıştırılmadı.** Deno yok; TypeScript
derlenmedi. `analyze-question`, `guardian-confirm`, `delete-account`,
`cleanup-anonymous` için elimde yalnızca gözden geçirme var.

**Mutasyon kontrolü Task 02'nin yeni testleri için genişletilmedi.**
`tools/mutation_check.sh` Task 01'in mutasyonlarını taşıyor; plandaki dört yeni
mutasyon (kota, veli kapısı, kod oran sınırı, anonim filtresi) yazılmadı. Yani
yeni pgTAP dosyalarının **ayırt ettiği** kanıtlanmadı, yalnızca yeşil yanacağı
umuluyor.

---

## 15. Emin olmadıklarım / sizin karar vermeniz gerekenler

1. **Hiçbir şey çalıştırılmadı.** 349 pgTAP iddiası ve 11 Dart test dosyası
   hiç koşmadı; `flutter analyze` hiç koşmadı. CI'ın ilk turu muhtemelen hem
   Task 01'den hem buradan hata dökecek. Bu bir tahmin değil, kaçınılmaz
   sonuç — beklenmeli.

2. **`c_day = 3000` ölçülmüş değil.** Kombo çarpanıyla birlikte günlük tavan
   yeniden kalibre edildi ama sayı hâlâ tahmin. Çok düşükse dürüst kullanıcıyı
   sessizce keser. Gerçek p99 günlük XP'nizi ölçün.

3. **E-posta sağlayıcısı.** Resend varsayıldı (`net.http_post` ile en az
   sürtünme). `app_config`e dört anahtar elle girilmeli:
   `email_api_url`, `email_api_key`, `email_from`, `guardian_confirm_url`.
   Farklı bir sağlayıcı/kurumsal SMTP kullanılacaksa `send_guardian_email`
   gövdesi değişir.

4. **Anonim kullanıcı temizliği.** `stale_anonymous_users(7)` yazıldı ama onu
   çağıracak zamanlanmış iş **yok**. `pg_cron` ya da Supabase Scheduled
   Functions kurulumu gerekiyor; ikisi de depoda yok.

5. **`guardian-confirm` kimliksiz bir uç nokta olacak.** Zorunlu (velinin
   hesabı yok). Token 32 baytlık rastgelelikten türetiliyor, hash'li, tek
   kullanımlık, 7 gün — ama yine de Task 01'in kapattığı sınıfa komşu bir
   yüzey. Onayınızı istiyorum.

6. **Hesap silme denetim izi.** KVKK "sil" diyor. "Silme gerçekleşti" kanıtı
   için hash'lenmiş bir `deleted_accounts` kaydı tutulsun mu, yoksa hiç iz
   kalmasın mı? Varsayılanım **iz yok**.

7. **`my_topic_progress` artık tüketicisiz.** Harita arşive gidince görünümün
   istemci tarafında okuyanı kalmadı; `study_attempts` yazılmaya devam ediyor,
   yani veri birikiyor ama gösterilmiyor. Bilinçli mi, yoksa Hatalarım'a bir
   "kapsama" görünümü mü istiyorsunuz?

8. **"Efsane" → "Zümrüt" isim gerilemesi.** Ordinal eşlemeyi siz seçtiniz.
   Eski Efsane kullanıcıları Zümrüt olarak görünecek. Kullanıcıya bir
   duyuru/açıklama gösterilsin mi?

9. **Şıksız tekrarlarda çarpan.** Kendi kendine notlanan sorularda doğruluk
   beyan ve çarpan onu beşle çarpıyor. Günlük tavan sınırlıyor ama
   sıfırlamıyor. Kabul edilebilir mi, yoksa çarpan yalnızca doğrulanabilir
   cevaplara mı uygulansın?

10. **Profil rozetsiz kaldı.** Uydurma rozet ızgarası kaldırıldı; gerçek bir
    rozet sistemi istiyorsanız ayrı bir task.

11. **`relacl` ölçümü hâlâ alınmadı.** Task 01 raporu bu çıktıyı istiyordu;
    geri alma blokları hâlâ genel. Task 02'nin göçleri de aynı belirsizliği
    miras alıyor.
