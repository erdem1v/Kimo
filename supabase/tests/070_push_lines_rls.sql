-- 070 — push_lines: RLS + grant'lar (Değişmez 6)
--
-- Tablo, iki kardeşi (device_tokens, app_config) özenle kilitlenmişken RLS'siz
-- yaratılmıştı. Şiddeti ORTAMA BAĞLIYDI: RLS kapalıyken erişim yalnızca
-- GRANT'lara bakar, ve grant'ların olup olmadığı projenin ne zaman kurulduğuna
-- göre değişir. Bu test belirsizliği ortadan kaldırıyor: hem RLS'i hem grant'ları
-- iddia ediyor, yani hangi ortam olursa olsun sonuç aynı.

begin;
set search_path to public, extensions, tests;

select plan(13);

select tests.create_supabase_user('alice');

-- ================================================================ push_lines
select ok(
  (select relrowsecurity from pg_class where oid = 'public.push_lines'::regclass),
  'push_lines üzerinde RLS açık'
);
select is(
  (select count(*)::int from pg_policy where polrelid = 'public.push_lines'::regclass),
  0,
  'push_lines politikasız (app_config kalıbı: politika yok = kimse erişemez)'
);

select ok(not has_table_privilege('authenticated', 'public.push_lines', 'SELECT'),
          'authenticated push_lines okuyamaz');
select ok(not has_table_privilege('authenticated', 'public.push_lines', 'INSERT'),
          'authenticated push_lines''a yazamaz (bildirim metni enjeksiyonu yok)');
select ok(not has_table_privilege('authenticated', 'public.push_lines', 'UPDATE'),
          'authenticated push_lines güncelleyemez');
select ok(not has_table_privilege('authenticated', 'public.push_lines', 'DELETE'),
          'authenticated push_lines silemez');
select ok(not has_table_privilege('anon', 'public.push_lines', 'SELECT'),
          'anon push_lines okuyamaz');
select ok(not has_table_privilege('anon', 'public.push_lines', 'INSERT'),
          'anon push_lines''a yazamaz');

-- ================================================================ app_config
-- Mevcut doğru karar korunuyor + grant'lar da geri alındı (savunma derinliği).
select ok(
  (select relrowsecurity from pg_class where oid = 'public.app_config'::regclass),
  'app_config üzerinde RLS açık (mevcut doğru karar korundu)'
);
select ok(not has_table_privilege('authenticated', 'public.app_config', 'SELECT'),
          'authenticated app_config okuyamaz (push_url / servis jetonu orada)');

-- =============================================================== DAVRANIŞ
select tests.authenticate_as('alice');
select throws_ok(
  'select 1 from public.push_lines limit 1',
  '42501', null,
  'authenticated push_lines''ı okumaya kalkınca reddediliyor'
);
select throws_ok(
  'select 1 from public.app_config limit 1',
  '42501', null,
  'authenticated app_config''i okumaya kalkınca reddediliyor'
);

-- ============================================= metinler hâlâ yerinde (pozitif)
-- Ayrıcalıklı oturuma dön: send_push SECURITY DEFINER olduğu için metinleri
-- okumaya devam eder; veri kaybolmadıysa o yol sağlamdır.
select tests.reset_role();
select ok(
  (select count(*) from public.push_lines) > 0,
  'bildirim metinleri duruyor (definer send_push okumaya devam edebilir)'
);

select * from finish();
rollback;
