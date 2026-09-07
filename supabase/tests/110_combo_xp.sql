-- 110 — Seri çarpanı (kombo) ve XP ekonomisi (0041)
--
-- Task kuralı: "arayüzde gösterilen her mekanik sunucuda gerçekten
-- uygulanmalı". Tasarım pratik ekranında ×3, oturum sonunda ×5 gösteriyor.
-- Bu dosya çarpanın GERÇEKTEN uygulandığını ve sayacın istemciden
-- yazılamadığını ayrı ayrı doğruluyor.

begin;
set search_path to public, extensions, tests;

select plan(13);

select tests.create_supabase_user('alice');

-- ============================================================== KATALOG
select has_column('public'::name, 'profiles'::name, 'combo'::name,
                  'combo sütunu var');
select has_column('public'::name, 'profiles'::name, 'combo_at'::name,
                  'combo_at sütunu var');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'combo', 'UPDATE'),
          'combo istemciden yazılamaz — çarpan satın alınamaz');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'combo_at', 'UPDATE'),
          'combo_at istemciden yazılamaz — oturum penceresi uzatılamaz');

-- ============================================================== FİKSTÜR
-- Şıklı bir soru: doğruluğu SUNUCU hesaplayabilsin.
select tests.reset_role();
insert into public.mistakes
  (user_id, subject, concept, mistake_type, photo_path, options, correct_index)
values (
  tests.get_supabase_uid('alice'), 'Matematik', 'Köklü Sayılar', 'islem_hatasi',
  tests.get_supabase_uid('alice')::text || '/soru.jpg',
  '[{"label":"A","text":"1"},{"label":"B","text":"2"}]'::jsonb,
  1
);

create temporary table fx as
  select m.id as mistake_id, tests.get_supabase_uid('alice') as uid
    from public.mistakes m
   where m.user_id = tests.get_supabase_uid('alice')
   limit 1;
-- Temp tablo postgres'in; sonraki okumalar `authenticated` rolüyle
-- (aynı oturum, SET ROLE) — tablo düzeyi SELECT izni açıkça verilmeli.
grant select on fx to authenticated;

-- ============================================================== DAVRANIŞ
select tests.authenticate_as('alice');

-- İlk doğru: kombo 1, çarpan 1, XP 10. Taban davranış DEĞİŞMEDİ.
select is(
  (select r.xp_awarded
     from fx cross join lateral
          public.submit_review(fx.mistake_id, true, 1, null) r),
  10,
  'ilk doğru cevap 10 XP (çarpan 1)'
);
select is(
  (select p.combo from public.profiles p where p.id = (select uid from fx)),
  1,
  'kombo 1 oldu'
);

-- İkinci doğru: kombo 2, çarpan 2, XP 20.
select is(
  (select r.xp_awarded
     from fx cross join lateral
          public.submit_review(fx.mistake_id, true, 1, null) r),
  20,
  'ikinci ardışık doğru 20 XP (çarpan 2) — çarpan GERÇEKTEN uygulanıyor'
);

select is(
  (select r.multiplier
     from fx cross join lateral
          public.submit_review(fx.mistake_id, true, 1, null) r),
  3,
  'üçüncü ardışık doğruda çarpan 3 — arayüzde gösterilen sayı bu'
);

-- Yanlış: kombo sıfırlanır ve XP verilmez.
select is(
  (select r.xp_awarded
     from fx cross join lateral
          public.submit_review(fx.mistake_id, false, 0, null) r),
  0,
  'yanlış cevap XP vermiyor'
);
select is(
  (select p.combo from public.profiles p where p.id = (select uid from fx)),
  0,
  'yanlış cevap komboyu SIFIRLIYOR'
);

-- Çarpan tavanı: art arda yedi doğru sonrası çarpan 5'te durmalı.
select is(
  (select max(r.multiplier)::int
     from fx
     cross join generate_series(1, 7) g
     -- LATERAL, g'ye REFERANS VERMELİ (g - g + 1 = 1): vermezse planlayıcı
     -- volatil çağrıyı satır başına yinelemek zorunda değildir ve yeni PG
     -- sürümünde tek kez çalıştırıp aynı sonucu 7 satıra kopyalıyordu —
     -- kombo hiç büyümüyor, test 1 görüyordu (ilk CI koşusunun bulgusu).
     cross join lateral
       public.submit_review(fx.mistake_id, true, g - g + 1, null) r),
  5,
  'çarpan 5''te duruyor (tasarımda gösterilen en yüksek değer)'
);

-- ------------------------------------------------- sunucu doğruluğu belirler
-- `p_choice` verildiğinde `p_correct` YOK SAYILIR. Çarpan kullanıcı beyanının
-- değerini beşe katladığı için, doğrulanabilir yerde doğrulamak şart.
select is(
  (select r.correct
     from fx cross join lateral
          public.submit_review(fx.mistake_id, true, 0, null) r),
  false,
  'yanlış şık seçilince "doğru yaptım" beyanı yok sayılıyor'
);

-- Şıkkı olmayan soruda beyan hâlâ kabul ediliyor (bilinçli ve belgeli sınır).
select tests.reset_role();
insert into public.mistakes (user_id, subject, concept, mistake_type)
values (tests.get_supabase_uid('alice'), 'Fizik', 'Kuvvet', 'dikkatsizlik');
select tests.authenticate_as('alice');

select is(
  (select r.correct
     from (select m.id from public.mistakes m
            where m.user_id = tests.get_supabase_uid('alice')
              and m.correct_index is null limit 1) q
     cross join lateral public.submit_review(q.id, true, null, null) r),
  true,
  'şıkkı olmayan soruda kendi kendine notlama korunuyor'
);

select * from finish();
rollback;
