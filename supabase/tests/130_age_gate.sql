-- 130 — Yaş kapısı: 13 sınırı zorlanıyor, veli onayı YOK (0063)
--
-- Bu dosya 130_guardian.sql'in yerini aldı. Eski dosya "18 altı ve onaysız
-- hesap arkadaş EKLEYEMİYOR"u kanıtlıyordu; o kural kalktı (13+ rejimi).
-- Yerine iki şey kanıtlanıyor:
--
--   1. Veli onayı nesnelerinin GERÇEKTEN gitmiş olduğu. "Ölü akış kalmasın"
--      iddiası ancak katalogda doğrulanırsa bir anlam taşır; `create or
--      replace` içeren eski bir göç yanlışlıkla yeniden koşarsa buradan görülür.
--   2. 13 yaş sınırının SUNUCUDA kestiği. Kullanım Koşulları bu sınırı ilan
--      ediyor; ilan edilip zorlanmayan bir sınır beyan-gerçek uyumsuzluğudur
--      (App Store 5.1.1 / Play Data Safety).

begin;
set search_path to public, extensions, tests;

select plan(27);

select tests.create_supabase_user('cocuk');
select tests.create_supabase_user('yetiskin');
select tests.create_supabase_user('hedef');

-- ================================================ YAPI: veli nesneleri gitti
select hasnt_table('public'::name, 'guardian_requests'::name,
                   'guardian_requests tablosu düşürüldü (veli e-postası saklanmıyor)');
select hasnt_column('public'::name, 'profiles'::name, 'guardian_email'::name,
                    'profiles.guardian_email düşürüldü — üçüncü kişinin adresi tutulmuyor');
select hasnt_function('public'::name, 'request_guardian_consent'::name,
                      '{text}'::name[],
                      'request_guardian_consent düşürüldü');
select hasnt_function('public'::name, 'confirm_guardian_consent'::name,
                      '{text}'::name[],
                      'confirm_guardian_consent düşürüldü');
select hasnt_function('public'::name, 'send_guardian_email'::name,
                      '{text,text,text}'::name[],
                      'send_guardian_email düşürüldü — veli postası gönderilmiyor');
select hasnt_function('public'::name, 'my_guardian_status'::name, '{}'::name[],
                      'my_guardian_status düşürüldü');
select has_function('public'::name, 'my_age_status'::name, '{}'::name[],
                    'yerine my_age_status geldi');

-- ================================================== KİLİT: yıl yalnızca RPC'den
select ok(not has_column_privilege('authenticated', 'public.profiles', 'birth_year', 'UPDATE'),
          'doğum yılı doğrudan yazılamaz (set_birth_year zorunlu)');

select tests.authenticate_as('cocuk');

select throws_ok(
  format('update public.profiles set birth_year = 2010 where id = %L',
         tests.get_supabase_uid('cocuk')),
  '42501', null,
  'kullanıcı yılı sütundan yazamıyor — 13 kapısı atlanamıyor'
);

-- ===================================================== 13 YAŞ SINIRI KESİYOR
-- Sınırın hemen altı ve bariz altı, ayrı SQLSTATE ile reddediliyor.
select throws_ok(
  format('select public.set_birth_year(%s)',
         extract(year from (now() at time zone 'Europe/Istanbul'))::int - 12),
  'KM013', null,
  '12 yaşındaki kullanıcı reddediliyor (sınırın bir yıl altı)'
);
select throws_ok(
  format('select public.set_birth_year(%s)',
         extract(year from (now() at time zone 'Europe/Istanbul'))::int - 8),
  'KM013', null,
  '8 yaşındaki kullanıcı reddediliyor'
);

-- Reddedilen deneme bir YAZMA değil: hesap kilitlenmiyor, kullanıcı tek
-- yazımlık hakkını kaybetmiyor.
select ok(
  (select birth_year is null from public.profiles
    where id = tests.get_supabase_uid('cocuk')),
  'reddedilen denemeden sonra yıl hâlâ boş — hesap bricklenmiyor'
);

select throws_ok(
  format('select public.set_birth_year(%s)',
         extract(year from (now() at time zone 'Europe/Istanbul'))::int - 120),
  '22023', null,
  '120 yaşındaki giriş hâlâ veri hatası (alt sınır korundu)'
);

-- Sınırın KENDİSİ geçerli: 13 yaşındaki kullanıcı girebiliyor.
select lives_ok(
  format('select public.set_birth_year(%s)',
         extract(year from (now() at time zone 'Europe/Istanbul'))::int - 13),
  '13 yaşındaki kullanıcı kabul ediliyor (sınır dâhil)'
);

select throws_ok(
  format('select public.set_birth_year(%s)',
         extract(year from (now() at time zone 'Europe/Istanbul'))::int - 14),
  '22023', null,
  'ikinci çağrı reddediliyor — yıl TEK YAZIMLIK kaldı'
);

