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

select plan(12);

select tests.create_supabase_user('alice');    -- gönderen
select tests.create_supabase_user('bob');      -- alıcı
select tests.create_supabase_user('mallory');  -- ilgisiz

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

select * from finish();
rollback;
