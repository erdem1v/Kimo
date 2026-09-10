-- 250 — Kayıt hız sınırı (0058): sayaç kapalı mı, kanca gerçekten kesiyor mu?
--
-- İki yön birden tutuluyor:
--   YAPI     — sayaç tablosu ve kanca hiçbir uygulama rolüne açık değil.
--   DAVRANIŞ — limit gerçekten reddediyor, kovalar ayrı, tuz yokken FAIL-OPEN.
--
-- Fail-open dalı ayrıca test ediliyor çünkü sessiz bir yanlış yapılandırma
-- (tuz girilmemiş) burada kayıt akışını KAPATSAYDI, hız sınırının önlediği
-- her şeyden pahalı olurdu.

begin;
set search_path to public, extensions, tests;

select plan(24);

-- ============================================================== YAPI

select has_table('public', 'signup_throttle', 'signup_throttle tablosu var');

select ok(
  (select relrowsecurity from pg_class where oid = 'public.signup_throttle'::regclass),
  'signup_throttle üzerinde RLS açık'
);

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'signup_throttle'),
  0,
  'signup_throttle üzerinde HİÇ politika yok (yalnızca definer fonksiyonlar)'
);

select ok(not has_table_privilege('authenticated', 'public.signup_throttle', 'SELECT'),
          'sayaç authenticated tarafından okunamıyor');
select ok(not has_table_privilege('authenticated', 'public.signup_throttle', 'INSERT'),
          'sayaç authenticated tarafından yazılamıyor');
select ok(not has_table_privilege('anon', 'public.signup_throttle', 'SELECT'),
          'sayaç anon tarafından okunamıyor');

select has_function('public', 'hook_before_user_created', array['jsonb'],
                    'kanca fonksiyonu var');

-- Kanca açık olsaydı herkes kendi IP sayacını şişirip o ağdaki başkalarının
-- kaydını engelleyebilirdi — bu yüzden iki rol de kapalı.
select ok(not has_function_privilege('authenticated',
            'public.hook_before_user_created(jsonb)', 'EXECUTE'),
          'kanca authenticated''a KAPALI');
select ok(not has_function_privilege('anon',
            'public.hook_before_user_created(jsonb)', 'EXECUTE'),
          'kanca anon''a kapalı');
select ok(has_function_privilege('supabase_auth_admin',
            'public.hook_before_user_created(jsonb)', 'EXECUTE'),
          'kanca supabase_auth_admin''e AÇIK (kapalıysa kayıt tamamen kırılır)');
select ok(not has_function_privilege('authenticated',
            'public.prune_signup_throttle()', 'EXECUTE'),
          'budama fonksiyonu authenticated''a kapalı (yalnızca pg_cron)');

-- ============================================================== DAVRANIŞ

-- --- tuz yokken FAIL-OPEN: kayıt geçmeli, sayaç hiç yazılmamalı
delete from public.app_config where key = 'signup_ip_salt';

select is(
  public.hook_before_user_created(jsonb_build_object(
    'metadata', jsonb_build_object('ip_address', '203.0.113.1'),
    'user',     jsonb_build_object('email', 'ali@ornek.com', 'is_anonymous', false))),
  '{}'::jsonb,
  'tuz girilmemişken kayıt GEÇİYOR (fail-open)'
);

select is(
  (select count(*)::int from public.signup_throttle),
  0,
  'tuz yokken sayaca hiç satır yazılmıyor'
);

-- --- tuz varken normal kayıt
insert into public.app_config (key, value) values ('signup_ip_salt', 'test-tuzu')
on conflict (key) do update set value = excluded.value;

select is(
  public.hook_before_user_created(jsonb_build_object(
    'metadata', jsonb_build_object('ip_address', '203.0.113.1'),
    'user',     jsonb_build_object('email', 'ali@ornek.com', 'is_anonymous', false))),
  '{}'::jsonb,
  'normal kayıt geçiyor'
);

