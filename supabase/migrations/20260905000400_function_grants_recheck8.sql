-- 0065 — Fonksiyon yetkisi beyaz listesi (Task 07 kapısı)
--
-- 0029, 0033, 0038, 0049, 0054, 0056 ve 0061 ile aynı kapı, güncellenmiş
-- listeyle. Postgres her YENİ fonksiyonda EXECUTE'u tekrar PUBLIC'e verdiği
-- için bu kontrol her paketin sonunda tekrarlanıyor.
--
-- LİSTEDEN ÇIKANLAR (0063'te DÜŞÜRÜLDÜLER — listede kalsalardı bu göç
-- "beyaz listedeki fonksiyon çağrılamıyor" ile patlardı):
--   request_guardian_consent, my_guardian_status
-- (confirm_guardian_consent ve send_guardian_email zaten listede değildi;
--  ikisi de yalnızca sunucu tarafından çağrılıyordu.)
--
-- Task 07'nin eklediği çağrılabilir fonksiyonlar:
--   is_suspended         → POLİTİKA İÇİNDEN çağrılıyor (mistakes/storage/
--       question_sends/friendships INSERT). Açık olmak ZORUNDA; kapalı olsaydı
--       politika ifadesi hata verir ve dört yazma yolu birden kırılırdı.
--   my_sanction / my_photo_warnings / ack_photo_warnings → askı ekranı ve
--       ihlal uyarısı. Kullanıcının kendi durumunu okuması meşru; hepsi
--       auth.uid()'e kilitli, parametre almıyorlar.
--   admin_user_sanctions / admin_suspend_user → yönetici ekranı; yetki
--       fonksiyonun İÇİNDE `is_admin()` ile doğrulanıyor (admin_question_action
--       ile aynı desen).
--   my_age_status        → `my_guardian_status`ın yerini aldı.
--   accept_legal_terms   → kayıt adımındaki koşul onayı.
--
-- BİLEREK LİSTEDE OLMAYANLAR:
--   mistakes_photo_violation → tetikleyici fonksiyonu; tetikleyici olarak
--       çalışıyor, EXECUTE yetkisine ihtiyacı yok. Açık olsaydı herkes
--       istediği kullanıcı için ihlal kaydı uydurabilirdi.
--   hook_before_user_created, prune_signup_throttle, prune_ai_result_cache →
--       yalnızca `supabase_auth_admin` ve pg_cron çağırır (0061'in gerekçesi).
--   send_push → 0029'un en ciddi bulgusu; kapalı kalır.

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
    -- yaş kapısı (0043 / 0063)
    'set_birth_year',
    'my_age_status',
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
    -- fotoğraf hash'i sonuç önbelleği (0060)
    'ai_cache_get',
    'ai_cache_put'
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
    'rate_limits',
    -- persona metin altyapısı (0055): başlık tablosu ve anti-tekrar imleci
    'push_kinds', 'push_cursors',
    -- kayıt hız sınırı (0058): IP hash'leri hiçbir uygulama rolüne açılmaz
    'signup_throttle',
    -- sonuç önbelleği (0060): TTL kararını fonksiyon veriyor, tablo kapalı
    'ai_result_cache',
    -- yaptırım defterleri (0062): kullanıcı kendi sicilini ne okur ne yazar;
    -- okuma my_sanction() / my_photo_warnings() üzerinden, süzülmüş hâlde
    'user_sanctions', 'photo_violations'
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
