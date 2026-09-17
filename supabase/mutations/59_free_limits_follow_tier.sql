-- test: supabase/tests/100_ai_quota.sql
--
-- MUTASYON: `free_*` sutunlarini CAGIRANIN katmanina bagla — yani 0099
-- oncesindeki davranisi geri getir.
-- BEKLENEN: 100'un "PREMIUM koltuktan bakildiginda bile ucretsiz pencere
-- siniri 10" ve "ucretsiz sutun ile CAGIRANIN sutunu ayni sayi DEGIL"
-- iddialari kirmizi.
--
-- NEDEN BU BIR KORUMA: paywall'in "Ucretsiz" sutunu bu iki sayiyi yaziyor.
-- Sunucu ayri bir alan yayinlamadigi surece ekran `ai_*` sutunlarini
-- kullanmak zorundaydi ve onlar CAGIRANIN katmanini anlatiyor: abonede kiyas
-- tablosu "Ucretsiz 50 | Plus 50", anonimde "Ucretsiz 3 | Plus 50" diyordu —
-- ikincisi omur boyu DENEME tavanini ucretsiz katman diye gosteriyor.
--
-- MUTASYON UCRETSIZ KULLANICIDA GORUNMEZ: iki sutun orada zaten esit. Bu
-- yuzden 100'un iddialari PREMIUM ve ANONIM koltuktan yapiliyor.
--
-- NOT: iki govde de goc dosyasindan URETILDI. Kaynak: 0099.
-- GERI ALMA `drop function` YAPAMAZ: o anda `my_daily_state` gorunumu
-- fonksiyona bagimli ve Postgres dusurmeyi reddeder. `create or replace`
-- kullaniliyor ve goc de ayni oneki tasiyor (check_sql 7. kontrol imza
-- onekini de karsilastiriyor).
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
  free_window_limit  := ai_window_limit;
  free_month_limit   := ai_month_limit;

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
-- @UNDO
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
