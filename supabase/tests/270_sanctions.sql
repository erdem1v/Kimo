-- 270 — Yaptırım altyapısı: askı, kalıcı yasak, kademeli içerik yaptırımı (0062)
--
-- Apple 1.2'nin dördüncü şartı ("eject abusive users") artık kodda var. Bu
-- dosya dört şeyi ayrı ayrı kanıtlıyor:
--
--   1. Defterler kullanıcıya KAPALI — sicilini ne okuyabiliyor ne yazabiliyor.
--   2. Merdiven gerçekten kademeli: iki ihlal ceza değil, üçüncüsü 7 günlük
--      askı, askıdan sonraki ihlal kalıcı yasak.
--   3. Pencere çalışıyor: 180 günden eski ihlaller eşiği doldurmuyor.
--   4. Yasak VERİ KATMANINDA duruyor — aynı INSERT askıdan önce geçiyor,
--      sonra 42501 alıyor. Ayırt edici olan bu: yalnızca "reddedildi" demek,
--      reddin askıdan geldiğini kanıtlamaz.
--
-- Ve bir aşırı kilitleme kontrolü: askıdaki kullanıcı kendi arşivini okumaya
-- devam ediyor. Ceza uygulamadan atmak değil, başkasına dokunmayı durdurmak.

begin;
set search_path to public, extensions, tests;

select plan(46);

select tests.create_supabase_user('ihlalci');
select tests.create_supabase_user('temiz');
select tests.create_supabase_user('askili');
select tests.create_supabase_user('yanlis');
select tests.create_supabase_user('dost');
select tests.create_supabase_user('bekci');
-- Yaş kapısı (0067) `mistakes` INSERT'te doğum yılı şart koşuyor; bu testin
-- konusu o değil, fikstürün kurulabilmesi için ön koşul (bkz. seed.sql).
select tests.age_all_users();

select tests.reset_role();
insert into public.admins (user_id) values (tests.get_supabase_uid('bekci'));

-- ================================================================== YAPI
select has_table('public'::name, 'user_sanctions'::name,
                 'user_sanctions defteri var');
select has_table('public'::name, 'photo_violations'::name,
                 'photo_violations defteri var');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.user_sanctions'::regclass),
  'user_sanctions üzerinde RLS açık'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.photo_violations'::regclass),
  'photo_violations üzerinde RLS açık'
);
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'user_sanctions'),
  0,
  'user_sanctions üzerinde HİÇ politika yok — yapısal olarak deny-by-default'
);
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'photo_violations'),
  0,
  'photo_violations üzerinde HİÇ politika yok'
);
select ok(not has_table_privilege('authenticated', 'public.user_sanctions', 'SELECT'),
          'kullanıcı kendi sicilini doğrudan OKUYAMIYOR (my_sanction süzüyor)');
select ok(not has_table_privilege('authenticated', 'public.user_sanctions', 'INSERT'),
          'kullanıcı kendine yaptırım YAZAMIYOR');
select ok(not has_table_privilege('authenticated', 'public.photo_violations', 'SELECT'),
          'ihlal defteri doğrudan okunamıyor');
select ok(not has_table_privilege('anon', 'public.photo_violations', 'SELECT'),
          'ihlal defteri anon''a da kapalı');

-- ================================================== NEGATİF: sayaç sıfırlanamaz
select tests.authenticate_as('ihlalci');

select throws_ok(
  format('insert into public.user_sanctions (user_id, action, reason_code, source) '
         'values (%L, ''lift'', ''other'', ''admin'')',
         tests.get_supabase_uid('ihlalci')),
  '42501', null,
  'kullanıcı kendi askısını KALDIRAMIYOR'
);
select throws_ok(
  'update public.photo_violations set voided_at = now()',
  '42501', null,
  'kullanıcı ihlalini geçersiz kılamıyor'
);
select throws_ok(
  'delete from public.photo_violations',
  '42501', null,
  'kullanıcı ihlal kaydını silemiyor — sayaç sıfırlanamaz'
);

