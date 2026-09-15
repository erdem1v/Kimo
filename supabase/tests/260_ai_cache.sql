-- 260 — Sonuç önbelleği (0060): ikinci ücret çıkmıyor, kapsam sızmıyor
--
-- İki yön:
--   YAPI     — tablo hiçbir uygulama rolüne açık değil; okuma/yazma yalnızca
--              iki definer fonksiyondan geçiyor (TTL kararını onlar veriyor).
--   DAVRANIŞ — isabet çalışıyor, KAPSAM KULLANICIYA KİLİTLİ, bayat kayıt
--              isabet etmiyor, bozuk hash sessizce "isabet yok"a dönüşmüyor.
--
-- Kapsam iddiası (14) bu dosyanın en önemlisi: küresel bir önbellek daha çok
-- tasarruf ederdi ama bir kullanıcı, elindeki fotoğrafın başkası tarafından
-- analiz edilip edilmediğini ölçebilirdi.

begin;
set search_path to public, extensions, tests;

select plan(18);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('mallory');

-- ============================================================== YAPI

select has_table('public', 'ai_result_cache', 'ai_result_cache tablosu var');

select ok(
  (select relrowsecurity from pg_class where oid = 'public.ai_result_cache'::regclass),
  'ai_result_cache üzerinde RLS açık'
);

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'ai_result_cache'),
  0,
  'ai_result_cache üzerinde HİÇ politika yok'
);

select ok(not has_table_privilege('authenticated', 'public.ai_result_cache', 'SELECT'),
          'önbellek authenticated tarafından doğrudan OKUNAMIYOR (TTL kararı fonksiyonda)');
select ok(not has_table_privilege('authenticated', 'public.ai_result_cache', 'INSERT'),
          'önbellek authenticated tarafından yazılamıyor');
select ok(not has_table_privilege('anon', 'public.ai_result_cache', 'SELECT'),
          'önbellek anon tarafından okunamıyor');

-- İMZALAR ÜÇ PARAMETRELİ. `p_taxonomy_version` 0071'de eklendi (önbellek
-- taksonomi sürümüne de anahtarlanıyor, yoksa ağaç değişince eski sonuç
-- dönerdi). Bu üç iddia iki parametreli imzayı sormaya devam ediyordu ve
-- `has_function_privilege` var olmayan imzada FALSE değil HATA veriyor —
-- yani dosya yedinci satırda düşüyor, kalan 12 iddia hiç koşmuyordu.
select ok(has_function_privilege('authenticated',
            'public.ai_cache_get(text,text,text)', 'EXECUTE'),
          'ai_cache_get authenticated''a AÇIK (edge fonksiyonu çağıranın JWT''siyle çağırıyor)');
select ok(has_function_privilege('authenticated',
            'public.ai_cache_put(text,text,jsonb,text)', 'EXECUTE'),
          'ai_cache_put authenticated''a açık');
select ok(not has_function_privilege('anon',
            'public.ai_cache_get(text,text,text)', 'EXECUTE'),
          'ai_cache_get anon''a kapalı');
select ok(not has_function_privilege('authenticated',
            'public.prune_ai_result_cache()', 'EXECUTE'),
          'budama fonksiyonu authenticated''a kapalı (yalnızca pg_cron)');

-- ============================================================== DAVRANIŞ

select tests.authenticate_as('alice');

select is(
  public.ai_cache_get(repeat('a', 64), 'eski'),
  null::jsonb,
  'boş önbellekte isabet yok'
);

select lives_ok(
  format('select public.ai_cache_put(%L, %L, %L::jsonb)',
         repeat('a', 64), 'eski', '{"is_readable": true, "ders": "Matematik"}'),
  'sonuç önbelleğe yazılıyor'
);

select is(
  public.ai_cache_get(repeat('a', 64), 'eski') ->> 'ders',
  'Matematik',
  'aynı fotoğraf + aynı müfredat İSABET ediyor — ikinci ücret çıkmıyor'
);

select is(
  public.ai_cache_get(repeat('a', 64), 'maarif'),
  null::jsonb,
  'farklı müfredat isabet etmiyor (prompt farklı, sonuç da farklı olurdu)'
);

-- EN ÖNEMLİ İDDİA: kapsam kullanıcıya kilitli.
select tests.authenticate_as('mallory');

select is(
  public.ai_cache_get(repeat('a', 64), 'eski'),
  null::jsonb,
  'BAŞKA kullanıcı aynı hash''le isabet ALAMIYOR (önbellek bir ölçme yüzeyi değil)'
);

-- Bozuk hash sessizce "isabet yok"a dönüşmüyor: çağıran bizim edge
-- fonksiyonumuz; oraya geçersiz değer gidiyorsa bilmek istiyoruz.
select throws_ok(
  $$select public.ai_cache_get('kisa', 'eski')$$,
  '22023', null,
  'geçersiz hash gürültüyle reddediliyor'
);

select tests.authenticate_as_anon();

select throws_ok(
  format('select public.ai_cache_get(%L, %L)', repeat('a', 64), 'eski'),
  '42501', null,
  'oturumsuz çağrı yetki hatası alıyor'
);

-- --- bayat kayıt isabet etmiyor (TTL 24 saat)
select tests.reset_role();

update public.ai_result_cache
   set created_at = now() - interval '25 hours'
 where user_id = tests.get_supabase_uid('alice');

select tests.authenticate_as('alice');

select is(
  public.ai_cache_get(repeat('a', 64), 'eski'),
  null::jsonb,
  '24 saatten eski kayıt isabet etmiyor'
);

select * from finish();
rollback;
