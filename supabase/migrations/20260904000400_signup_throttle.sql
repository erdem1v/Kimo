-- 0058 — Kayıt hız sınırı (before_user_created kancası)
--
-- NEDEN: 0057 ile e-posta doğrulaması kaldırıldı. Doğrulama, sahte hesabın
-- maliyetini "gerçek bir posta kutusu"na bağlayan tek şeydi; o gidince
-- e-posta alanı bir metin kutusundan ibaret (`a8f3k@gmail.com` yeter) ve
-- Supabase'in kendi tabanı IP başına 5 dakikada 30 kayda izin veriyor
-- (= günde 8.640). Her hesap ücretsiz katmanın aylık cap'ini alacağı için
-- bu, tek IP'den beş haneli aylık OpenAI faturası demek.
--
-- BU KANCA O SAYIYI 8.640'tan 300'e indiriyor (29 kat). Kararlı durumu
-- bağlamıyor — saldırgan hesapları biriktirip bekleyebilir; onu bağlayan tek
-- şey cihaz sınırı ve o bilinçli olarak ertelendi (tetiği ölçüm). Buradaki
-- iş, ölçeklenen frenin devreye girmesine kadar geçen süreyi ucuzlatmak.
--
-- CÖMERT OLMAK ZORUNDA. Türkiye'de mobil operatörler CGNAT kullanıyor: bir
-- yurt, bir okul ya da bir kafe tek IP'nin arkasında olabilir. 300/gün bir
-- sınıfın tamamını rahat karşılar, script binlerce kimlik üretemez. Aynı
-- gerekçeyle kotada IP boyutunu REDDETMİŞTİK; kayıt tarafında kabul
-- ediyoruz çünkü burada alternatif yok (IP uygulamaya yalnızca bu kancayla
-- ulaşıyor) ve sınır meşru kullanımın kat kat üstünde.
--
-- IP HAM SAKLANMIYOR (KVKK): yalnızca `sha256(salt || ip)`. Salt
-- `app_config.signup_ip_salt`'ta; yoksa hız sınırı ATLANIYOR (fail-open) ve
-- yalnızca alan adı kontrolü çalışıyor — yanlış yapılandırılmış bir ortam
-- kayıtları kapatmasın. Satırlar 7 günde bir budanıyor.
--
-- Geri alma:
--   `config.toml` → [auth.hook.before_user_created] enabled = false
--   drop function public.hook_before_user_created(jsonb);
--   drop table public.signup_throttle;
--   select cron.unschedule(jobid) from cron.job where jobname = 'signup-throttle-prune';

-- ------------------------------------------------------------------- sayaç
-- `rate_limits` KULLANILAMIYOR: onun `user_id` sütunu
-- `not null references auth.users(id)` ve bu kanca kullanıcı DAHA YARATILMADAN
-- çalışıyor. Ayrı tablo, aynı disiplin: RLS açık, politika yok, grant yok.
create table if not exists public.signup_throttle (
  ip_hash    bytea not null,
  kind       text  not null,
  window_key text  not null,
  n          int   not null default 0,
  updated_at timestamptz not null default now(),
  primary key (ip_hash, kind, window_key)
);

create index if not exists signup_throttle_updated_idx
  on public.signup_throttle (updated_at);

alter table public.signup_throttle enable row level security;
-- Politika YOK = yalnızca definer fonksiyonlar erişir.
revoke all on public.signup_throttle from public, anon, authenticated;

