# Task 07 — Yayın uyumluluğu raporu

Durum: **kod tamamlandı ve commit edildi. Kalan iş dağıtım ve yayın — metinlerin
bir URL'e konması, dört adresin `supabase.json`'a girilmesi ve
`app_config.legal_version`'ın yazılması.**

Bu paket, `docs/hukuki-metinler.md` §2'de belgelenen mağaza uyum bayraklarından
**altısını** kapatıyor (A-1, A-3, A-4, A-5, A-6, A-7) ve A-11'in metnini
hazırlıyor. Üç ürün kararı da uygulandı: veli onayı kaldırıldı, uygulama 13+
olarak konumlandı, yaptırım altyapısı yazıldı.

**Doğrulama durumu.** Yerelde koşan: `flutter analyze` (yalnızca Task 04'ten
kalan bir deprecation `info`), `flutter test` (**158/158**), `check_sql`
(71 göç, `plan(n)` sayıları iddia sayılarıyla birebir), `check_imports`,
`check_symbols`, `flutter pub get` + `gen-l10n`. **Yerelde KOŞMAYAN: pgTAP
süiti ve mutasyon kontrolü** — bu makinede Docker ve Supabase CLI yok (Task
06'daki aynı kısıt). İki yeni test dosyası, üç genişletilmiş test dosyası
(net **+68 iddia**, toplam **551**) ve **beş yeni mutasyon** ilk CI koşusunda
doğrulanacak. Her başlığın altında hangi kontrolün gerçekten koştuğu yazıyor.

---

## Özet

| | Önce | Sonra |
|---|---|---|
| Veli onayı | Mekanizma var ama **hiç çalışmıyor** (`?t=` ≠ `token`) | **Tamamen kaldırıldı**; 13+ rejimi |
| 13 yaş sınırı | Koşullarda ilan edilecek, kodda **5 yaş** kabul ediliyor | `set_birth_year` 13'ün altını `KM013` ile reddediyor |
| Yaş adımı | Ağ hatasında **atlanabiliyor** | Doğum yılı yazılmadan ilerlenemiyor |
| 18 altı arkadaş ekleme | Veli onayına kilitli (yani **kalıcı kapalı**) | Açık; kısıt yalnızca anonimlik ve askı |
| Koşul onayı | **Hiç alınmıyor** | Kayıt adımında, sürüm damgasıyla deftere |
| Kullanıcıyı durdurma | **Hiçbir mekanizma yok** | Askı + kalıcı yasak, dört politikada zorlanıyor |
| Uygunsuz içerikte tekrar | Fotoğraf sessizce düşüyor, **yaptırım yok** | Uyarı → uyarı → 7 gün askı → kalıcı yasak |
| Kullanıcıya geri bildirim | **Hiç yok** | Uygulama içi uyarı + askı ekranı + itiraz yolu |
| "Fotoğraf orada saklanmaz" | Yanlış beyan | Düzeltildi (model eğitiminde kullanılmaz, kısa süre tutulabilir) |
| "Yalnızca senin arşivinde" | Yönetici erişimini dışlıyor gibi | Düzeltildi |
| Yasal metinler ekranı | "Hazırlanıyor" yer tutucusu | Dört gerçek bağlantı (adres yoksa satır çizilmiyor) |
| Veli e-posta adresi | Toplanıyor, onay sonrası **silinmiyor** | Sütun ve tablo düşürüldü |

---

## Ne yapıldı

### 1. Veli onayı kaldırıldı — düzeltilerek değil (A-1)

**Bulgu.** Mekanizma **hiç çalışmamıştı.** `send_guardian_email` bağlantıyı
`?t=<token>` ile kuruyor, `guardian-confirm` edge fonksiyonu `token`
parametresini okuyordu. İsimler uyuşmadığı için token boş okunuyor, biçim
kontrolü düşüyor ve **her onay "bağlantı geçersiz" ile sonuçlanıyordu.** Yani
bugüne kadar tek bir veli onayı bile tamamlanmadı — ve 18 altı her kullanıcıda
arkadaş ekleme kalıcı olarak kapalıydı.

**Ne yapıldı** (`0063`). Mekanizmanın tamamı düştü:

| Ne | Nerede |
|---|---|
| `request_guardian_consent(text)` | fonksiyon düşürüldü |
| `confirm_guardian_consent(text)` | fonksiyon düşürüldü |
| `send_guardian_email(text,text,text)` | fonksiyon düşürüldü |
| `my_guardian_status()` | `my_age_status()` ile değiştirildi |
| `public.guardian_requests` | tablo düşürüldü |
| `profiles.guardian_email` | sütun düşürüldü |
| `guardian_confirm_url`, `email_api_url`, `email_api_key`, `email_from` | `app_config` satırları silindi |
| `supabase/functions/guardian-confirm/` | dizin silindi |
| `[functions.guardian-confirm]` | `config.toml` bloğu silindi |
| 13 ARB anahtarı | `ageMinorTitle/Body`, `ageGuardian*`, `guardianStatus*`, `settingsGuardian`, `friendsAddBlockedByGuardian` |

**Neden bu yaklaşım — üç gerekçe:**

1. **Hukuken zorunlu değil.** COPPA 13 altı için geçerli, KVKK'da çocuklara özel
   bir madde yok, Apple veli onayını Kids Category'de arıyor, Play Families 13
   altını hedefleyenler için. Sektör pratiği: koşullarda belirtilir, mekanizma
   kurulmaz.
2. **Mekanizma bir koruma değil, bir görüntü üretiyordu.** Velinin kimliği
   hiçbir şekilde doğrulanamıyordu — öğrenci kendi ikinci e-posta adresini
   girip kendi kendine onay verebilirdi. Bu, hukuki metinlerin §7 Soru 3'ünde
   zaten açıkça yazılmıştı.
3. **Veri minimizasyonu.** `guardian_email` ve `guardian_requests` ÜÇÜNCÜ bir
   kişinin adresini tutuyordu ve onay tamamlandıktan sonra bile silmiyordu.
   Ölü bir akış için kişisel veri saklamanın gerekçesi yok (KVKK Md. 4/2-ç).

**YERİNDE BIRAKILANLAR — bilinçli:**

- **`user_consents` içindeki `guardian` satırları ve CHECK değeri.** Defter
  DEĞİŞTİRİLEMEZ (Değişmez 7); geçmiş kayıtları geçersiz kılacak bir CHECK tam
  da o değişmezi bozardı. `record_consent` artık o türü kabul etmiyor — yazma
  yolu kapandı, geçmiş duruyor. `source` CHECK'indeki `guardian_email` de aynı
  gerekçeyle kaldı.
- **`is_minor_now(uuid)`.** Artık hiçbir özelliği kapatmıyor ama yaş
  derecelendirmesi ve ayarlardaki durum satırı için duruyor.
- **`profiles.birth_year`.** 13 sınırı için gerekli.

**`db reset` neden kırılmadı.** Eski göçler (lockdown v2/v3, cascade_audit,
recheck7) 0063'ten **önce** çalışıyor; nesneler o an duruyor ve kapılarından
geçiyorlar. Yalnızca yeni kapı (`0065`) düşürülen adları listelememeli — ve
listelemiyor; üstelik geri gelmediklerini **göç zamanında** doğruluyor.

**Nasıl doğrulandı.** `check_sql` temiz. pgTAP `130_age_gate.sql`
(`130_guardian.sql`ın yerini aldı, 22 iddia) **CI'da koşacak**: altı nesnenin
katalogda **olmadığını** (`hasnt_table` / `hasnt_column` / `hasnt_function`)
tek tek iddia ediyor. `180_lockdown_v2.sql`ın üç iddiası (guardian sütunu,
tablosu ve okunamazlığı) kırılıyordu; ikisi "hiç yok" iddiasına dönüştürüldü,
üçüncüsü yaşayan bir sunucu-özel tabloya (`user_sanctions`) taşındı — plan
sayısı değişmedi.

### 2. 18 altı arkadaş ekleme açıldı (karar)

**Ne yapıldı.** `can_add_friends(u)` = `not is_anonymous(u) and not is_suspended(u)`.
Yaş koşulu tamamen kalktı.

**Neden düşük riskli — dört mekanizma:**

1. **Arkadaş eklemenin TEK yolu 6 haneli `friend_code`.** Keşif yok, takma adla
   arama yok (`social_repository.search` Task 02'de kaldırılmıştı). Kodu
   bilmeyen kimse istek gönderemiyor.
2. **Saatte 20 deneme sınırı** (`bump_rate_limit('friend_code', 20, …)`) —
   kod uzayını taramak ucuz değil.
3. **Kod döndürülebiliyor** (günde bir kez): taciz durumunda kaçış yolu.
4. **Engelleme + şikâyet + yeni askıya alma.**

Yani "yabancıyla temas kurma" yüzeyi **yapısal olarak yok**; veli onayı bu
yüzeyi zaten kapatmıyordu, yalnızca kod alışverişini geciktiriyordu.

**Nasıl doğrulandı.** `130_age_gate.sql` 13 yaşındaki bir kullanıcının
`add_friend_by_code` ile **gerçekten istek gönderebildiğini** ve satırın
yazıldığını iddia ediyor. Kapının açıldığını kanıtlamak, kapandığını
kanıtlamak kadar önemli: sessizce kapalı kalan bir özellik, veli onayı
kaldırılırken çıkabilecek en sinsi gerileme olurdu.

### 3. 13 yaş sınırı sunucuda zorlanıyor (A-7)

**Bulgu.** `set_birth_year` 5–100 yaş aralığını kabul ediyordu. Kullanım
Koşulları 13 yaş sınırı ilan edecekse, 8 yaşındaki bir kullanıcının kayıt
olabilmesi beyan-gerçek uyumsuzluğu olurdu (App Store 5.1.1 / Play Data Safety).

**Ne yapıldı** (`0063`). Üst sınır `v_now - 5` → `v_now - 13`. Ret **ayrı bir
SQLSTATE** ile geliyor: `KM013`.

**Neden ayrı bir hata kodu.** İstemcinin "geçersiz yıl" (yazım hatası) ile "çok
küçüksün" (yaş kapısı) arasını ayırt edip **nazik bir açıklama** gösterebilmesi
için. Aynı kodla dönseydi ya iki durum tek metinde birleşirdi ya da istemci
Türkçe hata mesajı eşleştirmek zorunda kalırdı — kırılgan.

**Neden çark aralığı daraltılmadı.** Yalnızca geçerli yılları göstermek kapıyı
**ortadan kaldırırdı**: kullanıcı reddedilmez, sadece yalan söylerdi. Nötr yaş
kapısının davranışı budur — yıl serbestçe girilir, sunucu reddeder ve kullanıcı
NEDEN reddedildiğini öğrenir.

**Hesap kilitlenmiyor.** Reddedilen deneme bir YAZMA değil, dolayısıyla tek
yazımlık hak harcanmıyor; kullanıcı başka bir yıl girebilir. Nötr yaş kapısının
bilinen sınırı bu; alternatifi (reddedilen yılı kaydedip hesabı kapatmak)
çarkta yanlış kaydırmayı kalıcı cezaya çevirirdi.

**Yaş adımı artık atlanamıyor.** `_canContinue[_Step.age]` doğum yılının
yazılmasını şart koşuyor. Eski bypass'ın gerekçesi "atlayan kullanıcı sunucuda
reşit olmayan sayılır, arkadaş ekleme kapalı kalır"dı; veli onayı kalkınca o
kapalı taraf da kalktı ve bypass 13 sınırını atlatan bir deliğe dönüştü.

**Nasıl doğrulandı.** `130_age_gate.sql`: 12 ve 8 yaş `KM013` ile reddediliyor,
**13 yaşın kendisi kabul ediliyor** (sınır dâhil), 120 yaş hâlâ `22023`,
reddedilen denemeden sonra `birth_year` **hâlâ boş**, ikinci çağrı reddediliyor.
Mutasyon `21` sınırı 5 yaşa geri alıp testin bunu ayırt ettiğini kanıtlıyor.

### 4. Kullanım koşulları ve gizlilik onayı (A-4)

**Bulgu.** Onboarding'de kabul adımı yoktu; `user_consents.kind` CHECK'i
`terms`/`privacy` türlerini kabul etmiyordu. Apple 1.2 kullanıcı içeriği
barındıran uygulamalarda koşul kabulü arıyor.

**Ne yapıldı** (`0063`).

- `user_consents.text_version` sütunu eklendi, `kind` CHECK'i genişletildi.
- Yeni `accept_legal_terms()` RPC'si iki satır yazıyor (`terms`, `privacy`),
  `source='signup'`, sürümü `app_config.legal_version`'dan alıyor.
- Kayıt adımına ön seçili **olmayan** onay kutusu; iki metin **ayrı ayrı**
  tıklanabilir. `_canContinue` kutu işaretlenmeden düğmeyi açmıyor.
- `_register()` sırası: **önce onay, sonra `convertToPermanent`.**

**Neden bu yaklaşım — dört karar:**

1. **`record_consent`'in imzasına dokunulmadı.** Postgres'te farklı imza AYRI
   fonksiyondur (`20240101001500_fix_admin_update.sql`ın dersi); parametre
   eklemek çağrı yerlerini ve grant testlerini kırardı. Ayrı bir RPC hem daha
   temiz hem de sürümü ZORUNLU kılıyor.
2. **Sürümü sunucu belirliyor.** Onayın ispat değeri, sürümü kullanıcının
   beyan etmesine bağlı olamaz. `record_consent` artık `terms`/`privacy`
   kabul etmiyor: sürümsüz bir koşul onayı, ispat değeri olmayan bir kayıttır.
3. **İki ayrı satır, tek kutu.** Kullanıcı tek kutuyu işaretliyor ama iki ayrı
   belgeyi kabul ediyor; defterde ayrı durmaları, biri güncellendiğinde
   diğerinin onayının bozulmamasını sağlıyor.
4. **Onay ÖNCE yazılıyor.** Ters sırada, onay yazımı başarısız olsaydı ortada
   onayı olmayan kalıcı bir hesap kalırdı. Anonim oturumda `auth.uid()` zaten
   var ve `updateUser` dönüşümünde değişmiyor, yani onay doğru hesaba yazılıyor.

**KVKK aydınlatması için ayrı onay kaydı YOK** ve olmamalı: aydınlatma bir
bilgilendirme yükümlülüğüdür, onaya tabi değildir.

**Nasıl doğrulandı.** `065_consents.sql` 13 → **27 iddia**: sürüm sütunu var,
iki satır yazılıyor, `source='signup'`, aynı sürüm ikinci kez yazılmıyor,
**sürüm değişince yeni satır** yazılıyor, `record_consent` üç türü de
reddediyor, `text_version` geriye dönük değiştirilemiyor. Mutasyon `22`
sürümü null yazıp testin bunu ayırt ettiğini kanıtlıyor.

### 5. Yaptırım altyapısı (A-3 · §4.1 + §4.2)

**Bulgu.** Yönetici yalnızca İÇERİK kaldırabiliyordu. `ban`/`suspend`/`askıya`
taraması depoda tek bir yorum satırı dışında sonuçsuzdu. App Store Review
Guideline 1.2'nin dört şartından biri — *"the ability to eject abusive users
from the service"* — karşılanmıyordu. Ayrıca içerik taraması çalışıyordu ama
kullanıcıya **hiçbir geri bildirim** gitmiyordu ve tekrar edende yaptırım yoktu.

**Ne yapıldı** (`0062`). İki politikasız defter:

```
public.user_sanctions    (action: suspend|ban|lift, until, reason_code,
                          source: auto_photo|admin, actor_id, note, voided_at)
public.photo_violations  (mistake_id, strike_no, acknowledged_at, voided_at)
```

+ `is_suspended(uuid)` + `mistakes` üzerinde bir tetikleyici + beş RPC.

**Merdiven** (tetikleyicide, `photo_scan` → `flagged` geçişinde):

| Tespit | Ne oluyor |
|---|---|
| 1. | İhlal kaydedilir, kullanıcıya **nazik uyarı** |
| 2. | İhlal kaydedilir, uyarı **sertleşir** |
| 3. (180 gün içinde) | **7 günlük otomatik askı** + yönetici kuyruğu |
| Askıdan sonra yeni ihlal | **Kalıcı yasak** |

**Neden bu tasarım — yedi karar:**

1. **Sütun değil, politikasız tablo.** `profiles`e sütun eklemek tam bir
   `lockdown_v*` göçü zorunlu kılıyor; ayrıca `public.admins` emsali daha
   güçlü: RLS açık + **politika yok** = yapısal olarak deny-by-default.
   İleride biri yanlışlıkla geniş bir GRANT yazsa bile kapı açılmaz.
2. **Defter, durum sütunu değil.** Yaptırımın geçmişi olmak zorunda: itiraz,
   yönetici incelemesi ve "askıdan sonra tekrar ihlal" kuralı geçmişe bakıyor.
   Güncel durum en son satırdan **türetiliyor** — süreli askı kendiliğinden
   doluyor, **cron gerekmiyor**.
3. **Sayaç ayrı defterde, `mistakes`ten türetilmiyor.** "Kaç kez işaretlendi"
   sorusu `mistakes where photo_scan='flagged'` ile de yanıtlanabilirdi, ama
   kullanıcı kendi hatasını silebiliyor — sayaç sıfırlanabilir hâle gelirdi.
   `mistake_id` bu yüzden `on delete set null`.
4. **Tetikleyici, edge fonksiyonu değil.** `photo_scan='flagged'` yazan üç yol
   var (kullanıcı hızlı yolu, pg_cron süpürücüsü, elle yönetici yazması).
   Tetikleyici hepsini tek kapıdan geçiriyor ve `photo_scan` zaten KİLİTLİ bir
   sütun, yani istemci bu kapıyı çalamıyor.
5. **180 günlük kayan pencere, ömür boyu defter.** Tetikleyen şey otomatik bir
   sınıflandırıcı ve yanlış pozitifi var; üç yıla yayılmış üç kareyi bugünkü
   askının üçte biri saymak orantısız olurdu. Defterin KENDİSİ ömür boyu
   duruyor — yönetici hem 180 günlük hem ömür boyu sayacı görüyor.
6. **Otomatik karar SÜRELİ.** Makine hatasının bedelini sınırlamak için.
   Kalıcı yasağı ya tekrar (yani insan davranışı) ya da yönetici veriyor.
7. **Okuma açık kalıyor.** Askıdaki kullanıcı kendi arşivini görüyor, tekrar
   yapıyor, ligde duruyor, hesabını silebiliyor, engelleyebiliyor ve şikâyet
   edebiliyor. Kapanan tek şey ÜRETİM. Ceza uygulamadan atmak değil, başkasına
   dokunmayı durdurmak.

**Yasağın zorlanması — dört politika + bir fonksiyon:**

| Yer | Ne kapanıyor |
|---|---|
| `"Kendi hatanı ekle"` (mistakes INSERT) | hata satırı |
| `"Kendi fotolarını yükle"` (storage.objects INSERT) | depolama nesnesi |
| `sends_insert_friend` (question_sends INSERT) | soru gönderimi |
| `friendships_insert_own` (friendships INSERT) | arkadaşlık isteği |
| `can_add_friends` içindeki `not is_suspended` | `add_friend_by_code` (definer, RLS'i atlıyor) |

Satır ve nesne AYRI yollar: yalnızca birini kapatmak diğerini açık bırakırdı.

**`is_suspended` neden `security definer` ve `authenticated`'a açık.**
`20260903000800_block_enforcement.sql` bu tuzağa düşülüp düzeltilmiş: politika
ifadeleri ÇAĞIRANIN yetkisiyle değerlendiriliyor, dolayısıyla politikanın
içindeki düz bir `not exists (select 1 from user_sanctions …)` **her zaman TRUE**
dönerdi ve yasak hiç uygulanmazdı.

**Yanlış pozitif kullanıcıyı kilitlemiyor.** `admin_review_photo_scan(id,'clear')`
genişletildi: ilgili ihlal `voided_at` alıyor, sayaç eşiğin altına düşerse
OTOMATİK askı geçersiz kılınıyor ve deftere bir `lift` satırı yazılıyor. Sahibin
kendi fotoğrafına erişimi zaten hiçbir durumda kısıtlanmıyordu.

**Kullanıcıya bakan yüz.** Yeni `SuspendedScreen`: ne kapandı, ne zamana kadar,
**neler hâlâ açık** ve **itiraz yolu** (destek adresine tek dokunuşla giden
bağlantı). Ekran bir DUVAR değil — "Uygulamaya dön" ile geçiliyor; yasağı
zorlayan şey ekran değil, politikalar. İhlal uyarısı ana ekran açılışında
gösteriliyor ve `ack_photo_warnings` ile işaretleniyor.

**Push KULLANILMADI — bilinçli.** Yeni bir `push_kind`, dört persona × beş
varyant = **20 yeni metin**, `240_persona.sql`de üç sabit sayının güncellenmesi
ve Dart'ta üç yerde aynı yazım demekti. Yaptırım geri bildirimi uygulama içi
kaldı.

**Nasıl doğrulandı.** `270_sanctions.sql` (**44 iddia**) CI'da koşacak: yapı
(iki tablo, RLS açık, **politika sayısı 0**, hiçbir uygulama rolüne açık değil),
negatif (kullanıcı kendi askısını kaldıramıyor, ihlalini silemiyor/geçersiz
kılamıyor), merdiven (1-2 ceza değil, 3. askı, `until ≈ +7 gün`), kalıcı yasak
(süre dolduktan sonraki ihlal `ban`, `until is null`), pencere (200 gün önceki
iki ihlal eşiği doldurmuyor), yanlış pozitif geri alma, zorlama ve **aşırı
kilitleme kontrolü**.

Zorlama testi **ayırt edici**: aynı INSERT askıdan ÖNCE `lives_ok`, askıdan
SONRA `throws_ok('42501')`. Yalnızca "reddedildi" demek, reddin askıdan
geldiğini kanıtlamazdı. Mutasyonlar `18` (defterleri aç), `19` (politikalardan
askı koşulunu çıkar) ve `20` (pencereyi kaldır) bunu üç ayrı yönden hedefliyor.

### 6. Uygulama içindeki iki yanlış cümle (A-5)

| Metin | Eski | Yeni |
|---|---|---|
| `aiConsentBody` | "Fotoğraf orada saklanmaz" | "Kim olduğun gönderilmez. Fotoğrafın orada model eğitiminde kullanılmaz, ama kötüye kullanım denetimi için kısa bir süre tutulabilir." |
| `privacyAiBody` | "fotoğraf yalnızca senin arşivinde saklanır" | "…senin arşivinde saklanır; yalnızca sen, gönderdiğin arkadaşın ve bir şikâyet ya da güvenlik incelemesi hâlinde yetkili moderatörümüz görebilir." |

İkisine de gerekçeyi taşıyan `@` açıklama bloğu eklendi: kodda sıfır-saklama
(ZDR) ayarı, `store:false` parametresi ya da ilgili bir başlık **yok**;
`can_read_mistake_photo` `is_admin()` ile kısa devre yapıyor.

**Nasıl doğrulandı.** `flutter analyze` + `gen-l10n` temiz; iki cümle hukuki
metinlerdeki karşılıklarıyla birebir hizalandı (§4.5, §5.3, §5.4).

### 7. Yasal metin bağlantıları (A-6)

**Ne yapıldı.** `privacyLegalPlaceholder` silindi. Yeni `LegalLinks`
(`SupabaseConfig` deseni): `LEGAL_TERMS_URL`, `LEGAL_PRIVACY_URL`,
`LEGAL_KVKK_URL`, `LEGAL_DELETE_URL`, `SUPPORT_EMAIL`.

**Neden `--dart-define`, sunucu değil.** `app_config` istemciye **tamamen
kapalı** (servis rolü anahtarı orada duruyor) ve bir bağlantı listesi için ona
kapı açmak orantısız olurdu. Onay kaydındaki metin SÜRÜMÜ ise sunucudan
geliyor: onun ispat değeri var, adresin yok.

**Adres verilmemişse satır HİÇ ÇİZİLMİYOR.** Yer tutucu bilinçli olarak geri
getirilmedi — mağaza incelemesinde doğrudan sorulan şey oydu. Kırık bir
bağlantı göstermek, göstermemekten kötü.

**Yeni bağımlılık: `url_launcher`.** Depo "tek kullanım için bağımlılık
eklemiyor" ilkesine sahip; burada istisna yapıldı çünkü koşul bağlantısı mağaza
şartı ve URL açmanın başka yolu yok. `shared_preferences` ile aynı durum: paket
zaten GEÇİŞLİ olarak geliyordu, `pubspec.lock`ta yalnızca `transitive` →
`direct main` satırı değişti, sürüm değişmedi.

### 8. Hukuki metinler 1.1'e revize edildi

`docs/hukuki-metinler.md` sürüm 1.0 → **1.1**. Değişenler §"Hukuki metinlerde
ne değişti" başlığında; metinlerin tam hâli bu raporun sonunda.

---

## Ne DEĞİŞMEDİ

- **Onay defterinin değiştirilemezliği.** `user_consents`'te UPDATE/DELETE hâlâ
  hiçbir role verilmiyor; yeni `text_version` sütunu da aynı korumanın altında.
- **Sütun ayrıcalıkları.** `lockdown_v4` v3'ün listesini aynen taşıyor;
  `profiles`ta tek yazılabilir sütun hâlâ `avatar_path`.
- **Sunucu tarafı yazma yolları, depolama sahiplik kuralları, persona
  metinlerinin veride kalması, kota mekanizması.** Hiçbirine dokunulmadı.
- **Fotoğrafın yaş kapısından ÖNCE OpenAI'a gitmesi (A-2).** Kapsam dışı ve
  hâlâ açık — kalan bayrakların **en kırılganı**.
- **A-8 (engel kaldırma arayüzü), A-9 (tek soru silme), A-10 (havuz altyapısı).**
  Kapsam dışı.
- **Askıdaki kullanıcının HÂLİHAZIRDA paylaşılmış içeriği.** `public_questions`
  ve `received_questions` görünümlerine askı koşulu **eklenmedi**: ortak havuz
  A-10 ile kapsam dışı ve gönderilmiş bir soruyu geriye dönük yok etmek
  moderasyon ekseninin (`moderation='removed'`) işi.
- **Giriş ekranındaki `email_not_confirmed` dalı ve `resendSignUp`.** Task
  06'da bilinçli korunmuştu (üretimde doğrulamanın kapalı olduğu henüz teyit
  edilmedi — C-5). Hukuki metinlerdeki e-posta doğrulaması ifadeleri
  temizlendi, kodda o kaçış yolu duruyor.
- **`profiles.exam_track` ve `grade` ölü sütunları.** `lockdown_v4` yazarken
  karşıma çıktılar; **düşürmedim** — ayrı bir karar (aşağıda).
- **AI maliyet kontrolünün P1/P2/P3 paketleri** (ölçüme bağlı) ve **paywall.**

---

## Kaldırılan veli onayı bileşenleri ve geri getirme reçetesi

**Geri getirilmesi gerekirse ne yapılacak.** Aşağıdaki hepsi git geçmişinde
`3f9c4ba`'nın ebeveyninde (`65c6b3e`) duruyor:

```bash
git show 65c6b3e:supabase/functions/guardian-confirm/index.ts
git show 65c6b3e:supabase/migrations/20260902000500_age_and_guardian.sql
git show 65c6b3e:supabase/tests/130_guardian.sql
git show 65c6b3e:lib/features/onboarding/age_gate_step.dart
```

| Bileşen | Nasıl geri gelir |
|---|---|
| `request_guardian_consent`, `confirm_guardian_consent`, `send_guardian_email`, `my_guardian_status` | `0043`teki gövdeler yeni bir göçe kopyalanır |
| `public.guardian_requests` | `0043`teki DDL + `revoke all` + `lockdown_v5`e eklenmesi |
| `profiles.guardian_email` | `alter table … add column` + `lockdown_v5`in `locked` listesine |
| `can_add_friends`ın veli dalı | `0046`daki gövde geri yazılır |
| `guardian-confirm` edge fonksiyonu | Yukarıdaki `git show` çıktısı + `config.toml` bloğu |
| 13 ARB anahtarı ve `AgeGateStep`in veli kartı | `git show` çıktısından |
| `record_consent`in `guardian` türü | Fonksiyondaki `p_kind not in (…)` listesine eklenir |
| `0065`in "veli nesneleri geri gelmiş" kapısı | **Kaldırılmalı**, yoksa göç patlar |

**Ama önce şu ikisi düzeltilmeli:** (a) `?t=` → `?token=` uyuşmazlığı — mekanizma
onsuz yine çalışmaz; (b) `text_version` alanı — o gün yoktu, artık defterde var
ve veli onayı da sürümlenmeli.

**Ve şunu bilerek not ediyorum:** geri getirmek, kaldırılırken sayılan üç
gerekçeyi (hukuken zorunlu değil · velinin kimliği doğrulanamıyor · üçüncü
kişinin adresi saklanıyor) ortadan kaldırmıyor.

---

## Dağıtım adımları

**Sırayla.** Göçler `0062` → `0063` → `0064` → `0065` bu sırayla uygulanmalı;
`0064` (lockdown) `0063`ün düşürdüğü sütunu listelemiyor, `0065` (kapı) en
sonda olmalı.

1. **Göçler.** `20260905000100` … `20260905000400`. README'ye göre üretimde
   göçler **elle SQL Editor'a yapıştırılıyor**; `supabase db push`
   **ÇALIŞTIRILMAMALI**.
2. **Edge fonksiyonu dağıtımı gerekmiyor.** `guardian-confirm` silindi; kalan
   fonksiyonların hiçbiri değişmedi.
3. **Uygulama yeniden derlenmeli** — `--dart-define-from-file=supabase.json`
   ile ve yeni anahtarlarla.

### ⚠️ Atlanırsa SESSİZCE çalışmayacak adımlar

| Adım | Atlanırsa ne olur | Nasıl anlaşılır |
|---|---|---|
| **`app_config.legal_version` yazılmalı** | Onaylar `1.0` damgalanır — yayınlanan metin 1.1 olduğu hâlde. Kayıt akışı **durmaz**, hata **vermez**; yalnızca sunucu günlüğüne `raise warning` düşer | `select text_version from user_consents where kind='terms'` |
| **`LEGAL_TERMS_URL` / `LEGAL_PRIVACY_URL` girilmeli** | Kayıt adımındaki iki metin **düz yazı** olur, tıklanmaz. Onay kutusu yine çalışır, yani kullanıcı **okuyamadığı** bir belgeyi kabul eder | Kayıt ekranında bağlantılar altı çizili değilse |
| **`LEGAL_KVKK_URL` / `LEGAL_DELETE_URL` girilmeli** | Ayarlar → Veri ve Gizlilik'te o satırlar **hiç çizilmez**. Hiçbiri girilmezse yasal bölümün tamamı kaybolur — A-6 sessizce geri gelir | Ekranda "Yasal metinler" başlığı yoksa |
| **`SUPPORT_EMAIL` girilmeli** | Askı ekranındaki **itiraz düğmesi** "destek adresi henüz tanımlı değil" der. Yaptırım var, itiraz yolu yok — 1.2 açısından en kötü kombinasyon | Askı ekranını elle açıp denemek |
| **Hesap silme sayfası yayınlanmalı** ve adresi **Play Console'a** girilmeli | Play gönderimi engellenir (A-11) | Play Console → Veri güvenliği |
| **Metinler bir URL'de yayınlanmalı**, aynı adres ASC ve Play Console'a girilmeli | Gizlilik politikası bağlantısı ikisinde de **zorunlu alan** | Konsol formu |

**Not:** `legal_version` dışında hiçbiri veritabanı işi değil — hepsi derleme
yapılandırması. Yani bir adres unutulursa **yeni bir sürüm gerekir**, göç değil.

```sql
-- Metinler yayınlandıktan sonra, tek seferlik:
insert into public.app_config (key, value) values ('legal_version', '1.1')
on conflict (key) do update set value = excluded.value;
```

---

## Kapsam dışında değiştirmek zorunda kaldıklarım

| Ne | Neden zorunluydu |
|---|---|
| `admin_review_photo_scan(uuid,text)` genişletildi | Yanlış pozitif geri alma olmadan "yanlış pozitif kullanıcıyı kilitlemesin" şartı karşılanamıyordu. `clear` dalı artık ihlali de geçersiz kılıyor ve gerekirse otomatik askıyı kaldırıyor |
| `supabase/tests/180_lockdown_v2.sql` | Üç iddiası düşürülen guardian nesnelerine bakıyordu; **kırılırdı**. İkisi "hiç yok" iddiasına döndü, üçüncüsünün hedefi `user_sanctions` oldu. Plan sayısı değişmedi |
| `supabase/tests/120_friend_code.sql` | `set_birth_year` çağrısının yorumu artık yanlıştı ("kapı açılsın" — kapı yaşa bağlı değil). Çağrı yerinde, yorum düzeltildi |
| `supabase/tests/098_function_grants.sql` | Yeni RPC'lerin grant durumu bir yerde iddia edilmeliydi (+9 iddia) |
| `pubspec.yaml` / `pubspec.lock` | `url_launcher` (yukarıda gerekçesi). CI `git diff --exit-code pubspec.lock` koşuyor, birlikte commit edildi |
| `README.md` | "Kayıt akışına yaş/veli onayı adımı baştan tasarlanacaktır" diyordu — artık yanlış beyan |
| `FlaggedPhoto` modeline `ownerId` | Yaptırım kararı içeriğe değil KİŞİYE veriliyor; kuyruk satırından sahibin kimliği gerekiyordu. RPC bunu zaten döndürüyordu, model taşımıyordu |
| `supabase/config.toml` | `[functions.guardian-confirm]` bloğu, silinen fonksiyona işaret ediyordu |
| `0065`e cascade kapısı eklendi | `0048`in kapısı KENDİ zamanındaki katalogla karşılaştırıyor; iki yeni defteri **hiç görmüyordu**. Hesap silmede satır bırakırlarsa "tüm kayıtlar silinir" beyanı yanlış olurdu |

---

## Emin olmadıklarım ve karar vermeniz gerekenler

### 1. `KM013` özel SQLSTATE'i — deponun ilki, yerelde koşulmadı

Supabase istemcisi `PostgrestException.code`'u geçiriyor ve Postgres 5 karakterli
özel SQLSTATE'lere izin veriyor, ama bu **ilk CI koşusunda doğrulanacak**. Düşerse
alternatif: mesaj eşlemesi (`e.message.contains('13 yaş')`) — daha kırılgan.
Testte iddia var (`throws_ok('KM013')`), yani CI kırmızı yanarsa hemen görülür.

### 2. Erken kaldırılan askı yine "sicilde" sayılıyor

"Askıdan sonraki ihlal → kalıcı yasak" kuralı, geçmişte **geçersiz kılınmamış**
bir `auto_photo` askısı olmasına bakıyor. Yönetici bir askıyı `lift` ile erken
kaldırsa bile o askı sayılıyor; yalnızca **yanlış pozitif olduğu anlaşılıp**
`voided_at` alan askılar sayılmıyor.

Kasten böyle: erken kaldırma bir **af**, sicil temizliği değil. Ama bu bir ürün
kararı — farklı istiyorsanız `lift` de sicili silsin diye değiştirilebilir
(tetikleyicideki `v_prior` sorgusuna bir koşul).

### 3. `actor_id` cascade istisnası — gelecekteki bir göç için tuzak

`user_sanctions.actor_id` `on delete set null` ve `auth.users`a bakıyor. Deponun
değişmezi "auth.users'a bakan her FK cascade olmalı" diyor. İstisna **bilinçli**:
cascade olsaydı bir yöneticinin hesabını silmesi, BAŞKALARI hakkındaki yaptırım
kayıtlarını da silerdi. `0065`in kapısı istisnayı **sütun adına göre** tanıyor
ve iki yerde belgelendi — ama **yeni bir cascade denetimi yazan kişi aynı
istisnayı taşımak zorunda**, yoksa göç patlar.

### 4. pgTAP ve mutasyon yerelde koşmadı

Bu makinede Docker ve Supabase CLI yok. **68 yeni iddia ve 5 yeni mutasyon ilk
CI koşusunda doğrulanacak.** Riskli gördüğüm noktalar, öncelik sırasıyla:

- `hasnt_function(schema, name, args, desc)` 4-argümanlı biçimi — pgTAP'te
  `name[]` aşırı yüklemesiyle karışmasın diye açıkça `'{text}'::name[]` yazıldı.
- `270`in tetikleyici testleri, `mistakes`e ayrıcalıklı rolle satır ekleyip
  `photo_scan`ı elle `'flagged'` yapıyor. Tetikleyici `when` yan tümcesi
  geçişi doğru yakalamazsa iddialar düşer.
- `065`teki `app_config` yazımı `tests.reset_role()` altında yapılıyor.

### 5. Karar vermeniz gerekenler

| Konu | Bugünkü davranış | Alternatif |
|---|---|---|
| **`profiles.exam_track` ve `grade`** | Ölü sütunlar; **düşürmedim** | Düşürülürse `lockdown_v5` gerekir ve envanterdeki "toplanmıyor" beyanı şemayla da uyuşur. Küçük bir iş, ayrı bir karar |
| **Askıdaki kullanıcının eski içeriği** | Havuzda ve gelen kutularında **kalıyor** | `public_questions`a `not is_suspended(m.user_id)` eklenebilir; A-10 kapsam dışı olduğu için dokunmadım |
| **Sürüm değişince yeniden onay** | Akış **yok**; eski onay geçerli sayılıyor (§6 Md. 15 "kullanmaya devam kabuldür") | Hukukçu yeniden onay isterse uygulama içi bir akış yazılmalı |
| **13 altı reddi hesabı bricklemiyor** | Kullanıcı başka bir yıl girip geçebilir | Reddedilen yılı kaydedip hesabı kapatmak daha katı; çarkta yanlış kaydırmayı kalıcı cezaya çevirir |
| **Giriş ekranındaki `resendSignUp`** | Duruyor (Task 06 kararı) | Üretimde `enable_confirmations = false` teyit edilirse kaldırılabilir (C-5) |

### 6. Hâlâ açık ve en kırılgan bayrak: A-2

Soru fotoğrafı **yaş kapısından önce** OpenAI'a gidiyor: onboarding sırası
`firstCapture → age → …`. Kapsam dışıydı ve dokunmadım, ama 13 sınırını
zorlamaya başladığımız hâlde fotoğrafın yaş bilinmeden yurt dışına çıkması
bir çelişki üretiyor. Hukuki belgedeki (b) çözümü — çekimi yerinde bırakıp
**analizi** yaş adımına kadar ertelemek — mevcut "fotoğrafsız devam" yolu
sayesinde ucuz görünüyor.

---

## Hukuki metinlerde ne değişti

| Bölüm | Değişiklik |
|---|---|
| Üstbilgi | Sürüm 1.0 → **1.1**, dayanak commit `3f9c4ba`, "1.1'de ne değişti" kutusu |
| §1.1 envanter | Veli e-postası satırı **düştü**; doğum yılının amacı "13 sınırı" olarak düzeltildi; e-posta doğrulamasının kaldırıldığı not edildi |
| §1.7 onay kayıtları | `terms`/`privacy` türleri, `text_version` alanı ve sürümün **sunucudan** geldiği; "sürüm tutulmuyor" uyarısı kalktı |
| §1.9 saklama | Anonim hesaplardaki "30 güne kadar" dalı **çıktı**; yaptırım defterlerinin saklama davranışı eklendi |
| §1.9 cascade listesi | `guardian_requests` çıktı, `user_sanctions` + `photo_violations` girdi |
| §1.10 aktarım | **E-posta sağlayıcısı alıcı listesinden düştü** — uygulama artık hiçbir e-posta sağlayıcısına veri göndermiyor |
| §2 bayrakları | A-1, A-3, A-4, A-5, A-6, A-7 **"KAPANDI"**; A-11 "metin hazır, yayın sizde"; B-3 ve C-4 düştü; C-5 genişletildi |
| §3 mağaza formları | Veli e-postası kalemleri çıktı; App Review notu **1.2'nin dört şartını** sayacak şekilde yeniden yazıldı |
| KVKK §2 | "Yaş ve veli bilgisi" → "Yaş bilgisi"; onay kayıtlarına sürüm; **yeni (h) maddesi**: uyum kayıtları |
| KVKK §3, §4 | Veli onayı amacı ve dayanağı çıktı; 13 sınırı ve yaptırım kayıtları için iki yeni satır |
| KVKK §6 | E-posta sağlayıcısı satırı çıktı |
| KVKK §7 | "30 güne kadar" çıktı; uyum kayıtlarının saklama süresi ve 180 günlük pencere eklendi |
| **KVKK §8** | Tamamen yeniden yazıldı: 13+ beyanı, sınırın **kodda zorlandığı**, veli onayından **neden vazgeçildiği**, velilere yasal temsilci yolu |
| Gizlilik "Bir bakışta" | Veli onayı satırı düzeltildi; yaptırım satırı eklendi |
| Gizlilik §1, §4, §6, §7 | Veli e-postası çıktı; uyum kayıtları ve onay sürümü eklendi; e-posta sağlayıcısı çıktı; "30 gün" çıktı |
| **Gizlilik §9** | Yeniden yazıldı: 13+ sınırının teknik olarak uygulandığı, kod tabanlı arkadaşlık, veli onayının olmadığı |
| Gizlilik §11 (GDPR) | "Çocuklar" satırı: AB'de 16'ya kadar çıkabilen yaş sınırı için yol gösterildi |
| **Koşullar §3** | 13 sınırı ve teknik olarak uygulandığı; veli onayı şartı çıktı; **koşul kabulünün sürümüyle kaydedildiği** eklendi |
| **Koşullar §7** | **Kademeli yaptırım tablosu**, 180 günlük pencere, yanlış pozitif geri alma, kısıtlamanın neyi kapatıp neyi kapatmadığı, **itiraz yolu** |
| Koşullar §6, §14 | "askıya alınır" → "geçici olarak kısıtlanır veya kalıcı olarak kapatılır"; kısıtlama ekranının ne gösterdiği |
| Koşullar §13 | 18 altı satın almada veli onayı mekanizması olmadığı; cihaz düzeyi kısıtlama önerisi |
| §7 Soru 3 | **Konusuz kaldı**; karar gerekçesiyle kayda geçti, daraltılmış bir soru bırakıldı (TMK ehliyet) |
| §7 Soru 4 | **Teknik karşılığı yazıldı**; kalan soru: sürüm değişince yeniden onay gerekir mi |
| §7.4 kontrol listesi | Yeniden yazıldı; `legal_version` ve dart-define anahtarları **sessizce eksik kalacak adımlar** olarak işaretlendi |

---

## Değişen dosyalar

**Yeni göçler (sırayla):**
`20260905000100_sanctions.sql` (0062) ·
`20260905000200_guardian_removal.sql` (0063) ·
`20260905000300_lockdown_v4.sql` (0064) ·
`20260905000400_function_grants_recheck8.sql` (0065)

**Yeni testler:** `supabase/tests/130_age_gate.sql` (22) ·
`supabase/tests/270_sanctions.sql` (44) · `test/data/sanction_test.dart` (12)
**Genişletilenler:** `065_consents.sql` (13→27) · `098_function_grants.sql` (22→31)
**Düzeltilenler:** `180_lockdown_v2.sql` · `120_friend_code.sql`
**Silinen:** `supabase/tests/130_guardian.sql`

**Yeni mutasyonlar:** `18_sanctions_open` · `19_ban_not_enforced` ·
`20_violation_no_window` · `21_age_floor_open` · `22_consent_unversioned`

**Yeni Dart:** `lib/data/sanction_repository.dart` ·
`lib/services/legal_links.dart` · `lib/features/settings/suspended_screen.dart`

**Değişen Dart:** `daily_state_repository` · `moderation_repository` ·
`onboarding_flow` · `age_gate_step` · `auth_gate` · `home_shell` ·
`moderation_screen` · `privacy_screen` · `settings_screen` · `friends_view` ·
`app_tr.arb`

**Silinen:** `supabase/functions/guardian-confirm/`

**Diğer:** `pubspec.yaml`/`pubspec.lock` · `supabase.example.json` ·
`supabase/config.toml` · `README.md` · `docs/hukuki-metinler.md` ·
`docs/hesap-silme-sayfasi.md`

---

# Güncellenmiş hukuki metinler (tam hâlleriyle)

> **Bu üç metin `docs/hukuki-metinler.md` §4, §5 ve §6'dan OLDUĞU GİBİ
> alınmıştır** — elle kopyalanmadı, dosyadan çıkarıldı, yani birebir aynı.
> **Bakım yeri `hukuki-metinler.md`dir;** buradaki kopya bu raporun
> yazıldığı andaki (sürüm **1.1**) fotoğrafıdır. İkisi ileride ayrışırsa
> `hukuki-metinler.md` doğrudur.
>
> Köşeli parantezli alanlar (`[şirket unvanı]`, `[iletişim e-postası]`,
> `[gizlilik politikası URL'i]` …) **yayından önce doldurulmalıdır**;
> `[Yayın öncesi karar]` ile başlayan kutular editör notudur, yayınlanmadan
> önce silinir.

## 4. KVKK Aydınlatma Metni

> **Bu bölüm yayına hazır metindir.** Köşeli parantezleri doldurup olduğu gibi
> kullanabilirsiniz. `[Yayın öncesi karar]` ile başlayan kutular editör
> notudur — yayınlamadan önce silin.

---

### [uygulama adı] — Kişisel Verilerin Korunması Hakkında Aydınlatma Metni

**Son güncelleme:** [tarih] · **Sürüm:** 1.1

Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu'nun ("KVKK") 10.
maddesi uyarınca hazırlanmıştır. Amacı, uygulamayı kullandığınızda hangi
bilgilerinizi neden işlediğimizi, kimlerle paylaştığımızı ve haklarınızı sade
bir dille anlatmaktır.

Uygulamayı kullananların çoğu lise öğrencisi. Bu yüzden metni hem öğrencinin
hem velisinin okuyabileceği bir dille yazdık. Anlamadığınız bir yer olursa
[iletişim e-postası] adresine yazın, açıklayalım.

#### 1. Veri sorumlusu kimdir?

| | |
|---|---|
| **Unvan** | [şirket unvanı] |
| **Adres** | [açık adres] |
| **E-posta** | [iletişim e-postası] |
| **KEP adresi** | [KEP adresi] |
| **VERBİS kaydı** | [VERBİS kayıt bilgisi / "kayıt yükümlülüğümüz bulunmamaktadır"] |
| **Uygulama** | [uygulama adı] (iOS ve Android) |

#### 2. Hangi bilgilerinizi işliyoruz?

**a) Hesap bilgileri**
- E-posta adresiniz ve şifreniz (şifre geri döndürülemez biçimde saklanır)
- Seçtiğiniz takma ad, maskot ve varsa profil fotoğrafınız
- Size özel arkadaş kodunuz
- Gireceğiniz sınav yılı ve müfredat tercihiniz

**b) Yaş bilgisi**
- **Doğum yılınız.** Yalnızca yıl; gün ve ay sorulmuyor.

