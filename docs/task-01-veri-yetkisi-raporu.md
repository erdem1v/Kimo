# Task 01 — Veri katmanı yetki ve sahiplik düzeltmeleri

**Paket 1, 2 ve 3 — tamamlandı**
· Paket 1: A0 (test altyapısı) · A1 (sütun kilidi) · A2 (`push_lines`) · C (`send-push`)
· Paket 2: B1 (fotoğraf sahipliği) · B2 (kaldırma → depolama) · B3 (avatar + gerçek silme)
· Paket 3: E (sunucu otoriteli XP/cevap + çevrimdışı kuyruk) · D (onay defteri)

> **Durum: testler YAZILDI, ÇALIŞTIRILMADI.** Bu makinede `flutter`, `dart`,
> `supabase`, `docker`, `psql` kurulu değil. Aşağıda hiçbir düzeltme için
> "doğrulandı" demiyorum; her düzeltme için hangi testin ne iddia ettiğini
> yazıyorum. Çalıştırma adımları en altta.
>
> **Paket 2, siz "devam et" dediğiniz için test sonucu beklenmeden yapıldı.**
> Planda Paket 1'in yeşil sonucunu bekleyecektik. İki şey hâlâ açık: aşağıdaki
> `relacl` ölçümü alınmadı (geri alma blokları genel kaldı, `push_lines`'ın
> gerçek şiddeti ölçülmedi) ve 163 pgTAP iddiasının hiçbiri çalıştırılmadı.

---

## Uygulamadan ÖNCE çalıştırmanız gereken sorgu

Geri almanın gerçek olması ve `push_lines`'ın gerçek durumunu raporlayabilmem
için mevcut ACL'e ihtiyacım var. Göçleri uygulamadan önce:

```sql
select c.relname,
       c.relrowsecurity            as rls_acik,
       c.relacl                    as mevcut_yetkiler
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname in ('profiles','mistakes','study_attempts','question_attempts',
                     'question_sends','push_lines','app_config')
 order by c.relname;
```

Çıktıyı bana verin: (a) geri alma bloğunu tam olarak o ACL'e göre yazacağım,
(b) `push_lines`'ın "dünyaya açıktı" mı yoksa "zaten kapalıydı" mı olduğunu
tahminle değil ölçümle raporlayacağım.

---

## Bulgu bazlı

### C1 — `is_admin` kullanıcı-yazılabilir satırda

**Ne yapıldı.** `profiles.is_admin` sütunu düşürüldü; yönetici rolü politikası
olmayan yeni bir `public.admins` tablosuna taşındı (RLS açık, sıfır politika,
`revoke all`). `public.is_admin()` yeni tabloyu okuyacak şekilde yeniden yazıldı
— imza aynı kaldığı için Dart tarafı (`rpc('is_admin')`) ve tüm admin RPC'leri
değişmedi. Mevcut yöneticiler sütun düşürülmeden önce backfill edildi.

**Neden bu yaklaşım.** Sütun düzeyi `revoke` de yeterdi ve kümenin geri kalanında
kullandığım mekanizma bu. Ama `is_admin` bu depodaki en yüksek değerli hedef:
tek bir `PATCH /rest/v1/profiles {"is_admin": true}` isteği `moderate_report`,
`admin_all_questions`, `admin_question_action` ve `can_read_mistake_photo`'nun
admin dalını — yani **tüm kullanıcıların fotoğraflarını** — açıyordu.
Politikasız bir tablo *yapısal olarak* deny-by-default: ileride biri yanlışlıkla
geniş bir `GRANT` yazsa bile kapı açılmaz. **Reddedilen alternatif:** sütunu
yerinde bırakıp yalnızca `revoke update (is_admin)` yazmak — aynı sonucu verir
ama garantisi bir grant listesinin doğru kalmasına bağlıdır.

**Değişen dosyalar.** `supabase/migrations/20260901000100_privilege_lockdown.sql`
(tablo, backfill, `is_admin()` yeniden yazımı, sütun düşürme).

**Nasıl doğrulandı (test yazıldı, çalıştırılmadı).**
`supabase/tests/095_admins.sql` — negatif: `authenticated` ve `anon`
`public.admins`'e insert edemez; sıradan kullanıcı `insert into admins` denerse
42501 alır; `is_admin()` false döner; `moderate_report` "yetkisiz" der. Pozitif:
gerçek bir yönetici eklendiğinde `is_admin()` true döner ve
`admin_all_questions` çalışır — yani moderasyon ekranı ölmemiş olur.
`010` ayrıca `profiles.is_admin` sütununun artık var olmadığını iddia ediyor.

**Ne değişmedi.** Moderasyon iş mantığının hiçbiri. `moderate_report`,
`admin_question_action`, `admin_update_question` gövdeleri aynen duruyor.
Yönetici *atama* akışı yok — bugün de yoktu; `insert into public.admins` elle
yapılıyor (eskiden `update profiles set is_admin = true` elle yapılıyordu).

---

### C2 — `mistakes.moderation` ve `report_count` sahibi tarafından yazılabiliyor

**Ne yapıldı.** `mistakes` üzerinde sütun düzeyi yetkiler: `moderation`,
`report_count`, `solved_correct`, `solved_wrong`, `source`, `source_year`,
`source_session`, `user_id`, `correct_answer`, `review_count` hem INSERT hem
UPDATE için `authenticated`/`anon`'dan geri alındı. `photo_path` **yaz-bir-kez**
oldu: INSERT açık (yükleme akışı için şart), UPDATE kapalı.

**Neden bu yaklaşım.** Sütun düzeyi `GRANT`, RLS'ten önce executor'da
değerlendiriliyor, her erişim yolunda (PostgREST dahil) geçerli ve ihlal 42501
ile **gürültülü** başarısız oluyor. **Reddedilen alternatifler:** (a) RLS
`WITH CHECK` ile eski değeri karşılaştırmak — Postgres'te politika ifadesi eski
satırı göremez, ifade edilemez; (b) değeri sessizce geri yazan `BEFORE UPDATE`
trigger'ı — kullanıcı "kaydedildi" görür, veri değişmez; bu ürün zaten hataları
yutuyor, o kalıbı çoğaltmak istemedim.

**Değişen dosyalar.** `20260901000100_privilege_lockdown.sql` (`mistakes` bloğu).

**Nasıl doğrulandı (yazıldı, çalıştırılmadı).**
`supabase/tests/020_mistakes_column_lockdown.sql` — negatif: sahibi
`moderation='ok'`, `report_count=0`, `solved_correct=9999`, `source='osym'` ve
`photo_path='baskasi/...'` yazmaya kalkınca 42501; katalog düzeyinde de
`has_column_privilege` ile ayrıca iddia ediliyor. Pozitif: istemcinin bugün
attığı insert (`subject, concept, mistake_type, note, photo_path, is_public`)
hâlâ çalışıyor ve `note` güncellenebiliyor.

**Ne değişmedi.** `is_public` bilerek yazılabilir bırakıldı — paylaşımı geri
çekmek kullanıcının meşru hakkı. "Kaldırılmış içeriği geri açma" bununla değil,
`can_read_mistake_photo`'ya `moderation <> 'removed'` şartı eklenerek kapandı —
**bu iş Paket 2'de yapıldı**, aşağıya bakın.

---

### C3 — `xp`, `weekly_xp`, `league`, `streak` istemciden yazılıyor

**Ne yapıldı — kısmen.** `league`, `dismissed_reports`, `is_system`,
`guardian_consent`, `is_minor`, `hearts`, `gems`, `display_name`, `exam_track`,
`grade`, `created_at` kilitlendi. **`xp`, `weekly_xp`, `streak`, `week_start`,
`last_activity_date` bu pakette BİLEREK AÇIK bırakıldı.**

**Neden bu yaklaşım.** Bu beş sütun `social_repository.dart:55`'ten yazılıyor.
RPC'ler eklenmeden kilitlersem o yol 403 alır, çıplak `catch (_)` hatayı yutar,
ve `home_shell.dart:93`'teki `hydrate()` bir sonraki açılışta sunucudaki eski
değeri geri yükler — kullanıcı XP'sinin sıfırlandığını görür, hiçbir log'da iz
kalmaz. Sessiz veri kaybı. Sıra: RPC'ler (E1) → istemci geçer (E2) → sütunlar
kilitlenir (E4). **Reddedilen alternatif:** hepsini birden kilitleyip istemciyi
aynı anda değiştirmek — Paket 1'in "sıfır istemci etkisi" özelliğini kaybederdik
ve test altyapısının çalıştığını dört günlük işin sonunda öğrenirdik.

`league`'in kilitlenmesi tek başına önemli: `0017` onu generated column
olmaktan çıkarıp düz `text` yaptığı için yazılabilirdi, ve `league` değişimi
`push_on_friend_milestone` trigger'ını tetikleyip **tüm arkadaşlara sahte terfi
bildirimi** gönderiyordu.

**Değişen dosyalar.** `20260901000100_privilege_lockdown.sql` (`profiles` bloğu).

**Nasıl doğrulandı (yazıldı, çalıştırılmadı).**
`supabase/tests/010_profiles_column_lockdown.sql` — negatif: `league`,
`dismissed_reports`, `is_system`, `guardian_consent` yazımı 42501; `anon` için
de ayrıca iddia var. Pozitif: `nickname` güncellenebiliyor ve gerçekten
yazılıyor; `xp`/`weekly_xp`'nin **hâlâ açık** olduğu da açıkça iddia ediliyor —
yani bu paketin kapsamı testte de görünür.

