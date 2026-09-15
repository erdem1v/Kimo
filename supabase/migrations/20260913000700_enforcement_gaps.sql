-- 0094 — Kapatılamayan bayraklar ve zorlanmayan yaptırımlar (Task 13 · Paket 5)
--
-- BÜTÜNLÜK DENETİMİNİN BULDUĞU DÖRT BOŞLUK. Hepsi aynı sınıftan: bir kural
-- YAZILI ama VERİ KATMANINDA ZORLANMIYOR ya da bir anahtar ÇİZİLMİŞ ama HİÇBİR
-- YERE BAĞLANMAMIŞ.

-- ================================================ 1) `ff_ad_reward` ÖLÜ BAYRAKTI
-- 0079 bu bayrağı "AdMob tarafında bir sorun çıktığında reklam yüzeyini sürüm
-- beklemeden kapatmak için" diye tanımladı. Ama TEK BİR OKUYUCUSU YOKTU:
-- `DailyState.adRewardEnabled` getter'ı yazılmıştı ve üretim kodunda hiçbir
-- yerden çağrılmıyordu; hak duvarı yalnızca `ad_offer`e bakıyordu.
-- `app_config`'e `ff_ad_reward = 'false'` yazmak HİÇBİR ŞEYİ değiştirmiyordu.
--
-- KAPI SUNUCUYA DA KONULUYOR, bilinçli: istemci kapısı yalnızca GÜNCEL
-- sürümleri kapsar. `ad_offer` sunucunun kararı ve eski bir istemci de onu
-- okuyor — kill switch'in gerçekten anahtar olması için burada da olmalı.
--
-- GÖVDE DEĞİŞİYOR, OUT LİSTESİ DEĞİL: `create or replace` güvenli.
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
  plus_month_limit   int
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

