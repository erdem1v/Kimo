-- 230 — Lig yerleşimi: küme-tabanlı dağıtım + ucuz fallback + cron (0051)
--
-- Ürün kuralı: haftanın kohortları zamanlanmış işle kurulur (Pazartesi
-- 00:05 Istanbul); kullanıcı sekme açılışı asla tüm nüfusu dolaşmaz. Hafta
-- ortası gelen yeni kullanıcı `ensure_league_membership` ile YALNIZCA kendini
-- yerleştirir.

begin;
set search_path to public, extensions, tests;

select plan(10);

select tests.create_supabase_user('takim_a');
select tests.create_supabase_user('takim_b');
select tests.create_supabase_user('hayalet');   -- anonim: dışarıda kalmalı

select tests.reset_role();
update public.profiles set is_anonymous = true
 where id = tests.get_supabase_uid('hayalet');

-- ================================================ haftalık iş: tam kapsama
select public.league_weekly_rollover();

select is(
  (select count(*)::int
     from public.league_members m
     join public.league_cohorts c on c.id = m.cohort_id
    where c.week_start = (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date),
  2,
  'rollover iki gerçek kullanıcıyı da yerleştirdi'
);

select is(
  (select count(*)::int from public.league_members m
    where m.user_id = tests.get_supabase_uid('hayalet')),
  0,
  'anonim kullanıcı kohorta GİRMEDİ (0046 kararı korunuyor)'
);

-- İkinci koşum bir şey değiştirmez (idempotent).
select public.league_weekly_rollover();
select is(
  (select count(*)::int from public.league_members),
  2,
  'ikinci koşum kopya üye üretmedi'
);

-- Aynı ligdeki iki kullanıcı AYNI kohorta oturdu (30 kişilik kapasite).
select is(
  (select count(distinct m.cohort_id)::int from public.league_members m),
  1,
  'aynı ligin iki kullanıcısı tek kohortta'
);

-- ============================================== hafta ortası: ucuz fallback
select tests.create_supabase_user('yeni_gelen');
select tests.create_supabase_user('sekmesiz');   -- lig sekmesini hiç açmayan

select tests.authenticate_as('yeni_gelen');
select ok(
  public.ensure_league_membership() is not null,
  'hafta ortası gelen kullanıcı kendini yerleştirebiliyor'
);

select is(
  (select count(*)::int from public.league_members m
    where m.user_id = tests.get_supabase_uid('yeni_gelen')),
  1,
  'yeni gelen kohortta'
);

-- KRİTİK: fallback yalnızca ÇAĞIRANI yerleştirir. Eski sürüm burada tüm
-- nüfusu dolaşıyordu ve "sekmesiz" de yerleşirdi.
select is(
  (select count(*)::int from public.league_members m
    where m.user_id = tests.get_supabase_uid('sekmesiz')),
  0,
  'fallback başka kullanıcıyı YERLEŞTİRMEDİ (O(N) döngü kapandı)'
);

-- Yeni gelen mevcut kohortun boş koltuğuna oturdu; yeni kohort açılmadı.
select is(
  (select count(*)::int from public.league_cohorts),
  1,
  'kapasite varken yeni kohort açılmadı'
);

-- ================================================= cron kayıtları
select tests.reset_role();
select is(
  (select count(*)::int from cron.job
    where jobname = 'league-weekly-rollover'),
  1,
  'haftalık lig işi zamanlanmış'
);
select is(
  (select count(*)::int from cron.job
    where jobname in ('scan-photos-sweep', 'cleanup-anonymous-daily')),
  2,
  'tarama süpürmesi ve anonim temizlik işleri zamanlanmış'
);

select * from finish();
rollback;
