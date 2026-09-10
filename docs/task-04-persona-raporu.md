# Task 04 — Kimo Persona Sistemi Raporu

Durum: **istemci, sunucu ve testler yazıldı; doğrulama CI'da yapılacak.**

Doğrulama durumu: `check_sql` (62 göç, plan/iddia sayıları tutarlı) · `check_imports` ·
`check_symbols` — üçü de temiz. **`flutter analyze`, `flutter test` ve
`supabase db reset` + pgTAP bu makinede KOŞULAMADI:** ortamda Flutter SDK, Docker
ve Supabase CLI yok (`which flutter` → bulunamadı, `docker info` → kapalı).
Bu paketin derleme ve veritabanı doğrulaması ilk CI koşusunda yapılmalı; aşağıda
"nasıl doğrulandı" başlıkları hangi kontrolün gerçekten koştuğunu tek tek yazıyor.

---

## Özet

Persona = Kimo'nun **ses tonu**. Maskot tek, yüz tek; değişen yalnızca
bildirimlerin nasıl yazıldığı.

| | Önce | Sonra |
|---|---|---|
| Persona sayısı | 5 (akademisyen dâhil) | **4** |
| Görünen ad | "Adanalı Arabeskçi İsmail Hoşses Ayı" | "Adanalı Arabeskçi Kimo" |
| Metinlerin yeri | 200 satır Dart'ta + 105 satır SQL'de (75'i çift) | **200 satır yalnızca veritabanında** |
| Başlıklar | Dart ve SQL'de kopya | Tek tablo (`push_kinds`) |
| Seçim ekranı | Uzun adların sığmadığı çip kümesi | Örnek cümleli kart + kilit ekranı önizlemesi |
| Aynı metnin tekrarı | Mümkün (%20) | **İmkânsız** (istemci ve sunucu) |
| Geçersiz persona | Bildirimi sessizce düşürürdü | Göçte / RPC'de gürültüyle reddedilir |

---

## Ne yapıldı

### 1. Metinler tek kaynağa taşındı — artık uygulama güncellemesi gerekmiyor

**Ne:** `lib/data/mascot_lines.dart` (403 satır, 200 gömülü cümle) silindi.
Yerine `lib/data/notification_lines.dart`: metinleri sunucudaki `push_lines`
tablosundan okuyup `SharedPreferences`'a önbelleğe alan bir servis. Başlıklar da
tabloya taşındı (`push_kinds`).

**Neden bu yaklaşım:** Task'ın şartı "bir metnin tonunu düzeltmek veya persona
eklemek uygulama güncellemesi gerektirmemeli". Tek alternatif metinleri `.arb`'ye
taşımaktı — ama `.arb` de derlemeye giriyor, yani şartı karşılamıyordu.

**Tablo neden okunabilir yapılmadı:** `push_lines` Task 01'de kilitlendi (RLS
açık, politikasız, `revoke all`) ve öyle kalıyor — bildirim metni enjeksiyonu
minörlere giden bir kanalda ciddi bir vektör. Okuma yeni bir `security definer`
fonksiyondan geçiyor: `notification_lines()`. Sınıflandırma bilinçli: **salt
okuma, yazma yok, kişisel veri yok**; dönen içerik kullanıcının zaten
bildirimlerde gördüğü kendi kopyası. Fonksiyon `function_grants_recheck5`
beyaz listesinde; `send_push` listeye **girmedi**, kapalı kalmaya devam ediyor.

**Çevrimdışı:** Yerel hatırlatmalar cihazda planlanıyor ve ağ olmayabilir.
Önbellek hiç oluşmamışsa (yeni kurulum + çevrimdışı) tür başına **tek nötr yedek
cümle** devreye giriyor. Yedek cümle *içerik değil*, "bildirim hiç gitmesin"
olmasın diye emniyet kemeri: personayı duyurmaz ve ton düzeltmesi ona değil
tabloya yapılır. Kod içinde böyle işaretli.

**Dosyalar:** `lib/data/notification_lines.dart` (yeni), `lib/data/mascot_lines.dart`
(silindi), `lib/services/notification_service.dart`, `lib/main.dart`,
`lib/features/home/home_shell.dart`.

**Nasıl doğrulandı:** `test/data/notification_lines_test.dart` (12 test) —
önbellekten okuma, yer tutucu doldurma, bozuk önbellekte çökmeme, boş havuzda
nötr yedeğe düşme. `supabase/tests/240_persona.sql` — `notification_lines()`
`authenticated` tarafından çağrılabiliyor ve 200 satır dönüyor, `push_lines`
hâlâ okunamıyor. **Her ikisi de henüz koşmadı (bkz. durum satırı).**

### 2. Akademisyen çıkarıldı, adlar `<Persona> Kimo` biçimine geçti

**Ne:** `Mascot` enum'u dörde indi. Görünen ad, ton tarifi ve örnek cümle
enum'dan çıkıp `app_tr.arb`'ye geçti (arayüz metni oraya ait).

| Teknik anahtar | Eski ad | Yeni ad |
|---|---|---|
| `ev_hanimi` | Müşfik Ev Hanımı Ayı | **Anaç Kimo** |
| `arabeskci` | Adanalı Arabeskçi İsmail Hoşses Ayı | **Adanalı Arabeskçi Kimo** |
| `sanayi_ustasi` | Sanayi Ustası Ayı | **Sanayi Ustası Kimo** |
| `ceo` | CEO Ayı | **CEO Kimo** |
| `akademisyen` | Akademisyen Ayı | *(kaldırıldı)* |

Teknik anahtarlar **değişmedi**: veri göçünü gereksiz yere üçe katlardı ve
kullanıcıya görünen ad ile veritabanı değeri zaten ayrı alanlar.

Tasarım mock'unda adlar "Ev hanımı / Arabeskçi / Sanayi ustası / CEO" olarak
duruyor; task §2'nin `<Persona> Kimo` kuralı ve sizin "iki tane özel ad olmasın,
Adanalı Arabeskçi Kimo" notunuz mock'un kopyasını geçersiz kıldı.

**Göç:** `profiles.mascot` ve `auth.users.raw_user_meta_data` içindeki
`akademisyen` → `ev_hanimi` eşleniyor. Eşleme yapılmasaydı `Mascot.fromDb` null
dönerdi, `onboardingComplete` false olurdu ve mevcut kullanıcı karşılama akışına
geri düşerdi.

**Dosyalar:** `lib/models/mascot.dart`, `lib/l10n/app_tr.arb`,
`supabase/migrations/20260904000100_persona_lines.sql`.

### 3. Persona seçim ekranı — Claude Design `3b2`

