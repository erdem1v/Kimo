-- 300 — Ödüllü reklam: sunucu tarafı doğrulanmış ödül (0076)
--
-- ÜRÜN: hak bitince kullanıcı isteyerek reklam izliyor, 1 analiz hakkı
-- kazanıyor, günde en fazla 3. Ödül PENCEREYİ açıyor, aylık cap'i AÇMIYOR.
--
-- BU DOSYANIN EN ÖNEMLİ İDDİASI: `grant_ad_reward` `authenticated`'a KAPALI.
-- Açık olsaydı istemci kendi hakkını basar ve sunucu tarafı doğrulamanın
-- tamamı dekora dönerdi.

begin;
set search_path to public, extensions, tests;

select plan(39);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('mallory');

-- ============================================================== YAPI
select has_table('public'::name, 'ad_rewards'::name, 'ad_rewards tablosu var');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.ad_rewards'::regclass),
  'ad_rewards üzerinde RLS açık'
);
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'ad_rewards'),
  0,
  'ad_rewards üzerinde HİÇ politika yok'
);
select ok(not has_table_privilege('authenticated', 'public.ad_rewards', 'SELECT'),
          'ödül tablosu okunamıyor');
-- `status` yazılabilse istemci kendi bekleyen satırını `granted` yapıp
-- reklamı hiç izlemeden hak kazanırdı.
select ok(not has_table_privilege('authenticated', 'public.ad_rewards', 'UPDATE'),
          'ödül tablosu GÜNCELLENEMİYOR — status kendi kendine granted olamaz');
select ok(not has_table_privilege('authenticated', 'public.ad_rewards', 'INSERT'),
          'ödül satırı eklenemiyor');
select ok(not has_table_privilege('anon', 'public.ad_rewards', 'SELECT'),
          'anon da okuyamıyor');

-- PAKETİN EN ÖNEMLİ TEK İDDİASI.
select ok(not has_function_privilege(
            'authenticated',
            'public.grant_ad_reward(uuid, text, text)', 'EXECUTE'),
          'grant_ad_reward authenticated''a KAPALI — istemci hak basamaz');
select ok(has_function_privilege(
            'anon', 'public.grant_ad_reward(uuid, text, text)', 'EXECUTE'),
          'grant_ad_reward anon''a açık (SSV geri çağrısında JWT yok)');
select ok(has_function_privilege(
            'authenticated', 'public.start_ad_reward()', 'EXECUTE'),
          'start_ad_reward istemciye açık');

-- Kapsam kısıtları KATALOGDA, fonksiyon mantığında değil.
select has_index('public'::name, 'ad_rewards'::name,
                 'ad_rewards_one_pending'::name,
                 'kullanıcı başına tek bekleyen satır indeksi var');
select has_index('public'::name, 'ad_rewards'::name,
                 'ad_rewards_txn_uniq'::name,
                 'işlem kimliği tekil indeksi var (tekrar oynatma kapalı)');

-- ====================================================== FİKSTÜR
-- Pencereyi 0'a indiriyoruz: kullanıcı window_full, ay boş → reklam yolu
-- anlamlı. 10 çağrı yapmak yerine yapılandırmayı kullanmak aynı zamanda
-- app_config yolunu da sınıyor.
select tests.reset_role();
insert into public.app_config (key, value) values
  ('ai_window_free', '0'),
  ('ad_reward_secret', 'test-sir-1')
on conflict (key) do update set value = excluded.value;

select tests.authenticate_as('alice');
select is((select ai_state from public.my_daily_state), 'window_full',
          'fikstür: alice pencere dolu');
select is((select ad_offer from public.my_daily_state), true,
          'reklam yolu SUNULUYOR (ücretsiz, ay boş, pencere dolu, tavan var)');
select is((select ad_rewards_left from public.my_daily_state), 3,
          'günde 3 reklam hakkı');

-- İstemci RPC'yi doğrudan çağıramıyor.
select throws_ok(
  $$select public.grant_ad_reward(
      '00000000-0000-0000-0000-000000000001'::uuid, 'tx', 'test-sir-1')$$,
  '42501',
  null,
  'alice grant_ad_reward''ı doğrudan çağıramıyor'
);

-- ====================================================== NONCE
select ok((select s.ok from public.start_ad_reward() s),
          'start_ad_reward nonce veriyor');
-- Ağ kesilip kullanıcı yeniden dokunursa AYNI nonce dönmeli ve tabloda tek
-- bekleyen satır kalmalı; kısmi tekil indeks bunu şema düzeyinde garanti
-- ediyor.
select is(
  (select s.ad_nonce from public.start_ad_reward() s),
  (select s.ad_nonce from public.start_ad_reward() s),
  'ikinci çağrı AYNI nonce''u döndürüyor (idempotent)'
);
select tests.reset_role();
select is(
  (select count(*)::int from public.ad_rewards
    where user_id = tests.get_supabase_uid('alice') and status = 'pending'),
  1,
  'tabloda tek bekleyen satır var — bekleyenler birikmiyor'
);

