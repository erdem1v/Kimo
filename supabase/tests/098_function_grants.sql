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

select plan(35);

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
select ok(has_function_privilege('authenticated',
            'public.is_blocked_between(uuid,uuid)', 'EXECUTE'),
          'is_blocked_between AÇIK (engel kontrolü politikaların içinde)');
select ok(has_function_privilege('authenticated', 'public.is_admin()', 'EXECUTE'),
          'is_admin AÇIK (istemci rpc(''is_admin'') çağırıyor)');
-- Yerel hatırlatmaların metinleri veritabanında (0055) ve cihaz çevrimdışıyken
-- de planlıyor: bu kapanırsa hatırlatmalar nötr yedek cümleye düşer, yani
-- persona sistemi sessizce devre dışı kalır.
select ok(has_function_privilege('authenticated',
            'public.notification_lines()', 'EXECUTE'),
          'notification_lines AÇIK (yerel bildirim metinlerinin tek kapısı)');
-- BU İKİ İDDİA TERSİNE ÇEVRİLDİ (0092). Gerekçeleri — "havuz ekranı" ve
-- "müfredat haritası" — artık var olmayan ekranlardı: havuz Task 02'de
-- arşive alındı ve ikisinin de TEK çağıranı `lib/_archive/pool/`de. Yani
-- yeşil iki iddia, olmayan bir dünyanın yetkilerini savunuyordu; havuz v2'ye
-- kadar açık kalmaları yalnızca saldırı yüzeyiydi.
select ok(not has_function_privilege('authenticated',
            'public.random_public_questions(int)', 'EXECUTE'),
          'random_public_questions KAPALI (havuz arşivde)');
select ok(not has_function_privilege('authenticated',
            'public.available_question_counts()', 'EXECUTE'),
          'available_question_counts KAPALI (müfredat haritası arşivde)');
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

-- Task 07 (0062/0063). Kapalı olması gerekenler önce: tetikleyici fonksiyonu
-- açık olsaydı herkes istediği kullanıcı için ihlal kaydı uydurabilirdi.
select ok(not has_function_privilege('authenticated',
            'public.mistakes_photo_violation()', 'EXECUTE'),
          'mistakes_photo_violation KAPALI (tetikleyici; ihlal uydurulamaz)');
-- is_suspended DÖRT politikanın içinde çağrılıyor; kapanırsa fotoğraf yükleme,
-- soru gönderme ve arkadaşlık isteği birden çöker.
select ok(has_function_privilege('authenticated',
            'public.is_suspended(uuid)', 'EXECUTE'),
          'is_suspended AÇIK (politika ifadeleri çağırıyor)');
select ok(has_function_privilege('authenticated',
            'public.my_sanction()', 'EXECUTE'),
          'my_sanction AÇIK (askı ekranı ve itiraz yolu)');
select ok(has_function_privilege('authenticated',
            'public.my_photo_warnings()', 'EXECUTE'),
          'my_photo_warnings AÇIK (ihlal uyarısı)');
select ok(has_function_privilege('authenticated',
            'public.ack_photo_warnings()', 'EXECUTE'),
          'ack_photo_warnings AÇIK (kullanıcı uyarıyı okundu işaretler)');
select ok(has_function_privilege('authenticated',
            'public.admin_suspend_user(uuid,text,int,text,text)', 'EXECUTE'),
          'admin_suspend_user AÇIK (yetki içeride is_admin ile)');
select ok(has_function_privilege('authenticated',
            'public.admin_user_sanctions(uuid)', 'EXECUTE'),
          'admin_user_sanctions AÇIK (yetki içeride is_admin ile)');
select ok(has_function_privilege('authenticated',
            'public.accept_legal_terms()', 'EXECUTE'),
          'accept_legal_terms AÇIK (kayıt adımındaki koşul onayı)');
select ok(has_function_privilege('authenticated',
            'public.my_age_status()', 'EXECUTE'),
          'my_age_status AÇIK (my_guardian_status''ın yerini aldı)');

-- ------------------------------------------------------------ Task 10
-- Kota rejimi v2 ve ödüllü reklam. Bu dört satır 098'in kendi işi: "hangi
-- fonksiyon kime açık" sorusunun kanonik yeri burası.
select ok(has_function_privilege('authenticated', 'public.ai_state()', 'EXECUTE'),
          'ai_state AÇIK (my_daily_state''in SELECT listesinde çağrılıyor)');
select ok(not has_function_privilege('authenticated',
            'public.grant_ad_reward(uuid, text, text)', 'EXECUTE'),
          'grant_ad_reward KAPALI — istemci kendine reklam hakkı basamaz');
select ok(has_function_privilege('anon',
            'public.grant_ad_reward(uuid, text, text)', 'EXECUTE'),
          'grant_ad_reward anon''a AÇIK (SSV geri çağrısında JWT yok)');
select ok(not has_function_privilege('authenticated',
            'public.user_tier()', 'EXECUTE'),
          'user_tier KAPALI (katman my_daily_state''ten okunuyor)');

-- ====================================================== DAVRANIŞ
select tests.authenticate_as('alice');
select throws_ok(
  format('select public.send_push(%L, ''friend_request'', ''Sahte Kişi'')',
         tests.get_supabase_uid('alice')),
  '42501', null,
  'kullanıcı doğrudan bildirim gönderemiyor'
);
-- AŞIRI KİLİTLEME KARŞI-İDDİASI. Eskiden `available_question_counts()`
-- çağırıyordu — 0092 onu kapatınca bu iddia da düştü. Yerine GERÇEKTEN CANLI
-- bir yol kondu: `ensure_league_membership` lig sekmesi her açıldığında
-- çağrılıyor (yukarıda AÇIK olduğu ayrıca iddia ediliyor).
select lives_ok(
  'select public.ensure_league_membership()',
  'meşru RPC hâlâ çağrılabiliyor (lig sekmesinin açılış çağrısı)'
);

select * from finish();
rollback;
