-- 0083 — Hak iadesi: okunamayan fotoğraf hak harcamıyor (Task 12 · P5)
--
-- ÜRÜN KURALI (Tur 7 · n4, aynen): "Hak sayımı YALNIZCA OKUNABİLEN fotoğraflar
-- için düşer."
--
-- BUGÜNKÜ DAVRANIŞ BUNU İHLAL EDİYOR. `consume_ai_use()` OpenAI çağrısından
-- ÖNCE koşuyor ve `ai_calls`a satır yazıyor; iade eden hiçbir yol YOK. Yani:
--   * model fotoğrafı okuyamadı → hak gitti,
--   * OpenAI 5xx döndü → hak gitti,
--   * yanıt ayrıştırılamadı → hak gitti.
-- Tek fotoğrafta bu kozmetik bir kusurdu. 10'luk partide "10 hak verip 6 sonuç
-- almak" demek ve tasarım tam bunu yasaklıyor.
--
-- NEDEN SİLME DEĞİL İŞARETLEME: `ai_calls` aynı zamanda MALİYET DEFTERİ
-- (task-06). OpenAI çağrısı gerçekten yapıldı ve gerçekten para harcandı;
-- satırı silmek maliyet ölçümünü yalanlar. `refunded_at` kotayı serbest
-- bırakıyor, defteri bozmuyor.
--
-- İADE NEDEN SINIRLI (`ai_refund_daily`): iade sınırsız olsaydı okunamayan
-- fotoğraf göndermek BEDAVA olurdu — hak düşmez ama OpenAI çağrısı yine
-- yapılır ve para yine harcanır ($0,00146/çağrı). Sınır dürüst kullanımı
-- (birkaç bulanık kare) hiç cezalandırmıyor, kötüye kullanımı kapatıyor.
--
-- ALTYAPI HATASI SINIRSIZ İADE EDİLİYOR: 5xx ya da ayrıştırma hatası
-- KULLANICININ hatası değil. Sınıra dahil etmek, bizim sorunumuzu
-- kullanıcının bütçesine yazmak olurdu.
--
-- AMA BUNU SÖYLEYEBİLECEK TEK TARAF SUNUCU. İlk yazımda tavan bir
-- `p_capped boolean` parametresiyle kapatılabiliyordu ve fonksiyon
-- `authenticated`'a açıktı — yani karar İSTEMCİDEYDİ. PostgREST'e
-- `{"p_call_id": N, "p_capped": false}` gönderen bir istemci `ai_refund_daily`
-- tavanını atlayıp kendi BÜTÜN çağrılarını iade edebiliyordu; iade edilen satır
-- hem pencereden hem AYLIK cap'ten düştüğü için sonuç "OpenAI çağrısı yapıldı,
-- kota geri verildi" — yani sert maliyet tavanı diye bir şey kalmıyordu.
--
-- İKİ AYRI YÜZEY (`grant_ad_reward`/0076 deseninin aynısı):
--   * `refund_ai_use(bigint)`             → `authenticated`, HER ZAMAN tavanlı.
--   * `refund_ai_use_infra(text, bigint)` → yalnızca `anon`, paylaşılan sır.
--
-- SIR: `app_config.ai_refund_secret`. TOHUMLANMIYOR — bir sırrın göç dosyasında
-- yeri yok. Elle girilmeli:
--   insert into public.app_config (key, value)
--   values ('ai_refund_secret', '<uzun rastgele dize>')
--   on conflict (key) do update set value = excluded.value;
-- Aynı değer edge fonksiyonun `AI_REFUND_SECRET` gizlisinde durur:
--   supabase secrets set AI_REFUND_SECRET='<aynı dize>'
-- Sır GİRİLMEZSE altyapı iadesi HİÇ verilmez (fail-closed) ve edge fonksiyon
-- bunu günlüğe yazar — sessiz değil.
--
-- BİLİNEN SINIR: iade edilen çağrı bir REKLAM ÖDÜLÜNDEN geliyorsa
-- (`from_reward`) ödül satırı `consumed_at` işaretli KALIYOR. Ödülün işi
-- pencereyi açmaktı ve iade zaten pencere yuvasını geri veriyor, yani
-- kullanıcı kaybetmiyor; ödülü "geri almak" için hangi satırın harcandığını
-- bilmek gerekiyor ve o bağ defterde tutulmuyor. Bağ kurmak `ai_calls`a bir
-- FK daha eklemek demekti; iki katmanda da aynı sonucu veren bir şey için
-- doğru takas değil.
--
-- GERİ ALMA: `drop function public.refund_ai_use(bigint);`, `drop function public.refund_ai_use_infra(text, bigint);` ve
-- `ai_state()`/`consume_ai_use()`i 0075'teki gövdeleriyle yeniden yaratın.
-- `refunded_at` sütunu kalabilir (okunmazsa etkisiz).

