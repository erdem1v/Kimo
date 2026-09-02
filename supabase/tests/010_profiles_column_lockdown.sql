-- 010 — profiles: sütun düzeyi yazma yetkileri
--
-- İki katmanlı iddia. Sebep: 42501 BELİRSİZ — sütun ayrıcalığı reddi ile RLS
-- WITH CHECK ihlali aynı SQLSTATE'i veriyor. Yani tek başına throws_ok yeşil
-- yansa bile reddin sütun kilidinden geldiğini kanıtlamaz.
--   BİRİNCİL  : has_column_privilege() — katalogda gerçekten ne yazıyor
--   İKİNCİL   : throws_ok(42501)      — çalışma zamanında gerçekten reddediliyor
-- information_schema.column_privileges KULLANILMIYOR: sorgulayan role göre
-- filtreleniyor ve tablo düzeyi grant'ları sütunlara açmıyor, boş sonucu hiçbir
-- şey kanıtlamaz.

begin;
set search_path to public, extensions, tests;

select plan(28);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('mallory');

-- ============================================ KATALOG: kilitli olması gerekenler
select ok(not has_column_privilege('authenticated', 'public.profiles', 'league', 'UPDATE'),
          'league yazılamaz (0017 onu generated olmaktan çıkarıp açmıştı)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'dismissed_reports', 'UPDATE'),
          'dismissed_reports yazılamaz (haksız-şikayetçi yaptırımı sıfırlanamaz)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'is_system', 'UPDATE'),
          'is_system yazılamaz (aramadan gizlenme yok)');
-- Task 02 (göç 0047) bu üç ÖLÜ sütunu düşürdü: hiçbir kod okumuyor/yazmıyordu
-- ve arayüzde çalışmayan mekanikler gibi duruyorlardı. "Yazılamaz" iddiası
-- artık "hiç yok" iddiasına dönüştü — sütun geri gelirse test kırmızı olur.
select hasnt_column('public'::name, 'profiles'::name, 'guardian_consent'::name,
                    'guardian_consent düşürüldü (gerçek kayıt user_consents''te)');
select hasnt_column('public'::name, 'profiles'::name, 'is_minor'::name,
                    'is_minor düşürüldü (reşitlik birth_year''dan türetiliyor)');
select hasnt_column('public'::name, 'profiles'::name, 'hearts'::name,
                    'hearts düşürüldü (can artık rate_limits üzerinden)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'gems', 'UPDATE'),
          'gems yazılamaz');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'display_name', 'UPDATE'),
          'display_name yazılamaz');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'created_at', 'UPDATE'),
          'created_at yazılamaz');

-- is_admin artık sütun DEĞİL; public.admins tablosuna taşındı.
select hasnt_column('public'::name, 'profiles'::name, 'is_admin'::name,
                    'profiles.is_admin sütunu kaldırıldı (public.admins''e taşındı)');

-- ============================================ KATALOG: XP sütunları da kilitli
-- Bunlar 0026'da bilerek AÇIK bırakılmıştı (istemci onlara yazıyordu ve RPC'ler
-- henüz yoktu); 0036 kilitledi.
select ok(not has_column_privilege('authenticated', 'public.profiles', 'xp', 'UPDATE'),
          'xp yazılamaz (submit_* RPC''lerinden geçiyor)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'weekly_xp', 'UPDATE'),
          'weekly_xp yazılamaz (lig sıralaması sahtelenemez)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'nickname', 'UPDATE'),
          'nickname doğrudan yazılamaz (upsert_my_profile doğruluyor)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'updated_at', 'UPDATE'),
          'updated_at yazılamaz (touch_updated_at trigger''ı dolduruyor)');

-- ============================================ KATALOG: yazılabilir KALAN tek sütun
-- Bu yön en az diğeri kadar önemli: fazla kilitlemek uygulamayı sessizce kırar.
select ok(has_column_privilege('authenticated', 'public.profiles', 'avatar_path', 'UPDATE'),
          'avatar_path hâlâ yazılabilir (avatar yükleme akışı)');

-- ============================================ KATALOG: anon hiçbir şey yazamaz
select ok(not has_column_privilege('anon', 'public.profiles', 'nickname', 'UPDATE'),
          'anon nickname yazamaz');
select ok(not has_column_privilege('anon', 'public.profiles', 'xp', 'UPDATE'),
          'anon xp yazamaz');
select ok(not has_column_privilege('anon', 'public.profiles', 'league', 'UPDATE'),
          'anon league yazamaz');
select ok(not has_table_privilege('authenticated', 'public.profiles', 'INSERT'),
          'authenticated profil satırı EKLEYEMEZ (trigger + upsert_my_profile yeter)');

-- ============================================ DAVRANIŞ: gerçekten reddediliyor mu
select tests.authenticate_as('alice');

select throws_ok(
  format('update public.profiles set league = ''efsane'' where id = %L',
         tests.get_supabase_uid('alice')),
  '42501',
  'kullanıcı kendini en üst lige yazamaz'
);
select throws_ok(
  format('update public.profiles set dismissed_reports = 0 where id = %L',
         tests.get_supabase_uid('alice')),
  '42501',
  'kullanıcı haksız-şikayet sicilini sıfırlayamaz'
);
select throws_ok(
  format('update public.profiles set is_system = true where id = %L',
         tests.get_supabase_uid('alice')),
  '42501',
  'kullanıcı kendini sistem hesabı yapamaz'
);
-- Veli onayını kendi yazma denemesi artık SÜTUN OLMADIĞI için imkânsız;
-- yerine yeni yüzeyin aynı garantisi: doğum yılı bir kez yazılır.
select throws_ok(
  format('update public.profiles set birth_year = 2010 where id = %L',
         tests.get_supabase_uid('alice')),
  '42501',
  'kullanıcı doğum yılını doğrudan yazamaz (set_birth_year RPC''si zorunlu)'
);

-- ============================================ DAVRANIŞ: meşru akış çalışıyor
-- Takma ad artık RPC'den geçiyor (doğrulama orada).
select lives_ok(
  'select public.upsert_my_profile(''Ayşe'')',
  'takma adını RPC ile güncelleyebiliyor'
);
select is(
  (select nickname from public.profiles where id = tests.get_supabase_uid('alice')),
  'Ayşe',
  'takma ad gerçekten yazıldı'
);

-- Kalan tek doğrudan yazma: avatar yolu (CHECK kısıtı kendi klasörüne hapsediyor).
select lives_ok(
  format('update public.profiles set avatar_path = %L where id = %L',
         tests.get_supabase_uid('alice')::text || '/a.jpg',
         tests.get_supabase_uid('alice')),
  'avatar yolunu güncelleyebiliyor'
);

-- updated_at artık sunucu trigger''ı tarafından dolduruluyor
select ok(
  (select updated_at from public.profiles
    where id = tests.get_supabase_uid('alice')) > now() - interval '1 minute',
  'touch_updated_at trigger''ı updated_at''i güncelledi'
);

-- ============================================ RLS hâlâ satır sahipliğini koruyor
-- (WITH CHECK''i olmayan UPDATE politikasında USING yeni satıra da uygulanır,
--  yani satır bağışlama zaten mümkün değil. Burada 0 satır etkilenir, hata yok.)
select tests.authenticate_as('mallory');
select is(
  (select count(*)::int from public.profiles
    where id = tests.get_supabase_uid('alice') and nickname = 'Ayşe'),
  0,
  'mallory alice''in satırını GÖREMİYOR (RLS select)'
);

select * from finish();
rollback;