-- ====================================================== SIR
select is(
  public.grant_ad_reward(
    (select nonce from public.ad_rewards
      where user_id = tests.get_supabase_uid('alice') and status = 'pending'),
    'tx-1', 'yanlis-sir'),
  false,
  'YANLIŞ sırla ödül verilmiyor'
);

-- FAIL-CLOSED: `signup_ip_salt`'ın (fail-open) TERSİ. Kota sayıları
-- yapılandırılmamışsa akış devam ediyor; kimlik doğrulama sırrı
-- yapılandırılmamışsa ödül DURUYOR.
delete from public.app_config where key = 'ad_reward_secret';
select is(
  public.grant_ad_reward(
    (select nonce from public.ad_rewards
      where user_id = tests.get_supabase_uid('alice') and status = 'pending'),
    'tx-1', 'test-sir-1'),
  false,
  'SIR YOKKEN ödül verilmiyor (fail-closed)'
);
insert into public.app_config (key, value) values ('ad_reward_secret', 'test-sir-1')
on conflict (key) do update set value = excluded.value;

-- ====================================================== ÖDÜL
select is(
  public.grant_ad_reward(
    (select nonce from public.ad_rewards
      where user_id = tests.get_supabase_uid('alice') and status = 'pending'),
    'tx-1', 'test-sir-1'),
  true,
  'doğru sır + geçerli nonce → ödül veriliyor'
);
select is(
  (select count(*)::int from public.ad_rewards
    where user_id = tests.get_supabase_uid('alice') and status = 'granted'),
  1,
  'bir granted satır'
);

select tests.authenticate_as('alice');
select is((select ai_window_left from public.my_daily_state), 1,
          'ödül PENCEREYİ açıyor (+1)');
select is((select ad_rewards_left from public.my_daily_state), 2,
          'günlük reklam hakkı 3 → 2');
select is((select ai_state from public.my_daily_state), 'low',
          'hak geldi, durum artık dolu değil');

-- Ödül harcanınca işaretleniyor ve pencere tekrar kapanıyor.
select is((select allowed from public.consume_ai_use()), true,
          'ödülle açılan hak harcanabiliyor');
select tests.reset_role();
select is(
  (select count(*)::int from public.ad_rewards
    where user_id = tests.get_supabase_uid('alice')
      and status = 'granted' and consumed_at is not null),
  1,
  'harcanan ödül consumed_at ile işaretlendi'
);
select tests.authenticate_as('alice');
select is((select ai_window_left from public.my_daily_state), 0,
          'ödül harcandı, pencere yeniden kapalı');

-- ====================================================== TEKRAR OYNATMA
select tests.reset_role();
select is(
  public.grant_ad_reward(
    (select nonce from public.ad_rewards
      where user_id = tests.get_supabase_uid('alice') and status = 'granted'),
    'tx-1', 'test-sir-1'),
  true,
  'AYNI işlem kimliğiyle tekrar → true (AdMob 200 alsın, döngüye girmesin)'
);
select is(
  (select count(*)::int from public.ad_rewards
    where user_id = tests.get_supabase_uid('alice') and status = 'granted'),
  1,
  'tekrar oynatma İKİNCİ HAK ÜRETMİYOR'
);

-- ====================================================== GÜNLÜK TAVAN
-- Kalan iki hakkı da verip tavanı doldur.
select tests.authenticate_as('alice');
select ok((select s.ok from public.start_ad_reward() s), 'ikinci reklam başlıyor');
select tests.reset_role();
select ok(
  public.grant_ad_reward(
    (select nonce from public.ad_rewards
      where user_id = tests.get_supabase_uid('alice') and status = 'pending'),
    'tx-2', 'test-sir-1'),
  'ikinci ödül verildi'
);
select tests.authenticate_as('alice');
select ok((select s.ok from public.start_ad_reward() s), 'üçüncü reklam başlıyor');
select tests.reset_role();
select ok(
  public.grant_ad_reward(
    (select nonce from public.ad_rewards
      where user_id = tests.get_supabase_uid('alice') and status = 'pending'),
    'tx-3', 'test-sir-1'),
  'üçüncü ödül verildi'
);

select tests.authenticate_as('alice');
select is((select s.reason from public.start_ad_reward() s), 'no_rewards_left',
          'günlük tavan dolunca yeni reklam BAŞLAMIYOR');

-- ====================================================== AYLIK CAP
-- KARANLIK DESEN KORUMASI: kullanılamayacak bir ödül için reklam
-- gösterilmiyor. İki katman — hem `ad_offer` false hem RPC reddediyor.
select tests.reset_role();
delete from public.ad_rewards where user_id = tests.get_supabase_uid('mallory');
insert into public.app_config (key, value) values ('ai_month_free', '0')
on conflict (key) do update set value = excluded.value;

select tests.authenticate_as('mallory');
select is((select ai_state from public.my_daily_state), 'month_full',
          'mallory aylık cap dolu');
select is((select ad_offer from public.my_daily_state), false,
          'ay doluyken reklam yolu ÇİZİLMİYOR');
select is((select s.reason from public.start_ad_reward() s), 'month_full',
          'ay doluyken RPC de reddediyor — düğmenin çizilmemesi tek başına '
          'bir güvenlik kontrolü değil');

select * from finish();
rollback;