**Ne değişmedi.** XP hesaplama modeli (`game_progress.dart`) hiç değişmedi.
Lig kohort mantığı, `settle_past_leagues`, `sync_league_member_xp` aynen duruyor.

---

### `study_attempts.correct` / `question_attempts.correct` (P1)

**Ne yapıldı — yalnızca çevresi.** Her iki tabloda `UPDATE` ve `DELETE`
tamamen geri alındı; `user_id`, `id`, `created_at` insert'ten kilitlendi.
`correct` alanının kendisi **hâlâ istemciden yazılıyor.**

**Neden bu yaklaşım.** `correct`'i sunucuya taşımak `submit_pool_answer` /
`submit_sent_answer` RPC'lerini ve istemci ekranlarının yeniden yazılmasını
gerektiriyor (Paket 3). Bu pakette yapılabilen tek şey çevresini kapatmaktı:
artık geçmiş bir ölçüm sonradan düzeltilemiyor veya silinemiyor, ve satır
başkasının adına yazılamıyor.

**Değişen dosyalar.** `20260901000100_privilege_lockdown.sql`.

**Nasıl doğrulandı.** Katalog iddiaları `010`/`020` kalıbıyla Paket 3'te
gelecek; bu pakette yalnızca `revoke` uygulandı, ayrı test yazılmadı.
**Bu bir eksik** — Paket 3'te `060_answers_xp.sql` ile kapanacak.

**Ne değişmedi.** `correct`'in kendisi. Ve şu sınır Paket 3'te de kalacak:
`public_questions` görünümü `correct_index`'i istemciye veriyor, yani doğruluğu
sunucuya taşımak tek başına hile engellemez — bu yüzden Paket 3'te
`correct_index` havuz yükünden çıkarılacak.

---

### `guardian_consent` / `share_consent` — sütun sahipliği

**Ne yapıldı.** `profiles.guardian_consent` ve `profiles.is_minor` kilitlendi.

**Ama asıl bulgu farklı yerde ve BU PAKETTE KAPANMADI.** Doğrulama sırasında
çıktı: `profiles.guardian_consent` **ölü bir sütun** — hiçbir Dart kodu okumuyor
ya da yazmıyor. Gerçek onay kaydı **auth kullanıcı metadata'sında**:
`auth_repository.dart:29` kayıtta `guardian_consent`'i,
`user_profile.dart:91-94` ise `share_consent`'i `auth.updateUser()` ile yazıyor.
Auth metadata **tamamen kullanıcı-yazılabilir** ve zaman damgası yok. Yani
sütunu kilitlemek güvenlik kazancı sağlamıyor; onu "onay kaydı korundu" diye
raporlamak yanıltıcı olurdu.

**Değişen dosyalar.** `20260901000100_privilege_lockdown.sql`.

**Ne değişmedi / sırada ne var.** Değişmez 7 (zaman damgalı + değiştirilemez
onay) **sağlanmadı.** Paket 3'te yalnızca ekleme yapılabilen `user_consents`
defteri geliyor. Yaş kapısı tasarımı ve hukuki metinler kapsam dışı.

---

### `push_lines` tablosunda RLS hiç açılmamış

**Ne yapıldı.** RLS açıldı (politika yok = kimse erişemez), `public`/`anon`/
`authenticated` grant'ları geri alındı. `app_config` için de — RLS'i zaten
vardı ama grant'ları hiç geri alınmamıştı — aynısı savunma derinliği olarak
yapıldı. Ayrıca göçe bir güvence bloğu kondu: `public` şemasında RLS'siz bir
tablo kalırsa göç patlıyor (Değişmez 6).

**Neden bu yaklaşım.** Şiddet **ortama bağlı** ve bunu koddan kanıtlayamıyorum:
RLS kapalıyken erişim yalnızca GRANT'lara bakar, ve `config.toml`'daki
`auto_expose_new_tables` notuna göre yeni projelerde yeni tablolar
`anon`/`authenticated`'a otomatik açılmıyor, eski davranışla kurulmuş bir
projede açılıyor. Hem RLS'i hem grant'ları birden iddia etmek belirsizliği
ortamdan bağımsız olarak kapatıyor.

**Değişen dosyalar.** `supabase/migrations/20260901000200_push_lines_rls.sql`.

**Nasıl doğrulandı (yazıldı, çalıştırılmadı).**
`supabase/tests/070_push_lines_rls.sql` — negatif: RLS açık, politika sayısı 0,
`authenticated`/`anon` için SELECT/INSERT/UPDATE/DELETE yetkisi yok, okuma
denemesi 42501. Pozitif: metinler duruyor (`send_push` definer olduğu için
okumaya devam edebilir), `app_config` da kapalı.

**Ne değişmedi.** Metinlerin kendisi. `push_lines`'ta hâlâ birincil anahtar ve
`kind`/`mascot` üzerinde CHECK kısıtı yok — yazım hatası olan bir satır sessizce
erişilemez kalır. Güvenlik sorunu değil; aşağıda "çözmediklerim"de.

---

### H7 — `send-push` kimlik doğrulamasız, sırrı hakkında bilgi sızdırıyor

**Ne yapıldı.** Paylaşılan sır modeli **tamamen kaldırıldı**. `config.toml`'a
`[functions.send-push] verify_jwt = true` yazıldı (ve `analyze-question` için de
beyan edildi); `public.send_push` artık `app_config`'teki service_role jetonunu
`Authorization: Bearer` olarak gönderiyor. Edge function'dan `x-push-secret`
karşılaştırması ve onu çevreleyen 401 gövdesi silindi. Yerine: JWT'nin `role`
iddiasının `service_role` olduğu kontrolü (savunma derinliği), `kind` beyaz
listesi, `user_id` UUID biçim kontrolü, `title`/`body` uzunluk sınırı ve **tek
tip, ayrıntısız hata gövdesi** (`{"error":"gecersiz_istek"}`) — teşhis sunucu
günlüğüne yazılıyor, yanıta değil. Bayat token silme işlemi `user_id` ile
sınırlandı.

**Neden bu yaklaşım.** Sınıfı sertleştirmek yerine yok etmek. Doğrulamayı artık
Supabase ağ geçidi, fonksiyon **hiç çalışmadan** yapıyor; dolayısıyla uzunluk
sızıntısı, zamanlama kanalı ve sınırsız deneme sorunları tek hamlede ortadan
kalkıyor — üçü için ayrı ayrı kod yazmaya gerek kalmıyor. **Reddedilen
alternatif:** sırrı yerinde sertleştirmek (SHA-256 + sabit zamanlı karşılaştırma
+ Postgres destekli deneme sayacı). Aynı sonucu daha çok güvenlik koduyla elde
ediyor ve sır yine kimlik doğrulamasız bir uçta duruyor.

**Değişen dosyalar.**
- `supabase/functions/send-push/index.ts` — sır karşılaştırması kaldırıldı,
  doğrulama + beyaz liste + genel hatalar eklendi.
- `supabase/config.toml` — `[functions.send-push]` / `[functions.analyze-question]`
  `verify_jwt = true`.
- `supabase/migrations/20260901000300_push_auth.sql` — `send_push` yeniden
  yazıldı (aynı 4 parametreli imza), `net` şeması erişimi kısıtlandı.

**Nasıl doğrulandı.** Edge function tarafı için **otomatik test yazılmadı** —
Deno test altyapısı bu depoda hiç yok ve onu kurmak paketin kapsamını aşıyordu.
Bu bir eksik. Veritabanı tarafı `098_function_grants.sql` ile kapsanıyor
(aşağıya bakın).

**Ne değişmedi.** FCM gönderim mantığı, erişim jetonu üretimi ve önbelleği,
bayat token temizliği (yalnızca `user_id` ile sınırlandı) aynen duruyor.
Bildirim metinleri ve maskot eşleşmesi değişmedi.

---

### YENİ BULGU — `send_push` RPC olarak da çağrılabiliyordu

**Ne yapıldı.** H7'yi düzeltirken çıktı: Postgres yeni fonksiyonlarda `EXECUTE`'u
`PUBLIC`'e verir ve `authenticated` bunu miras alır. Bu depoda 13 fonksiyona açık
`grant` yazılmış, geri kalanına yazılmamıştı. En ciddisi `public.send_push`:
`SECURITY DEFINER` ve servis rolüyle çalışan edge function'ı tetikliyor. Yani
oturum açmış herhangi biri `POST /rest/v1/rpc/send_push` ile **istediği
kullanıcıya, istediği senaryo ve aktör adıyla** bildirim gönderebiliyordu —
H7'nin aynısı, yalnızca edge function yerine RPC yüzeyinden.

Ayrıca: `settle_past_leagues()` ve `assign_week_cohorts()` de çağrılabiliyordu
(etkileri sınırlı — yalnızca zaten olacak olanı tetikliyorlar), ve
`set_osym_account(uuid)` `public`+`authenticated`'dan geri alınmışken `anon`
atlanmıştı.

