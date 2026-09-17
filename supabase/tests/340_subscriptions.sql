-- 340 — Abonelik defteri ve makbuz doğrulaması (0092/0093)
--
-- `profiles.premium_until` 0075'ten beri şemada duruyor ve kota rejiminin
-- TAMAMI ona dayanıyor, ama o sütunu yazan hiçbir kod yolu yoktu. Bu paket
-- yazma yolunu getiriyor — ve o yol PARA ile katman arasındaki bağ olduğu
-- için bu dosya deponun en sıkı iddialarını taşıyor.
--
-- BU DOSYANIN EN ÖNEMLİ ÜÇ İDDİASI:
--   1. İSTEMCİ KATMAN İDDİA EDEMEZ. `apply_subscription` `authenticated`'a
--      KAPALI, yalnızca `anon` + paylaşılan sır. Açık olsaydı kullanıcı
--      kendine bedava abonelik yazardı.
--   2. SIR YOKSA ABONELİK YAZILMAZ (fail-closed). Yanlış yapılandırılmış bir
--      ortam bedava premium basmamalı.
--   3. DEFTER İLE İZDÜŞÜM AYRIŞAMAZ. `profiles.premium_until`, defterdeki
--      aktif satırların en geç bitişine eşit; iade ANINDA düşürüyor.

begin;
set search_path to public, extensions, tests;

select plan(31);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('bob');

-- ============================================================== KATALOG
select has_table('public'::name, 'subscriptions'::name, 'defter tablosu var');
select is(
  (select relrowsecurity from pg_class
    where oid = 'public.subscriptions'::regclass),
  true, 'subscriptions üzerinde RLS AÇIK');
-- Politika YOK = yalnızca definer fonksiyonlar erişir (`ai_calls` deseni).
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'subscriptions'),
  0, 'subscriptions üzerinde HİÇ politika yok — sunucu sahipli');
select ok(not has_table_privilege('authenticated', 'public.subscriptions', 'SELECT'),
          'istemci defteri OKUYAMIYOR');
select ok(not has_table_privilege('authenticated', 'public.subscriptions', 'INSERT'),
          'istemci deftere YAZAMIYOR');
select ok(not has_table_privilege('authenticated', 'public.subscriptions', 'DELETE'),
          'istemci defteri SİLEMİYOR');
select ok(not has_table_privilege('anon', 'public.subscriptions', 'SELECT'),
          'anon da defteri okuyamıyor (RPC''nin kendisi definer)');
select has_index('public'::name, 'subscriptions'::name,
                 'subscriptions_txn_uniq'::name,
                 'bir makbuz iki hesaba bağlanamaz (tekil indeks)');

-- BU PAKETİN EN ÖNEMLİ TEK SATIRI.
select ok(not has_function_privilege(
            'authenticated',
            'public.apply_subscription(text, text, text, text, timestamptz, boolean, text, uuid, jsonb)',
            'EXECUTE'),
          'apply_subscription istemciye KAPALI — kullanıcı kendine abonelik yazamaz');
select ok(has_function_privilege(
            'anon',
            'public.apply_subscription(text, text, text, text, timestamptz, boolean, text, uuid, jsonb)',
            'EXECUTE'),
          'apply_subscription YALNIZCA anon''a açık (grant_ad_reward deseni)');
select ok(has_function_privilege('authenticated', 'public.subscription_state()', 'EXECUTE'),
          'subscription_state istemciye açık (görünümün FROM listesinde)');

-- `ai_state()` DEĞİŞMEDİ: abonelik sütunları ayrı fonksiyonda. Task 12'de tam
-- o OUT listesini büyütme denemesi `db reset`i patlatmıştı.
select has_column('public'::name, 'my_daily_state'::name,
                  'sub_status'::name, 'görünümde sub_status var');
select has_column('public'::name, 'my_daily_state'::name,
                  'sub_expires_at'::name, 'görünümde sub_expires_at var');

-- ============================================================== FAIL-CLOSED
select tests.reset_role();
delete from public.app_config where key = 'iap_secret';
select ok(
  not (select public.apply_subscription(
         'uydurma', 'ios', 'TXN-1', 'active', now() + interval '30 days',
         true, 'kimo_plus_monthly', tests.get_supabase_uid('alice'))),
  'SIR GİRİLMEMİŞSE abonelik YAZILMIYOR (fail-closed)');

insert into public.app_config (key, value) values ('iap_secret', 'test-sir')
  on conflict (key) do update set value = excluded.value;

select ok(
  not (select public.apply_subscription(
         'yanlis-sir', 'ios', 'TXN-1', 'active', now() + interval '30 days',
         true, 'kimo_plus_monthly', tests.get_supabase_uid('alice'))),
  'YANLIŞ sırla abonelik yazılmıyor');

-- ============================================================== YAZMA YOLU
select ok(
  (select public.apply_subscription(
     'test-sir', 'ios', 'TXN-1', 'active', now() + interval '30 days',
     true, 'kimo_plus_monthly', tests.get_supabase_uid('alice'))),
  'doğru sırla abonelik yazılıyor');

-- İZDÜŞÜM AYNI İŞLEMDE: defter ile premium_until ayrışamaz.
select is(
  (select p.premium_until from public.profiles p
    where p.id = tests.get_supabase_uid('alice')),
  (select s.expires_at from public.subscriptions s
    where s.user_id = tests.get_supabase_uid('alice')),
  'premium_until defterdeki bitişe EŞİT — iki kaynak ayrışamaz');

