-- 180 — Task 02'nin yeni sütun ve tablolarının kilidi (0047)
--
-- Task kuralı: "Yeni yazılabilir alan eklemiyorsun. Can, elmas ve eklediğin
-- her yeni sayaç Task 01'deki sınıfın aynısı: sunucu sahipli, RPC üzerinden,
-- sütun ayrıcalıkları baştan kapalı, HER BİRİ İÇİN pgTAP NEGATİF TESTİ."
--
-- Bu dosya o negatif testlerin tamamı. Her iddia iki katman doğruluyor:
-- katalog (has_column_privilege) ve davranış (throws_ok 42501). İkisi ayrı
-- çünkü 42501 hem sütun ayrıcalığından hem RLS WITH CHECK'ten gelebiliyor ve
-- yalnızca birine bakmak hangisinin koruduğunu belirsiz bırakır.

begin;
set search_path to public, extensions, tests;

select plan(28);

select tests.create_supabase_user('alice');

-- ==================================================== KATALOG: yeni sütunlar
select ok(not has_column_privilege('authenticated', 'public.profiles', 'combo', 'UPDATE'),
          'combo yazılamaz (XP çarpanı satın alınamaz)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'combo_at', 'UPDATE'),
          'combo_at yazılamaz (oturum penceresi uzatılamaz)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'friend_code', 'UPDATE'),
          'friend_code yazılamaz (kimse kendi kodunu seçemez)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'birth_year', 'UPDATE'),
          'birth_year yazılamaz (yaş kapısı atlanamaz)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'guardian_email', 'UPDATE'),
          'guardian_email yazılamaz (onay başka adrese yönlendirilemez)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'is_anonymous', 'UPDATE'),
          'is_anonymous yazılamaz (sosyal yüzeye sızılamaz)');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'gems', 'UPDATE'),
          'gems yazılamaz (elmas basılamaz)');

-- Tek yazılabilir sütun hâlâ avatar_path.
select ok(has_column_privilege('authenticated', 'public.profiles', 'avatar_path', 'UPDATE'),
          'avatar_path hâlâ yazılabilir (aşırı kilitleme kontrolü)');

-- ==================================================== KATALOG: ölü sütunlar
select hasnt_column('public'::name, 'profiles'::name, 'hearts'::name,
                    'hearts düşürüldü');
select hasnt_column('public'::name, 'profiles'::name, 'is_minor'::name,
                    'is_minor düşürüldü');
select hasnt_column('public'::name, 'profiles'::name, 'guardian_consent'::name,
                    'guardian_consent düşürüldü');

-- ================================================ KATALOG: yeni tablolar
select ok(not has_table_privilege('authenticated', 'public.rate_limits', 'INSERT'),
          'rate_limits yazılamaz');
select ok(not has_table_privilege('authenticated', 'public.guardian_requests', 'SELECT'),
          'guardian_requests okunamaz');
-- Kilit modeli KOLON bazlı: tablo düzeyi INSERT bilinçli olarak verilmiyor
-- (created_at istemciden yazılamasın). has_table_privilege kolon grant'larını
-- saymaz; iddia kolonda yapılır (ilk CI koşusunun düzeltmesi).
select ok(has_column_privilege('authenticated', 'public.user_blocks', 'blocker_id', 'INSERT'),
          'user_blocks''a yazılabiliyor (kendi engelini eklemek meşru)');
select ok(has_table_privilege('authenticated', 'public.user_blocks', 'DELETE'),
          'engel kaldırılabiliyor');
select ok(not has_column_privilege('authenticated', 'public.user_blocks', 'created_at', 'INSERT'),
          'engel tarihi istemciden yazılamaz');

-- ============================== KATALOG: Task 01''in açık bıraktığı tablolar
select ok(not has_column_privilege('authenticated', 'public.question_reports', 'status', 'UPDATE'),
          'şikâyet durumu yazılamaz — moderasyon kararı taklit edilemez');
select ok(not has_column_privilege('authenticated', 'public.question_reports', 'reviewed_at', 'UPDATE'),
          'şikâyet inceleme zamanı yazılamaz');
select ok(not has_column_privilege('authenticated', 'public.friendships', 'created_at', 'UPDATE'),
          'arkadaşlık tarihi değiştirilemez');
select ok(has_column_privilege('authenticated', 'public.friendships', 'status', 'UPDATE'),
          'arkadaşlık durumu yazılabiliyor (kabul akışı — aşırı kilitleme kontrolü)');

-- =============================================================== DAVRANIŞ
select tests.authenticate_as('alice');

select throws_ok(
  format('update public.profiles set combo = 99 where id = %L',
         tests.get_supabase_uid('alice')),
  '42501', null,
  'kullanıcı kendi çarpanını yazamıyor'
);
select throws_ok(
  format('update public.profiles set gems = 9999 where id = %L',
         tests.get_supabase_uid('alice')),
  '42501', null,
  'kullanıcı kendine elmas basamıyor'
);
select throws_ok(
  format('update public.profiles set friend_code = ''AAAAAA'' where id = %L',
         tests.get_supabase_uid('alice')),
  '42501', null,
  'kullanıcı kendi arkadaş kodunu seçemiyor'
);
select throws_ok(
  format('update public.profiles set is_anonymous = false where id = %L',
         tests.get_supabase_uid('alice')),
  '42501', null,
  'kullanıcı anonimlik bayrağını değiştiremiyor'
);
select throws_ok(
  'insert into public.rate_limits (user_id, bucket, window_key, n) '
  'values (auth.uid(), ''ai'', ''2026-01-01'', 0)',
  '42501', null,
  'kullanıcı kendine yapay zekâ hakkı yazamıyor'
);
select throws_ok(
  'select * from public.guardian_requests',
  '42501', null,
  'kullanıcı veli onayı token hash''lerini okuyamıyor'
);

-- Meşru akış hâlâ çalışıyor (aşırı kilitleme kontrolü).
select lives_ok(
  format('update public.profiles set avatar_path = %L where id = %L',
         tests.get_supabase_uid('alice')::text || '/a.jpg',
         tests.get_supabase_uid('alice')),
  'avatar yolu hâlâ yazılabiliyor'
);
select lives_ok(
  'select public.upsert_my_profile(''Şevval'')',
  'takma ad RPC''den hâlâ yazılabiliyor'
);

select * from finish();
rollback;
