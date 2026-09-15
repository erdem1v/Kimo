-- test: supabase/tests/215_review_timing.sql
--
-- MUTASYON: `my_daily_state.due_count`u GUN bazli sayima geri dondur.
--
-- BEKLENEN: 215'in "henuz vadesi gelmedi: due_count 0" iddiasi kirmizi.
--
-- NEDEN BU BIR KORUMA: 0049'dan beri vade bir ZAMAN DAMGASI ve yeni soru ayni
-- gun +3 saate vadeleniyor. Gun bazli sayim, o gun ilerisi icin vadelenmis bir
-- soruyu gece yarisindan itibaren "bugun tekrar" sayiyor; istemcinin listesi
-- ise zaman bazli suzuyor. HUD "1 tekrar" derken oturum bos kaliyordu.
--
-- NOT: bu iddia Task 14'e kadar SAATE BAGLI olarak yesil kaliyordu (Istanbul
-- 21:00'den sonra now()+3sa ertesi gune tasidigi icin tarih karsilastirmasi
-- tesadufen dogru cevabi veriyordu). Duzeltmeden sonra gunun her saatinde
-- ayirt ediyor.
create or replace view public.my_daily_state
with (security_invoker = false) as
select
  p.id                                              as user_id,
  p.gems,
  p.xp,
  case when p.last_activity_date >= public.istanbul_day() - 1
       then p.streak else 0 end                     as streak,
  case when p.week_start = public.istanbul_week()
       then p.weekly_xp else 0 end                  as weekly_xp,
  p.league,
  p.last_activity_date,
  p.premium_until,
  public.istanbul_day()                             as today,
  public.istanbul_week()                            as week_start,
  (
    select count(*)::int from public.mistakes m
     where m.user_id = p.id
       and m.last_reviewed_at >=
           (public.istanbul_day())::timestamp at time zone 'Europe/Istanbul'
  )                                                 as reviewed_today_count,
  (
    select count(*)::int from public.mistakes m
     where m.user_id = p.id
       and not m.mastered
       and m.next_review_date <= public.istanbul_day()
  )                                                 as due_count,
  (
    select count(*)::int from public.received_questions rq
     where rq.solved_at is null
  )                                                 as unsolved_received_count,
  s.ai_tier,
  s.ai_state,
  s.ai_left,
  s.ai_window_left,
  s.ai_window_limit,
  s.ai_month_left,
  s.ai_month_limit,
  s.ai_next_at,
  s.ai_next_at_hm,
  s.ai_month_resets_at,
  s.ai_month_resets_on,
  s.ai_window_hours,
  s.ad_rewards_left,
  s.ad_rewards_per_day,
  s.ad_offer,
  s.plus_window_limit,
  s.plus_month_limit,
  f.ff_pair_streak,
  f.ff_multi_capture,
  f.ff_ad_reward,
  f.ff_iap,
  sub.sub_status,
  sub.sub_store,
  sub.sub_expires_at,
  sub.sub_renews,
  sub.sub_in_trial
from public.profiles p,
     public.ai_state() s,
     public.feature_flags() f
-- LEFT JOIN LATERAL: aboneliği olmayan kullanıcıda `subscription_state()`
-- SIFIR satır döndürüyor ve virgülle (cross join) yazılsaydı GÖRÜNÜMÜN
-- TAMAMI boş dönerdi — yani abonesi olmayan herkes HUD'unu kaybederdi.
left join lateral public.subscription_state() sub on true
where p.id = auth.uid();

-- @UNDO
create or replace view public.my_daily_state
with (security_invoker = false) as
select
  p.id                                              as user_id,
  p.gems,
  p.xp,
  case when p.last_activity_date >= public.istanbul_day() - 1
       then p.streak else 0 end                     as streak,
  case when p.week_start = public.istanbul_week()
       then p.weekly_xp else 0 end                  as weekly_xp,
  p.league,
  p.last_activity_date,
  p.premium_until,
  public.istanbul_day()                             as today,
  public.istanbul_week()                            as week_start,
  (
    select count(*)::int from public.mistakes m
     where m.user_id = p.id
       and m.last_reviewed_at >=
           (public.istanbul_day())::timestamp at time zone 'Europe/Istanbul'
  )                                                 as reviewed_today_count,
  (
    select count(*)::int from public.mistakes m
     where m.user_id = p.id
       and not m.mastered
       and (
         m.next_review_at <= now()
         or (m.next_review_at is null
             and m.next_review_date <= public.istanbul_day())
       )
  )                                                 as due_count,
  (
    select count(*)::int from public.received_questions rq
     where rq.solved_at is null
  )                                                 as unsolved_received_count,
  s.ai_tier,
  s.ai_state,
  s.ai_left,
  s.ai_window_left,
  s.ai_window_limit,
  s.ai_month_left,
  s.ai_month_limit,
  s.ai_next_at,
  s.ai_next_at_hm,
  s.ai_month_resets_at,
  s.ai_month_resets_on,
  s.ai_window_hours,
  s.ad_rewards_left,
  s.ad_rewards_per_day,
  s.ad_offer,
  s.plus_window_limit,
  s.plus_month_limit,
  f.ff_pair_streak,
  f.ff_multi_capture,
  f.ff_ad_reward,
  f.ff_iap,
  sub.sub_status,
  sub.sub_store,
  sub.sub_expires_at,
  sub.sub_renews,
  sub.sub_in_trial
from public.profiles p,
     public.ai_state() s,
     public.feature_flags() f
-- LEFT JOIN LATERAL: aboneliği olmayan kullanıcıda `subscription_state()`
-- SIFIR satır döndürüyor ve virgülle (cross join) yazılsaydı GÖRÜNÜMÜN
-- TAMAMI boş dönerdi — yani abonesi olmayan herkes HUD'unu kaybederdi.
left join lateral public.subscription_state() sub on true
where p.id = auth.uid();
