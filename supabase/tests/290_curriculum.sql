-- 290 — Konu ağacı: tek kaynak, sürüm pazarlığı, yazma doğrulaması
--
-- Task 09'a kadar ağaç YEDİ yerde duruyordu ve hiçbiri diğerini
-- doğrulamıyordu. Daha kötüsü: `mistakes.subject/concept` serbest `text`ti —
-- ne FK ne CHECK. Edge function AI'ın önerisini yalnızca `konu_valid` diye
-- İŞARETLİYORDU, reddetmiyordu. PostgREST'e doğrudan istek atan biri istediği
-- konuyu yazabiliyordu; "serbest metin girilmez" yalnızca bir istemci kuralıydı.
--
-- Bu dosya dört şeyi kilitliyor:
--   1) Ağaç tabloları uygulamaya KAPALI; okuma tek kapıdan.
--   2) Sürüm pazarlığı çalışıyor — değişmemişse ağaç gönderilmiyor.
--   3) Etiket/eski ad kanonik konuya çözülüyor.
--   4) Yazma yolunda ağaç dışı konu REDDEDİLİYOR — ve aşırı kilitlenmiyor.
--
-- `tests.skip_topic_check()` BURADA ÇAĞRILMIYOR: doğrulamanın kendisi test.

begin;
set search_path to public, extensions, tests;

select plan(25);

select tests.create_supabase_user('ogrenci');
select tests.age_all_users();

-- ============================================== KATALOG: tablolar kapalı
-- `push_kinds` deseni: RLS açık, politika yok, revoke all. Ağaç herkes için
-- aynı ve statik; satır düzeyi bir kural yok, dolayısıyla açık bir tablo
-- yalnızca sürüm pazarlığını ve gruplamayı istemciye bırakırdı.
select ok(not has_table_privilege('authenticated', 'public.curriculum_topics', 'SELECT'),
          'curriculum_topics authenticated''a kapalı');
select ok(not has_table_privilege('authenticated', 'public.curriculum_aliases', 'SELECT'),
          'curriculum_aliases authenticated''a kapalı');
select ok(not has_table_privilege('authenticated', 'public.curriculum_meta', 'SELECT'),
          'curriculum_meta authenticated''a kapalı');
select ok(not has_table_privilege('anon', 'public.curriculum_topics', 'SELECT'),
          'anon da okuyamıyor');

-- ============================================== TOHUM gerçekten yüklendi mi
-- Boş bir ağaç, konu seçilemeyen bir uygulama demek. Göç zamanında da bir kapı
-- var (0074) ama süit bunu ayrıca iddia ediyor: tohum bir ÜRETİLEN dosya ve
-- yeniden üretilirken bozulabilir.
select ok((select count(*) from public.curriculum_topics) > 400,
          'ağaç tohumlandı (400''den fazla konu)');
select isnt((select version from public.curriculum_meta), null,
            'sürüm yazıldı');
select ok(
  not exists (
    select 1
      from unnest(array['eski', 'maarif']) c
      cross join unnest(array['TYT', 'AYT']) e
     where not exists (
       select 1 from public.curriculum_topics t
        where t.curriculum = c and t.exam = e)
  ),
  'her (müfredat, sınav) hücresinde ders var — hiçbir kullanıcı grubu boşta değil'
);

-- ================================================= OKUMA: sürüm pazarlığı
select tests.authenticate_as('ogrenci');

-- SÜRÜM AYRICALIKLI FİKSTÜRDE ALINIYOR: `curriculum_meta` 0072'de bütün
-- uygulama rollerinden geri alındı (istemci sürümü `curriculum_tree`in
-- YANITINDAN öğreniyor, tabloyu hiç okumuyor). Alt sorgu `authenticated`
-- olarak koştuğu için dosya burada 42501 ile düşüyordu — iddia edilen şeyle
-- ilgisi olmayan bir sebeple.
create temp table _curver on commit drop as
  select version from public.curriculum_meta;
grant select on _curver to authenticated;

select is(
  (public.curriculum_tree('eski', (select version from _curver))
     ->> 'fresh')::boolean,
  true,
  'sürüm eşleşince fresh:true'
);
select ok(
  (public.curriculum_tree('eski', (select version from _curver))
     -> 'exams') is null,
  'taze yanıtta AĞAÇ GÖNDERİLMİYOR (434 konu her açılışta inmesin)'
);
select is(
  (public.curriculum_tree('eski', 'bayat-surum') ->> 'fresh')::boolean,
  false,
  'sürüm tutmayınca tam ağaç dönüyor'
);
select ok(
  jsonb_array_length(
    public.curriculum_tree('eski', null) -> 'exams' -> 'TYT') >= 10,
  'tam ağaçta TYT dersleri var'
);
select ok(
  (public.curriculum_tree('maarif', null) ->> 'curriculum') = 'maarif',
  'maarif ağacı ayrı dönüyor'
);