-- =========================================== MERDİVEN: 1, 2 ceza değil; 3 askı
select tests.reset_role();
insert into public.mistakes (user_id, subject, concept, photo_path)
values
  (tests.get_supabase_uid('ihlalci'), 'Tarih', 'i1',
   tests.get_supabase_uid('ihlalci')::text || '/i1.jpg'),
  (tests.get_supabase_uid('ihlalci'), 'Tarih', 'i2',
   tests.get_supabase_uid('ihlalci')::text || '/i2.jpg'),
  (tests.get_supabase_uid('ihlalci'), 'Tarih', 'i3',
   tests.get_supabase_uid('ihlalci')::text || '/i3.jpg'),
  (tests.get_supabase_uid('ihlalci'), 'Tarih', 'i4',
   tests.get_supabase_uid('ihlalci')::text || '/i4.jpg');

update public.mistakes set photo_scan = 'flagged'
 where user_id = tests.get_supabase_uid('ihlalci') and concept = 'i1';

select is(
  (select count(*)::int from public.photo_violations
    where user_id = tests.get_supabase_uid('ihlalci')),
  1,
  'birinci işaretleme ihlal defterine düşüyor'
);
select is(
  public.is_suspended(tests.get_supabase_uid('ihlalci')),
  false,
  'birinci ihlal ceza DEĞİL — yalnızca uyarı'
);

update public.mistakes set photo_scan = 'flagged'
 where user_id = tests.get_supabase_uid('ihlalci') and concept = 'i2';

select is(
  public.is_suspended(tests.get_supabase_uid('ihlalci')),
  false,
  'ikinci ihlal de askıya almıyor'
);
select is(
  (select strike_no from public.photo_violations
    where user_id = tests.get_supabase_uid('ihlalci')
    order by created_at desc, id desc limit 1),
  2,
  'ihlal sırası kayıtta duruyor (uyarının sertliği buradan seçiliyor)'
);

update public.mistakes set photo_scan = 'flagged'
 where user_id = tests.get_supabase_uid('ihlalci') and concept = 'i3';

select is(
  public.is_suspended(tests.get_supabase_uid('ihlalci')),
  true,
  'ÜÇÜNCÜ ihlal otomatik askıya alıyor'
);
select is(
  (select action from public.user_sanctions
    where user_id = tests.get_supabase_uid('ihlalci')
    order by created_at desc, id desc limit 1),
  'suspend',
  'otomatik karar ASKI (kalıcı yasak değil — makine hatası geri alınabilir olmalı)'
);
select ok(
  (select until between now() + interval '6 days' and now() + interval '8 days'
     from public.user_sanctions
    where user_id = tests.get_supabase_uid('ihlalci')
    order by created_at desc, id desc limit 1),
  'askı 7 gün sürüyor'
);
select is(
  (select source from public.user_sanctions
    where user_id = tests.get_supabase_uid('ihlalci')
    order by created_at desc, id desc limit 1),
  'auto_photo',
  'kararın kaynağı otomatik tarama olarak kayda geçiyor'
);

-- ======================================= ASKIDAN SONRAKİ İHLAL → KALICI YASAK
-- Süreyi bekleyemeyeceğimiz için askının bitişi geriye alınıyor. `is_suspended`
-- zamanı `until`den okuduğu için bu, yedi gün beklemekle aynı durum.
update public.user_sanctions set until = now() - interval '1 hour'
 where user_id = tests.get_supabase_uid('ihlalci');

select is(
  public.is_suspended(tests.get_supabase_uid('ihlalci')),
  false,
  'süre dolunca askı kendiliğinden kalkıyor (cron gerekmiyor)'
);

update public.mistakes set photo_scan = 'flagged'
 where user_id = tests.get_supabase_uid('ihlalci') and concept = 'i4';

select is(
  (select action from public.user_sanctions
    where user_id = tests.get_supabase_uid('ihlalci')
    order by created_at desc, id desc limit 1),
  'ban',
  'askı çekmiş kullanıcının yeni ihlali KALICI YASAK'
);
select ok(
  (select until is null from public.user_sanctions
    where user_id = tests.get_supabase_uid('ihlalci')
    order by created_at desc, id desc limit 1),
  'kalıcı yasağın bitiş tarihi yok'
);
select is(
  public.is_suspended(tests.get_supabase_uid('ihlalci')),
  true,
  'kalıcı yasak sonrası kullanıcı yasaklı'
);

-- ========================================================= 180 GÜNLÜK PENCERE
insert into public.mistakes (user_id, subject, concept, photo_path)
values
  (tests.get_supabase_uid('temiz'), 'Tarih', 't1',
   tests.get_supabase_uid('temiz')::text || '/t1.jpg'),
  (tests.get_supabase_uid('temiz'), 'Tarih', 't2',
   tests.get_supabase_uid('temiz')::text || '/t2.jpg'),
  (tests.get_supabase_uid('temiz'), 'Tarih', 't3',
   tests.get_supabase_uid('temiz')::text || '/t3.jpg');