-- ====================================================== 1) defter sütunu
alter table public.ai_calls
  add column if not exists refunded_at timestamptz;

create index if not exists ai_calls_active_idx
  on public.ai_calls (user_id, at) where refunded_at is null;

comment on column public.ai_calls.refunded_at is
  'İade anı. Doluysa satır KOTAYA SAYILMIYOR ama defterde duruyor — OpenAI '
  'çağrısı gerçekten yapıldı, maliyet ölçümü yalan söylememeli.';

insert into public.app_config (key, value) values ('ai_refund_daily', '10')
on conflict (key) do nothing;

-- ====================================================== 2) ai_state: iadeleri saymama
-- ÜÇ SAYIM ve BİR OFFSET sorgusu `refunded_at is null` süzgeci alıyor.
-- Gövde 0075'ten BİREBİR kopyalandı; başka hiçbir satır değişmedi. Bu
-- paketteki en olası regresyon, gövdeyi yeniden yazarken `next_at`
-- formülünü (k'ıncı en eski çağrı) sessizce naif `min()`e döndürmek olurdu.
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
  ad_offer := ai_tier = 'free'
          and not v_suspended
          and ai_month_left > 0
          and ai_window_left <= 0
          and ad_rewards_left > 0;

  return next;
end
$fn$;

revoke execute on function public.ai_state() from public, anon;
grant  execute on function public.ai_state() to authenticated;

-- ====================================================== 3) iade
-- ISTEMCI HICBIR KOSULDA TAVANI KALDIRAMAZ.
--
-- ILK YAZIM `refund_ai_use(p_call_id, p_capped boolean default true)` idi ve
-- `authenticated`'a acikti — yani `p_capped` TAMAMEN ISTEMCININ elindeydi.
-- PostgREST uzerinden `{"p_call_id": N, "p_capped": false}` gonderen bir
-- istemci `ai_refund_daily` tavanini atlayip kendi BUTUN cagrilarini iade
-- edebiliyordu. Iade edilen satir `refunded_at is null` suzgeci yuzunden hem
-- pencereden hem AYLIK cap'ten dustugu icin sonuc suydu: OpenAI cagrisi
-- yapildiktan SONRA kota geri veriliyor — sinirsiz analiz, sinirsiz maliyet.
-- Aylik cap'in tek isi buydu (0075: "sert maliyet tavani").
--
-- COZUM iki ayri yuzey; `grant_ad_reward` (0076) deseninin aynisi:
--   * `refund_ai_use(bigint)`       → `authenticated`, HER ZAMAN tavanli.
--   * `refund_ai_use_infra(text, bigint)` → yalnizca `anon`, paylasilan sirla
--     yetkili, tavansiz. Altyapi hatasi kullanicinin hatasi degil, ama bunu
--     soyleyebilecek tek taraf SUNUCU; istemcinin sozune guvenilmiyor.
--
-- Sir `app_config.ai_refund_secret`; TOHUMLANMIYOR ve yoksa iade VERILMIYOR
-- (fail-closed, `grant_ad_reward`in ayni kurali). Ayni deger edge fonksiyonun
-- `AI_REFUND_SECRET` gizlisinde durur.

drop function if exists public.refund_ai_use(bigint, boolean);