-- UÇTAN UCA: defter → premium_until → user_tier() → my_daily_state.ai_tier.
-- Task 12'nin çoklu çekim premium kilidi tam bu zincire bakıyor ve bugüne
-- kadar HİÇ açılmamıştı, çünkü `premium_until`i yazan bir yol yoktu.
select tests.authenticate_as('alice');
select is(
  (select ai_tier from public.my_daily_state),
  'premium',
  'katman PREMIUM oldu — çoklu çekim kilidi ilk kez gerçekten açılıyor');
select is(
  (select sub_status from public.my_daily_state),
  'active',
  'abonelik durumu istemciye görünüyor (sub_status)');
select ok(
  (select sub_renews from public.my_daily_state),
  'yenileme bilgisi istemciye görünüyor (sub_renews)');
select tests.reset_role();

-- ============================================================== İDEMPOTANS
select ok(
  (select public.apply_subscription(
     'test-sir', 'ios', 'TXN-1', 'active', now() + interval '30 days',
     true, 'kimo_plus_monthly', tests.get_supabase_uid('alice'))),
  'aynı makbuz ikinci kez yazılabiliyor (bildirim tekrar teslim edilebilir)');
select is(
  (select count(*)::int from public.subscriptions
    where user_id = tests.get_supabase_uid('alice')),
  1, 'ikinci yazım İKİNCİ SATIR üretmiyor — idempotent');

-- ============================================== BİR MAKBUZ İKİ HESABA OLMAZ
-- SONUÇ İSTİSNA DEĞİL, KARARA BAĞLANMIŞ `false` (0103 · Task 17 · T17-8).
--
-- Kısıt katalogda duruyor ve DEĞİŞMEDİ; değişen, ihlalin çağırana nasıl
-- göründüğü. Eskiden 23505 PostgREST üzerinden edge fonksiyonuna sızıyor ve
-- `verify-purchase`in genel `catch`inde 503'e dönüşüyordu — yani "geçici
-- arıza, yine dene". Durum ise kalıcı: makbuz başkasının. İstemci 503'te
-- satın almayı tamamlamıyor, mağaza teslimi tekrarlıyor, kullanıcı aynı
-- anlamsız hatayı görmeye devam ediyordu.
--
-- `lives_ok` BİLEREK: iddia "istisna FIRLATMIYOR" ve pgTAP bunu kendi
-- alt-işleminde yakalıyor. Düz bir `ok(not ...)` mutasyon altında işlemi
-- KOMPLE düşürürdü ve dosya "hiç çalışmadı" hâline gelirdi — kırmızı ile
-- bozuk arasındaki farkı kaybetmek, mutasyon kapısının işini bozar.
select lives_ok(
  format($q$select public.apply_subscription(
              'test-sir', 'ios', 'TXN-1', 'active', now() + interval '30 days',
              true, 'kimo_plus_monthly', %L)$q$,
         tests.get_supabase_uid('bob')),
  'çakışma İSTİSNA FIRLATMIYOR — karara bağlanmış sonuç dönüyor');
select ok(
  not (select public.apply_subscription(
         'test-sir', 'ios', 'TXN-1', 'active', now() + interval '30 days',
         true, 'kimo_plus_monthly', tests.get_supabase_uid('bob'))),
  'aynı makbuz İKİNCİ bir hesaba bağlanamıyor — dönen değer false');
select is(
  (select count(*)::int from public.subscriptions
    where user_id = tests.get_supabase_uid('bob')),
  0, 'çakışan makbuz ikinci hesapta satır AÇMADI');
select is(
  (select s.user_id from public.subscriptions s
    where s.platform = 'ios' and s.original_txn_id = 'TXN-1'),
  tests.get_supabase_uid('alice'),
  'makbuz hâlâ İLK hesaba bağlı — çakışma sahipliği devretmiyor');
select is(
  (select p.premium_until from public.profiles p
    where p.id = tests.get_supabase_uid('bob')),
  null,
  'ikinci hesaba premium YAZILMADI');

-- ============================================================== İADE
-- İade ANINDA düşürüyor: para geri verildi, hak da gitmeli. İptal
-- (`auto_renewing = false`) ise DÜŞÜRMÜYOR — ödenen dönem sonuna kadar premium.
select ok(
  (select public.apply_subscription(
     'test-sir', 'ios', 'TXN-1', 'refunded', now() + interval '30 days',
     false, 'kimo_plus_monthly')),
  'iade bildirimi yazıldı (kullanıcı DEFTERDEN çözüldü — p_user null)');
select is(
  (select p.premium_until from public.profiles p
    where p.id = tests.get_supabase_uid('alice')),
  null,
  'İADE premium''u ANINDA düşürdü — bitiş tarihi gelecekte olsa bile');

-- ============================================================== BİLİNMEYEN
select ok(
  not (select public.apply_subscription(
         'test-sir', 'android', 'BILINMEYEN', 'active',
         now() + interval '30 days', true, 'kimo_plus_monthly')),
  'bilinmeyen makbuz + p_user yok → false (uydurma kullanıcıya yazılmıyor)');

-- ============================================================== CRON
select is(
  (select count(*)::int from cron.job where jobname = 'subscriptions-reconcile'),
  1,
  'gecelik mutabakat zamanlanmış — webhook sessizce çalışmazsa ikinci katman');

select * from finish();
rollback;
