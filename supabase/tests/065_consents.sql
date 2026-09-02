-- 065 — Onay defteri: zaman damgalı ve değiştirilemez (Değişmez 7)
--
-- Bulgu raporda `profiles.guardian_consent` sütunu olarak geçiyordu, ama o
-- sütun ÖLÜ — hiçbir istemci kodu okumuyor/yazmıyor. Gerçek onay kaydı auth
-- kullanıcı metadata'sındaydı: tamamen kullanıcı-yazılabilir ve zaman damgasız,
-- yani onay geriye dönük değiştirilebiliyordu.

begin;
set search_path to public, extensions, tests;

select plan(13);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('mallory');

-- ============================================================== YAPI
select has_table('public'::name, 'user_consents'::name, 'user_consents tablosu var');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.user_consents'::regclass),
  'user_consents üzerinde RLS açık'
);
select ok(not has_table_privilege('authenticated', 'public.user_consents', 'INSERT'),
          'doğrudan INSERT kapalı (yalnızca record_consent)');
select ok(not has_table_privilege('authenticated', 'public.user_consents', 'UPDATE'),
          'UPDATE hiçbir role verilmemiş — DEĞİŞTİRİLEMEZLİĞİN garantisi bu');
select ok(not has_table_privilege('authenticated', 'public.user_consents', 'DELETE'),
          'DELETE hiçbir role verilmemiş');
select ok(has_table_privilege('authenticated', 'public.user_consents', 'SELECT'),
          'kullanıcı kendi kayıtlarını okuyabiliyor');

-- ============================================================== DAVRANIŞ
select tests.authenticate_as('alice');

select lives_ok(
  'select public.record_consent(''share'', true)',
  'onay kaydedilebiliyor'
);
select is(
  (select granted from public.my_consents where kind = 'share'),
  true,
  'my_consents en son kaydı gösteriyor'
);
select ok(
  (select recorded_at from public.my_consents where kind = 'share')
    > now() - interval '1 minute',
  'kayıt ZAMAN DAMGALI'
);

-- Geri alma da bir kayıttır: geçmiş silinmiyor, üstüne yazılıyor.
select lives_ok(
  'select public.record_consent(''share'', false)',
  'onay geri alınabiliyor'
);
select is(
  (select count(*)::int from public.user_consents
    where user_id = tests.get_supabase_uid('alice') and kind = 'share'),
  2,
  'defter GEÇMİŞİ tutuyor (iki kayıt), üstüne yazmıyor'
);

-- Değiştirilemezlik: kullanıcı kendi kaydını bile düzeltemez.
select throws_ok(
  format('update public.user_consents set granted = true where user_id = %L',
         tests.get_supabase_uid('alice')),
  '42501',
  'Değişmez 7: kullanıcı kendi onay kaydını değiştiremiyor'
);

-- Başkasının onayları görünmez.
select tests.authenticate_as('mallory');
select is(
  (select count(*)::int from public.user_consents),
  0,
  'başkasının onay kayıtları görünmüyor'
);

select * from finish();
rollback;