**c) Yüklediğiniz içerik**
- Çektiğiniz **soru fotoğrafları.** Bu fotoğraflarda el yazınız, defteriniz ve
  kadraja giren her şey bulunabilir.
- Fotoğraftan çıkarılan soru bilgileri (ders, konu, şıklar, doğru cevap)
- Bir soruyu arkadaşınıza gönderirken yazdığınız not
- Bir içeriği şikâyet ederken yazdığınız açıklama

**d) Çalışma ve ilerleme bilgileriniz**
- Hangi soruyu ne zaman çözdüğünüz, doğru mu yanlış mı yaptığınız
- XP puanınız, seriniz, elmaslarınız, lig ve haftalık sıralamanız
- Tekrar takviminiz

**e) Sosyal bilgiler**
- Arkadaşlıklarınız ve arkadaşlık istekleriniz
- Kime hangi soruyu gönderdiğiniz
- Engellediğiniz kullanıcılar ve yaptığınız şikâyetler

**f) Teknik bilgiler**
- Bildirimleri açtıysanız cihazınızın bildirim kimliği (jeton)
- Uygulama hata verdiğinde oluşan hata kayıtları ve teknik ayrıntılar
- Kötüye kullanımı önlemek için tutulan kullanım sayaçları

**g) Onay kayıtlarınız**
- Hangi onayı ne zaman verdiğiniz veya geri aldığınız
- Kullanım Koşulları ve Gizlilik Politikası'nı kabul ettiğinizde, **kabul
  ettiğiniz metnin sürüm numarası**

