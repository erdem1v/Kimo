# Task 03 — Yayına Hazırlık Raporu

Durum: **istemci ve sunucu işleri tamamlandı; Xcode gerektiren iOS adımları ve
cihaz duman testleri sizin makinenizde yapılacak** (adımlar bu raporda ve
`docs/ios-kurulum.md`'de).

Doğrulama durumu: `flutter analyze` temiz · **128 Flutter testi yeşil** ·
`check_symbols` / `check_imports` / `check_sql` (60 göç) temiz. **CI (koşu
#34136156237, main): üç iş de yeşil** — pgTAP **26 dosya / 413 iddia, PASS**;
mutasyon kontrolü **11/11 ayırt edildi, 0 sorun** (her mutant üç fazdan geçti:
mutasyon öncesi yeşil → mutasyonla kırmızı → geri almayla yeşil).

---

## Bulgu bazlı sonuçlar

### §2 — Demo/mock modun kaldırılması

**Ne yapıldı:** Mock yol tamamen silindi. `app.dart` artık koşulsuz
`AuthGate` açar; `main.dart` yapılandırma yoksa (SUPABASE_URL tanımsız)
uygulamayı AÇMAZ, ne eksik olduğunu söyleyen `ConfigErrorApp` tanı ekranını
gösterir. ~20 `SupabaseConfig.isConfigured` dalı, `lib/data/mock_data.dart` ve
`lib/state/mistake_store.dart` silindi; `todayMockNotice` arb anahtarı
kaldırıldı.

**Neden bu yaklaşım:** Alternatif, mock'u derleme bayrağı arkasında tutmaktı —
task açıkça "tamamen kalksın" dedi ve bayraklı yol, yanlış paketlenmiş release
riskini yalnızca gizlerdi.

**Test altyapısı:** `test/widget_test.dart` yeniden kuruldu. Seçilen dikiş:
testte sahte kimliklerle **gerçek** `Supabase.initialize` (
`detectSessionInUri: false`, `stopAutoRefresh()` ile) + `HomeShell`'i doğrudan
pompalama. Test ortamında HTTP her zaman 400 döner; ekranlar ağ hatasını zaten
yakaladığı için yapı iddiaları (4 sekme, indeks, nav-bar, tema/dil) aynen
yaşıyor. Dördüncü test artık "oturumsuz açılış karşılama ekranına düşer"
iddiasını da taşıyor. *Reddedilen alternatif:* repository arayüzleri + fake'ler
— 10 tekil (singleton) sınıfa arayüz çıkarmak 4 yapısal iddia için orantısızdı.

**Dosyalar:** `lib/app.dart`, `lib/main.dart`, `test/widget_test.dart`, 20+
ekran/repository dosyası (dal temizliği).

**Ne değişmedi:** `SupabaseConfig` sınıfı duruyor — tek görevi main'deki
fail-fast kontrolü.

### §3.1 — iOS hedefi ve izin metinleri

**Ne yapıldı (bu oturum + önceki oturum):** `NSCameraUsageDescription` ve
`NSPhotoLibraryUsageDescription` Türkçe, amacı açıklayan metinlerle eklendi;
`IPHONEOS_DEPLOYMENT_TARGET` 13.0 → 15.0 (firebase_core 4.x şartı);
`UIBackgroundModes: remote-notification` eklendi. `NSMicrophoneUsageDescription`
BİLİNÇLİ eklenmedi: yalnızca `pickImage` kullanılıyor, video yok; reşit
olmayan kitleden gereksiz izin istenmiyor (App Store statik analizi sorarsa
karar `docs/ios-kurulum.md`'de belgeli). iOS'ta HEIC→JPEG dönüşümünü zorlayan
`imageQuality: 85` bayrağı yük-taşıyıcı olarak yoruma bağlandı (kaldırılırsa
analiz yalnız iOS'ta kırılır).

**Sizin yapacaklarınız (Xcode gerekli):** kurulum + imzalama + push yetkisi +
`Podfile.lock` commit'i — adım adım `docs/ios-kurulum.md`. Push için ücretli
Apple Developer hesabı şart; E2E onboarding testi için şart DEĞİL.

### §3.2 — Android yayın imzalama + küçültme

**Ne yapıldı:** `android/app/build.gradle.kts` — `key.properties` varsa gerçek
yayın anahtarı, yoksa debug'a düşüş (iki durum da günlüğe yazılır;
google-services.json ile aynı dürüst desen). `isMinifyEnabled` +
`isShrinkResources` + `proguard-rules.pro` (flutter_local_notifications'ın
Gson serileştirmesi için keep kuralları — R8'in klasik kırılması).
`android.yml`'e isteğe bağlı `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEY_PROPERTIES`
sırları eklendi. Keystore/parolalar gitignore'da (zaten kapsanıyordu).

**Sizin yapacaklarınız:** anahtar üretimi —
`keytool -genkey -v -keystore kimo-release.jks -alias kimo -keyalg RSA -keysize 2048 -validity 10000`
→ `android/` altına, `key.properties` (biçim build.gradle.kts başında) →
GitHub sırlarına. **Keystore'u kaybetmek uygulamayı Play'de güncellenemez
yapar; yedekleyin.**

**Nasıl doğrulanır:** karartma açıkken cihaz duman testi (aşağıdaki listede) —
özellikle bildirim planla/yeniden başlat/al zinciri (R8'e duyarlı tek yol).

### §4.2 — Yurt dışı veri aktarımının açıklanması

**Ne yapıldı:** Üç katman:
1. **Bağlamında onay:** ilk analizden önce (fotoğraf çekilmiş, gönderilmek
   üzereyken) bir kez onay sayfası: fotoğrafın OpenAI'ya gideceği açık Türkçe
   metinle söylenir; "Anladım devam" onayı `record_consent('ai_upload')` ile
   **onay defterine** yazılır (değiştirilemez, zaman damgalı — mevcut ledger
   altyapısı genişletildi). "Fotoğrafsız devam" analizi atlar, fotoğrafı korur,
   elle giriş açılır — kaydetme yolu kapanmaz. Onboarding'in anonim
   ilk-çekim adımı aynı CaptureScreen'i kullandığı için bildirim orada da
   çıkar.
2. **Kalıcı görünürlük:** çekim ekranının boş hâlinde tek satırlık not.
3. **Yuva:** Ayarlar → "Veri ve gizlilik" (`PrivacyScreen`): aktarım
   açıklaması + hukuki metinlerin bağlanacağı yer tutucu (metin yazımı kapsam
   dışı — göreve göre ayrı kalem).

**Dosyalar:** `lib/features/capture/capture_screen.dart`,
`lib/state/user_profile.dart`, `lib/features/settings/privacy_screen.dart`,
`supabase/migrations/20260903000400_photo_scan.sql` (ledger 'ai_upload' türü).

### §4.3 — İçerik güvenliği taraması

**Ne yapıldı:** Yeni durum makinesi `mistakes.photo_scan`
(pending → clear | flagged) + yeni edge function **`scan-photos`**
(OpenAI `omni-moderation-latest`, görsel girdili, ücretsiz uç nokta — mevcut
OPENAI_API_KEY ile). Yeni yüklenen her fotoğraf tetikleyiciyle `pending`
başlar; **`clear` olmayan fotoğraf paylaşıma çıkamaz**: havuz görünümü,
arkadaşa gönderme politikası, fotoğraf okuma yetkisinin paylaşım dalları ve
gelen kutusu görünümü kapılandı. **Sahip her durumda kendi kaydını kullanır**
— yanlış pozitif öğrenciyi kilitlemez (task şartı). İki tetik: kayıt sonrası
istemcinin hızlı çağrısı (`consume_scan_use` ile günde 20 sınırlı — uç nokta
bedava moderasyon kâhinine dönüşmesin) + pg_cron süpürmesi 10 dk'da bir
(elle giriş / çökmüş istemci / çevrimdışı kuyruk satırları takılı kalmaz).
Tarama başarısızsa `pending` kalır: paylaşıma kapalı, kişisel kullanıma açık.
Şüpheliler admin moderasyon ekranına düşer; karar iki yönlü — "temiz"
paylaşımı açar, "kaldır" mevcut `moderation='removed'` + purge zincirine akar.

**Neden bu yaklaşım (reddedilen alternatif):** analyze-question içinde inline
moderasyon reddedildi — (a) elle giriş ve kota-bitmiş yol analizi hiç
çağırmıyor, (b) analiz HAM byte görüyor: istemci masum görsel analiz ettirip
depoya başka byte yükleyebilir. Karar KAYITLI NESNEYE bağlanmalıydı. İkinci
reddedilen: makine kararını `moderation` eksenine yazmak — şikâyet sigortasının
(auto-hidden/geri açma) değişmezlerini bozardı; iki eksen AND'lenir.

**Mevcut kayıtlar:** `clear` kabul edildi (zaten canlıda; geriye dönük tarama
istenirse tek UPDATE ile `pending`e çevrilir — rapora not).

**Nasıl doğrulandı:** pgTAP `220_photo_scan.sql` (16 iddia: pending→paylaşım
kapalı/sahip açık, clear→açılır, flagged→havuz+kutu+foto kapanır, admin iki
karar, purge zinciri) + mutasyonlar `09` (okuma kapısı) ve `10` (gönderim
politikası) — kapı kaldırılınca test kırmızıya döner.

### §5.1 — Hata gövdeleri ve CORS

**Zaten çözülmüş (hata gövdeleri):** `analyze-question` ve diğer fonksiyonlar
ham OpenAI gövdesini/istisna metnini artık YANSITMIYOR — tek tip
`{error:"gecersiz_istek"}`, detay yalnız sunucu günlüğünde (önceki task'ta
kapanmış; korundu).

**Ne yapıldı (CORS):** `analyze-question` ve `delete-account`'tan CORS
başlıkları ve OPTIONS dalları TAMAMEN kaldırıldı. *Reddedilen:* origin'e
sabitleme — sabitlenecek meşru bir tarayıcı origin'i yok; kalan her ACAO ölü
yapılandırmaydı. İleride web yönetim paneli gelirse o origin'e sabitlenerek
geri eklenir (fonksiyonlarda yorumla işaretli). Kullanıcıya görünen hata
mesajları istemcide zaten senaryoya özel (bkz. §5.2 reason kodları,
kota/çevrimdışı ayrımları).

### §5.2 — Prompt injection: `reason` serbest metni

**Ne yapıldı:** Şemadaki `reason` serbest metin alanı **`reason_code` enum'una**
çevrildi (`ok/unreadable/no_question/no_options`); prompt "SERBEST METİN
YAZMA" diye günceldi; sunucu, model bayraklarla çelişen kod seçerse kodu
bayraklardan kendisi türetir ve eski `reason` alanını siler — modelin yazdığı
hiçbir metin istemciye ulaşmaz. İstemcide `AnalysisFailure` enum'u + her kod
için **istemcinin kendi yerelleştirilmiş** cümlesi. Bonus: bu metinler İLK KEZ
gösteriliyor — eskiden `reason` hiç ekrana çıkmıyordu ve bulanık fotoğraf,
şıksız sayfa ve ağ hatası tek genel metne düşüyordu; artık onay ekranı nedeni
söylüyor ("daha yakından çek", "bağlantı yok, elle doldurabilirsin"...).
Korunanlar: katı JSON şeması, sınav enum'u, ders/konu çiftinin müfredat
ağacına karşı çifte doğrulaması — dokunulmadı.

### §5.3 — E-posta doğrulama akışı

**Ne yapıldı (istemci):** Onboarding'e yeni **doğrulama adımı**
(`EmailVerifyStep`): "gelen kutunu kontrol et" ekranı, 60 sn bekletmeli
**yeniden gönder** (sunucunun saatte-2 sınırına 429 mesajıyla saygılı),
**adresi değiştir** kaçışı (kayıt adımına döner; yeni `updateUser` askıdaki
adresi değiştirir), `userUpdated` dinleme + 8 sn'de bir `refreshSession`
yoklaması ile **otomatik ilerleme** (onay tarayıcıda/başka cihazda verilir;
push gelmez, sormak gerekir), ve **"şimdilik devam et"** — e-posta ulaşamayan
öğrenciyi uygulamanın dışında kilitlemez; doğrulama bir SONRAKİ soğuk açılışta
kaldığı yerden sorulur (`pendingEmail` kontrolüyle akış doğrudan bu adımdan
açılır). Onay sunucuda kapalıysa adım ilk karede kendini geçer — yerel geliştirme
bozulmaz. `LoginScreen` artık `email_not_confirmed` hatasını ayırıyor: özel
mesaj + doğrulama postasının otomatik yeniden gönderimi. Ölü kod silindi
(`AuthRepository.signUp`, `LoginScreen.startWithSignUp`). `userProfile.clear()`
artık bildirim/onay bayraklarını da sıfırlıyor (hesap değiştirmede sızıntı).

**Ne yapıldı (sunucu):** `stale_anonymous_users` — **veri kaybı yolunun kritik
ayağı**: 6. gün kayıt olup onayı bekleyen anonim kullanıcı 7. gün temizlikte
siliniyordu. Askıda e-posta dönüşümü olan hesaplar artık 30 güne kadar
esirgeniyor (`20260903000600_anonymous_email_pending.sql`).

**Veli e-postası akışıyla tutarlılık:** dokunulmadı — `uid` dönüşümde
değişmediği için yaş kapısı/veli kayıtları aynen geçerli; doğrulama adımı yaş
adımını yeniden çalıştırmaz.

**Sizin karar vereceğiniz:** üretimde `enable_confirmations`'ın açılma anı —
bu istemci sürümü YAYINLANMADAN açmayın (eski istemcide akış yine kopar).
Ayrıca üretim SMTP'si yapılandırın ve e-posta oran sınırını ~10/saat yapın
(varsayılan 2/saat, resend UX'ini boğar).

### §6.1 — Çökme raporlaması: **Sentry**

**Ne yapıldı:** `sentry_flutter` eklendi. `main.dart`: DSN tanımlıysa
`SentryFlutter.init` (zone + `FlutterError.onError` +
`PlatformDispatcher.onError` otomatik kurulur); değilse aynı kancalar
debugPrint'e akacak şekilde elle kurulur — iki modda aynı hata yolları.
Açılıştaki korumasız `await`ler tek tek try/catch'e alındı: hazırlık adımının
patlaması artık telemetrisiz beyaz ekran değil. Yayında `ErrorWidget.builder`
gri kutu yerine dostane kart gösteriyor. Merkezî `reportError(e, st, context:)`
yardımcısı: bağlantı hatalarını (SocketException vb.) RAPORLAMAZ (çevrimdışılık
kusur değil), gerisini Sentry'ye + debugPrint'e akıtır.

**PII koruması (reşit olmayan kitle):** `sendDefaultPii=false`, ekran
görüntüsü/widget ağacı KAPALI (fotoğraflar sınav sorusu = kullanıcı içeriği),
`beforeSend` temizleyicisi: kullanıcı kimliği/e-postası boşaltılır, e-posta
deseni ya da depolama yolu (`<uid>/...`) içeren breadcrumb'lar atılır, mesaj
gövdesindeki e-postalar maskelenir. Temizleyici birim testli
(`test/services/crash_service_test.dart`).

**Neden Sentry, Crashlytics değil:** Firebase bu depoda KOŞULLU —
`google-services.json` yoksa Android'de Firebase ölü, iOS'ta plist hiç yok.
Crashlytics tam da en çok görünürlük gereken derlemelerde (yapılandırmasız CI
APK'sı, tüm iOS derlemeleri) sessizce devre dışı kalırdı — push'ta yaşanan
başarısızlık kalıbının aynısı. Sentry tek DSN ister, iki platformda aynı
çalışır, DSN yokken no-op.

**NEREDEN BAKACAKSINIZ:**
1. <https://sentry.io> → ücretsiz hesap → "Create Project" → platform
   **Flutter** → proje adı `kimo`.
2. Kurulum sayfasındaki **DSN**'i alın (https://...@...ingest.sentry.io/...).
3. Yerel derleme: `flutter build apk --release --dart-define=SENTRY_DSN=<dsn>
   --dart-define-from-file=supabase.json`. CI: depo sırlarına `SENTRY_DSN`
   ekleyin — android.yml gerisini halleder (sır yoksa uyarı basar, raporsuz
   derler).
4. Panel: **Issues** sekmesi = çökmeler ve `reportError`'dan gelen yakalanmış
   hatalar; her kaydın `app.context` etiketi hatanın hangi akıştan geldiğini
   söyler (`bootstrapSocial`, `submitReview.schedule`, `verify.resend`...).
   E-posta uyarıları Settings → Alerts'ten.

### §6.2 — Sessiz başarısızlıklar

**Ne yapıldı:** Üç kovalı triyaj politikası yazıldı (crash_service.dart
başında, denetlenebilir): kullanıcıya-görünür / yalnız-telemetri /
gerekçesi-yazılı-bilinçli-sessiz. Denetimin saydığı noktalar tek tek gezildi:

- `home_shell._bootstrapSocial` — deponun en kritik boş catch'i (tüm XP/seri
  hidrasyonu) artık raporlanıyor; `_drainQueue` de.
- `notification_service.cancelAll` — tek TAMAMEN boş catch — raporlanıyor.
- `push_service.unregisterDevice` raporlanıyor (ve artık ÇAĞRILIYOR, bkz. §7.1).
- Falsy-sentinel dönen repository catch'leri (`isAdmin→false`,
  `unsolvedCount→0`, `myStats/myLeagueBoard/profileById/signedUrl→null`)
  raporlama kazandı — "veri yok" ile "hata oldu" artık bizim tarafta ayırt
  ediliyor.
- **Çevrimdışı takvim kaybı kapatıldı (denetimin en kritik senkron bulgusu):**
  cevabın XP'si kuyruğa giriyordu ama tekrar TAKVİMİ yazımı kayboluyordu —
  soru eski adımında kalıyor, senkronda yeniden soruluyor, merdiven hiç
  ilerlemiyordu. `SubmissionQueue`'ya yeni **`schedule`** türü eklendi:
  ağ hatasında takvim yaması kuyruğa girer (mutlak değerler → idempotent),
  sunucu reddi kuyruklanmaz (aynı sonucu verir), yalnız kuyruk da başarısızsa
  (oturum düşmüş) kullanıcı panelde görür + rapor düşer. `progressRepository`
  kuyruğa alamadığı cevabı da artık raporluyor.
  *Reddedilen alternatif:* takvimi `submit_review` RPC'sine taşımak — sunucu
  yetki modeli değişikliği; mevcut `review` kuyruğuyla çifte-uygulama riski.
  Ayrı tür kendi başına tutarlı.
- Sahipsiz future'lar: `sound.*` API'si `void` yapıldı (tanımı gereği
  ateşle-unut; ~25 çağrı yerindeki lint gürültüsü kökten bitti), kalanlar
  `unawaited(...)` ile niyet beyanına çevrildi ya da `await`lendi;
  `_answer` çağrıları bilinçli ateşle-unut olarak işaretlendi (panel anında
  açılmalı) ve hatalarını içeride raporluyor.
- `all_questions_screen`'deki 2 korumasız `setState` `mounted` kontrolü aldı.

### §6.3 — Lint kuralları

**Ne yapıldı:** `analysis_options.yaml` stok şablondan çıkarıldı:
`strict-casts`, `strict-raw-types`, `unawaited_futures`,
`use_build_context_synchronously` (açık beyan), `cancel_subscriptions`,
`only_throw_errors`. Çıkan ~30 bulgu BASTIRILMADAN düzeltildi (tek `// ignore`
yok). Önerilen ama bilinçli ertelenenler: `discarded_futures` (çok gürültülü,
ayrı bir geçiş ister), `avoid_catches_without_on_clauses` (triyaj yorumları
şimdilik aynı işi görüyor).

### §7.1 — Bildirim anahtarı push'u gerçekten kapatsın

**Ne yapıldı:** `unregisterDevice()` ölü koddu (0 çağrı) — artık üç yerde
çağrılıyor: anahtar KAPATILINCA (yerel iptal + jeton silme), **çıkışta**
(signOut'tan ÖNCE — sıralama şart, jeton silme oturum ister; eskiden aynı
telefonda açılan bir sonraki hesap öncekinin push'larını alıyordu) ve **hesap
silmede**. Anahtar AÇILINCA: izin → `replanFromCache` (gün planı ekran
yüklemesini beklemeden kurulur) + `registerDevice`. Cihaz kaydı artık
`notifyEnabled` şartlı — kapatan kullanıcının jetonu her dönüşte sessizce geri
yazılmıyor. Saat/sessiz-aralık değişiklikleri de anında yeniden planlatıyor.

**Ek düzeltmeler (denetim dışı, bu geçişte bulundu):**
- `planDay`'in `cancelAll`'u lig hatırlatmasını yarışta siliyordu → artık
  yalnız kendi 4 kimliğini iptal ediyor.
- Sessiz saat metni "bir sonraki uygun saate kayar" diyordu, kod DÜŞÜRÜYORDU
  (22:00 hatırlatma + 22-08 sessizlik seçen kullanıcı hiç hatırlatma
  almıyordu) → davranış metne uyduruldu: saf `resolveScheduledHour` yardımcısı
  ileri tarar, gece yarısını aşarsa güne taşar, 24 saat sessizse hiç planlamaz
  (kullanıcı kararı). Birim testli. *Reddedilen:* metni davranışa uydurmak —
  tuzağı kalıcılaştırırdı.
- iOS `areEnabled()` sabit `true` dönüyordu (iOS ayarından kapatılan izin
  uygulamada sonsuza dek "açık" görünüyordu) → `checkPermissions()` ile gerçek
  durum.

### §7.2 — Yeniden başlatmada bildirimler

**Ne yapıldı:** Manifest'e `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` ve
`ScheduledNotificationBootReceiver` alıcısı AÇIKÇA beyan edildi (eklenti
manifest birleşimi muhtemelen zaten getiriyordu ama beyan/belge yoktu; eklenti
sürümü değişirse davranış sessizce bozulmasın). `inexactAllowWhileIdle`
KORUNDU (task'ın açık şartı). iOS karşılığı: iOS planlanmış bildirimleri
yeniden başlatmada sistem kendisi korur; ayrıca yapılacak yoktur — yalnız izin
algılama düzeltmesi (§7.1) iOS'u da düzeltti.

### §8.1 — Seri sunucuda sıfırlanmıyor

**Ne yapıldı:** Yazma yolu değişmedi (`apply_progress` boşlukta zaten 1'e
döner; gece koşan sıfırlama işine gerek yok). Seriyi DIŞARI VEREN üç yüzeyin
üçü de **etkin seri** verecek şekilde kapılandı
(`last_activity_date >= istanbul_day() - 1` değilse 0): `profiles_public`
(arkadaş listesi — 40 günlük hayalet seri artık yayınlanmıyor),
`my_league_board`, `my_daily_state`. İstemcideki BOZUK maske kaldırıldı:
`applyServerTotals` pasif okumalarda "streak>0 ⇒ bugün aktif" çıkarımı
yapıyordu ve bayat seriyi canlı gösteriyordu; pasif okuma artık ayrı
`syncFromDailyState` ile geliyor — son aktif gün ve "bugün" SUNUCUNUN
söylediği değer. Milestone push tetikleyicisi etkilenmedi (tabloyu okur;
pgTAP'ta sanity iddiası var).

**Doğrulama:** pgTAP `200_streak_gate.sql` (11 iddia: üç yüzeyde bayat→0,
dün→30, bugün→30, ham tablo değeri değişmedi, weekly_xp kapısı) + mutasyon
`08` (kapısız görünüm → test kırmızı).

### §8.2 — Saat dilimi tutarsızlığı

**Ne yapıldı:** Günün tek tanımı artık sunucuda. `my_daily_state` v2
(drop+recreate): `today`, `week_start`, `last_activity_date`,
`reviewed_today_count` (Istanbul gün sınırıyla — eski istemci sayımı naif
yerel damga gönderiyordu ve TR'de sınır fiilen 03:00'a kayıyordu; gece 00-03
tekrarları hedefe sayılmıyordu), `due_count`, `unsolved_received_count`.
İstemci gün/hafta üretmeyi bıraktı: `GameProgress` "bugün"ü sunucudan alıyor
(`_serverToday`), `weekly_xp` görünümde de hafta-kapılı (haftanın ilk
açılışında geçen haftanın XP'si HUD'a sızıyordu — kapandı). Can (AI hakkı)
zaten sunucu takvimindeydi; seri/hedef/lig penceresi de aynı takvime bağlandı.
Yeni hatanın vade VARSAYILANI da UTC `current_date+1`'den kurtarıldı (bkz.
§9.1). Bildirim zamanlayıcısındaki `Europe/Istanbul` sabiti bilinçli ve artık
gerekçesi kodda (çözülmeyenler listesinde).

**Doğrulama:** pgTAP `210_daily_state.sql` (10 iddia: Istanbul 01:00 sayılır /
dün 23:00 sayılmaz, due sayımı, kutu süzgeçli rozet, tek-satır görünürlük).

### §8.3 — Avatar/fotoğraf bağlantıları

**Zaten çözülmüş (avatar):** 600 sn TTL'li, süresi dolunca tazeleyen önbellek
önceki task'ta kurulmuş; korundu.

**Ne yapıldı (soru fotoğrafları — 10.4 ile birlikte):** aynı desen
`MistakeRepository.signedUrl`'e kopyalandı: TTL-farkındalıklı önbellek
(30 sn emniyet payıyla), görsel hatasında `invalidateSignedUrl` + tek yeniden
deneme. Izgarada kaydırma başına imza isteği bitti; süresi dolan adres
kendiliğinden tazeleniyor. **TTL 600 sn SABİT bırakıldı** — moderasyon purge
penceresinin kendisi; yükseltmek yasak (kodda belgeli).

### §9.1 — Soğuk başlangıcın ikinci katmanı

**Ne yapıldı:** Vade artık zaman damgası: `mistakes.next_review_at`
(timestamptz). Yeni kayıt tetikleyiciyle **aynı gün + 3 saat** vadelenir —
ilk gün beş soru çeken öğrenci aynı akşam tekrarlarını görür (yeni öğrenilen
şey için pedagojik olarak da doğrusu). `next_review_date` GÖLGE olarak kaldı
ve tetikleyici damgadan türetir (eski istemci kuyruklarının yalnızca-tarih
yazan kayıtları da kabul edilir; iki alan ayrışamaz). Mevcut kayıtlar Istanbul
geceyarısına damgalandı (sıralama birebir korunur). Sorgular zamana geçti
(istemci `dueReviews`, görünümdeki `due_count`); dizin
`mistakes_due_at_idx`. UI metinleri zaten göreli ("bugün/№ gün sonra") —
uyumlu.

**Doğrulama:** pgTAP `215_review_timing.sql` (8 iddia: +3 saat vade, gölge
türetimi iki yönde, 3 saat dolmadan due_count'a girmez, dolunca girer, dizin).

### §9.2 — Öğrenilen soru sınavdan önce bir daha sorulmuyor

**Ne yapıldı:** Merdiven `[1,3,7,30]` DEĞİŞMEDİ; sonuna **bakım basamağı**
eklendi (`ReviewScheduler`): son adımı geçen soru kuyruğu terk etmez, 45 günde
bir döner. `mastered = true` yalnızca bir SONRAKİ bakım tekrarı kullanıcının
sınav tarihini (auth metadata `exam_year` → 20 Haziran) aşacaksa yazılır;
sınav yılı bilinmiyorsa süresiz bakımda kalır — yanlış "öğrenildi" demekten
iyidir. Bakımda yanlış cevap merdivenin başına döndürür (mevcut kural).
**Mahsur kayıtlar kurtarıldı:** göç, `mastered=true` olmuş tüm soruları
45 gün + kayda-özgü 0-13 gün saçılımla (hepsi aynı güne yığılmasın) döngüye
geri aldı. Panel metni güncellendi: "sınava kadar bir daha sormayacağım"
(yalnız gerçek emeklilikte görünür).

**Doğrulama:** `review_scheduler_test.dart` yeniden yazıldı (11 test: merdiven
aynen, bakıma geçiş, bakımda kalış, sınav-kesme iki yönlü, yıl bilinmiyorsa
süresiz, leech/clamp davranışları).

### §10 — Performans

- **10.1 Lig döngüsü:** *bulgunun tetiği düzeltildi* — döngü arkadaşlık
  kabulünde değil, haftanın İLK lig-sekmesi açılışında tetikleniyordu (kod
  izinde arkadaşlık kabulünden bu yola giden çağrı yok); O(N) sorun aynen
  gerçekti. Çözüm: (a) `assign_week_cohorts` KÜME-TABANLI yeniden yazıldı
  (boş koltuklar tek gruplu sorguyla, artanlar row_number/modulo ile tek
  INSERT — satır başına iç içe count bitti), (b) haftalık yerleşim
  **pg_cron**'a taşındı (Pazartesi 00:05 Istanbul = Pazar 21:05 UTC —
  Istanbul DST'siz; tahtalar hafta başında kullanıcı beklemeden dolu),
  (c) `ensure_league_membership` ucuz güvenlik ağına indi: yalnızca ÇAĞIRANI
  yerleştirir, settle'ı yalnızca gerçekten bekleyen kohort varsa çağırır.
  *Reddedilen:* tembel kalıp döngüyü optimize etmek — Pazartesi izdihamı ve
  hafta başı boş tahtalar kalırdı. Aynı cron altyapısına iki iş daha bindi:
  scan-photos süpürmesi (10 dk) ve `cleanup-anonymous` (günlük — fonksiyonun
  baştan beri eksik olan zamanlayıcısı). Doğrulama: pgTAP
  `230_league_rollover.sql` (10 iddia: tam kapsama, anonim dışarıda,
  idempotens, fallback yalnız çağıranı yerleştirir, cron kayıtları) +
  mutasyon `11` (rollover'ı kullanıcıya açınca 098 kırmızı).
- **10.2 Seri sorgular:** Bugün ekranı önceki task'ta paralellenmişti
  (zaten çözülmüş); AYNI desen dört yerde daha bulunup kapatıldı:
  `home_shell` (onaylar ∥ istatistikler), `profile_screen` (+ eksik
  re-entrancy kilidi), `settings_screen`, `friends_view` (arkadaş kodu
  zincirle paralel).
- **10.3 Satır indiren sayaçlar:** `reviewedTodayCount` ve `unsolvedCount`
  SİLİNDİ; sayılar `my_daily_state` sütunları (kullanıcının zaten yaptığı tek
  sorguya bindi + rozet artık gelen kutusuyla aynı süzgeçleri sayıyor).
- **10.4 Fotoğraf imzaları:** bkz. §8.3.
- İstemci tarafı denetim kalemleri (dar dinleyiciler vb.) Task 02'de
  yapılmıştı; doğrulandı (`ListenableBuilder` dar kapsamlı, `cacheWidth`
  ihtiyacı görülmedi — fotoğraflar zaten 1600px'e küçültülüyor).

---

## Zaten çözülmüş bulunan maddeler

| Madde | Kanıt |
|---|---|
| Ham hata gövdeleri istemciye sızıyor (5.1a) | `deny()` tek tip gövde; detay log'da |
| Bugün ekranı seri sorgular (10.2'nin adı geçen kısmı) | 5 sorgu `Future.wait` |
| Avatar imzalı URL önbelleği (8.3'ün avatar yarısı) | 600 sn TTL + tek yeniden imza |
| Bildirim saatleri/sessiz aralık tercihi uçtan uca | `AppSettings` ↔ planlayıcı |
| Yaş kapısı + veli onayı akışı | write-once doğum yılı, sunucu zorlaması |
| Bildirim izninin uygulama içi onay sonrası istenmesi | korunduğu doğrulandı |
| `reason` metninin arayüzde gösterilmesi | HİÇ gösterilmiyordu (gizli risk yarıya indi); yine de enum'a çevrildi |

## Bulunan ama ÇÖZÜLMEYEN edge case'ler

1. **Hatırlatma saat dilimi sabit Istanbul** — bilinçli: sunucu takvimi de
   Istanbul; yurt dışındaki öğrencide hatırlatma yerel değil Istanbul
   saatinde çalar. Kodda gerekçeli.
2. **Analiz iptali krediyi geri vermez** — HTTP isteği iptal edilemiyor
   (functions istemcisinde iptal yok); kredi sunucuda çoktan harcanmış olur.
   Kodda belgeli.
3. **`dueReviews` limitsiz** — 800 vadesi geçmiş kaydı olan kullanıcı hepsini
   tek seferde indirir. Gerçekçi eşiğin altında; sayfalama ayrı iş.
4. **Onboarding `_examYears = [2026..2030]` sabit** — 2030'da bayatlar.
5. **`MistakeStats.leechThreshold` kopyası** — scheduler'daki değerle elle
   eşzamanlı; ayrışırsa yalnız istatistik etiketi kayar.
6. **Yatay mod fiilen tasarlanmamış** — Info.plist hâlâ landscape'e izin
   veriyor; portre kilidi öneriyoruz ama tasarım kararı olduğu için
   dokunulmadı.
7. **Fotoğraf kaydının çevrimdışı kuyruğu yok** — capture akışı bunu ekranda
   dürüstçe söylüyor; kapsamlı bir "foto kuyruğu" ayrı iş.
8. **Var olan fotoğraflar taranmadı** — geriye dönük tarama isterseniz tek
   komut: `update mistakes set photo_scan='pending' where photo_path is not
   null and photo_scan='clear';` → süpürücü eritir (OpenAI moderation
   ücretsiz; sakınca maliyet değil, admin kuyruğuna düşebilecek yanlış
   pozitifler).
9. **`ensure_league_membership`'teki tek-kohort count'u** — kullanıcı başına
   1 count; O(N) değil, kabul edildi.

## Kapsam dışında değiştirmek zorunda kaldıklarım

- `sound.*` API imzaları `Future<void>` → `void` (lint geçişinin gereğiydi;
  davranış aynı).
- `received_questions` görünümüne `photo_scan='clear'` süzgeci (4.3'ün doğal
  uzantısı: şüpheli içeriğin üst verisi de reşit olmayanın kutusunda durmasın).
- `record_consent` / `user_consents` 'ai_upload' türünü kabul edecek şekilde
  genişledi (4.2 için gerekliydi).
- 6 mevcut pgTAP fikstürü yeni tarama kapısı için `photo_scan='clear'`
  işaretlemesi aldı (030/040/150/190/210 + 020/098 sayım güncellemeleri).

## Emin olmadıklarım / sizin karar vermeniz gerekenler

1. **Sentry hesabı**: ücretsiz plan başlangıç için yeter (5k olay/ay); DSN'i
   üretip sırlara eklemek sizde.
2. **`enable_confirmations` üretimde ne zaman açılacak** — bu sürüm yayınlandıktan
   sonra açın; SMTP + oran sınırı notu §5.3'te.
3. **Keystore saklama** — üretip güvenli yerde yedeklemek sizde; kaybı geri
   alınamaz.
4. **Xcode kurulumu için ~45 GB disk** — hâlâ ilk engel.
5. **Bakım aralığı 45 gün** — pedagojik bir seçim (30'luk son adımdan uzun,
   sınav dönemine birkaç tekrar sığdıracak kadar kısa). Farklı bir değer
   isterseniz `ReviewScheduler.defaultMaintenanceIntervalDays` tek nokta.
6. **Anonim temizlikte 30 günlük esirgeme penceresi** (§5.3 sunucu ayağı) —
   makul varsayılan; kısaltmak isterseniz göçteki tek satır.

---

## Üretime çıkış runbook'u (sırayla)

1. **Supabase Dashboard → Database → Extensions**: `pg_cron` ve `pg_net`'i
   etkinleştirin (göç 0051'i çalıştırmadan ÖNCE).
2. **SQL Editor**: `supabase/migrations/202609030001..0900` dosyalarını
   SIRAYLA çalıştırın (10 dosya). `db push` KULLANMAYIN (mevcut kural).
3. **Vault + app_config** (cron HTTP işleri için — yapılmazsa lig cron'u yine
   çalışır; yalnız tarama süpürmesi ve anonim temizlik uyur):
   ```sql
   select vault.create_secret('<SERVICE_ROLE_KEY>', 'service_role_key');
   insert into public.app_config (key, value)
   values ('edge_base_url', 'https://<PROJE>.supabase.co/functions/v1')
   on conflict (key) do update set value = excluded.value;
   ```
4. **Edge fonksiyonları** (göçlerden SONRA):
   `supabase functions deploy analyze-question scan-photos delete-account`
   (send-push/cleanup-anonymous/guardian-confirm değişmedi ama yeniden deploy
   zararsız). `scan-photos` için `supabase/config.toml`'daki
   `[functions.scan-photos] verify_jwt = true` beyanı depoda.
5. **Auth ayarları**: SMTP yapılandır → e-posta oran sınırını yükselt →
   istemci yayını SONRASI `enable_confirmations` aç.
6. **Kontrol sorguları**: `select * from cron.job;` (3 iş görünmeli);
   `select count(*) from mistakes where photo_scan='pending' and
   created_at < now()-interval '1 hour';` (0 olmalı — değilse süpürücü
   ayaklanmamış demektir: 3. adımı kontrol edin).
7. **Uyumluluk notu**: eski (yayındaki) istemci yeni şemayla çalışır —
   `my_daily_state`'in eski sütunları duruyor; eski istemcinin bozuk seri
   maskesi görünümdeki kapılama sayesinde kendiliğinden doğru gösterir; yeni
   yüklemeler scan-photos'u çağırmadığı için paylaşım en fazla 10 dk (süpürücü)
   gecikir.

## Cihaz duman testi listesi (karartmalı Android APK + iOS)

soğuk açılış → karşılama → "ilk yanlışını çek" → **aktarım onayı sayfası** →
analiz → onay ekranında sebep metni (bulanık fotoğrafla deneyin) → kaydet →
Bugün ekranında ~3 saat sonrası için tekrar → onboarding: yaş kapısı → profil
→ maskot → bildirim izni (sistem penceresi ancak uygulama içi evet'ten sonra)
→ kayıt → **doğrulama ekranı** (yeniden gönder + başka cihazdan onaylayınca
otomatik ilerleme) → uçak modunda 2 soru çöz → ağı aç, uygulamaya dön →
kuyruk boşaldı + takvim İLERLEDİ mi → bildirimi kapat → arkadaşından istek
gönderilince push GELMEMELİ → tekrar aç → hatırlatma saatini değiştir (plan
anında güncellenmeli) → cihazı yeniden başlat → hatırlatma yine gelmeli →
çıkış yap → ikinci hesapla gir → öncekinin push'u GELMEMELİ.

## iOS derleme ve yayın adımları

`docs/ios-kurulum.md` — makine kurulumundan (45 GB disk, Xcode, Flutter,
CocoaPods) simülatöre, gerçek cihaz imzalamaya, push yetkisine (ücretli hesap)
ve E2E davranış kontrol listesine kadar. İlk başarılı derlemeden sonra
`ios/Podfile` + `ios/Podfile.lock` commit edilmeli.

## Kapanış ekleri (inceleme soruları)

**Yeni sütunlar kilit modelinde mi?** Evet. `photo_scan`/`photo_scan_at` →
lockdown v3'te (`20260903000700`) `locked` sınıfında — katalog doğrulamalı
blok sınıflandırılmamış kolonu zaten göçü kırarak yakalar; `next_review_at` →
`update` listesinde. pgTAP negatif iddiaları: `020_mistakes_column_lockdown.sql`
(+4 iddia: photo_scan UPDATE/INSERT ve photo_scan_at UPDATE kapalı,
next_review_at UPDATE açık). Tarama kotası ayrı sütun değil — mevcut
`rate_limits` tablosunda `scan` kovası; o tablonun tamamı politikasız RLS +
grant'sız (pgTAP 100'ün negatif iddiaları kapsıyor).

**`my_daily_state` drop'unda bağımlı düştü mü?** Hayır — görünüme bağımlı
hiçbir fonksiyon/görünüm yok (ondan select eden ya da `setof my_daily_state`
dönen tek nesne yok; grep ile doğrulandı; olsaydı `drop view` CASCADE'siz
zaten hata verirdi). Düşen tek şey 0040'taki `comment on view` idi; göç henüz
hiçbir ortamda uygulanmadığı için yorum aynı dosyada (`20260903000200`)
güncellenmiş metinle geri eklendi.

**Portre kilidi:** Info.plist iPhone'da yalnız portre, iPad'de portre+ters
portre + `UIRequiresFullScreen` (iPad'de tüm yönler desteklenmeyince App
Store'un beyan şartı). Niyet "yan çevrilince dönmesin" olduğu için Android'e
de `android:screenOrientation="portrait"` kondu.

**Tekrar motorunun sınav-tarihi davranışı** (ürün değerlendirmesi için):
`docs/tekrar-motoru-sinav-davranisi.md`.

**CI'nın ilk gerçek koşusunda yakalanan güvenlik açığı (düzeltildi):**
pgTAP süiti bugüne dek hiç çalıştırılmamıştı; ilk koşu, engel (block)
kontrolünün RLS'in altından kaçtığını gösterdi. `user_blocks`'ı bilerek yalnız
engelleyen görür; ama gönderim ve arkadaşlık-isteği politikaları engeli düz
alt sorguyla kontrol ediyordu ve politika alt sorgusu İŞLEMİ YAPANIN RLS'iyle
çalışır — engellenen kişi engel satırını göremediği için kontrol hep
geçiyordu: **engellenen kullanıcı, engelleyen kişiye soru ve arkadaşlık
isteği göndermeye devam edebiliyordu.** Çözüm `are_friends` deseni:
`is_blocked_between(a,b)` definer yardımcı fonksiyonu
(`20260903000800_block_enforcement.sql`) — iki politika da ona geçti,
beyaz listeye ve 098'e eklendi. 150_blocks'un 7 ve 11. iddiaları artık bu
korumayı gerçekten kanıtlıyor.

**CI kapanış sonuçları:** koşu #34136156237 — pgTAP 26 dosya / **413 iddia
PASS**, mutasyon **11/11** (üç faz), `analyze + test` ve `statik kontroller`
yeşil. İlk gerçek koşunun çıkardığı ve düzeltilen test-altyapısı hataları
(ürün kodu değişmedi, tek istisna yukarıdaki engel açığı): (1) 41 adet
`throws_ok(sql, kod, 'açıklama')` — 3. argüman pgTAP'ta hata MESAJI olarak
karşılaştırılır; hepsi `null` errmsg'li 4-argüman forma çevrildi. (2) Testler
başka kullanıcının satırını hedef rolün RLS'i altında sorguluyordu (bob'un
arkadaş kodu, alice/sahip'in soru kimliği) → alt sorgu boş dönüp çağrıyı
sessiz no-op yapıyordu; kimlikler ayrıcalıklı temp fikstürlere alındı ve
`SET ROLE` sonrası okunabilmeleri için açık `grant select` verildi.
(3) `mutations/` klasörü `supabase test db`'nin pgTAP süpürmesine takılıyordu
→ `supabase/mutations/`'a taşındı. (4) Eski mutantların geri almaları
tarama-öncesi kanonik metni kuruyordu → 0050 sürümüne güncellendi.
(5) 110'daki çarpan-tavanı testi lateral'da `generate_series`'e referans
vermiyordu; yeni PG volatil çağrıyı tek kez çalıştırıyordu. (6) 130'da onay
geri-alma kaydı aynı işlemde aynı `now()` damgasını alıp defter sıralamasını
belirsiz bırakıyordu; fikstüre açık +1 sn verildi. (7) 180'in `user_blocks`
INSERT iddiası tablo düzeyindeydi; kilit modeli kolon bazlı — iddia kolona
çevrildi.

## Değişen dosyalar (özet)

57 dosya değişti, 3 yeni (+9 göç, +4 pgTAP süiti, +4 mutasyon, +3 test
dosyası, scan-photos fonksiyonu, EmailVerifyStep, PrivacyScreen,
crash_service, proguard-rules): tam liste `git status` ile; başlıca gruplar
yukarıdaki bulgu bölümlerinde tek tek sayıldı.
