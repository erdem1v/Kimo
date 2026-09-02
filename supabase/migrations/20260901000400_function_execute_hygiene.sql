-- 0029 — Fonksiyon EXECUTE yetkileri: varsayılan PUBLIC'i kapat
--
-- BULGU (H7'yi düzeltirken çıktı, denetim raporunda yok):
-- Postgres yeni fonksiyonlarda EXECUTE'u otomatik olarak PUBLIC'e verir ve
-- `authenticated` PUBLIC'i miras alır. Bu depodaki 13 fonksiyona açık `grant`
-- yazılmış ama geri kalanına yazılmamış — yani onlar da çağrılabilir durumda:
--
--   • public.send_push(uuid,text,text,text)  ← EN CİDDİSİ. SECURITY DEFINER ve
--     servis rolüyle çalışan edge function'ı tetikliyor. Oturum açmış herhangi
--     biri /rest/v1/rpc/send_push ile İSTEDİĞİ kullanıcıya, istediği `kind` ve
--     istediği aktör adıyla bildirim gönderebiliyordu.
--   • public.settle_past_leagues() — ligleri erken sonuçlandırma denemesi
--     (etkisi sınırlı: yalnızca geçmiş haftaları kapatıyor, yine de kapatılmalı)
--   • public.assign_week_cohorts() — kohort dağıtımını tetikleme
--   • public.set_osym_account(uuid) — 0025'te public+authenticated'dan geri
--     alınmış ama `anon` atlanmış
--   • trigger fonksiyonları — doğrudan çağrılınca hata veriyorlar (gerçek bir
--     vektör değiller) ama Data API yüzeyinde durmalarının bir sebebi yok
--
-- ŞİDDET yine ortama bağlı: config.toml'daki auto_expose_new_tables notuna göre
-- yeni projelerde public şemadaki yeni fonksiyonlar Data API'ye otomatik
-- açılmıyor; eski davranışla kurulmuş bir projede açılıyor. Düzeltme her iki
-- durumda da doğru.
--
-- YAKLAŞIM: beyaz liste. İstemcinin (ve RLS politikalarının) ihtiyaç duyduğu
-- fonksiyonlar dışındaki her şeyden EXECUTE geri alınır, sonra beyaz listenin
-- hâlâ çağrılabilir olduğu DOĞRULANIR — yani bu göç uygulamayı kırarsa
-- kendisi patlar, sessizce 403 üretmez.

do $mig$
declare
  -- İstemcinin rpc() ile çağırdığı + RLS politikalarının çağıran yetkisiyle
  -- değerlendirdiği fonksiyonlar. can_read_mistake_photo storage.objects
  -- politikasında, are_friends question_sends politikasında kullanılıyor:
  -- ikisi de `authenticated` tarafından çalıştırılabilir KALMALI.
  v_keep text[] := array[
    'is_admin',
    'are_friends',
    'can_read_mistake_photo',
    'admin_pending_reports',
    'admin_all_questions',
    'admin_update_question',
    'admin_question_action',
    'moderate_report',
    'random_public_questions',
    'random_questions_by_topic',
    'available_question_counts',
    'ensure_league_membership',
    'my_league_board'
  ];
  r      record;
  v_miss text[];
begin
  -- 1) Beyaz liste dışındaki her public fonksiyondan EXECUTE'u geri al.
  --    Eklenti fonksiyonları (pg_net, pgtap, ...) hariç tutulur.
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

  -- 2) Beyaz listedekiler authenticated'a açık kalmalı; değilse uygulama kırılır.
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
