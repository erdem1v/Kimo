-- 190 — Gelen kutusundan silme (0051)
--
-- Tasarımdaki "Sil" düğmesinin sunucu karşılığı. İddia edilenler: sütun
-- kilitli, RPC yalnızca alıcıya çalışıyor, satır GERÇEKTEN silinmiyor
-- (gönderenin kaydı ve moderasyon izi duruyor) ve gizlenmiş satır gelen
-- kutusunda görünmüyor.

begin;
set search_path to public, extensions, tests;

select plan(12);

select tests.create_supabase_user('sender');
select tests.create_supabase_user('receiver');
select tests.create_supabase_user('stranger');

-- ============================================================== YAPI
select has_column('public'::name, 'question_sends'::name, 'dismissed_at'::name,
                  'dismissed_at sütunu var');
select ok(
  not has_column_privilege('authenticated', 'public.question_sends',
                           'dismissed_at', 'UPDATE'),
  'dismissed_at istemciden GÜNCELLENEMEZ — tek yazma yolu RPC'
);
select ok(
  not has_column_privilege('authenticated', 'public.question_sends',
                           'dismissed_at', 'INSERT'),
  'dismissed_at istemciden EKLENEMEZ'
);
select ok(
  not has_function_privilege('public', 'public.dismiss_received_question(uuid)',
                             'EXECUTE'),
  'dismiss_received_question PUBLIC''e kapalı'
);
select ok(
  has_function_privilege('authenticated',
                         'public.dismiss_received_question(uuid)', 'EXECUTE'),
  'dismiss_received_question oturumlu kullanıcıya açık'
);

-- ============================================================== FİKSTÜR
select tests.reset_role();
update public.profiles
   set birth_year = extract(year from now())::int - 25
 where id in (tests.get_supabase_uid('sender'),
              tests.get_supabase_uid('receiver'));

insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('sender'), tests.get_supabase_uid('receiver'),
        'accepted');

insert into public.mistakes
  (user_id, subject, concept, mistake_type, photo_path, options, correct_index)
values (
  tests.get_supabase_uid('sender'), 'Kimya', 'Mol', 'islem_hatasi',
  tests.get_supabase_uid('sender')::text || '/soru.jpg',
  '[{"label":"A","text":"1"},{"label":"B","text":"2"}]'::jsonb, 1
);

-- Fotoğraf taraması (0050): gönderim politikası 'clear' ister.
update public.mistakes set photo_scan = 'clear'
 where user_id = tests.get_supabase_uid('sender');

select tests.authenticate_as('sender');
insert into public.question_sends (sender_id, receiver_id, mistake_id)
values (
  tests.get_supabase_uid('sender'),
  tests.get_supabase_uid('receiver'),
  (select id from public.mistakes
    where user_id = tests.get_supabase_uid('sender') limit 1)
);

-- ============================================================== GÖRÜNÜRLÜK
select tests.authenticate_as('receiver');
select is(
  (select count(*)::int from public.received_questions),
  1,
  'gönderim alıcının kutusunda görünüyor'
);

-- ====================================================== YABANCI GİZLEYEMEZ
select tests.authenticate_as('stranger');
select lives_ok(
  format('select public.dismiss_received_question(%L)',
         (select id from public.question_sends limit 1)),
  'yabancının çağrısı hata VERMİYOR (kimlik yoklamasına kapalı)'
);
select tests.authenticate_as('receiver');
select is(
  (select count(*)::int from public.received_questions),
  1,
  'ama yabancının çağrısı hiçbir şey GİZLEMEDİ'
);

-- ============================================================== GİZLEME
select lives_ok(
  format('select public.dismiss_received_question(%L)',
         (select id from public.question_sends limit 1)),
  'alıcı kendi gelen sorusunu gizleyebiliyor'
);
select is(
  (select count(*)::int from public.received_questions),
  0,
  'gizlenen soru gelen kutusunda GÖRÜNMÜYOR'
);

-- ====================================================== SATIR DURUYOR
select tests.reset_role();
select is(
  (select count(*)::int from public.question_sends),
  1,
  'satır SİLİNMEDİ — gönderenin kaydı ve moderasyon izi duruyor'
);
select isnt(
  (select dismissed_at from public.question_sends limit 1),
  null,
  'dismissed_at damgalandı'
);

select * from finish();
rollback;