**h) Uygulama kurallarına uyum kayıtları**
- Yüklediğiniz bir fotoğraf otomatik tarama tarafından uygunsuz bulunduysa
  bunun kaydı
- Hesabınıza bir kısıtlama uygulandıysa (askıya alma, kapatma) bunun kaydı,
  tarihi ve gerekçe kodu

**Toplamadığımız bilgiler:** adınız ve soyadınız, T.C. kimlik numaranız,
telefon numaranız, adresiniz, okulunuz, sınıfınız, konumunuz, rehberiniz.
Sağlık, din, siyasi görüş gibi özel nitelikli hiçbir veri toplamıyoruz.
Reklam kimliğinizi kullanmıyoruz ve sizi uygulama dışında takip etmiyoruz.

#### 3. Bu bilgileri neden işliyoruz?

| Amaç | Hangi bilgiler |
|---|---|
| Hesabınızı açmak ve sizi tanımak | Hesap bilgileri |
| Çektiğiniz sorunun okunması ve doğru derse/konuya yerleştirilmesi | Soru fotoğrafı, müfredat tercihi |
| Hata bankanızı ve tekrar takviminizi kurmak | Yüklediğiniz içerik, çalışma bilgileri |
| Oyunlaştırma: XP, seri, lig, elmas | Çalışma ve ilerleme bilgileri |
| Arkadaşlarınızla soru paylaşmanız | Sosyal bilgiler, yüklediğiniz içerik |
| Size bildirim göndermek | Bildirim jetonu, takma adınız |
| **Uygulamayı güvenli tutmak:** uygunsuz içeriği engellemek, şikâyetleri incelemek, taciz ve kötüye kullanımı önlemek | Soru fotoğrafları, şikâyetler, engellemeler, kullanım sayaçları |
| **13 yaş sınırını uygulamak** ve yaş derecelendirmesini doğru yapmak | Doğum yılı |
| **Kurallara uymayan kullanıcıyı durdurmak:** uygunsuz içerik tekrarlanırsa hesabı geçici olarak kısıtlamak veya kapatmak | Tarama sonuçları, ihlal ve kısıtlama kayıtları |
| Uygulamanın hatalarını bulup düzeltmek | Hata kayıtları |
| Yasal yükümlülüklerimizi yerine getirmek ve bir uyuşmazlık hâlinde hakkımızı savunmak | Duruma göre ilgili kayıtlar |

