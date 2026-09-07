-- 150 — Engelleme, şikâyet ve anonim oturum (0044 + 0046)
--
-- App Store'un zorunlu üç kontrolü (şikâyet, engelleme, silme) ve kayıt öncesi
-- anonim kullanıcının sosyal yüzeyden dışlanması. İkisi de arayüzde değil
-- SUNUCUDA zorlanmalı: arayüz düğmeyi gizleyebilir ama istek yine atılabilir.

begin;
set search_path to public, extensions, tests;

select plan(17);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('bob');

-- ============================================================== YAPI
select has_table('public'::name, 'user_blocks'::name, 'user_blocks tablosu var');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.user_blocks'::regclass),
  'user_blocks üzerinde RLS açık'
);
select has_column('public'::name, 'profiles'::name, 'is_anonymous'::name,
                  'is_anonymous sütunu var');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'is_anonymous', 'UPDATE'),
          'anonimlik bayrağı istemciden yazılamaz — sosyal yüzeye sızılamaz');

-- ============================================================== FİKSTÜR
select tests.reset_role();
-- İkisi de reşit olsun ki yaş kapısı bu dosyanın konusunu gölgelemesin.
update public.profiles
   set birth_year = extract(year from now())::int - 25
 where id in (tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'));

insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'), 'accepted');

insert into public.mistakes
  (user_id, subject, concept, mistake_type, photo_path, options, correct_index)
values (
  tests.get_supabase_uid('alice'), 'Fizik', 'Kuvvet', 'islem_hatasi',
  tests.get_supabase_uid('alice')::text || '/soru.jpg',
  '[{"label":"A","text":"1"},{"label":"B","text":"2"}]'::jsonb, 0
);

-- Fotoğraf taraması (0050): gönderim politikası 'clear' ister. Canlıda bunu
-- scan-photos süpürücüsü yazar; fikstürde ayrıcalıklı oturum yazıyor.
update public.mistakes set photo_scan = 'clear'
 where user_id = tests.get_supabase_uid('alice');

-- ====================================================== ENGELLEME: GÖNDERİM
select tests.authenticate_as('alice');
select lives_ok(
  format('insert into public.question_sends (sender_id, receiver_id, mistake_id) '
         'values (%L, %L, (select id from public.mistakes where user_id = %L limit 1))',
         tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'),
         tests.get_supabase_uid('alice')),
  'arkadaşlar birbirine soru gönderebiliyor'
);

-- Bob, Alice'i engelliyor.
select tests.authenticate_as('bob');
select lives_ok(
  format('select public.block_user(%L)', tests.get_supabase_uid('alice')),
  'kullanıcı engellenebiliyor'
);

select tests.authenticate_as('alice');
select throws_ok(
  format('insert into public.question_sends (sender_id, receiver_id, mistake_id) '
         'values (%L, %L, (select id from public.mistakes where user_id = %L limit 1))',
         tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'),
         tests.get_supabase_uid('alice')),
  '42501', null,
  'ENGELLENEN kişi artık soru gönderemiyor (arkadaşlık sürse bile)'
);

-- Engel geriye de bakıyor: daha önce gönderilenler de gizleniyor.
select tests.authenticate_as('bob');
select is(
  (select count(*)::int from public.received_questions),
  0,
  'engellenen kişinin ESKİ gönderimleri de gelen kutusunda görünmüyor'
);

-- Engellenen, engellendiğini göremiyor (bildirim de yok).
select tests.authenticate_as('alice');
select is(
  (select count(*)::int from public.user_blocks),
  0,
  'engellenen kişi engel kaydını GÖREMİYOR'
);

-- ====================================================== ENGELLEME: İSTEK
select tests.create_supabase_user('carol');
select tests.reset_role();
update public.profiles
   set birth_year = extract(year from now())::int - 25
 where id = tests.get_supabase_uid('carol');

select tests.authenticate_as('carol');
select lives_ok(
  format('select public.block_user(%L)', tests.get_supabase_uid('alice')),
  'carol da alice''i engelliyor'
);

select tests.authenticate_as('alice');
select throws_ok(
  format('insert into public.friendships (requester_id, addressee_id) values (%L, %L)',
         tests.get_supabase_uid('alice'), tests.get_supabase_uid('carol')),
  '42501', null,
  'engelleyen kişiye arkadaş isteği gönderilemiyor'
);

-- =============================================================== ANONİM
select tests.create_supabase_user('anon_user');
select tests.reset_role();
update public.profiles set is_anonymous = true
 where id = tests.get_supabase_uid('anon_user');

select tests.authenticate_as('alice');
select is(
  (select count(*)::int from public.profiles_public
    where id = tests.get_supabase_uid('anon_user')),
  0,
  'anonim kullanıcı profiles_public''te GÖRÜNMÜYOR'
);

select tests.authenticate_as('anon_user');
select ok(
  not public.can_add_friends(tests.get_supabase_uid('anon_user')),
  'anonim kullanıcı arkadaş ekleyemiyor'
);
select throws_ok(
  format('insert into public.friendships (requester_id, addressee_id) values (%L, %L)',
         tests.get_supabase_uid('anon_user'), tests.get_supabase_uid('bob')),
  '42501', null,
  'SUNUCU reddediyor: anonim hesap arkadaş isteği gönderemiyor'
);

-- Ama kendi hatasını yazabiliyor: kayıt öncesi akışın çalışması bu.
select lives_ok(
  format('insert into public.mistakes (subject, concept, mistake_type) '
         'values (''Kimya'', ''Mol'', ''dikkatsizlik'')'),
  'anonim kullanıcı KENDİ hatasını kaydedebiliyor — kayıt öncesi akış çalışıyor'
);

-- Kohorta girmiyor.
select tests.reset_role();
select public.assign_week_cohorts();
select is(
  (select count(*)::int from public.league_members m
    where m.user_id = tests.get_supabase_uid('anon_user')),
  0,
  'anonim kullanıcı lig kohortuna ATANMIYOR — sıralamayı kirletmiyor'
);
select ok(
  (select count(*)::int from public.league_members m
    where m.user_id = tests.get_supabase_uid('bob')) > 0,
  'kalıcı kullanıcı kohorta atanıyor (kontrol)'
);

select * from finish();
rollback;
