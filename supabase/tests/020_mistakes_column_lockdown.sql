-- 020 — mistakes: sütun düzeyi yazma yetkileri (C2'nin çekirdeği)
--
-- Denetim bulgusu C2: içerik sahibi `moderation` ve `report_count` yazabiliyordu,
-- yani moderatörün kaldırdığı soruyu `moderation='ok'` yazarak havuza geri
-- sokabiliyor ve şikayet sayacını sıfırlayabiliyordu.
--
-- INSERT ve UPDATE AYRI AYRI test edilir: `revoke update (photo_path)` INSERT'e
-- hiçbir şey yapmaz ve istemci (mistake_repository.dart) photo_path'i INSERT
-- ediyor. Tek yönü test etmek kilidin yarısını test etmek olur.

begin;
set search_path to public, extensions, tests;

select plan(29);

select tests.create_supabase_user('alice');

-- ============================================ KATALOG: kilitli (her iki komut)
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'moderation', 'UPDATE'),
          'moderation güncellenemez (kaldırılan içerik geri açılamaz)');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'moderation', 'INSERT'),
          'moderation insert edilemez');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'report_count', 'UPDATE'),
          'report_count güncellenemez (şikayet eşiği sıfırlanamaz)');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'solved_correct', 'UPDATE'),
          'solved_correct güncellenemez (havuz istatistiği şişirilemez)');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'solved_wrong', 'UPDATE'),
          'solved_wrong güncellenemez');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'source', 'INSERT'),
          'source insert edilemez (kendi sorusunu ÖSYM gibi gösteremez)');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'source', 'UPDATE'),
          'source güncellenemez');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'source_year', 'INSERT'),
          'source_year insert edilemez');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'user_id', 'INSERT'),
          'user_id insert edilemez (default auth.uid() dolduruyor)');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'user_id', 'UPDATE'),
          'user_id güncellenemez');

-- photo_path: INSERT açık (yükleme akışı), UPDATE kapalı → yaz-bir-kez
select ok(has_column_privilege('authenticated', 'public.mistakes', 'photo_path', 'INSERT'),
          'photo_path INSERT edilebilir (fotoğraf yükleme akışı çalışmalı)');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'photo_path', 'UPDATE'),
          'photo_path GÜNCELLENEMEZ (yaz-bir-kez)');

-- ============================================ KATALOG: yazılabilir KALMALI
select ok(has_column_privilege('authenticated', 'public.mistakes', 'subject', 'INSERT'),
          'subject insert edilebilir');
select ok(has_column_privilege('authenticated', 'public.mistakes', 'is_public', 'INSERT'),
          'is_public insert edilebilir (paylaşım opt-in''i ekleme ekranında)');
-- Task 03 (0049/0050/0053) kolonları:
select ok(has_column_privilege('authenticated', 'public.mistakes', 'next_review_at', 'UPDATE'),
          'next_review_at güncellenebilir (takvimi istemci yazar)');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'photo_scan', 'UPDATE'),
          'photo_scan güncellenemez — sahibi kendi fotoğrafını "temiz" işaretleyip paylaşımı açamaz');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'photo_scan', 'INSERT'),
          'photo_scan INSERT ile de yazılamaz (tetikleyici pending''e çevirir ama beyan da kapalı)');
select ok(not has_column_privilege('authenticated', 'public.mistakes', 'photo_scan_at', 'UPDATE'),
          'photo_scan_at de kapalı');
select ok(has_column_privilege('authenticated', 'public.mistakes', 'step', 'UPDATE'),
          'step güncellenebilir (tekrar zamanlaması istemcide)');
select ok(has_column_privilege('authenticated', 'public.mistakes', 'note', 'UPDATE'),
          'note güncellenebilir');

-- ============================================ KATALOG: anon
select ok(not has_column_privilege('anon', 'public.mistakes', 'subject', 'INSERT'),
          'anon hata ekleyemez');
select ok(not has_column_privilege('anon', 'public.mistakes', 'moderation', 'UPDATE'),
          'anon moderation yazamaz');

-- ============================================ DAVRANIŞ
select tests.authenticate_as('alice');

-- Meşru akış: istemcinin bugün attığı insert (user_id YOK, default dolduruyor)
select lives_ok(
  format('insert into public.mistakes
            (subject, concept, mistake_type, note, photo_path, is_public)
          values (''Matematik'', ''Türev'', ''dikkatsizlik'', ''not'', %L, false)',
         tests.get_supabase_uid('alice')::text || '/1.jpg'),
  'kendi hatasını fotoğrafıyla ekleyebiliyor (mistake_repository.dart:143 yolu)'
);

select throws_ok(
  'update public.mistakes set moderation = ''ok''',
  '42501',
  'C2: sahibi kaldırılmış içeriği geri açamaz'
);
select throws_ok(
  'update public.mistakes set report_count = 0',
  '42501',
  'C2: sahibi şikayet sayacını sıfırlayamaz'
);
select throws_ok(
  'update public.mistakes set solved_correct = 9999',
  '42501',
  'sahibi havuz istatistiğini şişiremez'
);
select throws_ok(
  'update public.mistakes set source = ''osym'', source_year = 2025',
  '42501',
  'sahibi sorusuna ÖSYM künyesi takamaz'
);
select throws_ok(
  'update public.mistakes set photo_path = ''baskasi/gizli.jpg''',
  '42501',
  'photo_path sonradan başkasının yoluna çevrilemez'
);

select lives_ok(
  'update public.mistakes set note = ''düzeltilmiş not''',
  'kendi notunu güncelleyebiliyor'
);

select * from finish();
rollback;