comment on table public.signup_throttle is
  'IP başına kimlik yaratma sayacı (before_user_created kancası). IP HAM '
  'SAKLANMAZ: ip_hash = sha256(app_config.signup_ip_salt || ip). kind = '
  '''anon'' (anonim oturum) | ''signup'' (e-postalı kayıt) — ayrı kovalar, '
  'bir okulun anonim ilk-açılışları kayıt bütçesini yemesin. window_key '
  'saatlik (YYYY-MM-DD HH24) ya da günlük (YYYY-MM-DD). 7 günde bir budanır.';

-- ------------------------------------------------------------------ kanca
-- İmza ve dönüş biçimi Supabase'in şart koştuğu gibi: `(event jsonb) returns
-- jsonb`; izin = '{}'::jsonb, ret = {"error":{"message":…,"http_code":…}}.
--
-- Payload'ın kullandığımız alanları:
--   event->'metadata'->>'ip_address'    → IP (uygulamaya ULAŞTIĞI TEK YER)
--   event->'user'->>'email'             → anonim oturumda boş
--   event->'user'->>'is_anonymous'      → hangi kovaya yazılacağı
--
-- SECURITY DEFINER: Supabase'in örneği kullanmıyor ama orada kanca kendi
-- tablosunu okuyor ve o tabloya `supabase_auth_admin` yetkisi veriliyor.
-- Bizde okunan tablolardan biri `app_config` — servis rolü anahtarı orada
-- duruyor. Auth yöneticisine o tabloyu açmaktansa fonksiyonu definer yapıp
-- erişimi fonksiyonun içinde tutuyoruz.
create or replace function public.hook_before_user_created(event jsonb)
returns jsonb
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_ip        text;
  v_email     text;
  v_anon      boolean;
  v_kind      text;
  v_salt      text;
  v_hash      bytea;
  v_domain    text;
  v_blocked   text;
  v_hour_lim  int;
  v_day_lim   int;
  v_n         int;
begin
  v_ip    := event -> 'metadata' ->> 'ip_address';
  v_email := lower(coalesce(event -> 'user' ->> 'email', ''));
  v_anon  := coalesce((event -> 'user' ->> 'is_anonymous')::boolean, false);
  v_kind  := case when v_anon then 'anon' else 'signup' end;

  -- 1) Tek kullanımlık alan adı. Doğrulama kalktığı için posta kutusu
  --    gerekmiyor; bu yüzden tek başına ZAYIF bir kontrol ve asıl işi
  --    aşağıdaki hız sınırı yapıyor. Ucuz olduğu için duruyor.
  if not v_anon and v_email <> '' then
    v_domain := split_part(v_email, '@', 2);
    select value into v_blocked
      from public.app_config where key = 'signup_blocked_domains';
    v_blocked := coalesce(
      v_blocked,
      'mailinator.com,guerrillamail.com,10minutemail.com,tempmail.com,'
      'yopmail.com,throwawaymail.com,sharklasers.com,trashmail.com');
    if v_domain = any (string_to_array(v_blocked, ',')) then
      return jsonb_build_object(
        'error', jsonb_build_object(
          'message', 'Bu e-posta sağlayıcısıyla kayıt olunamıyor. '
                     'Kalıcı bir adres kullanabilir misin?',
          'http_code', 400));
    end if;
  end if;

  -- 2) IP başına hız sınırı.
  select value into v_salt from public.app_config where key = 'signup_ip_salt';
  if v_salt is null or v_ip is null or v_ip = '' then
    -- FAIL-OPEN VE SESSİZ DEĞİL: tuz girilmemiş ya da IP gelmemişse kaydı
    -- ENGELLEMİYORUZ. Yanlış yapılandırılmış bir ortamda kayıt akışını
    -- kapatmak, hız sınırının önlediği her şeyden daha pahalı.
    raise warning 'hook_before_user_created: hiz siniri atlandi '
                  '(signup_ip_salt yok ya da ip_address bos)';
    return '{}'::jsonb;
  end if;

  v_hash := sha256(convert_to(v_salt || v_ip, 'UTF8'));

  select case when value ~ '^[0-9]+$' then value::int end into v_hour_lim
    from public.app_config where key = 'signup_hour_limit';
  select case when value ~ '^[0-9]+$' then value::int end into v_day_lim
    from public.app_config where key = 'signup_day_limit';
  v_hour_lim := coalesce(v_hour_lim, 60);
  v_day_lim  := coalesce(v_day_lim, 300);

  -- Günlük önce: daha kaba kapı, önce o konuşsun.
  -- Reddedilen bir istek de o IP'den gelen gerçek bir kimlik yaratma
  -- DENEMESİDİR; sayaca yazılması bilinçli.
  insert into public.signup_throttle (ip_hash, kind, window_key, n)
  values (v_hash, v_kind,
          to_char(now() at time zone 'Europe/Istanbul', 'YYYY-MM-DD'), 1)
  on conflict (ip_hash, kind, window_key) do update
     set n = signup_throttle.n + 1, updated_at = now()
   where signup_throttle.n < v_day_lim
  returning n into v_n;

  if v_n is null then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'Bu ağdan bugün çok fazla hesap açıldı. '
                   'Yarın yeniden deneyebilirsin.',
        'http_code', 429));
  end if;

  insert into public.signup_throttle (ip_hash, kind, window_key, n)
  values (v_hash, v_kind,
          to_char(now() at time zone 'Europe/Istanbul', 'YYYY-MM-DD HH24'), 1)
  on conflict (ip_hash, kind, window_key) do update
     set n = signup_throttle.n + 1, updated_at = now()
   where signup_throttle.n < v_hour_lim
  returning n into v_n;

  if v_n is null then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'Bu ağdan az önce çok fazla hesap açıldı. '
                   'Biraz sonra yeniden deneyebilirsin.',
        'http_code', 429));
  end if;

  return '{}'::jsonb;
exception
  when others then
    -- FAIL-OPEN, AMA SESSİZ DEĞİL. Bu kanca kayıt akışının önünde duruyor:
    -- burada fırlayan her istisna kaydı tamamen keserdi. Beklenmedik bir
    -- hatada kaydı geçiriyoruz ve sunucu günlüğüne yazıyoruz.
    raise warning 'hook_before_user_created hata: % (%)', sqlerrm, sqlstate;
    return '{}'::jsonb;
end
$fn$;

-- Kanca YALNIZCA auth yöneticisi tarafından çağrılır. `authenticated`'a açık
-- olsaydı herkes kendi IP sayacını şişirip başkalarının kaydını engelleyebilirdi.
revoke execute on function public.hook_before_user_created(jsonb)
  from public, anon, authenticated;
grant  execute on function public.hook_before_user_created(jsonb)
  to supabase_auth_admin;

comment on function public.hook_before_user_created(jsonb) is
  'before_user_created auth kancası: IP başına kimlik yaratma hız sınırı '
  '(varsayılan saatte 60, günde 300; app_config''ten gevşetilebilir) ve tek '
  'kullanımlık e-posta alan adı reddi. IP ham saklanmaz. Tuz yoksa ya da '
  'beklenmedik hata olursa FAIL-OPEN: kayıt geçer, sunucu günlüğüne uyarı '
  'yazılır. Yalnızca supabase_auth_admin çağırabilir.';

-- --------------------------------------------------------------- budama
-- Satırlar (ip_hash, kind, window_key) ile büyüyor: IP başına saatte bir
-- satır. Hem sınırsız büyümesin hem de KVKK açısından hash'ler süresiz
-- durmasın diye 7 günden eskiler siliniyor.
create or replace function public.prune_signup_throttle()
returns void
language sql
security definer set search_path = public
as $fn$
  delete from public.signup_throttle where updated_at < now() - interval '7 days';
$fn$;

revoke execute on function public.prune_signup_throttle()
  from public, anon, authenticated;

do $cron$
begin
  perform cron.unschedule(jobid)
    from cron.job where jobname = 'signup-throttle-prune';
exception when others then
  null; -- ilk kurulumda iş yok; sorun değil
end
$cron$;

-- Her gece 03:15 Istanbul = 00:15 UTC (Istanbul DST uygulamıyor, sabit +3).
select cron.schedule(
  'signup-throttle-prune',
  '15 0 * * *',
  $$select public.prune_signup_throttle()$$
);
