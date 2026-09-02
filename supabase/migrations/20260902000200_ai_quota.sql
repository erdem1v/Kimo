-- 0040 — Can: günlük yapay zekâ okutma hakkı
--
-- ÜRÜN TANIMI (task kararı):
--   • Soru KAYDETMEK her zaman serbest. Can, kaydetmeyi değil AI analizini
--     sınırlar.
--   • Can varken: fotoğraf çekilir, AI şıkları ve konuyu çıkarır.
--   • Can bittiğinde: aynı akış, AI adımı atlanır — kullanıcı elle girer.
--     Kaydetme yolu ASLA kapanmaz.
--   • Günlük 5 hak, sunucu takviminde (Europe/Istanbul) gün dönümünde tazelenir.
--
-- NEDEN SUNUCUDA: tazelenme "son harcamadan" türetiliyor ve gün anahtarı
-- sunucunun takviminden geliyor. Cihaz saatini ileri alan kullanıcı ek hak
-- alamaz. İstemcide bir zamanlayıcı YOK.
--
-- AYNI MEKANİZMA BİR GÜVENLİK AÇIĞINI DA KAPATIYOR: `analyze-question` edge
-- fonksiyonunun kişi başı sınırı yoktu (Task 01 raporu, açık bulgu #7) ve
-- OpenAI maliyeti doğrudan bize yazılıyordu. Artık her çağrı önce buradan
-- geçiyor.
--
-- ÖLÜ SÜTUN: `profiles.hearts` bu mekaniğin karşılığı DEĞİL — hiçbir kod onu
-- okumuyor/yazmıyordu ve arayüzde hep 5 görünüyordu; 0047'de düşürülüyor.

-- ------------------------------------------------------------- oran sınırları
-- Genel amaçlı sayaç: (kullanıcı, kova, pencere) üçlüsü başına bir tamsayı.
--
-- Pencere anahtarı METİN, kasıtlı: her kovanın kendi takvimi olabiliyor.
-- `ai` kovası Istanbul GÜNÜNÜ kullanıyor (ürün kuralı), `friend_code` kovası
-- Istanbul SAATİNİ. Epoch'a hizalı bir aralık kullanılsaydı günlük pencere
-- UTC gece yarısında dönerdi ve Türkiye'de saat 03:00'te tazelenirdi.
create table if not exists public.rate_limits (
  user_id    uuid not null references auth.users(id) on delete cascade,
  bucket     text not null,
  window_key text not null,
  n          int  not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, bucket, window_key)
);

create index if not exists rate_limits_updated_idx
  on public.rate_limits (updated_at);

alter table public.rate_limits enable row level security;
-- Politika YOK = yalnızca definer fonksiyonlar erişir. Sayaç kullanıcının
-- kendisine bile yazılabilir olmamalı; okunması `my_daily_state` görünümünden.
revoke all on public.rate_limits from public, anon, authenticated;

comment on table public.rate_limits is
  'Kullanıcı başına pencereli sayaçlar (günlük AI hakkı, arkadaş kodu deneme '
  'sınırı, veli e-postası sınırı). Yalnızca sunucu. Eski satırlar periyodik '
  'olarak silinebilir; updated_at indeksi bunun için.';

-- --------------------------------------------------------------- günlük kota
-- Tek doğruluk kaynağı. `my_daily_state` görünümü ve `consume_ai_use` aynı
-- fonksiyondan okuyor; sayı iki yerde tutulsaydı arayüz "2 hakkın kaldı"
-- derken sunucu reddedebilirdi.
create or replace function public.daily_ai_quota()
returns int language sql immutable as $$
  select 5;
$$;

-- Istanbul gün anahtarı — hem sayaçta hem görünümde aynı ifade kullanılsın.
create or replace function public.istanbul_day()
returns date language sql stable as $$
  select (now() at time zone 'Europe/Istanbul')::date;
$$;

-- Bir sonraki gün dönümü (kullanıcıya "yarın yenilenecek" derken).
create or replace function public.istanbul_day_reset()
returns timestamptz language sql stable as $$
  select ((now() at time zone 'Europe/Istanbul')::date + 1)::timestamp
           at time zone 'Europe/Istanbul';
$$;

