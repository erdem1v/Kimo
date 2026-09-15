-- 330 — Lig: kohort boyutuna göre terfi/düşme, çift kohort, engel (0089)
--
-- Bu dosya Task 12 araştırmasının lig bulgularını kilitliyor. Hiçbiri mevcut
-- süitte sınanmıyordu: 140 tam 12 kişilik TEK kohort kuruyor, 230 settle'ı
-- hiç çalıştırmıyor. Kesişim aralığı (6-9 kişi) ve tepe kademe kenar durumu
-- bu yüzden yıllarca görünmedi.
--
-- BU DOSYANIN EN ÖNEMLİ ÜÇ İDDİASI:
--   1. 6-9 kişilik kohortta HİÇ KİMSE düşmüyor. Eskiden terfi (ilk 5) ile
--      düşme (son 5) kesişiyordu ve ikinci UPDATE birincisini eziyordu: hak
--      edilmiş terfi sessizce iptal oluyor, tepe kademede ise ilk-5
--      oyuncusu NET DÜŞÜYORDU.
--   2. Bir kullanıcı aynı hafta İKİ kohorta giremiyor. Eskiden iki
--      yerleştirme yolu FARKLI advisory kilit alıyordu ve hiçbir kısıt yoktu.
--   3. Engellenen kullanıcı lig tahtasında MASKELİ. Satır kalıyor (sıralama
--      ve üye sayısı bozulmasın, engel ele verilmesin), kimlik gitmiyor.
--
-- FİKSTÜRLERDE `created_at` GEÇMİŞE ÇEKİLİYOR: yeni kullanıcı düşme koruması
-- (ilk iki hafta) aksi hâlde her senaryoyu bastırırdı. Korumanın kendisi
-- 4. bölümde ayrıca sınanıyor.

begin;
set search_path to public, extensions, tests;

select plan(16);

select tests.age_all_users();
select tests.skip_topic_check();

select tests.reset_role();

-- ============================================== 1) 6 kişi: çakışma yok
do $fx$
declare i int; v_id uuid;
begin
  insert into public.league_cohorts (id, tier, week_start)
  values ('aaaaaaaa-0006-0000-0000-000000000000', 'altin',
          public.istanbul_week() - 7);
  for i in 1..6 loop
    v_id := tests.create_supabase_user('k6_' || i);
    update public.profiles
       set league = 'altin', created_at = now() - interval '60 days'
     where id = v_id;
    insert into public.league_members (cohort_id, user_id, xp)
    values ('aaaaaaaa-0006-0000-0000-000000000000', v_id, 1000 - i * 10);
  end loop;
end
$fx$;

-- Tetikleyici `week_start`i kohorttan dolduruyor: çağıranların hiçbiri o
-- sütunu yazmıyor ve yazmak zorunda da olmamalı.
select is(
  (select count(distinct week_start)::int from public.league_members
    where cohort_id = 'aaaaaaaa-0006-0000-0000-000000000000'),
  1, 'week_start kohorttan otomatik dolduruldu');

select lives_ok('select public.settle_past_leagues()',
                'settle 6 kişilik kohortta çalışıyor');

select is(
  (select count(*)::int from public.league_members
    where cohort_id = 'aaaaaaaa-0006-0000-0000-000000000000' and move = 'down'),
  0, '6 kişilik kohortta KİMSE düşmedi — kesişim imkânsız');

select is(
  (select count(*)::int from public.league_members
    where cohort_id = 'aaaaaaaa-0006-0000-0000-000000000000' and move = 'up'),
  5, '6 kişilik kohortta ilk 5 terfi etti');

select is(
  (select count(*)::int from public.league_members
    where cohort_id = 'aaaaaaaa-0006-0000-0000-000000000000' and move is null),
  0, 'her üyeye TEK bir sonuç yazıldı — kümeler ayrık');

-- ============================================== 2) tepe kademe (elmas)
-- Eski kuralda terfi `elmas`ta tavanlıydı (`else 'elmas'`) ama düşme
-- `elmas → zumrut` idi: 6 kişilik elmas kohortunda 2. SIRADAKİ düşüyordu.
select tests.reset_role();
do $fx$
declare i int; v_id uuid;
begin
  insert into public.league_cohorts (id, tier, week_start)
  values ('aaaaaaaa-0006-1111-0000-000000000000', 'elmas',
          public.istanbul_week() - 7);
  for i in 1..6 loop
    v_id := tests.create_supabase_user('e6_' || i);
    update public.profiles
       set league = 'elmas', created_at = now() - interval '60 days'
     where id = v_id;
    insert into public.league_members (cohort_id, user_id, xp)
    values ('aaaaaaaa-0006-1111-0000-000000000000', v_id, 1000 - i * 10);
  end loop;
end
$fx$;

select lives_ok('select public.settle_past_leagues()', 'elmas kohortu kapandı');

select is(
  (select count(*)::int from public.profiles p
    join public.league_members m on m.user_id = p.id
   where m.cohort_id = 'aaaaaaaa-0006-1111-0000-000000000000'
     and p.league <> 'elmas'),
  0, 'küçük ELMAS kohortunda kimse düşmedi — tepe kademe kenar durumu kapalı');

