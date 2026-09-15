-- 320 — Ortak seri (0086 · Tur 7 · n6)
--
-- ÜRÜN KURALI: "Her ikiniz de GÜNDE BİR SORU ÇÖZDÜKÇE sayı büyür." Gönderim
-- seriyi BAŞLATIYOR, SÜRDÜRMÜYOR — bu ayrım çöp gönderim güdüsünü yapısal
-- olarak yok ediyor.
--
-- BU DOSYANIN EN ÖNEMLİ ÜÇ İDDİASI:
--   1. TABLO İSTEMCİYE KAPALI. Açık olsaydı kullanıcı kendi serisini şişirir.
--   2. `pair_streak_rollover` İSTEMCİYE KAPALI. Açık olsaydı kullanıcı seriyi
--      elle ilerletirdi.
--   3. KANONİK SIRA veri katmanında zorunlu. İki satır tutmak iki doğruluk
--      kaynağı demekti.

begin;
set search_path to public, extensions, tests;

select plan(24);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('bob');
select tests.create_supabase_user('mallory');
select tests.age_all_users();
select tests.skip_topic_check();

-- ============================================================== YAPI
select has_table('public'::name, 'pair_streaks'::name, 'pair_streaks tablosu var');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.pair_streaks'::regclass),
  'pair_streaks üzerinde RLS açık'
);
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'pair_streaks'),
  0,
  'pair_streaks üzerinde HİÇ politika yok (yalnızca definer fonksiyonlar)'
);
select ok(not has_table_privilege('authenticated', 'public.pair_streaks', 'SELECT'),
          'ikili seri tablosu OKUNAMIYOR — okuma my_pair_streaks()''ten');
select ok(not has_table_privilege('authenticated', 'public.pair_streaks', 'INSERT'),
          'satır EKLENEMİYOR — kullanıcı kendi serisini şişiremez');
select ok(not has_table_privilege('authenticated', 'public.pair_streaks', 'UPDATE'),
          'satır GÜNCELLENEMİYOR');

-- PAKETİN EN ÖNEMLİ TEK YETKİ İDDİASI.
select ok(not has_function_privilege(
            'authenticated', 'public.pair_streak_rollover()', 'EXECUTE'),
          'devir fonksiyonu KAPALI — kullanıcı seriyi elle ilerletemez');
select ok(has_function_privilege(
            'authenticated', 'public.my_pair_streaks()', 'EXECUTE'),
          'okuma RPC''si istemciye açık');
select ok(has_function_privilege(
            'authenticated', 'public.leave_pair_streak(uuid)', 'EXECUTE'),
          'tek dokunuşla çıkış açık (DSA kılavuzu kolay çıkış istiyor)');

-- Hesap silinince karşı tarafta yetim satır kalmamalı.
select ok(
  (select count(*)::int from pg_constraint con
    join pg_class c on c.oid = con.conrelid
   where c.relname = 'pair_streaks' and con.contype = 'f'
     and con.confdeltype = 'c') = 2,
  'iki bağ da CASCADE — hesap silinince yetim satır kalmıyor'
);