**Sizi profilleyip reklam göstermiyoruz.** Verilerinizi satmıyoruz.

#### 4. Hangi hukuki sebeple işliyoruz?

KVKK'nın 5. maddesindeki şu sebeplere dayanıyoruz:

| İşleme | Hukuki sebep |
|---|---|
| Hesap açma, uygulamayı kullandırma, sorularınızı saklama, arkadaş özellikleri, bildirim gönderme | **Md. 5/2-c** — sözleşmenin kurulması ve ifası için gerekli olması |
| İçerik moderasyonu, şikâyet incelemesi, taciz ve kötüye kullanımın önlenmesi, hata kayıtları, kullanım sayaçları | **Md. 5/2-f** — temel hak ve özgürlüklerinize zarar vermemek kaydıyla meşru menfaatimiz |
| Doğum yılının sorulması ve 13 yaş sınırının uygulanması | **Md. 5/2-f** — çocuğun korunmasına yönelik meşru menfaat; ayrıca ilgili mevzuattan doğan yükümlülüklerimiz kapsamında **Md. 5/2-ç** |
| İhlal kayıtlarının tutulması ve hesap kısıtlamaları | **Md. 5/2-f** — hizmetin ve diğer kullanıcıların güvenliğine yönelik meşru menfaat; ayrıca **Md. 5/2-e** (bir hakkın tesisi ve korunması) |
| Yasal saklama ve bildirim yükümlülükleri, yetkili makam talepleri | **Md. 5/2-ç** — hukuki yükümlülüğün yerine getirilmesi |
| Bir hakkın tesisi, kullanılması veya korunması (uyuşmazlık hâli) | **Md. 5/2-e** |
| **Soru fotoğrafınızın yurt dışındaki yapay zekâ servisine gönderilmesi** | **Açık rızanız** (aşağıda 5. bölüm) |

#### 5. Soru fotoğraflarınız ve yapay zekâ

Bu bölümü ayrı yazdık, çünkü en çok bilmeniz gereken kısım burası.

**Fotoğrafınız iki ayrı sebeple yurt dışına gönderiliyor:**

**a) Sorunun okunması için.** Fotoğrafı çektiğinizde, sorunun metnini ve
şıklarını çıkarmak, doğru derse ve konuya yerleştirmek için görsel, merkezi
Amerika Birleşik Devletleri'nde bulunan **OpenAI**'a gönderilir. Bu gönderimi
yapmadan önce sizden açık rıza alıyoruz: ilk fotoğrafınızı çektiğinizde bir
onay ekranı çıkıyor ve onayınız zaman damgasıyla kaydediliyor. **Onay vermek
zorunda değilsiniz** — "fotoğrafsız devam et" derseniz soruyu elle
girebilirsiniz, uygulamanın hiçbir özelliği kapanmaz.

**b) İçerik güvenliği için.** Kaydettiğiniz her fotoğraf, uygunsuz içerik
barındırıp barındırmadığını anlamak için OpenAI'ın içerik denetimi servisine
gönderilir. **Bu tarama zorunludur ve ayrı bir onaya bağlı değildir**, çünkü
uygulamada birbirine içerik gönderebilen ve çoğu reşit olmayan kullanıcılar var;
taramayı isteğe bağlı yapmak korumanın kendisini işlevsiz kılardı. Tarama
sonucu yalnızca "temiz" veya "şüpheli" olarak saklanır.

**Gönderimde kim olduğunuz belirtilmez.** İsteğe adınız, e-postanız, kullanıcı
kimliğiniz veya takma adınız eklenmez; giden şey fotoğraf ve sabit bir talimat
metnidir.

