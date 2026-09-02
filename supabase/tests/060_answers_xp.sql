-- 060 — Sunucu otoriteli cevaplama ve XP (C3 + P1)
--
-- Eskiden tek bir istek yetiyordu:
--     PATCH /rest/v1/profiles {"xp": 999999, "weekly_xp": 999999}
-- ve sync_league_member_xp trigger'ı bunu grup sıralamasına da yansıtıyordu.
-- Ayrıca study_attempts.correct ile question_attempts.correct istemci beyanıydı.
--
-- Bu dosya hem kilidi hem de meşru akışın hâlâ çalıştığını tutuyor.

begin;
set search_path to public, extensions, tests;

select plan(26);

select tests.create_supabase_user('alice');    -- soru sahibi
select tests.create_supabase_user('mallory');  -- çözen

insert into public.mistakes
  (user_id, subject, concept, extra_concepts, mistake_type, photo_path,
   options, correct_index, is_public)
values
  (tests.get_supabase_uid('alice'), 'Fizik', 'Kuvvet', array['Newton'],
   'islem_hatasi', tests.get_supabase_uid('alice')::text || '/q.jpg',
   '[{"label":"A","text":"1"},{"label":"B","text":"2"}]'::jsonb, 1, true);

-- ============================================ KATALOG: doğrudan yazma kapalı
select ok(not has_column_privilege('authenticated', 'public.profiles', 'xp', 'UPDATE'),
          'xp doğrudan yazılamaz');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'weekly_xp', 'UPDATE'),
          'weekly_xp doğrudan yazılamaz (lig sıralaması sahtelenemez)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'streak', 'UPDATE'),
          'streak doğrudan yazılamaz');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'last_activity_date', 'UPDATE'),
          'last_activity_date doğrudan yazılamaz');
select ok(not has_table_privilege('authenticated', 'public.study_attempts', 'INSERT'),
          'study_attempts''e doğrudan satır eklenemez');
select ok(not has_table_privilege('authenticated', 'public.question_attempts', 'INSERT'),
          'question_attempts''e doğrudan satır eklenemez');
select ok(not has_column_privilege('authenticated', 'public.question_sends', 'correct', 'UPDATE'),
          'question_sends.correct doğrudan yazılamaz');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'is_public', 'UPDATE'),
          'is_public doğrudan güncellenemez (set_question_sharing üzerinden)');
-- İmza Task 02'de değişti (0041): `p_correct` eklendi, kombo orada hesaplanıyor.
-- Eski imzayla yazılsaydı test "fonksiyon yok" diye HATA verirdi — kırmızı
-- olurdu ama sebebi güvenlik değil, bakımsızlık olurdu.
select ok(not has_function_privilege('authenticated',
            'public.apply_progress(int,boolean,date,boolean)', 'EXECUTE'),
          'apply_progress çağrılamaz (keyfi XP yazma primitifi olurdu)');

-- correct_index artık havuz yükünde yok.
select hasnt_column('public'::name, 'public_questions'::name, 'correct_index'::name,
                    'public_questions correct_index döndürmüyor');

-- ============================================ DAVRANIŞ: kilit
select tests.authenticate_as('mallory');

select throws_ok(
  format('update public.profiles set xp = 999999 where id = %L',
         tests.get_supabase_uid('mallory')),
  '42501',
  'C3: kullanıcı kendine XP yazamıyor'
);
select throws_ok(
  format('insert into public.study_attempts (user_id, subject, concept, correct, source)
          values (%L, ''Uydurma'', ''Konu'', true, ''review'')',
         tests.get_supabase_uid('mallory')),
  '42501',
  'P1: uydurma konu ölçümü eklenemiyor'
);

-- ============================================ DAVRANIŞ: meşru akış
-- Yanlış cevap: XP yok ama deneme kaydediliyor.
select is(
  (select xp_awarded from public.submit_pool_answer(
     (select id from public.mistakes where concept = 'Kuvvet'), 0)),
  0,
  'yanlış cevap XP vermiyor'
);
select is(
  (select xp from public.profiles where id = tests.get_supabase_uid('mallory')),
  0,
  'yanlış cevaptan sonra toplam XP hâlâ 0'
);

