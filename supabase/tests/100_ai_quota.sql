-- 100 — Analiz hakkı: katmanlı KAYAN pencere + aylık cap (0075)
--
-- Ürün kuralı (Task 10):
--   anonim   → TOPLAM 3 (ömür boyu)
--   ücretsiz → 8 saatte 10, ayda 300
--   premium  → 8 saatte 50, ayda 1.000
-- ve KAYDETME YOLU ASLA KAPANMAZ (o taraf arayüzde, burada kota sınanıyor).
--
-- SINIRLAR `app_config`'TEN DÜŞÜRÜLEREK sınanıyor, 300 çağrı yapılarak değil.
-- Bu yalnızca hız değil: yapılandırma yolunun GERÇEKTEN çalıştığını da
-- kanıtlıyor. Dolaylılık zaten bunun için var.

begin;
set search_path to public, extensions, tests;

select plan(50);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('mallory');

-- ============================================================== YAPI
select has_table('public'::name, 'ai_calls'::name, 'ai_calls defteri var');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.ai_calls'::regclass),
  'ai_calls üzerinde RLS açık'
);
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'ai_calls'),
  0,
  'ai_calls üzerinde HİÇ politika yok (yalnızca definer fonksiyonlar)'
);
select ok(not has_table_privilege('authenticated', 'public.ai_calls', 'SELECT'),
          'defter okunamıyor');
select ok(not has_table_privilege('authenticated', 'public.ai_calls', 'INSERT'),
          'deftere yazılamıyor — hak kendi kendine üretilemez');
select ok(not has_table_privilege('authenticated', 'public.ai_calls', 'UPDATE'),
          'defter güncellenemiyor');
-- SİLME ayrıca kapalı olmak zorunda: bir satır silmek kullanıcıya pencereden
-- bedava bir hak açardı.
select ok(not has_table_privilege('authenticated', 'public.ai_calls', 'DELETE'),
          'defterden satır SİLİNEMİYOR — silmek bedava hak demek olurdu');
select ok(not has_table_privilege('anon', 'public.ai_calls', 'SELECT'),
          'anon da okuyamıyor');

-- Kota rejiminin tamamı bu sütuna dayanıyor: yazılabilir olsaydı kullanıcı
-- kendini premium yapıp 50/8sa + 1.000/ay alırdı.
select ok(not has_column_privilege('authenticated', 'public.profiles',
                                   'premium_until', 'UPDATE'),
          'premium_until YAZILAMIYOR — kullanıcı kendini premium yapamaz');
select ok(not has_column_privilege('authenticated', 'public.profiles',
                                   'premium_until', 'INSERT'),
          'premium_until INSERT ile de yazılamıyor');

-- Yalnızca görünümün SELECT listesinde geçen fonksiyon açık olmalı.
select ok(has_function_privilege('authenticated', 'public.ai_state()', 'EXECUTE'),
          'ai_state çağrılabiliyor — kapalı olsaydı görünüm 42501 atardı');
select ok(not has_function_privilege('authenticated',
                                     'public.user_tier()', 'EXECUTE'),
          'user_tier kapalı');
select ok(not has_function_privilege('authenticated',
                                     'public.config_int(text, int)', 'EXECUTE'),
          'config_int kapalı');
select ok(not has_function_privilege('authenticated',
                                     'public.istanbul_month_reset()', 'EXECUTE'),
          'istanbul_month_reset kapalı');
select ok(not has_function_privilege('authenticated',
                                     'public.prune_ai_calls()', 'EXECUTE'),
          'prune_ai_calls kapalı');

select has_view('public'::name, 'my_daily_state'::name, 'my_daily_state var');
select ok(has_table_privilege('authenticated', 'public.my_daily_state', 'SELECT'),
          'günlük durum okunabiliyor');
select ok(not has_table_privilege('anon', 'public.my_daily_state', 'SELECT'),
          'anon günlük durumu okuyamıyor');

-- 0075 düşürdü; geri gelirlerse iki kota tanımı yan yana yaşardı.
select hasnt_function('public'::name, 'daily_ai_quota'::name,
                      'daily_ai_quota düşürüldü (sabit 5 rejimi bitti)');
select hasnt_function('public'::name, 'istanbul_day_reset'::name,
                      'istanbul_day_reset düşürüldü');

-- ====================================================== FAIL-OPEN
-- Anahtar yoksa varsayılana düşülüyor. Bu iddia olmasaydı yanlış
-- yapılandırılmış bir ortam analizi tümden kapatabilirdi.
delete from public.app_config where key like 'ai\_%';

select tests.authenticate_as('alice');
select is((select ai_window_limit from public.my_daily_state), 10,
          'anahtar YOKKEN ücretsiz pencere sınırı varsayılana düşüyor (10)');
select is((select ai_month_limit from public.my_daily_state), 300,
          'anahtar YOKKEN aylık cap varsayılana düşüyor (300)');
select is((select ai_tier from public.my_daily_state), 'free',
          'kalıcı hesap ücretsiz katmanda');
select is((select ai_state from public.my_daily_state), 'ok',
          'hak bolken durum ok');

-- ====================================================== KAYAN PENCERE
select tests.reset_role();
insert into public.app_config (key, value) values ('ai_window_free', '2')
on conflict (key) do update set value = excluded.value;

select tests.authenticate_as('alice');
select is((select remaining from public.consume_ai_use()), 1,
          'iki haklı pencerede birinci kullanım → 1 kaldı');
