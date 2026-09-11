-- test: supabase/tests/100_ai_quota.sql
--
-- MUTASYON: kayan pencere `app_config`'teki uzunluğu yok sayıp 24 saat sayıyor.
-- BEKLENEN: 100'ün "9 saat önceki çağrı PENCEREDE sayılmıyor" iddiası kırmızı.
--
-- BU MUTASYON NİYE DEĞERLİ: sayıya dayalı bütün iddiaları GEÇİYOR — tüketim
-- yine sınırda duruyor, `allowed=false` yine dönüyor, `ai_state` yine
-- `window_full` oluyor. Yalnızca YAŞLANMA iddiası düşüyor. Yani "doğru
-- görünüyor ama değil" sınıfından bir hatayı yakalıyor; o sınıf bu depoda
-- `27_age_gate_drops_suspension.sql` ile bir kez yaşandı.
--
-- SABİT KOVA (ör. `c.at >= istanbul_day()`) yerine 24 saat seçildi, BİLEREK:
-- sabit kova mutasyonu GÜNÜN SAATİNE bağlı olurdu — süit sabah 09:00'dan önce
-- koşarsa 9 saat önceki satır sabit kovada da dışarıda kalır, mutasyon
-- yakalanmaz ve `mutation_check.sh` "FAZ 2: HÂLÂ YEŞİL" diye kırmızıya döner.
-- 24 saat her saatte aynı sonucu veriyor.
--
-- NOT: iki gövde de göç dosyasından ÜRETİLDİ, elle kopyalanmadı.
create or replace function public.ai_state()
returns table (
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
  v_low       int;
  v_used      int;
  v_month     int;
  v_reward    int  := 0;
  v_effective int;
  v_ad_daily  int;
  v_suspended boolean;
begin
  -- Oturum yoksa SATIR DÖNMÜYOR. Görünüm bununla birlikte boş kalıyor ve
  -- istemci "okunamadı" dalına düşüyor — sıfır göstermekten farklı.
  if v_uid is null then
    return;
  end if;

  ai_tier := public.user_tier();
  if ai_tier is null then
    return;                       -- profil satırı yok (yarı kurulmuş hesap)
  end if;

  v_hours           := public.config_int('ai_window_hours', 8);
  v_low             := public.config_int('ai_low_threshold', 2);
  v_ad_daily        := public.config_int('ad_reward_daily', 3);
  v_suspended       := public.is_suspended(v_uid);
  ai_window_hours   := v_hours;
  plus_window_limit := public.config_int('ai_window_premium', 50);
  plus_month_limit  := public.config_int('ai_month_premium', 1000);

  ai_month_resets_at := public.istanbul_month_reset();
  ai_month_resets_on := (ai_month_resets_at at time zone 'Europe/Istanbul')::date;

  if ai_tier = 'anonymous' then
    -- ÖMÜR BOYU cap: pencere ve ay kavramı yok. Denemenin tamamı 3 analiz.
    ai_window_limit := public.config_int('ai_lifetime_anon', 3);
    ai_month_limit  := ai_window_limit;
    select count(*)::int into v_used
      from public.ai_calls c where c.user_id = v_uid;
    ai_window_left := greatest(ai_window_limit - v_used, 0);
    ai_month_left  := ai_window_left;
    ai_left        := ai_window_left;
    -- Gösterilecek bir saat YOK: hak geri gelmiyor, yol hesap açmaktan
    -- geçiyor. Pencere saati göstermek yanıltıcı olurdu.
    ai_next_at      := null;
    ai_next_at_hm   := null;
    ad_rewards_left := 0;         -- anonim reklam izleyemez (aşağıdaki not)
  else
    ai_window_limit := public.config_int(
      case when ai_tier = 'premium' then 'ai_window_premium'
           else 'ai_window_free' end,
      case when ai_tier = 'premium' then 50 else 10 end);
    ai_month_limit := public.config_int(
      case when ai_tier = 'premium' then 'ai_month_premium'
           else 'ai_month_free' end,
      case when ai_tier = 'premium' then 1000 else 300 end);

    -- KAYAN pencere: sabit kova değil.
    -- MUTASYON: pencere yapılandırmayı yok sayıyor ve 24 saat sayıyor.
    select count(*)::int into v_used
      from public.ai_calls c
     where c.user_id = v_uid
       and c.at > now() - interval '24 hours';

    -- Istanbul TAKVİM ayı.
    select count(*)::int into v_month
      from public.ai_calls c
     where c.user_id = v_uid
       and c.at >= date_trunc('month', now() at time zone 'Europe/Istanbul')
                   at time zone 'Europe/Istanbul';

    -- BUGÜN kazanılmış ve henüz harcanmamış reklam hakkı.
    --
    -- NEDEN "BUGÜN" VE PENCERE-GÖRELİ DEĞİL: pencereye göreli bir ödül
    -- (verildiği andan 8 saat sonra buharlaşan) kullanıcı ekrana bakarken
    -- sayının KENDİ KENDİNE düşmesine yol açardı. Tüm önermesi "sunucu
    -- hesaplıyor, sayı güvenilir" olan bir ekran için en kötü özellik.
    -- Istanbul günü, 3/gün tavanının zaten kullandığı saat — yeni bir zaman
    -- ekseni girmiyor ve ödül günler arası biriktirilemiyor.
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

    -- SONRAKİ HAKKIN ANI — `min(at) + 8sa` DEĞİL.
    --
    -- O formül yalnızca `kullanılan == etkin sınır` tam tutuyorsa doğru.
    -- Genel biçim pencerenin k'ıncı en eski çağrısı (k = kullanılan − etkin + 1).
    -- Yapılandırma sınırı daralttığında ve harcanmamış bir ödül gece yarısı
    -- süresi dolup etkin sınır düştüğünde de doğru kalıyor; naif `min()`
    -- ikisinde de SESSİZCE eksik bildirir.
    select c.at + make_interval(hours => v_hours) into ai_next_at
      from public.ai_calls c
     where c.user_id = v_uid
       and c.at > now() - make_interval(hours => v_hours)
     order by c.at
    offset greatest(v_used - v_effective, 0)
       limit 1;

    -- Duvar saati SUNUCUDA biçimlendiriliyor: cihaz saatini değiştiren bir
    -- öğrenciye yanlış saat gösterilmesin. Ay ADI burada üretilmiyor —
    -- Postgres'in `TM` ay adları `lc_time`'a bağlı ve Supabase'de `tr_TR`
    -- olduğu varsayılamaz; istemci ay adını kendi tablosundan koyuyor.
    ai_next_at_hm := to_char(ai_next_at at time zone 'Europe/Istanbul',
                             'HH24:MI');

    if ai_tier = 'premium' then
      ad_rewards_left := 0;       -- premium reklam görmemek için ödedi
    else
      ad_rewards_left := greatest(
        v_ad_daily - (
          select count(*)::int from public.ad_rewards r
           where r.user_id = v_uid
             and r.status = 'granted'
             and (r.granted_at at time zone 'Europe/Istanbul')::date
                 = public.istanbul_day()
        ), 0);
    end if;
  end if;

  ad_rewards_per_day := v_ad_daily;

  -- DURUM SIRASI ÖNEMLİ: ay pencereyi yeniyor.
  -- İkisi de doluysa reklam yolu GİZLENMELİ ve gizleyen şey `ai_state`;
  -- "pencere doldu" deyip saat göstermek, o saatte bir şey olacağını vaat
  -- etmek olurdu — aylık cap kapalıyken olmayacak.
  ai_state := case
    when v_suspended                       then 'suspended'
    when ai_tier = 'anonymous'
     and ai_left <= 0                      then 'lifetime_full'
    when ai_month_left <= 0                then 'month_full'
    when ai_window_left <= 0               then 'window_full'
    when ai_left <= v_low                  then 'low'
    else                                        'ok'
  end;

  -- Aylık sınır dolduğunda pencere saati GÖSTERİLMEZ (ürün kuralı). Kararı
  -- burada veriyoruz ki istemci bir şey seçmek zorunda kalmasın.
  if ai_state in ('month_full', 'lifetime_full', 'suspended') then
    ai_next_at    := null;
    ai_next_at_hm := null;
  end if;

  -- REKLAM GÖRÜNÜRLÜĞÜ SUNUCUNUN.
  --   * `ai_window_left <= 0` — elinde 7 hak olan kullanıcıya reklam
  --     göstermek reklam hasadı olurdu, duvara kapı açmak değil.
  --   * `ai_month_left > 0`   — kullanılamayacak bir ödül için reklam
  --     göstermek kullanıcıya düşmanca ve ödüllü reklam politikası açısından
  --     riskli. İKİ KATMAN: `start_ad_reward` da reddediyor (0076).
  --   * `ai_tier = 'free'`    — premium reklam görmemek için ödedi; anonim
  --     bir para kazanma yüzeyi değil, oradaki adım kayıt. Anonim oturum
  --     bedava açıldığı için reklam hakkı vermek sıfırlama yolu olurdu.
  ad_offer := ai_tier = 'free'
          and not v_suspended
          and ad_rewards_left > 0
          and ai_month_left > 0
          and ai_window_left <= 0;

  return next;
end
$fn$;
-- @UNDO
create or replace function public.ai_state()
returns table (
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
  v_low       int;
  v_used      int;
  v_month     int;
  v_reward    int  := 0;
  v_effective int;
  v_ad_daily  int;
  v_suspended boolean;
begin
  -- Oturum yoksa SATIR DÖNMÜYOR. Görünüm bununla birlikte boş kalıyor ve
  -- istemci "okunamadı" dalına düşüyor — sıfır göstermekten farklı.
  if v_uid is null then
    return;
  end if;

  ai_tier := public.user_tier();
  if ai_tier is null then
    return;                       -- profil satırı yok (yarı kurulmuş hesap)
  end if;

  v_hours           := public.config_int('ai_window_hours', 8);
  v_low             := public.config_int('ai_low_threshold', 2);
  v_ad_daily        := public.config_int('ad_reward_daily', 3);
  v_suspended       := public.is_suspended(v_uid);
  ai_window_hours   := v_hours;
  plus_window_limit := public.config_int('ai_window_premium', 50);
  plus_month_limit  := public.config_int('ai_month_premium', 1000);

  ai_month_resets_at := public.istanbul_month_reset();
  ai_month_resets_on := (ai_month_resets_at at time zone 'Europe/Istanbul')::date;

  if ai_tier = 'anonymous' then
    -- ÖMÜR BOYU cap: pencere ve ay kavramı yok. Denemenin tamamı 3 analiz.
    ai_window_limit := public.config_int('ai_lifetime_anon', 3);
    ai_month_limit  := ai_window_limit;
    select count(*)::int into v_used
      from public.ai_calls c where c.user_id = v_uid;
    ai_window_left := greatest(ai_window_limit - v_used, 0);
    ai_month_left  := ai_window_left;
    ai_left        := ai_window_left;
    -- Gösterilecek bir saat YOK: hak geri gelmiyor, yol hesap açmaktan
    -- geçiyor. Pencere saati göstermek yanıltıcı olurdu.
    ai_next_at      := null;
    ai_next_at_hm   := null;
    ad_rewards_left := 0;         -- anonim reklam izleyemez (aşağıdaki not)
  else
    ai_window_limit := public.config_int(
      case when ai_tier = 'premium' then 'ai_window_premium'
           else 'ai_window_free' end,
      case when ai_tier = 'premium' then 50 else 10 end);
    ai_month_limit := public.config_int(
      case when ai_tier = 'premium' then 'ai_month_premium'
           else 'ai_month_free' end,
      case when ai_tier = 'premium' then 1000 else 300 end);

    -- KAYAN pencere: sabit kova değil.
    select count(*)::int into v_used
      from public.ai_calls c
     where c.user_id = v_uid
       and c.at > now() - make_interval(hours => v_hours);

    -- Istanbul TAKVİM ayı.
    select count(*)::int into v_month
      from public.ai_calls c
     where c.user_id = v_uid
       and c.at >= date_trunc('month', now() at time zone 'Europe/Istanbul')
                   at time zone 'Europe/Istanbul';

    -- BUGÜN kazanılmış ve henüz harcanmamış reklam hakkı.
    --
    -- NEDEN "BUGÜN" VE PENCERE-GÖRELİ DEĞİL: pencereye göreli bir ödül
    -- (verildiği andan 8 saat sonra buharlaşan) kullanıcı ekrana bakarken
    -- sayının KENDİ KENDİNE düşmesine yol açardı. Tüm önermesi "sunucu
    -- hesaplıyor, sayı güvenilir" olan bir ekran için en kötü özellik.
    -- Istanbul günü, 3/gün tavanının zaten kullandığı saat — yeni bir zaman
    -- ekseni girmiyor ve ödül günler arası biriktirilemiyor.
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

    -- SONRAKİ HAKKIN ANI — `min(at) + 8sa` DEĞİL.
    --
    -- O formül yalnızca `kullanılan == etkin sınır` tam tutuyorsa doğru.
    -- Genel biçim pencerenin k'ıncı en eski çağrısı (k = kullanılan − etkin + 1).
    -- Yapılandırma sınırı daralttığında ve harcanmamış bir ödül gece yarısı
    -- süresi dolup etkin sınır düştüğünde de doğru kalıyor; naif `min()`
    -- ikisinde de SESSİZCE eksik bildirir.
    select c.at + make_interval(hours => v_hours) into ai_next_at
      from public.ai_calls c
     where c.user_id = v_uid
       and c.at > now() - make_interval(hours => v_hours)
     order by c.at
    offset greatest(v_used - v_effective, 0)
       limit 1;

    -- Duvar saati SUNUCUDA biçimlendiriliyor: cihaz saatini değiştiren bir
    -- öğrenciye yanlış saat gösterilmesin. Ay ADI burada üretilmiyor —
    -- Postgres'in `TM` ay adları `lc_time`'a bağlı ve Supabase'de `tr_TR`
    -- olduğu varsayılamaz; istemci ay adını kendi tablosundan koyuyor.
    ai_next_at_hm := to_char(ai_next_at at time zone 'Europe/Istanbul',
                             'HH24:MI');

    if ai_tier = 'premium' then
      ad_rewards_left := 0;       -- premium reklam görmemek için ödedi
    else
      ad_rewards_left := greatest(
        v_ad_daily - (
          select count(*)::int from public.ad_rewards r
           where r.user_id = v_uid
             and r.status = 'granted'
             and (r.granted_at at time zone 'Europe/Istanbul')::date
                 = public.istanbul_day()
        ), 0);
    end if;
  end if;

  ad_rewards_per_day := v_ad_daily;

  -- DURUM SIRASI ÖNEMLİ: ay pencereyi yeniyor.
  -- İkisi de doluysa reklam yolu GİZLENMELİ ve gizleyen şey `ai_state`;
  -- "pencere doldu" deyip saat göstermek, o saatte bir şey olacağını vaat
  -- etmek olurdu — aylık cap kapalıyken olmayacak.
  ai_state := case
    when v_suspended                       then 'suspended'
    when ai_tier = 'anonymous'
     and ai_left <= 0                      then 'lifetime_full'
    when ai_month_left <= 0                then 'month_full'
    when ai_window_left <= 0               then 'window_full'
    when ai_left <= v_low                  then 'low'
    else                                        'ok'
  end;

  -- Aylık sınır dolduğunda pencere saati GÖSTERİLMEZ (ürün kuralı). Kararı
  -- burada veriyoruz ki istemci bir şey seçmek zorunda kalmasın.
  if ai_state in ('month_full', 'lifetime_full', 'suspended') then
    ai_next_at    := null;
    ai_next_at_hm := null;
  end if;

  -- REKLAM GÖRÜNÜRLÜĞÜ SUNUCUNUN.
  --   * `ai_window_left <= 0` — elinde 7 hak olan kullanıcıya reklam
  --     göstermek reklam hasadı olurdu, duvara kapı açmak değil.
  --   * `ai_month_left > 0`   — kullanılamayacak bir ödül için reklam
  --     göstermek kullanıcıya düşmanca ve ödüllü reklam politikası açısından
  --     riskli. İKİ KATMAN: `start_ad_reward` da reddediyor (0076).
  --   * `ai_tier = 'free'`    — premium reklam görmemek için ödedi; anonim
  --     bir para kazanma yüzeyi değil, oradaki adım kayıt. Anonim oturum
  --     bedava açıldığı için reklam hakkı vermek sıfırlama yolu olurdu.
  ad_offer := ai_tier = 'free'
          and not v_suspended
          and ad_rewards_left > 0
          and ai_month_left > 0
          and ai_window_left <= 0;

  return next;
end
$fn$;