-- ============================================== 3) 11 kişi: düşme başlıyor
select tests.reset_role();
do $fx$
declare i int; v_id uuid;
begin
  insert into public.league_cohorts (id, tier, week_start)
  values ('aaaaaaaa-0011-0000-0000-000000000000', 'gumus',
          public.istanbul_week() - 7);
  for i in 1..11 loop
    v_id := tests.create_supabase_user('g11_' || i);
    update public.profiles
       set league = 'gumus', created_at = now() - interval '60 days'
     where id = v_id;
    insert into public.league_members (cohort_id, user_id, xp)
    values ('aaaaaaaa-0011-0000-0000-000000000000', v_id, 1000 - i * 10);
  end loop;
end
$fx$;

select lives_ok('select public.settle_past_leagues()', 'settle 11 kişide çalışıyor');

select is(
  (select count(*)::int from public.league_members
    where cohort_id = 'aaaaaaaa-0011-0000-0000-000000000000' and move = 'down'),
  5, '11 kişilik kohortta son 5 DÜŞTÜ — eşik burada bağlıyor');

select is(
  (select count(*)::int from public.league_members
    where cohort_id = 'aaaaaaaa-0011-0000-0000-000000000000' and move = 'stay'),
  1, '11 kişide tam 1 kişi ortada kaldı — kümeler kesişmiyor');

-- ============================================== 4) yeni kullanıcı korumasi
select tests.reset_role();
do $fx$
declare i int; v_id uuid;
begin
  insert into public.league_cohorts (id, tier, week_start)
  values ('aaaaaaaa-0011-2222-0000-000000000000', 'platin',
          public.istanbul_week() - 7);
  for i in 1..11 loop
    v_id := tests.create_supabase_user('yeni' || i);
    update public.profiles
       set league = 'platin',
           -- SON İKİSİ YENİ: bu hafta kaydolmuşlar, yani ilk lig haftaları.
           created_at = case when i > 9 then now()
                             else now() - interval '60 days' end
     where id = v_id;
    insert into public.league_members (cohort_id, user_id, xp)
    values ('aaaaaaaa-0011-2222-0000-000000000000', v_id, 1000 - i * 10);
  end loop;
end
$fx$;

select lives_ok('select public.settle_past_leagues()',
                'settle yeni kullanıcıyla çalışıyor');

select is(
  (select count(*)::int
     from public.league_members m
     join public.profiles p on p.id = m.user_id
    where m.cohort_id = 'aaaaaaaa-0011-2222-0000-000000000000'
      and m.move = 'down'
      and p.created_at > now() - interval '7 days'),
  0, 'İLK İKİ HAFTASINDAKİ kullanıcı son 5''te olsa bile düşmüyor');

select is(
  (select count(*)::int from public.league_members
    where cohort_id = 'aaaaaaaa-0011-2222-0000-000000000000' and move = 'down'),
  3, 'koruma yalnızca yenileri kapsıyor — yerleşik son 3 düştü');

-- ============================================== 5) çift kohort kısıtı
select tests.reset_role();
insert into public.league_cohorts (id, tier, week_start)
values ('aaaaaaaa-9999-0000-0000-000000000000', 'altin',
        public.istanbul_week() - 7);

select throws_ok(
  format($q$insert into public.league_members (cohort_id, user_id, xp)
            values ('aaaaaaaa-9999-0000-0000-000000000000', %L, 0)$q$,
         tests.get_supabase_uid('k6_1')),
  '23505', null,
  'aynı kullanıcı aynı hafta İKİ kohorta giremiyor (unique user_id, week_start)');

-- ============================================== 6) ligde engel maskelemesi
select tests.reset_role();
insert into public.user_blocks (blocker_id, blocked_id)
values (tests.get_supabase_uid('k6_1'), tests.get_supabase_uid('k6_2'));
-- Bu haftaya taze bir kohort: tahta yalnızca İÇİNDE BULUNULAN haftayı okuyor.
insert into public.league_cohorts (id, tier, week_start)
values ('bbbbbbbb-0000-0000-0000-000000000000', 'altin', public.istanbul_week());
insert into public.league_members (cohort_id, user_id, xp) values
  ('bbbbbbbb-0000-0000-0000-000000000000', tests.get_supabase_uid('k6_1'), 50),
  ('bbbbbbbb-0000-0000-0000-000000000000', tests.get_supabase_uid('k6_2'), 40);

select tests.authenticate_as('k6_1');
select is(
  (select nickname from public.my_league_board()
    where user_id = tests.get_supabase_uid('k6_2')),
  null,
  'engellenen kullanıcının takma adı MASKELİ (istemci "Öğrenci" çiziyor)');

select is(
  (select members from public.my_league_board() limit 1),
  2,
  'satır DÜŞMÜYOR: üye sayısı ve sıralama bozulmuyor — engel ele verilmiyor');

select * from finish();
rollback;
