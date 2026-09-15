-- 0096 — Fonksiyon yetkisi beyaz listesi (Task 13 kapısı)
--
-- 0087 ile aynı kapı, güncellenmiş listeyle. Task 13'ün SON kapısı ve bu
-- yüzden Task 13'ün BÜTÜN göçlerinden SONRA geliyor: kapı yalnızca kendi
-- çalışma anındaki kataloğu süzüyor, daha sonra yaratılan bir fonksiyon
-- "yeni fonksiyon PUBLIC'e açık doğar" kuralından hiç geçmez.
-- `tools/check_sql.py` bunu ayrıca denetliyor (3b).
--
-- LİSTEYE GİRENLER (Task 13):
--   istanbul_week → `istanbul_day()`in haftalık karşılığı. Görünümlerin
--       SELECT listesinden çağrılıyor, yani `authenticated` EXECUTE
--       edebilmeli. Sızdırdığı şey bir takvim tarihi.
--   subscription_state → `my_daily_state`in üçüncü kaynağı. Sıfır argümanlı ve
--       `auth.uid()`e kilitli; görünümün FROM listesinde olduğu için
--       `authenticated` EXECUTE edebilmeli.
--
-- LİSTEYE BİLEREK GİRMEYENLER (Task 13'te KAPATILANLAR):
--   set_question_sharing → havuz arayüzden çıktı (Task 02) ve `lib/` içinde
--       tek bir çağıranı yok. Sunucunun paylaşımı hâlâ kabul etmesi, Gizlilik
--       Politikası'nın "havuz şu an kullanımda değil" beyanıyla çelişiyordu.
--   submit_pool_answer → aynı gerekçe, ve dahası: doğru cevapta 10 XP + seri
--       veriyordu. `is_public` INSERT'i ile birlikte iki hesaplı bir XP/lig
--       şişirme yolu açıktı (K.K. §6'nın yasakladığı şey).
--   random_public_questions, random_questions_by_topic,
--   available_question_counts → havuz okuma yüzeyi. İstemcide sıfır çağıran.
--       Fonksiyonlar ve `question_attempts` YERİNDE kalıyor; havuz v2'de
--       dönerse geri açma tek göç (bkz. `lib/_archive/README.md`).
--
-- NOT: `apply_question_report` zaten listede DEĞİLDİ (havuz dönemi şikâyeti);
-- yürürlükteki şikâyet yolu `report_received_question` ve o listede kalıyor.
--
-- YALNIZCA-ANON: `grant_ad_reward` (0076), `refund_ai_use_infra` (0083) ve
-- `apply_subscription` (0092). Üçü de kullanıcı JWT'si TAŞIMAYAN bir mağaza /
-- ağ geri çağrısından besleniyor ve üçü de paylaşılan sırla yetkili.
-- `authenticated`'a açılmaları sırasıyla: bedava reklam hakkı, kota tavanının
-- kalkması, BEDAVA ABONELİK demek olurdu.
--
-- Bu dosyanın geri kalanı 0087'nin AYNISI. Kapılar kümülatif.

do $mig$
declare
  v_keep text[] := array[
    -- yetki / ilişki yardımcıları (POLİTİKA İÇİNDEN çağrılıyorlar: açık kalmalı)
    'is_admin',
    'are_friends',
    'can_read_mistake_photo',
    'can_read_avatar',
    'is_minor_now',
    'can_add_friends',
    'is_blocked_between',
    'is_suspended',
    'has_birth_year',
    'is_valid_topic',
    -- zaman yardimcilari (gorunumlerin SELECT listesinden cagriliyor)
    'istanbul_week',
    -- abonelik durum yuzeyi (my_daily_state'in kaynagi)
    'subscription_state',
    'my_curriculum',
    -- moderasyon
    'admin_pending_reports',
    'admin_all_questions',
    'admin_update_question',
    'admin_question_action',
    'moderate_report',
    'admin_photo_purge_queue',
    'admin_mark_photo_purged',
    'admin_flagged_photos',
    'admin_review_photo_scan',
    -- yaptırım (0062)
    'admin_user_sanctions',
    'admin_suspend_user',
    'my_sanction',
    'my_photo_warnings',
    'ack_photo_warnings',
    -- havuz (arayüzden çıkarıldı ama SQL yerinde; bkz. lib/_archive/README.md)
    -- lig
    'ensure_league_membership',
    'my_league_board',
    -- sosyal dizin (0068)
    'profiles_by_ids',
    'my_blocked_users',
    -- ilerleme
    'submit_sent_answer',
    'submit_review',
    'claim_daily_goal',
    'upsert_my_profile',
    -- onay defteri
    'record_consent',
    'accept_legal_terms',
    -- analiz hakkı / günlük durum (0040 → 0075)
    -- `daily_ai_quota` ve `istanbul_day_reset` 0075'te DÜŞÜRÜLDÜ; listede
    -- kalsalardı bu göç patlardı.
    'consume_ai_use',
    -- hak iadesi (0083)
    'refund_ai_use',
    'istanbul_day',
    'ai_state',
    -- özellik bayrakları (0079) — görünümün SELECT listesinde DOĞRUDAN
    -- çağrılıyor; `config_bool` BİLEREK listede değil.
    'feature_flags',
    -- ödüllü reklam (0076). `grant_ad_reward` burada DEĞİL — v_anon_only'de.
    'start_ad_reward',
    -- içerik taraması (0050)
    'consume_scan_use',
    -- yaş kapısı (0043 / 0063 / 0067)
    'set_birth_year',
    'my_age_status',
    'ai_age_ok',
    -- engelleme ve şikâyet (0044)
    'report_received_question',
    'dismiss_received_question',
    'block_user',
    'unblock_user',
    -- arkadaş kodu (0045)
    'add_friend_by_code',
    'rotate_friend_code',
    'mutual_friend_count',
    -- soru gönderme sarmalayıcısı (0081)
    'send_question_to_friends',
    -- ortak seri (0086) — `pair_streak_rollover` BİLEREK listede değil
    'my_pair_streaks',
    'start_pair_streak',
    'leave_pair_streak',
    -- persona metinleri (0055)
    'notification_lines',
    -- fotoğraf hash'i sonuç önbelleği (0060 / 0071)
    'ai_cache_get',
    'ai_cache_put',
    -- konu ağacı (0071)
    'tr_norm',
    'curriculum_tree',
    'resolve_topic_alias'
  ];
  r      record;
  v_miss text[];
begin
  for r in
    select p.oid::regprocedure as sig
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind = 'f'
       and p.proname <> all (v_keep)
       and not exists (
         select 1 from pg_depend d
          where d.objid = p.oid and d.deptype = 'e'
       )
  loop
    execute format(
      'revoke execute on function %s from public, anon, authenticated', r.sig);
  end loop;

  select array_agg(k) into v_miss
    from unnest(v_keep) k
   where not exists (
     select 1
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = k
        and has_function_privilege('authenticated', p.oid, 'EXECUTE')
   );

  if v_miss is not null then
    raise exception
      'Beyaz listedeki fonksiyon(lar) authenticated tarafından çağrılamıyor: % '
      '— bu göç uygulamayı kırardı', v_miss;
  end if;
end
$mig$;

-- ------------------------------------------------- yalnızca-anon fonksiyonlar
-- Yukarıdaki döngü v_keep dışındaki HER fonksiyonu `public, anon,
-- authenticated`tan revoke ediyor — yani 0076'nın `grant_ad_reward`a ve
-- 0083'ün `refund_ai_use_infra`ya verdiği anon yetkisini de aldı. Burası
-- onları geri veriyor ve gerçekten öyle olduğunu
-- İDDİA EDİYOR: yalnızca geri vermek, bir sonraki düzenlemede sessizce
-- düşmesine izin verirdi.
do $mig$
declare
  -- `refund_ai_use_infra` (0083) burada: TAVANSIZ iade yolu. Tavanlı yol
  -- (`refund_ai_use`) v_keep'te ve `authenticated`'a açık; tavansız olan
  -- ASLA açılamaz, yoksa istemci kendi kota tavanını kaldırırdı.
  v_anon_only text[] := array['grant_ad_reward', 'refund_ai_use_infra',
                              'apply_subscription'];
  r    record;
  v_bad text[];
begin
  for r in
    select p.oid::regprocedure as sig, p.proname
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind = 'f'
       and p.proname = any (v_anon_only)
  loop
    execute format('revoke execute on function %s from public, authenticated',
                   r.sig);
    execute format('grant execute on function %s to anon', r.sig);
  end loop;

  -- (a) anon çağırabiliyor mu?
  select array_agg(k) into v_bad
    from unnest(v_anon_only) k
   where not exists (
     select 1 from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = k
        and has_function_privilege('anon', p.oid, 'EXECUTE'));
  if v_bad is not null then
    raise exception
      'Yalnızca-anon fonksiyon(lar) anon tarafından çağrılamıyor: % — reklam '
      'ödülü geri çağrısı hiç çalışmazdı', v_bad;
  end if;

  -- (b) authenticated ÇAĞIRAMIYOR mu? Bu paketin en önemli tek iddiası:
  --     açık olsaydı istemci kendi reklam hakkını basar ve sunucu tarafı
  --     doğrulamanın tamamı dekora dönerdi.
  select array_agg(k) into v_bad
    from unnest(v_anon_only) k
   where exists (
     select 1 from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = k
        and has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  if v_bad is not null then
    raise exception
      'Yalnızca-anon fonksiyon(lar) authenticated tarafından ÇAĞRILABİLİYOR: '
      '% — istemci kendine reklam hakkı basabilir ya da kota tavanını '
      'kaldırabilir', v_bad;
  end if;
end
$mig$;

-- ------------------------------------------------- düşürülen kota fonksiyonları
-- 0075 `daily_ai_quota()` (gövdesi `select 5`) ve `istanbul_day_reset()`
-- fonksiyonlarını düşürdü: günlük sabit kota ve "yarın yenilenir" anı
-- kayan pencere rejiminde anlamsız.
--
-- Aynı gerekçe veli nesneleri bloğundakiyle aynı: `create or replace` içeren
-- eski bir göçün yeniden çalıştırılması onları SESSİZCE diriltirdi ve o anda
-- iki kota tanımı yan yana yaşardı — biri sabit 5, biri katmanlı.
do $mig$
declare v_bad text[];
begin
  select array_agg(p.proname order by p.proname) into v_bad
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('daily_ai_quota', 'istanbul_day_reset');

  if v_bad is not null then
    raise exception
      'Düşürülen kota fonksiyon(lar)ı geri gelmiş: % — 0075 rejimiyle '
      'çelişiyor', v_bad;
  end if;
end
$mig$;

-- ------------------------------------------------------- premium sütunu kapısı
-- Kota rejiminin tamamı `profiles.premium_until` sütununa dayanıyor: yazılabilir
-- olsaydı kullanıcı kendini premium yapıp 50/8sa + 1.000/ay alırdı.
--
-- `my_daily_state` de burada sınanıyor çünkü `create or replace view`
-- grant'ları KORUYOR — görünümü yeniden tanımlayan sonraki bir göç eski bir
-- `grant select to anon`ı farkında olmadan diriltebilir (`profiles_public`
-- kapısının aynı gerekçesi).
do $mig$
begin
  if has_column_privilege('authenticated', 'public.profiles', 'premium_until',
                          'UPDATE')
     or has_column_privilege('authenticated', 'public.profiles',
                             'premium_until', 'INSERT') then
    raise exception
      'profiles.premium_until istemciye yazılabilir — kullanıcı kendini '
      'premium yapabilir';
  end if;

  if has_table_privilege('anon', 'public.my_daily_state', 'SELECT') then
    raise exception 'my_daily_state anon tarafından okunabiliyor';
  end if;

  if not has_table_privilege('authenticated', 'public.my_daily_state',
                             'SELECT') then
    raise exception
      'my_daily_state authenticated tarafından OKUNAMIYOR — HUD tamamen boş '
      'kalırdı';
  end if;
end
$mig$;

-- ---------------------------------------------------- kaldırılan veli nesneleri
-- 0063 dört fonksiyonu, bir tabloyu ve bir sütunu düşürdü. Bu blok geri
-- gelmediklerini göç zamanında kanıtlıyor: `create or replace` içeren eski bir
-- göçün yanlışlıkla yeniden çalıştırılması ölü akışı sessizce diriltirdi.
do $mig$
declare v_bad text[];
begin
  select array_agg(p.proname order by p.proname) into v_bad
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('request_guardian_consent', 'confirm_guardian_consent',
                       'send_guardian_email', 'my_guardian_status');
  if v_bad is not null then
    raise exception 'Veli onayı fonksiyonları geri gelmiş: %', v_bad;
  end if;

  if to_regclass('public.guardian_requests') is not null then
    raise exception 'public.guardian_requests geri gelmiş';
  end if;

  if exists (
    select 1 from pg_attribute a
     where a.attrelid = 'public.profiles'::regclass
       and a.attname = 'guardian_email'
       and not a.attisdropped
  ) then
    raise exception 'profiles.guardian_email geri gelmiş';
  end if;
end
$mig$;

-- ------------------------------------------------------- düşürülen ölü sütunlar
-- 0069'un düşürdükleri. Aynı gerekçe: eski bir göç yeniden çalıştırılırsa
-- `add column if not exists` sütunu sessizce geri getirir ve lockdown listesi
-- onu tanımadığı için bir sonraki lockdown göçü patlar — hata o zaman değil,
-- AYLAR SONRA görünür.
do $mig$
declare
  v_dead text[][] := array[
    array['profiles', 'exam_track'],
    array['profiles', 'grade'],
    array['profiles', 'display_name'],
    array['mistakes', 'correct_answer'],
    array['mistakes', 'review_count']
  ];
  i     int;
  v_bad text[];
begin
  for i in 1 .. array_length(v_dead, 1) loop
    if exists (
      select 1 from pg_attribute a
       where a.attrelid = ('public.' || v_dead[i][1])::regclass
         and a.attname = v_dead[i][2]
         and not a.attisdropped
    ) then
      v_bad := coalesce(v_bad, array[]::text[]) || (v_dead[i][1] || '.' || v_dead[i][2]);
    end if;
  end loop;

  if v_bad is not null then
    raise exception 'Ölü sütun(lar) geri gelmiş: %', v_bad;
  end if;
end
$mig$;

-- ------------------------------------------------------- konu ağacı kapısı
-- Tohum (0072) ÜRETİLEN bir dosya. Yeniden üretilirken bozulur ya da elle
-- düzenlenip bozulursa göç sessizce boş bir ağaçla tamamlanır ve hata ancak
-- kullanıcı konu seçemediğinde görülür. Kapı bunu göç zamanına çekiyor.
do $mig$
declare
  v_topics int;
  v_ver    text;
begin
  select count(*) into v_topics from public.curriculum_topics;
  select version into v_ver from public.curriculum_meta;

  if v_topics = 0 then
    raise exception 'Konu ağacı BOŞ — tohum göçü (0072) çalışmamış';
  end if;
  if v_ver is null or v_ver = '' then
    raise exception 'Konu ağacı sürümü yazılmamış';
  end if;

  -- Her (müfredat, sınav) hücresinde en az bir ders olmalı. Biri boşalırsa o
  -- kullanıcı grubu hiç konu seçemez ve bunu ancak onlar fark eder
  -- (240_persona'nın "boşluk yok" iddiasının aynı gerekçesi).
  if exists (
    select 1
      from unnest(array['eski', 'maarif']) c
      cross join unnest(array['TYT', 'AYT']) e
     where not exists (
       select 1 from public.curriculum_topics t
        where t.curriculum = c and t.exam = e
     )
  ) then
    raise exception 'Konu ağacında boş (müfredat, sınav) hücresi var';
  end if;

  -- Her etiket gerçek bir konuya işaret etmeli: tohum yeniden üretilirken
  -- bir konu silinip etiketi kalırsa seçici var olmayan bir konuyu önerir.
  if exists (
    select 1 from public.curriculum_aliases a
     where not exists (
       select 1 from public.curriculum_topics t
        where t.curriculum = a.curriculum and t.exam = a.exam
          and t.subject = a.subject and t.topic = a.topic
     )
  ) then
    raise exception 'Öksüz etiket: var olmayan bir konuya işaret ediyor';
  end if;
end
$mig$;

-- ------------------------------------------------------------ dizin kapısı
-- 0068 `profiles_public`i istemciye kapattı. Bu blok kapının açık kalmadığını
-- göç zamanında kanıtlıyor: `create or replace view` grant'ları KORUYOR, yani
-- görünümü yeniden tanımlayan sonraki bir göç eski `grant select`i farkında
-- olmadan diriltebilir.
do $mig$
begin
  if has_table_privilege('authenticated', 'public.profiles_public', 'SELECT')
     or has_table_privilege('anon', 'public.profiles_public', 'SELECT') then
    raise exception
      'profiles_public hâlâ doğrudan okunabiliyor — dizin dökülebilirliği açık';
  end if;
end
$mig$;
-- ------------------------------------------------------------------ RLS kapısı
-- Değişmez 6: public şemadaki her tabloda RLS açık.
do $mig$
declare v_bad text[];
begin
  select array_agg(c.relname order by c.relname) into v_bad
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relkind = 'r'
     and not c.relrowsecurity;

  if v_bad is not null then
    raise exception 'RLS açık olmayan public tablo(lar): % — Değişmez 6 ihlali', v_bad;
  end if;
end
$mig$;

-- ----------------------------------------------------------- cascade kapısı
-- 0048'in kapısı KENDİ çalıştığı andaki katalogla karşılaştırma yapıyor: daha
-- sonra eklenen bir tablo o kontrolden HİÇ geçmiyor. `user_sanctions` ve
-- `photo_violations` kullanıcıya ait veri tutuyor; hesap silmede geride satır
-- bırakırlarsa "hesabınız ve ona bağlı tüm kayıtlar silinir" beyanı yanlış
-- olurdu (Gizlilik Politikası §8, hesap silme sayfası).
do $mig$
declare
  -- Task 10: `ai_calls` ve `ad_rewards` da kullanıcıya ait veri tutuyor;
  -- hesap silmede geride satır bırakırlarsa "hesabınız ve ona bağlı tüm
  -- kayıtlar silinir" beyanı yanlış olurdu.
  v_owned text[] := array['user_sanctions', 'photo_violations',
                          'ai_calls', 'ad_rewards', 'subscriptions'];
  v_bad   text[];
begin
  -- (a) auth.users'a bakan her anahtar cascade mi?
  select array_agg(format('%s (%s)', c.relname, con.conname) order by c.relname)
    into v_bad
    from pg_constraint con
    join pg_class c      on c.oid = con.conrelid
    join pg_namespace n  on n.oid = c.relnamespace
    join pg_class rc     on rc.oid = con.confrelid
    join pg_namespace rn on rn.oid = rc.relnamespace
   where con.contype = 'f'
     and n.nspname = 'public'
     and rn.nspname = 'auth'
     and rc.relname = 'users'
     and c.relname = any (v_owned)
     -- SAHİPLİK sütunu üzerinden süzülüyor, kısıt ADINA göre değil: ad
     -- otomatik üretiliyor ve elle değiştirilebilir.
     --
     -- `actor_id` BİLEREK dışarıda: o sütun kaydın sahibini değil, yaptırımı
     -- VEREN yöneticiyi gösteriyor ve `on delete set null`. Yönetici kendi
     -- hesabını silse bile başkası hakkındaki karar defterde kalmalı;
     -- cascade olsaydı bir yöneticinin ayrılması sicilleri silerdi.
     and (select a.attname from pg_attribute a
           where a.attrelid = con.conrelid
             and a.attnum = con.conkey[1]) = 'user_id'
     and con.confdeltype <> 'c';

  if v_bad is not null then
    raise exception
      'auth.users''a cascade OLMAYAN yabancı anahtar(lar): % — hesap silme '
      'bu tablolarda satır bırakır', v_bad;
  end if;

  -- (b) bağ gerçekten var mı? (user_id sütununu FK'siz eklemek (a)'yı atlatır)
  select array_agg(t order by t) into v_bad
    from unnest(v_owned) t
   where not exists (
     select 1
       from pg_constraint con
       join pg_class c      on c.oid = con.conrelid
       join pg_namespace n  on n.oid = c.relnamespace
       join pg_class rc     on rc.oid = con.confrelid
       join pg_namespace rn on rn.oid = rc.relnamespace
      where con.contype = 'f'
        and n.nspname = 'public'
        and c.relname = t
        and rn.nspname = 'auth'
        and rc.relname = 'users'
   );

  if v_bad is not null then
    raise exception
      'auth.users''a hiç bağı olmayan kullanıcı tablosu/tabloları: %', v_bad;
  end if;
end
$mig$;

-- ------------------------------------------------- yalnızca-sunucu tabloları
do $mig$
declare
  v_server_only text[] := array[
    'admins', 'app_config', 'push_lines', 'submission_tokens',
    'rate_limits',
    -- persona metin altyapısı (0055): başlık tablosu ve anti-tekrar imleci
    'push_kinds', 'push_cursors',
    -- kayıt hız sınırı (0058): IP hash'leri hiçbir uygulama rolüne açılmaz
    'signup_throttle',
    -- sonuç önbelleği (0060): TTL kararını fonksiyon veriyor, tablo kapalı
    'ai_result_cache',
    -- ortak seri (0086): okuma `my_pair_streaks()`ten; tabloya yazmak
    -- kullanıcının kendi serisini şişirmesi demekti
    'pair_streaks',
    -- yaptırım defterleri (0062): kullanıcı kendi sicilini ne okur ne yazar;
    -- okuma my_sanction() / my_photo_warnings() üzerinden, süzülmüş hâlde
    'user_sanctions', 'photo_violations',
    -- konu ağacı (0071): herkes için aynı ve statik, yani satır düzeyi bir
    -- kural yok. Açık bir tablo yalnızca sürüm pazarlığını ve gruplamayı
    -- istemciye bırakırdı; okuma curriculum_tree() üzerinden tek turda.
    'curriculum_topics', 'curriculum_aliases', 'curriculum_meta',
    -- kota defteri ve reklam ödülleri (0075): sayılar my_daily_state'ten
    -- geliyor; defterin kendisi kullanıcıya bile okunabilir olmamalı.
    -- `ad_rewards.status` yazılabilse istemci reklamı izlemeden hak kazanırdı.
    'ai_calls', 'ad_rewards'
  , 'subscriptions'];
  v_bad text[];
begin
  select array_agg(t) into v_bad
    from unnest(v_server_only) t
   where has_table_privilege('authenticated', 'public.' || t, 'SELECT')
      or has_table_privilege('authenticated', 'public.' || t, 'INSERT')
      or has_table_privilege('anon',          'public.' || t, 'SELECT');

  if v_bad is not null then
    raise exception
      'Yalnızca-sunucu tablolarında hâlâ uygulama yetkisi var: %', v_bad;
  end if;
end
$mig$;

-- ------------------------------------------------------- bayrak sütunu kapısı
-- `my_daily_state` bu depoda ÜÇ KEZ yeniden tanımlandı (0040 → 0048 → 0075 →
-- 0079) ve 0075 iki sütunu (`ai_quota`, `ai_resets_at`) BİLEREK düşürdü. Aynı
-- şey bayraklara kazayla olursa istemci `null` okur, `Features` yedeğine düşer
-- ve UZAKTAN KAPATMA SESSİZCE ÖLÜR — yani kill switch'in kendisi kaybolur ve
-- kimse fark etmez. Kapı o yüzden burada: görünümü yeniden kuran sonraki göç
-- bu üç sütunu taşımak zorunda.
do $mig$
declare
  v_want text[] := array['ff_pair_streak', 'ff_multi_capture',
                         'ff_ad_reward', 'ff_iap'];
  v_miss text[];
begin
  select array_agg(w) into v_miss
    from unnest(v_want) w
   where not exists (
     select 1
       from pg_attribute a
       join pg_class c on c.oid = a.attrelid
       join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = 'my_daily_state'
        and a.attname = w
        and a.attnum > 0
        and not a.attisdropped
   );

  if v_miss is not null then
    raise exception
      'my_daily_state bayrak sütun(lar)ını kaybetti: % — görünümü yeniden '
      'kuran göç onları taşımak zorunda, yoksa uzaktan kapatma sessizce ölür',
      v_miss;
  end if;
end
$mig$;

-- ----------------------------------------------- ortak seri cascade kapısı
-- `v_owned` kontrolü SAHİPLİK sütununu `user_id` adıyla arıyor; ikili seride
-- öyle bir sütun yok (`a_id`/`b_id`). Kapı bu yüzden ayrı yazıldı.
--
-- NEDEN ÖNEMLİ: Gizlilik Politikası §8 "hesabınız ve ona bağlı tüm kayıtlar
-- silinir" diyor. İki bağdan biri cascade olmasa, silinen kullanıcının ikili
-- serisi karşı tarafın listesinde yetim bir satır olarak kalırdı —
-- `0050_cascade_audit`'in kapatmak için var olduğu hata sınıfı.
do $mig$
declare
  v_bad text[];
begin
  select array_agg(format('%s (%s)', a.attname, con.conname) order by a.attname)
    into v_bad
    from pg_constraint con
    join pg_class c      on c.oid = con.conrelid
    join pg_namespace n  on n.oid = c.relnamespace
    join pg_class rc     on rc.oid = con.confrelid
    join pg_namespace rn on rn.oid = rc.relnamespace
    join pg_attribute a  on a.attrelid = con.conrelid
                        and a.attnum = con.conkey[1]
   where con.contype = 'f'
     and n.nspname  = 'public'
     and c.relname  = 'pair_streaks'
     and rn.nspname = 'auth'
     and rc.relname = 'users'
     and con.confdeltype <> 'c';

  if v_bad is not null then
    raise exception
      'pair_streaks üzerindeki şu bağ(lar) CASCADE değil: % — hesap silinince '
      'karşı tarafın listesinde yetim satır kalır', v_bad;
  end if;

  -- POZİTİF İDDİA: iki bağ da GERÇEKTEN var. Yalnızca "cascade olmayan yok"
  -- demek, bağların hiç olmaması hâlinde de yeşil yanardı.
  select array_agg(t) into v_bad
    from unnest(array['a_id', 'b_id']) t
   where not exists (
     select 1
       from pg_constraint con
       join pg_class c      on c.oid = con.conrelid
       join pg_namespace n  on n.oid = c.relnamespace
       join pg_class rc     on rc.oid = con.confrelid
       join pg_namespace rn on rn.oid = rc.relnamespace
       join pg_attribute a  on a.attrelid = con.conrelid
                           and a.attnum = con.conkey[1]
      where con.contype = 'f'
        and n.nspname  = 'public'
        and c.relname  = 'pair_streaks'
        and rn.nspname = 'auth'
        and rc.relname = 'users'
        and a.attname  = t
   );

  if v_bad is not null then
    raise exception
      'pair_streaks üzerinde auth.users bağı YOK: %', v_bad;
  end if;
end
$mig$;
