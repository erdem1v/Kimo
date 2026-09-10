-- 065 — Onay defteri: zaman damgalı ve değiştirilemez (Değişmez 7)
--
-- Bulgu raporda `profiles.guardian_consent` sütunu olarak geçiyordu, ama o
-- sütun ÖLÜ — hiçbir istemci kodu okumuyor/yazmıyor. Gerçek onay kaydı auth
-- kullanıcı metadata'sındaydı: tamamen kullanıcı-yazılabilir ve zaman damgasız,
-- yani onay geriye dönük değiştirilebiliyordu.

begin;
set search_path to public, extensions, tests;

select plan(27);

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
select has_column('public'::name, 'user_consents'::name, 'text_version'::name,
                  'onay kaydı hangi METNİ onayladığını tutuyor (0063)');

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
  '42501', null,
  'Değişmez 7: kullanıcı kendi onay kaydını değiştiremiyor'
);

-- Başkasının onayları görünmez.
select tests.authenticate_as('mallory');
select is(
  (select count(*)::int from public.user_consents),
  0,
  'başkasının onay kayıtları görünmüyor'
);

-- ================================================ KOŞUL VE GİZLİLİK (0063)
-- Apple 1.2: kullanıcı içeriği barındıran uygulamada koşul kabulü aranıyor.
-- Kayıt bu onay olmadan tamamlanmamalı; burada onayın DEFTERE ve SÜRÜMÜYLE
-- düştüğü kanıtlanıyor.
select tests.reset_role();
insert into public.app_config (key, value) values ('legal_version', '1.1')
on conflict (key) do update set value = excluded.value;

select tests.authenticate_as('alice');

select lives_ok(
  'select public.accept_legal_terms()',
  'koşul ve gizlilik onayı kaydedilebiliyor'
);
select is(
  (select count(*)::int from public.user_consents
    where user_id = tests.get_supabase_uid('alice')
      and kind in ('terms', 'privacy') and granted),
  2,
  'iki ayrı belge iki ayrı satır — biri güncellenince diğeri bozulmasın'
);
select is(
  (select text_version from public.my_consents where kind = 'terms'),
  '1.1',
  'onay kaydı METİN SÜRÜMÜNÜ taşıyor'
);
select is(
  (select source from public.my_consents where kind = 'privacy'),
  'signup',
  'kaynak kayıt adımı olarak işaretleniyor'
);

-- Aynı sürüm ikinci kez yazılmıyor: defter gürültüsüz kalsın.
select lives_ok(
  'select public.accept_legal_terms()',
  'ikinci çağrı hata vermiyor'
);
select is(
  (select count(*)::int from public.user_consents
    where user_id = tests.get_supabase_uid('alice') and kind = 'terms'),
  1,
  'aynı sürüm ikinci kez deftere yazılmıyor'
);

-- Sürüm DEĞİŞİRSE yeni onay gerekir — kayıt metne bağlıdır.
select tests.reset_role();
update public.app_config set value = '2.0' where key = 'legal_version';
select tests.authenticate_as('alice');
select lives_ok(
  'select public.accept_legal_terms()',
  'yeni sürüm onaylanabiliyor'
);
select is(
  (select count(*)::int from public.user_consents
    where user_id = tests.get_supabase_uid('alice') and kind = 'terms'),
  2,
  'sürüm değişince YENİ satır yazılıyor'
);
select is(
  (select text_version from public.my_consents where kind = 'terms'),
  '2.0',
  'my_consents en güncel sürümü gösteriyor'
);

-- Sürümsüz yol kapalı: koşul onayı yalnızca accept_legal_terms'ten geçer.
select throws_ok(
  'select public.record_consent(''terms'', true)',
  '22023', null,
  'record_consent koşul onayı YAZAMIYOR — sürümsüz kayıt ispat değeri taşımaz'
);
select throws_ok(
  'select public.record_consent(''privacy'', true)',
  '22023', null,
  'gizlilik onayı da record_consent üzerinden yazılamıyor'
);
-- Veli onayı türü GEÇMİŞ için CHECK'te duruyor ama yazma yolu kapandı (0063).
select throws_ok(
  'select public.record_consent(''guardian'', true)',
  '22023', null,
  'veli onayı artık yazılamıyor (tür geçmiş kayıtlar için CHECK''te kalıyor)'
);

-- Sürüm de değiştirilemez: defterin dokunulmazlığı yeni sütunu da kapsıyor.
select throws_ok(
  format('update public.user_consents set text_version = ''9.9'' where user_id = %L',
         tests.get_supabase_uid('alice')),
  '42501', null,
  'Değişmez 7: onaylanan metin sürümü geriye dönük değiştirilemiyor'
);

select * from finish();
rollback;