select is((select remaining from public.consume_ai_use()), 0,
          'ikinci kullanım → 0');
select is((select allowed from public.consume_ai_use()), false,
          'ÜÇÜNCÜ çağrı reddediliyor — hata atmadan, allowed=false ile');
select is((select ai_state from public.my_daily_state), 'window_full',
          'durum window_full');
select ok(
  (select ai_next_at from public.my_daily_state)
    between now() and now() + interval '8 hours',
  'sonraki hakkın anı pencere içinde ve gelecekte'
);
select isnt((select ai_next_at_hm from public.my_daily_state), null,
            'sonraki hakkın saati HH:MM olarak hazır geliyor');

-- PENCERENİN GERÇEKTEN KAYDIĞI — bu dosyanın en önemli davranış iddiası.
-- Zamanı ileri alamadığımız için satırı GERİYE tarihliyoruz: 9 saat önceki
-- bir çağrı pencereden ÇIKMIŞ ama AYIN içinde. Sabit kova uygulaması bu
-- iddiayı geçemez (mutasyon 34 tam bunu kuruyor).
select tests.reset_role();
delete from public.ai_calls where user_id = tests.get_supabase_uid('alice');
insert into public.ai_calls (user_id, at, tier)
values (tests.get_supabase_uid('alice'), now() - interval '9 hours', 'free');

select tests.authenticate_as('alice');
select is((select ai_window_left from public.my_daily_state), 2,
          '9 saat önceki çağrı PENCEREDE sayılmıyor — pencere kayıyor');
select is((select ai_month_left from public.my_daily_state), 299,
          'aynı çağrı AY içinde sayılıyor — iki sınır ayrı eksende');

-- ====================================================== AYLIK CAP
select tests.reset_role();
insert into public.app_config (key, value) values ('ai_month_free', '1')
on conflict (key) do update set value = excluded.value;

select tests.authenticate_as('alice');
select is((select ai_state from public.my_daily_state), 'month_full',
          'aylık cap dolunca durum month_full (pencere boş olsa bile)');
-- ÜRÜN KURALI: ay dolduğunda pencere saati GÖSTERİLMEZ — o saat artık bir şey
-- vaat etmiyor. Kararı sunucu veriyor ki istemci seçmek zorunda kalmasın.
select is((select ai_next_at_hm from public.my_daily_state), null,
          'ay doluyken pencere saati GÖSTERİLMİYOR');
select is((select ai_month_resets_on from public.my_daily_state),
          (date_trunc('month', now() at time zone 'Europe/Istanbul')
           + interval '1 month')::date,
          'ayın yenilenme günü ayın biri');
select is((select ad_offer from public.my_daily_state), false,
          'ay doluyken reklam YOLU SUNULMUYOR — ödül kullanılamazdı');

-- ====================================================== PREMIUM
select tests.reset_role();
delete from public.app_config where key like 'ai\_%';
update public.profiles set premium_until = now() + interval '30 days'
 where id = tests.get_supabase_uid('alice');

select tests.authenticate_as('alice');
select is((select ai_tier from public.my_daily_state), 'premium',
          'premium_until gelecekteyse katman premium');
select is((select ai_window_limit from public.my_daily_state), 50,
          'premium pencere sınırı 50');
select is((select ai_month_limit from public.my_daily_state), 1000,
          'premium aylık cap 1.000');
select is((select ad_rewards_left from public.my_daily_state), 0,
          'premium reklam görmüyor');

-- Zaman damgası olmasının TÜM sebebi bu: cron olmadan süresi doluyor.
select tests.reset_role();
update public.profiles set premium_until = now() - interval '1 day'
 where id = tests.get_supabase_uid('alice');
select tests.authenticate_as('alice');
select is((select ai_tier from public.my_daily_state), 'free',
          'premium_until GEÇMİŞTE ise katman kendiliğinden free''ye düşüyor');

-- ====================================================== ANONİM
select tests.reset_role();
delete from public.ai_calls where user_id = tests.get_supabase_uid('mallory');
update public.profiles set is_anonymous = true
 where id = tests.get_supabase_uid('mallory');

select tests.authenticate_as('mallory');
select is((select ai_window_limit from public.my_daily_state), 3,
          'anonim ömür cap''i 3');
select is((select remaining from public.consume_ai_use()), 2, 'anonim 1/3');
select is((select remaining from public.consume_ai_use()), 1, 'anonim 2/3');
select is((select remaining from public.consume_ai_use()), 0, 'anonim 3/3');
select is((select allowed from public.consume_ai_use()), false,
          'anonim DÖRDÜNCÜ çağrı reddediliyor');
select is((select ai_state from public.my_daily_state), 'lifetime_full',
          'durum lifetime_full — pencere/ay değil');
select is((select ai_next_at_hm from public.my_daily_state), null,
          'anonimde gösterilecek saat YOK (hak geri gelmiyor)');
select is((select ad_offer from public.my_daily_state), false,
          'anonim reklam görmüyor — yeni oturum sıfırlama yolu olurdu');

-- ====================================================== YALITIM
select tests.reset_role();
update public.profiles set is_anonymous = false
 where id = tests.get_supabase_uid('mallory');
select tests.authenticate_as('alice');
select is((select ai_left from public.my_daily_state),
          (select least(ai_window_left, ai_month_left) from public.my_daily_state),
          'gösterilen sayı BAĞLAYICI sınırdan geliyor');

select * from finish();
rollback;
