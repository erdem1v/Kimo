-- 0038 — Fonksiyon yetkisi beyaz listesinin yeniden uygulanması (Paket 3 kapısı)
--
-- 0033 ile aynı kapı, güncellenmiş listeyle. Postgres her YENİ fonksiyonda
-- EXECUTE'u tekrar PUBLIC'e verdiği için bu kontrol her paketin sonunda
-- tekrarlanıyor. 0034 ve 0037 sekiz yeni fonksiyon ekledi.
--
-- apply_progress BİLEREK listede DEĞİL: yalnızca diğer definer fonksiyonlar
-- çağırıyor (onlar postgres olarak çalıştığı için EXECUTE'a ihtiyaçları yok).
-- Doğrudan çağrılabilseydi keyfi XP yazma primitifi olurdu.

do $mig$
declare
  v_keep text[] := array[
    -- yetki / ilişki yardımcıları (POLİTİKA İÇİNDEN çağrılıyorlar: açık kalmalı)
    'is_admin',
    'are_friends',
    'can_read_mistake_photo',
    'can_read_avatar',
    -- moderasyon
    'admin_pending_reports',
    'admin_all_questions',
    'admin_update_question',
    'admin_question_action',
    'moderate_report',
    'admin_photo_purge_queue',
    'admin_mark_photo_purged',
    -- havuz / harita / lig
    'random_public_questions',
    'random_questions_by_topic',
    'available_question_counts',
    'ensure_league_membership',
    'my_league_board',
    -- ilerleme (0034)
    'submit_pool_answer',
    'submit_sent_answer',
    'submit_review',
    'claim_daily_goal',
    'set_question_sharing',
    'upsert_my_profile',
    -- onay defteri (0037)
    'record_consent'
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
-- Değişmez 6'nın son kontrolü. 0027'deki aynı güvence O AN var olan tabloları
-- kapsıyordu; ondan sonra dört tablo eklendi (admins, submission_tokens,
-- user_consents ve 0031'in kolonları). Bu blok bugünü doğruluyor ve ileride
-- RLS'siz bir tablo eklenirse göç zamanında gürültüyle patlıyor.
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
-- Politikasız RLS zaten erişimi kapatıyor, ama grant'ların da geri alınmış
-- olduğunu ayrıca doğruluyoruz: ileride biri RLS'i kapatırsa tablo yine de
-- açılmasın (iki bağımsız katman).
do $mig$
declare
  v_server_only text[] := array[
    'admins', 'app_config', 'push_lines', 'submission_tokens'
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