**Ne:** `Wrap` + `KimoChip(label)` yerine tasarımın kendisi: başlık, kilit ekranı
önizlemesi, dört kart (radyo + ad + tırnak içinde örnek cümle), "Bu sesle devam
et" butonu ve altında beş parçalı adım göstergesi.

**Neden kahraman maskot kaldırıldı:** Eski sayfada tepede 120px bir Kimo vardı.
Ekranın tek işi dört tonun farkını beş saniyede duyurmak; 120px'lik maskot,
karşılaştırılacak dört cümleyi ekranın dışına iterdi. Maskot artık önizlemenin
içinde, gerçek bildirimde göründüğü boyutta (38px kutuda `Kimo(size: 30)`).

**Örnek cümleler nereden geliyor:** Karttaki dört cümle `.arb`'de — kullanıcı
henüz persona seçmeden görünmek zorundalar ve önbellek soğukken (yeni kurulum)
ekran boş kalamaz. Üstteki kilit ekranı önizlemesi ise **canlı havuzdan** aynı
senaryonun *başka* bir varyantını gösteriyor (tasarım da öyle: kart ile önizleme
farklı cümleler); havuz inmemişse karttaki örneğe düşüyor.

**Seçim artık zorunlu değil:** Tasarım ilk seçeneği ön seçili gösteriyor ve
buton "Bu sesle devam et" diyor. `_canContinue` bu adımda her zaman `true`;
varsayılan `Mascot.fallback` (= `ev_hanimi`), sunucudaki
`coalesce(mascot, 'ev_hanimi')` ile aynı.

**Ayarlar aynı kartı kullanıyor:** `mascot_sheet.dart` artık `PersonaCard`'ın
kendisini gösteriyor. İki yerde iki farklı düzen, kullanıcının onboarding'de
öğrendiği karşılaştırmayı ayarlarda yeniden öğrenmesini gerektirirdi. Sheet
ayrıca **ağı beklemeden kapanıyor**: `setMascot` artık üç ağ çağrısı yapıyor ve
eski hâlinde sheet göstergesiz asılı kalıyordu.

**Token eşlemesi:** Tasarımın literal renkleri mevcut `KimoColors`'a eşlendi;
ekran renk sabiti yazmıyor. Beş ara ton token setinde yok ve en yakın token'a
yuvarlandı — sapmalar aşağıda "çözülmeyenler"de.

**Dosyalar:** `lib/features/onboarding/persona_card.dart` (yeni),
`lib/features/onboarding/onboarding_flow.dart`,
`lib/features/onboarding/mascot_sheet.dart`,
`lib/widgets/kit/kimo_progress.dart` (`StepDots`), `lib/l10n/app_tr.arb`.

**Nasıl doğrulandı:** `test/features/onboarding/persona_card_test.dart` (6 test)
— dört kart, örnek cümleler, seçili kartın aksan zemini, erişilebilirlik
bayrağı, `StepDots` parça sayısı. **Henüz koşmadı.**

### 4. Bildirim akışındaki dört hata kapatıldı

| # | Hata | Düzeltme |
|---|---|---|
| 1 | **Persona değişikliği sunucuya gecikmeli ulaşıyordu.** `setMascot` yalnızca auth metadata'sına yazıyordu; `profiles.mascot`'a yazan tek yol `HomeShell`'in açılıştaki `ensureProfile`'ıydı. Ayarlardan sesini değiştiren kullanıcı, uygulamayı kapatıp açana kadar push'larını **eski sesle** alıyordu. | `setMascot` artık `ensureProfile`'ı da çağırıyor ve metin önbelleğini tazeliyor (`lib/state/user_profile.dart`). |
| 2 | **`push_lines`'ta PK/FK/CHECK yoktu** (Task 01 raporu "çözülmedi" md. 4) ve `upsert_my_profile.p_mascot` doğrulanmıyordu. Yazım hatası olan satır sessizce hiç seçilmiyor, bildirim **görünmeden** düşüyordu. | `primary key (kind, mascot, idx)`, `kind` → `push_kinds` yabancı anahtarı, `mascot` CHECK'i; `upsert_my_profile` geçersiz personada `22023` atıyor. Hata artık göç/çağrı zamanında gürültülü. |
| 3 | **Metin ve başlıklar ikiye katlanmıştı.** Üç senaryonun 75 cümlesi hem Dart'ta hem `push_lines`'ta; başlıklar `MascotLines.title` ile `send_push`'un `v_title` case'inde. Birini düzelten diğerini kaçırırdı. `send_push`'un `else` dalı hâlâ eski ürün adını (`'AI YKS Coach'`) taşıyordu. | Dart kopyası silindi, başlıklar `push_kinds`'a taşındı, varsayılan başlık `'Kimo'` oldu. |
| 4 | **Aynı metin arka arkaya gelebiliyordu.** İki tarafta da hafıza yoktu (`Random().nextInt` / `order by random()`); beş varyantta olasılık %20. Aynı cümleyi üst üste gören kullanıcı bildirimi okumayı bırakır — persona sisteminin varlık sebebi ortadan kalkar. | İstemcide `pickLineIndex` + `SharedPreferences` imleci; sunucuda `push_cursors` tablosu ve `send_push`'un dışlamalı seçimi. Tek varyant kaldıysa tekrara izin veriliyor: **tekrar etmiş bir hatırlatma, hiç gelmeyenden iyidir.** |

### 5. Şema — kilit modeline oturuşu

`lockdown_v3`'ün kolon kataloğundaki 10 tablodan **hiçbirine kolon eklenmedi**,
dolayısıyla `lockdown_v4` gerekmedi. `profiles.mascot` zaten `locked` kovasında
ve tek yazma yolu `upsert_my_profile`; bu doğru sınıflandırma korundu.

Yeni iki tablo (`push_kinds`, `push_cursors`) kolon kataloğuna değil,
**yalnızca-sunucu tabloları** kapısına girdi (`function_grants_recheck5`) —
uygulamaya hiç açılmadıkları için doğru kova bu. İkisinde de RLS açık ve
politika yok (Değişmez 6 korunuyor).

**Göçler:** `20260904000100_persona_lines.sql` (0055),
`20260904000200_function_grants_recheck5.sql` (0056).

### 6. Persona artık görünür bir kimlik işareti değil