create or replace function public.refund_ai_use(p_call_id bigint)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_hit int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_call_id is null then
    return false;
  end if;

  -- TAVAN HER ZAMAN UYGULANIR. Parametreyle gevsetilemez.
  if not public.bump_rate_limit(
       'ai_refund',
       public.config_int('ai_refund_daily', 10),
       public.istanbul_day()::text) then
    return false;
  end if;

  -- IDEMPOTENT: `refunded_at is null` kosulu iki kez cagrilmayi zararsiz
  -- kiliyor. Olmasaydi edge fonksiyonun yeniden denemesi ikinci bir yuva
  -- acardi — yani hak BASARDI.
  update public.ai_calls c
     set refunded_at = now()
   where c.id = p_call_id
     and c.user_id = v_uid
     and c.refunded_at is null;

  get diagnostics v_hit = row_count;
  return v_hit > 0;
end
$fn$;

revoke execute on function public.refund_ai_use(bigint) from public, anon;
grant  execute on function public.refund_ai_use(bigint) to authenticated;

comment on function public.refund_ai_use(bigint) is
  'Okunamayan fotografin hakkini geri verir (Tur 7 - n4 kurali). Satiri '
  'SILMIYOR, `refunded_at` ile isaretliyor — maliyet defteri korunuyor. '
  'Idempotent. HER ZAMAN `ai_refund_daily` ile tavanli; tavani kaldiran '
  'parametre YOK (istemci kendi kotasini acamaz).';

-- ---------------------------------------------------------- altyapi iadesi
-- Kullanici kimligi PARAMETRE DEGIL: `ai_calls` satirinin kendisi `user_id`
-- tasiyor, yani "hangi kullanici" sorusunu defter cevapliyor. Task 01'in
-- "hicbir RPC user_id parametresi almaz" degismezi boylece korunuyor.
--
-- TAVAN YOK, dolayisiyla `bump_rate_limit` da cagrilmiyor — o fonksiyon
-- `auth.uid()` okuyor ve burada oturum yok.
create or replace function public.refund_ai_use_infra(
  p_secret  text,
  p_call_id bigint
)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_secret text;
  v_hit    int;
begin
  select value into v_secret from public.app_config
   where key = 'ai_refund_secret';

  if v_secret is null or v_secret = '' then
    raise warning 'refund_ai_use_infra: ai_refund_secret yok — iade VERILMIYOR';
    return false;
  end if;
  if p_secret is null or p_secret <> v_secret then
    return false;
  end if;
  if p_call_id is null then
    return false;
  end if;

  update public.ai_calls c
     set refunded_at = now()
   where c.id = p_call_id
     and c.refunded_at is null;

  get diagnostics v_hit = row_count;
  return v_hit > 0;
end
$fn$;

-- CIPLAK BOOLEAN DONUYOR: hangi kontrolun dustugunu soyleyen bir oracle yok.
revoke execute on function public.refund_ai_use_infra(text, bigint)
  from public, authenticated;
grant  execute on function public.refund_ai_use_infra(text, bigint) to anon;

comment on function public.refund_ai_use_infra(text, bigint) is
  'Altyapi hatasi (5xx / ayristirma) kaynakli iade. TAVANSIZ, bu yuzden '
  'YALNIZCA anon cagirabilir ve yetkilendirme app_config.ai_refund_secret '
  'ile. Sir yoksa iade VERILMEZ (fail-closed). Kullanici kimligi ai_calls '
  'satirindan okunuyor, parametre olarak alinmiyor.';

-- ====================================================== 4) consume: kimlik döndür
-- İMZA DEĞİŞMİYOR ama DÖNÜŞ TİPİ değişiyor (yeni `call_id` sütunu) — bu da
-- `create or replace` ile YAPILAMIYOR. `drop` + `create` zorunlu; depoda bu
-- tuzağa iki kez düşülmüş (0014/0015, 0016/0024): `create or replace` ikinci
-- bir aşırı yükleme üretiyor ve mevcut çağrılar "function is not unique" ile
-- patlıyor.
drop function if exists public.consume_ai_use(text);

create function public.consume_ai_use(p_sha_hex text default null)
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

  if v_s is null or v_s.ai_left <= 0 then
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

comment on function public.consume_ai_use(text) is
  'Bir AI analiz hakkı harcar ve DEFTER SATIRININ KİMLİĞİNİ döndürür. Hak '
  'yoksa istisna ATMAZ, allowed=false döner. Kimlik, okunamayan fotoğrafın '
  'iadesi (refund_ai_use) için gerekiyor — Tur 7 · n4 kuralı.';
