-- test: supabase/tests/310_feature_flags.sql
--
-- MUTASYON: tanınmayan bir değeri `false` say (fail-open yerine fail-closed).
-- BEKLENEN: 310'un "tanınmayan değer varsayılana düşüyor, özelliği SESSİZCE
-- kapatmıyor" iddiası kırmızı.
--
-- NEDEN BU BİR KORUMA: bayrak sütunu bir KILL SWITCH ve anahtar değeri elle
-- SQL Editor'dan giriliyor. 'evet', 'yes', 'True ' gibi bir yazım hatasının
-- canlı bir özelliği kapatması, bayrağın önlemek için var olduğu hatadan daha
-- pahalı olurdu. 0075'in asimetrisi burada da geçerli: özellik/kota sayıları
-- fail-open, kimlik doğrulama sırrı fail-closed.
create or replace function public.config_bool(p_key text, p_default boolean)
returns boolean language sql stable security definer set search_path = public
as $fn$
  select coalesce(
    (select lower(btrim(value)) in ('true', 't', '1')
       from public.app_config where key = p_key),
    p_default);
$fn$;
revoke execute on function public.config_bool(text, boolean)
  from public, anon, authenticated;
-- @UNDO
create or replace function public.config_bool(p_key text, p_default boolean)
returns boolean language sql stable security definer set search_path = public
as $fn$
  select coalesce(
    (select case
              when lower(btrim(value)) in ('true',  't', '1') then true
              when lower(btrim(value)) in ('false', 'f', '0') then false
            end
       from public.app_config where key = p_key),
    p_default);
$fn$;
revoke execute on function public.config_bool(text, boolean)
  from public, anon, authenticated;