update public.mistakes set photo_scan = 'flagged'
 where user_id = tests.get_supabase_uid('temiz') and concept in ('t1', 't2');

-- İlk iki ihlal 200 gün öncesine alınıyor: pencerenin dışına düşsünler.
update public.photo_violations set created_at = now() - interval '200 days'
 where user_id = tests.get_supabase_uid('temiz');

update public.mistakes set photo_scan = 'flagged'
 where user_id = tests.get_supabase_uid('temiz') and concept = 't3';

select is(
  (select count(*)::int from public.photo_violations
    where user_id = tests.get_supabase_uid('temiz')),
  3,
  'defter ÖMÜR BOYU tutuyor — üç ihlal de duruyor'
);
select is(
  public.is_suspended(tests.get_supabase_uid('temiz')),
  false,
  '180 günden eski ihlaller eşiği doldurmuyor — askı YOK'
);

-- =============================================== YANLIŞ POZİTİF GERİ ALINIYOR
insert into public.mistakes (user_id, subject, concept, photo_path)
values
  (tests.get_supabase_uid('yanlis'), 'Tarih', 'y1',
   tests.get_supabase_uid('yanlis')::text || '/y1.jpg'),
  (tests.get_supabase_uid('yanlis'), 'Tarih', 'y2',
   tests.get_supabase_uid('yanlis')::text || '/y2.jpg'),
  (tests.get_supabase_uid('yanlis'), 'Tarih', 'y3',
   tests.get_supabase_uid('yanlis')::text || '/y3.jpg');

update public.mistakes set photo_scan = 'flagged'
 where user_id = tests.get_supabase_uid('yanlis');

select is(
  public.is_suspended(tests.get_supabase_uid('yanlis')),
  true,
  'üç işaretlemeyle askıya alındı'
);

select tests.authenticate_as('bekci');
select public.admin_review_photo_scan(
  (select id from public.mistakes
    where user_id = tests.get_supabase_uid('yanlis') and concept = 'y3'),
  'clear');

select is(
  public.is_suspended(tests.get_supabase_uid('yanlis')),
  false,
  'yönetici "temiz" deyince OTOMATİK askı kalkıyor — yanlış pozitif kilitlemiyor'
);
select is(
  (select action from public.user_sanctions
    where user_id = tests.get_supabase_uid('yanlis')
      and voided_at is null
    order by created_at desc, id desc limit 1),
  'lift',
  'geri alma deftere yazılıyor (askı satırı silinmiyor, geçersiz kılınıyor)'
);
select is(
  (select count(*)::int from public.photo_violations
    where user_id = tests.get_supabase_uid('yanlis') and voided_at is not null),
  1,
  'temizlenen fotoğrafın ihlali geçersiz kılındı'
);

-- ================================== ZORLAMA: aynı yazma, askıdan önce ve sonra
select tests.reset_role();
insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('askili'), tests.get_supabase_uid('dost'),
        'accepted');
insert into public.mistakes (user_id, subject, concept, photo_path)
values
  (tests.get_supabase_uid('askili'), 'Tarih', 'a1',
   tests.get_supabase_uid('askili')::text || '/a1.jpg'),
  (tests.get_supabase_uid('askili'), 'Tarih', 'a2',
   tests.get_supabase_uid('askili')::text || '/a2.jpg');
update public.mistakes set photo_scan = 'clear'
 where user_id = tests.get_supabase_uid('askili');

select tests.authenticate_as('askili');

-- `user_id` GÖNDERİLMİYOR: sütun kilitli ve `default auth.uid()` taşıyor —
-- istemci de tam olarak böyle yazıyor (mistake_repository.dart). Açıkça
-- göndermek 42501'i ASKIDAN DEĞİL sütun kilidinden aldırırdı ve test
-- ölçmek istediği şeyi ölçmezdi.
select lives_ok(
  'insert into public.mistakes (subject, concept) '
  'values (''Tarih'', ''serbest'')',
  'ASKIDAN ÖNCE: hata kaydı ekleyebiliyor'
);
select lives_ok(
  format('insert into public.question_sends (sender_id, receiver_id, mistake_id) '
         'values (%L, %L, (select id from public.mistakes '
         'where user_id = %L and concept = ''a1''))',
         tests.get_supabase_uid('askili'), tests.get_supabase_uid('dost'),
         tests.get_supabase_uid('askili')),
  'ASKIDAN ÖNCE: arkadaşına soru gönderebiliyor'
);

