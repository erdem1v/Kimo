-- test: supabase/tests/130_age_gate.sql
--
-- MUTASYON: `set_birth_year`in üst sınırını 0043'teki hâline (5 yaş) geri al.
-- BEKLENEN: 130'un "12/8 yaşındaki kullanıcı reddediliyor" iddiaları kırmızı.
--
-- Neden bu mutasyon: 13 sınırı Kullanım Koşulları'nda İLAN EDİLİYOR. İlan
-- edilip zorlanmayan bir sınır beyan-gerçek uyumsuzluğudur (App Store 5.1.1 /
-- Play Data Safety) ve tek bir sayının değişmesiyle sessizce kaybolabilir.
-- Testin o sayıyı gerçekten ölçtüğünü kanıtlayan tek şey bu.
create or replace function public.set_birth_year(p_year int)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_now  int  := extract(year from (now() at time zone 'Europe/Istanbul'))::int;
  v_have int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_year is null or p_year > v_now - 5 or p_year < v_now - 100 then
    raise exception 'Doğum yılı geçersiz' using errcode = '22023';
  end if;

  select p.birth_year into v_have
    from public.profiles p where p.id = v_uid for update;

  if v_have is not null then
    raise exception 'Doğum yılı zaten kayıtlı' using errcode = '22023';
  end if;

  update public.profiles set birth_year = p_year where id = v_uid;
end
$fn$;
-- @UNDO
create or replace function public.set_birth_year(p_year int)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_now  int  := extract(year from (now() at time zone 'Europe/Istanbul'))::int;
  v_have int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_year is null or p_year < v_now - 100 then
    raise exception 'Doğum yılı geçersiz' using errcode = '22023';
  end if;
  if p_year > v_now - 13 then
    raise exception 'Kimo 13 yaş ve üzeri için' using errcode = 'KM013';
  end if;

  select p.birth_year into v_have
    from public.profiles p where p.id = v_uid for update;

  if v_have is not null then
    raise exception 'Doğum yılı zaten kayıtlı' using errcode = '22023';
  end if;

  update public.profiles set birth_year = p_year where id = v_uid;
end
$fn$;
