-- 240 — Persona (Kimo'nun sesi): metin havuzu, kısıtlar, anti-tekrar imleci
--
-- Task 04'ün üç sözleşmesini kilitliyor:
--
--   1) BOŞLUK YOK. Her senaryo × persona hücresinde en az beş cümle var.
--      Bir hücre boşalırsa `send_push` boş döner ve bildirim GÖRÜNMEDEN düşer;
--      bunu ancak "bana hiç bildirim gelmiyor" diyen kullanıcı fark eder.
--      Bu yüzden garanti kodda değil burada: eksilme CI'da kırmızı yanar.
--
--   2) YENİ TABLOLAR KAPALI. `push_kinds` ve `push_cursors`, `push_lines` ile
--      aynı kovada: uygulamaya hiç açılmıyorlar. Bildirim metni enjeksiyonu
--      minörlere giden bir kanalda ciddi bir vektör.
--
--   3) OKUMA TEK KAPIDAN. İstemci metinleri `notification_lines()` definer
--      fonksiyonundan alıyor; `push_lines` okunabilir hâle GELMİYOR ve
--      `send_push` çağrılabilir hâle GELMİYOR.
--
-- İki katmanlı iddia kuralı (bkz. 010'un başlığı): 42501 hem sütun/tablo
-- ayrıcalığından hem RLS'ten gelebildiği için her davranış iddiasının yanında
-- bir katalog iddiası duruyor.

begin;
set search_path to public, extensions, tests;

select plan(30);

select tests.create_supabase_user('alice');

-- ==================================================== KISITLAR (bulgu: md. 4)
-- Eskiden `push_lines`'ın PK'sı, FK'sı ve CHECK'i yoktu: yazım hatası olan bir
-- satır sessizce hiç seçilmiyordu.
select ok(
  exists (
    select 1 from pg_constraint
     where conrelid = 'public.push_lines'::regclass and contype = 'p'
  ),
  'push_lines birincil anahtarlı (kind, mascot, idx)'
);
select ok(
  exists (
    select 1 from pg_constraint
     where conrelid = 'public.push_lines'::regclass
       and contype = 'f'
       and confrelid = 'public.push_kinds'::regclass
  ),
  'push_lines.kind → push_kinds yabancı anahtarı var (yazım hatası göçte patlar)'
);
select ok(
  exists (
    select 1 from pg_constraint
     where conrelid = 'public.push_lines'::regclass
       and contype = 'c'
       and conname = 'push_lines_mascot_check'
  ),
  'push_lines.mascot CHECK kısıtlı (yalnız dört persona)'
);

-- ======================================================== İÇERİK ve BOŞLUKLAR
select is(
  (select count(*)::int from public.push_lines where mascot = 'akademisyen'),
  0,
  'akademisyen personasının satırı kalmadı'
);
select is(
  (select count(*)::int from public.push_kinds),
  10,
  'on senaryonun tamamı başlıklı'
);
select is(
  (select count(*)::int from public.push_kinds where btrim(title) = ''),
  0,
  'her senaryonun başlığı dolu'
);
select is(
  (select count(*)::int from public.push_lines),
  200,
  '10 senaryo × 4 persona × 5 varyant = 200 satır'
);

-- BOŞLUK GARANTİSİ: hiçbir hücrede beşten az cümle yok.
select is(
  (select count(*)::int
     from public.push_kinds k
    cross join (values ('ev_hanimi'), ('arabeskci'), ('sanayi_ustasi'), ('ceo'))
               as m(mascot)
    where (select count(*) from public.push_lines l
            where l.kind = k.kind and l.mascot = m.mascot) < 5),
  0,
  'her senaryo × persona hücresinde en az beş cümle var (bildirim asla düşmez)'
);

-- Yer tutucu tuzağı: `send_push` {n} ve {lig}'i AYNI parametreden dolduruyor,
-- ikisi bir cümlede geçerse biri yanlış değeri alır.
select is(
  (select count(*)::int from public.push_lines
    where line like '%{n}%' and line like '%{lig}%'),
  0,
  'hiçbir cümlede {n} ve {lig} birlikte geçmiyor'
);

-- ================================================ KATALOG: yeni tablolar kapalı
select ok(
  (select relrowsecurity from pg_class where oid = 'public.push_cursors'::regclass),
  'push_cursors üzerinde RLS açık (Değişmez 6)'
);
select is(
  (select count(*)::int from pg_policy where polrelid = 'public.push_cursors'::regclass),
  0,
  'push_cursors politikasız (politika yok = kimse erişemez)'
);
select ok(not has_table_privilege('authenticated', 'public.push_cursors', 'SELECT'),
          'authenticated push_cursors okuyamaz');
select ok(not has_table_privilege('authenticated', 'public.push_cursors', 'UPDATE'),
          'authenticated push_cursors''u güncelleyemez (imleci oynatıp metin seçemez)');
select ok(not has_table_privilege('anon', 'public.push_cursors', 'SELECT'),
          'anon push_cursors okuyamaz');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.push_kinds'::regclass),
  'push_kinds üzerinde RLS açık'
);
select ok(not has_table_privilege('authenticated', 'public.push_kinds', 'SELECT'),
          'authenticated push_kinds okuyamaz');
