-- 310 — Uzaktan özellik bayrakları (0079)
--
-- ÜRÜN: riskli bir yüzey (ortak seri, çoklu çekim, ödüllü reklam) ölçüm kötü
-- çıkarsa MAĞAZA GÜNCELLEMESİ BEKLENMEDEN kapatılabilmeli.
--
-- BU DOSYANIN EN ÖNEMLİ İKİ İDDİASI:
--   1. `config_bool` `authenticated`'a KAPALI. Açık olsaydı istemci
--      `app_config`'teki HERHANGİ bir anahtarı yoklayabilirdi — orada
--      `push_service_key` duruyor.
--   2. Tanınmayan bir değer özelliği SESSİZCE KAPATMIYOR, varsayılana
--      düşüyor. Yazım hatasının bir kill switch'i tetiklemesi, kill switch'in
--      kendisinden daha pahalı bir hata sınıfı.
--
-- İKİ KATMANLI İDDİA (240'ın kuralı): 42501 hem sütun ayrıcalığından hem
-- RLS'ten gelebildiği için her davranış iddiasının yanında bir pg_catalog
-- iddiası duruyor.

begin;
set search_path to public, extensions, tests;

select plan(19);

select tests.create_supabase_user('alice');

-- ============================================================== YETKİLER
select ok(not has_function_privilege(
            'authenticated', 'public.config_bool(text, boolean)', 'EXECUTE'),
          'config_bool authenticated''a KAPALI — app_config yoklanamaz');
select ok(not has_function_privilege(
            'anon', 'public.config_bool(text, boolean)', 'EXECUTE'),
          'config_bool anon''a da kapalı');
select ok(has_function_privilege(
            'authenticated', 'public.feature_flags()', 'EXECUTE'),
          'feature_flags authenticated''a AÇIK — görünümün SELECT listesinde');
select ok(not has_function_privilege(
            'anon', 'public.feature_flags()', 'EXECUTE'),
          'feature_flags anon''a kapalı');

-- Aşırı kilitleme KARŞI-İDDİASI: bayrak yolu app_config'i istemciye AÇMIYOR.
select ok(not has_table_privilege('authenticated', 'public.app_config', 'SELECT'),
          'app_config authenticated''a hâlâ kapalı');

-- ============================================================== SÜTUNLAR
-- Görünüm bu depoda dört kez yeniden tanımlandı; sütunların varlığı
-- 0080'in göç zamanı kapısıyla birlikte iki yerden korunuyor.
select has_column('public'::name, 'my_daily_state'::name,
                  'ff_pair_streak'::name, 'görünümde ff_pair_streak var');
select has_column('public'::name, 'my_daily_state'::name,
                  'ff_multi_capture'::name, 'görünümde ff_multi_capture var');
select has_column('public'::name, 'my_daily_state'::name,
                  'ff_ad_reward'::name, 'görünümde ff_ad_reward var');

-- ============================================================== VARSAYILANLAR
-- Anahtar YOKKEN politika gövdede duruyor.
delete from public.app_config where key like 'ff\_%';

select is((select ff_pair_streak from public.feature_flags()), false,
          'anahtar yokken ortak seri KAPALI doğuyor (DSA Md. 28(1) kılavuzu)');
select is((select ff_multi_capture from public.feature_flags()), true,
          'anahtar yokken çoklu çekim açık (bayrak bir kill switch)');
select is((select ff_ad_reward from public.feature_flags()), true,
          'anahtar yokken ödüllü reklam açık');

-- =========================================================== APP_CONFIG SÜRÜYOR
insert into public.app_config (key, value) values
  ('ff_pair_streak', 'true'), ('ff_multi_capture', 'false')
on conflict (key) do update set value = excluded.value;

select is((select ff_pair_streak from public.feature_flags()), true,
          'ff_pair_streak app_config''ten açılıyor');
select is((select ff_multi_capture from public.feature_flags()), false,
          'ff_multi_capture app_config''ten KAPATILIYOR — kill switch çalışıyor');

-- Kısa ve sayısal biçimler de tanınıyor: değeri elle giren insan hangisini
-- yazacağını hatırlamak zorunda kalmasın.
update public.app_config set value = 't'  where key = 'ff_pair_streak';
select is((select ff_pair_streak from public.feature_flags()), true,
          '''t'' biçimi tanınıyor');
insert into public.app_config (key, value) values ('ff_ad_reward', '0')
on conflict (key) do update set value = excluded.value;
select is((select ff_ad_reward from public.feature_flags()), false,
          '''0'' biçimi tanınıyor');

-- TANINMAYAN DEĞER → VARSAYILAN, sessiz kapatma DEĞİL.
update public.app_config set value = 'evet' where key = 'ff_multi_capture';
select is((select ff_multi_capture from public.feature_flags()), true,
          'tanınmayan değer varsayılana düşüyor, özelliği SESSİZCE kapatmıyor');

-- ============================================================== GÖRÜNÜM
select tests.authenticate_as('alice');

select is((select ff_pair_streak from public.my_daily_state), true,
          'görünüm bayrağı app_config''ten taşıyor');
select is((select ff_ad_reward from public.my_daily_state), false,
          'görünüm kapatılmış bayrağı false olarak taşıyor');

-- Davranış iddiası: kapalı fonksiyon çalışma zamanında da reddediyor.
select throws_ok(
  $$ select public.config_bool('ff_pair_streak', false) $$,
  '42501',
  NULL,
  'config_bool çalışma zamanında da 42501 — katalog ve davranış uyumlu'
);

select * from finish();
rollback;
