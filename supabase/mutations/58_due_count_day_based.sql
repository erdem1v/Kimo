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
-- NOT: iki govde de goc dosyasindan URETILDI. Kaynak: 0099 (ucretsiz
-- katman sutunlari + daily_goal_date). GORUNUM GOVDELERI KAPININ KOR
-- NOKTASI: check_sql'in 7. ve 10. kontrolleri yalnizca FONKSIYON,
-- POLITIKA ve GRANT karsilastiriyor. Gorunume sutun eklendiginde bu
-- dosya elle guncellenmezse `create or replace view` daha KISA listeyi
-- yazmaya calisir ve Postgres 'cannot drop columns from view' ile
-- reddeder — mutasyon kontrolu FAZ 2'de duser.
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
  sub.sub_in_trial,
  -- ÜCRETSİZ KATMANIN sınırları (0099). Paywall'ın "Ücretsiz" sütunu bunları
  -- kullanıyor; `ai_window_limit`/`ai_month_limit` ÇAĞIRANIN katmanını
  -- anlatıyor ve abonede/anonimde yanlış sütun oluyordu.
  s.free_window_limit,
  s.free_month_limit,
  -- GÜNLÜK HEDEF ÖDÜLÜ BUGÜN ALINDI MI (0099). Sunucuda zaten duruyordu ama
  -- yayınlanmıyordu: istemci yalnızca oturum-içi bir alana bakıyor ve
  -- `GameProgress.clear()` onu çıkışta sıfırlıyor. Kullanıcı uygulamayı
  -- yeniden kurar ya da ikinci cihazdan girerse istemci "ödül alınmadı"
  -- sanıyor, ilerleme halkasını eksik gösteriyor ve `claim_daily_goal`
  -- sessizce `gems_awarded = 0` döndürüyordu.
  p.daily_goal_date,
  -- SESSİZ SAATLER OKUNABİLİR OLMALI (0100). Yazma `set_quiet_hours`tan
  -- geçiyor ama istemcinin DEĞERİ de görmesi gerekiyor: yalnızca cihazda
  -- tutulsaydı ikinci cihaz kendi varsayılanını (22–08) gösterir, sunucu ise
  -- ilk cihazın yazdığını uygular — deponun iki turdur kapattığı "istemci bir
  -- yere yazıyor, okuyan başka yere bakıyor" sınıfının aynısı.
  p.quiet_start,
  p.quiet_end
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
  sub.sub_in_trial,
  -- ÜCRETSİZ KATMANIN sınırları (0099). Paywall'ın "Ücretsiz" sütunu bunları
  -- kullanıyor; `ai_window_limit`/`ai_month_limit` ÇAĞIRANIN katmanını
  -- anlatıyor ve abonede/anonimde yanlış sütun oluyordu.
  s.free_window_limit,
  s.free_month_limit,
  -- GÜNLÜK HEDEF ÖDÜLÜ BUGÜN ALINDI MI (0099). Sunucuda zaten duruyordu ama
  -- yayınlanmıyordu: istemci yalnızca oturum-içi bir alana bakıyor ve
  -- `GameProgress.clear()` onu çıkışta sıfırlıyor. Kullanıcı uygulamayı
  -- yeniden kurar ya da ikinci cihazdan girerse istemci "ödül alınmadı"
  -- sanıyor, ilerleme halkasını eksik gösteriyor ve `claim_daily_goal`
  -- sessizce `gems_awarded = 0` döndürüyordu.
  p.daily_goal_date,
  -- SESSİZ SAATLER OKUNABİLİR OLMALI (0100). Yazma `set_quiet_hours`tan
  -- geçiyor ama istemcinin DEĞERİ de görmesi gerekiyor: yalnızca cihazda
  -- tutulsaydı ikinci cihaz kendi varsayılanını (22–08) gösterir, sunucu ise
  -- ilk cihazın yazdığını uygular — deponun iki turdur kapattığı "istemci bir
  -- yere yazıyor, okuyan başka yere bakıyor" sınıfının aynısı.
  p.quiet_start,
  p.quiet_end
from public.profiles p,
     public.ai_state() s,
     public.feature_flags() f
-- LEFT JOIN LATERAL: aboneliği olmayan kullanıcıda `subscription_state()`
-- SIFIR satır döndürüyor ve virgülle (cross join) yazılsaydı GÖRÜNÜMÜN
-- TAMAMI boş dönerdi — yani abonesi olmayan herkes HUD'unu kaybederdi.
left join lateral public.subscription_state() sub on true
where p.id = auth.uid();