Çözüm: beyaz liste. İstemcinin ve RLS politikalarının ihtiyaç duyduğu 13
fonksiyon dışındaki tüm `public` fonksiyonlarından `EXECUTE` geri alındı, sonra
beyaz listenin hâlâ çağrılabilir olduğu **göç içinde doğrulandı** — yani bu göç
uygulamayı kırarsa sessizce 403 üretmek yerine kendisi patlıyor.

**Neden bu yaklaşım.** Kara liste (tek tek revoke) yazsaydım bir sonraki
fonksiyon yine açık gelirdi. Beyaz liste fail-closed.

**Değişen dosyalar.**
`supabase/migrations/20260901000400_function_execute_hygiene.sql`.

**Nasıl doğrulandı (yazıldı, çalıştırılmadı).**
`supabase/tests/098_function_grants.sql` — negatif: `send_push`,
`settle_past_leagues`, `assign_week_cohorts`, `handle_new_user`,
`touch_updated_at` `authenticated`'a kapalı; `set_osym_account` `anon`'a da
kapalı; doğrudan `select public.send_push(...)` 42501. Pozitif — ve bu yön
kritik: `can_read_mistake_photo` ve `are_friends` **açık kalmalı**, çünkü RLS
politikalarının içinden çağrılıyorlar ve politika ifadeleri çağıranın yetkisiyle
değerlendiriliyor; kapanırlarsa fotoğraflar ve arkadaşa soru gönderme tamamen
çöker.

---

### YENİ BULGU — `question_sends`'te alıcı gönderiyi tahrif edebiliyor

**Ne yapıldı.** `sends_update_receiver` politikası
`using/with check (auth.uid() = receiver_id)` — sütun kısıtı yok. Alıcı kendisine
gelen satırda `sender_id`, `mistake_id` ve `note`'u yeniden yazabiliyordu:
"falanca arkadaşım bana şu soruyu şu notla göndermiş" diye sahte kanıt
üretilebiliyordu. UPDATE yetkisi `solved_at` ve `correct` ile sınırlandı.

**Neden bu yaklaşım.** RLS bunu ifade edemez (politika sütun seçemez); sütun
ayrıcalığı tek satırda eder. Bu, kümenin kök nedeninin ders kitabı örneği.

**Değişen dosyalar.** `20260901000100_privilege_lockdown.sql`.