**OpenAI fotoğrafı ne yapıyor?** OpenAI, API üzerinden gönderilen içeriği
yapay zekâ modellerini eğitmek için kullanmaz. Ancak kötüye kullanımın
denetlenmesi amacıyla içerik sınırlı bir süre saklanabilir ve bu süre sonunda
silinir. Güncel koşullar için: [OpenAI veri işleme politikası URL'i].

**Gönderim geri alınamaz.** Onayınızı ileride geri alabilirsiniz — bu, o andan
sonraki gönderimleri durdurur; daha önce gönderilmiş bir fotoğrafı geri
çağıramayız.

> **[Yayın öncesi karar — yurt dışına aktarımın hukuki dayanağı]**
> KVKK'nın 9. maddesi 2024 değişikliğiyle yeniden düzenlendi. İki yol var:
>
> **Seçenek 1 — Standart sözleşme (Md. 9/3-b/3).** Kurul'un ilan ettiği standart
> sözleşme metni OpenAI (ve diğer yurt dışı sağlayıcılar) ile imzalanır ve
> imzadan itibaren **5 iş günü içinde** Kurul'a bildirilir. **Daha koruyucu ve
> daha sürdürülebilir yol budur:** aktarımı açık rızanın kırılganlığından
> kurtarır, kullanıcı rızasını geri alsa bile hizmet güvenliği taraması
> hukuken ayakta kalır ve sürekli/sistematik aktarım için doğru araçtır.
> Maliyeti: sağlayıcıyı imzaya ikna etmek ve bildirim yükümlülüğü.
>
> **Seçenek 2 — Açık rıza (Md. 9/6-a).** Uygulamanın bugün yaptığı budur.
> **Daha hızlı ve hemen uygulanabilir**, ama Md. 9/6 istisnaları **"arızi
> olmak"** kaydıyla düzenlenmiştir. Her fotoğrafta çalışan sürekli bir
> aktarımın "arızi" sayılması tartışmalıdır; ayrıca zorunlu moderasyon
> taramasına açık rıza dayanağı hiç uymaz (rızayı geri alan kullanıcıda tarama
> yine de çalışır).
>
> **Önerimiz:** Seçenek 1'i hedefleyin, Seçenek 2'yi geçiş döneminde koruyun —
> yani standart sözleşme tamamlanana kadar açık rıza almaya devam edin.
> Yukarıdaki metin bu ikili yapıya göre yazılmıştır. Standart sözleşme
> imzalandığında, 4. bölümdeki tablonun son satırına *"ve Kurul'a bildirilen
> standart sözleşme (Md. 9/3-b/3)"* ifadesi eklenmelidir.

#### 6. Bilgilerinizi kimlerle paylaşıyoruz?

Verilerinizi **satmıyoruz** ve reklam amacıyla kimseyle paylaşmıyoruz.
Hizmeti sunabilmek için aşağıdaki hizmet sağlayıcılarla çalışıyoruz:

| Kime | Ne aktarılıyor | Neden | Nerede |
|---|---|---|---|
| **Supabase** (barındırma ve veritabanı) | Uygulamadaki tüm verileriniz | Hesabınızın ve içeriğinizin saklanması | [Supabase bölge/ülke] |
| **OpenAI** | Soru fotoğrafları (kimliksiz) | Sorunun okunması ve içerik güvenliği taraması | ABD |
| **Google (Firebase Cloud Messaging)** | Cihaz bildirim jetonu ve bildirim metni. **Bildirim metninde size soru gönderen kişinin takma adı yer alır** (ör. "Ayşe sana bir soru yolladı"). Sorunun kendisi veya fotoğraf gönderilmez | Bildirimlerin cihazınıza ulaştırılması | ABD |
| **Sentry** (hata izleme) | Uygulama hata kayıtları ve teknik ayrıntılar. **Kullanıcı kimliğiniz ve e-postanız gönderilmeden önce silinir**; ekran görüntüsü hiç alınmaz | Hataların bulunup düzeltilmesi | [Sentry bölge/ülke] |

Ayrıca yasal olarak zorunlu olduğumuz hâllerde yetkili kamu kurum ve
kuruluşlarına, talepleri kapsamında bilgi verebiliriz.

Bu sağlayıcıların tamamı bizim adımıza ve talimatımızla çalışan **veri
işleyenlerdir**; verilerinizi kendi amaçları için kullanamazlar.
Supabase, OpenAI, Google ve Sentry'ye yapılan aktarımlar yurt dışına aktarım
niteliğindedir ve 5. bölümde anlatılan hukuki dayanaklara tabidir.

#### 7. Verilerinizi ne kadar süre saklıyoruz?

| Veri | Süre |
|---|---|
| Hesabınız ve içeriğiniz (fotoğraflar dahil) | **Hesabınızı silene kadar.** Otomatik bir süre sınırı yoktur |
| Kayıt olmadan denediyseniz (anonim hesap) | **7 gün** sonra otomatik olarak silinir |
| Uygulama kurallarına uyum kayıtları (ihlal ve kısıtlama kayıtları) | Hesabınızı silene kadar. Otomatik kısıtlama kararında yalnızca **son 180 gün** dikkate alınır |
| Fotoğrafınıza verilen geçici erişim adresleri | 10 dakika |
| Hata kayıtları (Sentry) | [Sentry saklama süresi] |
| Yasal saklama yükümlülüğüne tabi kayıtlar | İlgili mevzuatın öngördüğü süre |

**Hesabınızı sildiğinizde ne oluyor?** Uygulama içinden hesabınızı
silebilirsiniz. Bekleme süresi veya geri alma penceresi yoktur; işlem
geri alınamaz. Önce fotoğraflarınız ve avatarınız depodan silinir, ardından
hesabınız ve ona bağlı tüm kayıtlar (sorularınız, ilerlemeniz, arkadaşlıklarınız,
gönderdiğiniz sorular, onay kayıtlarınız, bildirim jetonlarınız) silinir.
Depolama temizliği tamamlanmazsa hesap **silinmez** ve size hata bildirilir —
yarım silme yapmayız.

Silme işleminden sonra geri alınamayacak birkaç şey vardır ve bunları açıkça
söylüyoruz: daha önce OpenAI'a gönderilmiş fotoğraflar, daha önce gönderilmiş
bildirimler ve arkadaşınıza gönderdiğiniz bir sorunun onun tarafında kalan
kaydı geri çağrılamaz. Kimliğinizle ilişkilendirilmemiş teknik hata kayıtları
da Sentry'deki saklama süresi boyunca kalabilir.

#### 8. Yaşınız 18'den küçükse

**Uygulama 13 yaş ve üzeri içindir. 13 yaşından küçükler kullanamaz.**

- Kayıt sırasında **doğum yılınızı** soruyoruz. Yalnızca yıl; gün ve ay değil.
- **Bu sınır teknik olarak uygulanıyor:** 13 yaşından küçük bir doğum yılı
  girildiğinde kayıt tamamlanmaz ve bunun nedeni size açıkça söylenir.
- Doğum yılı **bir kez yazılır**, sonradan değiştirilemez. Yanlış girdiyseniz
  [iletişim e-postası] adresine yazın, düzeltelim.
- 13–18 yaş arasındaysanız uygulamanın **tüm özelliklerini** kullanabilirsiniz.
  Arkadaş eklemenin tek yolu, karşı tarafın size verdiği **6 haneli arkadaş
  kodudur** — kimse sizi takma adınızla arayıp bulamaz, size kodunuzu
  vermediğiniz biri arkadaşlık isteği gönderemez. İstemediğiniz biri olursa
  onu engelleyebilir ve kodunuzu yenileyebilirsiniz.

**Veli onayı hakkında.** Daha önceki sürümlerde 18 yaşından küçük
kullanıcılarda arkadaş ekleme veli onayına bağlanmıştı. **Bu uygulamadan
vazgeçildi.** Nedeni: 13–17 yaş için veli onayı yürürlükteki mevzuatta zorunlu
tutulmuyor, mekanizmanın kendisi velinin kimliğini doğrulayamıyordu ve
uygulamanın sosyal yüzeyi zaten kod tabanlı (yabancıyla temas kurma yolu yok).
Bunun yerine korumayı, herkes için çalışan üç mekanizmaya dayandırıyoruz:
zorunlu içerik taraması, engelleme/şikâyet ve kurallara uymayan hesabın
kısıtlanması.

**Velilere:** Çocuğunuzun uygulamada hangi verilerinin işlendiğini öğrenmek,
bir içeriğin kaldırılmasını ya da hesabın silinmesini istemek için
[iletişim e-postası] adresine yazabilirsiniz. Yasal temsilci sıfatıyla
başvurduğunuzda, çocuğunuzun KVKK Md. 11 haklarını onun adına
kullanabilirsiniz.

#### 9. İçeriğinizi kimler görebilir?

Bunu açıkça yazmak istiyoruz:

- **Soru fotoğraflarınız varsayılan olarak özeldir.** Bir arkadaşınıza
  göndermediğiniz sürece başka bir kullanıcı onları göremez.
- Bir soruyu arkadaşınıza gönderirseniz, o kişi sorunun fotoğrafını,
  şıklarını ve yazdığınız notu görür.
- **Bir şikâyet veya güvenlik incelemesi söz konusu olduğunda, yetkili
  moderatörümüz içeriğinizi — hiç kimseyle paylaşmadığınız fotoğraflar
  dahil — görüntüleyebilir.** Bu yetki, uygunsuz içeriği ve reşit olmayan
  kullanıcılara yönelik riskleri denetleyebilmek için vardır ve yalnızca
  sınırlı sayıda yetkili kişide bulunur.
- Takma adınız, maskotunuz, XP'niz, seriniz, liginiz ve arkadaş sayınız
  uygulamadaki **diğer kullanıcılara görünür**. Profil fotoğrafınızı ise
  yalnızca siz, arkadaşlarınız ve o haftaki lig grubunuzdaki kişiler görür.
- Birini engellediğinizde o kişi engellendiğini öğrenmez; size soru ve
  arkadaşlık isteği gönderemez hâle gelir.

#### 10. Verileriniz nasıl korunuyor?

- Fotoğraflarınız **herkese kapalı** depolama alanlarında tutulur; erişim
  yalnızca 10 dakika geçerli, imzalı adreslerle olur.
- Veritabanında satır düzeyinde güvenlik kuralları uygulanır: kural olarak
  yalnızca kendi satırlarınızı okuyabilirsiniz.
- XP, seri, lig ve doğru cevap gibi kritik alanları uygulama değil **sunucu**
  belirler; istemciden değiştirilemez.
- Onay kayıtları yalnızca ekleme yapılabilen bir defterde tutulur;
  değiştirilemez ve silinemez.
- Şifreler geri döndürülemez biçimde saklanır.
- Tüm veri trafiği şifreli bağlantı üzerinden geçer.

Hiçbir sistemin %100 güvenli olmadığını da dürüstçe söylüyoruz. Bir güvenlik
ihlali yaşanırsa Kurul'a ve etkilenen kullanıcılara mevzuatın öngördüğü şekilde
bildirim yaparız.

#### 11. Haklarınız (KVKK Md. 11)

Bize başvurarak şunları talep edebilirsiniz:

1. Kişisel verinizin işlenip işlenmediğini öğrenme
2. İşlenmişse buna ilişkin bilgi talep etme
3. İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme
4. Yurt içinde veya yurt dışında verilerinizin aktarıldığı üçüncü kişileri bilme
5. Eksik veya yanlış işlenmişse düzeltilmesini isteme
6. Kanundaki şartlar çerçevesinde silinmesini veya yok edilmesini isteme
7. Düzeltme, silme veya yok etme işlemlerinin, verilerinizin aktarıldığı üçüncü
   kişilere bildirilmesini isteme
8. Verilerinizin münhasıran otomatik sistemlerle analiz edilmesi suretiyle
   aleyhinize bir sonuç ortaya çıkmasına itiraz etme
9. Kanuna aykırı işleme sebebiyle zarara uğramanız hâlinde zararınızın
   giderilmesini talep etme

**Nasıl başvurursunuz?** Talebinizi [iletişim e-postası] adresine ya da
[açık adres] adresine yazılı olarak iletebilirsiniz. Kimliğinizi doğrulamak
için sizden ek bilgi isteyebiliriz. Başvurunuzu **en geç 30 gün içinde**
sonuçlandırırız. Ücretsizdir; işlemin ayrıca bir maliyeti varsa Kurul'un
belirlediği tarifedeki ücreti isteyebiliriz.

Cevabımızı yetersiz bulursanız veya 30 gün içinde cevap alamazsanız Kişisel
Verileri Koruma Kurulu'na şikâyette bulunabilirsiniz.

**Hızlı yollar:** Hesabınızı ve verilerinizi uygulama içinden
Ayarlar → Hesabımı sil ile kendiniz silebilirsiniz. Şu an tek bir soruyu
uygulama içinden silemiyorsunuz; böyle bir talebiniz varsa
[iletişim e-postası] adresine yazın, silelim.

#### 12. Bu metin değişirse

Bu metni güncellediğimizde uygulama içinde ve bu sayfada duyururuz. Önemli bir
değişiklik olursa (ör. yeni bir hizmet sağlayıcı veya yeni bir aktarım) sizi
ayrıca bilgilendiririz.

---

---

## 5. Gizlilik Politikası

> **Bu bölüm yayına hazır metindir ve bir URL'de yayınlanmak üzere yazılmıştır.**
> App Store Connect ve Google Play, bu bağlantıyı zorunlu tutuyor. KVKK
> Aydınlatma Metni ile aynı gerçeklere dayanır, sadece daha kısa ve okunaklıdır.

---

### [uygulama adı] Gizlilik Politikası

**Son güncelleme:** [tarih] · **Sürüm:** 1.1

[uygulama adı], YKS'ye hazırlanan öğrenciler için bir çalışma uygulamasıdır.
Kullanıcılarımızın çoğu lise öğrencisi olduğu için bu metni kısa ve anlaşılır
tutmaya çalıştık.

Uygulamayı [şirket unvanı] işletiyor. Sorularınız için: [iletişim e-postası]

#### Bir bakışta

| | |
|---|---|
| 🚫 **Verilerinizi satmıyoruz** | Hiçbir koşulda |
| 🚫 **Reklam yok, takip yok** | Uygulamada reklam SDK'sı yok, reklam kimliğinizi kullanmıyoruz, sizi uygulama dışında izlemiyoruz |
| 📷 **Soru fotoğraflarınız özeldir** | Bir arkadaşınıza göndermediğiniz sürece diğer kullanıcılar göremez |
| 🤖 **Fotoğraflar yapay zekâya gidiyor** | Sorunun okunması ve içerik güvenliği için, **kim olduğunuz belirtilmeden** |
| 🧑‍⚖️ **Moderatörümüz görebilir** | Şikâyet veya güvenlik incelemesinde, paylaşmadığınız fotoğraflar dahil |
| 🗑️ **İstediğiniz zaman silebilirsiniz** | Uygulama içinden, tek adımda, kalıcı olarak |
| 👦 **13 yaş altı kullanamaz** | Bu sınır kayıt sırasında teknik olarak uygulanır |
| 🚧 **Kurallara uymayanı durdururuz** | Uygunsuz içerik tekrarlanırsa hesap geçici olarak kısıtlanır; itiraz edebilirsiniz |

#### 1. Hangi bilgileri topluyoruz?

**Siz verdiğiniz için:**
- E-posta adresiniz ve şifreniz
- Takma adınız, maskotunuz, varsa profil fotoğrafınız
- Doğum yılınız (yalnızca yıl)
- Gireceğiniz sınav yılı ve müfredatınız
- **Çektiğiniz soru fotoğrafları** ve bunlarla ilgili yazdıklarınız

**Uygulamayı kullandıkça oluşan:**
- Hangi soruyu ne zaman çözdüğünüz, doğru/yanlış geçmişiniz, tekrar takviminiz
- XP, seri, elmas, lig ve haftalık sıralamanız
- Arkadaşlıklarınız, gönderdiğiniz sorular, engellemeleriniz, şikâyetleriniz
- Verdiğiniz onayların zaman damgalı kaydı ve kabul ettiğiniz metnin sürümü
- Bir fotoğrafınız otomatik tarama tarafından uygunsuz bulunduysa bunun kaydı;
  hesabınıza bir kısıtlama uygulandıysa kısıtlamanın tarihi ve gerekçe kodu

**Teknik olarak oluşan:**
- Bildirimleri açtıysanız cihazınızın bildirim kimliği
- Uygulama hata verdiğinde oluşan hata kayıtları
- Kötüye kullanımı önleyen kullanım sayaçları

**Toplamadıklarımız:** ad-soyad, T.C. kimlik numarası, telefon, adres, okul,
sınıf, konum, rehber, sağlık verisi, reklam kimliği. Uygulamada çerez
kullanılmaz.

#### 2. Bu bilgileri neden topluyoruz?

Hesabınızı açmak; çektiğiniz soruyu okuyup doğru konuya yerleştirmek; hata
bankanızı ve tekrar takviminizi kurmak; XP, seri ve lig sistemini çalıştırmak;
arkadaşlarınızla soru paylaşmanızı sağlamak; bildirim göndermek; uygulamayı
uygunsuz içerikten ve kötüye kullanımdan korumak; 18 yaşından küçük
kullanıcıları korumak; hataları bulup düzeltmek; yasal yükümlülüklerimizi
yerine getirmek.

Bunların dışında bir amaçla kullanmıyoruz. Sizi profilleyip reklam
göstermiyoruz.

#### 3. Soru fotoğraflarınız ve yapay zekâ

Bu, en dikkat etmenizi istediğimiz bölüm.

Çektiğiniz fotoğrafta **el yazınız, defteriniz ve kadraja giren her şey**
bulunabilir. Fotoğraf iki sebeple yurt dışındaki bir yapay zekâ servisine
(**OpenAI**, ABD) gönderilir:

1. **Sorunun okunması için.** Bunun için önceden onayınızı alırız. Onay vermek
   zorunda değilsiniz; "fotoğrafsız devam et" derseniz soruyu elle
   girebilirsiniz ve uygulamanın hiçbir özelliği kapanmaz.
2. **İçerik güvenliği taraması için.** Kaydettiğiniz her fotoğraf uygunsuz
   içerik barındırıp barındırmadığı açısından taranır. **Bu tarama zorunludur.**
   Uygulamada kullanıcılar birbirine içerik gönderebiliyor ve çoğu reşit değil;
   taramayı isteğe bağlı yapmak korumayı işlevsiz kılardı.

**Gönderimde kim olduğunuz belirtilmez** — adınız, e-postanız veya kullanıcı
kimliğiniz eklenmez.

**OpenAI fotoğrafı ne yapıyor?** İçerik yapay zekâ modellerinin eğitiminde
kullanılmaz. Ancak kötüye kullanımın denetlenmesi için sınırlı bir süre
saklanabilir. Güncel koşullar: [OpenAI veri işleme politikası URL'i].

**Gönderim geri alınamaz.** Onayınızı geri alabilirsiniz; bu, sonraki
gönderimleri durdurur ama gönderilmiş bir fotoğrafı geri getirmez.

#### 4. Uygulamayı kullananlar birbirinin nesini görüyor?

| Bilgi | Kim görebiliyor |
|---|---|
| Takma adınız, maskotunuz, XP'niz, etkin seriniz, liginiz, arkadaş sayınız | **Uygulamadaki tüm kullanıcılar** |
| Profil fotoğrafınız | Siz, arkadaşlarınız ve o haftaki lig grubunuz |
| Soru fotoğraflarınız ve notlarınız | **Yalnızca siz** — ta ki bir arkadaşınıza gönderene kadar |
| Bir arkadaşınıza gönderdiğiniz soru | O arkadaşınız |
| Doğum yılınız ve e-postanız | **Hiçbir kullanıcı** |
| Engellediğiniz kişiler | **Yalnızca siz.** Engellenen kişi bunu öğrenmez |

Arkadaş eklemenin tek yolu 6 haneli arkadaş kodudur; kimse sizi takma adınızla
arayıp bulamaz. Kodunuzu günde bir kez yenileyebilirsiniz.

#### 5. Moderatör erişimi

Bunu saklamak istemiyoruz: bir şikâyet geldiğinde veya otomatik tarama bir
fotoğrafı şüpheli işaretlediğinde, **yetkili moderatörümüz içeriğinizi — hiç
kimseyle paylaşmadığınız fotoğraflar dahil — görüntüleyebilir.**

Bu yetki, uygunsuz içeriği ve reşit olmayan kullanıcılara yönelik riskleri
denetleyebilmek için vardır. Yalnızca sınırlı sayıda yetkili kişide bulunur ve
uygulama içinden kimseye verilemez.

#### 6. Kimlerle paylaşıyoruz?

Verilerinizi satmıyoruz ve reklam için kimseyle paylaşmıyoruz. Hizmeti
sunabilmek için şu sağlayıcılarla çalışıyoruz — hepsi bizim adımıza ve
talimatımızla çalışır:

| Sağlayıcı | Ne için | Ne gidiyor |
|---|---|---|
| **Supabase** | Barındırma ve veritabanı | Uygulamadaki tüm verileriniz |
| **OpenAI** (ABD) | Soru okuma + içerik güvenliği | Soru fotoğrafları, kimliksiz |
| **Google / Firebase** (ABD) | Bildirim iletimi | Cihaz bildirim kimliği ve bildirim metni. Bildirimde **size soru gönderen kişinin takma adı** yer alır; sorunun kendisi veya fotoğraf gitmez |
| **Sentry** | Hata izleme | Hata kayıtları. Kullanıcı kimliğiniz ve e-postanız **gönderilmeden önce silinir**; ekran görüntüsü hiç alınmaz |

Ayrıca yasal olarak zorunlu olduğumuz hâllerde yetkili makamlara bilgi
verebiliriz.

**Yurt dışı:** Bu sağlayıcıların tamamı Türkiye dışında bulunuyor, yani
verileriniz yurt dışına aktarılıyor. Aktarımlar, KVKK Aydınlatma Metni'nde
açıklanan hukuki dayanaklara göre yapılır: [KVKK aydınlatma metni URL'i].

#### 7. Verileriniz ne kadar kalıyor?

- **Hesabınız ve içeriğiniz:** siz silene kadar. Otomatik bir süre sınırı yok.
- **Kayıt olmadan denediyseniz:** 7 gün sonra otomatik silinir.
- **İhlal ve kısıtlama kayıtları:** hesabınızı silene kadar. Otomatik kısıtlama
  kararı verilirken yalnızca **son 180 gün** dikkate alınır.
- **Fotoğraflara verilen geçici erişim adresleri:** 10 dakika.
- **Hata kayıtları:** [Sentry saklama süresi].

#### 8. Silme

Hesabınızı **uygulama içinden** silebilirsiniz: Ayarlar → Hesabımı sil.
Bekleme süresi yoktur ve işlem geri alınamaz. Fotoğraflarınız, sorularınız,
ilerlemeniz, arkadaşlıklarınız, gönderdiğiniz sorular, onay kayıtlarınız ve
bildirim kaydınız silinir.

Uygulamayı kaldırdıysanız veya uygulamaya erişemiyorsanız silme talebinizi
[hesap silme sayfası URL'i] üzerinden veya [iletişim e-postası] adresine
yazarak iletebilirsiniz.

**Silmeden sonra geri alınamayacaklar** (dürüst olmak adına): daha önce OpenAI'a
gönderilmiş fotoğraflar, gönderilmiş bildirimler, bir arkadaşınıza gönderdiğiniz
sorunun onun tarafında kalan kaydı ve kimliğinizle ilişkilendirilmemiş teknik
hata kayıtları.

Ayrıca gelen kutunuzda bir soruyu "sil" dediğinizde o soru sizden gizlenir ama
gönderenin kaydı ve moderasyon izi korunur.

**Tek bir soruyu silmek:** Şu an uygulama içinde tek tek silme özelliği yok.
Böyle bir talebiniz varsa [iletişim e-postası] adresine yazın.

#### 9. Çocuklar

**Uygulama 13 yaş ve üzeri içindir. 13 yaşından küçükler kullanamaz** ve bu
sınır kayıt sırasında teknik olarak uygulanır: 13 yaşından küçük bir doğum yılı
girildiğinde kayıt tamamlanmaz.

13–18 yaş arasındaki kullanıcılar uygulamanın tüm özelliklerini kullanabilir.
Arkadaş eklemenin tek yolu 6 haneli arkadaş kodudur; kimse kimseyi takma adıyla
arayıp bulamaz. Yüklenen her fotoğraf otomatik olarak taranır ve uygunsuz
bulunan bir fotoğraf paylaşıma çıkamaz.

**Veli onayı mekanizması yoktur.** Daha önceki sürümlerde 18 altı kullanıcılarda
arkadaş ekleme veli onayına bağlanmıştı; bundan vazgeçildi. Ayrıntılı gerekçe
KVKK Aydınlatma Metni §8'de: [KVKK aydınlatma metni URL'i].

**Veliler:** çocuğunuzun verileri hakkında bilgi almak, bir içeriğin
kaldırılmasını ya da hesabın silinmesini istemek için [iletişim e-postası]
adresine yazın.

#### 10. Güvenlik

Fotoğraflarınız herkese kapalı depolama alanlarında tutulur; erişim yalnızca
10 dakika geçerli imzalı adreslerle olur. Veritabanında satır düzeyinde güvenlik
kuralları uygulanır. XP, seri ve doğru cevap gibi kritik değerleri sunucu
belirler. Onay kayıtları değiştirilemeyen bir deftere yazılır. Tüm trafik
şifreli bağlantı üzerinden geçer.

Hiçbir sistem %100 güvenli değildir. Bir ihlal yaşanırsa mevzuatın öngördüğü
şekilde bildirim yaparız.

#### 11. Haklarınız

Nerede olursanız olun şunları talep edebilirsiniz: verilerinize erişmek,
düzeltilmesini istemek, silinmesini istemek, işlenmesine itiraz etmek, verdiğiniz
onayı geri almak ve bir kopyasını istemek.

**Türkiye'deki kullanıcılar (KVKK):** KVKK Md. 11 kapsamındaki haklarınızın tam
listesi ve başvuru usulü için: [KVKK aydınlatma metni URL'i]. Başvurularınızı
en geç 30 gün içinde sonuçlandırırız. Cevabımızı yetersiz bulursanız Kişisel
Verileri Koruma Kurulu'na şikâyette bulunabilirsiniz.

**Avrupa Birliği / AEA ve Birleşik Krallık'taki kullanıcılar (GDPR / UK GDPR):**

| Konu | Karşılığı |
|---|---|
| Hukuki dayanaklarımız | Sözleşmenin ifası (Md. 6/1-b): hesap, içerik saklama, arkadaş özellikleri · Meşru menfaat (Md. 6/1-f): içerik moderasyonu, güvenlik, hata izleme, çocuk koruma · Açık rıza (Md. 6/1-a): soru fotoğrafının yapay zekâ ile okunması · Hukuki yükümlülük (Md. 6/1-c) |
| Haklarınız | Erişim (Md. 15), düzeltme (16), silme (17), işlemenin kısıtlanması (18), veri taşınabilirliği (20), itiraz (21), rızayı geri alma (7/3) |
| Uluslararası aktarım | Verileriniz Türkiye'ye ve ABD'ye aktarılır. Bu aktarımlar için Avrupa Komisyonu'nun Standart Sözleşme Hükümleri'ne (SCC) ve ilgili ek önlemlere dayanıyoruz: [SCC durumu doldurulacak] |
| Özel nitelikli veri | İşlemiyoruz (Md. 9) |
| Otomatik karar verme | Hukuki sonuç doğuran otomatik karar verme yapmıyoruz. Yapay zekâ yalnızca sorunuzu okur ve sınıflandırır; sonucu onaylamadan kaydedilmez |
| Çocuklar | Uygulama 13 yaş altına yönelik değildir ve bu sınır teknik olarak uygulanır. Md. 8 kapsamında bulunduğunuz ülkenin belirlediği bilgi toplumu hizmeti yaş sınırı 13'ten yüksekse (bazı AB ülkelerinde 16'ya kadar çıkabilir), o sınırın altındaki kullanıcılar için veli izni gerekir; böyle bir durumda [iletişim e-postası] adresine yazın |
| Şikâyet | Bulunduğunuz ülkedeki veri koruma otoritesine şikâyette bulunabilirsiniz |

Talepleriniz için: [iletişim e-postası]

#### 12. Bu politika değişirse

Güncellemeleri bu sayfada yayınlar ve uygulama içinde duyururuz. Önemli bir
değişiklikte (yeni bir sağlayıcı veya yeni bir aktarım gibi) sizi ayrıca
bilgilendiririz. Sayfanın en üstündeki tarih son güncelleme tarihidir.

#### 13. İletişim

[şirket unvanı]
[açık adres]
[iletişim e-postası]

---

---

## 6. Kullanım Koşulları

> **Bu bölüm yayına hazır metindir.** Operatörü korumak üzere yazıldı, ancak
> Türk tüketici hukukunda geçersiz sayılacak maddelerden bilinçli olarak
> kaçınıldı — geçersiz bir madde koruma sağlamaz, yalnızca belgenin
> güvenilirliğini düşürür. Bu tercihler §7'de tek tek gerekçelendirildi.

---

### [uygulama adı] Kullanım Koşulları

**Yürürlük tarihi:** [tarih] · **Sürüm:** 1.1

#### 1. Bu sözleşme kim ile kim arasında?

Bu koşullar, [uygulama adı] uygulamasını işleten **[şirket unvanı]**
("biz", "Şirket") ile uygulamayı kullanan siz ("kullanıcı", "siz") arasındaki
sözleşmedir.

Uygulamayı indirip hesap açtığınızda bu koşulları kabul etmiş olursunuz.
Kabul etmiyorsanız uygulamayı kullanmayın.

Uygulamayı Apple App Store veya Google Play üzerinden edindiyseniz, ilgili
mağazanın kendi koşulları da geçerlidir. Bu sözleşme sizinle bizim aramızdadır;
**Apple ve Google bu sözleşmenin tarafı değildir** ve uygulamadan doğan
taleplerinizin muhatabı biziz.

#### 2. Uygulama ne yapıyor?

[uygulama adı], YKS'ye hazırlanan öğrenciler için bir çalışma uygulamasıdır.
Kısaca:

- Yanlış yaptığınız soruyu fotoğraflarsınız.
- Yapay zekâ destekli bir sistem fotoğraftaki soruyu okumaya, şıklarını
  çıkarmaya ve doğru derse/konuya yerleştirmeye çalışır.
- Soru hata bankanıza kaydedilir ve aralıklı tekrar yöntemiyle zaman içinde
  tekrar tekrar karşınıza çıkar.
- XP, seri, lig ve arkadaşlarla soru paylaşma gibi oyunlaştırma özellikleri
  çalışma alışkanlığınızı desteklemek içindir.

**Uygulama bir öğretmen, özel ders veya danışmanlık hizmeti değildir.**

#### 3. Kimler kullanabilir?

- Uygulamayı **13 yaşından küçükler kullanamaz.** Kayıt sırasında doğum
  yılınızı soruyoruz ve bu sınırı teknik olarak uyguluyoruz: 13 yaşından küçük
  bir doğum yılı girildiğinde kayıt tamamlanmaz.
- Doğum yılınız **bir kez yazılır** ve sonradan değiştirilemez. Yanlış
  girdiyseniz [iletişim e-postası] adresine yazın.
- **18 yaşından küçükseniz**, uygulamayı kullanmadan önce veliniz veya yasal
  temsilcinizle konuşmanızı bekliyoruz. Bu sözleşme, 18 yaşından küçük
  kullanıcılar bakımından velinin bilgisi ve izniyle kurulmuş sayılır.
- Uygulamayı kullanabilmek için kayıt adımında **bu Koşulları ve Gizlilik
  Politikası'nı kabul etmeniz gerekir.** Kabulünüz, kabul ettiğiniz metnin
  sürümüyle birlikte kaydedilir.
- Hesabınız daha önce bu koşulların ihlali nedeniyle kapatıldıysa yeni hesap
  açamazsınız.

**Veliler için:** Çocuğunuzun hesabı, verileri veya bu sözleşme hakkındaki her
konuda [iletişim e-postası] adresinden bize ulaşabilirsiniz. Hesabın silinmesini
isteme hakkınız her zaman saklıdır.

#### 4. Hesabınız

- Verdiğiniz bilgilerin doğru olmasından siz sorumlusunuz.
- Şifrenizi gizli tutun ve kimseyle paylaşmayın. Hesabınızdan yapılan
  işlemlerden, hesabınızın izniniz dışında kullanıldığını bize bildirene kadar
  siz sorumlusunuz.
- Bir başkasının hesabını kullanamaz, başkası adına hesap açamazsınız.
- Hesabınızı istediğiniz zaman uygulama içinden silebilirsiniz.

#### 5. Yüklediğiniz içerik ve taahhütleriniz

Uygulamaya yüklediğiniz fotoğraflar, notlar ve diğer içerikler **sizin
içeriğinizdir.** Bize devretmiyorsunuz.

İçerik yüklerken şunları taahhüt ediyorsunuz:

**a)** Yüklediğiniz içeriği paylaşma hakkına sahipsiniz.

**b)** Telif hakkı size ait olmayan materyalleri yüklemiyorsunuz. Bir yayınevinin
soru kitabından çektiğiniz sorunun telifi o yayınevine aittir; **kendi çalışma
arşiviniz için** kullanmak ile bunu başkalarına dağıtmak farklı şeylerdir. Bir
soruyu arkadaşınıza gönderirken bunu düşünün.

**c)** **Başkasının kişisel verisini paylaşmıyorsunuz.** Fotoğrafta bir
arkadaşınızın yüzü, adı, telefonu, notu veya sizin dışınızda birinin özel
bilgisi varsa o fotoğrafı yüklemeyin. Fotoğrafı çekmeden önce kadraja bakın.

