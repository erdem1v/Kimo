-- 140 — Lig: altı kademe, 30 kişilik kohort (0039)
--
-- Geçişin en kırılgan yeri `elmas` adının ANLAM DEĞİŞTİRMESİ: eski yapıda 4.,
-- yeni yapıda 6. kademe. Eşleme sıraya göre ve tek yönde yapılmak zorundaydı;
-- bu dosya sonucun doğru olduğunu doğruluyor.

begin;
set search_path to public, extensions, tests;

select plan(19);

select tests.create_supabase_user('alice');

-- ============================================================== KISIT
select is(
  (select count(*)::int
     from pg_constraint con
     join pg_class c on c.oid = con.conrelid
    where c.relname = 'profiles'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%league%'),
  1,
  'profiles.league üzerinde tam bir CHECK var'
);

select tests.reset_role();

select lives_ok(
  format('update public.profiles set league = ''platin'' where id = %L',
         tests.get_supabase_uid('alice')),
  'platin geçerli bir kademe'
);
select lives_ok(
  format('update public.profiles set league = ''zumrut'' where id = %L',
         tests.get_supabase_uid('alice')),
  'zumrut geçerli bir kademe'
);
select lives_ok(
  format('update public.profiles set league = ''elmas'' where id = %L',
         tests.get_supabase_uid('alice')),
  'elmas geçerli bir kademe (artık TEPE kademe)'
);
select throws_ok(
  format('update public.profiles set league = ''efsane'' where id = %L',
         tests.get_supabase_uid('alice')),
  '23514',
  'efsane ARTIK GEÇERSİZ — eski kademe adı kabul edilmiyor'
);

-- ======================================================= sıra ve etiketler
select is(public.league_rank('bronz'),  1, 'bronz 1. kademe');
select is(public.league_rank('gumus'),  2, 'gümüş 2. kademe');
select is(public.league_rank('altin'),  3, 'altın 3. kademe');
select is(public.league_rank('platin'), 4, 'platin 4. kademe — eski elmasın yeri');
select is(public.league_rank('zumrut'), 5, 'zümrüt 5. kademe — eski efsanenin yeri');
select is(public.league_rank('elmas'),  6, 'elmas 6. kademe');
select is(public.league_label('zumrut'), 'Zümrüt', 'zumrut etiketi doğru');

-- =========================================================== kohort boyutu
select is(public.league_cohort_size(), 30, 'kohort 30 kişilik');
select ok(
  public.league_cohort_size() > 5 + 5,
  'kohort ilk 5 ile son 5''i birlikte barındıracak kadar büyük — '
  'aksi hâlde aynı kişi hem çıkıp hem düşerdi'
);

-- ================================================= terfi ve düşme zincirleri
-- `settle_past_leagues` doğrudan çağrılamıyor (yetki kapalı); mantığı geçmiş
-- haftadan bir kohort kurup tetikleyerek doğruluyoruz.
select tests.reset_role();

insert into public.league_cohorts (id, tier, week_start)
values ('11111111-1111-1111-1111-111111111111', 'altin',
        (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date - 7);

-- 12 kişilik geçmiş kohort: 1. sıradaki terfi etmeli, sonuncusu düşmeli.
-- Kullanıcılar `tests.create_supabase_user` ile kuruluyor: auth.users'a elle
-- INSERT etmek NOT NULL sütunları (instance_id, aud, role…) atlar ve
-- on_auth_user_created tetikleyicisi profil satırını yaratamaz.
do $fx$
declare
  i    int;
  v_id uuid;
begin
  for i in 1..12 loop
    v_id := tests.create_supabase_user('lig' || i);
    update public.profiles set league = 'altin' where id = v_id;
    insert into public.league_members (cohort_id, user_id, xp)
    values ('11111111-1111-1111-1111-111111111111', v_id, 1000 - i * 10);
  end loop;
end
$fx$;

select public.settle_past_leagues();

select is(
  (select p.league
     from public.league_members m
     join public.profiles p on p.id = m.user_id
    where m.cohort_id = '11111111-1111-1111-1111-111111111111'
    order by m.xp desc
    limit 1),
  'platin',
  'kohortun birincisi altından PLATİNE çıktı (yeni zincir)'
);

select is(
  (select p.league
     from public.league_members m
     join public.profiles p on p.id = m.user_id
    where m.cohort_id = '11111111-1111-1111-1111-111111111111'
    order by m.xp asc
    limit 1),
  'gumus',
  'kohortun sonuncusu altından GÜMÜŞE düştü'
);

select is(
  (select count(*)::int
     from public.league_members m
     join public.profiles p on p.id = m.user_id
    where m.cohort_id = '11111111-1111-1111-1111-111111111111'
      and p.league = 'platin'),
  5,
  'tam 5 kişi terfi etti'
);

select is(
  (select count(*)::int
     from public.league_members m
     join public.profiles p on p.id = m.user_id
    where m.cohort_id = '11111111-1111-1111-1111-111111111111'
      and p.league = 'gumus'),
  5,
  'tam 5 kişi düştü'
);

select ok(
  (select settled_at is not null from public.league_cohorts
    where id = '11111111-1111-1111-1111-111111111111'),
  'kohort kapatıldı'
);

select * from finish();
rollback;
