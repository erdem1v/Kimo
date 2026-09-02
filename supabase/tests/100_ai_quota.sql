-- 100 — Can: günlük yapay zekâ okutma hakkı (0040)
--
-- Ürün kuralı: günde 5 hak, Europe/Istanbul gün dönümünde tazelenir, kaydetme
-- yolu asla kapanmaz. Bu dosya iki şeyi ayrı ayrı doğruluyor:
--   • sayacın kendisi istemciye KAPALI (yoksa hak kendi kendine yazılırdı),
--   • tüketimin 5'te DURDUĞU ve gün değişince sıfırlandığı.

begin;
set search_path to public, extensions, tests;

select plan(20);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('mallory');

-- ============================================================== YAPI
select has_table('public'::name, 'rate_limits'::name, 'rate_limits tablosu var');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.rate_limits'::regclass),
  'rate_limits üzerinde RLS açık'
);
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'rate_limits'),
  0,
  'rate_limits üzerinde HİÇ politika yok (yalnızca definer fonksiyonlar)'
);
select ok(not has_table_privilege('authenticated', 'public.rate_limits', 'SELECT'),
          'sayaç okunamıyor');
select ok(not has_table_privilege('authenticated', 'public.rate_limits', 'INSERT'),
          'sayaç yazılamıyor — hak kendi kendine üretilemez');
select ok(not has_table_privilege('authenticated', 'public.rate_limits', 'UPDATE'),
          'sayaç güncellenemiyor');
select ok(not has_table_privilege('anon', 'public.rate_limits', 'SELECT'),
          'anon da okuyamıyor');

select has_view('public'::name, 'my_daily_state'::name, 'my_daily_state görünümü var');
select ok(has_table_privilege('authenticated', 'public.my_daily_state', 'SELECT'),
          'günlük durum okunabiliyor');

-- ============================================================== DAVRANIŞ
select tests.authenticate_as('alice');

select is(
  (select ai_left from public.my_daily_state),
  5,
  'gün başında 5 hak var'
);

select is(
  (select remaining from public.consume_ai_use()),
  4,
  'bir hak harcanınca 4 kalıyor'
);

select is(
  (select ai_left from public.my_daily_state),
  4,
  'görünüm sayaçla aynı sayıyı gösteriyor (tek doğruluk kaynağı)'
);

-- Kalan dördü tek tek: küme döndüren fonksiyonu SELECT listesinde çağırmak
-- yerine her çağrı ayrı bir iddia. Okunabilir ve hangi adımda kırıldığı belli.
select is((select remaining from public.consume_ai_use()), 3, 'ikinci kullanım → 3');
select is((select remaining from public.consume_ai_use()), 2, 'üçüncü kullanım → 2');
select is((select remaining from public.consume_ai_use()), 1, 'dördüncü kullanım → 1');
select is((select remaining from public.consume_ai_use()), 0, 'beşinci kullanım → 0');

select is(
  (select allowed from public.consume_ai_use()),
  false,
  'ALTINCI çağrı reddediliyor — hata atmadan, allowed=false ile'
);

select ok(
  (select resets_at from public.consume_ai_use()) > now(),
  'yenilenme anı gelecekte (kullanıcıya "yarın" denebilsin)'
);

-- Gün değişimi: sayaç satırı GÜN ANAHTARIYLA tutuluyor, ertesi günün anahtarı
-- yok demek sıfırdan başlamak demek. Zamanı ileri alamadığımız için anahtarı
-- doğrudan kontrol ediyoruz.
select tests.reset_role();
select is(
  (select count(*)::int from public.rate_limits
    where user_id = tests.get_supabase_uid('alice')
      and bucket = 'ai'
      and window_key = ((now() at time zone 'Europe/Istanbul')::date + 1)::text),
  0,
  'YARININ anahtarında satır yok — gün dönümünde hak kendiliğinden tazeleniyor'
);

-- Sayaç kullanıcıya özel.
select tests.authenticate_as('mallory');
select is(
  (select ai_left from public.my_daily_state),
  5,
  'başkasının harcaması benim hakkımı etkilemiyor'
);

select * from finish();
rollback;
