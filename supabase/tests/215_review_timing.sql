-- 215 — Tekrar zamanlaması: aynı gün ilk vade + tarih gölgesi (0049)
--
-- Ürün kuralı: yeni eklenen hata AYNI GÜN (~3 saat sonra) vadelenir —
-- öğrencinin emek verdiği gün karşılığını görmesi için. `next_review_date`
-- artık damgadan türetilen bir gölge; iki alan asla ayrışamaz.

begin;
set search_path to public, extensions, tests;

select plan(9);

select tests.create_supabase_user('acemi');
-- Yaş kapısı (0067) `mistakes` INSERT'te doğum yılı şart koşuyor; bu testin
-- konusu o değil, fikstürün kurulabilmesi için ön koşul (bkz. seed.sql).
select tests.age_all_users();
-- Konu doğrulaması (0071) fikstürlerdeki uydurma konuları reddederdi; bu
-- testin konusu o değil (bkz. seed.sql).
select tests.skip_topic_check();

select tests.authenticate_as('acemi');

-- ============================================== aynı gün ilk vade (INSERT)
insert into public.mistakes (subject, concept)
values ('Matematik', 'Kümeler');

select ok(
  (select m.next_review_at between now() + interval '2 hours 59 minutes'
                              and now() + interval '3 hours 1 minute'
     from public.mistakes m where m.concept = 'Kümeler'),
  'yeni hata ~3 saat sonraya vadelendi (ertesi gün DEĞİL)'
);

select is(
  (select m.next_review_date from public.mistakes m where m.concept = 'Kümeler'),
  ((now() + interval '3 hours') at time zone 'Europe/Istanbul')::date,
  'tarih gölgesi damgadan türedi'
);

-- HUD sayacı: vade dolmadan due_count''a girmez (ZAMAN bazlı sayım, 0096).
--
-- VADE AÇIKÇA "BUGÜNÜN İLERİSİ"NE ÇEKİLİYOR — `now() + 3 saat`e
-- BIRAKILMIYOR. Sebebi bu iddianın SAATE BAĞLI olmasıydı: tetikleyicinin
-- verdiği vade İstanbul saatiyle 21:00''den sonra ERTESİ güne taşıyor ve o
-- pencerede gün bazlı sayım da tesadüfen 0 döndürüyor. Yani iddia günün 21
-- saatinde hatayı yakalıyor, üç saatinde sessizce yeşil kalıyordu — mutasyon
-- 58 tam da o pencerede koşup ayırt edilememişti.
--
-- Damga bugünün İstanbul gününün SON dakikası: her saatte hem GELECEKTE
-- (zaman bazlı → 0) hem de BUGÜNÜN TARİHİNDE (gün bazlı → 1). İki sayım
-- böylece günün her saatinde ayrışıyor.
update public.mistakes
   set next_review_at =
         ((public.istanbul_day() + 1)::timestamp at time zone 'Europe/Istanbul')
         - interval '1 minute'
 where concept = 'Kümeler';

select is(
  (select m.next_review_date from public.mistakes m where m.concept = 'Kümeler'),
  public.istanbul_day(),
  'vade bugünün içinde kaldı (tarih gölgesi bugün)'
);

select is(
  (select s.due_count from public.my_daily_state s),
  0,
  'henüz vadesi gelmedi: due_count 0 (gün bazlı eski sayım 1 gösterirdi)'
);

-- ================================================ damga yazımı (UPDATE)
update public.mistakes
   set next_review_at = '2026-09-10T00:00:00Z'
 where concept = 'Kümeler';

select is(
  (select m.next_review_date from public.mistakes m where m.concept = 'Kümeler'),
  date '2026-09-10',
  'damga güncellenince gölge tarih yeniden türedi (UTC geceyarısı = Istanbul '
  '03:00, gün aynı)'
);

-- ================================= eski istemci kuyruğu: yalnızca tarih yazar
update public.mistakes
   set next_review_date = date '2026-09-20'
 where concept = 'Kümeler';

select is(
  (select m.next_review_date from public.mistakes m where m.concept = 'Kümeler'),
  date '2026-09-20',
  'yalnızca tarih yazan eski kayıt kabul edildi'
);
select is(
  (select m.next_review_at from public.mistakes m where m.concept = 'Kümeler'),
  timestamp '2026-09-20 00:00:00' at time zone 'Europe/Istanbul',
  've damga tarihten (Istanbul geceyarısı) türedi — iki alan ayrışamaz'
);

-- ================================================= vadesi geçmiş → due
select tests.reset_role();
update public.mistakes
   set next_review_at = now() - interval '1 hour'
 where concept = 'Kümeler';

select tests.authenticate_as('acemi');
select is(
  (select s.due_count from public.my_daily_state s),
  1,
  'vadesi dolunca due_count''a girdi'
);

-- ============================================================== dizin
select ok(
  exists (select 1 from pg_indexes
           where schemaname = 'public'
             and indexname = 'mistakes_due_at_idx'),
  'zaman bazlı vade sorgusunun dizini var'
);

select * from finish();
rollback;
