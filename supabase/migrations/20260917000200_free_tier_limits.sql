-- 0099 — ücretsiz katman sınırları ve `daily_goal_date` yayınlanıyor (Task 17)
--
-- İKİ BULGU, TEK GÖÇ. İkisi de `my_daily_state`i yeniden kurmayı gerektiriyor
-- ve görünümün tam gövdesi 58 numaralı mutasyonun içinde de duruyor; iki ayrı
-- göç, iki ayrı mutasyon güncellemesi ve iki kat risk demekti.
--
-- 1) PAYWALL'IN "ÜCRETSİZ" SÜTUNU YANLIŞ SAYIYI GÖSTERİYORDU.
--    `ai_state()` iki sınır sütununu da ÇAĞIRANIN katmanına göre dolduruyor;
--    sunucu ayrı bir "ücretsiz katman sınırı" alanı hiç yayınlamıyordu.
--    Abonede kıyas tablosu "Ücretsiz 50 | Plus 50", anonimde "Ücretsiz 3 |
--    Plus 50" yazıyordu — ikincisi ömür boyu DENEME tavanını ücretsiz katman
--    diye gösteriyor. Task 16 istemci tarafını kapattı (rakamlar güvenilir
--    değilse tablo hiç çizilmiyor), ama abone kullanıcı o yüzden tabloyu hiç
--    göremiyordu. Kalıcı çözüm buydu: sınırları katmandan BAĞIMSIZ yayınlamak.
--
-- 2) `daily_goal_date` YAYINLANMIYORDU.
--    Günlük hedef ödülünün "bugün alındı mı" bilgisi `profiles.daily_goal_date`
--    olarak sunucuda duruyor ama görünümde yoktu. İstemci yalnızca oturum-içi
--    `_lastGoalDate`e bakıyor ve `GameProgress.clear()` onu çıkışta
--    sıfırlıyor. Sonuç: yeniden kurulumda ya da ikinci cihazda istemci "ödül
--    alınmadı" sanıyor, ilerleme halkasını %100 yerine eksik gösteriyor ve
--    "Devam"a basınca `claim_daily_goal` sessizce `gems_awarded = 0`
--    döndürüyor. Task 16'nın C0-2 için eklediği geri alma da bunu düzeltmiyor,
--    çünkü sunucu HATA atmıyor — sıfır ödül veriyor.
--
-- SIRA ZORUNLU: görünüm fonksiyona bağımlı, yani önce görünüm düşüyor.
-- `ai_state()`in OUT satır tipi değişiyor ve Postgres bunu `create or replace`
-- ile kabul etmiyor (SONA eklemek de dahil) — deponun 5. statik kontrolü
-- zaten yakalıyor. `drop function ... cascade` YAZILMIYOR: görünümü sessizce
-- düşürürdü ve geri kuran satır olmazdı.
--
-- CANLI GÖVDELER 0094 (`ai_state`, askı kapısı) ve 0096 (`my_daily_state`,
-- zaman bazlı `due_count`) sürümlerinden ÜRETİLDİ — ilk tanımdan değil.
-- Bu göçün kardeşi 0098 tam bu hatayı bir kez yaptı ve kapı yakaladı.
--
-- DROP GRANT'LARI SİLER: fonksiyonun ve görünümün yetkileri yeniden yazılıyor.
drop view if exists public.my_daily_state;
drop function if exists public.ai_state();

