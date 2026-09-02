-- 0022 — Aynı soru aynı arkadaşa tekrar gönderilebilsin
-- Supabase → SQL Editor'da çalıştır.
--
-- 0008'deki unique (sender_id, receiver_id, mistake_id) kısıtı, "bu soruyu ona
-- zaten göndermiştin" hatasına yol açıyordu. Tekrar göndermek meşru bir istek
-- (unuttu, not ekleyerek yeniden atmak istiyor); kısıtı kaldırıyoruz.
--
-- Kısıt adı tablo tanımından otomatik üretildiği için adıyla değil, tanımıyla
-- bulunup düşürülür (elle yeniden adlandırılmış olabilir).

do $$
declare
  v_name text;
begin
  select con.conname into v_name
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace nsp on nsp.oid = rel.relnamespace
  where nsp.nspname = 'public'
    and rel.relname = 'question_sends'
    and con.contype = 'u'
    -- attname 'name' tipindedir; text[] ile karşılaştırmak için cast şart.
    and (
      select array_agg(att.attname::text order by att.attname::text)
      from unnest(con.conkey) as k(attnum)
      join pg_attribute att
        on att.attrelid = con.conrelid and att.attnum = k.attnum
    ) = array['mistake_id', 'receiver_id', 'sender_id']::text[]
  limit 1;

  if v_name is not null then
    execute format(
      'alter table public.question_sends drop constraint %I', v_name);
  end if;
end $$;

-- Gönderen tarafın kendi gönderimlerini listelemesi (ve tekrar kontrolü) için
-- yararlı; unique index düştüğü için sorgu planı bunu kullanacak.
create index if not exists question_sends_sender_idx
  on public.question_sends (sender_id, mistake_id);
