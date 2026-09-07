-- 210 — my_daily_state v2: gün sayaçları sunucuda, Istanbul takvimiyle (0048)
--
-- İki iddia grubu:
--  • reviewed_today_count Istanbul GÜN SINIRINI kullanır. Eski istemci sayımı
--    yerel geceyarısını offset'siz gönderiyordu ve Türkiye'de sınır fiilen
--    03:00'a kayıyordu; gece 00-03 arasının tekrarları hedefe sayılmıyordu.
--  • due_count / unsolved_received_count satır indirmeden, gelen kutusu
--    süzgeçleriyle tutarlı sayar.

begin;
set search_path to public, extensions, tests;

select plan(10);

select tests.create_supabase_user('caliskan');
select tests.create_supabase_user('gonderen');

select tests.reset_role();

-- ============================================== reviewed_today_count sınırı
-- Istanbul bugününün 01:00'i → SAYILIR; dün 23:00 → SAYILMAZ.
insert into public.mistakes (user_id, subject, concept, last_reviewed_at, next_review_date)
values
  (tests.get_supabase_uid('caliskan'), 'Matematik', 'Türev',
   (public.istanbul_day())::timestamp at time zone 'Europe/Istanbul'
     + interval '1 hour',
   public.istanbul_day() + 3),
  (tests.get_supabase_uid('caliskan'), 'Matematik', 'Limit',
   (public.istanbul_day())::timestamp at time zone 'Europe/Istanbul'
     - interval '1 hour',
   public.istanbul_day() + 3);

select tests.authenticate_as('caliskan');

select is(
  (select s.reviewed_today_count from public.my_daily_state s),
  1,
  'Istanbul 01:00 tekrarı bugüne sayıldı, dün 23:00 sayılmadı — gün sınırı '
  'sunucuda ve Istanbul''da'
);

-- ============================================================== due_count
select tests.reset_role();

insert into public.mistakes (user_id, subject, concept, next_review_date, mastered)
values
  -- vadesi geçmiş → sayılır
  (tests.get_supabase_uid('caliskan'), 'Fizik', 'Vektörler',
   public.istanbul_day() - 2, false),
  -- bugün vadeli → sayılır
  (tests.get_supabase_uid('caliskan'), 'Fizik', 'Kuvvet',
   public.istanbul_day(), false),
  -- yarın vadeli → sayılmaz
  (tests.get_supabase_uid('caliskan'), 'Fizik', 'Enerji',
   public.istanbul_day() + 1, false),
  -- öğrenilmiş → sayılmaz
  (tests.get_supabase_uid('caliskan'), 'Fizik', 'Tork',
   public.istanbul_day() - 1, true);

select tests.authenticate_as('caliskan');

select is(
  (select s.due_count from public.my_daily_state s),
  2,
  'due_count: vadesi geçen + bugünkü sayıldı; yarınki ve öğrenilmiş sayılmadı'
);

-- ============================================= unsolved_received_count
select tests.reset_role();

-- Gönderenin fotoğraflı, şıklı, cevabı işaretli bir sorusu olsun
-- (received_questions görünümünün şartları).
insert into public.mistakes (id, user_id, subject, concept, photo_path,
                             options, correct_index)
values ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeee0001',
        tests.get_supabase_uid('gonderen'), 'Kimya', 'Mol',
        tests.get_supabase_uid('gonderen') || '/soru.jpg',
        '[{"label":"A","text":""},{"label":"B","text":""}]'::jsonb,
        0);

-- Fotoğraf taraması (0050): gelen kutusu ve rozet 'clear' ister.
update public.mistakes set photo_scan = 'clear'
 where id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeee0001';

insert into public.question_sends (id, sender_id, receiver_id, mistake_id)
values ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeee0002',
        tests.get_supabase_uid('gonderen'),
        tests.get_supabase_uid('caliskan'),
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeee0001');

select tests.authenticate_as('caliskan');

select is(
  (select s.unsolved_received_count from public.my_daily_state s),
  1,
  'çözülmemiş gelen soru rozete sayılıyor'
);

-- Çözülünce düşer.
select tests.reset_role();
update public.question_sends set solved_at = now()
 where id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeee0002';

select tests.authenticate_as('caliskan');
select is(
  (select s.unsolved_received_count from public.my_daily_state s),
  0,
  'çözülen soru rozetten düşüyor'
);

-- Kaldırılan (dismiss) soru da sayılmaz — rozet gelen kutusuyla aynı gerçeği
-- göstermeli.
select tests.reset_role();
update public.question_sends
   set solved_at = null, dismissed_at = now()
 where id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeee0002';

select tests.authenticate_as('caliskan');
select is(
  (select s.unsolved_received_count from public.my_daily_state s),
  0,
  'kutudan kaldırılan soru rozette de yok (aynı süzgeç)'
);

-- ============================================================ yapı ve yetki
select tests.reset_role();

select is(
  (select count(*)::int from information_schema.columns
    where table_schema = 'public' and table_name = 'my_daily_state'
      and column_name in ('today','week_start','last_activity_date',
                          'reviewed_today_count','due_count',
                          'unsolved_received_count')),
  6,
  'v2 sütunlarının altısı da görünümde'
);

select ok(has_table_privilege('authenticated', 'public.my_daily_state', 'SELECT'),
          'oturumlu kullanıcı okuyabiliyor');
select ok(not has_table_privilege('anon', 'public.my_daily_state', 'SELECT'),
          'anon okuyamıyor');

-- Görünüm yalnızca KENDİ satırını verir.
select tests.authenticate_as('gonderen');
select is(
  (select count(*)::int from public.my_daily_state),
  1,
  'herkes tek satır görür: kendisininki'
);
select is(
  (select s.user_id from public.my_daily_state s),
  tests.get_supabase_uid('gonderen'),
  've o satır gerçekten kendisi'
);

select * from finish();
rollback;
