-- 220 — Fotoğraf içerik taraması: 'clear' olmayan paylaşıma çıkamaz (0050)
--
-- Ürün kuralı: yüklenen görsel makine taramasından geçene kadar YALNIZCA
-- sahibine görünür. Şüpheli işaretlenen içerik paylaşımdan düşer ama sahibi
-- kendi kaydını kullanmaya devam eder (yanlış pozitif kilitlemez). Admin
-- kararı iki yönlü: temiz → paylaşım açılır, kaldır → mevcut purge değişmezi.

begin;
set search_path to public, extensions, tests;

select plan(21);

select tests.create_supabase_user('sahip');
select tests.create_supabase_user('dost');
select tests.create_supabase_user('bekci');
-- Yaş kapısı (0067) `mistakes` INSERT'te doğum yılı şart koşuyor; bu testin
-- konusu o değil, fikstürün kurulabilmesi için ön koşul (bkz. seed.sql).
select tests.age_all_users();
-- Konu doğrulaması (0071) fikstürlerdeki uydurma konuları reddederdi; bu
-- testin konusu o değil (bkz. seed.sql).
select tests.skip_topic_check();

select tests.reset_role();
insert into public.admins (user_id) values (tests.get_supabase_uid('bekci'));
insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('sahip'), tests.get_supabase_uid('dost'),
        'accepted');

-- ============================================== yükleme → pending (trigger)
-- FİKSTÜR AYRICALIKLI KURULUYOR (aşağıdaki 'bicim' fikstürüyle aynı biçim).
-- Bu dosyanın konusu paylaşıma çıkmış içeriğin taramadan geçmesi, yani
-- `is_public = true` fikstürün ANLAMI. 0090 o sütunun INSERT yetkisini geri
-- aldığı için `authenticated` olarak yazmak artık 42501 veriyor ve dosya
-- yedinci satırda düşüyordu. Sütun ayrıcalıkları tablo sahibine uygulanmaz;
-- `postgres` olarak kurup hemen role dönüyoruz. Tetikleyici (0050) rolden
-- bağımsız çalışıyor, yani 'pending' iddiası aynı şeyi kanıtlamaya devam
-- ediyor.
select tests.reset_role();
insert into public.mistakes
  (user_id, subject, concept, photo_path, options, correct_index, is_public)
values (tests.get_supabase_uid('sahip'), 'Tarih', 'İnkılaplar',
        tests.get_supabase_uid('sahip')::text || '/supheli.jpg',
        '[{"label":"A","text":""},{"label":"B","text":""}]'::jsonb, 0, true);
select tests.authenticate_as('sahip');

select is(
  (select m.photo_scan from public.mistakes m
    where m.user_id = tests.get_supabase_uid('sahip')),
  'pending',
  'yeni yüklenen fotoğraf pending başlar (istemci ne yazarsa yazsın)'
);

-- ============================================ pending: paylaşım kapalı
select is(
  (select count(*)::int from public.public_questions q
    where q.owner_id = tests.get_supabase_uid('sahip')),
  0,
  'pending fotoğraf havuz görünümünde YOK'
);

select throws_ok(
  format('insert into public.question_sends (sender_id, receiver_id, mistake_id) '
         'values (%L, %L, (select id from public.mistakes where user_id = %L))',
         tests.get_supabase_uid('sahip'), tests.get_supabase_uid('dost'),
         tests.get_supabase_uid('sahip')),
  '42501', null,
  'pending fotoğraflı soru arkadaşa GÖNDERİLEMEZ'
);

select is(
  public.can_read_mistake_photo(
    tests.get_supabase_uid('sahip')::text || '/supheli.jpg'),
  true,
  'SAHİBİ pending fotoğrafını okumaya devam eder (yanlış pozitif kilitlemez)'
);

select tests.authenticate_as('dost');
select is(
  public.can_read_mistake_photo(
    tests.get_supabase_uid('sahip')::text || '/supheli.jpg'),
  false,
  'havuza açık bile olsa pending fotoğrafı BAŞKASI okuyamaz'
);

-- ================================================== clear: paylaşım açılır
select tests.reset_role();
update public.mistakes set photo_scan = 'clear'
 where user_id = tests.get_supabase_uid('sahip');

select tests.authenticate_as('dost');
select is(
  (select count(*)::int from public.public_questions q
    where q.owner_id = tests.get_supabase_uid('sahip')),
  1,
  'clear olunca havuzda görünür'
);
select is(
  public.can_read_mistake_photo(
    tests.get_supabase_uid('sahip')::text || '/supheli.jpg'),
  true,
  'clear olunca fotoğraf da okunur'
);

select tests.authenticate_as('sahip');
select lives_ok(
  format('insert into public.question_sends (sender_id, receiver_id, mistake_id) '
         'values (%L, %L, (select id from public.mistakes where user_id = %L))',
         tests.get_supabase_uid('sahip'), tests.get_supabase_uid('dost'),
         tests.get_supabase_uid('sahip')),
  'clear olunca arkadaşa gönderilebilir'
);

-- ============================================ flagged: paylaşımdan düşer
select tests.reset_role();
update public.mistakes set photo_scan = 'flagged'
 where user_id = tests.get_supabase_uid('sahip');

select tests.authenticate_as('dost');
select is(
  (select count(*)::int from public.public_questions q
    where q.owner_id = tests.get_supabase_uid('sahip')),
  0,
  'flagged havuzdan düşer'
);
select is(
  (select count(*)::int from public.received_questions),
  0,
  'gönderilmiş olsa bile flagged içerik alıcının kutusundan düşer'
);
select is(
  public.can_read_mistake_photo(
    tests.get_supabase_uid('sahip')::text || '/supheli.jpg'),
  false,
  've fotoğrafı okunamaz'
);

