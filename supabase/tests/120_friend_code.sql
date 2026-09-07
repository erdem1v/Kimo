-- 120 — Arkadaş kodu (0045)
--
-- Task 01 dizinin toplu dökülebilirliğini açık risk olarak bırakmıştı. Kod
-- tabanlı ekleme o riski "dökülebilir ama EKLENEBİLİR DEĞİL"e indiriyor:
-- kodu bilmeden istek gönderilemiyor. Bu dosya kodun üretildiğini, tekil
-- olduğunu, istemciden yazılamadığını ve taranamadığını doğruluyor.

begin;
set search_path to public, extensions, tests;

select plan(16);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('bob');

-- ============================================================== KATALOG
select has_column('public'::name, 'profiles'::name, 'friend_code'::name,
                  'friend_code sütunu var');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'friend_code', 'UPDATE'),
          'kod istemciden yazılamaz — kimse kendi kodunu seçemez');
select has_index('public'::name, 'profiles'::name, 'profiles_friend_code_key'::name,
                 'kod üzerinde tekillik indeksi var');

-- ============================================================== ÜRETİM
select tests.reset_role();

select ok(
  (select friend_code is not null from public.profiles
    where id = tests.get_supabase_uid('alice')),
  'kod kayıt anında üretiliyor — "kodun henüz yok" ara durumu yok'
);
select is(
  (select length(friend_code) from public.profiles
    where id = tests.get_supabase_uid('alice')),
  6,
  'kod 6 karakter'
);
select ok(
  (select friend_code !~ '[ILO01]' from public.profiles
    where id = tests.get_supabase_uid('alice')),
  'karışan karakterler (I, L, O, 0, 1) kodda YOK'
);
select isnt(
  (select friend_code from public.profiles where id = tests.get_supabase_uid('alice')),
  (select friend_code from public.profiles where id = tests.get_supabase_uid('bob')),
  'iki kullanıcının kodu farklı'
);

-- ============================================================== EKLEME
-- Bob'un kodu ayrıcalıklı oturumda okunur: profiles SELECT politikası yalnız
-- kendi satırını açar; alice olarak bob'un satırını sorgulamak BOŞ döner ve
-- test sessizce NULL kodla çağrı yapar (ilk CI koşusunun bulgusu).
select tests.reset_role();
create temp table _bob_code on commit drop as
  select friend_code as code from public.profiles
   where id = tests.get_supabase_uid('bob');
-- Temp tablo postgres'in; sonraki okumalar `authenticated` rolüyle
-- (aynı oturum, SET ROLE) — tablo düzeyi SELECT izni açıkça verilmeli.
grant select on _bob_code to authenticated;

select tests.authenticate_as('alice');

-- Reşit olmayan/onaysız hesapta kapı kapalı; testin bu bölümü için yaşı ver.
select lives_ok(
  format('select public.set_birth_year(%s)', extract(year from now())::int - 25),
  'yaş kaydedildi (kapı açılsın)'
);

select is(
  (select f.reason
     from _bob_code b
     cross join lateral public.add_friend_by_code(b.code) f),
  'eklendi',
  'kodla arkadaş isteği gönderilebiliyor'
);

select is(
  (select count(*)::int from public.friendships
    where requester_id = tests.get_supabase_uid('alice')
      and addressee_id = tests.get_supabase_uid('bob')),
  1,
  'istek gerçekten yazıldı'
);

-- Tireli ve küçük harfli yazım da kabul edilmeli (kullanıcı kopyalarken bozar).
select lives_ok(
  format('select public.add_friend_by_code(%L)',
         lower(substr((select code from _bob_code), 1, 3)
               || '-' ||
               substr((select code from _bob_code), 4, 3))),
  'tireli ve küçük harfli kod normalize ediliyor'
);

-- ============================================================== REDDEDİLENLER
-- Başarısızlık İSTİSNA DEĞİL dönüş değeri: istisna işlemi geri alır ve oran
-- sınırı sayacını da siler; o zaman geçersiz denemeler hiç sayılmaz ve kod
-- uzayını taramak bedava olurdu.
select is(
  (select f.reason
     from (select p.friend_code as code from public.profiles p
            where p.id = tests.get_supabase_uid('alice')) a
     cross join lateral public.add_friend_by_code(a.code) f),
  'bulunamadi',
  'kendi kodunu ekleyemiyor'
);

select is(
  (select reason from public.add_friend_by_code('ZZZZZZ')),
  'bulunamadi',
  'bilinmeyen kod reddediliyor — VAR OLAN kodla AYNI cevap (sızıntı yok)'
);

select is(
  (select ok from public.add_friend_by_code('ZZZZZZ')),
  false,
  'reddedilen deneme ok=false döndürüyor (istisna atmıyor)'
);

select throws_ok(
  'select public.add_friend_by_code(''ABC'')',
  '22023', null,
  'eksik uzunluktaki kod reddediliyor'
);

-- ------------------------------------------------------------- kaba kuvvet
-- Saatte 20 deneme. Sınır GEÇERSİZ denemelerde de işliyor; yalnızca başarılı
-- eklemede sayılsaydı 887 milyonluk uzayı taramak bedava olurdu.
-- Denemeler artık istisna ATMIYOR, yani her biri sayacı gerçekten artırıyor.
-- Yalnızca SINIRIN KENDİSİ istisna atıyor (54000) ve döngüyü durdurmasın diye
-- yakalanıyor. Alt işlem geri alması burada zararsız: sınır aşıldığında
-- kaydedilecek bir artış zaten yok.
do $fx$
declare i int;
begin
  for i in 1..25 loop
    begin
      perform public.add_friend_by_code('ZZZZZ' || chr(65 + (i % 20)));
    exception when sqlstate '54000' then
      exit;  -- sınıra ulaşıldı
    end;
  end loop;
end
$fx$;

select throws_ok(
  'select public.add_friend_by_code(''ZZZZZZ'')',
  '54000', null,
  'saatlik deneme sınırı aşılınca reddediliyor — kod uzayı taranamıyor'
);

select * from finish();
rollback;
