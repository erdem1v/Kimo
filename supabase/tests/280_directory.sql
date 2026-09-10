-- 280 — Kullanıcı dizini kapalı + engellenenler listesi (0068)
--
-- İDDİANIN ÖZÜ: takma ad aramasını KALDIRMAK dizini KAPATMADI.
-- `socialRepository.search()` Task 02'de silindi ve arkadaş ekleme 6 haneli
-- koda bağlandı, ama `profiles_public` görünümü `authenticated` rolüne açık
-- kaldı. Uygulamayı hiç çalıştırmadan, bir oturum + anon anahtarla
-- `select * from profiles_public` bütün kullanıcı tabanını sayfa sayfa
-- döküyordu. 0045 bunu "bilinen ve kabul edilen sınır" diye not etmişti;
-- 0068 kapattı.
--
-- Kapatmanın bedeli aşırı kilitleme riski: arkadaş listesi, lig tahtası ve
-- profil kartı hâlâ ÇALIŞMAK ZORUNDA. Bu dosya her iki yönü de iddia ediyor.

begin;
set search_path to public, extensions, tests;

select plan(16);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('bob');
select tests.create_supabase_user('carol');
select tests.age_all_users();

select tests.reset_role();
update public.profiles set nickname = 'Alice' where id = tests.get_supabase_uid('alice');
update public.profiles set nickname = 'Bob'   where id = tests.get_supabase_uid('bob');
update public.profiles set nickname = 'Carol' where id = tests.get_supabase_uid('carol');

-- ==================================================== KATALOG: görünüm kapalı
select ok(not has_table_privilege('authenticated', 'public.profiles_public', 'SELECT'),
          'profiles_public authenticated''a KAPALI (dizin dökülemiyor)');
select ok(not has_table_privilege('anon', 'public.profiles_public', 'SELECT'),
          'profiles_public anon''a da kapalı');

-- Yetim index de gitti: arama kalktığında unutulmuştu (0005).
select ok(
  not exists (
    select 1 from pg_indexes
     where schemaname = 'public' and indexname = 'profiles_nickname_lower_idx'
  ),
  'takma ad arama index''i düşürüldü (kullanan sorgu kalmamıştı)'
);

-- ==================================================== DAVRANIŞ: dökülemiyor
select tests.authenticate_as('alice');

select throws_ok(
  'select count(*) from public.profiles_public',
  '42501', null,
  'görünüm çalışma zamanında da okunamıyor'
);

-- `profiles` TABLOSU zaten RLS ile kendi satırına kilitli; dizin oradan da
-- dökülemez. Bu iddia, kapıyı görünümden tabloya kaydırmanın işe yaramadığını
-- gösteriyor.
select is(
  (select count(*)::int from public.profiles),
  1,
  'profiles tablosundan yalnız KENDİ satırı görünüyor'
);

-- ============================================= DAVRANIŞ: kimliğe göre çalışıyor
select is(
  (select p.nickname from public.profiles_by_ids(
     array[tests.get_supabase_uid('bob')]) p),
  'Bob',
  'kimliği bilinen profil RPC ile okunabiliyor (arkadaş listesi çalışmalı)'
);
select is(
  (select count(*)::int from public.profiles_by_ids(
     array[tests.get_supabase_uid('bob'), tests.get_supabase_uid('carol')])),
  2,
  'çoklu okuma çalışıyor (lig tahtası / arkadaş listesi)'
);
select is(
  (select count(*)::int from public.profiles_by_ids(array[]::uuid[])),
  0,
  'boş liste boş sonuç (hata değil)'
);

-- ÜST SINIR: sayfalayarak dökmenin ucuz yolu kapalı.
select throws_ok(
  format('select count(*) from public.profiles_by_ids(%L::uuid[])',
         (select array_agg(gen_random_uuid()) from generate_series(1, 61))),
  '22023', null,
  '61 kimlik reddediliyor (dizini parça parça dökme yolu kapalı)'
);
select lives_ok(
  format('select count(*) from public.profiles_by_ids(%L::uuid[])',
         (select array_agg(gen_random_uuid()) from generate_series(1, 60))),
  '60 kimlik kabul ediliyor (sınır kapsayıcı)'
);

-- ============================================= AŞIRI KİLİTLEME KARŞI-İDDİASI
-- Lig tahtası `profiles_public`i DEĞİL kendi RPC'sini okuyor; kapatma onu
-- etkilememeli. Etkileseydi lig ekranı boşalırdı ve bunu ancak cihazda
-- görürdük.
select lives_ok(
  'select count(*) from public.my_league_board()',
  'lig tahtası RPC''si çalışmaya devam ediyor'
);

-- ================================================= ENGELLENENLER LİSTESİ (A-8)
select lives_ok(
  format('select public.block_user(%L)', tests.get_supabase_uid('bob')),
  'engelleme çalışıyor'
);
select is(
  (select b.nickname from public.my_blocked_users() b),
  'Bob',
  'engellenen kişi ADIYLA listeleniyor (kaldırılabilmesi için şart)'
);

-- Liste ÇAĞIRANA kilitli: kimin kimi engellediği sorulamıyor.
select tests.authenticate_as('carol');
select is(
  (select count(*)::int from public.my_blocked_users()),
  0,
  'başkasının engel listesi görünmüyor (parametre almıyor)'
);

select tests.authenticate_as('alice');
select lives_ok(
  format('select public.unblock_user(%L)', tests.get_supabase_uid('bob')),
  'engel kaldırılabiliyor'
);
select is(
  (select count(*)::int from public.my_blocked_users()),
  0,
  'engel kalkınca liste boşalıyor'
);

select * from finish();
rollback;