**d)** İçeriğiniz üçüncü kişilerin haklarını, yürürlükteki mevzuatı ve bu
koşulları ihlal etmiyor.

**Fotoğraflarınız hakkında bilmeniz gereken:** Çektiğiniz fotoğraf, sorunun
okunması ve içerik güvenliği taraması için yurt dışındaki bir yapay zekâ
servisine gönderilir. Ayrıntılar Gizlilik Politikası'ndadır:
[gizlilik politikası URL'i].

#### 6. Yasak kullanımlar — sıfır tolerans

**Uygunsuz içeriğe ve uygulamayı kötüye kullanan kullanıcılara sıfır tolerans
gösteriyoruz.** Aşağıdakiler kesinlikle yasaktır. Tespit edildiğinde içerik
kaldırılır; ağırlığına göre hesabınız **geçici olarak kısıtlanır veya kalıcı
olarak kapatılır** (nasıl işlediği için bkz. §7):

- Cinsel içerik; **çocukların cinsel istismarına ilişkin her türlü materyal**
- Şiddet, kendine zarar verme veya intiharı özendiren içerik
- Nefret söylemi, ayrımcılık, hakaret, tehdit
- **Taciz, zorbalık, ısrarlı rahatsız etme** — özellikle başka bir kullanıcıya
  yönelik
- Yasa dışı ürün veya faaliyetlerin tanıtımı
- Başkasının kişisel verilerinin veya özel görüntülerinin izinsiz paylaşılması
- Spam, reklam, dolandırıcılık, kimlik avı
- Bir başkasının kimliğine bürünmek
- Uygulamanın güvenlik önlemlerini aşmaya çalışmak, otomatik araçlarla veri
  çekmek, tersine mühendislik yapmak, sistemi aşırı yüklemek
- XP, seri, lig veya oyunlaştırma mekanizmalarını hile ile manipüle etmek
- Uygulamayı, yasa dışı bir amaçla ya da başkalarına zarar vermek için kullanmak

Çocukların cinsel istismarına ilişkin içerik tespit ettiğimizde, içeriği
kaldırmakla yetinmez, hesabı kapatır ve yetkili makamlara bildiririz.

#### 7. Şikâyet, engelleme ve moderasyon

**Sizin elinizdekiler:**
- Size gönderilen her içeriği **şikâyet edebilirsiniz** — uygulama içinde,
  içeriğin yanındaki şikâyet seçeneğiyle.
- Bir kullanıcıyı **engelleyebilirsiniz.** Engellediğiniz kişi size soru veya
  arkadaşlık isteği gönderemez. Engellediğinizi karşı taraf öğrenmez.
- Şikâyet ettiğiniz içerik, incelemeyi beklemeden sizden hemen gizlenir.

**Bizim yaptıklarımız:**
- Yüklenen her fotoğraf, uygunsuz içeriğe karşı **otomatik olarak taranır.**
  Tarama tamamlanmamış veya şüpheli işaretlenmiş bir fotoğraf paylaşıma çıkamaz.
  Fotoğraf sizin arşivinizde kalmaya devam eder ve siz görebilirsiniz;
  engellenen yalnızca paylaşımdır.
- Şikâyetleri **makul bir süre içinde** inceler; gerekirse içeriği kaldırır,
  gizler veya hesabı kısıtlarız.
- Bir güvenlik incelemesi kapsamında, yetkili moderatörümüz içeriğinizi —
  paylaşmadığınız fotoğraflar dahil — görüntüleyebilir. Bu, uygulamayı reşit
  olmayan kullanıcılar için güvenli tutmanın karşılığıdır ve Gizlilik
  Politikası'nda açıkça anlatılmıştır.
- Bu koşulları ihlal eden içeriği **önceden bildirimde bulunmaksızın**
  kaldırma, gizleme veya hesabı kısıtlama hakkımız saklıdır. Ciddi olmayan
  ihlallerde önce uyarmayı tercih ederiz.

**Uygunsuz içerikte kademeli yaptırım.** Otomatik tarama bir fotoğrafınızı
uygunsuz bulursa şu sıra işler:

| Tespit | Ne oluyor |
|---|---|
| **Birinci** | Fotoğraf paylaşıma çıkmaz; size uygulama içinde bildirilir |
| **İkinci** | Aynı sonuç, uyarı daha açık; ihlal kaydedilir |
| **Üçüncü** | Hesabınız **7 gün** boyunca kısıtlanır ve durum yönetici incelemesine düşer |
| Kısıtlama bittikten sonra yeni bir ihlal | Hesabınız **kalıcı olarak kapatılır** |

Bu sayım **son 180 günü** kapsar; daha eski tespitler otomatik karara dâhil
edilmez. Bir tespitin hatalı olduğu anlaşılırsa (yanlış pozitif) kayıt geçersiz
kılınır ve buna bağlı kısıtlama kaldırılır.

**Kısıtlama neyi kapatır, neyi kapatmaz.** Kapanır: fotoğraf yükleme,
arkadaşınıza soru gönderme, arkadaş ekleme. **Açık kalır:** arşiviniz,
tekrarlarınız, liginiz, hesabınızı silme hakkınız ve bir kullanıcıyı engelleme
ya da şikâyet etme hakkınız. Amaç sizi uygulamadan atmak değil, başkasına
dokunmayı durdurmaktır.

**İtiraz.** Bir kararın hatalı olduğunu düşünüyorsanız [iletişim e-postası]
adresine yazarak itiraz edebilirsiniz; uygulama içindeki kısıtlama ekranı da
sizi doğrudan bu adrese yönlendirir. İtirazınızı bir insan değerlendirir.

Şikâyet mekanizmasını kötüye kullanmayın: dayanaksız şikâyetleri tekrarlayan
kullanıcıların şikâyetleri dikkate alınmayabilir.

#### 8. Fikri mülkiyet

**Bize ait olanlar:** Uygulamanın kendisi, tasarımı, arayüzü, logosu, adı,
maskotları, metinleri, sesleri, kaynak kodu ve altyapısı [şirket unvanı]'na
aittir ve fikri mülkiyet mevzuatıyla korunur. Size, uygulamayı bu koşullara
uygun olarak kişisel ve ticari olmayan amaçlarla kullanmanız için
**devredilemez, münhasır olmayan, geri alınabilir bir kullanım hakkı**
tanıyoruz. Bunun dışında hiçbir hak devredilmiş sayılmaz.

**Size ait olanlar:** Yüklediğiniz içeriğin hakları sizde kalır. Bize
verdiğiniz izin **yalnızca hizmeti sunabilmemiz için gereken kadardır:**

- İçeriğinizi sunucularımızda saklamak ve size göstermek,
- Teknik olarak işlemek (boyutlandırma, format dönüştürme, güvenli saklama),
- Bir soruyu gönderdiğinizde yalnızca **seçtiğiniz kişiye** iletmek,
- İçerik güvenliği taramasından geçirmek ve bir şikâyet hâlinde incelemek,
- Yedekleme ve sistem güvenliği amacıyla kopyalamak.

Bu izin **ücretsizdir, dünya çapında geçerlidir ve yalnızca yukarıdaki
amaçlarla sınırlıdır.** İçeriğinizi reklamda, tanıtımda veya yapay zekâ
modellerinin eğitiminde kullanmıyoruz ve üçüncü kişilere satmıyoruz.

İçeriğinizi veya hesabınızı sildiğinizde bu izin sona erer. Yedekleme
sistemlerindeki kopyalar teknik olarak mümkün olan en kısa sürede silinir;
daha önce arkadaşınıza ilettiğiniz bir içerik onun tarafında kalabilir.

#### 9. Telif hakkı ihlali bildirimi (uyar–kaldır)

Uygulamada, hakkınızı ihlal ettiğini düşündüğünüz bir içerik varsa bize bildirin.

**Bildiriminizi [telif bildirim e-postası] adresine gönderin ve şunları
ekleyin:**

1. Ad, soyad / unvan ve iletişim bilgileriniz
2. Hak sahibi olduğunuzu gösteren bilgi veya belgeler
3. İhlal edildiğini düşündüğünüz eserin tanımı
4. İhlalin uygulamada nerede olduğu (ekran görüntüsü, kullanıcı adı, tarih —
   bulmamıza yetecek kadar bilgi)
5. Bildirimdeki bilgilerin doğru olduğuna dair beyanınız
6. İmzanız (elektronik imza kabul edilir)

**Süreç:** Bildiriminizi aldıktan sonra en kısa sürede değerlendirir ve haklı
bulduğumuz hâlde içeriği kaldırır veya erişime kapatırız. İçeriği yükleyen
kullanıcıyı durumdan haberdar eder ve kendisine itiraz imkânı tanırız. İtiraz
haklı bulunursa içerik geri getirilebilir. 5846 sayılı Fikir ve Sanat Eserleri
Kanunu ve 5651 sayılı Kanun'daki başvuru yolları saklıdır.

**Karşı bildirim:** İçeriğiniz hatalı bir bildirim üzerine kaldırıldıysa aynı
adrese yazarak itiraz edebilirsiniz.

**Tekrarlayan ihlalci politikası:** Hakkında birden fazla haklı telif bildirimi
gelen kullanıcıları uyarırız. İhlal tekrarlanırsa hesap kalıcı olarak kapatılır.

**Kötüniyetli bildirimler:** Gerçeğe aykırı bildirimde bulunanlar bundan doğan
zararlardan sorumludur.

#### 10. Neyi garanti etmiyoruz

Bu bölümü dikkatle okuyun; uygulamadan ne beklemeniz gerektiğini anlatıyor.

- **Uygulama size sınav başarısı, puan artışı veya sıralama vaat etmez.**
  Hiçbir sonuç garantisi vermiyoruz. Çalışmanın sonucu birçok etkene bağlıdır
  ve bunların büyük kısmı bizim kontrolümüzde değildir.
- **Yapay zekâ hata yapabilir.** Fotoğraftan çıkarılan soru metni, şıklar,
  işaretlenen doğru cevap, ders ve konu ataması **yanlış olabilir.** Kaydetmeden
  önce sonucu kontrol etmek sizin sorumluluğunuzdadır; uygulama bunun için bir
  onay ekranı gösterir. **Uygulamanın çıktısına dayanarak yanlış öğrendiğiniz
  bir bilgiden sorumlu değiliz.**
- Uygulamadaki soru içerikleri, konu ağacı ve müfredat eşlemeleri hatalı veya
  güncel olmayan bilgiler içerebilir. Resmî kaynak değildir; ÖSYM'nin veya Millî
  Eğitim Bakanlığı'nın yayınlarının yerine geçmez.
- **Uygulamanın kesintisiz veya hatasız çalışacağını garanti etmiyoruz.**
  Bakım, güncelleme, altyapı sağlayıcılarımızdan kaynaklanan sorunlar veya
  teknik arızalar nedeniyle hizmet geçici olarak durabilir.
- Uygulama "olduğu gibi" sunulmaktadır. Mevzuatın izin verdiği ölçüde, açık veya
  zımni başka bir garanti vermiyoruz.
- **Verilerinizi yedeklemek sizin sorumluluğunuzdadır** demiyoruz — verilerinizi
  korumak için makul özeni gösteriyoruz. Ancak teknik bir arıza sonucu veri
  kaybı ihtimalini de tümüyle ortadan kaldıramayız.
- Diğer kullanıcıların davranışlarından ve yükledikleri içerikten sorumlu
  değiliz. Size rahatsızlık veren bir kullanıcıyı engelleyin ve bize bildirin.

#### 11. Sorumluluğumuzun sınırı

Mevzuatın izin verdiği en geniş ölçüde:

- Dolaylı zararlardan, kâr kaybından, veri kaybından, itibar kaybından veya
  sınav sonucunuza ilişkin beklentilerinizin karşılanmamasından sorumlu
  değiliz.
- Uygulamanın kullanımından doğan toplam sorumluluğumuz, ilgili talep tarihinden
  önceki 12 ay içinde bize ödediğiniz tutarla sınırlıdır. Uygulama şu anda
  ücretsiz olduğu için bu tutar sıfırdır.

**Bu sınırlamaların istisnaları:** Yukarıdaki sınırlamalar **kastımızdan veya
ağır ihmalimizden doğan zararlarda, ölüm ve bedensel zararlarda ve mevzuatın
sınırlandırılmasına izin vermediği diğer hâllerde uygulanmaz.** Tüketici
mevzuatından doğan haklarınız saklıdır ve bu sözleşmeyle sınırlandırılamaz.

#### 12. Tazmin

Bu koşulları ihlal etmeniz veya yüklediğiniz içerik nedeniyle üçüncü bir kişi
bize karşı bir talepte bulunursa (örneğin telif hakkı sahibi veya fotoğrafta yer
alan bir kişi), bu talepten doğan **doğrudan zararlarımızı ve makul avukatlık
giderlerimizi** karşılamayı kabul edersiniz.

Bu yükümlülük, **bizim kendi kusurumuzdan kaynaklanan talepleri kapsamaz.**
18 yaşından küçük kullanıcılar bakımından bu madde, genel hükümler çerçevesinde
veli veya yasal temsilcinin sorumluluğu saklı kalmak üzere uygulanır.

#### 13. Ücretli hizmetler (şu an mevcut değil)

**Uygulama şu anda tamamen ücretsizdir. Uygulama içi satın alma, abonelik veya
başka bir ödeme yoktur.**

İleride ücretli özellikler sunarsak aşağıdaki kurallar geçerli olacaktır ve
bunları uygulamaya almadan önce sizi ayrıca bilgilendireceğiz:

- **[Fiyatlandırma]** Ücretler, özellikler ve varsa deneme süresi satın alma
  ekranında açıkça gösterilir. Fiyatlar KDV dahil olarak belirtilir.
- **[Ödeme]** Satın almalar Apple App Store veya Google Play üzerinden yapılır;
  ödeme, iade ve fatura süreçleri ilgili mağazanın kurallarına tabidir.
- **[Yenileme]** Abonelikler, siz iptal etmediğiniz sürece dönem sonunda
  otomatik olarak yenilenir. İptali cihazınızın mağaza hesabı ayarlarından
  yapabilirsiniz.
- **[Cayma hakkı]** Mesafeli Sözleşmeler Yönetmeliği kapsamında, elektronik
  ortamda anında ifa edilen hizmetlerde cayma hakkına ilişkin istisnalar
  saklıdır; bu husus satın alma öncesi ayrıca bildirilir.
- **[18 yaş altı]** Uygulamada veli onayı mekanizması bulunmadığından, 18
  yaşından küçük kullanıcıların satın alma yapması velinin bilgisi ve izniyle
  yapılmış sayılır. Velilere, cihaz düzeyinde (App Store / Google Play) satın
  alma kısıtlaması kurmalarını öneririz.
- **[Ücretsiz özelliklerin korunması]** Ücretli bir katman gelmesi, o güne
  kadar ücretsiz sunduğumuz temel özellikleri kendiliğinden ücretli hâle
  getirmez; böyle bir değişiklik olursa önceden duyurulur.
- **[Fesih hâlinde]** Hesabınız bu koşulları ihlal ettiğiniz için kapatılırsa
  kullanılmamış dönem için iade yapılmayabilir; iade talepleri ilgili mağazanın
  kurallarına göre değerlendirilir.

#### 14. Hesabın kapatılması ve fesih

**Siz:** Hesabınızı istediğiniz zaman, sebep göstermeden, uygulama içinden
silebilirsiniz (Ayarlar → Hesabımı sil). Bekleme süresi yoktur; işlem geri
alınamaz.

**Biz:** Bu koşulları ihlal etmeniz hâlinde hesabınızı **geçici olarak
kısıtlayabilir veya kalıcı olarak kapatabiliriz** (§7'deki kademeli yaptırım).
Ciddi olmayan ihlallerde önce uyarırız; ağır ihlallerde (çocuk istismarı
içeriği, taciz, yasa dışı faaliyet, güvenlik saldırısı) doğrudan kapatırız.
Hesabınız kısıtlandığında uygulamayı açtığınızda **ne olduğunu, ne zamana kadar
sürdüğünü ve nasıl itiraz edebileceğinizi** gösteren bir ekran görürsünüz.
Güvenlik veya hukuki bir engel yoksa gerekçeyi de bildiririz.

Ayrıca hizmeti tamamen sonlandırmaya karar verirsek, verilerinizi
indirebilmeniz veya alternatif bulabilmeniz için **makul bir süre önceden
haber veririz.**

Hesabınız kapandığında içeriğiniz ve verileriniz Gizlilik Politikası'nda
anlatıldığı şekilde silinir.

#### 15. Koşullarda değişiklik

Bu koşulları zaman zaman güncelleyebiliriz. Önemli bir değişiklik olduğunda
uygulama içinde bildirim yaparız ve yürürlük tarihinden önce makul bir süre
tanırız. Değişiklikten sonra uygulamayı kullanmaya devam etmeniz, yeni
koşulları kabul ettiğiniz anlamına gelir. Kabul etmiyorsanız hesabınızı
silebilirsiniz.

Aleyhinize olan değişiklikler geçmişe etkili uygulanmaz.

#### 16. Uygulanacak hukuk ve uyuşmazlıkların çözümü

Bu sözleşmeye **Türk hukuku** uygulanır.

**Tüketici iseniz** (uygulamayı ticari veya mesleki olmayan amaçlarla
kullanıyorsanız): 6502 sayılı Tüketicinin Korunması Hakkında Kanun'dan doğan
haklarınız saklıdır. Uyuşmazlıklarınızı **kendi yerleşim yerinizdeki** Tüketici
Hakem Heyeti'ne veya Tüketici Mahkemesi'ne taşıyabilirsiniz; bu sözleşme sizi
başka bir yerdeki mahkemeye gitmeye zorlamaz.

**Tüketici değilseniz:** [yetkili mahkeme ve icra daireleri] yetkilidir.

Bize ulaşmayı denemeden dava açmak zorunda değilsiniz — ama çoğu sorun
[iletişim e-postası] adresine yazınca daha hızlı çözülüyor.

Bu sözleşmenin bir maddesi geçersiz sayılırsa diğer maddeler yürürlükte kalır.

#### 17. İletişim

[şirket unvanı]
[açık adres]
Genel: [iletişim e-postası]
Telif bildirimleri: [telif bildirim e-postası]
Gizlilik ve KVKK başvuruları: [iletişim e-postası]

---

---

# Play hesap silme sayfası metni

> Yayınlanacak hâli. Gerekçesi, neden bir form değil bir talep yolu olduğu ve
> nasıl yayınlanacağı `docs/hesap-silme-sayfasi.md` dosyasının başındadır.

## YAYINLANACAK METİN

### [uygulama adı] — Hesabımı sil

**Son güncelleme:** [tarih]

Hesabınızı ve verilerinizi istediğiniz zaman kalıcı olarak silebilirsiniz.
İki yol var.

#### 1. Uygulama içinden (en hızlısı)

**Ayarlar → Hesabımı sil**

Onaylamak için takma adınızı yazmanız istenir. Bekleme süresi ve geri alma
penceresi yoktur; işlem tamamlandığında hesabınız gerçekten silinmiş olur.

#### 2. Uygulamayı sildiyseniz veya erişemiyorsanız

**[iletişim e-postası]** adresine, hesabınıza kayıtlı e-posta adresinden bir
ileti gönderin ve konuya *"Hesap silme talebi"* yazın. Talebinizi **en geç 30
gün içinde** sonuçlandırırız. Kimliğinizi doğrulamak için sizden ek bilgi
isteyebiliriz — bu, başkasının sizin hesabınızı sildirmesini önlemek içindir.

---

#### Silindiğinde ne oluyor?

**Önce dosyalarınız, sonra hesabınız siliniyor.** Fotoğraflarınız ve profil
görseliniz depolama alanından kaldırılmadan hesap silinmez; dosyaların tamamı
silinemezse **işlem durur ve hesabınız olduğu gibi kalır.** Yarım bir silmeyi
"silindi" diye göstermeyiz.

**Silinen veriler:**

- Arşivinizdeki tüm sorular ve **soru fotoğraflarınız**
- Profil fotoğrafınız
- Profiliniz: takma adınız, maskotunuz, doğum yılınız, arkadaş kodunuz
- XP'niz, seriniz, elmaslarınız, lig geçmişiniz
- Çalışma ve tekrar geçmişiniz, cevap kayıtlarınız
- Arkadaşlıklarınız ve arkadaşlık istekleriniz
- Gönderdiğiniz ve size gönderilen sorular
- Engellemeleriniz ve yaptığınız şikâyetler
- Onay kayıtlarınız
- Bildirim kaydınız (cihaz jetonunuz)
- Uygulama kurallarına uyum kayıtlarınız (varsa ihlal ve kısıtlama kayıtları)
- E-posta adresiniz ve hesabınızın kendisi

#### Silmeden sonra geri getiremediklerimiz

Dürüst olmak adına bunları da yazıyoruz:

- **Daha önce yapay zekâ servisine gönderilmiş fotoğraflar.** Soru fotoğrafları
  okunmak ve içerik güvenliği taramasından geçmek üzere OpenAI'a gönderiliyor;
  gönderilmiş bir kopyayı geri çağıramayız.
- **Daha önce gönderilmiş bildirimler.**
- **Bir arkadaşınıza gönderdiğiniz sorunun onun tarafında kalan kaydı.**
- **Kimliğinizle ilişkilendirilmemiş teknik hata kayıtları** (hata izleme
  servisimizin saklama süresi boyunca). Bu kayıtlarda kullanıcı kimliğiniz ve
  e-posta adresiniz gönderilmeden önce silinir.

#### Kayıt olmadan denediyseniz

Hesap açmadan uygulamayı denediyseniz hiçbir şey yapmanıza gerek yok:
kayıt olunmamış hesaplar **7 gün sonra otomatik olarak** silinir.

#### Tek bir soruyu silmek

Şu an uygulama içinde soruları tek tek silme özelliği yok. Belirli bir sorunun
ya da fotoğrafın silinmesini istiyorsanız **[iletişim e-postası]** adresine
yazın, sileriz.

#### Diğer talepleriniz

Verilerinize erişmek, düzeltilmesini istemek, bir kopyasını almak veya
işlenmesine itiraz etmek için de aynı adrese yazabilirsiniz. Haklarınızın tam
listesi ve başvuru usulü için: [KVKK aydınlatma metni URL'i]

---

**[şirket unvanı]**
[açık adres]
[iletişim e-postası]

Gizlilik Politikası: [gizlilik politikası URL'i]
Kullanım Koşulları: [kullanım koşulları URL'i]
