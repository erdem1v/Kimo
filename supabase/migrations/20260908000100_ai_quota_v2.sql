-- 0075 — Kota rejimi v2: katmanlı KAYAN pencere + aylık cap (Task 10)
--
-- NE DEĞİŞİYOR VE NEDEN:
--
-- 0040 günde 5 sabit hak veriyordu: tek kova (`rate_limits` bucket `ai`),
-- pencere anahtarı Istanbul GÜNÜ, `daily_ai_quota()` gövdesi `select 5`.
-- Katman kavramı, aylık cap ve kayan pencere HİÇ YAZILMAMIŞTI
-- (bkz. docs/task-06-ai-maliyet-raporu.md: "Kayan pencere, aylık cap, katman
-- fonksiyonu ve rampa yazılmadı"). Ürün kararı netleşti:
--
--   katman    | 8 saatlik pencere | aylık cap
--   ----------|-------------------|-------------------
--   anonim    | —                 | TOPLAM 3 (ömür boyu)
--   ücretsiz  | 10                | 300
--   premium   | 50                | 1.000
--
-- NEDEN SAYAÇ DEĞİL DEFTER: `rate_limits(bucket, window_key, n)` SABİT KOVA
-- yapabilir, kayan pencere yapamaz. "Son 8 saatte kaç çağrı" sorusu tek tek
-- çağrı zamanlarını gerektiriyor; arayüzün göstereceği "sonraki hakkın
-- 14:30'da" değeri de zaten o zamanlardan türüyor. Bu yüzden `ai` kovası
-- append-only bir deftere (`ai_calls`) dönüyor. `rate_limits` KALIYOR:
-- `scan`, `friend_code`, `friend_code_rotate` ve yeni `ad_start` kovaları
-- ona bağlı.
--
-- YAZILMAYAN İKİ KOVA (task-06 planlamıştı, bilerek yazılmadı):
--   * `ai_month`       — defterden türetilebilir. İkinci bir sayaç tutmak
--                        0040'ın kendi yorumunda reddedilen "sayı iki yerde"
--                        hatasını geri getirirdi.
--   * `ai_window_hit`  — bu bir telemetri, bir sınır değil. REDDETME YOLUNA
--                        yazma koyardı; hiçbir maliyeti olmaması gereken tek
--                        yol orası. Bedeli açıkça: "duvara çarptıktan sonra
--                        kaç kez daha denedi" sinyalini kaybediyoruz.
--
-- RAKAMLAR `app_config`'TE: birim AI maliyeti HÂLÂ ÖLÇÜLMEDİ (task-06), yani
-- bu sayılar tahmin. Göç gerektirmeden gevşetilebilmeleri gerekiyor.
-- `signup_throttle` (0058) deseni: definer fonksiyon içinden okunuyor, anahtar
-- yoksa varsayılana düşülüyor.
--
-- ASİMETRİ, BİLİNÇLİ: **kota sayıları fail-open, kimlik doğrulama sırrı
-- fail-closed.** Yanlış yapılandırılmış bir ortam analizi kapatmasın; ama
-- `ad_reward_secret` (0076) yoksa ödül VERİLMEZ — orada açık kalmak bedava
-- hak basmak olurdu.

-- ====================================================== premium katmanı
-- Sunucu sahipli, istemciye kapalı (lockdown_v7'de `locked`).
--
-- `boolean` DEĞİL `timestamptz`: cron olmadan kendiliğinden süresi dolan tek
-- şekil. Bir `is_premium boolean` her gün bir işin onu sıfırlamasını
-- gerektirirdi ve o iş düşerse kullanıcı bedava premium kalırdı.
--
-- BU PAKETTE YAZAN HİÇBİR ŞEY YOK — bilinçli. Abonelik satın alma (IAP) ayrı
-- bir task ve bu sütunu o dolduracak. `upsert_my_profile` (0055) yalnızca
-- `nickname`/`mascot` yazıyor, yani istemcinin bu sütuna hiçbir yolu yok.
-- İç testte elle SQL ile set ediliyor.
alter table public.profiles
  add column if not exists premium_until timestamptz;

comment on column public.profiles.premium_until is
  'Premium aboneliğin bitiş anı. Sunucu sahipli; istemci YAZAMAZ (lockdown). '
  'null ya da geçmiş = ücretsiz katman. IAP task''ı dolduracak; bu sürümde '
  'yazan bir yol YOK, yalnızca elle SQL.';

-- ====================================================== yapılandırma okuma
-- Tam sayı app_config anahtarı, fail-open.
--
-- HERKESTEN REVOKE: yalnızca diğer definer fonksiyonlar çağırıyor ve onlar
-- tanımlayıcı yetkisiyle çalıştığı için EXECUTE'a ihtiyaç duymuyorlar
-- (`bump_rate_limit` ve `apply_progress` ile aynı durum). Görünümün SELECT
-- listesinde GEÇMEDİĞİ için `authenticated`'a açılması gerekmiyor — 0040'ın
-- 121-125. satırlarındaki uyarı yalnızca görünümde doğrudan çağrılan
-- fonksiyonlar için geçerli.
create or replace function public.config_int(p_key text, p_default int)
returns int language sql stable security definer set search_path = public
as $fn$
  select coalesce(
    (select case when value ~ '^[0-9]+$' then value::int end
       from public.app_config where key = p_key),
    p_default);
$fn$;

revoke execute on function public.config_int(text, int)
  from public, anon, authenticated;

comment on function public.config_int(text, int) is
  'app_config''ten tam sayı okur; anahtar yok ya da sayı değilse varsayılan '
  '(fail-open). Yalnızca definer fonksiyonlar çağırır.';

-- Varsayılanları tohumla. `do nothing`: üretimde elle girilmiş bir değer
-- varsa göç onu EZMEMELİ.
insert into public.app_config (key, value) values
  ('ai_window_hours',   '8'),
  ('ai_window_free',    '10'),
  ('ai_window_premium', '50'),
  ('ai_month_free',     '300'),
  ('ai_month_premium',  '1000'),
  ('ai_lifetime_anon',  '3'),
  ('ai_low_threshold',  '2'),
  ('ad_reward_daily',   '3'),
  ('ad_pending_ttl_min','5')
on conflict (key) do nothing;

-- ====================================================== katman
-- SIFIR ARGÜMANLI, bilinçli. `user_tier(p_user uuid)` olsaydı herhangi bir
-- kullanıcı başkasının abonelik durumunu yoklayabilirdi; Task 01'in "hiçbir
-- RPC `user_id` parametresi almaz" değişmezi bunu kapatıyor.
--
-- Ayrıca `authenticated`'a KAPALI: istemci katmanı `my_daily_state.ai_tier`
-- sütunundan okuyor, ikinci bir yüzeye gerek yok.
create or replace function public.user_tier()
returns text language sql stable security definer set search_path = public
as $fn$
  select case
           when p.is_anonymous then 'anonymous'
           when p.premium_until is not null and p.premium_until > now()
             then 'premium'
           else 'free'
         end
    from public.profiles p
   where p.id = auth.uid();
$fn$;

revoke execute on function public.user_tier()
  from public, anon, authenticated;

comment on function public.user_tier() is
  'Oturumdaki kullanıcının katmanı: anonymous | free | premium. Sıfır '
  'argümanlı (başkasının katmanı sorulamaz). Yalnızca definer fonksiyonlar.';

-- Ayın yenilenme anı (Istanbul takvimi).
create or replace function public.istanbul_month_reset()
returns timestamptz language sql stable set search_path = public
as $fn$
  select (date_trunc('month', now() at time zone 'Europe/Istanbul')
          + interval '1 month') at time zone 'Europe/Istanbul';
$fn$;

revoke execute on function public.istanbul_month_reset()
  from public, anon, authenticated;

-- ====================================================== çağrı defteri
-- Her AI analizi bir satır. Kayan pencere, aylık cap ve kalibrasyon
-- sinyallerinin TEK kaynağı.
--
-- `bigint identity`, uuid DEĞİL: tablo sunucu-içi, istemciden hiç
-- referanslanmıyor ve şemanın en büyüğü olacak (kullanıcı başına 300/ay).
-- 8 bayt yerine 16 bayt hem yığında hem indekste gereksiz. Deponun uuid
-- alışkanlığından bilinçli sapma.
--
-- `(user_id, at)` TEK GEREKEN kota indeksi: 8 saatlik pencere sayımı,
-- `next_at` için k'ıncı-en-eski araması ve ay sayımı üçü de aynı önekte
-- aralık taraması. Aya özel bir indeks EKLENMEMELİ.
create table if not exists public.ai_calls (
  id           bigint generated always as identity primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  at           timestamptz not null default now(),
  tier         text not null,
  photo_sha256 bytea,
  from_reward  boolean not null default false
);

create index if not exists ai_calls_user_at_idx on public.ai_calls (user_id, at);
create index if not exists ai_calls_at_idx      on public.ai_calls (at);

alter table public.ai_calls enable row level security;
-- Politika YOK = yalnızca definer fonksiyonlar erişir. Defterin kendisi
-- kullanıcıya bile okunabilir olmamalı; sayılar `my_daily_state`'ten geliyor.
revoke all on public.ai_calls from public, anon, authenticated;

comment on table public.ai_calls is
  'AI analiz çağrı defteri. Kayan pencere, aylık cap ve anonim ömür cap''inin '
  'tek kaynağı; aynı zamanda maliyet defteri (task-06). Yalnızca sunucu. '
  '92 günde bir budanır (prune_ai_calls) — ANONİM satırlar budanmaz.';

comment on column public.ai_calls.tier is
  'Çağrı ANINDAKİ katman. Kalibrasyon için: bir kullanıcı ay içinde katman '
  'değiştirebilir ve geçmiş çağrılar eski katmanda yapılmıştır.';

comment on column public.ai_calls.from_reward is
  'Bu çağrı reklam ödülüyle mi açıldı. Ödüllü reklamın gerçekten kullanılıp '
  'kullanılmadığını ölçmek için.';

-- ====================================================== reklam ödülü tablosu
-- BU TABLO 0076'DA DEĞİL BURADA, bilerek: aşağıdaki `ai_state()` onu okuyor
-- ve `language sql`/`plpgsql` gövdeleri yaratma anında çözümleniyor. Tablo
-- sonraki göçte olsaydı bu göç "relation does not exist" ile patlardı.
-- Fonksiyonları 0076 yazıyor.
create table if not exists public.ad_rewards (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  nonce          uuid not null unique,
  status         text not null default 'pending'
                 check (status in ('pending', 'granted')),
  transaction_id text,
  created_at     timestamptz not null default now(),
  granted_at     timestamptz,
  consumed_at    timestamptz
);

-- KAPSAM KISITI KATALOGDA, fonksiyon mantığında değil: kullanıcı başına en
-- fazla BİR canlı bekleyen satır. Böylece terk edilmiş reklamlar tabloyu
-- büyütemiyor ve bir betik sınırsız pending üretemiyor.
create unique index if not exists ad_rewards_one_pending
  on public.ad_rewards (user_id) where status = 'pending';

-- TEKRAR OYNATMA (replay) da katalogda kapanıyor: AdMob aynı geri çağrıyı
-- yeniden denerse ikinci bir hak üretilemez.
create unique index if not exists ad_rewards_txn_uniq
  on public.ad_rewards (transaction_id) where transaction_id is not null;

create index if not exists ad_rewards_granted_idx
  on public.ad_rewards (user_id, granted_at) where status = 'granted';

alter table public.ad_rewards enable row level security;
revoke all on public.ad_rewards from public, anon, authenticated;

comment on table public.ad_rewards is
  'Ödüllü reklam ödülleri. `nonce` sunucunun ürettiği tahmin edilemez '
  'belirteç; istemci AdMob''a `customData` olarak veriyor ve ödül ancak '
  'Google''ın imzalı sunucu geri çağrısıyla `granted` oluyor. İki durum '
  'yeter: "expired" bir durum değil, silme. Yalnızca sunucu.';

-- ====================================================== TEK ARİTMETİK
-- Hem `consume_ai_use()` hem `my_daily_state` buradan okuyor. Sayı iki yerde
-- hesaplansaydı arayüz "2 hakkın kaldı" derken sunucu reddedebilirdi —
-- 0040'ın kendi gerekçesi.
--
-- ÇIKTI ADLARI `ai_`/`ad_` ÖNEKLİ, bilinçli: plpgsql'de `returns table`
-- çıktı adları gövdede DEĞİŞKEN olur. Düz `tier`/`state` adları
-- `ai_calls.tier` ile çakışır ve her başvuruyu nitelemek ya da
-- `#variable_conflict` yazmak gerekirdi. Önek o sınıf hatayı tümden siliyor.
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

-- Görünümün SELECT listesinde DOĞRUDAN çağrılıyor, o yüzden `authenticated`
-- EXECUTE'u ZORUNLU: `security_invoker = false` görünümlerde tablo erişimi
-- görünüm sahibinin yetkisiyle denetlenir ama FONKSİYON çağrısının EXECUTE'u
-- ÇAĞIRANA karşı denetlenir. Kapatılırsa görünüm her kullanıcıda 42501 atar
-- (0040'ın 121-125. satırlarındaki ders).
--
-- Sıfır argümanlı ve `auth.uid()` okuyor: doğrudan çağrılsa bile yalnızca
-- çağıranın durumunu söyler, başkasının kotasını sızdırmaz.
revoke execute on function public.ai_state() from public, anon;
grant  execute on function public.ai_state() to authenticated;

comment on function public.ai_state() is
  'Oturumdaki kullanıcının analiz hakkı durumu. Kotanın TEK aritmetiği; '
  'consume_ai_use ve my_daily_state ikisi de buradan okur.';

-- ====================================================== tüketim
-- Görünüm `daily_ai_quota()` ve `istanbul_day_reset()`e bağımlı; ikisini
-- düşürebilmek için görünüm ÖNCE gidiyor. `consume_ai_use` dönüş tipi
-- değiştiği için `create or replace` mümkün değil.
drop view if exists public.my_daily_state;
drop function if exists public.consume_ai_use();

-- Bir analiz hakkı harcar. Hak yoksa HATA ATMAZ: `allowed = false` döner.
-- 0040'ın gerekçesi aynen geçerli — hak bitmesi bir hata değil, beklenen bir
-- ürün durumu.
--
-- `allowed` ilk sütun ve `remaining` adı KORUNDU: `analyze-question`'ın
-- mevcut `row?.allowed === true` / `Number(row?.remaining ?? 0)` okumaları
-- çalışmaya devam ediyor. `remaining` BAĞLAYICI sayı (pencere ile ay
-- kalanının küçüğü) — istemci hangi sınırın bağladığını hesaplamıyor.
--
-- `resets_at` GİTTİ: günlük anahtar kalktığı için "yarın yenilenir"
-- anlamsızlaştı. Yerine `ai_next_at` (ne zaman tekrar çağırabilirim) +
-- `ai_month_resets_at`, ve `ai_state` nedenini söylüyor.
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
  ad_offer           boolean
)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_s      record;
  v_reward uuid;
  v_sha    bytea;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  -- YARIŞ KOŞULU: 0040'ın tek ifadelik `on conflict … where` idiomu sayaçta
  -- yarışsızdı ÇÜNKÜ çakışan satırı INSERT kilitliyordu. Defterde öyle bir
  -- satır yok: "pencerede say, sonra ekle" bir hayalet okuma ve READ
  -- COMMITTED'da iki eşzamanlı işlem de `sınır-1` görüp ikisi de commit eder.
  --
  -- İŞLEM ÖMÜRLÜ (`_xact_`) OLMAK ZORUNDA: oturum ömürlü `pg_advisory_lock`
  -- Supavisor'ın işlem kipinde havuzlanmış bağlantılar arasında sızar ve
  -- havuzu kilitler. İki anahtarlı biçimdeki ad alanı `hashtext`in int4
  -- çarpışmalarını bu özelliğin içinde tutuyor; iki ilgisiz kullanıcının
  -- çarpışması yalnızca birkaç ms sıralama demek.
  --
  -- TEK kilit alınıyor → kilitlenme sıralaması sorunu yok. `grant_ad_reward`
  -- (0076) AYNI kilidi alıyor, yani ödül verme ile tüketim araya girmiyor.
  -- Kilit RPC commit'inde bırakılıyor; OpenAI çağrısı bundan SONRA, yani
  -- kilit ağ beklerken tutulmuyor.
  --
  -- REDDEDİLEN İYİMSER YOL (doğru GÖRÜNÜYOR, değil): "ekle, say, fazlaysa
  -- geri al". Eşzamanlı ve commit edilmemiş bir ekleme sayımda GÖRÜNMEZ,
  -- yani iki işlem de kendini sınır içinde sanıp ikisi de geçer.
  -- `profiles … for update` ise `apply_progress`/`submit_*` ile çekişir ve
  -- gerçek bir kilitlenme sıralaması tehlikesi açar.
  perform pg_advisory_xact_lock(hashtext('ai_quota'), hashtext(v_uid::text));

  select * into v_s from public.ai_state();

  if v_s is null or v_s.ai_left <= 0 then
    return query
      select false, coalesce(v_s.ai_state, 'window_full'), v_s.ai_tier,
             0, coalesce(v_s.ai_window_left, 0), v_s.ai_window_limit,
             coalesce(v_s.ai_month_left, 0), v_s.ai_month_limit,
             v_s.ai_next_at, v_s.ai_next_at_hm,
             v_s.ai_month_resets_at, v_s.ai_month_resets_on,
             coalesce(v_s.ad_rewards_left, 0),
             coalesce(v_s.ad_offer, false);
    return;
  end if;

  -- Pencere taban sınırı dolmuşsa hak bugünün harcanmamış ödülünden geliyor;
  -- o ödülü ŞİMDİ işaretliyoruz. En eskisi önce: kullanıcı kazandığı sırayla
  -- harcıyor ve gece yarısı kaybolacak olan ilk gidiyor.
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

  -- Fotoğraf özeti ZORUNLU DEĞİL ve geçersizse sessizce düşüyor: burası
  -- maliyet yolu, bir kalibrasyon sinyali için analizi reddetmek yanlış olur.
  if p_sha_hex is not null and p_sha_hex ~ '^[0-9a-f]{64}$' then
    v_sha := decode(p_sha_hex, 'hex');
  end if;

  insert into public.ai_calls (user_id, tier, photo_sha256, from_reward)
  values (v_uid, v_s.ai_tier, v_sha, v_reward is not null);

  -- EKLEMEDEN SONRA yeniden okuyoruz ki dönen sayılar harcama SONRASI olsun.
  -- READ COMMITTED'da plpgsql gövdesindeki her ifade yeni bir anlık görüntü
  -- alıyor, yani az önce eklenen satır `stable` bir çağrıya görünür.
  select * into v_s from public.ai_state();

  return query
    select true, v_s.ai_state, v_s.ai_tier,
           v_s.ai_left, v_s.ai_window_left, v_s.ai_window_limit,
           v_s.ai_month_left, v_s.ai_month_limit,
           v_s.ai_next_at, v_s.ai_next_at_hm,
           v_s.ai_month_resets_at, v_s.ai_month_resets_on,
           v_s.ad_rewards_left, v_s.ad_offer;
end
$fn$;

revoke execute on function public.consume_ai_use(text) from public, anon;
grant  execute on function public.consume_ai_use(text) to authenticated;

comment on function public.consume_ai_use(text) is
  'Bir AI analiz hakkı harcar. Hak yoksa istisna ATMAZ, allowed=false döner. '
  'Kayan pencere + aylık cap + anonim ömür cap''i; reklam ödülü pencereyi '
  'açar, aylık cap''i AÇMAZ.';

-- ====================================================== günlük durum v3
-- Sütunlar eklendiği/çıkarıldığı için DROP + CREATE (yukarıda düşürüldü).
--
-- `ai_quota` ve `ai_resets_at` KALDIRILDI, takma ad verilmedi: gerçek
-- kullanıcı yok (dört kişilik iç test), geriye dönük uyumluluk gerekmiyor.
-- İstemci ve bu göç BİRLİKTE dağıtılmak zorunda.
--
-- Üç alt sorgu (reviewed_today_count / due_count / unsolved_received_count)
-- 0049'dan BİREBİR kopyalandı. Bu paketteki en olası regresyon onları
-- yeniden yazarken `due_count`un süzgecini sessizce değiştirmek olurdu.
--
-- Tek `lateral` ile `ai_state()`: görünümün SELECT listesinde yalnızca iki
-- fonksiyon var (`istanbul_day`, `ai_state`), yani `authenticated`'a yalnızca
-- o ikisi için EXECUTE vermek yetiyor. Kotanın geri kalan altı fonksiyonu
-- `ai_state()`in içinde definer olarak çalışıyor.
create view public.my_daily_state
with (security_invoker = false) as
select
  p.id                                              as user_id,
  p.gems,
  p.xp,
  case when p.last_activity_date >= public.istanbul_day() - 1
       then p.streak else 0 end                     as streak,
  case when p.week_start = (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date
       then p.weekly_xp else 0 end                  as weekly_xp,
  p.league,
  p.last_activity_date,
  p.premium_until,
  public.istanbul_day()                             as today,
  (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date
                                                    as week_start,
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
  s.plus_month_limit
from public.profiles p, public.ai_state() s
where p.id = auth.uid();

revoke all on public.my_daily_state from public, anon;
grant select on public.my_daily_state to authenticated;

comment on view public.my_daily_state is
  'Kullanıcının günlük durumu (yalnızca kendi satırı). Analiz hakkının TÜM '
  'gösterim değerleri burada: durum, kalan, sonraki hakkın saati, ayın '
  'yenilenme günü, reklam hakkı. İstemci hiçbir şey hesaplamıyor.';

-- ====================================================== ölü fonksiyonlar
-- `daily_ai_quota()`: gövdesi `select 5` olan günlük sabit kota. Günlük
-- anahtar kavramı kalktı. `istanbul_day_reset()`: "yarın yenilenir" anı.
-- İkisinin de tek çağıranı eski görünüm ve eski `consume_ai_use`; testlerde,
-- edge fonksiyonlarında ve mutasyonlarda HİÇ geçmiyorlar (grep ile
-- doğrulandı). 0078 ikisinin geri gelmediğini de sınıyor.
--
-- `istanbul_day()` KALIYOR: görünümün `today`/`reviewed_today_count`/
-- `due_count` sütunları ve `consume_scan_use` ona bağlı.
drop function if exists public.daily_ai_quota();
drop function if exists public.istanbul_day_reset();

-- ====================================================== budama
-- 92 gün = içinde bulunulan ay + iki ay; task-06'nın kalibrasyon sinyalleri
-- için yeterli.
--
-- `not is_anonymous` YÜKLEMİ TAŞIYICI: anonim cap'i ÖMÜR BOYU, yani budanan
-- bir satır 3 taze hak demek olurdu. `cleanup-anonymous` o hesapları 7 günde
-- siliyor ama bu yüklem ömür cap'ini o işin sağlığına BAĞLAMIYOR.
create or replace function public.prune_ai_calls()
returns void language sql security definer set search_path = public
as $fn$
  delete from public.ai_calls c
   where c.at < now() - interval '92 days'
     and exists (select 1 from public.profiles p
                  where p.id = c.user_id and not p.is_anonymous);
$fn$;

revoke execute on function public.prune_ai_calls()
  from public, anon, authenticated;

comment on function public.prune_ai_calls() is
  '92 günden eski çağrı defteri satırlarını siler. ANONİM kullanıcıların '
  'satırları budanmaz: onların cap''i ömür boyu.';
