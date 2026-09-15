-- 0096 — HUD tekrar sayacı ZAMAN bazlı (Task 14)
--
-- BULGU: `my_daily_state.due_count` vadeyi yalnızca TARİHTEN okuyordu
--   and m.next_review_date <= public.istanbul_day()
-- oysa 0049'dan beri vade bir ZAMAN DAMGASI (`next_review_at`) ve yeni eklenen
-- soru AYNI GÜN +3 saate vadeleniyor. Sonuç: saat 00:00'dan itibaren, o gün
-- ilerisi için vadelenmiş bir soru sayaca giriyordu.
--
-- İSTEMCİ BAŞKA TÜRLÜ SÜZÜYOR (`mistake_repository.dart`):
--   next_review_at <= now  OR  (next_review_at is null AND next_review_date <= today)
-- yani HUD "1 tekrar" derken oturumun listesi boş kalabiliyordu. Sayı ile
-- listenin aynı şeyi söylememesi, "arayüzde görünen her mekanik gerçekten
-- çalışır" değişmezinin ihlali.
--
-- NEDEN ŞİMDİ GÖRÜLDÜ: `tests/215` bunu zaten iddia ediyordu ("gün bazlı eski
-- sayım 1 gösterirdi") ama SAATE BAĞLI olarak yeşil kalıyordu. Vade `now() +
-- 3 saat`; İstanbul saatiyle 21:00'den sonra bu ertesi güne taşıyor ve tarih
-- karşılaştırması tesadüfen 0 döndürüyordu. Bugüne kadarki bütün CI koşuları
-- o pencereye denk gelmiş; gece yarısını geçen ilk koşuda kırmızı döndü.
-- Yani test doğru şeyi iddia ediyordu, yalnızca günün 21 saatinde kanıt
-- üretmiyordu.
--
-- Sütun listesi DEĞİŞMİYOR, bu yüzden `create or replace view` yeterli
-- (görünüm ayrıca `received_questions`e dayanıyor; düşürmek zinciri düşürürdü
-- — bkz. 0087 ve check_sql.py 8. kontrol).
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