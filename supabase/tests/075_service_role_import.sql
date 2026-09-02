-- 075 — service_role duman testi: içe aktarıcı hâlâ çalışıyor mu?
--
-- tools/bin/supabase_admin.dart, SUPABASE_SERVICE_KEY ile ham REST üzerinden
-- mistakes'e user_id / photo_path / is_public / source / source_year /
-- source_session yazıyor (11.000 soruluk MEB + ÖSYM içe aktarımı). Bu kolonların
-- hepsi 0026'da `authenticated` için kilitlendi.
--
-- Sütun ayrıcalıkları rol bazlıdır ve `revoke ... from public, anon,
-- authenticated` service_role'e dokunmamalı. AMA: eğer service_role'ün yetkisi
-- yalnızca PUBLIC üzerinden geliyorsa, `revoke ... from public` onu da keserdi.
-- Supabase service_role'e açık grant veriyor, yani beklenen sonuç "etkilenmedi" —
-- fakat bunu VARSAYMAK yerine İDDİA ediyoruz. İçe aktarıcının kırıldığını üç ay
-- sonra öğrenmek istemiyoruz.

begin;
set search_path to public, extensions, tests;

select plan(11);

select ok(has_table_privilege('service_role', 'public.mistakes', 'INSERT'),
          'service_role mistakes''e insert edebiliyor');

select ok(has_column_privilege('service_role', 'public.mistakes', 'user_id', 'INSERT'),
          'service_role user_id yazabiliyor (içe aktarıcı sahibi elle veriyor)');
select ok(has_column_privilege('service_role', 'public.mistakes', 'photo_path', 'INSERT'),
          'service_role photo_path yazabiliyor');
select ok(has_column_privilege('service_role', 'public.mistakes', 'is_public', 'INSERT'),
          'service_role is_public yazabiliyor (hazır sorular havuza açık gelir)');
select ok(has_column_privilege('service_role', 'public.mistakes', 'source', 'INSERT'),
          'service_role source yazabiliyor');
select ok(has_column_privilege('service_role', 'public.mistakes', 'source_year', 'INSERT'),
          'service_role source_year yazabiliyor');
select ok(has_column_privilege('service_role', 'public.mistakes', 'source_session', 'INSERT'),
          'service_role source_session yazabiliyor');
select ok(has_column_privilege('service_role', 'public.mistakes', 'correct_index', 'INSERT'),
          'service_role correct_index yazabiliyor');

-- Yetim fotoğraf temizleyicisi (prune_orphans) mistakes''i okuyup satır siliyor.
select ok(has_table_privilege('service_role', 'public.mistakes', 'SELECT'),
          'service_role mistakes okuyabiliyor (prune_orphans yol karşılaştırması)');

-- app_config''ten osym_user_id okunuyor (supabase_admin.dart:40).
select ok(has_table_privilege('service_role', 'public.app_config', 'SELECT'),
          'service_role app_config okuyabiliyor (osym_user_id)');

-- Sistem hesabını işaretleyen fonksiyon yalnızca service_role/postgres için.
select ok(not has_function_privilege('authenticated',
            'public.set_osym_account(uuid)', 'EXECUTE'),
          'set_osym_account authenticated''a kapalı (0025 kararı korundu)');

select * from finish();
rollback;