-- ============================================================== KANONİK SIRA
select tests.reset_role();
select throws_ok(
  format($q$insert into public.pair_streaks (a_id, b_id)
             values (%L, %L)$q$,
         greatest(tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob')),
         least(tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'))),
  '23514', null,
  'TERS sırayla satır yazılamıyor — iki doğruluk kaynağı imkânsız'
);

-- ============================================================== BAŞLATMA
insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'), 'accepted');

insert into public.mistakes (user_id, subject, concept, mistake_type, photo_path)
values (tests.get_supabase_uid('alice'), 'Fizik', 'Kuvvet', 'islem_hatasi',
        tests.get_supabase_uid('alice')::text || '/a.jpg'),
       (tests.get_supabase_uid('bob'), 'Fizik', 'Kuvvet', 'islem_hatasi',
        tests.get_supabase_uid('bob')::text || '/b.jpg');

-- BAYRAK AÇILIYOR. 0094 `ff_pair_streak`i SUNUCUYA da taşıdı ve varsayılanı
-- `false` — yani bu satır olmadan `start_pair_streak` ve `pair_streak_rollover`
-- hiçbir şey yapmadan `false` dönüyor ve dosyanın davranış bölümünün TAMAMI
-- (altı iddia) mekanizma bozuk gibi görünerek düşüyor. Aşağıdaki "bayrak
-- kapalıyken" bölümü bayrağı bilerek `false`a çekip geri açıyor, yani kapının
-- kendisi ayrıca sınanmaya devam ediyor.
insert into public.app_config (key, value) values ('ff_pair_streak', 'true')
  on conflict (key) do update set value = excluded.value;

select tests.authenticate_as('alice');
select ok(not (select public.start_pair_streak(tests.get_supabase_uid('bob'))),
          'çözülmüş gönderim yokken seri BAŞLAMIYOR');

-- Tek yönde çözüm yeterli DEĞİL: "ortak" olması iki yön demek.
select tests.reset_role();
insert into public.question_sends (sender_id, receiver_id, mistake_id, solved_at)
select tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'), m.id, now()
  from public.mistakes m where m.user_id = tests.get_supabase_uid('alice') limit 1;
select tests.authenticate_as('alice');
select ok(not (select public.start_pair_streak(tests.get_supabase_uid('bob'))),
          'TEK yönde çözüm yetmiyor');

select tests.reset_role();
insert into public.question_sends (sender_id, receiver_id, mistake_id, solved_at)
select tests.get_supabase_uid('bob'), tests.get_supabase_uid('alice'), m.id, now()
  from public.mistakes m where m.user_id = tests.get_supabase_uid('bob') limit 1;
select tests.authenticate_as('alice');
select ok((select public.start_pair_streak(tests.get_supabase_uid('bob'))),
          'iki yönde de çözüm varsa seri BAŞLIYOR');
select ok(not (select public.start_pair_streak(tests.get_supabase_uid('bob'))),
          'ikinci kez başlatmak FALSE — kopya satır yok');

-- Arkadaş olmayanla seri kurulamıyor.
select ok(not (select public.start_pair_streak(tests.get_supabase_uid('mallory'))),
          'arkadaş olmayanla seri kurulamıyor');

-- ============================================================== OKUMA
select is((select count(*)::int from public.my_pair_streaks()), 1,
          'okuma RPC''si ikiliyi döndürüyor');
select is((select friend_id from public.my_pair_streaks()),
          tests.get_supabase_uid('bob'),
          'karşı tarafın kimliği dönüyor (kim kime sorusu yok)');

-- ENGELLEME: `are_friends` engelleri HİÇ görmüyor, kontrol ayrıca yazılmalı.
select tests.reset_role();
insert into public.user_blocks (blocker_id, blocked_id)
values (tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'));
select tests.authenticate_as('alice');
select is((select count(*)::int from public.my_pair_streaks()), 0,
          'ENGELLENEN ikili listede GÖRÜNMÜYOR');
select tests.reset_role();
delete from public.user_blocks where blocker_id = tests.get_supabase_uid('alice');

-- ============================================================== DEVİR
-- İkisi de DÜN aktifse +1. Sınırları düşürerek değil, tarihleri kurarak
-- sınıyoruz: devir mantığı tarih karşılaştırmasından oluşuyor.
update public.profiles set last_activity_date = public.istanbul_day() - 1
 where id in (tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'));
update public.pair_streaks set streak = 5, last_day = public.istanbul_day() - 2;

select public.pair_streak_rollover();
select is((select streak from public.pair_streaks), 6,
          'ikisi de dün aktifse seri ilerliyor');

-- İdempotent: aynı gün ikinci koşu ilerletmiyor.
select public.pair_streak_rollover();
select is((select streak from public.pair_streaks), 6,
          'ikinci koşu ilerletmiyor — devir idempotent');

-- Biri dün çalışmadıysa sıfırlanıyor.
update public.profiles set last_activity_date = public.istanbul_day() - 3
 where id = tests.get_supabase_uid('bob');
update public.pair_streaks set last_day = public.istanbul_day() - 2;
select public.pair_streak_rollover();
select is((select streak from public.pair_streaks), 0,
          'biri dün çalışmadıysa seri SIFIRLANIYOR');

-- ====================== BAYRAK VE ASKI SUNUCUDA DA (0094)
-- `ff_pair_streak` yalnızca İSTEMCİ tarafında uygulanıyordu: `start_pair_streak`
-- bayraktan bağımsız açıktı ve `pair-streak-daily` cron'u kapalıyken de bütün
-- serileri ilerletiyordu. Kapatma kararı "küçükler için varsayılan kapalı"
-- (DSA Md. 28(1) Kılavuzu) gerekçesiyle alınmışken eski bir istemci sürümü ya
-- da doğrudan RPC çağrısı seriyi başlatabiliyor, kapalı dönemde VERİ BİRİKMEYE
-- devam ediyordu.
select tests.reset_role();
insert into public.app_config (key, value) values ('ff_pair_streak', 'false')
  on conflict (key) do update set value = excluded.value;
select tests.authenticate_as('alice');
select ok(
  not (select public.start_pair_streak(tests.get_supabase_uid('bob'))),
  'BAYRAK KAPALIYKEN ortak seri başlatılamıyor (sunucu da kapatıyor)');

-- ASKI ÜRETİMİ DURDURUR (0062). Ortak seri karşı tarafa GÖRÜNEN kalıcı bir
-- satır yaratıyor, yani bir üretim yüzeyi.
--
-- TAZE İKİLİ ŞART. Bu iddia önce alice–bob'u deniyordu ve o ikilinin serisi
-- yukarıda ZATEN BAŞLAMIŞTI: `start_pair_streak` "zaten var" dalından `false`
-- dönüyor, yani iddia askı kapısı SÖKÜLSE DE yeşil kalıyordu. Mutasyon 55 tam
-- bunu gösterdi (FAZ 2'de test hâlâ yeşildi) — iddia doğru cümleyi yazıyor ama
-- yanlış sebeple geçiyordu.
--
-- Şimdi alice–mallory kullanılıyor: arkadaşlık ve İKİ YÖNDE çözülmüş gönderim
-- kuruluyor, ikilinin satırı yok, bayrak açık, engel yok. Geriye tek engel
-- askı kalıyor.
select tests.reset_role();
update public.app_config set value = 'true' where key = 'ff_pair_streak';

insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('alice'), tests.get_supabase_uid('mallory'),
        'accepted');
insert into public.mistakes (user_id, subject, concept, mistake_type, photo_path)
values (tests.get_supabase_uid('mallory'), 'Fizik', 'Kuvvet', 'islem_hatasi',
        tests.get_supabase_uid('mallory')::text || '/m.jpg');
insert into public.question_sends (sender_id, receiver_id, mistake_id, solved_at)
select tests.get_supabase_uid('alice'), tests.get_supabase_uid('mallory'),
       m.id, now()
  from public.mistakes m
 where m.user_id = tests.get_supabase_uid('alice') limit 1;
insert into public.question_sends (sender_id, receiver_id, mistake_id, solved_at)
select tests.get_supabase_uid('mallory'), tests.get_supabase_uid('alice'),
       m.id, now()
  from public.mistakes m
 where m.user_id = tests.get_supabase_uid('mallory') limit 1;

insert into public.user_sanctions (user_id, action, until, reason_code, source)
values (tests.get_supabase_uid('alice'), 'suspend', now() + interval '7 days',
        'other', 'admin');
select tests.authenticate_as('alice');
select ok(
  not (select public.start_pair_streak(tests.get_supabase_uid('mallory'))),
  'ASKIDAKİ kullanıcı ortak seri BAŞLATAMIYOR');

select * from finish();
rollback;
