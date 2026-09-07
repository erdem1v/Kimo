-- 220 — Fotoğraf içerik taraması: 'clear' olmayan paylaşıma çıkamaz (0050)
--
-- Ürün kuralı: yüklenen görsel makine taramasından geçene kadar YALNIZCA
-- sahibine görünür. Şüpheli işaretlenen içerik paylaşımdan düşer ama sahibi
-- kendi kaydını kullanmaya devam eder (yanlış pozitif kilitlemez). Admin
-- kararı iki yönlü: temiz → paylaşım açılır, kaldır → mevcut purge değişmezi.

begin;
set search_path to public, extensions, tests;

select plan(16);

select tests.create_supabase_user('sahip');
select tests.create_supabase_user('dost');
select tests.create_supabase_user('bekci');

select tests.reset_role();
insert into public.admins (user_id) values (tests.get_supabase_uid('bekci'));
insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('sahip'), tests.get_supabase_uid('dost'),
        'accepted');

-- ============================================== yükleme → pending (trigger)
select tests.authenticate_as('sahip');
insert into public.mistakes
  (subject, concept, photo_path, options, correct_index, is_public)
values ('Tarih', 'İnkılaplar',
        tests.get_supabase_uid('sahip')::text || '/supheli.jpg',
        '[{"label":"A","text":""},{"label":"B","text":""}]'::jsonb, 0, true);

select is(
  (select m.photo_scan from public.mistakes m
    where m.user_id = tests.get_supabase_uid('sahip')),
  'pending',
  'yeni yüklenen fotoğraf pending başlar (istemci ne yazarsa yazsın)'
);

-- ============================================ pending: paylaşım kapalı
select is(
  (select count(*)::int from public.public_questions q
    where q.owner_id = tests.get_supabase_uid('sahip')),
  0,
  'pending fotoğraf havuz görünümünde YOK'
);

select throws_ok(
  format('insert into public.question_sends (sender_id, receiver_id, mistake_id) '
         'values (%L, %L, (select id from public.mistakes where user_id = %L))',
         tests.get_supabase_uid('sahip'), tests.get_supabase_uid('dost'),
         tests.get_supabase_uid('sahip')),
  '42501',
  'pending fotoğraflı soru arkadaşa GÖNDERİLEMEZ'
);

select is(
  public.can_read_mistake_photo(
    tests.get_supabase_uid('sahip')::text || '/supheli.jpg'),
  true,
  'SAHİBİ pending fotoğrafını okumaya devam eder (yanlış pozitif kilitlemez)'
);

select tests.authenticate_as('dost');
select is(
  public.can_read_mistake_photo(
    tests.get_supabase_uid('sahip')::text || '/supheli.jpg'),
  false,
  'havuza açık bile olsa pending fotoğrafı BAŞKASI okuyamaz'
);

-- ================================================== clear: paylaşım açılır
select tests.reset_role();
update public.mistakes set photo_scan = 'clear'
 where user_id = tests.get_supabase_uid('sahip');

select tests.authenticate_as('dost');
select is(
  (select count(*)::int from public.public_questions q
    where q.owner_id = tests.get_supabase_uid('sahip')),
  1,
  'clear olunca havuzda görünür'
);
select is(
  public.can_read_mistake_photo(
    tests.get_supabase_uid('sahip')::text || '/supheli.jpg'),
  true,
  'clear olunca fotoğraf da okunur'
);

select tests.authenticate_as('sahip');
select lives_ok(
  format('insert into public.question_sends (sender_id, receiver_id, mistake_id) '
         'values (%L, %L, (select id from public.mistakes where user_id = %L))',
         tests.get_supabase_uid('sahip'), tests.get_supabase_uid('dost'),
         tests.get_supabase_uid('sahip')),
  'clear olunca arkadaşa gönderilebilir'
);

-- ============================================ flagged: paylaşımdan düşer
select tests.reset_role();
update public.mistakes set photo_scan = 'flagged'
 where user_id = tests.get_supabase_uid('sahip');

select tests.authenticate_as('dost');
select is(
  (select count(*)::int from public.public_questions q
    where q.owner_id = tests.get_supabase_uid('sahip')),
  0,
  'flagged havuzdan düşer'
);
select is(
  (select count(*)::int from public.received_questions),
  0,
  'gönderilmiş olsa bile flagged içerik alıcının kutusundan düşer'
);
select is(
  public.can_read_mistake_photo(
    tests.get_supabase_uid('sahip')::text || '/supheli.jpg'),
  false,
  've fotoğrafı okunamaz'
);

-- ============================================== admin kararı: temiz
select tests.authenticate_as('bekci');
select is(
  (select count(*)::int from public.admin_flagged_photos()),
  1,
  'şüpheli fotoğraf admin kuyruğunda'
);

select lives_ok(
  format('select public.admin_review_photo_scan(
            (select id from public.mistakes where user_id = %L), ''clear'')',
         tests.get_supabase_uid('sahip')),
  'admin temiz işaretleyebiliyor'
);
select tests.authenticate_as('dost');
select is(
  (select count(*)::int from public.public_questions q
    where q.owner_id = tests.get_supabase_uid('sahip')),
  1,
  'temiz kararıyla paylaşım geri açıldı'
);

-- =========================================== admin kararı: kaldır → purge
select tests.authenticate_as('bekci');
select lives_ok(
  format('select public.admin_review_photo_scan(
            (select id from public.mistakes where user_id = %L), ''remove'')',
         tests.get_supabase_uid('sahip')),
  'admin kaldırabiliyor'
);
select is(
  (select count(*)::int from public.admin_photo_purge_queue()),
  1,
  'kaldırma mevcut purge kuyruğuna düştü (Değişmez 3 zinciri aynen işliyor)'
);

select * from finish();
rollback;
