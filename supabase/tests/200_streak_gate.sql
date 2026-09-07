-- 200 — Etkin seri: kopan seri her okuma yüzeyinde 0 görünür (0047/0048)
--
-- Ürün kuralı: `profiles.streak` yalnızca cevap geldiğinde güncellenir; 40
-- gündür girmeyen kullanıcının satırında bayat bir 40 durur. Dışarı veren
-- her yüzey (profiles_public, my_league_board, my_daily_state) bu sayıyı
-- `last_activity_date >= istanbul_day() - 1` şartıyla kapılamak ZORUNDA —
-- aksi hâlde kopmuş seri arkadaş listesinde canlı görünür.

begin;
set search_path to public, extensions, tests;

select plan(11);

select tests.create_supabase_user('gazi');
select tests.create_supabase_user('seyirci');

-- ============================================================== kurulum
select tests.reset_role();

-- Bayat seri: 30 günlük sayı, 5 gün önce son aktivite.
update public.profiles
   set streak = 30,
       last_activity_date = public.istanbul_day() - 5,
       nickname = 'gazi'
 where id = tests.get_supabase_uid('gazi');

-- Aynı haftanın kohortuna elle üye yap (my_league_board o kohortu okusun).
insert into public.league_cohorts (id, tier, week_start)
values ('11111111-2222-3333-4444-555555555555', 'bronz',
        (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date);
insert into public.league_members (cohort_id, user_id, xp)
values ('11111111-2222-3333-4444-555555555555',
        tests.get_supabase_uid('gazi'), 10);

-- ====================================================== bayat → 0 görünür
select tests.authenticate_as('seyirci');

select is(
  (select p.streak from public.profiles_public p
    where p.id = tests.get_supabase_uid('gazi')),
  0,
  'profiles_public: 5 gün önceki 30''luk seri BAŞKALARINA 0 görünür'
);

select tests.authenticate_as('gazi');

select is(
  (select s.streak from public.my_daily_state s),
  0,
  'my_daily_state: bayat seri sahibine de 0 görünür (HUD yalan söylemez)'
);

select is(
  (select b.streak from public.my_league_board() b
    where b.user_id = tests.get_supabase_uid('gazi')),
  0,
  'my_league_board: lig tahtasında da 0'
);

select is(
  (select s.last_activity_date from public.my_daily_state s),
  public.istanbul_day() - 5,
  'my_daily_state son aktivite gününü olduğu gibi veriyor (istemci maskesi '
  'artık sunucunun söylediği günden besleniyor)'
);

select is(
  (select s.today from public.my_daily_state s),
  public.istanbul_day(),
  'my_daily_state günün tek tanımını (Istanbul) veriyor'
);

-- ================================================= dünkü aktivite → yaşıyor
select tests.reset_role();
update public.profiles
   set last_activity_date = public.istanbul_day() - 1
 where id = tests.get_supabase_uid('gazi');

select tests.authenticate_as('seyirci');
select is(
  (select p.streak from public.profiles_public p
    where p.id = tests.get_supabase_uid('gazi')),
  30,
  'dün aktifse seri yaşıyor: 30 görünür'
);

select tests.authenticate_as('gazi');
select is(
  (select s.streak from public.my_daily_state s),
  30,
  'HUD da 30 gösteriyor'
);
select is(
  (select b.streak from public.my_league_board() b
    where b.user_id = tests.get_supabase_uid('gazi')),
  30,
  'lig tahtası da 30'
);

-- ==================================================== bugün aktif → yaşıyor
select tests.reset_role();
update public.profiles
   set last_activity_date = public.istanbul_day()
 where id = tests.get_supabase_uid('gazi');

select tests.authenticate_as('gazi');
select is(
  (select s.streak from public.my_daily_state s),
  30,
  'bugün aktifse 30 görünür'
);

-- ============================================ yazma yolu etkilenmedi (0043)
-- apply_progress boşluk görünce zaten 1'e döndürüyor; milestone tetikleyicisi
-- görünümlerden değil TABLODAN okuduğu için kapılamadan etkilenmez. Bayat 30
-- tabloya 30 olarak yazılı kalır — kapılama yalnız okuma katmanında.
select tests.reset_role();
select is(
  (select streak from public.profiles
    where id = tests.get_supabase_uid('gazi')),
  30,
  'tablodaki ham değer DEĞİŞMEDİ — kapılama okuma katmanında'
);

-- weekly_xp kapısı da my_daily_state'e geldi (0048): geçen haftanın XP'si
-- HUD'a sızmaz.
update public.profiles
   set weekly_xp = 500,
       week_start = (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date - 7
 where id = tests.get_supabase_uid('gazi');

select tests.authenticate_as('gazi');
select is(
  (select s.weekly_xp from public.my_daily_state s),
  0,
  'geçen haftanın weekly_xp''si HUD''da 0 görünür'
);

select * from finish();
rollback;
