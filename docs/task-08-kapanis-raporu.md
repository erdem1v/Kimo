# Task 08 — Yayın öncesi kapanış raporu

Mağazaya gönderim öncesi kalan kod işleri. Üç tür: Task 07'den devreden
mağaza bayrakları (A-2, A-8, A-9), bilinen hatalar, ve gerçek bir özellik
(çevrimdışı fotoğraf kuyruğu).

**Doğrulama durumu.** Bu makinede Docker yok; pgTAP ve mutasyon süiti
**yalnızca CI'da** koşuyor. Yerelde koşan ve YEŞİL olanlar: `flutter analyze`,
`flutter test` (184 test), `tools/check_sql.py`, `tools/check_symbols.py`,
`tools/check_imports.py` (üçü de kendi selftest'leriyle birlikte). SQL
tarafında yazılan iddialar "yazıldı, CI'da koşacak" durumunda.

---

## 1. Analiz yaş kapısının arkasına alındı (A-2)

**Sorun.** Onboarding sırası `firstCapture → age → …`. Öğrencinin ilk
fotoğrafı, yaşı bilinmeden `analyze-question` üzerinden OpenAI'a gidiyordu.
Task 07 ile 13 yaş sınırını zorlamaya başladık ve hukuki metinler "13 altını
kabul etmiyoruz" diyor — yani reddedeceğimiz bir kullanıcının verisi
reddedilmeden önce yurt dışına aktarılıyordu. Task 07 raporu bunu "kalan
bayrakların en kırılganı" diye bırakmıştı.

**Ne yapıldı — üç katman.**

**(1) İstemci: fotoğraf yerelde bekliyor.** `CaptureScreen`'e `deferAnalysis`
modu eklendi. Onboarding çekiminde analiz de yükleme de yapılmıyor; fotoğraf
`PhotoQueue`'ya `gate: 'age'` damgasıyla giriyor ve kullanıcı bir sonraki adıma
dönüyor. `AgeGateStep._saveYear()` başarılı olunca `releaseAgeGate()` + `flush()`
çağrılıyor — analiz o an, arka planda çalışıyor. `KM013` (13 altı) dalında
`purgeAgeGated()` kaydı ve **cihazdaki dosyayı** siliyor.

**Adım sırası değişmedi**: öğrenci hâlâ ilk iş olarak fotoğraf çekiyor.

**(2) Sunucu: yaş doğrulanmadan analiz reddediliyor.** Yeni definer fonksiyon
`public.ai_age_ok()` (göç 0067). `analyze-question/index.ts` bunu **en başta**
soruyor — önbellekten de kotadan da önce — ve `403 { reason: "age_required" }`
dönüyor. Kapı sorulamazsa (ağ hatası) analiz **yapılmıyor**: fail-open burada
kapının hiç olmadığı duruma eşitlenirdi.

**(3) Veri: yaş yoksa satır da fotoğraf da yazılamıyor.** `mistakes` ve
`storage.objects` INSERT politikalarına `public.has_birth_year(auth.uid())`
eklendi. "13 altı reddedilirse fotoğraf depolamada bırakılmamalı" böylece
istemci nezaketi değil veri katmanı garantisi oldu.

**Neden "doğum yılı dolu" testi yaşı hesaplamaya yetiyor.** `set_birth_year`
(0063) tek yazımlık ve 13 altını `KM013` ile reddediyor — sütun doluysa değeri
zorunlu olarak 13+. Yaşı burada yeniden hesaplamak aynı kuralın ikinci kopyasını
yaratırdı.

**Reddedilen alternatifler.** (a) Adım sırasını `age → firstCapture` yapmak —
görev açıkça yasakladı ve çevrimdışı hâli çözmüyor. (b) Doğum yılını analiz
çağrısının gövdesine koyup sunucuda karar vermek — fotoğraf yine bizim Deno
fonksiyonumuza ulaşırdı ve karar kaynağı istemciye taşınırdı.

**Sonradan kapatılan boşluk.** İlk yazımda ertelenmiş çekimde OpenAI **aktarım
onayı** hiç sorulmuyordu; kuyruk boşalırken analiz kullanıcı ekranda değilken
çalışacağı için onay sessizce atlanmış olurdu (Task 03, 4.2'nin ihlali). Onay
artık kuyruğa almadan ÖNCE soruluyor ve `PhotoQueue.flush` ikinci kapı olarak
`userProfile.aiConsent`'i kontrol ediyor: onay yoksa analiz atlanıyor, kayıt
elle doldurulmak üzere bekliyor.

**Değişen dosyalar.** `supabase/migrations/20260906000200_age_gate_ai.sql`,
`supabase/functions/analyze-question/index.ts`,
`lib/features/capture/capture_screen.dart`,
`lib/features/onboarding/onboarding_flow.dart`,
`lib/features/onboarding/age_gate_step.dart`, `lib/data/photo_queue.dart`,
`lib/data/mistake_repository.dart`, `lib/models/models.dart`
(`AnalysisFailure.ageRequired`).

**Nasıl doğrulandı.** `tests/130_age_gate.sql`: doğum yılı yokken `ai_age_ok()`
false ve `mistakes` INSERT'i 42501; **aşırı kilitleme karşı-iddiası** olarak
yılı olan kullanıcının hâlâ ekleyebildiği. Mutasyon
`24_ai_age_gate_open.sql` kapıyı her zaman açık bırakıp 130'un kırmızıya
döndüğünü kanıtlıyor.

**Ne değişmedi.** Onboarding adımlarının sırası, "fotoğrafsız devam" yolu,
aktarım onayının metni ve deftere yazılması.

---

## 2. Çevrimdışı fotoğraf kuyruğu

**Sorun.** Cevaplar için kuyruk vardı (`SubmissionQueue`), fotoğraf için yoktu.
`app_tr.arb` bunu açıkça söylüyordu: *"İnternet giderse fotoğraf kuyruğa
girmez"*. Hedef kitle serviste ve kapsama alanı zayıf yerlerde çalışıyor.

**Ne yapıldı.** `lib/data/photo_queue.dart` — `SubmissionQueue` desenini
izleyen tekil sınıf: `uid` damgası, sıra korumalı `flush`,
`PostgrestException` → kaydı düşür / ağ hatası → dur ayrımı, `_flushing`
kilidi, aynı üç tetikleyici (`home_shell` resume, soğuk açılış,
`drainIfPending`), oturum kapanışında `clear()`.

**Üç bilinçli fark ve gerekçeleri:**

| Konu | `SubmissionQueue` | `PhotoQueue` | Neden |
|---|---|---|---|
| Depolama | tamamı prefs | üstveri prefs, **baytlar dosya** | base64'e çevrilmiş JPEG megabaytlarca metin; prefs her yazımda dosyanın tamamını yeniden serileştiriyor |
| Sınır aşımı | en eskiyi **düşür** | yeni kaydı **reddet** | kaybolan şey kullanıcının fotoğrafı, tekrar üretilebilir bir eylem değil |
| Sıra | katı | `needsUser` **atlanır** | kullanıcı eylemi bekleyen kayıt arkasındakileri rehin alırdı |

**Durum makinesi.** `needsAnalysis` → (analiz) → `needsUser` ya da `ready` →
(yükleme+insert) → düşer. `correctIndex` yapay zekâdan **gelmiyor**
(`analyze-question` şeması doğru cevabı döndürmüyor), yani analizi bekleyen
kayıtlar normalde `needsUser`'a düşüyor — §5'in "doğru cevabı kullanıcı
işaretler" kuralının doğrudan sonucu; akış bunu gizlemiyor.

**Görünürlük.** Bu depoda sessiz kuyruk kabul edilmiyor. `today_screen`'de
"N fotoğrafın sırada bekliyor" şeridi — **hem panoda hem sıfır-veri ekranında**.
İkincisi kritik: onboarding'in ilk çekimi kuyruğa girdiğinde arşiv HENÜZ BOŞ ve
şerit yalnız panoda olsaydı A-2 çözümü tam da orada sessizce kaybolurdu.
Yeni ekran `lib/features/capture/pending_photos_screen.dart`: küçük durum
rozeti + "Tamamla" / "Sil".

**Kuyruk dolduğunda çıkmaz yok.** Reddetme mesajı tek başına bırakılmadı;
`showPhotoQueueFullSheet` doğrudan bekleyenler ekranına götüren bir birincil
düğme taşıyor.

**`path_provider`** doğrudan bağımlılık oldu (zaten geçişli olarak vardı;
`pubspec.lock`'ta yalnız `dependency` alanı `transitive` → `direct main`).

**Nasıl doğrulandı.** `test/data/photo_queue_test.dart` — 14 test: disk
biçiminin okunması, bozuk JSON'un kuyruğu kilitlememesi, durum yeniden
hesabı (eksik doğru şıkta `ready` OLMAMASI), `purgeAgeGated`'in yalnız kilitli
kayıtları silmesi, `clear`'ın dosyaları da silmesi, sayaçlar.
**Kapsam dışı: `flush()`** — ağ çağrısı gerektiriyor ve depoda sahte Supabase
istemcisi yok (`mocktail` bilinçli eklenmedi).

**Bilinen kabul: en-az-bir-kez.** `MistakeRepository.add` idempotent değil;
yanıt kaybolursa kopya satır oluşabilir. Sunucu tarafı bir idempotans anahtarı
`mistakes`e yeni sütun ve yeni bir lockdown göçü isterdi — dört kişilik iç
testte bu takas doğru değil. Kullanıcı kopyayı silebiliyor (A-9).

---

## 3. Elle giriş akışının son hâli

**Ürün kuralı (karara bağlandı).** Kaydetme yolu hiçbir koşulda kapanmaz, ama
eksik veriyle de kaydedilmez.

`ConfirmMistakeScreen` zaten üç yolun ortak formuydu (hak bitti / AI onayı yok /
fotoğrafsız devam). Değişenler:

1. **Şık sayısı kullanıcıda.** Liste eskiden ya AI'dan geliyordu ya beş harf
   sabitiyle doluyordu; dört şıklı bir soruda elle giriş yapan öğrenci olmayan
   bir E şıkkını işaretleyip kaydedebiliyordu. Artık 4/5 seçimi var ve seçili
   şık listenin dışında kalırsa işaret **düşüyor**.
   Şık **metni** girilmiyor — pratik ekranı zaten yalnız harfleri gösteriyor.
2. **Not alanı gerçekten bağlandı.** `_note` controller'ı tanımlıydı, dispose
   ediliyordu, `_save`'de okunuyordu — ama hiçbir `TextField`'a bağlı değildi,
   yani `note` her kayıtta boş gidiyordu. Fotoğrafsız bir soruda pratik
   ekranının gösterebildiği tek içerik bu.
3. **Çevrimdışı kaydetme.** Ağ hatasında kayıt `ready` olarak kuyruğa giriyor
   ve "sıraya alındı" deniyor. Sunucu **reddi** kuyruğa alınmıyor (tekrar
   denemek aynı sonucu verir).
4. **"Analizi bekle"** düğmesi: fotoğraf var ve analiz yapılamadıysa
   (ağ / yaş kapısı / hiç denenmemiş) görünüyor. §5'in iki yolu da açık.

### Öz-değerlendirme: kaldırılmadı, ağırlığı düştü

Şıksız eski satırlarda "Doğru çözdüm / Bilemedim" **duruyor** — fotoğrafı
bulanık çıkmış ya da şıkları okunamayan bir kayıtta kullanıcının tek çıkışı bu.
İki değişiklik:

**(a) Öz-raporlu doğru merdivende daha yavaş ilerliyor.** `ReviewScheduler.review`
yeni bir `selfReported` bayrağı alıyor:

| Durum | Adım | Aralık | `mastered` |
|---|---|---|---|
| Şıklı doğru | `i → i+1` | `steps[i+1]` | kurallara göre yazılabilir |
| **Öz-raporlu doğru** | `i → i+1` | **`steps[i]`** | **asla yazılmaz** |
| Yanlış (iki yol) | 0'a döner | değişmiyor | — |

Yani merdiven kapanmıyor ama takvim yavaşlıyor ve "öğrenildi" damgası yalnızca
gerçekten işaretlenmiş bir şıktan çıkabiliyor. Görevin şikâyeti tam buydu.
Yanlış cevap iki yolda da aynı: "bilemedim" demekte abartma güdüsü yok.

**(b) Yanında "Bu soruda şık yok — şıkları ekle" kartı.** Şık sayısı + doğru şık
soran bir sheet; satır `options`/`correct_index` ile güncelleniyor
(`MistakeRepository.completeMistake`) ve soru **bu turda cevaplanmıyor**, bir
sonrakine bırakılıyor — doğru şıkkı az önce kendisi işaretleyen kullanıcıya aynı
soruyu sormak tekrarın ölçtüğü şeyi ölçmez.

**Yeni kayıtlar zaten hep eksiksiz**: `_canSave` ders + konu + doğru şık şart
koşuyor ve tüm yollar 4–5 şık yazıyor. Bu kart yalnızca eski satırlarda görünür.

**Nasıl doğrulandı.** `review_scheduler_test.dart`'ta dört yeni test: her
merdiven adımında normal/öz-raporlu aralık farkı (şıklı doğrunun bugünkü
davranışının **değişmediği** karşı-iddiasıyla), bakım basamağı, aynı koşulda
şıklı doğrunun emekli edip beyanın etmediği, ve yanlışın iki yolda özdeş
olduğu.

---

## 4. Engel kaldırma arayüzü (A-8)

Sunucu 0044'ten beri hazırdı (`unblock_user`, `blocks_delete_own`); istemci
API'si de vardı ama **ölüydü** — `friendRepository.unblock` ve `blockedIds`
hiçbir yerden çağrılmıyordu. Kullanıcı birini engelleyebiliyor, listeyi
göremiyor ve geri alamıyordu.

**Ne yapıldı.** Yeni RPC `public.my_blocked_users()` (0068) ve yeni ekran
`lib/features/settings/blocked_users_screen.dart`; ayarların "Hesap"
bölümünden açılıyor.

**Neden yeni bir RPC.** İsimleri `profiles_public`'ten okumak iki nedenle
yanlıştı: görünüm anonim ve sistem hesaplarını süzüyor (0047) — engellediğin
anonim biri listede **boşluk** olarak görünür ve engeli kaldırılamazdı — ve
görünüm 0068'de zaten istemciye kapandı. `my_blocked_users` süzgeçsiz okuyor,
`auth.uid()`'e kilitli ve parametre almıyor (kimin kimi engellediği
sorulamıyor). Avatar bilerek dönmüyor.

**Nasıl doğrulandı.** `tests/280_directory.sql`: engelleme → ad listeleniyor,
başkasının listesi görünmüyor, engel kalkınca liste boşalıyor.

---

## 5. Tek soru silme (A-9)

**Ne yapıldı.** Yeni edge function `supabase/functions/delete-question/index.ts`.
JWT'den uid, satırı sahiplikle oku, **önce depo nesnesi sonra satır**.
Arayüz: arşiv satırında silme düğmesi + `showModalBottomSheet` onayı.

**Neden edge function, neden RPC değil.** SQL'den `storage.objects` silmek
**yetmiyor**: metadata satırı gidiyor, nesne nesne deposunda kalıyor. Depo bunu
zaten biliyor — moderasyon temizliği bu yüzden kuyruk + Storage API kalıbı
kullanıyor (0031). Gerçek silme yalnızca Storage API üzerinden oluyor.

**Sıra.** Satır önce gitseydi `photo_path`i kaybeder ve dosya sessizce yetim
kalırdı (`all_questions_screen`'deki yönetici silmesinin aynı gerekçesi). Ters
yöndeki kalan risk — nesne gitti, satır kalmadı — kullanıcıya **görünür hata**
olarak dönüyor ve ikinci deneme satırı siliyor.

**Yanında:** `lockdown_v5` `mistakes` için istemcinin DELETE yetkisini geri
aldı. Bugüne kadar istemci satırı doğrudan silebiliyordu (`init.sql:95` +
hiçbir lockdown'da revoke yok) ve o yol yetim dosya bırakırdı. Politika
düşürülmedi: definer yollar (admin, hesap silme) zaten RLS'i atlıyor ve
politikayı silmek katalogda "silme hiç düşünülmemiş" izlenimi bırakırdı.

**Nasıl doğrulandı.** `tests/020`: `has_table_privilege(... 'DELETE')` false ve
çalışma zamanında 42501. Mutasyon `25_mistakes_delete_open.sql`.

---

## 6. Portre kilidi — zaten yapılmış, doğrulandı

| Katman | Durum |
|---|---|
| Android | `AndroidManifest.xml:27` → `android:screenOrientation="portrait"` |
| iOS | `Info.plist:68-78` → `UIRequiresFullScreen` + iPhone yalnız portre, iPad portre + ters portre |
| Dart | `SystemChrome` çağrısı **yok** — gerekmiyor, platform beyanı daha güçlü |

Task 03'te kapatılmış. **Kod değişikliği yok.**

---

## 7. `scan-photos`: gerçek MIME, boyut sınırı, terminal durum

**Sorun.** MIME sabit `image/jpeg` yazılıyordu. PNG/WebP yüklendiğinde
moderation isteği reddediliyor, satır `pending` **kalıyor** ve süpürücü on
dakikada bir aynı indirmeyi boşuna tekrarlıyordu. Boyut kapısı da yoktu
(`analyze-question` 8 MB'da duruyor, tarama tarafında karşılığı yoktu) ve
kovalar sınırsız kurulmuştu.

**Ne yapıldı.**

- **Gerçek tür bayttan okunuyor** (`sniffMime`): sihirli baytlar (JPEG/PNG/WebP),
  uyuşmazsa depodaki `content-type` beyanına düşülüyor, o da tanınmazsa `null`.
  Beyana **tek başına** güvenilmedi: yükleme çağrısında istemci ne yazdıysa o.
- **Boyut kapısı** `MAX_BYTES = 8 MiB`, base64'e çevirmeden **önce** —
  sırası önemli, yoksa kapının korumak istediği belleği zaten harcamış olurduk.
- **Terminal durum `'unsupported'`** (göç 0066). `'flagged'` yazmak **yanlış**
  olurdu: 0062'nin ihlal tetikleyicisi `flagged`'da ateşliyor ve kullanıcı
  **dosya biçimi yüzünden** yaptırım merdivenine girerdi.
- **Kapıda reddetme:** `mistake-photos` kovasına `file_size_limit = 8 MiB` +
  `allowed_mime_types = {jpeg, png, webp}`; `avatars`'a aynı tür kümesi + 4 MiB.

**`unsupported` neden güvenli.** Bütün paylaşım kapıları **pozitif** yazılmış
(`photo_scan = 'clear'`), yani yeni değer hiçbirinde eşleşmiyor: satır sahibine
açık, paylaşıma kapalı. Süpürücünün kısmi index'i `where photo_scan = 'pending'`
olduğu için kuyruktan da çıkıyor.

**Yönetici artık kör değil.** `admin_review_photo_scan(id,'clear')` bir satırı
durumuna bakmadan paylaşıma açıyor — yani yönetici hiç taranmamış bir fotoğrafı
da temiz işaretleyebiliyor. Yetki **bilerek duruyor** (son söz insanda) ama
karar bilerek verilsin diye `admin_all_questions` artık `photo_scan` döndürüyor
ve yönetici listesinde "taranmadı" / "taranamadı" / "şüpheli" rozeti görünüyor.
`clear` durumunda rozet çizilmiyor — mutlu yol gürültü olmasın.

**Nasıl doğrulandı.** `tests/220_photo_scan.sql`: `unsupported` CHECK'te kabul
ediliyor, havuzda görünmüyor, **ihlal sayacını artırmıyor**, süpürücü
kuyruğunda değil, ve `admin_all_questions` durumu döndürüyor. İhlal iddiası
için **ayrı bir kullanıcı ve satır** kuruldu: dosyanın mevcut fikstürü bilerek
`flagged`'dan geçiyor, yani onun sayacı zaten dolu ve sıfır iddiası orada
anlamsız olurdu.

---

## 8. `dueReviews()` limitsizdi

`.limit(60)` eklendi; sıralama zaten `next_review_at` artan, yani kesilen kısım
her zaman "daha az acil" olan.

**Sayaç artık sunucudan.** Listenin uzunluğunu sayaç olarak kullanmak, arşivi
büyük bir kullanıcıya gerçekte olduğundan **az** tekrar olduğunu söylerdi.
`my_daily_state.due_count` aynı kuralı sunucuda, İstanbul gününe göre
hesaplıyor; `today_screen` ve `notifications.planDay` artık onu okuyor.
Çevrimdışıyken listeye düşülüyor.

`fetch()` de limitsizdi — sınırsız değil, **sessizce kesiliyordu**: PostgREST'in
`max-rows` ayarı (varsayılan 1000) listeyi kırpıyor ve istemci fark etmiyordu.
Açık bir `.limit(500)` kondu (kapsam dışı, aşağıda listelendi).

---

## 9. Leech eşiği tek kaynağa indi

`ReviewScheduler.defaultLeechThreshold = 4` tek kaynak; constructor varsayılanı
ve `MistakeStats.leechThreshold` ona bağlı. `schedulerLeechThreshold` köprüsü
düştü.

Testteki eşitlik iddiası **tautolojiye** dönüşeceği için (bir sabiti kendisiyle
karşılaştırmak) **davranış testine** çevrildi: planlayıcı eşikte inatçı diyor,
altında demiyor; istatistik aynı sınırı `isLeech` bayrağına hiç bakmadan
görüyor.

---

## 10. Sınav yılı listesi mevcut yıldan türetiliyor

`[2026 … 2030]` sabiti iki dosyada duruyordu. `UserProfile.examYears({now})`
tek kaynak: ilk yıl, o yılın sınavı henüz olmadıysa bu yıl, olduysa gelecek yıl;
ardından 5 yıl. Sınav tarihi `ReviewScheduler.examCutoffFor`'dan geliyor —
tekrar motoru "sınav geçti mi" sorusunu zaten o tarihle yanıtlıyor, ikinci bir
tarih uydurmak ikisini ayrıştırırdı.

`test/state/exam_years_test.dart`: 19/20/21 Haziran sınır günleri, 2031 ve 2040
kaymaları, uzunluk ve ardışıklık, müfredat eşiğiyle uyum.

---

## 11. `profiles` UPDATE politikasında `WITH CHECK`

```sql
create policy "Kendi profilini güncelle"
  on public.profiles for update
  using      (auth.uid() = id)
  with check (auth.uid() = id);
```

**Tuzak neydi.** `WITH CHECK`'i olmayan bir UPDATE politikasında `USING` yeni
satıra da uygulanıyor; `with check` eklendiği anda o örtük koruma kalkıyor.
Task 01 bu yüzden eklemeyi reddetmişti. Burada sahiplik koşulu **açıkça yeniden
yazılarak** tuzağın kendisi kapatıldı.

**Doğrulama katalog düzeyinde olmak zorunda:** `WITH CHECK`'in ısırdığı tek
senaryo satırın `id`'sini başkasına çevirmek ve `id` sütun ayrıcalığında
kilitli, yani çalışma zamanında tetiklenemiyor. `tests/010` üç şey iddia ediyor:
`with_check` dolu, sahiplik koşulunu taşıyor (boş bir `true` değil), ve `USING`
korunmuş. Mutasyon `26_profiles_with_check_true.sql` politikayı
`with check (true)` ile yeniden yazıp iddianın gerçekten ayırt ettiğini
kanıtlıyor.

---

## 12. Takma ad araması ve dizin dökülebilirliği

**Arama zaten yoktu.** `socialRepository.search()` Task 02'de silinmişti; geriye
yalnız gerekçe yorumları kalmıştı (bayat olanlar temizlendi).

**Açık kalan gerçek yüzey.** `profiles_public` görünümü `authenticated` rolüne
doğrudan açıktı: uygulamayı hiç çalıştırmadan, bir oturum + anon anahtarla
`select * from profiles_public` bütün kullanıcı tabanını sayfa sayfa
döküyordu. 0045 bunu "bilinen ve kabul edilen sınır" diye not etmişti — yani
aramayı kaldırmak dizini **kapatmamış**, yalnızca arayüzden gizlemişti.

**Ne yapıldı (göç 0068).**
- Yeni definer RPC `public.profiles_by_ids(uuid[])`, en fazla **60 kimlik**
  (aşımda `22023`). İstemcideki üç okuma da (kendi profilim / id listesi / tek
  id) buna geçti; büyük arkadaş listeleri istemcide parçalanıyor.
- `revoke select on public.profiles_public from authenticated, anon, public`.
- Yetim `profiles_nickname_lower_idx` düşürüldü (arama kalkınca unutulmuştu).
- `function_grants_recheck9`'a bir kapı: `create or replace view` grant'ları
  **koruyor**, yani görünümü yeniden tanımlayan sonraki bir göç eski
  `grant select`i farkında olmadan diriltebilir — göç zamanında patlıyor.

**Lig tahtası etkilenmedi:** `my_league_board` `profiles` tablosunu doğrudan
okuyor (definer). `tests/280` bunu ayrıca iddia ediyor (aşırı kilitleme
karşı-iddiası).

**pgTAP'te yan etki:** `050`, `150` ve `200` görünümü doğrudan okuyordu; üçü de
`profiles_by_ids`'e taşındı. İddiaların **konusu değişmedi** — avatar
ilişki-kapısı, anonim süzgeci ve seri maskesi görünümün içinde ve aynen
sınanıyor.

---

## 13. E-posta doğrulama artıkları temizlendi

`login_screen`'deki `email_not_confirmed` dalı, `authRepository.resendSignUp`
ve `signInEmailNotConfirmed` l10n anahtarı silindi; atıl kalan `dart:async`
importu da düştü. Task 07'de bilinçli korunmuşlardı (üretimde
`enable_confirmations = false` teyit edilmemişti); teyit verildi.

---

## 14. Ölü sütunlar

Yöntem: her aday için `lib/`, `supabase/migrations/` (view, trigger, policy,
function, index, grant) ve `supabase/functions/` tarandı; **lockdown ve recheck
listelerindeki adlar sayılmadı** — orada olmak "kullanılıyor" değil
"sınıflandırıldı" demek.

| Sütun | Bulgu | Karar |
|---|---|---|
| `profiles.exam_track` | Tek tanım `init.sql:28`; başka referans yalnız 5 lockdown listesi | **Düşürüldü** |
| `profiles.grade` | Aynı | **Düşürüldü** |
| `profiles.display_name` | `nickname` ile çift kayıt; `handle_new_user` yazıyor ama `upsert_my_profile` hiç güncellemiyor → **bayatlıyor**, hiçbir ekranda doğru göstermiyor | **Düşürüldü** |
| `mistakes.correct_answer` | Tek tanım `reviews.sql:8`; hiç okunmuyor/yazılmıyor | **Düşürüldü** |
| `mistakes.review_count` | Tek tanım; hiç artırılmıyor | **Düşürüldü** |
| `profiles.dismissed_reports` | `moderation.sql:61,67,194` canlı kullanıyor | Ölü değil |
| `mistakes.photo_purged_at` | `moderation_purge.sql` kuyruk mantığı | Ölü değil |
| `mistakes.source*` | ÖSYM içe aktarımı | Ölü değil |
| index `profiles_nickname_lower_idx` | Kullanan sorgu yok | **Düşürüldü** |

**`display_name`'in ek işi.** Sütun yalnız kilitli listede durmuyordu, hâlâ
yazılıyordu: `handle_new_user()` yeniden yazıldı (nickname ataması,
`is_anonymous` dalı ve `assign_friend_code()` çağrısı **aynen** korunarak — bu
üçünden biri kaybolsa yeni kullanıcı kodsuz doğar ve arkadaş eklemenin tek yolu
sessizce kapanırdı) ve `user_profile.dart`'taki metadata yazımı kaldırıldı.
**Okuma yedeği duruyor**: 0069 öncesinde açılmış hesapların metadata'sında
takma ad yalnızca orada olabilir.

`tests/010`'a bir **aşırı kilitleme karşı-iddiası** eklendi: yeni doğan
kullanıcının hâlâ takma adı **ve arkadaş kodu** var.

`function_grants_recheck9`'a bir kapı daha: beş sütunun geri gelmediği. Eski bir
göç yeniden çalıştırılırsa `add column if not exists` sütunu sessizce geri
getirir ve hata **aylar sonra**, bir sonraki lockdown göçünde görünürdü.

---

## 15. Testler ve mutasyonlar

**Yeni pgTAP:** `280_directory.sql` (16 iddia).
**Genişletilen:** `010` (28→35), `020` (29→33), `130` (22→27), `220` (16→21),
`270` (44→46). Süitin toplam plan sayısı **590**; `tools/check_sql.py` her
dosyada `plan(n)` ile gerçek iddia sayısının birebir eştiğini doğruluyor.

**Yeni mutasyonlar:**

| Dosya | Bozduğu koruma | Kırmızıya dönen test |
|---|---|---|
| `23_profiles_public_open` | görünümü yeniden `authenticated`'a açar | `280_directory` |
| `24_ai_age_gate_open` | `ai_age_ok()` her zaman `true` | `130_age_gate` |
| `25_mistakes_delete_open` | istemciye DELETE geri verir | `020` |
| `26_profiles_with_check_true` | `with check (true)` | `010` |
| `27_age_gate_drops_suspension` | yaş koşulunu ekler, **askı koşulunu düşürür** | `270_sanctions` |

`27` bilerek **"doğru görünen yanlış"**: 0067 `mistakes` INSERT politikasını
`drop` + `create` ile yeniden yazıyor, yani 0062'nin askı koşulunu elle taşımak
gerekiyordu. Onu düşürmek bu paketin en olası regresyonu ve dışarıdan bakınca
göç doğru görünüyor — yaş kapısı çalışıyor, `130` yeşil, hiçbir şey patlamıyor.
Kırmızıya dönmesi gereken `270`. Mutasyon iki testin aynı şeyi ölçmediğini
kanıtlıyor.

**Fikstür yan etkisi.** Yaş koşulu RLS'e girdiği için `mistakes`'e insert eden
her pgTAP dosyası kendi fikstürünü kuramaz hâle geldi. `supabase/seed.sql`'e
`tests.age_all_users()` yardımcısı eklendi ve 12 dosyada tek satırla çağrılıyor.
`130_age_gate.sql` bilerek **çağırmıyor** — orada boş doğum yılı testin kendisi.

**Yeni Dart testleri:** `test/data/photo_queue_test.dart` (14),
`test/state/exam_years_test.dart` (7), `review_scheduler_test.dart`'a 5,
`mistake_stats_test.dart` davranış testine çevrildi. Toplam **184 test yeşil**.

---

## Dağıtımda atlanırsa sessizce çalışmayacak adımlar

1. **Göçlerden ÖNCE:** `select count(*) from public.profiles where birth_year is null;`
   Sıfır değilse o hesaplar göç sonrası **soru ekleyemez ve fotoğraf
   yükleyemez** hâle gelir (yaş koşulu RLS'e giriyor). Kullanıcıya yalnızca
   "kaydedilemedi" görünür. Dört test hesabında sıfır beklense de bakılmadan
   geçilmemeli; doluysa o hesaplar yaş adımından geçirilmeli.
2. **`supabase functions deploy delete-question`** — yeni fonksiyon. Yoksa
   silme düğmesi hata verir.
3. **`supabase functions deploy scan-photos`** ve **`analyze-question`** —
   ikisi de değişti. Eski sürüm ayakta kalırsa yaş kapısı ve MIME düzeltmesi
   **yok sayılır ve hiçbir hata görünmez**.
4. **`app_config.edge_base_url` + vault `service_role_key` dolu mu** — boşsa
   `scan-photos` süpürücüsü hiç çalışmıyor ve hata da vermiyor
   (`league_cron.sql:260-262`, `where exists (...)` no-op'a düşüyor).
5. **Kova sınırları göçle yazılıyor** ama üretimde göçler elle uygulandığı için
   `20260906000100`'ün `update storage.buckets` bloğunun gerçekten çalıştığı
   doğrulanmalı; göç sonundaki kapı sınır yazılamazsa patlıyor.

## Kapsamın dışında değiştirmek zorunda kaldıklarım

- **`fetch()` limiti** (`archiveLimit = 500`). Görev yalnız `dueReviews()`
  diyordu; `fetch()`'in sessiz kesilmesi daha kötü bir durumdu.
- **`avatars` kovası sınırları.** Görev `mistake-photos`'u kastediyordu; aynı
  göçte ikisini birden sınırlamak bir satır.
- **`handle_new_user()` yeniden yazımı** — `display_name` düşürmenin zorunlu
  sonucu.
- **`persona_card_test.dart`.** `hasFlag(SemanticsFlag.…)` Flutter 3.32'de
  kullanımdan kaldırılmış ve `flutter analyze` bunu `info` olarak bildiriyor —
  yani **CI'daki analyze adımı bu değişikliklerden bağımsız olarak zaten
  kırmızıydı**. `isSemantics(isSelected: true)` ile düzeltildi.
- **Bayat yorumlar** (`social_repository.dart`, `models/social.dart`).

## Açık iş olarak kalanlar (bu task'ta kapsam dışı)

- **`due_count` kuralının üç kopyası:** sunucu görünümü
  (`daily_state_v2.sql:65`), istemci sorgusu (`mistake_repository.dart`) ve
  `mistake_stats.dart`. Limit sonrası sayaç sunucudan geldiği için tutarsızlık
  kullanıcıya yansımıyor, ama üç kopya duruyor. Ek olarak `mistake_stats`
  `nextReviewDate` (tarih), `dueReviews()` `next_review_at` (zaman damgası)
  kullanıyor — ayrışabilirler.
- **`PhotoQueue.flush()` için birim testi yok** (sahte Supabase istemcisi
  gerektiriyor).
- **Kuyruğun en-az-bir-kez semantiği** kopya satır üretebilir (§2).

## Emin olmadıklarım / karar vermeniz gerekenler

| Konu | Bugünkü hâli | Alternatif |
|---|---|---|
| **Öz-rapor kuralının sayısal ayarı** | "bir kademe kısa aralık + asla `mastered`" | Ölçümle bulunması gereken bir değer; kural `ReviewScheduler.review` içinde **tek noktada** ve testler o noktaya bakıyor |
| **`unsupported` satırda yönetici yetkisi** | Yönetici `clear` yapabiliyor, rozet uyarıyor | `admin_review_photo_scan` bu durumu reddedebilir; son sözü insandan almak istemedik |
| **Onboarding'in ilk izlenimi** | "Kimo hemen bakıyor" anı → "sırada bekliyor" | Yaş adımını çekimin hemen ardına almak akışı hızlandırır ama adım sırasını değiştirir |
| **`profiles_by_ids` 60 kimlik sınırı** | Lig kohortu 12, arkadaş listesi tipik olarak çok altında | Sınır dar gelirse istemci zaten parçalıyor; sunucu sınırını yükseltmek dizin dökme maliyetini düşürür |
