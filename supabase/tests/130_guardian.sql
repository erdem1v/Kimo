-- 130 — Yaş kapısı ve veli onayı (0043)
--
-- Task 01 açıkça uyarmıştı: "defter onayın denetlenebilir kaydı, paylaşımın
-- ZORLAYICISI DEĞİL. Bunu 'onay artık zorunlu tutuluyor' diye okumayın."
-- Bu dosya o cümlenin artık bir özellik için GEÇERSİZ olduğunu kanıtlıyor:
-- 18 yaşından küçük ve onaysız bir hesap arkadaş EKLEYEMİYOR ve bu SUNUCUDA
-- zorlanıyor, arayüzde değil.

begin;
set search_path to public, extensions, tests;

select plan(21);

select tests.create_supabase_user('cocuk');
select tests.create_supabase_user('yetiskin');
select tests.create_supabase_user('hedef');

-- ============================================================== YAPI
select has_table('public'::name, 'guardian_requests'::name,
                 'guardian_requests tablosu var');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.guardian_requests'::regclass),
  'guardian_requests üzerinde RLS açık'
);
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'guardian_requests'),
  0,
  'guardian_requests üzerinde HİÇ politika yok'
);
select ok(not has_table_privilege('authenticated', 'public.guardian_requests', 'SELECT'),
          'onay istekleri okunamıyor — token hash''leri sızmıyor');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'birth_year', 'UPDATE'),
          'doğum yılı doğrudan yazılamaz');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'guardian_email', 'UPDATE'),
          'veli e-postası doğrudan yazılamaz');

-- ============================================================== DOĞUM YILI
select tests.authenticate_as('cocuk');

-- Yaş bilinmiyorken KAPALI TARAF: reşit sayılmıyor.
select ok(
  public.is_minor_now(tests.get_supabase_uid('cocuk')),
  'doğum yılı yokken kullanıcı reşit SAYILMIYOR (kapalı taraf)'
);
select ok(
  not public.can_add_friends(tests.get_supabase_uid('cocuk')),
  'yaş bilinmiyorken arkadaş ekleme kapalı'
);

select lives_ok(
  format('select public.set_birth_year(%s)',
         extract(year from now())::int - 15),
  'doğum yılı bir kez yazılabiliyor'
);

-- TEK YAZIMLIK: 18 altı kullanıcı kısıtı aşmak için yılını büyütemez.
select throws_ok(
  format('select public.set_birth_year(%s)',
         extract(year from now())::int - 30),
  '22023',
  'doğum yılı İKİNCİ kez yazılamıyor — kısıt yılı değiştirerek aşılamaz'
);

select throws_ok(
  format('select public.set_birth_year(%s)', extract(year from now())::int),
  '22023',
  'saçma yıl reddediliyor'
);

-- ================================================== ONAYSIZ: ARKADAŞ EKLEME YOK
select ok(
  public.is_minor_now(tests.get_supabase_uid('cocuk')),
  '15 yaşındaki kullanıcı reşit değil'
);
select ok(
  not public.can_add_friends(tests.get_supabase_uid('cocuk')),
  'onay gelmeden arkadaş ekleme kapalı'
);

select throws_ok(
  format('insert into public.friendships (requester_id, addressee_id) values (%L, %L)',
         tests.get_supabase_uid('cocuk'), tests.get_supabase_uid('hedef')),
  '42501',
  'SUNUCU reddediyor: onaysız reşit olmayan hesap arkadaş isteği gönderemiyor'
);

-- ====================================================== ONAY GELİNCE AÇILIYOR
-- Veli bağlantıya tıkladığında ne olduğunu taklit ediyoruz: defter kaydı
-- doğrudan yazılıyor (gerçekte confirm_guardian_consent yazıyor).
select tests.reset_role();
insert into public.user_consents (user_id, kind, granted, source)
values (tests.get_supabase_uid('cocuk'), 'guardian', true, 'guardian_email');

select tests.authenticate_as('cocuk');
select ok(
  public.can_add_friends(tests.get_supabase_uid('cocuk')),
  'onay deftere düşünce arkadaş ekleme AÇILIYOR'
);
select lives_ok(
  format('insert into public.friendships (requester_id, addressee_id) values (%L, %L)',
         tests.get_supabase_uid('cocuk'), tests.get_supabase_uid('hedef')),
  'onaydan sonra istek gönderilebiliyor'
);

-- ====================================================== ONAY GERİ ALINABİLİR
-- Defter geçmişi tutuyor; en son kayıt geçerli. Geri alınınca kapı yeniden
-- kapanmalı — aksi hâlde "onayı geri çekmek" işlevsiz bir düğme olurdu.
select tests.reset_role();
insert into public.user_consents (user_id, kind, granted, source)
values (tests.get_supabase_uid('cocuk'), 'guardian', false, 'settings');

select tests.authenticate_as('cocuk');
select ok(
  not public.can_add_friends(tests.get_supabase_uid('cocuk')),
  'onay geri alınınca arkadaş ekleme YENİDEN kapanıyor'
);

-- =========================================================== REŞİT KULLANICI
select tests.authenticate_as('yetiskin');
select lives_ok(
  format('select public.set_birth_year(%s)',
         extract(year from now())::int - 25),
  'reşit kullanıcı doğum yılını yazabiliyor'
);
select ok(
  not public.is_minor_now(tests.get_supabase_uid('yetiskin')),
  '25 yaşındaki kullanıcı reşit'
);
select ok(
  public.can_add_friends(tests.get_supabase_uid('yetiskin')),
  'reşit kullanıcıya veli onayı SORULMUYOR — kapı açık'
);

-- ------------------------------------------------------- defter dokunulmazlığı
select throws_ok(
  format('update public.user_consents set granted = true where user_id = %L',
         tests.get_supabase_uid('cocuk')),
  '42501',
  'onay kaydı hâlâ değiştirilemez (Değişmez 7 korunuyor)'
);

select * from finish();
rollback;