`UserAvatar` fotoğraf yokken personanın emojisini (🧸/🎤/🔧/💼) ve rengini
gösteriyordu — arkadaş listesinde, ligde ve gelen kutusunda. Bu, "persona ayrı
bir karakter değil" kararının tam tersini gösteriyordu. Artık takma adın baş
harfi gösteriliyor (tasarım `3c`'deki avatar). `Mascot.emoji` ve `Mascot.color`
silindi; `LeagueEntry.mascot` ve `PublicProfile.mascot` alanları okunmadıkları
için kaldırıldı.

**Türkçe not:** `'i'.toUpperCase()` 'I' verir, doğrusu 'İ'. Tek harf
gösterildiği için bu fark doğrudan yanlış harf demek; `_Initial.initialOf`
i/ı çiftini elle ele alıyor.

---

## Ne DEĞİŞMEDİ (Task 03'ün bildirim düzeltmeleri)

Hiçbirine dokunulmadı; değişen tek şey metnin nereden geldiği:

- `resolveScheduledHour` — sessiz saate denk gelen hatırlatma düşmez, kayar.
  Sözleşmesi `test/services/notification_service_test.dart`'ta 6 vakayla kilitli
  ve **bu test değişmeden geçmeli**; dokunulmadığının kanıtı bu.
- `planDay` yalnız `[_idReviews, _idStreak, _idStreakTomorrow, _idComeback]`'i
  iptal ediyor; `_idLeague` bilerek dışarıda.
- `areEnabled`'ın iOS `checkPermissions` okuması.
- Anahtar kapatılınca `unregisterDevice`; çıkışta `unregister → cancelAll →
  signOut` sırası; `account_repository`'nin hesap silmede unregister'ı.
- Boot alıcısı beyanı ve `AndroidScheduleMode.inexactAllowWhileIdle`.
- Bildirim saatleri, sıklığı ve sessiz aralık mantığı.

Tek dokunuş: `_at`'in `zonedSchedule` çağrısındaki `catch (e)` → `catch (e, st)`
+ `reportError(context: 'notify.schedule')`. Eskiden yalnız `debugPrint`'ti;
planlanamayan hatırlatma sessizce kayboluyordu ve tek iz orasıydı.

---

## Doldurulan eksik kombinasyonlar

Boş **hücre** yoktu; eksik **varyant** vardı. `friend_league_up` ve
`friend_streak` persona başına 3 varyant taşıyordu, diğer sekiz senaryo 5.
İkisi de zaten baştan sona yeniden yazılıyordu (aşağı bak: hepsi kıyaslama
içeriyordu), o yüzden nötre düşürmek yerine **16 yeni cümle** yazıldı ve iki
senaryo da 5 varyanta çıktı.

Sonuç: **10 senaryo × 4 persona × 5 varyant = 200 satır, boş hücre yok.**

Garanti kodda değil iki yerde birden: göçün sonundaki `do` bloğu (hücre boşsa
göç patlar) ve `supabase/tests/240_persona.sql` (hücre boşalırsa CI kırmızı).

---

## Ton kuralı ihlalleri ve düzeltmeler

Kural: persona **ses tonunu** değiştirir, **baskı seviyesini** değiştirmez.
Altı kovada 58 satır düzeltildi.

| Kova | Ne demek | Adet |
|---|---|---|
| Kıyaslama | "sen kaçtasın?", "sen neredesin?", "rekabet kızışıyor" | 13 |
| Suçlama | "hâlâ çözmedin", "bugün mü bırakacaksın", "gitme demiştim" | 11 |
| Performans dili | metrik, hedef, "performans durdu", "ivme kaybediyoruz" | 11 |
| Kayıp dili | "çöpe gidiyor", "yandı", "elden gidiyor", "paslanıyor" | 10 |
| Duygusal yük | "içim rahat etsin", "benim her şeyimdi", "yokluğun ağır" | 7 |
| Tehdit / son şans | "son şansın", "sonrası yok", "son teslim" | 5 |
| Zorunluluk dili | "-malıyız" | 1 |

**CEO nasıl korundu:** CEO'nun ayırt ediciliği büyük ölçüde yasaklı dilden
geliyordu; düzeltme onu Usta'ya çevirebilirdi. Ayrım ekseni **baskıdan
konuşkanlık ve yakınlığa** kaydırıldı: CEO artık *net ve planlı* — metrik değil
sıra/öncelik dili ("Bugünün planında {n} soru var.", "Öncelik sırası hazır.").

**`friend_*` senaryolarının kalıbı değişti:** arkadaşı kutla, kullanıcıya dönme.
Kullanıcıya dönen her kuyruk ("sen de…", "sıra sende", "sen neredesin?")
kıyaslamadır ve 30 satırın neredeyse tamamı böyle bitiyordu. Migration yorumu
zaten amacı *"sosyal baskı değil, sosyal kanıt"* diye tanımlıyordu — yazılan
metinler baskı tarafına düşmüştü.

**İki başlık da değişti** (başlık personaya göre değişmiyor, hepsinde aynı):

| Eski | Yeni | Neden |
|---|---|---|
| `Serin tehlikede 🔥` | `Serini sürdür 🔥` | tehdit/kayıp dili |
| `Ligde son gün ⚔️` | `Lig haftası bitiyor 🏆` | kılıç da yarışma imgesiydi |

`notifyStepBody` de aynı sebeple düzeltildi ("serin tehlikeye girdiğinde" →
"serini sürdürme vaktinde").

---

## Bulduğum ama ÇÖZMEDİKLERİM

1. **`league_result` hâlâ ölü.** 20 metin tabloya taşındı ama hiçbir planlayıcı
   bu senaryoyu tetiklemiyor; `push_lines`'ta rows var, gönderen yok. Tetikleyici
   eklemek bildirim **zamanlaması** demek ve o Task 03'ün alanı, bu task'ın
   kapsam dışında. Metinler taşındı ki tetikleyici geldiğinde yazılacak bir şey
   kalmasın.

2. **`push.unregisterDevice()` hâlâ bellekteki `_token`'a bağlı.** Soğuk
   açılıştan sonra `registerDevice` koşmadan çıkış yapılırsa jeton sunucuda
   kalıyor — Task 03 §7.1'de kapatılan sızıntının kalan kenarı. Persona
   kapsamının dışında, dokunulmadı.

3. **Tasarımdan beş küçük sapma.** Tasarımın literal renklerinden beşi token
   setinde yok ve en yakın token'a yuvarlandı: seçili metin `#7A2E13`/`#FFB79B` →
   `actionText`, seçili kart gölgesi `#F0DACD` → `cardShadow`, boş radyo kenarı
   `#DDD3C6`/`#4A4239` → `border`. Ayrıca persona adı tasarımda Baloo 2 16.5/600,
   token setinde en yakını `t.section` (18/600). "Ekranlar renk sabiti yazmaz"
   kuralı bunlara token eklemekten daha değerli görüldü.

4. **Geri düğmesi tasarımda "‹ Geri" etiketli, kodda ikon.** Bu paylaşılan
   onboarding başlığı ve etiket eklemek yedi adımın hepsinde dokunma hedefini
   değiştirirdi. İkon kaldı; etiket zaten `tooltip`'te.

5. **"Adım n / N" sayısı tasarımla uyuşmuyor.** Tasarım "Adım 4 / 5" diyor; kod
   anonim kullanıcıda **7**, girişli kullanıcıda **4** adım üretiyor (kayıt ve
   e-posta doğrulama akışa dâhil). Gerçek sayı gösteriliyor; adım sayısını
   değiştirmek kapsam dışıydı.

6. **`profiles_public` görünümü hâlâ `mascot` yayınlıyor.** İstemci artık
   okumuyor. Görünümden çıkarmak bir göç daha demekti ve zararsız.

---

## Kapsam dışında değiştirmek zorunda kaldıklarım

- **`UserAvatar` API'si** (`mascot:` → `name:`) ve yedek görselin baş harfe
  dönmesi. `Mascot.emoji`/`color` silindiği için zorunluydu; 7 çağrı yeri
  güncellendi (gelen kutusu, arkadaşlar, lig, profil, herkese açık profil,
  soru gönderme).
- **Onboarding çerçevesi** — üstteki tek parça `KimoProgressBar` kalktı, alta
  beş parçalı `StepDots` geldi. Paylaşılan çerçeve olduğu için diğer altı adım
  da görsel olarak değişti. Tasarım `3a` da aynı parçalı göstergeyi kullanıyor,
  yani tutarlı. (Bu, planda sorulup onaylanan iki karardan biriydi.)
- **`LeagueEntry.mascot` / `PublicProfile.mascot`** alanları kaldırıldı —
  okunmayan alanlar.

---

## Sizin karar vermeniz gerekenler

1. **Doğrulama.** Bu paket derlenmemiş ve veritabanına uygulanmamış durumda
   (ortamda Flutter/Docker/Supabase CLI yok). İlk CI koşusu üç işi de
   sınayacak; `db` işi 0055'i uygularken `auth.users` güncellemesinin yerel
   ortamda **boş tabloda no-op** olacağını unutmayın — akademisyen eşlemesinin
   asıl doğrulaması canlı projede yapılmalı.

2. **CEO'nun yeni tonu.** "Net ve planlı" ekseni Usta'dan yeterince ayrışıyor
   mu? Beğenilmezse metinler artık **veride**: tek bir `update` yeterli, uygulama
   güncellemesi gerekmiyor. Bu değişikliğin asıl kazancı da bu.

3. **`league_result` tetikleyicisi** istiyor musunuz? Metinler hazır bekliyor;
   eklemek Task 03'ün zamanlama alanına dokunmayı gerektirir.

4. **Çevrimdışı yedeğin kapsamı.** Bugün tür başına tek nötr cümle var. Daha
   sağlam alternatif, göçten üretilen `assets/notification_lines.json` tohumu +
   CI'da `git diff --exit-code` kontrolü — persona soğuk açılışta da duyulur.
   Daha fazla makine getirdiği için önerilmedi; isterseniz eklenir.

---

## Değişen dosyalar

**Yeni:** `supabase/migrations/20260904000100_persona_lines.sql` ·
`supabase/migrations/20260904000200_function_grants_recheck5.sql` ·
`supabase/tests/240_persona.sql` · `supabase/mutations/12_persona_gap.sql` ·
`supabase/mutations/13_push_cursors_open.sql` ·
`lib/data/notification_lines.dart` · `lib/features/onboarding/persona_card.dart` ·
`test/data/notification_lines_test.dart` ·
`test/features/onboarding/persona_card_test.dart`

**Silinen:** `lib/data/mascot_lines.dart`

**Değişen:** `lib/models/mascot.dart` · `lib/models/social.dart` ·
`lib/state/user_profile.dart` · `lib/services/notification_service.dart` ·
`lib/main.dart` · `lib/l10n/app_tr.arb` · `lib/widgets/user_avatar.dart` ·
`lib/widgets/kit/kimo_progress.dart` ·
`lib/features/onboarding/onboarding_flow.dart` ·
`lib/features/onboarding/mascot_sheet.dart` ·
`lib/features/profile/settings_screen.dart` · `lib/features/home/home_shell.dart` ·
`lib/features/home/today_screen.dart` · `lib/features/league/league_screen.dart` ·
`lib/features/league/friends_view.dart` · `lib/features/inbox/inbox_screen.dart` ·
`lib/features/inbox/send_question_sheet.dart` ·
`lib/features/profile/profile_screen.dart` ·
`lib/features/social/public_profile_screen.dart` ·
`supabase/tests/098_function_grants.sql`

---

# Ek — taşınan metinlerin tam listesi

Toplam **200** satır · korunan **126** · düzeltilen **58** · yeni yazılan **16**

### Düzeltilen satırlar (eski → yeni)

| Senaryo | Persona | # | Kova | Eski | Yeni |
|---|---|---|---|---|---|
| `reviews_due` | ev_hanimi | 1 | suçlama | Canım, bugün {n} soru bekliyor seni. Üşenme e mi? | Canım, bugün {n} soru bekliyor seni. Hazır olunca başlarız. |
| `reviews_due` | arabeskci | 3 | duygusal yük | Bugün {n} soru… biraz acıtacak ama iyi gelecek. | Bugün {n} soru… ağırdan alalım, olur biter. |
| `reviews_due` | arabeskci | 4 | duygusal yük | Gel gel, {n} soru bekliyor. Kaçma kaderinden. | Gel gel, {n} soru bekliyor. Sen varsan kolay. |
| `reviews_due` | ceo | 3 | performans dili | Günlük hedefe {n} soru uzaktasın. | Bugünün planında {n} soru var. |
| `streak_risk` | ev_hanimi | 1 | duygusal yük | Canım, {n} günlük serin gidiyor. Bir soru çöz de içim rahat etsin. | Canım, {n} günlük serin duruyor. Tek soru yeter, sürer gider. |
| `streak_risk` | ev_hanimi | 2 | suçlama | Yavrum üşenme, tek soru yeter. {n} günlük emeğin var. | Yavrum, tek soru yeter. {n} günlük emeğin var. |
| `streak_risk` | ev_hanimi | 3 | suçlama | Akşam oldu, hâlâ soru çözmedin. Serini düşün biraz. | Akşam oldu. Bir soruyla serini sürdürebilirsin. |
| `streak_risk` | ev_hanimi | 5 | duygusal yük | Bir soru çöz de yatarken huzurlu olayım. | Bir soru çöz, günü kapatalım. |
| `streak_risk` | arabeskci | 1 | kayıp dili | Yandı gülüm {n} günlük serin, bir soru çöz de sönmesin. | {n} günlük serin bir alev gibi gülüm, bir soruyla parlar. |
| `streak_risk` | arabeskci | 2 | duygusal yük | Bu seri benim her şeyimdi… bırakma dostum. | Bu seri ikimizin dostum, bir soru yeter. |
| `streak_risk` | arabeskci | 3 | kayıp dili | {n} gün emek verdik, bir gecede yıkılmasın. | {n} gün emek verdik, bugün de bir soru koyalım üstüne. |
| `streak_risk` | arabeskci | 4 | duygusal yük | Gözüm yollarda, elin soruda olsun. | Akşamın sonuna bir soru yakışır dostum. |
| `streak_risk` | arabeskci | 5 | kayıp dili | Seri gidiyor, gitme diyemedim sana. | Seri sende dostum, bir soruyla sürsün. |
| `streak_risk` | sanayi_ustasi | 1 | kayıp dili | Usta, {n} günlük emek çöpe gidiyor. Geç tezgâha. | Usta, {n} günlük emek duruyor. Geç tezgâha. |
| `streak_risk` | sanayi_ustasi | 2 | suçlama | Bugün elini sürmedin. Bir soru, bitti gitti. | Bir soru, bitti gitti. |
| `streak_risk` | sanayi_ustasi | 3 | kayıp dili | Serinin ipi kopmak üzere. Bağla şunu. | Serinin ipi elinde. Bir düğüm daha at. |
| `streak_risk` | sanayi_ustasi | 4 | suçlama | {n} gün çalıştın, bugün mü bırakacaksın? | {n} gün çalıştın. Bugün bir soru, devamı gelir. |
| `streak_risk` | ceo | 1 | performans dili | {n} günlük seri risk altında. Bugünkü aksiyon tamamlanmadı. | {n} günlük seri sürüyor. Bugünün tek maddesi: bir soru. |
| `streak_risk` | ceo | 2 | performans dili | Günlük hedef sıfır. Kapatalım mı? | Bugünün listesi boş. Bir maddeyle kapatalım. |
| `streak_risk` | ceo | 3 | performans dili | Süreklilik metriğin bugün kırılıyor. Tek soru yeter. | Süreklilik planın sürüyor. Tek soru yeter. |
| `streak_risk` | ceo | 4 | performans dili | {n} gün üst üste performans — bugün düşürme. | {n} gün üst üste. Bugün de bir soru koyalım. |
| `streak_risk` | ceo | 5 | tehdit / son şans | Son teslim gece yarısı. Bir soru, seri devam. | Gün gece yarısı kapanıyor. Bir soru, seri devam. |
| `comeback` | ev_hanimi | 4 | suçlama | Hataların seni bekliyor, küsme onlara. | Hataların seni bekliyor, hazır olunca gel. |
| `comeback` | arabeskci | 1 | suçlama | {n} gündür yoksun… beni de sorularını da bıraktın. | {n} gündür yoksun… buralar sessiz kaldı. |
| `comeback` | arabeskci | 2 | suçlama | Gitme demiştim, gittin. | Yolun açık olsun dedim, dönüşünü bekledim. |
| `comeback` | arabeskci | 4 | duygusal yük | Yokluğun ağır dostum. | Bir türkü tuttum, sen gelince söyleriz dostum. |
| `comeback` | sanayi_ustasi | 3 | kayıp dili | Aletler paslanıyor. Gel şu işi yapalım. | Aletler yerinde. Gel şu işi yapalım. |
| `comeback` | ceo | 1 | performans dili | {n} gündür aktivite yok. | {n} gündür kayıt yok. |
| `comeback` | ceo | 2 | performans dili | Performans durdu. Yeniden başlayalım. | Plan beklemede. Yeniden başlayalım. |
| `comeback` | ceo | 4 | performans dili | Ara uzadı, ivme kaybediyoruz. | Ara uzadı. Kısa bir başlangıç yeter. |
| `league_last_day` | ev_hanimi | 2 | kayıp dili | Yavrum bugün kapanıyor, {sira}. sıradan kurtaralım seni. | Yavrum bugün kapanıyor, {sira}. sıradasın. Bir iki soru iyi gider. |
| `league_last_day` | ev_hanimi | 4 | kayıp dili | {lig} elden gidecek, biraz çabala. | {lig} haftası bitiyor, biraz çabala. |
| `league_last_day` | ev_hanimi | 5 | tehdit / son şans | Bugün son şansın, sonra üzülme. | Bugün son gün; ne yaparsan kâr. |
| `league_last_day` | arabeskci | 2 | kayıp dili | {lig} gidiyor elden, hâlâ tutabilirsin. | {lig} haftası kapanıyor, son sözü sen söyle. |
| `league_last_day` | sanayi_ustasi | 2 | kayıp dili | Hafta kapanıyor, {lig} elden gitmesin. | Hafta kapanıyor usta, {lig} haftasının son mesaisi. |
| `league_last_day` | sanayi_ustasi | 3 | suçlama | {sira}. sıra iyi değil. Bugün toparla. | {sira}. sıradasın. Bugün toparlarız. |
| `league_last_day` | sanayi_ustasi | 4 | tehdit / son şans | Mesai bitiyor, iş yarım. | Mesai bitiyor. Son bir parça iş var. |
| `league_last_day` | sanayi_ustasi | 5 | tehdit / son şans | Son çıkış bugün. Sonrası yok. | Son gün bugün. Elimizden geleni yapalım. |
| `league_last_day` | ceo | 2 | zorunluluk dili | Son gün. {sira}. sıradan yukarı çıkmalıyız. | Son gün. {sira}. sıradayız, yukarısı açık. |
| `league_last_day` | ceo | 3 | tehdit / son şans | {lig} pozisyonun risk altında. | {lig} haftası bugün kapanıyor. |
| `league_last_day` | ceo | 5 | suçlama | Son 24 saat. Sıralamayı düzelt. | Son gün. Sıralama hâlâ değişebilir. |
| `league_result` | ceo | 4 | performans dili | Sonuç: {lig}. Hedefleri güncelleyelim. | Sonuç: {lig}. Planı güncelleyelim. |
| `league_result` | ceo | 5 | performans dili | Performans değerlendirmesi: {lig}. | Hafta kapanışı: {lig}. |
| `question_received` | ev_hanimi | 4 | suçlama | Bir soru geldi {ad}'dan, kırma çocuğu. | Bir soru geldi {ad}'dan, vaktin olunca bak. |
| `question_received` | ceo | 2 | performans dili | Gelen soru: {ad}. Aksiyon bekliyor. | Gelen soru: {ad}. Sıraya aldım. |
| `friend_league_up` | ev_hanimi | 1 | kıyaslama | {ad} çok çalışmış, {lig} ligine çıkmış. Sen de geri kalma canım. | {ad} çok çalışmış, {lig} ligine çıkmış. Ne güzel haber. |
| `friend_league_up` | ev_hanimi | 3 | kıyaslama | {ad} yükselmiş {lig} ligine. Onu görünce içim açıldı, seni de bekliyorum. | {ad} yükselmiş {lig} ligine. Onu görünce içim açıldı. |
| `friend_league_up` | arabeskci | 1 | kıyaslama | {ad} çıktı {lig} ligine, biz burada kaldık dostum. | {ad} çıktı {lig} ligine, yolu açık olsun dostum. |
| `friend_league_up` | arabeskci | 3 | kıyaslama | {ad} yükseldi {lig}'e… Sen de yükselirsin, inanıyorum. | {ad} yükseldi {lig}'e… Bu sevinç dostun sevinci. |
| `friend_league_up` | sanayi_ustasi | 3 | kıyaslama | {ad} terfi etti: {lig}. Sen de kolları sıva. | {ad} terfi etti: {lig}. Helal olsun. |
| `friend_league_up` | ceo | 2 | kıyaslama | {ad} bir üst lige geçti: {lig}. Sen neredesin? | {ad} bir üst lige geçti: {lig}. Tebrikler ona. |
| `friend_league_up` | ceo | 3 | kıyaslama | {ad} performansıyla {lig} ligine çıktı. Sıra sende. | {ad} istikrarlı çalıştı ve {lig} ligine çıktı. |
| `friend_streak` | ev_hanimi | 2 | kıyaslama | Arkadaşın {ad} {n} günlük seriye ulaştı canım, sen de vakit ayır. | Arkadaşın {ad} {n} günlük seriye ulaştı canım. |
| `friend_streak` | arabeskci | 1 | kıyaslama | {ad} {n} gündür hiç bırakmadı. Sen de bırakma. | {ad} {n} gündür hiç bırakmadı. Helal olsun dostuma. |
| `friend_streak` | arabeskci | 3 | kıyaslama | {ad}'ın serisi {n} güne dayandı. Sen de dayan. | {ad}'ın serisi {n} güne dayandı. Dostun yolunda dostum. |
| `friend_streak` | sanayi_ustasi | 2 | kıyaslama | Arkadaşın {ad} {n} gün aksatmadı. Sen kaçtasın? | Arkadaşın {ad} {n} gün aksatmadı. Sağlam usta. |
| `friend_streak` | ceo | 2 | kıyaslama | Arkadaşın {ad} {n} günlük seride. Rekabet kızışıyor. | Arkadaşın {ad} {n} günlük seride. Tebrikler ona. |
| `friend_streak` | ceo | 3 | kıyaslama | {ad} {n} gündür istikrarlı. Sen de tempoyu koru. | {ad} {n} gündür istikrarlı. Güzel iş. |

### Yeni yazılan satırlar (eksik varyantlar)

| Senaryo | Persona | # | Metin |
|---|---|---|---|
| `friend_league_up` | ev_hanimi | 4 | {ad} için sevindim canım, artık {lig} liginde. |
| `friend_league_up` | ev_hanimi | 5 | Arkadaşın {ad} {lig} ligine çıkmış. Tebrik etsen sevinir. |
| `friend_league_up` | arabeskci | 4 | {ad} {lig} ligine geçti dostum, güzel haber böyle olur. |
| `friend_league_up` | arabeskci | 5 | Bir dost yükseldi: {ad}, artık {lig} liginde. |
| `friend_league_up` | sanayi_ustasi | 4 | {ad} {lig} ligine geçmiş. İyi iş. |
| `friend_league_up` | sanayi_ustasi | 5 | Haber var usta: {ad} artık {lig} liginde. |
| `friend_league_up` | ceo | 4 | Terfi haberi: {ad} artık {lig} liginde. |
| `friend_league_up` | ceo | 5 | {ad}'ın haftası iyi geçti — {lig}. |
| `friend_streak` | ev_hanimi | 4 | {ad} için sevindim: {n} gündür hiç aksatmamış. |
| `friend_streak` | ev_hanimi | 5 | Arkadaşın {ad} {n} günlük seride. Ne güzel. |
| `friend_streak` | arabeskci | 4 | {n} gün aralıksız… {ad} sağlam duruyor. |
| `friend_streak` | arabeskci | 5 | Dostun {ad} {n} gündür sözünde. Böylesi az bulunur. |
| `friend_streak` | sanayi_ustasi | 4 | {ad} {n} gündür vardiyayı kaçırmamış. |
| `friend_streak` | sanayi_ustasi | 5 | Usta işi: {ad}'ın serisi {n} günde. |
| `friend_streak` | ceo | 4 | {ad}'ın serisi {n} güne ulaştı. |
| `friend_streak` | ceo | 5 | Not: {ad} {n} gündür aralıksız çalışıyor. |

---

## Tam döküm

İşaretsiz satır orijinalinden **aynen** taşındı. **⟲** ton kuralı gereği düzeltildi, **✚** eksik varyant olarak yeni yazıldı.


### `reviews_due` — “Tekrar zamanı 🔁”

**ev_hanimi**

1. Canım, bugün {n} soru bekliyor seni. Hazır olunca başlarız. **⟲**
2. Sofra hazır, {n} tekrar seni bekliyor.
3. Yavrum, biraz oturup {n} soru çözsen?
4. Hataların seni özledi, {n} tane var.
5. Bir çay koy, {n} soruyu birlikte halledelim.

**arabeskci**

1. {n} soru var dostum, gel şu dertle yüzleşelim.
2. Eski hataların kapıda, {n} tane. Alalım içeri.
3. Bugün {n} soru… ağırdan alalım, olur biter. **⟲**
4. Gel gel, {n} soru bekliyor. Sen varsan kolay. **⟲**
5. Dert çok, soru {n}. Başlayalım.

**sanayi_ustasi**

1. Tezgâhta {n} soru duruyor usta.
2. {n} parça iş var, halledelim.
3. Bugünün yükü {n} soru. Kolay gelsin.
4. Aletleri kap, {n} soru bizi bekliyor.
5. İş birikmesin: {n} tekrar hazır.

**ceo**

1. Bugünün kuyruğu: {n} soru.
2. {n} görev açık. Kapatma zamanı.
3. Bugünün planında {n} soru var. **⟲**
4. {n} tekrar bekliyor. Öncelik sırası hazır.
5. Biriken iş: {n}. Bugün eritelim.


### `streak_risk` — “Serini sürdür 🔥”

**ev_hanimi**

1. Canım, {n} günlük serin duruyor. Tek soru yeter, sürer gider. **⟲**
2. Yavrum, tek soru yeter. {n} günlük emeğin var. **⟲**
3. Akşam oldu. Bir soruyla serini sürdürebilirsin. **⟲**
4. {n} gündür aksatmadın, bugün de aksatma olur mu?
5. Bir soru çöz, günü kapatalım. **⟲**

**arabeskci**

1. {n} günlük serin bir alev gibi gülüm, bir soruyla parlar. **⟲**
2. Bu seri ikimizin dostum, bir soru yeter. **⟲**
3. {n} gün emek verdik, bugün de bir soru koyalım üstüne. **⟲**
4. Akşamın sonuna bir soru yakışır dostum. **⟲**
5. Seri sende dostum, bir soruyla sürsün. **⟲**

**sanayi_ustasi**

1. Usta, {n} günlük emek duruyor. Geç tezgâha. **⟲**
2. Bir soru, bitti gitti. **⟲**
3. Serinin ipi elinde. Bir düğüm daha at. **⟲**
4. {n} gün çalıştın. Bugün bir soru, devamı gelir. **⟲**
5. Vardiya bitmedi. Bir soru kaldı.

**ceo**

1. {n} günlük seri sürüyor. Bugünün tek maddesi: bir soru. **⟲**
2. Bugünün listesi boş. Bir maddeyle kapatalım. **⟲**
3. Süreklilik planın sürüyor. Tek soru yeter. **⟲**
4. {n} gün üst üste. Bugün de bir soru koyalım. **⟲**
5. Gün gece yarısı kapanıyor. Bir soru, seri devam. **⟲**


### `comeback` — “Seni özledik 👋”

**ev_hanimi**

1. Günlerdir yoksun canım, merak ettim.
2. {n} gündür uğramadın, iyi misin?
3. Kapıyı açık bıraktım, istediğin zaman gel.
4. Hataların seni bekliyor, hazır olunca gel. **⟲**
5. Başlamak için bir soru yeter.

**arabeskci**

1. {n} gündür yoksun… buralar sessiz kaldı. **⟲**
2. Yolun açık olsun dedim, dönüşünü bekledim. **⟲**
3. Dönersen kapı açık, sorular da öyle.
4. Bir türkü tuttum, sen gelince söyleriz dostum. **⟲**
5. Bir soru çöz, eski günlere dönelim.

**sanayi_ustasi**

1. {n} gündür tezgâh boş usta.
2. İş birikti, gelsen iyi olur.
3. Aletler yerinde. Gel şu işi yapalım. **⟲**
4. Uzun mola oldu. Toparlanalım.
5. Kapıyı kapatmadım, bekliyorum.

**ceo**

1. {n} gündür kayıt yok. **⟲**
2. Plan beklemede. Yeniden başlayalım. **⟲**
3. Biriken iş büyüyor. Kısa bir seans yeter.
4. Ara uzadı. Kısa bir başlangıç yeter. **⟲**
5. Bugün on dakika ayır, toparlarız.


### `league_last_day` — “Lig haftası bitiyor 🏆”

**ev_hanimi**

1. Ligde {sira}. sıradasın canım, son gün. Biraz gayret!
2. Yavrum bugün kapanıyor, {sira}. sıradasın. Bir iki soru iyi gider. **⟲**
3. Son akşam. Bir iki soru, sıran yükselsin.
4. {lig} haftası bitiyor, biraz çabala. **⟲**
5. Bugün son gün; ne yaparsan kâr. **⟲**

**arabeskci**

1. Son gün dostum, {sira}. sıradayız. Kaderi değiştirelim.
2. {lig} haftası kapanıyor, son sözü sen söyle. **⟲**
3. Bu gece biter her şey. {sira}. sıra kader değil.
4. Az kaldı, bir hamle yeter.
5. Ağlamak yok, çözmek var. Son gün.

**sanayi_ustasi**

1. Son gün usta, {sira}. sıradasın. Vites büyüt.
2. Hafta kapanıyor usta, {lig} haftasının son mesaisi. **⟲**
3. {sira}. sıradasın. Bugün toparlarız. **⟲**
4. Mesai bitiyor. Son bir parça iş var. **⟲**
5. Son gün bugün. Elimizden geleni yapalım. **⟲**

**ceo**

1. Dönem kapanıyor. Sıra: {sira}.
2. Son gün. {sira}. sıradayız, yukarısı açık. **⟲**
3. {lig} haftası bugün kapanıyor. **⟲**
4. Bugün kapanış. Hedef: ilk beş.
5. Son gün. Sıralama hâlâ değişebilir. **⟲**


### `league_result` — “Hafta kapandı 🏆”

**ev_hanimi**

1. Müjde canım, {lig}'ndesin! Gurur duydum.
2. Yavrum {lig}'nde artık, helal olsun.
3. Bu hafta bitti, {lig}'ndesin. Aferin sana.
4. Emeklerin boşa gitmedi: {lig}.
5. Yeni hafta, yeni grup. {lig}'nde bekliyorum seni.

**arabeskci**

1. Yükseldik dostum, {lig}! Bu sevinç bizim.
2. Kaderimiz döndü, {lig}'ndeyiz.
3. Hafta bitti, {lig} yazıldı alnımıza.
4. Düştük ama bittik demek değil. {lig}'nde toparlarız.
5. Yeni hafta, yeni umut: {lig}.

**sanayi_ustasi**

1. Hafta kapandı, {lig}'ndesin. Hayırlı olsun.
2. Terfi var usta: {lig}.
3. Bu hafta iş iyi gitti: {lig}.
4. Düşmüşüz. Toparlanır, {lig}'nde çalışırız.
5. Yeni hafta başladı, tezgâh yeni: {lig}.

**ceo**

1. Dönem kapandı: {lig}. Tebrikler.
2. Terfi onaylandı — {lig}.
3. Yeni dönem, yeni lig: {lig}.
4. Sonuç: {lig}. Planı güncelleyelim. **⟲**
5. Hafta kapanışı: {lig}. **⟲**


### `question_received` — “Sana soru geldi 📨”

**ev_hanimi**

1. {ad} sana bir soru yolladı canım, bak bakalım.
2. Arkadaşından soru geldi; {ad} çözebilecek misin diye merak ediyor.
3. {ad}'ın gönderdiği soru masada duruyor.
4. Bir soru geldi {ad}'dan, vaktin olunca bak. **⟲**
5. {ad} seni düşünmüş, soru göndermiş.

**arabeskci**

1. {ad} bir soru yolladı, meydan okuyor sanki.
2. Dostun {ad}'dan bir soru… ağır olabilir.
3. {ad} attı soruyu, top sende.
4. Gel bakalım, {ad} ne yollamış.
5. {ad}'dan haber var, sorulu haber.

**sanayi_ustasi**

1. {ad} bir iş yolladı. Bak bakalım.
2. Tezgâha {ad}'dan soru düştü.
3. {ad} meydan okuyor usta.
4. İş geldi: {ad}'dan bir soru.
5. {ad} sınıyor seni. Göster kendini.

**ceo**

1. {ad}'dan yeni bir görev geldi.
2. Gelen soru: {ad}. Sıraya aldım. **⟲**
3. {ad} sana bir soru atadı.
4. Kuyruğuna {ad}'dan bir soru eklendi.
5. {ad} meydan okudu. Cevap ver.


### `friend_request` — “Arkadaşlık isteği 🤝”

**ev_hanimi**

1. {ad} arkadaş olmak istiyor canım.
2. Kapıda {ad} var, arkadaşlık istiyor.
3. {ad} seni eklemiş, bir bak istersen.
4. Yeni bir arkadaş: {ad}. Sevindim.
5. {ad}'dan istek geldi, bekletme.

**arabeskci**

1. {ad} dost olmak istiyor. Dostluk güzeldir.
2. Bir istek var {ad}'dan, gönül kapısı çalıyor.
3. {ad} elini uzatmış, tut istersen.
4. Yeni bir dost mu geliyor? {ad}.
5. {ad} arkadaşlık istedi, çok düşünme.

**sanayi_ustasi**

1. {ad} arkadaşlık istiyor. Karar senin.
2. Yeni çırak mı geliyor? {ad} istek attı.
3. {ad} ekibe katılmak istiyor.
4. İstek var: {ad}.
5. {ad} seni eklemiş usta.

**ceo**

1. {ad} ağına katılmak istiyor.
2. Yeni bağlantı talebi: {ad}.
3. {ad} arkadaşlık isteği gönderdi, onay bekliyor.
4. Çevren büyüyor: {ad}.
5. {ad}'dan istek. Değerlendir.


### `question_solved` — “Soru çözüldü ✅”

**ev_hanimi**

1. {ad} gönderdiğin soruyu çözdü, aferin ona.
2. Soruna cevap geldi canım, {ad} bakmış.
3. {ad} çözmüş bile, hadi bir tane daha yolla.
4. Gönderdiğin soru boş kalmadı, {ad} uğraşmış.
5. {ad}'dan haber var: soru çözüldü.

**arabeskci**

1. {ad} çözdü soruyu, helal olsun.
2. Yolladığın soru cevabını buldu: {ad}.
3. {ad} altından kalktı, sen de boş durma.
4. Soru gitti, cevap geldi. {ad}.
5. {ad} meydanı boş bırakmadı.

**sanayi_ustasi**

1. {ad} işi bitirmiş.
2. Yolladığın soruyu {ad} halletti.
3. {ad} tezgâhtan kalkmış, çözmüş.
4. İş tamam: {ad} çözdü.
5. {ad} eli yatkınmış, çözdü soruyu.

**ceo**

1. {ad} gönderdiğin soruyu kapattı.
2. Görev tamamlandı: {ad}.
3. {ad} çözdü. Bir tane daha gönder.
4. Sonuç geldi: {ad} yanıtladı.
5. {ad} teslim etti.


### `friend_league_up` — “Arkadaşın yükseldi 🏆”

**ev_hanimi**

1. {ad} çok çalışmış, {lig} ligine çıkmış. Ne güzel haber. **⟲**
2. Arkadaşın {ad} bu hafta ligi atladı, {lig}'e geçti. Maşallah.
3. {ad} yükselmiş {lig} ligine. Onu görünce içim açıldı. **⟲**
4. {ad} için sevindim canım, artık {lig} liginde. **✚**
5. Arkadaşın {ad} {lig} ligine çıkmış. Tebrik etsen sevinir. **✚**

**arabeskci**

1. {ad} çıktı {lig} ligine, yolu açık olsun dostum. **⟲**
2. Duydun mu, {ad} bir üst lige uçtu. {lig} artık onun.
3. {ad} yükseldi {lig}'e… Bu sevinç dostun sevinci. **⟲**
4. {ad} {lig} ligine geçti dostum, güzel haber böyle olur. **✚**
5. Bir dost yükseldi: {ad}, artık {lig} liginde. **✚**

**sanayi_ustasi**

1. {ad} tezgâhı sıkı çalıştırmış, {lig} ligine geçti.
2. Usta, {ad} bir üst lige çıktı. {lig}'de şimdi.
3. {ad} terfi etti: {lig}. Helal olsun. **⟲**
4. {ad} {lig} ligine geçmiş. İyi iş. **✚**
5. Haber var usta: {ad} artık {lig} liginde. **✚**

**ceo**

1. {ad} bu hafta {lig} ligine terfi etti.
2. {ad} bir üst lige geçti: {lig}. Tebrikler ona. **⟲**
3. {ad} istikrarlı çalıştı ve {lig} ligine çıktı. **⟲**
4. Terfi haberi: {ad} artık {lig} liginde. **✚**
5. {ad}'ın haftası iyi geçti — {lig}. **✚**


### `friend_streak` — “Arkadaşın seri yapıyor 🔥”

**ev_hanimi**

1. {ad} tam {n} gündür aksatmıyor. Ne çalışkan çocuk.
2. Arkadaşın {ad} {n} günlük seriye ulaştı canım. **⟲**
3. {ad} {n} gündür her gün soru çözüyor. Helal olsun ona.
4. {ad} için sevindim: {n} gündür hiç aksatmamış. **✚**
5. Arkadaşın {ad} {n} günlük seride. Ne güzel. **✚**

**arabeskci**

1. {ad} {n} gündür hiç bırakmadı. Helal olsun dostuma. **⟲**
2. Dostun {ad} {n} günlük seri yaptı, yürek ister bu.
3. {ad}'ın serisi {n} güne dayandı. Dostun yolunda dostum. **⟲**
4. {n} gün aralıksız… {ad} sağlam duruyor. **✚**
5. Dostun {ad} {n} gündür sözünde. Böylesi az bulunur. **✚**

**sanayi_ustasi**

1. {ad} {n} gündür tezgâhın başında. Adam gibi iş.
2. Arkadaşın {ad} {n} gün aksatmadı. Sağlam usta. **⟲**
3. {ad} {n} günlük seriyi devirdi. Helal.
4. {ad} {n} gündür vardiyayı kaçırmamış. **✚**
5. Usta işi: {ad}'ın serisi {n} günde. **✚**

**ceo**

1. {ad} {n} gün üst üste hedefini tutturdu.
2. Arkadaşın {ad} {n} günlük seride. Tebrikler ona. **⟲**
3. {ad} {n} gündür istikrarlı. Güzel iş. **⟲**
4. {ad}'ın serisi {n} güne ulaştı. **✚**
5. Not: {ad} {n} gündür aralıksız çalışıyor. **✚**