-- `drop` + `create or replace` — ikisi birden, BILEREK.
--
-- `drop` zorunlu: OUT satir tipi degisiyor. `create or replace` ise
-- mutasyonlar icin: 36, 54 ve 59 numarali mutasyonlar bu fonksiyonun tam
-- govdesini tasiyor ve GERI ALMA yarilari `drop function` YAPAMAZ — o anda
-- `my_daily_state` gorunumu hala fonksiyona bagimli ve Postgres dusurmeyi
-- reddediyor ("cannot drop function ... other objects depend on it").
-- Geri alma `create or replace` yazmak zorunda; check_sql'in 7. kontrolu de
-- imza onekini karsilastirdigi icin CANLI govde de ayni oneki tasimali.
-- (Ilk surum `create function` yaziyordu ve mutasyon kontrolu FAZ 3'te
-- "geri alma calistirilamadi / veritabani BOZUK" ile dustu.)
create or replace function public.ai_state()
returns table (
  -- SIRA 0075'TEKININ AYNISI OLMAK ZORUNDA. `create or replace`, OUT
  -- parametrelerinin tanimladigi satir tipini (ad + SIRA dahil) degistirmeye
  -- izin vermiyor: "cannot change return type of existing function /
  -- Row type defined by OUT parameters is different". Bu dosya ayni kurali
  -- `consume_ai_use` icin zaten biliyor (asagida drop + create yapiyor).
  ai_tier            text,
  ai_state           text,
  ai_left            int,
  ai_window_left     int,
  ai_window_limit    int,
  ai_month_left      int,
  ai_month_limit     int,
  ai_next_at         timestamptz,
  ai_next_at_hm      text,
  ai_month_resets_at timestamptz,
  ai_month_resets_on date,
  ai_window_hours    int,
  ad_rewards_left    int,
  ad_rewards_per_day int,
  ad_offer           boolean,
  plus_window_limit  int,
  plus_month_limit   int,
  -- ÜCRETSİZ KATMANIN sınırları — ÇAĞIRANIN katmanından BAĞIMSIZ (0099).
  -- `ai_window_limit` / `ai_month_limit` çağıranın kendi katmanını anlatıyor;
  -- paywall'ın "Ücretsiz" sütunu ise ücretsiz katmanı anlatmak zorunda.
  -- Abonede ikisi eşitleniyordu ("Ücretsiz 50 | Plus 50"), anonimde ömür boyu
  -- deneme tavanı ücretsiz katman gibi görünüyordu ("Ücretsiz 3").
  free_window_limit  int,
  free_month_limit   int
)
language plpgsql stable security definer set search_path = public
as $fn$
declare
  v_uid       uuid := auth.uid();
  v_hours     int;
  v_used      int;
  v_month     int;
  v_reward    int := 0;
  v_effective int;
  v_suspended boolean;