-- =========================================================== DURUM OKUMASI
select is(
  (select a.birth_year_set from public.my_age_status() a),
  true,
  'my_age_status yılın yazıldığını söylüyor'
);
select is(
  public.is_minor_now(tests.get_supabase_uid('cocuk')),
  true,
  '13 yaşındaki kullanıcı reşit değil (türetiliyor, saklanmıyor)'
);

-- ================================ 18 ALTI ARKADAŞ EKLEME ARTIK AÇIK (karar)
-- Eski 130 bunun tersini iddia ediyordu. Kapının açıldığını kanıtlamak,
-- kapandığını kanıtlamak kadar önemli: sessizce kapalı kalan bir özellik
-- veli onayı kaldırıldığında ortaya çıkabilecek en sinsi gerilemedir.
select is(
  public.can_add_friends(tests.get_supabase_uid('cocuk')),
  true,
  '18 altı kullanıcı arkadaş ekleyebiliyor — veli onayı koşulu kalktı'
);

select tests.reset_role();
create temp table _hedef_code on commit drop as
  select friend_code as code from public.profiles
   where id = tests.get_supabase_uid('hedef');
grant select on _hedef_code to authenticated;

select tests.authenticate_as('cocuk');

select is(
  (select f.reason
     from _hedef_code h
     cross join lateral public.add_friend_by_code(h.code) f),
  'eklendi',
  '18 altı kullanıcı kodla gerçekten istek gönderebiliyor'
);
select is(
  (select count(*)::int from public.friendships
    where requester_id = tests.get_supabase_uid('cocuk')
      and addressee_id = tests.get_supabase_uid('hedef')),
  1,
  'arkadaşlık isteği satırı yazıldı'
);

-- ================================================================== REŞİT
select tests.authenticate_as('yetiskin');

select lives_ok(
  format('select public.set_birth_year(%s)',
         extract(year from (now() at time zone 'Europe/Istanbul'))::int - 30),
  'reşit kullanıcı yılını yazabiliyor'
);
select is(
  public.is_minor_now(tests.get_supabase_uid('yetiskin')),
  false,
  '30 yaşındaki kullanıcı reşit'
);

-- ================================ YAŞ KAPISI ANALİZİN VE DEPOLAMANIN ÖNÜNDE
-- (A-2, göç 0067). Onboarding sırası `firstCapture → age → …`, yani ilk
-- fotoğraf yaş bilinmeden çekiliyordu ve doğrudan OpenAI'a gidiyordu. İstemci
-- artık analizi erteliyor, ama bu kapı ondan BAĞIMSIZ: uç noktaya doğrudan
-- istek atan biri arayüzü hiç görmez.
--
-- 'yetiskin' yukarıda yılını yazdı → kapı ona AÇIK olmalı. Bu pozitif iddia
-- aşırı kilitlemeyi kapatıyor: kapı herkese kapalıysa uygulama çalışmaz.
select is(public.ai_age_ok(), true,
          'doğum yılı yazılmış kullanıcı analiz yaptırabiliyor');
select is(public.has_birth_year(tests.get_supabase_uid('yetiskin')), true,
          'has_birth_year dolu yılı görüyor');

select tests.create_supabase_user('yilsiz');
-- Konu doğrulaması (0071) fikstürlerdeki uydurma konuları reddederdi; bu
-- testin konusu o değil (bkz. seed.sql).
select tests.skip_topic_check();
select tests.authenticate_as('yilsiz');

select is(public.ai_age_ok(), false,
          'doğum yılı YOKKEN analiz reddediliyor (fotoğraf yurt dışına çıkmaz)');

-- Depolama tarafı: satır da yazılamıyor. Analiz kapısı tek başına yetmezdi —
-- 13 altı reddedilen bir kullanıcının fotoğrafı depoda kalabilirdi.
select throws_ok(
  format('insert into public.mistakes (user_id, subject, concept, photo_path)
          values (%L, ''Matematik'', ''Türev'', %L)',
         tests.get_supabase_uid('yilsiz'),
         tests.get_supabase_uid('yilsiz')::text || '/1.jpg'),
  '42501', null,
  'doğum yılı yokken hata satırı EKLENEMİYOR (fotoğraf depoda bırakılmaz)'
);

-- AŞIRI KİLİTLEME KARŞI-İDDİASI: yılı olan kullanıcı hâlâ ekleyebiliyor.
select tests.authenticate_as('yetiskin');
select lives_ok(
  format('insert into public.mistakes (user_id, subject, concept)
          values (%L, ''Matematik'', ''Türev'')',
         tests.get_supabase_uid('yetiskin')),
  'yılı olan kullanıcı soru eklemeye DEVAM ediyor'
);

select * from finish();
rollback;