**Nasıl doğrulandı (yazıldı, çalıştırılmadı).**
`supabase/tests/085_question_sends.sql` — negatif: alıcı `sender_id` ve `note`
yazmaya kalkınca 42501. Pozitif: alıcı çözüldü işaretleyebiliyor; ilgisiz bir
kullanıcı gönderileri göremiyor (mevcut arkadaşlık RLS'i bozulmadı).

---

### A0 — test altyapısı (düzeltme değil, ön koşul)

**Ne yapıldı.** `supabase db reset` üç ayrı sebeple çalışmıyordu ve bu
gürültüsüz başarısız oluyordu:

1. Temel şema `migrations/` dışındaydı (`supabase/schema.sql`) — `profiles`,
   `mistakes`, `mistake_type` enum'u ve `mistake-photos` kovası hiç
   yaratılmıyordu, sonraki 24 göç boş bir veritabanına uygulanıyordu.
2. Supabase CLI `<14 haneli zaman damgası>_ad.sql` biçimi bekliyor;
   `0002_reviews.sql` gibi adlar **atlanıyor** ve CLI yine de 0 çıkış kodu
   döndürüyor.
3. `config.toml` `[db.seed]`'i açıp var olmayan `./seed.sql`'e işaret ediyordu.

Yapılanlar: 24 göç `git mv` ile zaman damgası biçimine alındı (sıra birebir
korundu), `schema.sql` → `20240101000000_init.sql` olarak en başa taşındı ve
idempotent hâle getirildi (SQL'in anlamı birebir korundu; yalnızca "varsa atla"
sarmalayıcıları eklendi), `supabase/schema.sql` yerinde bir işaretçi notu olarak
bırakıldı, `supabase/seed.sql` (pgTAP + `tests.*` yardımcıları) ve
`supabase/tests/` eklendi.

**Neden bu yaklaşım.** Yeniden adlandırma üretimi etkilemiyor — göçler zaten
elle SQL Editor'a yapıştırılarak uygulanıyor ve her dosyanın açıklayıcı başlığı
korundu. Bu adım olmadan pgTAP dosyaları hiçbir ortamda, CI'da bile
çalıştırılamazdı.

**Kritik ayrıntı — `tests.authenticate_as` `SECURITY INVOKER` olmak zorunda ve
`SET` yan tümcesi taşıyamaz.** Postgres her iki durumda da fonksiyona girişte
yeni bir GUC yuvası açıp çıkışta geri sarıyor; o durumda kimlik kurulumu
fonksiyon döner dönmez siliniyor ve **bütün "reddedilmeli" testleri `postgres`
olarak çalışıp geçiyor** — yeşil ama değersiz bir süit. Bu depodaki diğer her
fonksiyon `security definer` olduğu için yanlışlıkla eklenmesi çok kolay;
`seed.sql`'e uyarı yorumu kondu ve `000_setup_smoke.sql` bunu katalogdan
doğruluyor.

**Nasıl doğrulandı (yazıldı, çalıştırılmadı).**
`supabase/tests/000_setup_smoke.sql` — `authenticate_as`'in gerçekten
`auth.uid()`'yi değiştirdiğini, `current_user`'ın `authenticated` olduğunu ve
`prosecdef`/`proconfig`'in beklenen değerlerde olduğunu iddia ediyor.
**Bu dosya kırmızıysa diğer hiçbir teste güvenilmemeli.**

---

---

# Paket 2 — depolama katmanı

### H4 — fotoğraf yetkisi yanlış soruyu soruyor

**Ne yapıldı.** İki bağımsız katman.
**(1) Veri:** `mistakes` üzerinde `check (photo_path is null or photo_path like
user_id::text || '/%')` — bir satır artık kendi sahibinin klasörü dışını
gösteremez, yani gölge satır kurulamaz. Aynı kalıp `profiles.avatar_path` için de.
**(2) Yetki:** `can_read_mistake_photo` yeniden yazıldı; kilit taşı
`m.user_id::text = (storage.foldername(p_name))[1]` — erişim veren satır dosyanın
**sahibi olmak zorunda**.

**Neden bu yaklaşım.** Yalnızca fonksiyonu düzeltmek yetmezdi: veri katmanı hâlâ
yalan söyleyen satırlar kabul ederdi ve `admin_all_questions` / moderasyon kuyruğu
o satırdaki yolu moderatöre gösterip yanlış fotoğrafı incelettirirdi. Yalnızca
CHECK kısıtı da yetmezdi: kısıt ileride `not valid` yapılırsa ya da bir göç onu
düşürürse yetki kapısı da açılırdı. İkisi birbirinin yedeği.
**Reddedilen alternatif:** politikaya `with check` eklemek. `profiles`'ta bu bir
tuzak — `WITH CHECK`'i olmayan bir UPDATE politikasında `USING` yeni satır için
de uygulanıyor, `with check` eklediğim anda o örtük koruma kaybolur ve
`auth.uid() = id`'yi elle yeniden yazmam gerekirdi. CHECK kısıtı aynı garantiyi
daha güçlü veriyor (her role, `service_role` dahil) ve o tuzağa hiç girmiyor.

**Değişen dosyalar.** `supabase/migrations/20260901000500_photo_ownership.sql`.

**Nasıl doğrulandı (yazıldı, çalıştırılmadı).**
`supabase/tests/030_photo_ownership.sql`. En değerli kısmı "sahtecilik" bölümü:
CHECK kısıtını işlem içinde **geçici olarak düşürüp** gölge satırı zorla kuruyor
ve yetki fonksiyonunun kısıttan bağımsız olarak da `false` döndüğünü iddia ediyor
— iki katmanın gerçekten ayrı olduğunu böyle gösteriyor. Ayrıca gölge satırın
`is_public=true` olmasına rağmen fotoğrafı **üçüncü kişilere de açmadığını**
(eski kodun en kötü hâli) ve sahibinin kendi erişiminin bozulmadığını kontrol
ediyor. Uçtan uca depolama iddiaları `is_empty`/`isnt_empty` ile — reddedilen
SELECT hata fırlatmaz, sıfır satır döner.

**Ne değişmedi.** Yükleme akışı, yol şeması (`<uid>/<epoch_ms>.jpg`) ve içe
aktarıcının `<ownerId>/<source>/<dosya>` şeması — ikincisi kısıtla zaten uyumlu,
ilk segment yine sahibin kimliği.

---

### "Kaldırıldı" gerçekten kaldırmıyor

**Ne yapıldı.** Üç parça.
1. `can_read_mistake_photo` artık `moderation <> 'removed'` arıyor → kaldırılan
   içeriğe **yeni imzalı adres üretilemiyor**.
2. **init göçündeki `"Kendi fotolarını gör"` politikası kaldırıldı.** Bu,
   uygularken çıkan ve tek başına düzeltmeyi geçersiz kılan bir ayrıntıydı:
   o politika `"mistake photos readable"` ile **AYRI bir permissive SELECT
   politikasıydı** ve Postgres çoklu permissive politikaları OR'lar. Yani sahibi,
   `can_read_mistake_photo` ne derse desin kendi klasöründeki her şeyi
   okuyabiliyordu. O politika dururken Değişmez 3 sağlanamazdı.
3. Nesnenin kendisi siliniyor: moderatör kararı verdikten hemen sonra istemci
   dosyayı siliyor (`moderator can purge mistake photos` politikası),
   `photo_purged_at` iz bırakıyor, `admin_photo_purge_queue()` yarım kalanları
   listeliyor ve moderasyon ekranı açılışta **tekrar deniyor** + kalanları
   uyarı şeridinde gösteriyor.

**Neden bu yaklaşım.** Halihazırda dağıtılmış imzalı adresler ömürleri boyunca
çalışır (Supabase imzayı üretim anında doğrular, her istekte değil), o yüzden
politika düzeltmesi tek başına Değişmez 3'ü sağlamıyor — dosya silinmeli.
**Reddedilen alternatif:** veritabanından `pg_net` ile depolama API'sini çağıran
yeni bir Edge Function. Daha sağlam olurdu ama yeni bir servis rolü yüzeyi ve
yeni bir sessiz hata kaynağı açardı — H7 tam da bu kalıptan çıkmıştı.

**Değişen dosyalar.**
`supabase/migrations/20260901000600_moderation_purge.sql`,
`lib/data/moderation_repository.dart` (`purgePhoto`, `pendingPurges`),
`lib/features/admin/moderation_screen.dart` (karar sonrası temizlik + yeniden
deneme şeridi), `lib/features/admin/all_questions_screen.dart` ('hide' sonrası
temizlik; **'delete' öncesi** temizlik — satır silinince `photo_path` kaybolur ve
nesne bugünkü gibi yetim kalırdı).

**Nasıl doğrulandı (yazıldı, çalıştırılmadı).**
`supabase/tests/040_moderation_storage.sql` — `removed` sonrası yabancı **ve
sahibi** okuyamıyor (`is_public` hâlâ `true` olmasına rağmen; test bunu ayrıca
iddia ediyor), moderatör inceleme için okuyabiliyor, kuyruk yarım kalanı
listeliyor ve işaretlenince düşüyor, sıradan kullanıcı kuyruğu göremiyor.

**Ne değişmedi.** Moderasyon iş mantığı ve `is_public`'e dokunmama kararı
(`0012`'nin gerekçesi korundu: sahibinin paylaşım niyeti moderasyon kararından
ayrı tutuluyor).

**Artık risk, açıkça:** moderatörün istemcisi silme adımından önce çökerse nesne
kalır. O durumda yeni adres üretilemez ama eski adres ömrü dolana kadar çalışır.
Kuyruk + ekran açılışında yeniden deneme bunu kapatmaya çalışıyor; garanti değil.

---

### H5 — avatar kovası + gerçek silme (Değişmez 4)

**Ne yapıldı.** `avatars readable` politikası `using (bucket_id = 'avatars')`
idi — sahiplik/ilişki kontrolü yok, oturum açan herkes tüm kovayı listeleyip her
nesneye imzalı URL üretebiliyordu. Yerine `can_read_avatar(name)`: sahiplik yolun
kendisinden türetiliyor; başkasının dosyası ancak **profilde o an duran** avatarsa
ve aranızda ilişki varsa (arkadaş ya da bu haftaki lig grubu) okunabiliyor.

Gerçek silme: `removeAvatar` artık **önce sütunu boşaltıp sonra dosyayı siliyor**
ve silme başarısız olursa kullanıcıya söylüyor. `uploadAvatar` yeni dosyayı
yazdıktan sonra klasörü süpürüyor. Süpürme "önceki yolu hatırla" yerine
**klasörü tarayarak** çalışıyor, böylece geçmişte birikmiş artıklar da temizleniyor
(her avatar değişimi yeni zaman damgalı bir nesne yaratıyordu ve eskisi sonsuza
dek kalıyordu).

**Neden bu yaklaşım.** Eski kod `catch (_) { }` içinde yalnızca DB sütununu
null'lıyordu ve yorumu bunu açıkça kabul ediyordu ("dosyayı silmiyoruz"). Bir
silme işleminin sessizce hiçbir şey silmemesi KVKK Md. 7 / GDPR Md. 17 açısından
savunulabilir değil.

**Değişen dosyalar.**
`supabase/migrations/20260901000700_avatar_access.sql`,
`lib/data/social_repository.dart`, `lib/features/profile/profile_screen.dart`.

**Nasıl doğrulandı (yazıldı, çalıştırılmadı).**
`supabase/tests/050_avatars.sql` — yabancı ne güncel ne eski avatarı okuyabiliyor
ve **kovayı listeleyemiyor** (`count(*) = 0`), arkadaş güncel avatarı görüyor ama
eskisini göremiyor, sahibi kendi klasörünü listeleyebiliyor (süpürme buna
dayanıyor).

**Ne değişmedi.** Yükleme/güncelleme/silme politikaları (0024) — zaten kendi
klasörüyle sınırlıydılar.

---

### `profiles_public`'te avatar yolu sızıntısı — ve bir plan düzeltmesi

**Ne yapıldı.** `avatar_path` görünümde **kaldırılmadı, ilişkiye bağlandı**:
kendin ve kabul edilmiş arkadaşların için dolu, yabancılar için `null`.

**Neden plandan saptım.** Plan "kolonu tamamen çıkar" diyordu ve ben planda
"arkadaş listesi etkilenmez, avatarı `my_league_board`'dan alıyor" demiştim.
**Bu yanlıştı.** Uygularken kontrol ettim: `social_screen.dart:82` arkadaş
profillerini `profilesByIds` ile, yani tam da bu görünümden çekiyor. Kolonu
tümden çıkarmak arkadaş listesindeki ve profil kartlarındaki avatarları
söndürürdü — yani bir güvenlik düzeltmesi görünür bir ürün gerilemesi üretirdi.
Sizin amacınız "toplu döküm depolama yolu sızdırmasın" idi; ilişkiye bağlamak o
amacı aynen sağlıyor, gerilemeyi üretmiyor.

**Değişen dosyalar.** `supabase/migrations/20260901000700_avatar_access.sql`.
Kolon adı/sırası/tipi korundu, dolayısıyla `PublicProfile.fromRow`
(`lib/models/social.dart:180`) hiç değişmedi.

**Nasıl doğrulandı.** `050_avatars.sql` — yabancı için `null`, arkadaş ve kendisi
için dolu, görünümün diğer kolonları etkilenmemiş.

**Ne değişmedi.** Aramanın kendisi (`ilike '%q%'`, min 2 karakter, hız sınırı yok)
ve görünümün `authenticated`'a doğrudan açık olması. Dizinin toplu dökülebilirliği
**kapanmadı** — sizin kararınızla sosyal/UX pass'ine ertelendi. Artık dökülen
veride depolama yolu yok, o kadar.

---

### İmzalı adres ömrü 3600 s → 600 s (ve neden önce önbellek düzeltildi)

**Ne yapıldı.** Sıra sizin koyduğunuz gibi: **önce önbellek, sonra TTL.**
`social_repository`'deki avatar önbelleği artık **son kullanma zamanı** tutuyor
(eskiden URL'i süresiz saklıyordu, imza 1 saatte ölüyordu — yani bir saati aşan
oturumlarda avatarlar zaten sessizce kırılıyordu). `UserAvatar` ve `MistakePhoto`
görsel yüklenemediğinde **bir kez** yeniden imzalıyor (tek seferlik: kalıcı hatada
sonsuz istek döngüsü olmasın). Ancak bundan sonra TTL 600 s'ye indirildi.

**Neden 600 ve neden 300 değil.** Değişmez 3'ü asıl sağlayan şey nesnenin
silinmesi; TTL yalnızca silmeye kadarki pencere. 5 dakika, ekranı açık bırakan
kullanıcıyı gereksizce yeniden imzalamaya zorlardı; 10 dakika pencereyi 6 kat
daraltıyor ve retry'i nadir tutuyor.

**Değişen dosyalar.** `lib/data/social_repository.dart`,
`lib/data/mistake_repository.dart`, `lib/widgets/user_avatar.dart`,
`lib/widgets/mistake_photo.dart`.

**Ne değişmedi.** Havuz fotoğraflarının gösterim yolu.
Ek olarak `lib/data/question_pool_repository.dart`'taki **ölü** `signedUrl`
kopyası kaldırıldı: hiçbir yerden çağrılmıyordu ve aynı kova için ikinci bir
imzalama yolu olarak TTL değişince sessizce 3600'de kalırdı.

---

### Paket 2'de sessiz hataların kaldırıldığı yerler

Sütun kısıtı ve gerçek silme geldiği için, dokunduğum yazma yollarındaki çıplak
`catch (_)`'ler kaldırıldı ve hata kullanıcıya gösteriliyor:
`uploadAvatar` / `removeAvatar` artık `AvatarException` fırlatıyor,
`profile_screen` sebebi snackbar'da gösteriyor. Eskiden `uploadAvatar` `null`
dönüyordu ve "yükledim ama görünmüyor" durumunun sebebi hiçbir yerde yoktu.

**Kapsam sınırı:** yalnızca dokunduğum yollar. Depodaki diğer `catch (_)`'ler
(XP senkronu, tekrar zamanlaması, push token) Paket 3'e ve gözlemlenebilirlik
task'ına ait.

---

---

# Paket 3 — sunucu otoritesi ve onay defteri

### C3 — `xp` / `weekly_xp` / `streak` istemciden yazılıyor

**Ne yapıldı.** Puanlama tamamen sunucuya taşındı. Beş RPC eklendi
(`submit_pool_answer`, `submit_sent_answer`, `submit_review`,
`claim_daily_goal`, `set_question_sharing`) ve hepsi ortak bir
`apply_progress` üzerinden geçiyor. Ardından sütunlar kilitlendi: `profiles`
üzerinde istemcinin yazabildiği **tek sütun `avatar_path`** kaldı;
`nickname`/`mascot` `upsert_my_profile` RPC'sinden geçiyor.
`study_attempts` ve `question_attempts` INSERT'leri tamamen geri alındı,
`question_sends` UPDATE'i de öyle.

**Neden bu yaklaşım.** Alternatif — sütunları ayrı bir tabloya taşımak —
`profiles_public`, `my_league_board`, `settle_past_leagues`,
`sync_league_member_xp` ve tüm okuma yollarını yeniden yazmayı gerektirirdi.
Sütun ayrıcalıkları aynı garantiyi çok daha küçük bir hata yüzeyiyle veriyor.

Uygulamada dört tuzağa dikkat edildi: hiçbir RPC `user_id` parametresi almıyor
(definer fonksiyon RLS'i atladığı için o bir kimliğe bürünme primitifi olurdu);
`profiles` güncellemesi **tek bir UPDATE** (ikiye bölünse AFTER trigger'ları iki
kez çalışır ve `league_members.xp`'ye geçici bir `0` yazılırdı); satır
`for update` ile kilitleniyor (paralel çağrılar günlük tavanı aşmasın); ve
`week_start` doğru yazılıyor (`sync_league_member_xp` ona bakıyor).

**Değişen dosyalar.** `supabase/migrations/20260901000900_progress_rpcs.sql`,
`20260901001100_progress_lockdown.sql`, `lib/state/game_progress.dart`
(`_scheduleSync` silindi, `applyServerTotals` geldi),
`lib/data/social_repository.dart` (`syncStats` **silindi**, `ensureProfile`
RPC'ye geçti), `lib/data/progress_repository.dart`,
`lib/data/question_pool_repository.dart`, üç ekran.

**Nasıl doğrulandı (yazıldı, çalıştırılmadı).**
`supabase/tests/060_answers_xp.sql` — negatif: `xp` yazımı ve uydurma
`study_attempts` satırı 42501; `apply_progress` çağrılamıyor. Pozitif: doğru
cevap 10 XP veriyor, toplam sunucuda artıyor, seri 1 oluyor, ölçüm **sorunun
kendi konusuna** (ve ek konusuna) yazılıyor, aynı soru ikinci kez XP vermiyor.
`010` de güncellendi: artık `xp`/`nickname`/`updated_at`'in **kilitli**
olduğunu, tek yazılabilir sütunun `avatar_path` kaldığını iddia ediyor.

**Ne değişmedi.** Lig kohort mantığı, `settle_past_leagues`, tekrar
zamanlayıcısı (`ReviewScheduler`) ve `GameProgress`'in yerel seri mantığı —
sonuncusu bilerek: `registerActivity`/`addXp` artık yalnızca **iyimser** yerel
güncelleme, ve mevcut `streak_test.dart` bu sayede bozulmadan çalışıyor.

---

### `correct` / `correct_index` — tam sunucu otoritesi

**Ne yapıldı.** `correct_index` `public_questions` görünümünden **tamamen**,
`received_questions`'tan ise **yalnızca çözülmemiş** satırlar için çıkarıldı.
Doğru cevap artık `submit_*_answer` yanıtında dönüyor.

**Neden bu yaklaşım.** Sizin onayladığınız gibi: `correct`'i sunucuya taşımak
tek başına tiyatro olurdu, çünkü görünümler doğru şıkkın indeksini istemciye
zaten veriyordu. Saldırgan yalnızca doğru şıkkı göndermek zorunda kalırdı.

**Çözülmüş sorularda kolonu geri açtım** (`case when s.solved_at is not null
then m.correct_index end`) — çünkü "gelen sorular" ekranı daha önce çözülmüş bir
soruya dönüldüğünde doğru şıkkı gösteriyordu; kolonu tümden kaldırmak orada bir
gerileme olurdu. Güvenlik amacı korunuyor: cevabı **çözmeden önce** göremiyorsun.

**⚠️ Bu göç bölünemez.** `public_questions`, `random_public_questions` ve
`random_questions_by_topic`'in **dönüş tipi**; görünümü drop etmek onları da
düşürüyor. Üçü aynı göçte birlikte drop edilip birlikte yeniden yaratıldı, aynı
imzayla. (Depoda bu tuzağa iki kez düşülmüş — 0014/0015 ve 0016/0024.)

**Değişen dosyalar.** `supabase/migrations/20260901001000_hide_correct_index.sql`,
`lib/models/public_question.dart`, `lib/models/received_question.dart`,
`lib/features/pool/solve_pool_screen.dart`,
`lib/features/pool/received_questions_screen.dart`.

**Ne değişmedi.** `admin_pending_reports` ve `admin_all_questions` hâlâ
`correct_index` döndürüyor — moderatörün yanlış işaretlenmiş cevabı görüp
düzeltebilmesi gerekiyor ve o yüzey `is_admin()` ile korunuyor. Kullanıcının
KENDİ hatalarındaki `correct_index` de yerinde: kendi verisi.

---

### Çevrimdışı XP kaybı — planın kendi standardına uymayan yer

**Ne yapıldı.** `lib/data/submission_queue.dart`: kalıcı (SharedPreferences),
sıra koruyan, ilk hatada duran bir gönderim kuyruğu. `submit_review` ve
`claim_daily_goal` ağ hatasında kuyruğa alınıyor; uygulama açılışında
`home_shell` **`hydrate()`'ten ÖNCE** kuyruğu boşaltıyor.

**Neden bu yaklaşım.** Sizin yakaladığınız çelişki gerçekti: E3'te eski
istemcinin 403 alıp `catch (_)` ile yutmasını, sonra `hydrate()`'in eski değeri
geri yazmasını "sessiz veri kaybı" diye reddediyordum; risk #5'te aynı
mekanizmayı çevrimdışı kullanıcı için kabul ediyordum. Bir düzeltmenin kendi
yarattığı gerilemeyi "kapsam dışı" diye devretmek doğru değildi.

**Kuyruk EN AZ BİR KEZ semantiğiyle çalışıyor**, o yüzden tekrar gönderim
güvenli olmalı. Üç akış zaten idempotent (`question_attempts` PK,
`solved_at is null`, `daily_goal_date`); `submit_review` değildi, bu yüzden
istemcinin ürettiği tek seferlik `p_token` ve `submission_tokens` tablosu
eklendi — aynı anahtarla ikinci çağrı ölçümü ve XP'yi ikilemiyor.

**Kuyruk DÖRT akışı da kapsıyor** — `pool`, `sent`, `review`, `goal`.
İlk sürümde havuz ve gelen soruları dışarıda bırakmıştım; gerekçem "çevrimdışıyken
sonucu gösteremeyiz" idi. Bu doğru ama yetersiz bir gerekçeydi: sonucu
gösterememek, cevabın KAYBOLMASINDAN iyidir. Şimdi o iki akış da ağ hatasında
kuyruğa alınıyor ve kullanıcı "Bağlantı yok. Cevabın kaydedildi, sonucu bağlantı
gelince göreceksin." bilgisini alıyor.

Sunucunun REDDETTİĞİ çağrılar (`PostgrestException` — ör. "bu soru havuzda
değil") kuyruğa alınmıyor: tekrar denemek aynı sonucu verir, kuyruğa koymak
yalnızca sonsuz bir yeniden deneme üretirdi. Yalnızca ağ katmanı hataları
kuyruğa giriyor.

**Değişen dosyalar.** `lib/data/submission_queue.dart` (yeni), `pubspec.yaml`
(`shared_preferences` geçişli bağımlılıktan doğrudan bağımlılığa terfi —
`pubspec.lock`'ta zaten 2.5.5 olarak çözülmüştü),
`lib/features/home/home_shell.dart`, `lib/features/practice/practice_screen.dart`.

**Ne değişmedi.** Çevrimdışı OKUMA tarafı (soru listesi, önbellek stratejisi) —
o hâlâ kapsam dışı çevrimdışı task'ına ait.

---

### Onay defteri (Değişmez 7)

**Ne yapıldı.** `user_consents`: yalnızca ekleme yapılabilen, zaman damgalı
defter. `UPDATE` ve `DELETE` **hiçbir uygulama rolüne verilmiyor** — değiştirilemezliğin
tek gerçek garantisi bu. Yazma `record_consent` RPC'sinden, okuma `my_consents`
görünümünden. Kayıt anındaki veli onayı `handle_new_user` trigger'ıyla signUp
metadata'sından deftere geçiriliyor (o anda henüz oturum yok, istemci RPC
çağıramaz).

**Neden ayrı tablo — Küme A'da reddettiğim yaklaşım.** Orada sütun ayrıcalığı
yetiyordu. Burada gereksinim "değiştirilemez ve zaman damgalı", yani yapısal
olarak bir **defter**: bir sütunun tek bir güncel değeri olur, geçmişi olmaz.

**Değişen dosyalar.** `supabase/migrations/20260901001200_consent_ledger.sql`,
`lib/state/user_profile.dart` (`setShareConsent` artık auth metadata yerine
RPC'ye yazıyor; `loadConsents` eklendi ve `loadFromAuth` artık metadata'daki
`share_consent`'i **okumuyor**).

**Nasıl doğrulandı (yazıldı, çalıştırılmadı).**
`supabase/tests/065_consents.sql` — negatif: doğrudan INSERT/UPDATE/DELETE
kapalı, kullanıcı kendi kaydını bile değiştiremiyor (42501), başkasının
onayları görünmüyor. Pozitif: kayıt ekleniyor, zaman damgası dolu, geri alma
**yeni bir kayıt** olarak yazılıyor (defter geçmişi tutuyor, üstüne yazmıyor).

**Ne değişmedi — ve bu önemli.** Yaş kapısı tasarımı, `is_minor` mantığı ve
hukuki metinler kapsam dışı. Ayrıca `share_consent`'in `is_public`'i belirlemesi
hâlâ istemci tarafında: defter **onayın denetlenebilir kaydı**, paylaşımın
zorlayıcısı değil. Bunu "onay artık zorunlu tutuluyor" diye okumayın.

---

## Bağımsız denetim sonrası düzeltmeler (satır 19 ve 20)

Satır 19/20 kodunu yazdıktan sonra bağımsız bir denetime verdim, çünkü kendi
yazdığım koda karşı taraflıyım. Denetim **gerçek hatalar buldu** ve bunlardan
birkaçı benim ürettiğim gerilemelerdi. Hepsi düzeltildi:

**1. Kuyruk yalnızca soğuk açılışta boşalıyordu.** `flush()`'ın tek çağrı yeri
`_bootstrapSocial()` idi, o da yalnızca `initState`'ten çağrılıyordu. Metroda
çevrimdışı çözüp yukarı çıkan kullanıcı, uygulamayı kapatıp açana kadar hiçbir
cevabını gönderemiyordu — kuyruğun varlık sebebini boşa çıkaran bir boşluk.
Düzeltme: `AppLifecycleState.resumed` dalında boşaltma + her gönderimden önce
`drainIfPending()`. Yeni bağımlılık yok.

**2. Kalıcı bir ret kuyruğu SONSUZA DEK tıkıyordu.** `flush()` her hatada
`break` ediyor ve kaydı asla düşürmüyordu; `progress_repository` ise 42501 gibi
kalıcı retleri de kuyruğa alıyordu. Somut senaryo: kullanıcı çevrimdışıyken
kendi hatasını siler → `submit_review` 42501 döner → o kayıt kuyruğun başında
ölümsüzleşir → **arkasındaki bütün cevaplar da ölür**; tek çıkış oturum
kapatmak. Yani kuyruk, önlemek için yazıldığı kaybın daha kötüsünü üretiyordu.
Düzeltme: sunucu reddi → kaydı düşür ve devam et; ağ hatası → dur. Kalıcı retler
artık kuyruğa hiç alınmıyor.

**3. Çevrimdışı cevap KIRMIZI boyanıyordu.** `_revealedCorrect` null kaldığı
için seçilen şık "yanlış" dalına düşüyordu: uygulama "sonucu bağlantı gelince
göreceksin" derken cevabı yanlışmış gibi gösteriyordu. Artık nötr gösteriliyor.

**4. `enqueue` sessizce düşürebiliyordu.** Oturum düşmüşse kayıt atılıyor ama
arayüz yine "kaydedildi" diyordu. Artık `bool` dönüyor; alınamadıysa hata
kullanıcıya gösteriliyor.

**5. `mounted` kontrolü sunucunun gerçeğini atıyordu.** Kullanıcı pratik
ekranından çıkarsa dönen toplamlar uygulanmıyor, iyimser yerel XP düzeltilmeden
kalıyordu. `gameProgress` küresel bir tekil; kontrol kaldırıldı.

**6. `clear()` devam eden bir boşaltmayla yarışıyordu** (liste nesnesi
değiştiriliyordu) — artık yerinde temizleniyor. **`pendingCount` kaldırıldı:**
soğuk açılışta 0 döndürdüğü için göstergeye bağlanması tam da en gerekli anda
yanlış bilgi verirdi; yerine diskten okuyan `loadPendingCount()` var.

**7. Mutasyon geri almaları göç dosyalarına dayanıyordu — bu kırıktı.**
`04_admin_table.sql`'in restore'u `0026` idi. `0026` artık yeniden
çalıştırılamıyor (sonradan eklenen `xp_today`, `xp_today_date`,
`daily_goal_date`, `photo_purged_at` kolonları "sınıflandırılmamış kolon" hatası
veriyor), yani **eklediğim CI adımı olduğu gibi kırmızı olurdu.** Daha kötüsü:
çalışsaydı `xp`/`streak` grant'larını geri açacaktı — C3'ü yeniden açacaktı.
Artık her mutasyon kendi geri almasını `-- @UNDO` bölümünde taşıyor; göç
dosyaları geri alma olarak hiç kullanılmıyor.

**8. Mutasyon 01 iki korumayı birden bozuyordu** (03'ün üst kümesiydi); artık
yalnızca sahiplik kontrolünü kaldırıyor. **030'daki kısıt düşürme** `if exists`
aldı; yoksa mutasyon 02 ile birlikte işlem abort olup 14 iddiadan 13'ü hiç
çalışmıyordu.

### Denetimin bulduğu ama BU TURDA ÇÖZMEDİKLERİM

Sessizce bırakmıyorum, kayda geçiriyorum:

- **Tekrar ZAMANLAYICISI kuyruğa alınmıyor.** `mistakeRepository.submitReview`
  (SM-2: `step`, `next_review_date`, `lapses`) hatayı yutuyor. Çevrimdışı: XP ve
  ölçüm kuyruğa giriyor ama tekrar planı **kayboluyor** — bağlantı gelince kart
  hâlâ bugüne planlı görünüyor. Kuyruk dört *XP* akışını kapsıyor, tekrar
  planlayıcısını değil. Rapordaki "dört akışın hepsi" ifadesi bu anlamda dar
  okunmalı.
- **Aynı soru çevrimdışıyken iki kez cevaplanabiliyor** (deneme henüz sunucuya
  gitmediği için havuzdan elenmiyor). Havuzda zararsız (PK dedup); gönderilen
  soruda ikinci cevap `correct` alanını ezebiliyor.
- **Seri gün sınırı.** Çevrimdışı N. günde verilen cevap N+2'de boşalırsa
  aktivite N+2'ye yazılıyor; N gününde hak edilen seri kayboluyor.
- **`_send` zaman aşımı yok** — captive portal arkasında tek bir asılı RPC
  boşaltmayı süresiz bloklayabilir.
- **`enqueue`'nun 200 üstü kırpması** devam eden bir boşaltmanın listesini önden
  kesebilir (>200 bekleyen gerekir; düşük olasılıklı ama gerçek).
- **Havuz cevapları günlük tekrar sayacını ilerletmiyor** (bu değişiklikten önce
  de öyleydi).

## Kapsam dışında değiştirmek zorunda kaldıklarım

1. **24 göç dosyasının yeniden adlandırılması + `schema.sql`'in taşınması.**
   Plan onaylandı, yine de burada kayda geçiyorum: bu, güvenlik düzeltmesi değil
   test altyapısı ön koşuludur. `git mv` kullanıldığı için geçmiş korundu
   (24 rename olarak görünüyor). Üretime etkisi yok.
2. **`README.md`'ye "Veritabanı ve güvenlik testleri" bölümü.** Depoda Supabase
   yerel geliştirme, göç uygulama veya edge function dağıtımı hakkında **hiçbir
   dokümantasyon yoktu**. Testleri çalıştırmanız gerektiği için ekledim.
   README'nin geri kalanı ciddi ölçüde eskimiş (aşağıya bakın) — ona dokunmadım.
3. **`app_config` grant'larının geri alınması.** `push_lines` düzeltmesinin
   yanında, aynı satırda. RLS'i zaten vardı, davranış değişmiyor; savunma
   derinliği.
4. **`send_push`'a `raise warning` eklenmesi.** Gözlemlenebilirlik ayrı bir
   task ama bu düzeltme **yeni bir zorunlu yapılandırma anahtarı**
   (`push_service_key`) getiriyor; eksik olduğunda fonksiyon sessizce hiçbir şey
   yapmıyordu. Kendi yarattığım sessiz hatayı kapatmak için tek satır ekledim.
5. **Moderasyon ekranına temizlik şeridi** (Paket 2). Dosya silme adımı istemcide
   olduğu için yarım kalabiliyor; kuyruğu yazıp UI'sını yazmamak onu erişilemez
   bir RPC olarak bırakırdı. Ekran açılışında yeniden deneme + kalan sayısını
   gösteren bir şerit ekledim. UI işi, ama düzeltmenin kendisini gerçek kılan
   parça.
6. **`question_pool_repository.dart`'taki ölü `signedUrl` kaldırıldı** (Paket 2).
   Kapsam dışı temizlik gibi görünüyor ama TTL'i değiştirdiğim için aynı kova
   için ikinci bir imzalama yolunun sessizce eski değerde kalması gerçek bir
   tuzaktı.
7. **`pubspec.yaml`'a `shared_preferences` eklendi** (Paket 3). Yeni bağımlılık
   eklemek kapsam genişletmesidir; ama çevrimdışı kuyruk için kalıcı depolama
   şarttı ve paket `pubspec.lock`'ta zaten 2.5.5 olarak çözülmüş geçişli bir
   bağımlılıktı (supabase_flutter kullanıyor), yani yalnızca doğrudan
   bağımlılığa terfi etti. `flutter pub get` çözümü değiştirmemeli.
8. **`user_profile.loadFromAuth` artık `share_consent`'i metadata'dan okumuyor**
   (Paket 3). Onboarding/ayarlar akışına dokunmak istemiyordum ama onayın
   kaynağını deftere taşımak bunu zorunlu kıldı: iki kaynak bırakmak, hangisinin
   doğru olduğunu belirsiz bırakırdı.

---

## Bulduğum ama bu task'ta çözmediğim yeni şeyler

1. **`send_push` RPC yüzeyi** — çözüldü (yukarıda), ama denetim raporunda hiç
   yoktu. Raporun kendi uyarısını doğruluyor: politika/yetki hataları okumayla
   değil, ancak sistematik testle bulunuyor.
2. **`question_sends` alıcı tahrifi** — çözüldü (yukarıda), raporda yoktu.
3. **Sistem hesabı kimliğinin taklidi.** `nickname` serbest yazılabilir ve
   doğrulanmıyor; bir kullanıcı `nickname = 'ÖSYM Çıkmış Sorular'` yazarak
   (`0025`'in verdiği ad) hem aramada hem havuz künyesinde resmî hesap gibi
   görünebilir. **Çözülmedi** — Paket 3'teki `upsert_my_profile` RPC'sinde
   reddedilecek.
4. **`push_lines`'ta birincil anahtar ve CHECK kısıtı yok.** `kind`/`mascot`
   serbest metin; yazım hatası olan bir satır sessizce hiç seçilmez. Güvenlik
   sorunu değil, veri bütünlüğü.
5. **`0021_push` göçünde koşulsuz `delete from public.push_lines`.** Tek başına
   yeniden çalıştırılırsa `0023`'ün eklediği satırları da siler. `db reset`
   sırasıyla çalıştığı için etkisi yok; elle yeniden çalıştırmada var.
   Tarihsel göç dosyasına dokunmamayı tercih ettim.
6. **`README.md` büyük ölçüde gerçeğe aykırı.** "Backend şimdilik yok",
   Riverpod, drift, Freezed, SM-2 `easeFactor`, yanlış test yolları — hiçbiri
   koddaki durumu yansıtmıyor. P2 / kapsam dışı, dokunmadım.
7. **`analyze-question` fonksiyonunda kullanıcı başına hız sınırı yok** ve
   `mimeType` doğrulanmadan data URL'ine giriyor; OpenAI hataları istemciye
   olduğu gibi yansıtılıyor. Ücretli çağrı; kötüye kullanım maliyeti gerçek.
   Kapsam dışı (H7 yalnızca `send-push`'tı).
8. **`question_pool_repository.dart:126-127`** `42501`'i "Arkadaşlık onaylı değil"
   diye çeviriyor — sütun kilidi geldikten sonra bu mesaj yanıltıcı olabilir.
   Paket 3'te düzeltilecek (o pakette `question_sends` yazma yolu zaten
   değişiyor). Aynı dosyadaki ölü `signedUrl` Paket 2'de kaldırıldı.

**Paket 2'de çıkanlar:**

9. **`"Kendi fotolarını gör"` ikinci bir permissive SELECT politikasıydı.**
   Çoklu permissive politikalar OR'landığı için sahibi, `can_read_mistake_photo`
   ne derse desin kendi klasöründeki her şeyi okuyabiliyordu. Bu, "kaldırıldı
   gerçekten kaldırsın" düzeltmesini tek başına geçersiz kılardı — fonksiyona
   `moderation <> 'removed'` eklemek yetmezdi. **Çözüldü** (politika kaldırıldı,
   tek okuma otoritesi bırakıldı). Denetim raporunda yoktu.
10. **Planımdaki "arkadaş listesi etkilenmez" ifadesi yanlıştı.** Arkadaş listesi
    profilleri `profiles_public`'ten okuyor. Düzeltildi ve tasarım buna göre
    değiştirildi (yukarıda).
11. **`admin_question_action('delete')` nesneyi yetim bırakıyordu.** Satır
    silinince `photo_path` kayboluyor ve dosya sonsuza dek kalıyordu;
    `prune_orphans` yalnızca sistem hesabının klasörünü süpürüyor. **Çözüldü**
    (silme öncesi temizlik).

---

## Emin olmadıklarım / sizin karar vermeniz gerekenler

1. **Hiçbir şey çalıştırılmadı.** Yaptığım otomatik kontroller yalnızca
   biçimsel: dolar-tırnak ve parantez dengesi, pgTAP `plan(n)` sayısının gerçek
   iddia sayısıyla eşleşmesi, Dart için string/yorum/interpolasyon farkındalığı
   olan bir ayraç tarayıcısı, ve sütun beyaz listelerinin şemayla birebir
   örtüştüğünün karşılaştırılması. **Hiçbiri bir SQL ya da Dart ayrıştırması
   değil.** Bir sözdizimi hatası, yanlış bir `has_column_privilege` argümanı ya
   da beklenmedik bir katalog davranışı ilk gerçek çalıştırmaya kadar görünmez.

   Bu araçların güvenilirliği hakkında dürüst olmak gerekirse: yazdığım üç
   denetleyicinin **üçü de ilk sürümlerinde yanlış sonuç verdi** (iddia sayacı
   `isnt_empty`'yi kaçırdı, Dart tarayıcısı interpolasyondan sonra metne
   dönmüyordu, kullanılmayan-import tarayıcısı ise o kadar çok yanlış pozitif
   üretti ki tamamen attım ve yerine dokunduğum importları tek tek doğruladım).
   Yani buradaki "temiz" çıktılar, çalıştırılmış bir test yerine geçmez.
2. **`push_lines`'ın gerçek şiddeti hâlâ ölçülmedi.** Yukarıdaki `relacl`
   sorgusunun çıktısını bekliyorum. Şu an raporda "ortama bağlıydı" diyorum;
   ölçümle "dünyaya açıktı" ya da "zaten kapalıydı" diye netleştireceğim.
3. **Geri alma bloğu henüz gerçek değil.** Göç başlıklarına geri alma sorgusunu
   yazdım ama hedef ACL'i bilmediğim için "mevcut ACL'i geri yükleyin" diyor.
   `relacl` çıktısıyla bunu somut SQL'e çevireceğim.
4. **Trigger fonksiyonlarından `EXECUTE` geri almanın trigger'ları kırmadığını
   varsayıyorum.** PostgreSQL ayrıcalık kontrolünü trigger *oluşturma* anında
   yapar, *tetiklenme* anında değil — standart sertleştirme pratiği bu yönde.
   Ama bunu bu ortamda kanıtlayamadım. Eğer yanılıyorsam `handle_new_user`
   kullanıcı oluşturmayı, `touch_updated_at` her profil güncellemesini kırar.
   **İkisi de teste bağlandı**: `000` profil satırının oluştuğunu, `010`
   `updated_at`'in dolduğunu iddia ediyor. Yani bu belirsizlik ilk çalıştırmada
   kesin olarak çözülecek.
5. **PostgREST `upsert`'ünün hangi sütun ayrıcalıklarını istediğinden %100 emin
   değilim** (`ON CONFLICT DO UPDATE SET` listesine `id` dahil mi?). Savunmacı
   davrandım: `id` hem INSERT hem UPDATE listesinde. Zararsız — RLS `id`'yi
   zaten `auth.uid()`'ye sabitliyor. Paket 3'te `upsert_my_profile` RPC'si bu
   belirsizliği tamamen ortadan kaldıracak.
6. **`net` şeması erişimini kısıtladım** ama pg_net'in istek geçmişini ne kadar
   tuttuğunu ölçemedim. Servis jetonu artık `Authorization` başlığında gidiyor
   ve pg_net başlıkları kuyruk tablosunda saklıyor. Erişimi kapattım; saklama
   süresini siz kontrol etmek isteyebilirsiniz.
7. **Mutasyon kontrolü ARACI yazıldı ama yine çalıştırılmadı.**
   `tools/mutation_check.sh` + `supabase/tests/mutations/` (7 mutasyon) her
   korumayı tek tek bozup ilgili pgTAP dosyasının kırmızıya döndüğünü
   doğruluyor; CI'da `supabase test db`'den sonra çalışıyor. Yani artık bir
   ÖNERİ değil, çalıştırılabilir bir adım — ama bu makinede hâlâ koşturulmadı.
   Eski not, hâlâ geçerli olduğu için duruyor: "hem
   düzeltilmiş hem düzeltilmemiş şemada yeşil yanan" bir test olup olmadığını
   bilmiyorum. Testleri çalıştırdığınızda en azından `020`'deki
   `moderation='ok'` iddiasını, `095`'teki admin insert iddiasını ve
   `098`'deki `send_push` iddiasını düzeltmeyi geri alıp kırmızıya döndüğünü
   görerek doğrulamanızı öneriyorum.
8. **`is_public` hâlâ yazılabilir** ama artık zararsız: `can_read_mistake_photo`
   `moderation <> 'removed'` arıyor, yani `is_public=true` yazmak kaldırılmış bir
   sorunun fotoğrafını geri açmıyor (Paket 2). Sorunun havuz görünümüne dönmesi
   de `moderation='ok'` gerektiriyor, o da kilitli.

**Paket 2'ye ait olanlar:**

9. **`storage.objects` fikstürlerini gerçek bir şemaya karşı denemedim.**
   Testlerde `(bucket_id, name)` ile satır ekliyorum. Depolama şemasının bu
   sürümünde `path_tokens` üretilmiş bir kolon ve daha yeni sürümlerde `level`
   kolonu + `storage.prefixes` trigger'ları var. Insert hata verirse fikstürü
   çalışan kapsayıcıdaki `\d storage.objects` çıktısına göre düzeltmek gerekir.
   Bu, testlerin **yazılıp çalıştırılmamasının** doğrudan sonucu.
10. **`profiles_public` artık satır başına `are_friends` çağırıyor.** Sorgular
    küçük (`eq`, `inFilter` ~onlarca kimlik, arama `limit 20`) olduğu için maliyet
    ihmal edilebilir olmalı; ama plan sorgusu projeksiyonu sıralamadan ÖNCE
    uygularsa arama sorgusunda beklediğimden çok satır için değerlendirilebilir.
    Kullanıcı sayısı büyürse ölçülmeli.
11. **Kaldırma → dosya silme arası atomik değil.** Karar veritabanında, silme
    moderatörün oturumunda. Arada kopma olursa nesne kalır; kuyruk ve ekran
    açılışında yeniden deneme bunu kapatmaya çalışıyor ama **garanti değil.**
    Tam garanti sunucu tarafı bir temizleyici ister — bilinçli olarak almadım
    (yeni servis rolü yüzeyi). Karar sizin.
12. **`can_read_avatar`'ın lig-kohortu dalı test edilmedi.** Kohort fikstürü
    kurmak gerekiyordu; arkadaşlık ve yabancı dalları test edildi. Bu dal
    kırılırsa lig sıralamasında avatarlar maskota düşer (sessiz ürün gerilemesi,
    güvenlik sorunu değil).

**Paket 3'e ait olanlar:**

13. **Günlük XP tavanı (1500) tahmin.** `apply_progress` içindeki `c_day`
    gerçek kullanımdan kalibre edilmedi — elimde kullanım verisi yok. **Çok
    düşük olursa dürüst kullanıcıyı sessizce keser**, çok yüksek olursa
    kendi kendine raporlanan tekrar akışında sahteciliği yeterince
    sınırlamaz. 150 doğru cevap/gün üst sınır varsayımıyla seçildi; p99 günlük
    XP'nizi ölçüp güncelleyin.
14. **Günlük hedef bonusunda sunucu "hedef tamamlandı mı" sorusunu
    yanıtlayamıyor.** Hedef dinamik (o gün planı gelen tekrar sayısına göre
    değişiyor) ve sunucu tekrar planlayıcısının durumunu bilmiyor. Sunucunun
    garanti ettiği daha dar: **günde en fazla bir kez ve ancak gerçekten
    çalışıldıysa**. Kötüye kullanım tavanı 50 XP/gün.
15. **Anlaşmalı XP çiftçiliği tamamen kapanmadı.** Aynı soru aynı arkadaşa
    tekrar gönderilebiliyor (0022 bilinçli olarak unique kısıtını kaldırmıştı)
    ve her yeni gönderi ilk çözümünde 10 XP veriyor. Günlük tavan bunu
    sınırlıyor ama sıfırlamıyor. Kapatmak `question_attempts`'i gönderilen
    sorulara da yazmayı gerektirirdi; o da soruyu kullanıcının havuz akışından
    düşürürdü — davranış değişikliği olurdu, bilerek yapmadım.
16. **`shared_preferences` çözümünü doğrulayamadım.** `pubspec.lock` 2.5.5
    diyor ve paket zaten geçişli bağımlılıktı, ama `flutter pub get`
    çalıştıramadığım için kilidin gerçekten değişmediğini göremedim.
17. ~~Kuyruk oturum kapanınca temizlenmiyor.~~ **Yazarken fark edip düzelttim,
    kayda geçiriyorum:** ilk hâlinde bir cihazda A kullanıcısı çevrimdışı cevap
    verip çıkış yapsa, B giriş yaptığında kuyruk B'nin oturumuyla boşalacak ve
    A'nın cevapları **B'ye yazılacaktı**. İki katmanla kapatıldı: her kayda
    sahibinin kimliği yazılıyor ve boşaltırken yabancı kayıtlar atılıyor
    (`submission_queue.dart`), ayrıca çıkışta kuyruk temizleniyor
    (`auth_gate.dart`). İkinci katman tek başına yetmezdi — çıkış akışı
    çağrılmadan da (çökme, jeton süresi dolması) hesap değişebiliyor.

---

### CI — testlerin gerçekten çalıştığı yer

`.github/workflows/ci.yml` eklendi. Depoda **hiç CI yoktu**; bu ilk otomatik
kalite kapısı. Gerekçe doğrudan bu task'ın en büyük açığı: 203 iddia yazıldı ama
bu makinede çalıştırılamıyor, oysa CI koşucularında Docker var.

İki iş: `supabase start` + `db reset` + `test db`, ve ayrı bir işte
`flutter analyze` + `flutter test`.

İki ayrıntı bilinçli:
- **`db reset` çıktısında `skipped` araması ve varsa işi kırma.** Supabase CLI
  adı zaman damgası biçiminde olmayan göçleri sessizce atlıyor ve **yine de 0
  çıkış kodu döndürüyor** — o durumda testler boş bir veritabanına karşı yeşil
  yanar ve hiçbir şey kanıtlamaz. A0'ın yeniden adlandırması bunu bir kez
  çözdü; bu kontrol tekrar bozulmasını engelliyor.
- **`supabase start` `-x storage-api` OLMADAN.** `storage.objects` şeması o
  konteynerin kendi göçlerinden geliyor; hariç tutulursa 030/040/050 depolama
  testleri anlamsız bir şemaya karşı çalışır.

Ayrıca `git diff --exit-code pubspec.lock`: `shared_preferences` terfisinin
kilidi gerçekten değiştirmediğini burada göreceğiz (bu makinede
doğrulayamadığım şeylerden biri).

### Son kapılar

Son göç (`20260901001300`) üç şeyi birden doğruluyor ve tutmazsa **patlıyor**:
fonksiyon beyaz listesi, `public` şemasında RLS'siz tablo kalmaması (Değişmez 6)
ve yalnızca-sunucu tablolarında (`admins`, `app_config`, `push_lines`,
`submission_tokens`) uygulama rollerine yetki kalmaması. Sonuncusu ikinci bir
katman: ileride biri RLS'i kapatsa bile tablo grant yokluğundan kapalı kalır.

## Testleri çalıştırma

```bash
npm install supabase --save-dev     # Docker Desktop (WSL2) gerekir
npx supabase start                  # -x storage-api KULLANMAYIN
npx supabase db reset               # göçler + seed.sql
npx supabase test db                # supabase/tests/
```

`db reset` çıktısında **`skipped` satırı olmadığını doğrulayın.**

Paket 1 Dart tarafına hiç dokunmamıştı. Paket 2 ve 3 dokunuyor (toplam ~18
dosya, biri yeni bağımlılık), o yüzden artık şunlar şart:

```bash
flutter pub get && flutter analyze && flutter test
```

Mevcut 6 testin bozulmamış olması gerekiyor: `SendResult`, `ReviewScheduler`,
`League`, `TopicProgress`, `GameProgress` seri mantığı ve widget testi — hiçbiri
değiştirdiğim yollara dokunmuyor.

**Beklenen pgTAP toplamı: 203 iddia, 13 dosya.**

| Dosya | İddia |
|---|---|
| `000_setup_smoke` | 9 |
| `010_profiles_column_lockdown` | 28 |
| `020_mistakes_column_lockdown` | 25 |
| `030_photo_ownership` | 14 |
| `060_answers_xp` | 26 |
| `065_consents` | 13 |
| `040_moderation_storage` | 12 |
| `050_avatars` | 13 |
| `070_push_lines_rls` | 13 |
| `075_service_role_import` | 11 |
| `085_question_sends` | 12 |
| `095_admins` | 11 |
| `098_function_grants` | 16 |

`plan(n)` sayıları gerçek iddia sayılarıyla eşleşecek şekilde doğrulandı;
uyuşmazlık olursa TAP "Bad plan" der ve iş kırmızı olur.

### Mutasyon kontrolü — en çok bunu öneriyorum

Testler hiç çalıştırılmadığı için "hem düzeltilmiş hem düzeltilmemiş şemada
yeşil yanan" bir test olup olmadığını bilmiyorum. Bütçe tek bir şeye yeterse:

`supabase/tests/030_photo_ownership.sql` içindeki **"SAHTECİLİK"** iddiaları.
`20260901000500_photo_ownership.sql` göçünü geri alıp çalıştırın — kırmızı
olmalılar. Yeşil kalıyorlarsa test ayrım yapmıyor demektir ve H4 düzeltmesinin
kanıtı yok. Aynısı `040`'taki "KALDIRILDI" iddiaları ve `095`'teki admin insert
iddiası için de geçerli.
