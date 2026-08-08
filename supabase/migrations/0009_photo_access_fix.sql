-- 0009 — Fotoğraf erişim düzeltmesi (havuz + gönderilen sorular)
-- Supabase → SQL Editor'da çalıştır.
--
-- SORUN: 0007/0008'deki storage politikaları doğrudan public.mistakes'e sorgu
-- atıyordu. Politika ifadesi de çağıran kullanıcının yetkisiyle çalıştığı için
-- mistakes'in "sadece kendi satırların" RLS'i devreye giriyor, alt sorgu boş
-- dönüyor ve fotoğraf reddediliyordu.
--
-- ÇÖZÜM: kontrolü security definer bir fonksiyona taşı. Fonksiyon sadece
-- "bu fotoğrafı görebilir miyim?" sorusuna evet/hayır döner; satır içeriğini
-- dışarı sızdırmaz.

create or replace function public.can_read_mistake_photo(p_name text)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1
    from public.mistakes m
    where m.photo_path = p_name
      and (
        -- kendi fotoğrafın
        m.user_id = auth.uid()
        -- havuza açılmış soru
        or m.is_public
        -- sana gönderilmiş soru
        or exists (
          select 1 from public.question_sends s
          where s.mistake_id = m.id and s.receiver_id = auth.uid()
        )
      )
  );
$$;

grant execute on function public.can_read_mistake_photo(text) to authenticated;

-- Eski (çalışmayan) politikaları kaldır.
drop policy if exists "public question photos readable" on storage.objects;
drop policy if exists "sent question photos readable"   on storage.objects;

-- Tek politika: havuz + gönderilen + kendi fotoğrafların.
drop policy if exists "mistake photos readable" on storage.objects;
create policy "mistake photos readable" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'mistake-photos'
    and public.can_read_mistake_photo(name)
  );