begin
  if v_uid is null then
    return;
  end if;

  v_hours         := public.config_int('ai_window_hours', 8);
  ai_window_hours := v_hours;
  ai_tier         := public.user_tier();
  if ai_tier is null then
    return;
  end if;

  v_suspended        := public.is_suspended(v_uid);
  ad_rewards_per_day := public.config_int('ad_reward_daily', 3);
  plus_window_limit  := public.config_int('ai_window_premium', 50);
  plus_month_limit   := public.config_int('ai_month_premium', 1000);
  free_window_limit  := public.config_int('ai_window_free', 10);
  free_month_limit   := public.config_int('ai_month_free', 300);

  ai_month_resets_at := public.istanbul_month_reset();
  ai_month_resets_on := (ai_month_resets_at at time zone 'Europe/Istanbul')::date;

  if ai_tier = 'anonymous' then
    ai_window_limit := public.config_int('ai_lifetime_anon', 3);
    ai_month_limit  := ai_window_limit;
    select count(*)::int into v_used
      from public.ai_calls c
     where c.user_id = v_uid
       and c.refunded_at is null;
    ai_window_left := greatest(ai_window_limit - v_used, 0);
    ai_month_left  := ai_window_left;
    ai_left        := ai_window_left;
    ai_next_at      := null;
    ai_next_at_hm   := null;
    ad_rewards_left := 0;
  else
    ai_window_limit := public.config_int(
      case when ai_tier = 'premium' then 'ai_window_premium'
           else 'ai_window_free' end,
      case when ai_tier = 'premium' then 50 else 10 end);
    ai_month_limit := public.config_int(
      case when ai_tier = 'premium' then 'ai_month_premium'
           else 'ai_month_free' end,
      case when ai_tier = 'premium' then 1000 else 300 end);

    select count(*)::int into v_used
      from public.ai_calls c
     where c.user_id = v_uid
       and c.refunded_at is null
       and c.at > now() - make_interval(hours => v_hours);

    select count(*)::int into v_month
      from public.ai_calls c
     where c.user_id = v_uid
       and c.refunded_at is null
       and c.at >= date_trunc('month', now() at time zone 'Europe/Istanbul')
                   at time zone 'Europe/Istanbul';

    if ai_tier = 'free' then
      select count(*)::int into v_reward
        from public.ad_rewards r
       where r.user_id = v_uid
         and r.status = 'granted'
         and r.consumed_at is null
         and (r.granted_at at time zone 'Europe/Istanbul')::date
             = public.istanbul_day();
    end if;

    v_effective    := ai_window_limit + v_reward;
    ai_window_left := greatest(v_effective - v_used, 0);
    ai_month_left  := greatest(ai_month_limit - v_month, 0);
    ai_left        := least(ai_window_left, ai_month_left);

    -- SONRAKİ HAKKIN ANI — `min(at) + 8sa` DEĞİL; pencerenin k'ıncı en eski
    -- çağrısı (k = kullanılan − etkin + 1). İade edilmiş satırlar sıraya da
    -- girmiyor, yoksa geri verilmiş bir yuva "dolu" gibi saat üretirdi.
    select c.at + make_interval(hours => v_hours) into ai_next_at
      from public.ai_calls c
     where c.user_id = v_uid
       and c.refunded_at is null
       and c.at > now() - make_interval(hours => v_hours)
     order by c.at
    offset greatest(v_used - v_effective, 0)
       limit 1;

    ai_next_at_hm := to_char(ai_next_at at time zone 'Europe/Istanbul',
                             'HH24:MI');

    -- 0075:367-378'DEN GERI GETIRILDI. Bu blok dusmustu ve sonucu sessizdi:
    -- `ad_rewards_left` NULL kaliyor, `ad_offer` NULL'a dusuyor, istemcideki
    -- `ad_offer == true` hicbir zaman tutmuyordu — yani odullu reklam yolu
    -- arayuzde TAMAMEN oludu.
    if ai_tier = 'premium' then
      ad_rewards_left := 0;       -- premium reklam gormemek icin odedi
    else
      ad_rewards_left := greatest(
        ad_rewards_per_day - (
          select count(*)::int from public.ad_rewards r
           where r.user_id = v_uid
             and r.status = 'granted'
             and (r.granted_at at time zone 'Europe/Istanbul')::date
                 = public.istanbul_day()
        ), 0);
    end if;
  end if;

  -- Durum sırası: askı > ömür > ay > pencere > az > bol.
  ai_state := case
    when v_suspended                       then 'suspended'
    when ai_tier = 'anonymous'
     and ai_window_left <= 0               then 'lifetime_full'
    when ai_month_left <= 0                then 'month_full'
    when ai_window_left <= 0               then 'window_full'
    when ai_left <= public.config_int('ai_low_threshold', 2) then 'low'
    else 'ok'
  end;

  -- 0075:398-403'TEN GERI GETIRILDI. Aylik sinir doldugunda pencere saati
  -- GOSTERILMEZ (urun kurali). Karari burada veriyoruz ki istemci bir sey
  -- secmek zorunda kalmasin; `my_daily_state` yorumu ve
  -- `DailyState.aiNextAtHm` dokumani zaten "sunucu bunu null yapiyor" diyor.
  if ai_state in ('month_full', 'lifetime_full', 'suspended') then
    ai_next_at    := null;
    ai_next_at_hm := null;
  end if;

  -- Kullanılamayacak bir ödül karşılığında reklam gösterilmez (karanlık desen
  -- koruması): ay doluyken teklif YOK.
  --
  -- `ff_ad_reward` KAPISI BURADA (0094). Bayrak 0079'da tanımlanmıştı ama TEK
  -- BİR OKUYUCUSU YOKTU: `app_config`'e `false` yazmak hiçbir şeyi
  -- değiştirmiyordu. Kapı SUNUCUDA da olmak zorunda — istemci kapısı yalnızca
  -- güncel sürümleri kapsar, `ad_offer` ise sunucunun kararı.
  ad_offer := ai_tier = 'free'
          and not v_suspended
          and public.config_bool('ff_ad_reward', true)
          and ai_month_left > 0
          and ai_window_left <= 0
          and ad_rewards_left > 0;

  return next;
end
$fn$;

revoke execute on function public.ai_state() from public, anon;
grant  execute on function public.ai_state() to authenticated;

comment on function public.ai_state() is
  'Analiz hakkının tüm gösterim değerleri. `free_*` sütunları ÜCRETSİZ '
  'katmanın sınırları ve çağıranın katmanından bağımsız (0099); `ai_*` '
  'sütunları çağıranın kendi katmanını anlatıyor.';

create view public.my_daily_state
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
  p.daily_goal_date
from public.profiles p,
     public.ai_state() s,
     public.feature_flags() f
-- LEFT JOIN LATERAL: aboneliği olmayan kullanıcıda `subscription_state()`
-- SIFIR satır döndürüyor ve virgülle (cross join) yazılsaydı GÖRÜNÜMÜN
-- TAMAMI boş dönerdi — yani abonesi olmayan herkes HUD'unu kaybederdi.
left join lateral public.subscription_state() sub on true
where p.id = auth.uid();

revoke all on public.my_daily_state from public, anon;
grant select on public.my_daily_state to authenticated;

comment on view public.my_daily_state is
  'Kullanıcının günlük durumu (yalnızca kendi satırı). Analiz hakkının TÜM '
  'gösterim değerleri, ücretsiz katman sınırları (0099), özellik bayrakları, '
  'abonelik durumu ve günlük hedef ödülünün alındığı gün. İstemci hiçbir şey '
  'hesaplamıyor.';