select ok(not has_table_privilege('authenticated', 'public.push_kinds', 'INSERT'),
          'authenticated push_kinds''a yazamaz (bildirim başlığı enjeksiyonu yok)');

-- ============================================== KATALOG: fonksiyon yetkileri
select ok(has_function_privilege('authenticated',
            'public.notification_lines()', 'EXECUTE'),
          'notification_lines authenticated''a AÇIK (yerel bildirim metinleri)');
select ok(not has_function_privilege('anon',
            'public.notification_lines()', 'EXECUTE'),
          'notification_lines anon''a kapalı');
select ok(not has_function_privilege('authenticated',
            'public.send_push(uuid,text,text,text)', 'EXECUTE'),
          'send_push hâlâ KAPALI (metin okuma açılırken gönderim açılmadı)');

-- ==================================================================== DAVRANIŞ
select tests.authenticate_as('alice');

select throws_ok(
  'select 1 from public.push_cursors limit 1',
  '42501', null,
  'authenticated push_cursors''ı okumaya kalkınca reddediliyor'
);
select throws_ok(
  'select 1 from public.push_kinds limit 1',
  '42501', null,
  'authenticated push_kinds''ı okumaya kalkınca reddediliyor'
);

-- Tablo kapalı ama metin okunabiliyor: tek kapı definer fonksiyon.
select is(
  (select count(*)::int from public.notification_lines()),
  200,
  'notification_lines() 200 satırın tamamını döndürüyor (havuz istemcide tam)'
);
select is(
  (select count(*)::int from public.notification_lines() where title is null),
  0,
  'her satır başlığıyla birlikte geliyor (Dart''taki başlık kopyası kalktı)'
);

-- ============================================ persona doğrulaması (bulgu: md. 4)
select throws_ok(
  $$select public.upsert_my_profile('Alice', 'akademisyen')$$,
  '22023', null,
  'kaldırılmış persona yazılamıyor (eskiden sessizce kabul ediliyordu)'
);
select throws_ok(
  $$select public.upsert_my_profile('Alice', 'korsan')$$,
  '22023', null,
  'uydurma persona yazılamıyor'
);
select lives_ok(
  $$select public.upsert_my_profile('Alice', 'sanayi_ustasi')$$,
  'geçerli persona yazılabiliyor'
);

-- ==================================== uygulama adı: canlı tanımda eski ad YOK
-- Ad "Kimo" olarak kesinleşti (mağazada "Kimo: AI YKS"). Depo tarafında bir
-- `git grep` kapısı var ama o, UYGULANMIŞ GÖÇ dosyalarını muaf tutmak zorunda:
-- `send_push` üç kez `create or replace` edildi ve eski gövdeler geçmişte
-- eski adı yazıyor. Grep onları ayırt edemez — hangi tanımın YÜRÜRLÜKTE
-- olduğunu bilmez.
--
-- Bu iddia tam olarak onu soruyor: katalogdaki CANLI fonksiyon gövdelerinde
-- eski ad geçmiyor. Yani "eski ad kaldı mı" sorusu dosya metnine değil
-- veritabanının kendisine soruluyor. Bildirim başlığı minörlere giden bir
-- kanal; yanlış marka adı orada görünür.
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosrc ilike '%yks coach%'),
  0,
  'canlı fonksiyon gövdelerinin hiçbirinde eski uygulama adı yok'
);

-- AŞIRI KİLİTLEME KARŞI-İDDİASI: yukarıdaki sayım fonksiyonlar SİLİNSE de
-- sıfır dönerdi. Bu satır bildirim yolunun hâlâ ayakta olduğunu söylüyor —
-- ve başlıkların hiçbirinin eski adı taşımadığını.
-- AYRICALIKLI ROL: `push_kinds` sunucu tablosu, hiçbir uygulama rolüne açık
-- değil (bildirim metinlerinin tek istemci kapısı `notification_lines`).
-- Bu iki iddia katalog sorgusu, davranış değil — rol değiştirmenin sakıncası
-- yok ve dosya burada 42501 ile düşüyordu.
select tests.reset_role();
select is(
  (select count(*)::int from public.push_kinds where title ilike '%yks coach%'),
  0,
  'bildirim başlıklarında eski uygulama adı yok'
);
select ok(
  (select count(*) from public.push_kinds where coalesce(title, '') <> '') = 10,
  'on senaryonun da başlığı yerinde (send_push yedeği yalnız boşlukta devreye girer)'
);

select * from finish();
rollback;
