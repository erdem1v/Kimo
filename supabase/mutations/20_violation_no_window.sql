-- test: supabase/tests/270_sanctions.sql
--
-- MUTASYON: ihlal sayacının 180 günlük penceresini kaldır (ömür boyu biriksin).
-- BEKLENEN: 270'in "180 günden eski ihlaller eşiği doldurmuyor — askı YOK"
-- iddiası kırmızı.
--
-- Neden bu mutasyon: pencere bir ÜRÜN KARARI ve sessizce kaybolabilir —
-- `and v.created_at > now() - interval '180 days'` satırını silmek hiçbir
-- yapıyı bozmaz, yalnızca üç yıla yayılmış üç yanlış pozitifi askıya çevirir.
-- Testin o davranışı gerçekten ölçtüğünü kanıtlayan tek şey bu.
create or replace function public.mistakes_photo_violation()
returns trigger
language plpgsql security definer set search_path = public
as $fn$
declare
  v_n     int;
  v_prior boolean;
begin
  select count(*) into v_n
    from public.photo_violations v
   where v.user_id = new.user_id
     and v.voided_at is null;
  v_n := v_n + 1;

  insert into public.photo_violations (user_id, mistake_id, strike_no)
  values (new.user_id, new.id, v_n);

  if public.is_suspended(new.user_id) then
    return null;
  end if;

  select exists (
    select 1 from public.user_sanctions s
     where s.user_id = new.user_id
       and s.source  = 'auto_photo'
       and s.action  = 'suspend'
       and s.voided_at is null
  ) into v_prior;

  if v_prior then
    insert into public.user_sanctions (user_id, action, until, reason_code, source)
    values (new.user_id, 'ban', null, 'photo_repeat', 'auto_photo');
  elsif v_n >= 3 then
    insert into public.user_sanctions (user_id, action, until, reason_code, source)
    values (new.user_id, 'suspend', now() + interval '7 days',
            'photo_repeat', 'auto_photo');
  end if;

  return null;
end
$fn$;
-- @UNDO
create or replace function public.mistakes_photo_violation()
returns trigger
language plpgsql security definer set search_path = public
as $fn$
declare
  v_n     int;
  v_prior boolean;
begin
  select count(*) into v_n
    from public.photo_violations v
   where v.user_id = new.user_id
     and v.voided_at is null
     and v.created_at > now() - interval '180 days';
  v_n := v_n + 1;

  insert into public.photo_violations (user_id, mistake_id, strike_no)
  values (new.user_id, new.id, v_n);

  if public.is_suspended(new.user_id) then
    return null;
  end if;

  select exists (
    select 1 from public.user_sanctions s
     where s.user_id = new.user_id
       and s.source  = 'auto_photo'
       and s.action  = 'suspend'
       and s.voided_at is null
  ) into v_prior;

  if v_prior then
    insert into public.user_sanctions (user_id, action, until, reason_code, source)
    values (new.user_id, 'ban', null, 'photo_repeat', 'auto_photo');
  elsif v_n >= 3 then
    insert into public.user_sanctions (user_id, action, until, reason_code, source)
    values (new.user_id, 'suspend', now() + interval '7 days',
            'photo_repeat', 'auto_photo');
  end if;

  return null;
end
$fn$;
