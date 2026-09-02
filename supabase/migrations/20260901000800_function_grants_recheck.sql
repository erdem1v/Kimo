-- 0033 — Fonksiyon yetkisi beyaz listesinin yeniden uygulanması
--
-- NEDEN AYRI BİR GÖÇ: 0029'daki beyaz liste NOKTA ATIŞIDIR — yalnızca o an var
-- olan fonksiyonlara uygulanır. Postgres her YENİ fonksiyonda EXECUTE'u tekrar
-- PUBLIC'e verir, yani sonradan eklenen her RPC varsayılan olarak yeniden açık
-- gelir. 0031 ve 0032 üç yeni fonksiyon ekledi.
--
-- Bu göç, her paketin sonunda tekrarlanacak bir KAPIDIR: beyaz liste güncellenir
-- ve yeniden uygulanır. Yeni RPC ekleyen herkes ya kendi göçünde `revoke execute
-- ... from public, anon` yazmalı (0031/0032 öyle yaptı) ya da bu listeye
-- eklemeli — ikisini de yapmazsa aşağıdaki blok fonksiyonu kapatır ve uygulama
-- kırılırsa göç patlayarak haber verir.

do $mig$
declare
  -- İstemcinin rpc() ile çağırdığı + RLS politikalarının çağıran yetkisiyle
  -- değerlendirdiği fonksiyonlar.
  v_keep text[] := array[
    -- yetki / ilişki yardımcıları (POLİTİKA İÇİNDEN çağrılıyorlar: açık kalmalı)
    'is_admin',
    'are_friends',
    'can_read_mistake_photo',
    'can_read_avatar',
    -- moderasyon (yetki kontrolü fonksiyonun İÇİNDE, is_admin() ile)
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
    'my_league_board'
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
