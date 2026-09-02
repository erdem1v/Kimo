-- 0015 — Yönetim ekranında "Kaydedilemedi" hatasının düzeltmesi
-- Supabase → SQL Editor'da çalıştır.
--
-- SORUN: 0014, admin_update_question'a p_extra_concepts parametresi ekledi.
-- Postgres'te farklı imza = AYRI fonksiyon demek, yani "create or replace"
-- eskisini değiştirmedi; 5 ve 6 parametreli iki sürüm birden var oldu.
-- Çağrı hangisine gideceği belirsiz kalınca ("function is not unique") kayıt
-- başarısız oluyordu.
--
-- ÇÖZÜM: eski sürümü kaldır, tek imza bırak.

drop function if exists public.admin_update_question(uuid, text, text, text, int);

-- Tek geçerli sürüm (0014 ile aynı; güvenlik için yeniden tanımlanıyor).
create or replace function public.admin_update_question(
  p_id             uuid,
  p_subject        text default null,
  p_concept        text default null,
  p_exam           text default null,
  p_correct_index  int  default null,
  p_extra_concepts text[] default null
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_old_concept text;
begin
  if not public.is_admin() then
    raise exception 'yetkisiz';
  end if;

  select concept into v_old_concept from public.mistakes where id = p_id;

  update public.mistakes
     set subject        = coalesce(p_subject, subject),
         concept        = coalesce(p_concept, concept),
         exam           = coalesce(p_exam, exam),
         correct_index  = coalesce(p_correct_index, correct_index),
         extra_concepts = coalesce(p_extra_concepts, extra_concepts)
   where id = p_id;

  -- Bağlı ölçümlerde ders/sınav her zaman güncellenir.
  update public.study_attempts
     set subject = coalesce(p_subject, subject),
         exam    = coalesce(p_exam, exam)
   where mistake_id = p_id;

  -- Konu düzeltildiyse yalnızca ESKİ ana konuya yazılmış ölçümler taşınır;
  -- ek konu satırları kendi konularında kalır.
  if p_concept is not null and p_concept <> v_old_concept then
    update public.study_attempts
       set concept = p_concept
     where mistake_id = p_id
       and concept = v_old_concept;
  end if;
end;
$$;

grant execute on function
  public.admin_update_question(uuid, text, text, text, int, text[])
  to authenticated;