-- ---------------------------------------------------------------- tüketim
-- Bir AI okuma hakkı harcar. Hak yoksa HATA ATMAZ: `allowed = false` döner.
--
-- Neden istisna değil: hak bitmesi bir hata değil, beklenen bir ürün durumu.
-- İstisna atılsaydı edge fonksiyonun onu ayırt edip 200 döndürmesi, istemcinin
-- de hata mesajını ayrıştırması gerekirdi; ikisi de kırılgan.
--
-- Yarış koşulu tek ifadede kapatılıyor: `on conflict do update ... where`
-- sayaç kotanın altındaysa artırıyor, değilse HİÇBİR satır döndürmüyor.
-- Önce oku-sonra-yaz yapılsaydı iki eşzamanlı çağrı aynı değeri okuyup
-- ikisi de hak alırdı.
create or replace function public.consume_ai_use()
returns table (allowed boolean, remaining int, resets_at timestamptz)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid   uuid := auth.uid();
  v_quota int  := public.daily_ai_quota();
  v_key   text := public.istanbul_day()::text;
  v_n     int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  insert into public.rate_limits (user_id, bucket, window_key, n)
  values (v_uid, 'ai', v_key, 1)
  on conflict (user_id, bucket, window_key) do update
     set n = rate_limits.n + 1,
         updated_at = now()
   where rate_limits.n < v_quota
  returning rate_limits.n into v_n;

  if v_n is null then
    -- Kota dolu: satır vardı ama koşul tutmadı.
    return query select false, 0, public.istanbul_day_reset();
    return;
  end if;

  return query
    select true, greatest(v_quota - v_n, 0), public.istanbul_day_reset();
end
$fn$;

revoke execute on function public.consume_ai_use() from public, anon;
grant execute on function public.consume_ai_use() to authenticated;

-- Bu üç yardımcı `my_daily_state` görünümünün SELECT listesinde çağrılıyor.
-- `security_invoker = false` görünümlerde TABLO erişimi görünüm sahibinin
-- yetkisiyle denetleniyor ama FONKSİYON çağrısının EXECUTE yetkisi ÇAĞIRANA
-- karşı denetleniyor; kapatılırsa görünüm okunurken 42501 alınır.
-- Sızdırdıkları bilgi yok: biri sabit 5, ikisi sunucunun takvimi.
revoke execute on function public.daily_ai_quota() from public, anon;
grant execute on function public.daily_ai_quota() to authenticated;
revoke execute on function public.istanbul_day() from public, anon;
grant execute on function public.istanbul_day() to authenticated;
revoke execute on function public.istanbul_day_reset() from public, anon;
grant execute on function public.istanbul_day_reset() to authenticated;

-- ------------------------------------------------------- ortak oran sınırı
-- Kötüye kullanım sınırları için (arkadaş kodu denemesi, veli e-postası).
-- Sayaç aşıldıysa `false` döner; çağıran kendi hata mesajını verir.
--
-- `apply_progress` gibi: yalnızca diğer definer fonksiyonlar çağırıyor,
-- kimseye EXECUTE verilmiyor. Doğrudan çağrılabilseydi kullanıcı kendi
-- sayacını tüketerek başkasının değil ama kendi sınırını manipüle edebilirdi.
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

-- --------------------------------------------------------- günlük durum
-- İstemcinin HUD'u bu görünümden besleniyor: kalan can, elmas, XP, seri.
--
-- `security_invoker = false` (tanımlayıcı): `rate_limits` politikasız RLS ile
-- kapalı olduğu için çağıran onu okuyamaz. Koruma tek satırlık `auth.uid()`
-- süzgeci — `received_questions` görünümündeki desenin aynısı.
--
-- Kalan hak burada TÜRETİLİYOR, saklanmıyor: gün değişince satır eskiyor ve
-- sayaç kendiliğinden sıfırdan sayılıyor.
create or replace view public.my_daily_state
with (security_invoker = false) as
select
  p.id                                              as user_id,
  greatest(public.daily_ai_quota() - coalesce(r.n, 0), 0) as ai_left,
  public.daily_ai_quota()                           as ai_quota,
  public.istanbul_day_reset()                       as ai_resets_at,
  p.gems,
  p.xp,
  p.streak,
  p.weekly_xp,
  p.league
from public.profiles p
left join public.rate_limits r
       on r.user_id = p.id
      and r.bucket = 'ai'
      and r.window_key = public.istanbul_day()::text
where p.id = auth.uid();

revoke all on public.my_daily_state from public, anon;
grant select on public.my_daily_state to authenticated;

comment on view public.my_daily_state is
  'Oturumdaki kullanıcının günlük durumu: kalan AI hakkı (can), elmas, XP, '
  'seri, lig. Kalan hak saklanmaz, sayaçtan türetilir.';
