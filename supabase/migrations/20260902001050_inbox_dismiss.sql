-- 0050a — Gelen kutusundan silme (Task 02, 3n)
--
-- SIRA: bu göç, fonksiyon yetkisi kapısından (0049 / 20260902001100) ÖNCE
-- çalışıyor ve `dismiss_received_question` o kapının beyaz listesinde. Kapıdan
-- sonra eklenseydi hiçbir zaman süpürülmez, yani "yeni fonksiyon PUBLIC'e açık
-- doğar" kuralı onun için hiç sınanmazdı.
--
-- NEDEN: Onaylanan tasarımda gelen soru kartında üç eylem var — Çöz · Sil ·
-- Bildir. "Bildir" 0044'te kuruldu, "Çöz" zaten vardı, ama **"Sil"in sunucuda
-- hiçbir karşılığı yoktu**. Task'ın kuralı açık: arayüzde gösterilen her
-- mekanik sunucuda gerçekten çalışıyor olmalı. Yalnızca istemcide gizlemek,
-- uygulamayı bir daha açtığında sorunun geri gelmesi demekti.
--
-- NE SİLİNİYOR: hiçbir şey. Satır DURUYOR, yalnızca ALICI için gizleniyor
-- (`dismissed_at`). Gerçekten silmek iki şeyi bozardı:
--   1. Gönderen tarafın "gönderdim" kaydı yok olurdu.
--   2. Şikâyet edilmiş bir gönderim moderasyon kuyruğundan da kaybolurdu —
--      yani rahatsız edici bir gönderimi silmek onu incelenemez kılardı.
--
-- SÜTUN KİLİTLİ DOĞUYOR: `dismissed_at` istemciye kapalı, tek yazma yolu
-- `dismiss_received_question()`. Doğrudan UPDATE açık kalsaydı alıcı
-- `solved_at`/`correct` ile aynı sınıfa giren bir alanı elle yazabilirdi.
-- (`question_sends` üzerinde UPDATE zaten 0036'da tamamen kapatılmıştı;
-- burada onu GEVŞETMİYORUZ — RPC `security definer` olarak yazıyor.)
--
-- GERİ ALMA: `alter table public.question_sends drop column dismissed_at;`
-- ve fonksiyonu düşürün. Gizlenen satırlar yeniden görünür olur.

alter table public.question_sends
  add column if not exists dismissed_at timestamptz;

comment on column public.question_sends.dismissed_at is
  'Alıcı bu gönderimi gelen kutusundan kaldırdı. Satır silinmiyor: gönderenin '
  'kaydı ve moderasyon izi duruyor. Yalnızca dismiss_received_question() yazar.';

-- İstemci bu sütunu yazamaz.
revoke update (dismissed_at) on public.question_sends from authenticated;
revoke insert (dismissed_at) on public.question_sends from authenticated;

-- Alıcının kendi kutusunu tararken kullandığı indeks; gizlenenler dışarıda.
create index if not exists question_sends_inbox_idx
  on public.question_sends (receiver_id, created_at desc)
  where dismissed_at is null;

-- ------------------------------------------------------------------ gizleme
-- `user_id` PARAMETRESİ YOK (Task 01 değişmezi): alıcı `auth.uid()`'den.
create or replace function public.dismiss_received_question(p_send uuid)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  update public.question_sends
     set dismissed_at = now()
   where id = p_send
     and receiver_id = v_uid
     and dismissed_at is null;

  -- Bulunamadıysa sessiz geçiyoruz: satır zaten gizlenmiş ya da bize ait
  -- değil. İkisini ayırt eden bir hata mesajı, başkasının gönderim
  -- kimliklerini yoklamaya yarardı.
end
$fn$;

revoke execute on function public.dismiss_received_question(uuid)
  from public, anon;
grant  execute on function public.dismiss_received_question(uuid)
  to authenticated;

-- ------------------------------------------------------------------ görünüm
-- 0044'teki görünümün AYNISI, tek fark son koşul. Bütün çözülebilirlik ve
-- moderasyon filtreleri olduğu gibi korunuyor.
create or replace view public.received_questions
with (security_invoker = false) as
select
  s.id                as send_id,
  s.sender_id,
  sp.nickname         as sender_nickname,
  sp.mascot           as sender_mascot,
  s.note,
  s.created_at,
  s.solved_at,
  s.correct,
  m.id                as mistake_id,
  m.subject,
  m.concept,
  m.exam,
  m.photo_path,
  m.options,
  case when s.solved_at is not null then m.correct_index end as correct_index
from public.question_sends s
join public.mistakes m on m.id = s.mistake_id
join public.profiles sp on sp.id = s.sender_id
where s.receiver_id = auth.uid()
  and m.photo_path is not null
  and m.options is not null
  and m.correct_index is not null
  and m.moderation <> 'removed'
  and not exists (
    select 1 from public.question_reports r
     where r.mistake_id = m.id
       and r.reporter_id = auth.uid()
       and r.status = 'pending'
  )
  and not exists (
    select 1 from public.user_blocks b
     where b.blocker_id = auth.uid()
       and b.blocked_id = s.sender_id
  )
  -- YENİ: alıcının kutusundan kaldırdıkları.
  and s.dismissed_at is null;

revoke all on public.received_questions from public, anon;
grant select on public.received_questions to authenticated;

-- ------------------------------------------------------- katalog doğrulaması
-- Sütun gerçekten kilitli mi (0047'nin deseni, tek sütun için).
do $chk$
declare
  v_bad text;
begin
  select string_agg(priv, ', ')
    into v_bad
    from unnest(array['INSERT', 'UPDATE']) priv
   where has_column_privilege('authenticated', 'public.question_sends',
                              'dismissed_at', priv);

  if v_bad is not null then
    raise exception
      'question_sends.dismissed_at hâlâ yazılabilir (%): kilit uygulanmadı',
      v_bad;
  end if;

  -- Yeni fonksiyon PUBLIC'e açık DOĞUYOR (PostgreSQL varsayılanı). 0049'un
  -- kapısı birazdan bunu zaten süpürecek; buradaki kontrol o kapıya bağımlı
  -- kalmamak için — göç sırası değişirse hata burada, göç anında çıkar.
  if has_function_privilege(
       'public', 'public.dismiss_received_question(uuid)', 'EXECUTE')
     or has_function_privilege(
       'anon', 'public.dismiss_received_question(uuid)', 'EXECUTE')
  then
    raise exception
      'dismiss_received_question hâlâ public/anon''a açık';
  end if;
end
$chk$;