-- =========================================================== ETİKET ÇÖZÜMÜ
-- `tools/remap_konu.sql` bu tabloda eridi: 265 MEB etiketi artık ağacın
-- kendisinde ve tek seferlik elle çalıştırılan bir betiğe ihtiyaç yok.
select is(
  public.resolve_topic_alias('eski', 'AYT', 'Biyoloji', 'Destek ve Hareket Sistemi'),
  'İskelet Sistemi',
  'eski MEB adı kanonik konuya çözülüyor'
);
select is(
  public.resolve_topic_alias('eski', 'AYT', 'Fizik', 'ATIŞLAR'),
  'Kuvvet ve Hareket',
  'arama etiketi büyük/küçük harften bağımsız çözülüyor'
);
select is(
  public.resolve_topic_alias('eski', 'AYT', 'Fizik', 'Kuvvet ve Hareket'),
  'Kuvvet ve Hareket',
  'kanonik ad kendisine çözülüyor'
);
select is(
  public.resolve_topic_alias('eski', 'AYT', 'Fizik', 'uydurma konu'),
  null,
  'tanınmayan ad null döner (sessizce bir şeye eşlenmez)'
);

-- ============================================================= DOĞRULAMA
select is(public.is_valid_topic('eski', 'AYT', 'Fizik', 'Kuvvet ve Hareket'), true,
          'ağaçtaki konu geçerli');
select is(public.is_valid_topic('eski', 'AYT', 'Fizik', 'Atışlar'), false,
          'ETİKET bir konu DEĞİL — kaydedilen ad kanonik olmalı');

-- ============================================ YAZMA: ağaç dışı konu reddediliyor
select throws_ok(
  $$insert into public.mistakes (subject, concept, exam)
    values ('Fizik', 'Uydurma Konu', 'AYT')$$,
  'KM022', null,
  'ağaç dışı konu REDDEDİLİYOR (serbest metin yüzeyi kapandı)'
);
select throws_ok(
  $$insert into public.mistakes (subject, concept, exam, extra_concepts)
    values ('Fizik', 'Kuvvet ve Hareket', 'AYT', array['Uydurma Ek Konu'])$$,
  'KM022', null,
  'ek konular da doğrulanıyor'
);

-- ======================================== AŞIRI KİLİTLEME KARŞI-İDDİALARI
-- Bu yön en az diğeri kadar önemli: fazla kilitlemek uygulamayı sessizce kırar.
select lives_ok(
  $$insert into public.mistakes (subject, concept, exam)
    values ('Fizik', 'Kuvvet ve Hareket', 'AYT')$$,
  'geçerli konu HÂLÂ eklenebiliyor'
);
select is(
  (select curriculum from public.mistakes
    where user_id = tests.get_supabase_uid('ogrenci') limit 1),
  'eski',
  'satır kendi müfredatını taşıyor (moderatörünkine bakılmıyor)'
);
select ok(
  not has_column_privilege('authenticated', 'public.mistakes', 'curriculum', 'UPDATE'),
  'curriculum istemciye KAPALI — doğrulama başka ağaca yönlendirilemez'
);

-- Konusuna DOKUNULMAYAN satır güncellenebilmeli. Bu koşul olmasaydı, henüz
-- temizlenmemiş eski bir satıra dokunan her admin düzeltmesi — yani onları
-- düzeltmek için var olan araç — reddedilirdi.
-- Fikstür ağaç dışı bir satır kurmak zorunda — tam olarak temsil etmesi
-- gereken durum bu. Tetikleyici SADECE bu ekleme için kapatılıp hemen geri
-- açılıyor; kapalı bırakmak testin geri kalanını anlamsız kılardı.
select tests.reset_role();
alter table public.mistakes disable trigger mistakes_topic_check;
insert into public.mistakes (user_id, subject, concept, exam)
values (tests.get_supabase_uid('ogrenci'), 'Fizik', 'Ağaçtan Düşmüş Konu', 'AYT');
alter table public.mistakes enable trigger mistakes_topic_check;

select tests.authenticate_as('ogrenci');
select lives_ok(
  $$update public.mistakes set note = 'düzeltildi'
     where concept = 'Ağaçtan Düşmüş Konu'$$,
  'konusuna dokunulmayan eski satır güncellenebiliyor'
);
select throws_ok(
  $$update public.mistakes set concept = 'Hâlâ Yok'
     where concept = 'Ağaçtan Düşmüş Konu'$$,
  'KM022', null,
  'ama konuyu DEĞİŞTİRMEK geçerli bir konuya inmek zorunda'
);

select * from finish();
rollback;
