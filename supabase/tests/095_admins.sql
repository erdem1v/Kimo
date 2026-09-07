-- 095 — Yönetici rolü: is_admin sütunundan politikasız tabloya (C1)
--
-- Denetim bulgusu C1, kümenin en ciddisiydi: `is_admin` kullanıcının kendi
-- yazabildiği satırda duruyordu, yani
--     PATCH /rest/v1/profiles?id=eq.<kendi uid> {"is_admin": true}
-- tek istekle tam moderasyon devralmaya yetiyordu — moderate_report,
-- admin_all_questions, admin_question_action ve can_read_mistake_photo''nun
-- admin dalı (TÜM kullanıcıların fotoğrafları) dahil.
--
-- Sütun grant''ı da yeterdi; ayrı tablo seçildi çünkü politikasız bir tablo
-- YAPISAL olarak deny-by-default: ileride biri yanlışlıkla geniş bir GRANT
-- yazsa bile kapı açılmaz.

begin;
set search_path to public, extensions, tests;

select plan(11);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('rootuser');

-- ============================================================== YAPI
select has_table('public'::name, 'admins'::name, 'public.admins tablosu var');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.admins'::regclass),
  'admins üzerinde RLS açık'
);
select is(
  (select count(*)::int from pg_policy where polrelid = 'public.admins'::regclass),
  0,
  'admins politikasız (yapısal olarak deny-by-default)'
);
select ok(not has_table_privilege('authenticated', 'public.admins', 'SELECT'),
          'authenticated admins okuyamaz');
select ok(not has_table_privilege('authenticated', 'public.admins', 'INSERT'),
          'authenticated kendini admin YAPAMAZ (C1 kapandı)');
select ok(not has_table_privilege('anon', 'public.admins', 'INSERT'),
          'anon kendini admin yapamaz');

-- ============================================================== DAVRANIŞ
select tests.authenticate_as('alice');

select throws_ok(
  format('insert into public.admins (user_id) values (%L)',
         tests.get_supabase_uid('alice')),
  '42501', null,
  'C1: sıradan kullanıcı kendini yönetici yapamaz'
);
select is(public.is_admin(), false, 'sıradan kullanıcı için is_admin() false');

-- Moderasyon RPC''si gerçekten kapalı mı (yalnızca grant değil, davranış)
select throws_ok(
  format('select public.moderate_report(%L, ''remove'')', gen_random_uuid()),
  'yetkisiz',
  'yönetici olmayan moderate_report çağıramıyor'
);

-- ============================================================== POZİTİF
-- Gerçek bir yönetici eklenince is_admin() true dönmeli, yoksa moderasyon
-- ekranı tamamen ölür.
select tests.reset_role();
insert into public.admins (user_id) values (tests.get_supabase_uid('rootuser'));

select tests.authenticate_as('rootuser');
select is(public.is_admin(), true, 'gerçek yönetici için is_admin() true');
select lives_ok(
  'select public.admin_all_questions(10, 0)',
  'yönetici soru listesini çekebiliyor (moderasyon ekranı çalışıyor)'
);

select * from finish();
rollback;