-- Aynı soruyu tekrar cevaplamak ikinci kez XP vermez (question_attempts PK).
select is(
  (select xp_awarded from public.submit_pool_answer(
     (select id from public.mistakes where concept = 'Kuvvet'), 1)),
  0,
  'aynı soru ikinci kez XP vermiyor (doğru cevapla bile)'
);

-- Doğru cevabın gerçekten puan verdiğini ayrı bir soruyla göster.
select tests.reset_role();
insert into public.mistakes
  (user_id, subject, concept, mistake_type, photo_path, options, correct_index, is_public)
values
  (tests.get_supabase_uid('alice'), 'Kimya', 'Mol', 'kavram_eksikligi',
   tests.get_supabase_uid('alice')::text || '/q2.jpg',
   '[{"label":"A","text":"1"},{"label":"B","text":"2"}]'::jsonb, 0, true);

select tests.authenticate_as('mallory');
select is(
  (select xp_awarded from public.submit_pool_answer(
     (select id from public.mistakes where concept = 'Mol'), 0)),
  10,
  'doğru cevap 10 XP veriyor'
);
select is(
  (select xp from public.profiles where id = tests.get_supabase_uid('mallory')),
  10,
  'toplam XP sunucuda arttı'
);
select is(
  (select streak from public.profiles where id = tests.get_supabase_uid('mallory')),
  1,
  'seri sunucuda 1 oldu (ilk aktivite)'
);
select is(
  (select correct_index from public.submit_pool_answer(
     (select id from public.mistakes where concept = 'Mol'), 0)),
  0,
  'doğru şık YANITTA dönüyor (soruyla birlikte değil)'
);

-- Ölçüm sorunun KENDİ konusundan yazıldı — istemcinin gönderdiğinden değil.
select is(
  (select count(*)::int from public.study_attempts
    where user_id = tests.get_supabase_uid('mallory') and concept = 'Mol'),
  1,
  'ölçüm sorunun kendi konusuna yazıldı'
);
-- İlk sorunun ek konusu da işlendi (harita ikisini birden doldurur).
select is(
  (select count(*)::int from public.study_attempts
    where user_id = tests.get_supabase_uid('mallory') and concept = 'Newton'),
  1,
  'ek konu da ölçüme yazıldı'
);

-- ============================================ paylaşım / profil RPC'leri
select tests.authenticate_as('alice');
select lives_ok(
  format('select public.set_question_sharing(%L, false)',
         (select id from public.mistakes where concept = 'Kuvvet')),
  'sahibi paylaşımı geri çekebiliyor'
);

select tests.reset_role();
update public.mistakes set moderation = 'removed' where concept = 'Kuvvet';
select tests.authenticate_as('alice');
select throws_ok(
  format('select public.set_question_sharing(%L, true)',
         (select id from public.mistakes where concept = 'Kuvvet')),
  '42501',
  'kaldırılmış içerik havuza geri açılamıyor'
);

select throws_ok(
  'select public.upsert_my_profile(''a'')',
  '22023',
  'çok kısa takma ad reddediliyor'
);
select lives_ok(
  'select public.upsert_my_profile(''Ayşe K'')',
  'geçerli takma ad kabul ediliyor'
);

-- Sistem hesabı kimliğinin taklidi (yeni bulgu).
select tests.reset_role();
update public.profiles set is_system = true, nickname = 'ÖSYM Çıkmış Sorular'
 where id = tests.get_supabase_uid('alice');
select tests.authenticate_as('mallory');
select throws_ok(
  'select public.upsert_my_profile(''ÖSYM Çıkmış Sorular'')',
  '22023',
  'sistem hesabının adı taklit edilemiyor'
);

select * from finish();
rollback;