-- ============================================ 2) askı AI TÜKETİMİNİ durdurmuyordu
-- `ai_state` `'suspended'` diyordu ama `ai_left` normal hesaplanıyordu ve
-- `consume_ai_use` yalnızca `ai_left <= 0`'a bakıyordu. Askıdaki kullanıcı
-- istemcide askı ekranını kapatabildiği için (`auth_gate` `onContinue`)
-- fotoğraf çekip analiz ettirebiliyordu: GERÇEK OpenAI maliyeti oluşuyor,
-- hakkı yanıyor, sonra kaydetme `mistakes` politikasında 42501 ile düşüyordu.
--
-- İstemci dokümanı bunun TERSİNİ söylüyordu: "Analiz sonucunu kaydedemeyeceği
-- için hak da harcatılmıyor." Sunucu bunu uygulamıyordu.
--
-- `start_ad_reward` askıyı ZATEN soruyordu; bu, aynı kuralın tüketim
-- tarafındaki karşılığı.
create or replace function public.consume_ai_use(p_sha_hex text default null)
returns table (
  allowed            boolean,
  ai_state           text,
  ai_tier            text,
  remaining          int,
  ai_window_left     int,
  ai_window_limit    int,
  ai_month_left      int,
  ai_month_limit     int,
  ai_next_at         timestamptz,
  ai_next_at_hm      text,
  ai_month_resets_at timestamptz,
  ai_month_resets_on date,
  ad_rewards_left    int,
  ad_offer           boolean,
  call_id            bigint
)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_s      record;
  v_reward uuid;
  v_sha    bytea;
  v_call   bigint;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  -- İŞLEM ÖMÜRLÜ advisory kilit (0075'in gerekçesi aynen): oturum ömürlü
  -- kilit Supavisor'ın işlem kipinde havuzlanmış bağlantılar arasında sızar.
  -- `grant_ad_reward` AYNI kilidi alıyor, yani ödül verme ile tüketim araya
  -- girmiyor. Kilit OpenAI çağrısı sırasında TUTULMUYOR.
  perform pg_advisory_xact_lock(hashtext('ai_quota'), hashtext(v_uid::text));

  select * into v_s from public.ai_state();

  -- ASKI TÜKETİMİ DURDURUYOR (0094). `ai_left <= 0` ile AYNI dalda: reddin
  -- sebebi `ai_state` alanında zaten ayrımlanıyor (`suspended`), istemci
  -- doğru ekranı çiziyor ve HİÇBİR hak yanmıyor. Gövdenin geri kalanı
  -- 0083'ten BİREBİR — `photo_sha256`, `from_reward` ve ödül tüketimi
  -- dahil hiçbir satır yeniden yazılmadı.
  if v_s is null or v_s.ai_state = 'suspended' or v_s.ai_left <= 0 then
    return query
      select false, coalesce(v_s.ai_state, 'window_full'), v_s.ai_tier,
             0, coalesce(v_s.ai_window_left, 0), v_s.ai_window_limit,
             coalesce(v_s.ai_month_left, 0), v_s.ai_month_limit,
             v_s.ai_next_at, v_s.ai_next_at_hm,
             v_s.ai_month_resets_at, v_s.ai_month_resets_on,
             coalesce(v_s.ad_rewards_left, 0),
             coalesce(v_s.ad_offer, false),
             null::bigint;
    return;
  end if;

  if v_s.ai_window_left > 0
     and v_s.ai_window_left <= (
       select count(*)::int from public.ad_rewards r
        where r.user_id = v_uid and r.status = 'granted'
          and r.consumed_at is null
          and (r.granted_at at time zone 'Europe/Istanbul')::date
              = public.istanbul_day())
  then
    select r.id into v_reward
      from public.ad_rewards r
     where r.user_id = v_uid and r.status = 'granted'
       and r.consumed_at is null
       and (r.granted_at at time zone 'Europe/Istanbul')::date
           = public.istanbul_day()
     order by r.granted_at
     limit 1;
    if v_reward is not null then
      update public.ad_rewards set consumed_at = now() where id = v_reward;
    end if;
  end if;

  if p_sha_hex is not null and p_sha_hex ~ '^[0-9a-f]{64}$' then
    v_sha := decode(p_sha_hex, 'hex');
  end if;

  insert into public.ai_calls (user_id, tier, photo_sha256, from_reward)
  values (v_uid, v_s.ai_tier, v_sha, v_reward is not null)
  returning public.ai_calls.id into v_call;

  select * into v_s from public.ai_state();

  return query
    select true, v_s.ai_state, v_s.ai_tier,
           v_s.ai_left, v_s.ai_window_left, v_s.ai_window_limit,
           v_s.ai_month_left, v_s.ai_month_limit,
           v_s.ai_next_at, v_s.ai_next_at_hm,
           v_s.ai_month_resets_at, v_s.ai_month_resets_on,
           v_s.ad_rewards_left, v_s.ad_offer, v_call;
end
$fn$;
revoke execute on function public.consume_ai_use(text) from public, anon;
grant  execute on function public.consume_ai_use(text) to authenticated;

-- ============================ 3) "sayıyı 0 yaz, özellik kapansın" YANLIŞTI
-- `bump_rate_limit` ilk INSERT'i `on conflict` dalına HİÇ GİRMEDEN yapıyor;
-- `p_limit` yalnızca çakışma dalında okunuyor. Yani `p_limit = 0` iken pencere
-- başına BİR çağrı geçiyordu. `qsend_daily = '0'` yazan operatör özelliği
-- kapattığını sanır ama her kullanıcı günde bir soru göndermeye devam ederdi.
-- Aynı tuzak `ai_refund_daily` ve diğer bütün kovalarda.
create or replace function public.bump_rate_limit(
  p_bucket     text,
  p_limit      int,
  p_window_key text
)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_n   int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  -- SIFIR GERÇEKTEN KAPATIYOR. Bu satır olmadan ilk çağrı `on conflict`
  -- dalına hiç girmediği için sınırı görmüyordu.
  if p_limit <= 0 then
    return false;
  end if;

  insert into public.rate_limits (user_id, bucket, window_key, n)
  values (v_uid, p_bucket, p_window_key, 1)
  on conflict (user_id, bucket, window_key) do update
     set n = rate_limits.n + 1,
         updated_at = now()
   where rate_limits.n < p_limit
  returning rate_limits.n into v_n;

  return v_n is not null;
end
$fn$;

revoke execute on function public.bump_rate_limit(text, int, text)
  from public, anon, authenticated;

comment on function public.bump_rate_limit(text, int, text) is
  'Kova + pencere anahtarı başına sayaç. `p_limit <= 0` GERÇEKTEN kapatıyor: '
  'ilk INSERT `on conflict` dalına girmediği için sınırı görmüyordu ve '
  'app_config''e 0 yazmak özelliği kapatmıyordu.';

