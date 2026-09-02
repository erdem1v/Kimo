-- 0049 — Fonksiyon yetkisi beyaz listesi (Task 02 kapısı)
--
-- 0029, 0033 ve 0038 ile aynı kapı, güncellenmiş listeyle. Postgres her YENİ
-- fonksiyonda EXECUTE'u tekrar PUBLIC'e verdiği için bu kontrol her paketin
-- sonunda tekrarlanıyor. Task 02 on dört yeni çağrılabilir fonksiyon ekledi.
--
-- LİSTEDE OLMAYANLAR BİLEREK KAPALI — hepsi yalnızca başka definer
-- fonksiyonlar tarafından çağrılıyor ve onlar postgres olarak çalıştığı için
-- EXECUTE'a ihtiyaç duymuyorlar:
--   apply_progress          → doğrudan çağrılabilseydi keyfi XP yazma primitifi
--   bump_rate_limit         → kullanıcı kendi sayacını manipüle edebilirdi
--   generate/assign_friend_code, normalize_friend_code
--   send_guardian_email     → keyfi adrese e-posta gönderme primitifi
--   confirm_guardian_consent→ token'ı bilen herkes zaten edge fonksiyondan
--                             geçiyor; RPC olarak açılması gereksiz yüzey
--   stale_anonymous_users   → yalnızca temizlik işi
--   sync_anonymous_flag, handle_new_user, touch_updated_at → tetikleyiciler
--   settle_past_leagues, assign_week_cohorts, league_cohort_size
--   league_rank, league_label, daily_chest_gems
--   send_push, set_osym_account

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
    -- moderasyon
    'admin_pending_reports',
    'admin_all_questions',
    'admin_update_question',
    'admin_question_action',
    'moderate_report',
    'admin_photo_purge_queue',
    'admin_mark_photo_purged',
    -- havuz (arayüzden çıkarıldı ama SQL yerinde; bkz. lib/_archive/README.md)
    'random_public_questions',
    'random_questions_by_topic',
    'available_question_counts',
    -- lig
    'ensure_league_membership',
    'my_league_board',
    -- ilerleme
    'submit_pool_answer',
    'submit_sent_answer',
    'submit_review',
    'claim_daily_goal',
    'set_question_sharing',
    'upsert_my_profile',
    -- onay defteri
    'record_consent',
    -- can / günlük durum (0040) — üçü `my_daily_state` görünümünün SELECT
    -- listesinden çağrılıyor, EXECUTE çağırana karşı denetleniyor
    'consume_ai_use',
    'daily_ai_quota',
    'istanbul_day',
    'istanbul_day_reset',
    -- yaş kapısı ve veli onayı (0043)
    'set_birth_year',
    'request_guardian_consent',
    'my_guardian_status',
    -- engelleme ve şikâyet (0044)
    'report_received_question',
    -- 3n'deki "Sil": alıcı gelen soruyu kutusundan kaldırır (0051).
    'dismiss_received_question',
    'block_user',
    'unblock_user',
    -- arkadaş kodu (0045)
    'add_friend_by_code',
    'rotate_friend_code',
    'mutual_friend_count'
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

-- ------------------------------------------------------------------ RLS kapısı
-- Değişmez 6. Task 02 üç tablo ekledi (rate_limits, guardian_requests,
-- user_blocks); üçünde de RLS açık olmalı.
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

-- ------------------------------------------------- yalnızca-sunucu tabloları
-- Politikasız RLS zaten erişimi kapatıyor; grant'ların da geri alınmış olduğunu
-- ayrıca doğruluyoruz (iki bağımsız katman). Task 02 listeye iki tablo ekledi.
do $mig$
declare
  v_server_only text[] := array[
    'admins', 'app_config', 'push_lines', 'submission_tokens',
    'rate_limits', 'guardian_requests'
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

-- ------------------------------------------------------------- ölü sütun kapısı
-- Task 02 üç ölü sütun düşürdü. Geri gelirlerse (ör. eski bir göç yeniden
-- uygulanırsa) sessizce "varmış gibi duran ama çalışmayan" mekanikler geri
-- döner; bu kapı onu yakalar.
do $mig$
declare
  v_dead text[] := array['hearts', 'is_minor', 'guardian_consent'];
  v_bad  text[];
begin
  select array_agg(a.attname order by a.attname) into v_bad
    from pg_attribute a
   where a.attrelid = 'public.profiles'::regclass
     and not a.attisdropped
     and a.attnum > 0
     and a.attname = any (v_dead);

  if v_bad is not null then
    raise exception
      'profiles üzerinde ölü sütun(lar) geri gelmiş: % — 0047''ye bakın', v_bad;
  end if;
end
$mig$;
