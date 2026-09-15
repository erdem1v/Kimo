-- 085 — question_sends: alıcı gönderiyi tahrif edemez (YENİ BULGU)
--
-- Denetim raporunda yok, kilitlemeyi tasarlarken çıktı. `sends_update_receiver`
-- politikası şöyle:
--     using (auth.uid() = receiver_id) with check (auth.uid() = receiver_id)
-- Sütun kısıtı yok. Yani ALICI, kendisine gelen satırda sender_id, mistake_id ve
-- note'u yeniden yazabiliyordu: "falanca arkadaşım bana şu soruyu şu notla
-- göndermiş" diye sahte kanıt üretilebiliyordu.
--
-- RLS bunu ifade EDEMEZ (politika sütun seçemez); sütun ayrıcalığı tek satırda
-- eder. Bu dosya tam olarak o farkı gösteriyor.

begin;
set search_path to public, extensions, tests;

select plan(30);

select tests.create_supabase_user('alice');    -- gönderen
select tests.create_supabase_user('bob');      -- alıcı
select tests.create_supabase_user('mallory');  -- ilgisiz
-- Yaş kapısı (0067) `mistakes` INSERT'te doğum yılı şart koşuyor; bu testin
-- konusu o değil, fikstürün kurulabilmesi için ön koşul (bkz. seed.sql).
select tests.age_all_users();
-- Konu doğrulaması (0071) fikstürlerdeki uydurma konuları reddederdi; bu
-- testin konusu o değil (bkz. seed.sql).
select tests.skip_topic_check();

-- ============================================================== KATALOG
select ok(not has_column_privilege('authenticated', 'public.question_sends', 'sender_id', 'UPDATE'),
          'alıcı sender_id''yi değiştiremez (sahte gönderen üretilemez)');
select ok(not has_column_privilege('authenticated', 'public.question_sends', 'mistake_id', 'UPDATE'),
          'alıcı mistake_id''yi değiştiremez (sahte soru bağlanamaz)');
select ok(not has_column_privilege('authenticated', 'public.question_sends', 'note', 'UPDATE'),
          'alıcı note''u değiştiremez (sahte not yazılamaz)');
select ok(not has_column_privilege('authenticated', 'public.question_sends', 'receiver_id', 'UPDATE'),
          'receiver_id değiştirilemez');

-- 0036 sonrası: question_sends üzerinde İSTEMCİYE HİÇBİR UPDATE kalmadı.
-- `solved_at`/`correct` artık yalnızca submit_sent_answer RPC'sinden yazılıyor.
select ok(not has_column_privilege('authenticated', 'public.question_sends', 'solved_at', 'UPDATE'),
          'solved_at istemciden yazılamaz (submit_sent_answer RPC''sine taşındı)');
select ok(not has_column_privilege('authenticated', 'public.question_sends', 'correct', 'UPDATE'),
          'correct istemciden yazılamaz (skor sunucuda hesaplanır)');
select ok(has_column_privilege('authenticated', 'public.question_sends', 'sender_id', 'INSERT'),
          'sender_id INSERT edilebilir (gönderme akışı)');
select ok(has_column_privilege('authenticated', 'public.question_sends', 'note', 'INSERT'),
          'note INSERT edilebilir (gönderirken not eklenebilir)');

