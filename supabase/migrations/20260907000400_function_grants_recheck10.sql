-- 0074 — Fonksiyon yetkisi beyaz listesi (Task 09 kapısı)
--
-- 0029, 0033, 0038, 0049, 0054, 0056, 0061, 0065 ve 0070 ile aynı kapı,
-- güncellenmiş listeyle. Postgres her YENİ fonksiyonda EXECUTE'u tekrar
-- PUBLIC'e verdiği için bu kontrol her paketin sonunda tekrarlanıyor.
--
-- Task 09'un eklediği çağrılabilir fonksiyonlar:
--   tr_norm            → `curriculum_aliases.alias_norm` ÜRETİLMİŞ SÜTUNU
--       bunun üstünde duruyor; `immutable` ve açık olmak zorunda.
--   curriculum_tree    → istemcinin ağacı çektiği tek kapı (sürüm pazarlıklı).
--   is_valid_topic     → `mistakes` doğrulama TETİKLEYİCİSİNDEN çağrılıyor,
--       yani açık olmak ZORUNDA; kapalı olsaydı her INSERT kırılırdı
--       (is_suspended'ın aynı gerekçesi, 0052'nin dersi).
--   resolve_topic_alias→ eski ad/etiket çözümü (içe aktarma, tohum remap'i).
--   my_curriculum      → `mistakes.curriculum` varsayılanı.
--
-- İMZASI DEĞİŞENLER: `ai_cache_get` ve `ai_cache_put` taksonomi sürümünü
-- anahtara aldı (0071). Eski imzalar `drop` edildi; listede AD ile
-- tutulduğu için beyaz liste değişmiyor.

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
    'random_public_questions',
    'random_questions_by_topic',
    'available_question_counts',
    -- lig
    'ensure_league_membership',
    'my_league_board',
    -- sosyal dizin (0068)
    'profiles_by_ids',
    'my_blocked_users',
    -- ilerleme
    'submit_pool_answer',
    'submit_sent_answer',
    'submit_review',
    'claim_daily_goal',
    'set_question_sharing',
    'upsert_my_profile',
    -- onay defteri
    'record_consent',
    'accept_legal_terms',
    -- can / günlük durum (0040)
    'consume_ai_use',
    'daily_ai_quota',
    'istanbul_day',
    'istanbul_day_reset',
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
  v_owned text[] := array['user_sanctions', 'photo_violations'];
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
    -- yaptırım defterleri (0062): kullanıcı kendi sicilini ne okur ne yazar;
    -- okuma my_sanction() / my_photo_warnings() üzerinden, süzülmüş hâlde
    'user_sanctions', 'photo_violations',
    -- konu ağacı (0071): herkes için aynı ve statik, yani satır düzeyi bir
    -- kural yok. Açık bir tablo yalnızca sürüm pazarlığını ve gruplamayı
    -- istemciye bırakırdı; okuma curriculum_tree() üzerinden tek turda.
    'curriculum_topics', 'curriculum_aliases', 'curriculum_meta'
  ];
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