-- ============================================== admin kararı: temiz
-- Kimlik ayrıcalıklı oturumda alınır (mistakes RLS'i bekci'ye sahip'in
-- satırını göstermez; alt sorgu NULL döner ve karar no-op olurdu).
select tests.reset_role();
create temp table _sahip_mistake on commit drop as
  select id from public.mistakes
   where user_id = tests.get_supabase_uid('sahip');
-- Temp tablo postgres'in; sonraki okumalar `authenticated` rolüyle
-- (aynı oturum, SET ROLE) — tablo düzeyi SELECT izni açıkça verilmeli.
grant select on _sahip_mistake to authenticated;

select tests.authenticate_as('bekci');
select is(
  (select count(*)::int from public.admin_flagged_photos()),
  1,
  'şüpheli fotoğraf admin kuyruğunda'
);

select lives_ok(
  format('select public.admin_review_photo_scan(%L, ''clear'')',
         (select id from _sahip_mistake)),
  'admin temiz işaretleyebiliyor'
);
select tests.authenticate_as('dost');
select is(
  (select count(*)::int from public.public_questions q
    where q.owner_id = tests.get_supabase_uid('sahip')),
  1,
  'temiz kararıyla paylaşım geri açıldı'
);

-- =========================================== admin kararı: kaldır → purge
select tests.authenticate_as('bekci');
select lives_ok(
  format('select public.admin_review_photo_scan(%L, ''remove'')',
         (select id from _sahip_mistake)),
  'admin kaldırabiliyor'
);
select is(
  (select count(*)::int from public.admin_photo_purge_queue()),
  1,
  'kaldırma mevcut purge kuyruğuna düştü (Değişmez 3 zinciri aynen işliyor)'
);

-- ==================================== 0066: 'unsupported' terminal durumu
-- SORUN: `scan-photos` MIME'ı sabit `image/jpeg` yazıyordu. PNG/WebP
-- yüklenince moderation isteği reddediliyor, satır 'pending' KALIYOR ve
-- süpürücü on dakikada bir aynı indirmeyi boşuna tekrarlıyordu — sonsuz kuyruk.
--
-- Terminal durum ŞART, ama 'flagged' YANLIŞ olurdu: 0062'nin ihlal
-- tetikleyicisi 'flagged'da ateşliyor ve kullanıcı DOSYA BİÇİMİ yüzünden
-- yaptırım merdivenine girerdi.
--
-- TEMİZ SAYFA ŞART: yukarıdaki 'sahip' fikstürü bilerek 'flagged'dan geçti,
-- yani onun ihlal sayacı ZATEN dolu. Sıfır iddiası orada anlamsız olurdu;
-- ayrı bir kullanıcı ve ayrı bir satır kuruluyor.
select tests.reset_role();
select tests.create_supabase_user('bicim');
select tests.age_all_users();

insert into public.mistakes
  (user_id, subject, concept, photo_path, options, correct_index, is_public)
values (tests.get_supabase_uid('bicim'), 'Fizik', 'Optik',
        tests.get_supabase_uid('bicim')::text || '/webp_sanilan.png',
        '[{"label":"A","text":""},{"label":"B","text":""}]'::jsonb, 0, true);

create temporary table _unsup on commit drop as
select id from public.mistakes where user_id = tests.get_supabase_uid('bicim');
-- Tablo `postgres`un; aşağıdaki iddialar `authenticated` rolüyle (aynı oturum,
-- SET ROLE) okuyor — tablo düzeyi SELECT açıkça verilmeli. 060'ın aynı notu.
grant select on _unsup to authenticated;

select lives_ok(
  format('update public.mistakes set photo_scan = ''unsupported'' where id = %L',
         (select id from _unsup)),
  'photo_scan CHECK''i ''unsupported'' değerini kabul ediyor'
);

select is(
  (select count(*)::int from public.photo_violations v
    where v.user_id = tests.get_supabase_uid('bicim')),
  0,
  'unsupported İHLAL SAYILMIYOR — dosya biçimi yaptırım merdivenini işletmez'
);

-- Süpürücü kuyruğu `photo_scan = 'pending'` kısmi index'i üzerinden dönüyor;
-- terminal durum oradan da çıkmış olmalı, yoksa sonsuz tekrar sürerdi.
select is(
  (select count(*)::int from public.mistakes m
    where m.photo_scan = 'pending' and m.user_id = tests.get_supabase_uid('bicim')),
  0,
  'unsupported satır süpürücü kuyruğunda DEĞİL'
);

select tests.authenticate_as('dost');
select is(
  (select count(*)::int from public.public_questions q
    where q.owner_id = tests.get_supabase_uid('bicim')),
  0,
  'unsupported fotoğraf havuzda GÖRÜNMÜYOR (paylaşım kapıları ''clear'' arıyor)'
);

-- ============================ yönetici listesi tarama durumunu GÖSTERİYOR
-- `admin_review_photo_scan(id,'clear')` durumdan bağımsız çalışıyor: yönetici
-- hiç taranmamış bir fotoğrafı da paylaşıma açabilir. Yetki bilerek duruyor,
-- ama kararın bilerek verilmesi için durum listede görünmek zorunda.
select tests.authenticate_as('bekci');
select is(
  (select q.photo_scan from public.admin_all_questions(200, 0) q
    where q.id = (select id from _unsup)),
  'unsupported',
  'admin_all_questions tarama durumunu döndürüyor'
);

select * from finish();
rollback;
