-- 000 — Test altyapısının kendisi çalışıyor mu?
--
-- Bu dosya kırmızıysa DİĞER HİÇBİR TESTE GÜVENMEYİN. Özellikle 4. iddia:
-- tests.authenticate_as gerçekten auth.uid()'yi değiştiriyor mu? Değiştirmiyorsa
-- bütün "reddedilmeli" testleri `postgres` olarak çalışır, her şey yeşil yanar
-- ve süit hiçbir şey kanıtlamaz.

begin;
set search_path to public, extensions, tests;

select plan(9);

-- 1) pgTAP ve yardımcılar yerinde mi
select has_schema('tests', 'tests şeması var');
select has_function('tests'::name, 'authenticate_as'::name,
                    'tests.authenticate_as tanımlı');

-- 2) authenticate_as SECURITY INVOKER olmalı (definer ise GUC'lar geri sarılır)
select is(
  (select p.prosecdef from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'tests' and p.proname = 'authenticate_as'),
  false,
  'authenticate_as SECURITY INVOKER (definer olsaydı kimlik kurulumu sessizce silinirdi)'
);

-- 3) authenticate_as SET yan tümcesi taşımamalı (aynı sebep)
select is(
  (select p.proconfig from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'tests' and p.proname = 'authenticate_as'),
  null,
  'authenticate_as proconfig boş (SET yan tümcesi de GUC yuvasını geri sarardı)'
);

-- 4) Kullanıcı üretimi + profiles trigger'ı
select tests.create_supabase_user('smoke_alice');
select isnt(tests.get_supabase_uid('smoke_alice'), null, 'sahte kullanıcı üretildi');
select is(
  (select count(*)::int from public.profiles
    where id = tests.get_supabase_uid('smoke_alice')),
  1,
  'on_auth_user_created profiles satırını yarattı'
);

-- 5) ★ KRİTİK: kimliğe bürünme gerçekten çalışıyor mu
select tests.authenticate_as('smoke_alice');
select is(auth.uid(), tests.get_supabase_uid('smoke_alice'),
          'auth.uid() authenticate_as ile birlikte hareket ediyor');
select is(current_user::text, 'authenticated',
          'current_user authenticated (sütun/tablo GRANT kontrolleri buna bakıyor)');

-- 6) anon rolüne geçiş
select tests.authenticate_as_anon();
select is(auth.uid(), null, 'anon rolünde auth.uid() null');

select * from finish();
rollback;