select tests.authenticate_as('bekci');
select public.admin_suspend_user(
  tests.get_supabase_uid('askili'), 'suspend', 7, 'abuse', 'elle askı');

select tests.authenticate_as('askili');

select throws_ok(
  'insert into public.mistakes (subject, concept) '
  'values (''Tarih'', ''yasak'')',
  '42501', null,
  'ASKIDAN SONRA: aynı hata kaydı REDDEDİLİYOR'
);
-- İKİ KOŞUL BİRLİKTE YAŞIYOR (Task 08 / göç 0067). `mistakes` INSERT
-- politikasına yaş koşulu eklenirken askı koşulunun düşürülmesi bu paketin en
-- olası regresyonuydu: yaş testi (130) yeşil kalır, koruma sessizce kaybolurdu.
-- Bu kullanıcının doğum yılı DOLU (age_all_users), yani yukarıdaki ret yaştan
-- değil askıdan geliyor — iddia ancak ikisi ayrıştığında anlam taşıyor.
select is(
  public.has_birth_year(tests.get_supabase_uid('askili')),
  true,
  'askılı kullanıcının doğum yılı DOLU — ret yaş kapısından değil askıdan'
);
select ok(
  (select with_check like '%is_suspended%' and with_check like '%has_birth_year%'
     from pg_policies
    where schemaname = 'public' and tablename = 'mistakes'
      and cmd = 'INSERT'),
  'INSERT politikası HEM askı HEM yaş koşulunu taşıyor'
);
select throws_ok(
  format('insert into public.question_sends (sender_id, receiver_id, mistake_id) '
         'values (%L, %L, (select id from public.mistakes '
         'where user_id = %L and concept = ''a2''))',
         tests.get_supabase_uid('askili'), tests.get_supabase_uid('dost'),
         tests.get_supabase_uid('askili')),
  '42501', null,
  'ASKIDAN SONRA: soru gönderemiyor'
);
select throws_ok(
  format('insert into public.friendships (requester_id, addressee_id, status) '
         'values (%L, %L, ''pending'')',
         tests.get_supabase_uid('askili'), tests.get_supabase_uid('temiz')),
  '42501', null,
  'ASKIDAN SONRA: arkadaşlık isteği gönderemiyor'
);
select is(
  (select f.reason from public.add_friend_by_code(
     (select friend_code from public.profiles
       where id = tests.get_supabase_uid('askili'))) f),
  'askida',
  'kod yolu da kapalı ve nedeni ASKI olarak dönüyor'
);

-- ======================================== AŞIRI KİLİTLEME: okuma açık kalıyor
select ok(
  (select count(*) from public.mistakes
    where user_id = tests.get_supabase_uid('askili')) >= 2,
  'askıdaki kullanıcı KENDİ arşivini okumaya devam ediyor'
);
select is(
  (select s.suspended from public.my_sanction() s),
  true,
  'kendi durumunu görebiliyor (itiraz yolu için şart)'
);
select is(
  (select s.permanent from public.my_sanction() s),
  false,
  'süreli askı kalıcı yasak olarak gösterilmiyor'
);

select tests.authenticate_as('temiz');
select lives_ok(
  'insert into public.mistakes (subject, concept) '
  'values (''Tarih'', ''normal'')',
  'askıda OLMAYAN kullanıcı etkilenmiyor (aşırı kilitleme yok)'
);
select is(
  public.can_add_friends(tests.get_supabase_uid('temiz')),
  true,
  'askıda olmayan kullanıcı arkadaş ekleyebiliyor'
);

-- ================================================================== YETKİ
select throws_ok(
  format('select public.admin_suspend_user(%L, ''ban'')',
         tests.get_supabase_uid('dost')),
  'yetkisiz',
  'yönetici olmayan kimseyi yasaklayamıyor'
);
select ok(
  has_function_privilege('authenticated', 'public.is_suspended(uuid)', 'EXECUTE'),
  'is_suspended authenticated''a AÇIK — politika ifadeleri onu çağırıyor'
);

select * from finish();
rollback;
