-- 040 — "Kaldırıldı" depolama katmanında da geçerli (Değişmez 3)
--
-- moderate_report ve admin_question_action yalnızca moderation='removed'
-- yazıyordu; is_public'e BİLEREK dokunmuyorlardı ("sahibinin paylaşım niyeti
-- korunsun"). Ama can_read_mistake_photo moderation'a hiç bakmıyor, yalnızca
-- is_public'e bakıyordu. Sonuç: `inappropriate` / `personal_info` diye
-- kaldırılmış bir sorunun fotoğrafı hâlâ TÜM oturum açmış kullanıcılara
-- imzalanabiliyordu.
--
-- Bu dosya iki şeyi birden tutuyor: kaldırılan içerik kapanıyor, ve moderatör
-- inceleme yapabilmek için görmeye devam ediyor.

begin;
set search_path to public, extensions, tests;

select plan(12);

select tests.create_supabase_user('alice');     -- soru sahibi
select tests.create_supabase_user('mallory');   -- sıradan kullanıcı
select tests.create_supabase_user('mod');       -- moderatör

insert into public.admins (user_id) values (tests.get_supabase_uid('mod'));

insert into public.mistakes
  (user_id, subject, concept, mistake_type, photo_path, options, correct_index, is_public)
values
  (tests.get_supabase_uid('alice'), 'Biyoloji', 'Mitoz', 'kavram_eksikligi',
   tests.get_supabase_uid('alice')::text || '/soru.jpg',
   '[{"label":"A","text":"1"}]'::jsonb, 0, true);

insert into storage.objects (bucket_id, name)
values ('mistake-photos', tests.get_supabase_uid('alice')::text || '/soru.jpg');

-- ==================================================== ÖNCE: her şey normal
select tests.authenticate_as('mallory');
select is(public.can_read_mistake_photo(
            tests.get_supabase_uid('alice')::text || '/soru.jpg'),
          true, 'moderation=ok iken havuz fotoğrafı okunabiliyor');
select isnt_empty(
  format('select 1 from storage.objects where name = %L',
         tests.get_supabase_uid('alice')::text || '/soru.jpg'),
  'moderation=ok iken depolama katmanında da görünüyor'
);

-- ==================================================== KALDIR
select tests.reset_role();
update public.mistakes set moderation = 'removed'
 where user_id = tests.get_supabase_uid('alice');

-- ★ Değişmez 3: kimse okuyamaz — is_public HÂLÂ true olmasına rağmen.
select is(
  (select is_public from public.mistakes
    where user_id = tests.get_supabase_uid('alice')),
  true,
  'is_public hâlâ true (paylaşım niyeti korunuyor — mevcut tasarım kararı)'
);

select tests.authenticate_as('mallory');
select is(public.can_read_mistake_photo(
            tests.get_supabase_uid('alice')::text || '/soru.jpg'),
          false, 'KALDIRILDI: yabancı artık okuyamıyor');
select is_empty(
  format('select 1 from storage.objects where name = %L',
         tests.get_supabase_uid('alice')::text || '/soru.jpg'),
  'KALDIRILDI: depolama katmanında da görünmüyor'
);

-- Sahibi bile okuyamaz. init göçündeki "Kendi fotolarını gör" politikası AYRI
-- bir permissive SELECT politikasıydı ve OR'landığı için sahibi kendi
-- klasöründeki her şeyi okuyabiliyordu; 0030 onu kaldırdı.
select tests.authenticate_as('alice');
select is(public.can_read_mistake_photo(
            tests.get_supabase_uid('alice')::text || '/soru.jpg'),
          false, 'KALDIRILDI: sahibi de okuyamıyor (Değişmez 3)');
select is_empty(
  format('select 1 from storage.objects where name = %L',
         tests.get_supabase_uid('alice')::text || '/soru.jpg'),
  'KALDIRILDI: sahibi için de depolama katmanı kapalı'
);

-- Moderatör inceleme yapabilmeli.
select tests.authenticate_as('mod');
select is(public.can_read_mistake_photo(
            tests.get_supabase_uid('alice')::text || '/soru.jpg'),
          true, 'moderatör kaldırılmış içeriği inceleyebiliyor');

-- ==================================================== temizlik kuyruğu
select is(
  (select count(*)::int from public.admin_photo_purge_queue()),
  1,
  'temizlik kuyruğu kaldırılmış ama nesnesi duran içeriği listeliyor'
);

select lives_ok(
  format('select public.admin_mark_photo_purged(%L)',
         (select id from public.mistakes
           where user_id = tests.get_supabase_uid('alice'))),
  'moderatör temizlendi işareti koyabiliyor'
);
select is(
  (select count(*)::int from public.admin_photo_purge_queue()),
  0,
  'işaretlenen içerik kuyruktan düşüyor'
);

-- Sıradan kullanıcı kuyruğa erişemez.
select tests.authenticate_as('mallory');
select is(
  (select count(*)::int from public.admin_photo_purge_queue()),
  0,
  'sıradan kullanıcı temizlik kuyruğunu göremiyor'
);

select * from finish();
rollback;