-- ==================================================== DELETE KAPALI (0090)
-- `sends_delete_own` politikası 0008'den beri hem gönderene hem alıcıya satır
-- silme hakkı veriyordu ve hiçbir lockdown göçü bu tablo için `revoke_delete`
-- yazmamıştı. Bu, 0050a'nın "satır DURUYOR, moderasyon izi kaybolmaz"
-- değişmezini deliyordu: taciz eden bir gönderen, alıcı şikâyet etmeden önce
-- satırı silerse `report_received_question` "bu gönderim sana ait değil" ile
-- patlar ve şikâyet HİÇ açılamazdı.
--
-- İstemci bu yolu hiç kullanmıyordu (`dismiss_received_question` RPC'si var),
-- yani kapatmanın ürüne maliyeti sıfır. POLİTİKA DÜŞÜRÜLMEDİ — 0084'ün
-- `mistakes` için yazdığı gerekçe: definer yollar RLS'i zaten atlıyor ve
-- politikayı silmek katalogda "silme hiç düşünülmemiş" izlenimi bırakırdı.
select ok(not has_table_privilege('authenticated', 'public.question_sends', 'DELETE'),
          'question_sends DELETE yetkisi YOK — moderasyon izi silinemiyor');

-- ============================================================== FİKSTÜR
-- Ayrıcalıklı oturumda kur (postgres tablo sahibi, RLS ona uygulanmaz).
select tests.reset_role();

insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'), 'accepted');

insert into public.mistakes (user_id, subject, concept, mistake_type, photo_path)
values (tests.get_supabase_uid('alice'), 'Fizik', 'Kuvvet', 'islem_hatasi',
        tests.get_supabase_uid('alice')::text || '/soru.jpg');

insert into public.question_sends (sender_id, receiver_id, mistake_id, note)
select tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'), m.id, 'kolay gelsin'
  from public.mistakes m where m.user_id = tests.get_supabase_uid('alice') limit 1;

-- ============================================================== DAVRANIŞ
select tests.authenticate_as('bob');

select throws_ok(
  format('update public.question_sends set sender_id = %L',
         tests.get_supabase_uid('mallory')),
  '42501', null,
  'alıcı gönderiyi başkasından gelmiş gibi gösteremez'
);
select throws_ok(
  'update public.question_sends set note = ''uydurma not''',
  '42501', null,
  'alıcı gönderenin notunu değiştiremez'
);

-- Meşru akış artık RPC'den geçiyor: doğrudan UPDATE reddedilmeli.
select throws_ok(
  'update public.question_sends set solved_at = now(), correct = true',
  '42501', null,
  'alıcı çözüldü işaretini doğrudan yazamaz (submit_sent_answer zorunlu)'
);

-- Arkadaşlık kuralı (mevcut doğru karar) bozulmadı: mallory arkadaş değil.
select tests.authenticate_as('mallory');
select is(
  (select count(*)::int from public.question_sends),
  0,
  'ilgisiz kullanıcı gönderileri göremiyor (mevcut RLS korundu)'
);

-- ==========================================================================
-- Task 12 · P4 — NOT SINIRI, HIZ SINIRI, TEK ÇAĞRIDA GÖNDERİM (0081)
-- ==========================================================================

select tests.reset_role();

-- ------------------------------------------------------------- katalog
select has_column('public'::name, 'received_questions'::name,
                  'sender_avatar_path'::name,
                  'gelen kutusu görünümü gönderen avatarını taşıyor (n5)');
select ok(has_function_privilege(
            'authenticated',
            'public.send_question_to_friends(uuid, uuid[], text)', 'EXECUTE'),
          'toplu gönderim RPC''si istemciye açık');
-- İstemci sayacı KENDİSİ artıramamalı; sarmalayıcının var olma sebebi bu.
select ok(not has_function_privilege(
            'authenticated', 'public.bump_rate_limit(text, int, text)', 'EXECUTE'),
          'bump_rate_limit hâlâ istemciye KAPALI');

-- --------------------------------------------------- not uzunluğu (VERİ KATMANI)
-- Bu iddianın konusu sayı değil SINIRIN YERİ: eskiden sınır yalnızca
-- istemcideki `maxLength` idi ve PostgREST'e doğrudan istek atan yol
-- SINIRSIZDI.
select throws_ok(
  format($q$insert into public.question_sends (sender_id, receiver_id, mistake_id, note)
             select %L, %L, m.id, repeat('x', 251)
               from public.mistakes m where m.user_id = %L limit 1$q$,
         tests.get_supabase_uid('alice'), tests.get_supabase_uid('mallory'),
         tests.get_supabase_uid('alice')),
  '23514', null,
  '251 karakterlik not VERİTABANINDA reddediliyor'
);

-- ------------------------------------------------------------- fikstür
-- İki yeni soru: biri tekrar yasağını, biri arkadaş başına tavanı sınamak için.
insert into public.mistakes (user_id, subject, concept, mistake_type, photo_path)
values (tests.get_supabase_uid('alice'), 'Fizik', 'Basınç', 'islem_hatasi',
        tests.get_supabase_uid('alice')::text || '/q2.jpg'),
       (tests.get_supabase_uid('alice'), 'Fizik', 'Isı', 'islem_hatasi',
        tests.get_supabase_uid('alice')::text || '/q3.jpg');

-- TARAMA 'clear'E ÇEKİLİYOR. 0087 gönderim RPC'sine içerik kapısını ekledi
-- (`moderation = 'ok' and photo_scan = 'clear'`) — RLS politikasının zaten
-- istediği koşulun DEFINER gövdesinde tekrarı. Fotoğraflı her kayıt
-- tetikleyiciyle 'pending' doğuyor (0050), yani bu satır olmadan aşağıdaki
-- gönderimlerin hepsi `not_sendable` dönüyor ve üç iddia birden, sınamak
-- istedikleri şeyle (tek çağrıda yazım, kendine gönderim, günlük tavan)
-- ilgisi olmayan bir sebeple düşüyor. `photo_scan` UPDATE'i istemciye kapalı,
-- bu yüzden ayrıcalıklı bölümde.
update public.mistakes set photo_scan = 'clear'
 where user_id = tests.get_supabase_uid('alice');

-- Sınırları DÜŞÜRÜP sınıyoruz, 3 çağrı yapıp değil (100_ai_quota deseni).
insert into public.app_config (key, value) values ('qsend_daily', '2')
on conflict (key) do update set value = excluded.value;

-- ------------------------------------------------------------- davranış
select tests.authenticate_as('alice');

select is(
  (select sent from public.send_question_to_friends(
     (select id from public.mistakes
       where user_id = tests.get_supabase_uid('alice')
         and concept = 'Basınç' limit 1),
     array[tests.get_supabase_uid('bob')], 'kolay gelsin')),
  1,
  'arkadaşa gönderim TEK çağrıda yazılıyor'
);

select is(
  (select sent from public.send_question_to_friends(
     (select id from public.mistakes
       where user_id = tests.get_supabase_uid('alice')
         and concept = 'Basınç' limit 1),
     array[tests.get_supabase_uid('bob')], null)),
  0,
  'AYNI soru aynı kişiye 30 gün içinde TEKRAR gitmiyor'
);

select is(
  (select blocked from public.send_question_to_friends(
     (select id from public.mistakes
       where user_id = tests.get_supabase_uid('alice')
         and concept = 'Isı' limit 1),
     array[tests.get_supabase_uid('bob')], null)),
  1,
  'arkadaş başına GÜNLÜK tavan: aynı kişiye ikinci soru gitmiyor'
);

select is(
  (select sent from public.send_question_to_friends(
     (select id from public.mistakes
       where user_id = tests.get_supabase_uid('alice')
         and concept = 'Isı' limit 1),
     array[tests.get_supabase_uid('mallory')], null)),
  0,
  'ARKADAŞ OLMAYANA gitmiyor — kontrol RPC gövdesinde (definer RLS''i atlıyor)'
);

-- Çalışma zamanı karşılığı: gönderen kendi satırını bile silemiyor.
select throws_ok(
  format($q$delete from public.question_sends where sender_id = %L$q$,
         tests.get_supabase_uid('alice')),
  '42501', null,
  'gönderen kendi gönderimini SİLEMİYOR (dismiss ile gizlenir, silinmez)'
);

-- ==================================================== SAHİPLİK (definer/RLS)
-- `send_question_to_friends` SECURITY DEFINER, yani `question_sends` ve
-- `mistakes` üzerindeki RLS DEĞERLENDİRİLMİYOR (depo bunu 0062:517 ve
-- 0063:79-81'de zaten yazıyor; hiçbir yerde `force row level security` yok).
-- İlk yazımda politikanın altı koşulu "tek doğruluk kaynağı" sayılıp gövdede
-- TEKRARLANMAMIŞTI: `p_mistake` keyfi bir uuid olduğu için kullanıcı
-- BAŞKASININ sorusunu arkadaşlarına gönderebiliyordu.
--
-- BU DOSYANIN EN ÖNEMLİ İDDİASI BU: başkasının satırı gönderilemiyor.
select tests.reset_role();
insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('bob'), tests.get_supabase_uid('mallory'), 'accepted')
on conflict do nothing;
select tests.authenticate_as('bob');
select is(
  (select sent from public.send_question_to_friends(
     (select id from public.mistakes
       where user_id = tests.get_supabase_uid('alice') limit 1),
     array[tests.get_supabase_uid('mallory')], null)),
  0,
  'BAŞKASININ sorusu gönderilemiyor — sahiplik gövdede zorlanıyor'
);
select is(
  (select reason from public.send_question_to_friends(
     (select id from public.mistakes
       where user_id = tests.get_supabase_uid('alice') limit 1),
     array[tests.get_supabase_uid('mallory')], null)),
  'not_sendable',
  'red sebebi ayrımlanmadan "not_sendable" dönüyor'
);
select tests.reset_role();
select tests.authenticate_as('alice');

select is(
  (select reason from public.send_question_to_friends(
     (select id from public.mistakes
       where user_id = tests.get_supabase_uid('alice')
         and concept = 'Isı' limit 1),
     array[tests.get_supabase_uid('alice')], null)),
  'none',
  'kendine gönderim sayılmıyor'
);

select throws_ok(
  format($q$select * from public.send_question_to_friends(
              (select id from public.mistakes where user_id = %L limit 1),
              array[%L]::uuid[], repeat('y', 251))$q$,
         tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob')),
  '22023', null,
  'RPC 250 karakteri aşan notu reddediyor (istemciden ÖNCE sunucu)'
);

select throws_ok(
  format($q$select * from public.send_question_to_friends(
              (select id from public.mistakes where user_id = %L limit 1),
              (select array_agg(gen_random_uuid()) from generate_series(1, 21)))$q$,
         tests.get_supabase_uid('alice')),
  '22023', null,
  'tek çağrıda 20''den fazla alıcı reddediliyor'
);

-- Günlük tavan gerçekten bağlıyor mu: tavan 2, ALTINDAKİ İKİ GÖNDERİM
-- BURADA YAPILIYOR.
--
-- Eski yorum "iki gönderim yapıldı" diyordu ve yanlıştı: alice'in günlük
-- sayacı BİR kez artmıştı. Reddedilen denemeler (tekrar yasağı, arkadaş
-- başına tavan, arkadaş olmayan alıcı) günlük kovayı hiç bumplamıyor —
-- `bump_rate_limit`in `on conflict ... where n < p_limit` dalı tavana
-- gelince satırı GÜNCELLEMİYOR bile.
--
-- Sayıyı varsayım yerine fikstürde üretiyoruz: iki yeni arkadaş, birine
-- gönderim sayacı 2'ye çıkarıyor, ikincisi tavana çarpıyor. Aşağıdaki
-- "sayaç işlemişti" iddiası da bu sayede n = 2 görüyor.
select tests.reset_role();
select tests.create_supabase_user('deniz');
select tests.age_all_users();
insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('alice'), tests.get_supabase_uid('mallory'), 'accepted'),
       (tests.get_supabase_uid('alice'), tests.get_supabase_uid('deniz'), 'accepted');
select tests.authenticate_as('alice');

-- İKİNCİ GÖNDERİM (iddia değil, fikstür): günlük sayaç 2 oluyor.
select public.send_question_to_friends(
  (select id from public.mistakes
    where user_id = tests.get_supabase_uid('alice')
      and concept = 'Isı' limit 1),
  array[tests.get_supabase_uid('mallory')], null);

select is(
  (select reason from public.send_question_to_friends(
     (select id from public.mistakes
       where user_id = tests.get_supabase_uid('alice')
         and concept = 'Isı' limit 1),
     array[tests.get_supabase_uid('deniz')], null)),
  'daily_limit',
  'GÜNLÜK tavan dolunca kalan alıcılar denenmiyor'
);

-- Başarısızlık İSTİSNA DEĞİL: sayaç geri alınmadı, yani sınır gerçekten
-- bağlıyor (istisna olsaydı işlem geri alınır ve sayaç sıfırlanırdı).
select tests.reset_role();
select ok(
  (select n from public.rate_limits
    where user_id = tests.get_supabase_uid('alice')
      and bucket = 'qsend') >= 2,
  'sayaç işlemişti — başarısızlık istisna atmadığı için geri alınmadı'
);

-- ================== "SAYIYI 0 YAZ, ÖZELLİK KAPANSIN" YANLIŞTI (0094)
-- `bump_rate_limit` ilk INSERT'i `on conflict` dalına HİÇ GİRMEDEN yapıyordu;
-- `p_limit` yalnızca ÇAKIŞMA dalında okunuyordu. Yani `p_limit = 0` iken
-- pencere başına BİR çağrı geçiyordu: `qsend_daily = '0'` yazan operatör
-- özelliği kapattığını sanır ama her kullanıcı günde bir soru göndermeye
-- devam ederdi. Aynı tuzak `ai_refund_daily` dahil BÜTÜN kovalarda vardı.
--
-- Fonksiyon hiçbir role açık değil (yalnızca definer yollar çağırıyor), bu
-- yüzden iddia ÜRÜN DÜZEYİNDE yazılıyor.
select tests.reset_role();
insert into public.app_config (key, value) values ('qsend_daily', '0')
  on conflict (key) do update set value = excluded.value;
-- Taze bir gönderen: önceki bloklar alice'in kovalarını doldurdu.
select tests.create_supabase_user('zeynep');
select tests.age_all_users();
insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('zeynep'), tests.get_supabase_uid('bob'), 'accepted');
insert into public.mistakes (user_id, subject, concept, mistake_type, photo_path,
                             options, correct_index)
values (tests.get_supabase_uid('zeynep'), 'Fizik', 'Kuvvet', 'islem_hatasi',
        tests.get_supabase_uid('zeynep')::text || '/z.jpg',
        '["A","B"]'::jsonb, 0);
update public.mistakes set photo_scan = 'clear'
 where user_id = tests.get_supabase_uid('zeynep');
select tests.authenticate_as('zeynep');
select is(
  (select sent from public.send_question_to_friends(
     (select id from public.mistakes
       where user_id = tests.get_supabase_uid('zeynep') limit 1),
     array[tests.get_supabase_uid('bob')], null)),
  0,
  'qsend_daily = 0 GERÇEKTEN kapatıyor — ilk gönderim de geçmiyor');

select * from finish();
rollback;