select is(
  (select count(*)::int from public.signup_throttle where kind = 'signup'),
  2,
  'sayaç iki satır yazdı (saatlik + günlük pencere)'
);

-- IP HAM SAKLANMIYOR: sütun bytea ve sha256 çıktısı her zaman 32 bayt.
select is(
  (select distinct octet_length(ip_hash)::int from public.signup_throttle),
  32,
  'IP ham değil, 32 baytlık sha256 özeti olarak saklanıyor'
);

-- --- saatlik limit gerçekten kesiyor
insert into public.app_config (key, value) values ('signup_hour_limit', '2')
on conflict (key) do update set value = excluded.value;

-- Yukarıdaki çağrı saatlik kovayı 1 yaptı; bu ikinciyi 2'ye çıkarır, üçüncü red.
select is(
  public.hook_before_user_created(jsonb_build_object(
    'metadata', jsonb_build_object('ip_address', '203.0.113.1'),
    'user',     jsonb_build_object('email', 'veli@ornek.com', 'is_anonymous', false))),
  '{}'::jsonb,
  'limitin altındaki ikinci kayıt hâlâ geçiyor'
);

select is(
  public.hook_before_user_created(jsonb_build_object(
    'metadata', jsonb_build_object('ip_address', '203.0.113.1'),
    'user',     jsonb_build_object('email', 'ayse@ornek.com', 'is_anonymous', false)))
    -> 'error' ->> 'http_code',
  '429',
  'saatlik limit aşılınca 429 — kalıcı engel değil, yeniden denenebilir'
);

-- --- kovalar AYRI: bir okulun anonim ilk-açılışları kayıt bütçesini yemiyor
select is(
  public.hook_before_user_created(jsonb_build_object(
    'metadata', jsonb_build_object('ip_address', '203.0.113.1'),
    'user',     jsonb_build_object('is_anonymous', true))),
  '{}'::jsonb,
  'aynı IP kayıt kovasında doluyken anonim oturum hâlâ açılabiliyor'
);

-- --- tek kullanımlık alan adı
select is(
  public.hook_before_user_created(jsonb_build_object(
    'metadata', jsonb_build_object('ip_address', '203.0.113.9'),
    'user',     jsonb_build_object('email', 'x@mailinator.com', 'is_anonymous', false)))
    -> 'error' ->> 'http_code',
  '400',
  'tek kullanımlık alan adı reddediliyor'
);

select is(
  public.hook_before_user_created(jsonb_build_object(
    'metadata', jsonb_build_object('ip_address', '203.0.113.9'),
    'user',     jsonb_build_object('is_anonymous', true))),
  '{}'::jsonb,
  'anonim oturumda alan adı kontrolü çalışmıyor (e-posta yok)'
);

-- --- günlük limit ayrı bir kapı
insert into public.app_config (key, value) values ('signup_day_limit', '1')
on conflict (key) do update set value = excluded.value;

select is(
  public.hook_before_user_created(jsonb_build_object(
    'metadata', jsonb_build_object('ip_address', '198.51.100.7'),
    'user',     jsonb_build_object('email', 'ilk@ornek.com', 'is_anonymous', false))),
  '{}'::jsonb,
  'yeni IP''nin ilk kaydı geçiyor'
);

select is(
  public.hook_before_user_created(jsonb_build_object(
    'metadata', jsonb_build_object('ip_address', '198.51.100.7'),
    'user',     jsonb_build_object('email', 'ikinci@ornek.com', 'is_anonymous', false)))
    -> 'error' ->> 'http_code',
  '429',
  'günlük limit aşılınca 429'
);

-- --- farklı IP etkilenmiyor (sayaç gerçekten IP başına)
select is(
  public.hook_before_user_created(jsonb_build_object(
    'metadata', jsonb_build_object('ip_address', '198.51.100.8'),
    'user',     jsonb_build_object('email', 'baska@ornek.com', 'is_anonymous', false))),
  '{}'::jsonb,
  'başka bir IP''nin sayacı etkilenmiyor'
);

select * from finish();
rollback;