-- ============================================ 4) ortak seri sunucuda da kapalı
-- `ff_pair_streak` yalnızca İSTEMCİ tarafında uygulanıyordu: `start_pair_streak`
-- ve `leave_pair_streak` bayraktan bağımsız `authenticated`'a açıktı,
-- `pair-streak-daily` cron'u bayrak kapalıyken de bütün serileri
-- ilerletiyordu ve `my_pair_streaks()` veri döndürmeye devam ediyordu.
--
-- Kapatma kararı "küçükler için varsayılan kapalı" (DSA Md. 28(1) Kılavuzu,
-- 14 Temmuz 2025, par. 57(b)(viii)) gerekçesiyle alınmışken eski bir istemci
-- sürümü ya da doğrudan RPC çağrısı seriyi başlatabiliyordu — ve kapalı
-- dönemde VERİ BİRİKMEYE devam ediyordu.
--
-- ASKI DA BURADA: `start_pair_streak` askıyı hiç sormuyordu. Yaptırım tasarımı
-- "kapanan tek şey ÜRETİM" diyor ve ortak seri yeni bir üretim/sosyal yüzey —
-- karşı tarafa görünen kalıcı bir satır yaratıyor.
create or replace function public.start_pair_streak(p_friend uuid)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_a   uuid;
  v_b   uuid;
  v_n   int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_friend is null or p_friend = v_uid then
    return false;
  end if;

  -- BAYRAK SUNUCUDA DA (0094). `ff_pair_streak` yalnızca İSTEMCİ tarafında
  -- uygulanıyordu: eski bir istemci sürümü ya da doğrudan RPC çağrısı seriyi
  -- başlatabiliyordu ve kapalı dönemde VERİ BİRİKMEYE devam ediyordu. Kapatma
  -- kararının gerekçesi DSA Md. 28(1) Kılavuzu — o gerekçe veri birikmesini de
  -- kapsıyor.
  if not public.config_bool('ff_pair_streak', false) then
    return false;
  end if;

  -- ASKI ÜRETİMİ DURDURUR (0062 kuralı). Ortak seri karşı tarafa GÖRÜNEN
  -- kalıcı bir satır yaratıyor, yani bir üretim yüzeyi; askıdaki kullanıcı
  -- aski öncesi çözülmüş gönderimlerle yeni seri başlatabiliyordu.
  if public.is_suspended(v_uid) then
    return false;
  end if;
  if not public.are_friends(v_uid, p_friend) then
    return false;
  end if;
  if public.is_blocked_between(v_uid, p_friend) then
    return false;
  end if;

  -- İKİ YÖNDE DE çözülmüş gönderim şartı.
  if not exists (
    select 1 from public.question_sends s
     where s.sender_id = v_uid and s.receiver_id = p_friend
       and s.solved_at is not null
  ) or not exists (
    select 1 from public.question_sends s
     where s.sender_id = p_friend and s.receiver_id = v_uid
       and s.solved_at is not null
  ) then
    return false;
  end if;

  v_a := least(v_uid, p_friend);
  v_b := greatest(v_uid, p_friend);

  if exists (select 1 from public.pair_streaks s
              where s.a_id = v_a and s.b_id = v_b) then
    return false;   -- zaten var
  end if;

  select count(*)::int into v_n
    from public.pair_streaks s
   where v_uid in (s.a_id, s.b_id);
  if v_n >= public.config_int('pair_streak_max', 3) then
    return false;
  end if;

  insert into public.pair_streaks (a_id, b_id, streak, best, last_day)
  values (v_a, v_b, 1, 1, public.istanbul_day())
  on conflict do nothing;
  return true;
end
$fn$;
revoke execute on function public.start_pair_streak(uuid) from public, anon;
grant  execute on function public.start_pair_streak(uuid) to authenticated;

-- ---------------------------------------------- devir de bayrağa bağlandı
create or replace function public.pair_streak_rollover()
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_yday date := public.istanbul_day() - 1;
begin
  -- BAYRAK KAPALIYKEN SERİLER İLERLEMİYOR (0094). Eskiden bu iş bayraktan
  -- BAĞIMSIZ koşuyordu: `ff_pair_streak` kapalıyken arayüz hiçbir şey
  -- çizmiyor ama veri birikmeye devam ediyordu. Kapatma kararının gerekçesi
  -- DSA Md. 28(1) Kılavuzu ve o gerekçe veri birikmesini de kapsıyor.
  if not public.config_bool('ff_pair_streak', false) then
    return;
  end if;

  -- İLERLET: ikisi de dün aktifti.
  update public.pair_streaks s
     set streak   = s.streak + 1,
         best     = greatest(s.best, s.streak + 1),
         last_day = v_yday
    from public.profiles pa, public.profiles pb
   where pa.id = s.a_id
     and pb.id = s.b_id
     and s.last_day is distinct from v_yday
     and pa.last_activity_date = v_yday
     and pb.last_activity_date = v_yday;

  -- SIFIRLA: en az biri dün çalışmadı ve seri hâlâ açık görünüyor.
  -- Tasarım kırılmayı sıfırlama olarak istiyor ("Ortak seriniz sıfırlandı");
  -- DİL suçlamıyor ve davetle bitiyor, ama SAYI sıfırlanıyor.
  update public.pair_streaks s
     set streak = 0
    from public.profiles pa, public.profiles pb
   where pa.id = s.a_id
     and pb.id = s.b_id
     and s.streak > 0
     and s.last_day is distinct from v_yday
     and (pa.last_activity_date is distinct from v_yday
          or pb.last_activity_date is distinct from v_yday);
end
$fn$;

revoke execute on function public.pair_streak_rollover()
  from public, anon, authenticated;
