-- 0035 — correct_index istemci yükünden çıkarılıyor (P1'in asıl yarısı)
--
-- NEDEN: `correct`i sunucuya taşımak tek başına TİYATRODUR — public_questions ve
-- received_questions görünümleri doğru şıkkın indeksini istemciye zaten
-- veriyordu. İstemci cevabı bildiği sürece "doğruluğu sunucu belirliyor" demek
-- hiçbir şey ifade etmez; saldırgan yalnızca doğru şıkkı göndermek zorunda kalır.
--
-- Bundan sonra doğru cevap YALNIZCA submit_pool_answer / submit_sent_answer
-- yanıtında dönüyor, yani ancak cevap verildikten SONRA öğreniliyor.
--
-- ⚠️ BU GÖÇ BÖLÜNEMEZ. public_questions, iki fonksiyonun DÖNÜŞ TİPİ:
--     random_public_questions()      returns setof public.public_questions
--     random_questions_by_topic()    returns setof public.public_questions
-- Görünümü drop etmek onları da düşürür. Bu yüzden görünüm ve iki fonksiyon
-- BİRLİKTE drop edilip BİRLİKTE yeniden yaratılıyor, aynı isim ve imzayla.
-- (0014/0015 ve 0016/0024'te aynı tuzağa iki kez düşülmüş — bkz. o göçlerin
-- başlıkları.)
--
-- available_question_counts görünümden okuyor ama dönüş tipi kendi tanımı;
-- `language sql` gövdeleri bağımlılık olarak izlenmiyor, dolayısıyla dokunmaya
-- gerek yok — kullandığı kolonlar (subject, concept) yerinde kalıyor.

-- ------------------------------------------------------------------ havuz
drop function if exists public.random_public_questions(int);
drop function if exists public.random_questions_by_topic(text, text, int);
drop view if exists public.public_questions;

create view public.public_questions
  with (security_invoker = false)
  as select
       m.id,
       m.user_id       as owner_id,
       p.nickname      as owner_nickname,
       m.subject,
       m.concept,
       m.exam,
       m.photo_path,
       m.options,
       -- correct_index BİLEREK YOK. Doğru cevap submit_*_answer yanıtında döner.
       m.solved_correct,
       m.solved_wrong,
       m.created_at,
       m.source,
       m.source_year,
       m.source_session
     from public.mistakes m
     join public.profiles p on p.id = m.user_id
     where m.is_public
       and m.moderation = 'ok'
       and m.photo_path is not null
       and m.options is not null
       -- Cevabı tanımsız soru havuza çıkmaz (kolon gizli olsa da filtre kalıyor).
       and m.correct_index is not null;

grant select on public.public_questions to authenticated;

create function public.random_public_questions(p_limit int default 10)
returns setof public.public_questions
language sql
security definer set search_path = public
as $fn$
  select q.*
  from public.public_questions q
  where q.owner_id <> auth.uid()
    and not exists (
      select 1 from public.question_attempts a
      where a.mistake_id = q.id and a.user_id = auth.uid()
    )
    and not exists (
      select 1 from public.question_reports r
      where r.mistake_id = q.id and r.reporter_id = auth.uid()
    )
  order by random()
  limit greatest(1, least(p_limit, 50));
$fn$;

revoke execute on function public.random_public_questions(int) from public, anon;
grant  execute on function public.random_public_questions(int) to authenticated;

create function public.random_questions_by_topic(
  p_subject text,
  p_concept text default null,
  p_limit   int  default 10
)
returns setof public.public_questions
language sql
security definer set search_path = public
as $fn$
  select q.*
  from public.public_questions q
  where q.owner_id <> auth.uid()
    and q.subject = p_subject
    and (p_concept is null or q.concept = p_concept)
    and not exists (
      select 1 from public.question_attempts a
      where a.mistake_id = q.id and a.user_id = auth.uid()
    )
    and not exists (
      select 1 from public.question_reports r
      where r.mistake_id = q.id and r.reporter_id = auth.uid()
    )
  order by random()
  limit greatest(1, least(p_limit, 50));
$fn$;

revoke execute on function public.random_questions_by_topic(text, text, int)
  from public, anon;
grant  execute on function public.random_questions_by_topic(text, text, int)
  to authenticated;

-- -------------------------------------------------------- gelen sorular
-- Buna bağlı fonksiyon yok; doğrudan yeniden yaratılabilir.
drop view if exists public.received_questions;
create view public.received_questions
  with (security_invoker = false)
  as select
       s.id          as send_id,
       s.sender_id,
       p.nickname    as sender_nickname,
       p.mascot      as sender_mascot,
       s.note,
       s.created_at,
       s.solved_at,
       s.correct,
       m.id          as mistake_id,
       m.subject,
       m.concept,
       m.exam,
       m.photo_path,
       m.options,
       -- Doğru şık YALNIZCA ÇÖZÜLMÜŞ gönderilerde açılıyor. Çözmeden önce
       -- görünmüyor (güvenlik amacı bu), çözdükten sonra görünüyor ki kullanıcı
       -- daha sonra geri dönüp cevabına bakabilsin — o ekran zaten sonucu
       -- gösteriyordu, kolonu tümden kaldırmak orada bir gerileme olurdu.
       case when s.solved_at is not null then m.correct_index end as correct_index
     from public.question_sends s
     join public.mistakes m on m.id = s.mistake_id
     join public.profiles p on p.id = s.sender_id
     where s.receiver_id = auth.uid()
       and m.photo_path is not null
       and m.options is not null
       and m.correct_index is not null;

grant select on public.received_questions to authenticated;

-- NOT: admin_pending_reports ve admin_all_questions correct_index döndürmeye
-- DEVAM EDİYOR. Moderatörün yanlış işaretlenmiş cevabı görüp düzeltebilmesi
-- gerekiyor ve o yüzey zaten is_admin() ile korunuyor.
