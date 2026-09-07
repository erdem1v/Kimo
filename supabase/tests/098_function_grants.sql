-- 098 — Fonksiyon EXECUTE yetkileri (H7'yi düzeltirken çıkan yeni bulgu)
--
-- Postgres yeni fonksiyonlarda EXECUTE'u PUBLIC'e verir ve `authenticated`
-- PUBLIC'i miras alır. Bu depoda 13 fonksiyona açık grant yazılmış, geri
-- kalanına yazılmamıştı — yani onlar da Data API üzerinden çağrılabiliyordu.
--
-- EN CİDDİSİ: public.send_push. SECURITY DEFINER ve servis rolüyle çalışan edge
-- function'ı tetikliyor. Oturum açmış herhangi biri
--     POST /rest/v1/rpc/send_push {"p_user": "<herhangi biri>", ...}
-- ile İSTEDİĞİ kullanıcıya, istediği senaryo ve aktör adıyla bildirim
-- gönderebiliyordu. H7'nin ta kendisi, yalnızca edge function yerine RPC yüzeyi.
--
-- Bu dosya iki yönü birden tutuyor: kapalı olması gerekenler kapalı, AÇIK olması
-- gerekenler açık. İkincisi olmadan aşırı kilitleme sessizce uygulamayı kırar.

begin;
set search_path to public, extensions, tests;

select plan(20);

select tests.create_supabase_user('alice');

-- ====================================================== KAPALI OLMASI GEREKENLER
select ok(not has_function_privilege('authenticated',
            'public.send_push(uuid,text,text,text)', 'EXECUTE'),
          'send_push authenticated''a KAPALI (keyfi bildirim gönderimi kapandı)');
select ok(not has_function_privilege('anon',
            'public.send_push(uuid,text,text,text)', 'EXECUTE'),
          'send_push anon''a kapalı');
select ok(not has_function_privilege('authenticated',
            'public.settle_past_leagues()', 'EXECUTE'),
          'settle_past_leagues authenticated''a kapalı');
select ok(not has_function_privilege('authenticated',
            'public.assign_week_cohorts()', 'EXECUTE'),
          'assign_week_cohorts authenticated''a kapalı');
select ok(not has_function_privilege('anon',
            'public.set_osym_account(uuid)', 'EXECUTE'),
          'set_osym_account anon''a da kapalı (0025 yalnızca public+authenticated demişti)');
select ok(not has_function_privilege('authenticated',
            'public.handle_new_user()', 'EXECUTE'),
          'handle_new_user Data API yüzeyinde değil');
select ok(not has_function_privilege('authenticated',
            'public.touch_updated_at()', 'EXECUTE'),
          'touch_updated_at Data API yüzeyinde değil');

-- ====================================================== AÇIK KALMASI GEREKENLER
-- can_read_mistake_photo ve are_friends RLS politikalarının İÇİNDE çağrılıyor ve
-- politika ifadeleri ÇAĞIRAN yetkisiyle değerlendiriliyor. Bunlar kapanırsa
-- fotoğraflar ve arkadaşa soru gönderme tamamen çöker.
select ok(has_function_privilege('authenticated',
            'public.can_read_mistake_photo(text)', 'EXECUTE'),
          'can_read_mistake_photo AÇIK (storage politikası bunu çağırıyor)');
select ok(has_function_privilege('authenticated',
            'public.are_friends(uuid,uuid)', 'EXECUTE'),
          'are_friends AÇIK (question_sends politikası bunu çağırıyor)');
select ok(has_function_privilege('authenticated', 'public.is_admin()', 'EXECUTE'),
          'is_admin AÇIK (istemci rpc(''is_admin'') çağırıyor)');
select ok(has_function_privilege('authenticated',
            'public.random_public_questions(int)', 'EXECUTE'),
          'random_public_questions AÇIK (havuz ekranı)');
select ok(has_function_privilege('authenticated',
            'public.available_question_counts()', 'EXECUTE'),
          'available_question_counts AÇIK (müfredat haritası)');
select ok(has_function_privilege('authenticated',
            'public.ensure_league_membership()', 'EXECUTE'),
          'ensure_league_membership AÇIK (lig sekmesi)');
select ok(has_function_privilege('authenticated', 'public.my_league_board()', 'EXECUTE'),
          'my_league_board AÇIK (lig sıralaması)');

-- Task 03 (0050/0051) eklemeleri: tarama açık, haftalık yerleşim kapalı.
select ok(has_function_privilege('authenticated',
            'public.consume_scan_use()', 'EXECUTE'),
          'consume_scan_use AÇIK (scan-photos hızlı yolu)');
select ok(has_function_privilege('authenticated',
            'public.admin_flagged_photos()', 'EXECUTE'),
          'admin_flagged_photos AÇIK (yetki içeride is_admin ile)');
select ok(has_function_privilege('authenticated',
            'public.admin_review_photo_scan(uuid,text)', 'EXECUTE'),
          'admin_review_photo_scan AÇIK (yetki içeride is_admin ile)');
select ok(not has_function_privilege('authenticated',
            'public.league_weekly_rollover()', 'EXECUTE'),
          'league_weekly_rollover KAPALI (yalnızca pg_cron çağırır)');

-- ====================================================== DAVRANIŞ
select tests.authenticate_as('alice');
select throws_ok(
  format('select public.send_push(%L, ''friend_request'', ''Sahte Kişi'')',
         tests.get_supabase_uid('alice')),
  '42501',
  'kullanıcı doğrudan bildirim gönderemiyor'
);
select lives_ok(
  'select public.available_question_counts()',
  'meşru RPC hâlâ çağrılabiliyor'
);

select * from finish();
rollback;
