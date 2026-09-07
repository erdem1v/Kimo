-- 030 — H4: fotoğraf yetkisi dosyanın sahipliğinden türer
--
-- BU DOSYADAKİ EN DEĞERLİ TEST "sahtecilik" bölümü. Eski
-- can_read_mistake_photo şunu soruyordu: "bu yolu talep eden bir satır var mı?"
-- Saldırgan kendi satırına kurbanın yolunu yazınca cevap "evet" oluyordu.
--
-- Mutasyon kontrolü için: bu dosyayı 0030 göçünü geri alarak çalıştırırsanız
-- "sahtecilik" iddiaları KIRMIZI olmalı. Yeşil kalıyorlarsa test ayrımı
-- yapmıyor demektir.

begin;
set search_path to public, extensions, tests;

select plan(14);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('mallory');

-- ============================================================ (1) CHECK kısıtı
select tests.authenticate_as('mallory');

-- Gölge satır artık VERİ KATMANINDA imkânsız: 23514 (check_violation).
select throws_ok(
  format('insert into public.mistakes
            (subject, concept, mistake_type, photo_path)
          values (''X'', ''Y'', ''dikkatsizlik'', %L)',
         tests.get_supabase_uid('alice')::text || '/gizli.jpg'),
  '23514', null,
  'H4: başkasının klasörünü gösteren satır EKLENEMEZ'
);

select lives_ok(
  format('insert into public.mistakes
            (subject, concept, mistake_type, photo_path)
          values (''X'', ''Y'', ''dikkatsizlik'', %L)',
         tests.get_supabase_uid('mallory')::text || '/kendi.jpg'),
  'kendi klasörünü gösteren satır eklenebiliyor'
);

select lives_ok(
  'insert into public.mistakes (subject, concept, mistake_type, photo_path)
   values (''X'', ''Y'', ''dikkatsizlik'', null)',
  'photo_path null olabilir (fotoğrafsız hata kaydı)'
);

-- ==================================================== (2) fikstür: alice''in soruları
select tests.reset_role();

insert into public.mistakes
  (user_id, subject, concept, mistake_type, photo_path, options, correct_index, is_public)
values
  (tests.get_supabase_uid('alice'), 'Fizik', 'Kuvvet', 'islem_hatasi',
   tests.get_supabase_uid('alice')::text || '/acik.jpg',
   '[{"label":"A","text":"1"}]'::jsonb, 0, true),
  (tests.get_supabase_uid('alice'), 'Fizik', 'Enerji', 'islem_hatasi',
   tests.get_supabase_uid('alice')::text || '/ozel.jpg',
   null, null, false);

-- Fotoğraf taraması (0050): havuz görünürlüğü 'clear' ister; fikstürde
-- ayrıcalıklı oturum yazıyor (canlıda scan-photos süpürücüsü).
update public.mistakes set photo_scan = 'clear'
 where user_id = tests.get_supabase_uid('alice');

insert into storage.objects (bucket_id, name) values
  ('mistake-photos', tests.get_supabase_uid('alice')::text || '/acik.jpg'),
  ('mistake-photos', tests.get_supabase_uid('alice')::text || '/ozel.jpg');

-- ===================================================== (3) fonksiyon davranışı
select tests.authenticate_as('alice');
select is(public.can_read_mistake_photo(
            tests.get_supabase_uid('alice')::text || '/ozel.jpg'),
          true, 'sahibi kendi özel fotoğrafını okuyabiliyor');

select tests.authenticate_as('mallory');
select is(public.can_read_mistake_photo(
            tests.get_supabase_uid('alice')::text || '/acik.jpg'),
          true, 'havuza açılmış sorunun fotoğrafı okunabiliyor');
select is(public.can_read_mistake_photo(
            tests.get_supabase_uid('alice')::text || '/ozel.jpg'),
          false, 'yabancı, paylaşılmamış fotoğrafı okuyamıyor');
select is(public.can_read_mistake_photo(
            tests.get_supabase_uid('alice')::text || '/hicyok.jpg'),
          false, 'karşılığı olmayan yol okunamıyor');

-- ============================================ (4) ★ SAHTECİLİK — iki katman ayrı
-- CHECK kısıtını bu işlem içinde geçici olarak düşürüp gölge satırı zorla
-- kuruyoruz. Amaç: yetki fonksiyonunun kısıttan BAĞIMSIZ olarak da doğru
-- olduğunu göstermek. Biri atlanırsa diğeri tutmalı.
select tests.reset_role();
alter table public.mistakes drop constraint if exists mistakes_photo_path_owned;

insert into public.mistakes
  (user_id, subject, concept, mistake_type, photo_path, options, correct_index, is_public)
values
  (tests.get_supabase_uid('mallory'), 'Sahte', 'Sahte', 'dikkatsizlik',
   tests.get_supabase_uid('alice')::text || '/ozel.jpg',
   '[{"label":"A","text":"1"}]'::jsonb, 0, true);

select tests.authenticate_as('mallory');
select is(public.can_read_mistake_photo(
            tests.get_supabase_uid('alice')::text || '/ozel.jpg'),
          false,
          'SAHTECİLİK: gölge satır kurulsa BİLE saldırgan okuyamıyor');

-- Ve daha kötüsü de kapalı: gölge satır is_public=true olduğu için eski kodda
-- kurbanın özel fotoğrafı HERKESE açılıyordu.
select tests.create_supabase_user('carol');
select tests.authenticate_as('carol');
select is(public.can_read_mistake_photo(
            tests.get_supabase_uid('alice')::text || '/ozel.jpg'),
          false,
          'SAHTECİLİK: gölge satır fotoğrafı üçüncü kişilere de AÇMIYOR');

-- Sahibi kendi dosyasını okumaya devam edebilmeli (gölge satır bunu bozmasın).
select tests.authenticate_as('alice');
select is(public.can_read_mistake_photo(
            tests.get_supabase_uid('alice')::text || '/ozel.jpg'),
          true, 'gölge satır sahibinin erişimini bozmuyor');

-- ============================================ (5) depolama politikası uçtan uca
-- Reddedilen SELECT hata FIRLATMAZ, sıfır satır döner — bu yüzden is_empty.
select tests.authenticate_as('mallory');
select is_empty(
  format('select 1 from storage.objects
           where bucket_id = ''mistake-photos'' and name = %L',
         tests.get_supabase_uid('alice')::text || '/ozel.jpg'),
  'RLS: yabancı, özel fotoğrafı depolama katmanında da göremiyor'
);
select isnt_empty(
  format('select 1 from storage.objects
           where bucket_id = ''mistake-photos'' and name = %L',
         tests.get_supabase_uid('alice')::text || '/acik.jpg'),
  'RLS: havuz fotoğrafı depolama katmanında görünüyor'
);

-- ============================================ (6) avatar yolu da sahipliğe bağlı
select tests.authenticate_as('mallory');
select throws_ok(
  format('update public.profiles set avatar_path = %L where id = %L',
         tests.get_supabase_uid('alice')::text || '/avatar.jpg',
         tests.get_supabase_uid('mallory')),
  '23514', null,
  'avatar_path başkasının klasörünü gösteremez'
);
select lives_ok(
  format('update public.profiles set avatar_path = %L where id = %L',
         tests.get_supabase_uid('mallory')::text || '/avatar.jpg',
         tests.get_supabase_uid('mallory')),
  'kendi klasöründeki avatar yolu yazılabiliyor'
);

select * from finish();
rollback;
