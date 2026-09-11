-- test: supabase/tests/300_ad_reward.sql
--
-- MUTASYON: aylık cap dolu kullanıcıya da reklam teklif et.
-- BEKLENEN: 300'ün "ay doluyken RPC de reddediyor" iddiası kırmızı.
--
-- KARANLIK DESEN KORUMASI: kullanılamayacak bir ödül karşılığında reklam
-- izletmek kullanıcıya düşmanca ve ödüllü reklam politikası açısından riskli.
-- Düğmenin çizilmemesi tek başına bir güvenlik kontrolü DEĞİL; sunucu da
-- reddetmeli. Bu mutasyon ikinci katmanı söküyor.
create or replace function public.start_ad_reward()
returns table (ok boolean, ad_nonce uuid, reason text)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_new uuid;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  delete from public.ad_rewards r
   where r.user_id = v_uid and r.status = 'pending';
  insert into public.ad_rewards (user_id, nonce)
  values (v_uid, gen_random_uuid())
  returning public.ad_rewards.nonce into v_new;
  return query select true, v_new, 'ok'::text;
end
$fn$;
-- @UNDO
create or replace function public.start_ad_reward()
returns table (ok boolean, ad_nonce uuid, reason text)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid      uuid := auth.uid();
  v_s        record;
  v_ttl      int;
  v_existing uuid;
  v_new      uuid;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  v_ttl := public.config_int('ad_pending_ttl_min', 5);

  delete from public.ad_rewards r
   where r.user_id = v_uid
     and r.status = 'pending'
     and r.created_at < now() - make_interval(mins => v_ttl);

  select r.nonce into v_existing
    from public.ad_rewards r
   where r.user_id = v_uid and r.status = 'pending'
   limit 1;
  if v_existing is not null then
    return query select true, v_existing, 'pending'::text;
    return;
  end if;

  select * into v_s from public.ai_state();
  if v_s is null then
    return query select false, null::uuid, 'no_state'::text;
    return;
  end if;

  if v_s.ai_state = 'suspended' then
    return query select false, null::uuid, 'suspended'::text;
    return;
  end if;
  if v_s.ai_tier <> 'free' then
    return query select false, null::uuid, 'not_free_tier'::text;
    return;
  end if;
  if v_s.ai_month_left <= 0 then
    return query select false, null::uuid, 'month_full'::text;
    return;
  end if;
  if v_s.ad_rewards_left <= 0 then
    return query select false, null::uuid, 'no_rewards_left'::text;
    return;
  end if;
  if v_s.ai_window_left > 0 then
    return query select false, null::uuid, 'not_needed'::text;
    return;
  end if;

  if not public.bump_rate_limit(
           'ad_start',
           public.config_int('ad_reward_daily', 3) * 4,
           public.istanbul_day()::text) then
    return query select false, null::uuid, 'too_many_attempts'::text;
    return;
  end if;

  begin
    insert into public.ad_rewards (user_id, nonce)
    values (v_uid, gen_random_uuid())
    returning public.ad_rewards.nonce into v_new;
  exception
    when unique_violation then
      select r.nonce into v_new
        from public.ad_rewards r
       where r.user_id = v_uid and r.status = 'pending'
       limit 1;
      if v_new is null then
        return query select false, null::uuid, 'race'::text;
        return;
      end if;
  end;

  return query select true, v_new, 'ok'::text;
end
$fn$;
