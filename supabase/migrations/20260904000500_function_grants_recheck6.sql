-- 0059 — Fonksiyon yetkisi beyaz listesi (Task 06 / P1b kapısı)
--
-- 0029, 0033, 0038, 0049, 0054 ve 0056 ile aynı kapı, güncellenmiş listeyle.
-- Postgres her YENİ fonksiyonda EXECUTE'u tekrar PUBLIC'e verdiği için bu
-- kontrol her paketin sonunda tekrarlanıyor.
--
-- Task 06 / P1b'nin eklediği iki fonksiyon da BİLEREK LİSTEDE DEĞİL —
-- ikisi de istemciden çağrılmamalı, bu yüzden aşağıdaki döngü onları
-- `authenticated`'tan geri alıyor:
--   hook_before_user_created → yalnızca `supabase_auth_admin` çağırır. Açık
--       olsaydı herkes kendi IP sayacını şişirip o ağdaki başkalarının
--       kaydını engelleyebilirdi.
--   prune_signup_throttle    → yalnızca pg_cron çağırır.
-- (v_keep listeye giren adın `authenticated` tarafından ÇAĞRILABİLİR olmasını
--  şart koşuyor; bu ikisini oraya yazmak göçü patlatırdı.)
--
-- LİSTEDE OLMAYAN ESKİ YENİLER BİLEREK KAPALI:
--   send_push → 0029'un en ciddi bulgusu; açıkken oturum açmış herkes istediği
--               kullanıcıya sahte bildirim gönderebiliyordu. Kapalı kalır.

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
    -- can / günlük durum (0040)
    'consume_ai_use',
    'daily_ai_quota',
    'istanbul_day',
    'istanbul_day_reset',
    -- içerik taraması (0050)
    'consume_scan_use',
    -- yaş kapısı ve veli onayı (0043)
    'set_birth_year',
    'request_guardian_consent',
    'my_guardian_status',
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
    'notification_lines'
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

-- ------------------------------------------------- yalnızca-sunucu tabloları
do $mig$
declare
  v_server_only text[] := array[
    'admins', 'app_config', 'push_lines', 'submission_tokens',
    'rate_limits', 'guardian_requests',
    -- persona metin altyapısı (0055): başlık tablosu ve anti-tekrar imleci
    'push_kinds', 'push_cursors',
    -- kayıt hız sınırı (0058): IP hash'leri hiçbir uygulama rolüne açılmaz
    'signup_throttle'
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
