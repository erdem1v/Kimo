-- 0092 — Abonelik defteri ve sunucu tarafı makbuz doğrulama (Task 13 · Paket 3)
--
-- BUGÜNKÜ DURUM: `profiles.premium_until` 0075'te eklendi, `user_tier()` onu
-- okuyor, kota rejiminin tamamı ona dayanıyor — ama O SÜTUNU YAZAN HİÇBİR KOD
-- YOLU YOK. Göçün kendi yorumu bunu açıkça söylüyor: "BU PAKETTE YAZAN HİÇBİR
-- ŞEY YOK — bilinçli. Abonelik satın alma (IAP) ayrı bir task ve bu sütunu o
-- dolduracak." Bu, o task.
--
-- ==========================================================================
-- DEFTER Mİ SAYAÇ MI: İKİSİ DE, VE TEK YAZARLA
--
-- Depo "sayı iki yerde" kalıbını 0075'te açıkça reddediyor. Yine de
-- `user_tier()`i `subscriptions`tan okutmak SEÇİLMEDİ:
--   `user_tier()` → `ai_state()` → `my_daily_state` zinciri kota motorunun
--   sıcak yolu ve Task 12'de tam orada bir `create or replace` tuzağına
--   düşüldü (OUT sütun sırası değişince `db reset` patladı). Abonelik için o
--   zincire dokunmak bu paketin en riskli hamlesi olurdu.
--
-- Bunun yerine: `subscriptions` = DEFTER (mağaza olaylarının gerçeği),
-- `profiles.premium_until` = İZDÜŞÜM, ve TEK YAZAR var — `apply_subscription`
-- ikisini AYNI İŞLEMDE yazıyor. Emsal: `profiles.league` de
-- `league_members`ın izdüşümü ve tek yazarı `settle_past_leagues`.
-- Ayrışamayacakları pgTAP'te ayrıca iddia ediliyor.
--
-- Böylece `user_tier()`, `ai_state()` ve `consume_ai_use()` HİÇ DEĞİŞMİYOR.
--
-- ==========================================================================
-- YETKİLENDİRME: `grant_ad_reward` (0076) DESENİNİN AYNISI
--
-- İstemci hiçbir koşulda katman iddia edemez. Yazma yolu `anon`-çağrılabilir
-- TEK bir RPC ve paylaşılan bir sır:
--   sır sızarsa hasar : bedava abonelik.
--   anahtar sızarsa   : her satır + auth.admin.deleteUser.
--
-- `p_user` PARAMETRESİ VE TASK 01 DEĞİŞMEZİ: "hiçbir RPC `user_id` parametresi
-- almaz" kuralı, bir AUTHENTICATED kullanıcının başkası adına iş yapmasını
-- engellemek için var. Bu fonksiyon `authenticated`'a KAPALI ve yalnızca
-- `anon` + sır ile çağrılabiliyor — `grant_ad_reward`ın `p_nonce`u ile aynı
-- güç sınıfı (sırrı taşıyan bizim edge fonksiyonumuz). Yenileme/iade
-- bildirimlerinde `p_user` NULL geçiliyor ve kullanıcı DEFTERDEN çözülüyor;
-- mağaza bildirimi zaten kullanıcıyı bilmiyor.
--
-- SIR: `app_config.iap_secret`. TOHUMLANMIYOR — bir sırrın göç dosyasında yeri
-- yok. Elle girilmeli:
--   insert into public.app_config (key, value)
--   values ('iap_secret', '<uzun rastgele dize>')
--   on conflict (key) do update set value = excluded.value;
-- Aynı değer edge fonksiyonların `IAP_SECRET` gizlisinde durur.
-- Sır GİRİLMEZSE abonelik HİÇ yazılmaz (fail-closed).
--
-- GERİ ALMA: `drop table public.subscriptions cascade;`,
-- `drop function public.apply_subscription(...);`,
-- `drop function public.subscription_state();` ve `my_daily_state`i 0079'un
-- gövdesiyle yeniden yaratın.

-- ====================================================== 1) defter
-- SUNUCU SAHİPLİ TABLO: `ai_calls`/`ad_rewards` DDL kalıbının birebir kopyası —
-- tablo + indeksler + RLS açık + HİÇ POLİTİKA YOK + revoke all + comment.
create table if not exists public.subscriptions (
  user_id         uuid not null references auth.users(id) on delete cascade,
  platform        text not null check (platform in ('ios', 'android')),
  product_id      text not null,
  original_txn_id text not null,
  status          text not null check (status in
                    ('trial', 'active', 'grace', 'expired',
                     'refunded', 'revoked')),
  expires_at      timestamptz,
  auto_renewing   boolean,
  last_event_at   timestamptz not null default now(),
  raw_event       jsonb,
  created_at      timestamptz not null default now(),
  primary key (user_id, platform)
);

-- BİR MAKBUZ İKİ HESABA BAĞLANAMAZ. Kısıt fonksiyon mantığında değil
-- KATALOGDA: `ad_rewards`ın `transaction_id` tekilliğiyle aynı karar.
create unique index if not exists subscriptions_txn_uniq
  on public.subscriptions (platform, original_txn_id);

create index if not exists subscriptions_active_idx
  on public.subscriptions (expires_at)
  where status in ('trial', 'active', 'grace');

alter table public.subscriptions enable row level security;
-- Politika YOK = yalnızca definer fonksiyonlar erişir.
revoke all on public.subscriptions from public, anon, authenticated;

comment on table public.subscriptions is
  'Mağaza abonelik defteri. Sunucu sahipli: politika YOK, istemci hiçbir '
  'satırı göremez/yazamaz. `profiles.premium_until` bu defterin izdüşümü ve '
  'tek yazar `apply_subscription`. Kullanıcı kendi durumunu '
  '`my_daily_state.sub_*` sütunlarından okuyor.';

comment on column public.subscriptions.original_txn_id is
  'Apple originalTransactionId / Play purchaseToken kökü. Yenileme '
  'bildirimleri kullanıcıyı bilmiyor; defteri bu alan üzerinden buluyorlar.';

-- ====================================================== 2) tek yazma yolu
create or replace function public.apply_subscription(
  p_secret        text,
  p_platform      text,
  p_original_txn  text,
  p_status        text,
  p_expires_at    timestamptz,
  p_auto_renewing boolean default null,
  p_product       text default null,
  p_user          uuid default null,
  p_raw           jsonb default null
)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_secret  text;
  v_uid     uuid;
  v_product text;
  v_premium timestamptz;
begin
  if p_secret is null or p_secret = '' then
    return false;
  end if;

  select value into v_secret from public.app_config where key = 'iap_secret';

  -- FAIL-CLOSED, ve SESSİZ DEĞİL (`grant_ad_reward`ın aynı kuralı).
  if v_secret is null or v_secret = '' then
    raise warning 'apply_subscription: iap_secret yok — abonelik YAZILMIYOR';
    return false;
  end if;
  if p_secret <> v_secret then
    return false;
  end if;

  if p_platform is null or p_original_txn is null or p_status is null then
    return false;
  end if;

  -- KULLANICI: satın alma akışında edge fonksiyon JWT'den çözüp geçiyor;
  -- mağaza BİLDİRİMİNDE `p_user` null ve kullanıcı DEFTERDEN çözülüyor.
  v_uid := p_user;
  if v_uid is null then
    select s.user_id, s.product_id into v_uid, v_product
      from public.subscriptions s
     where s.platform = p_platform and s.original_txn_id = p_original_txn;
    if v_uid is null then
      -- Bilinmeyen makbuz: satın alma doğrulaması hiç gelmemiş ya da defter
      -- budanmış. Bildirimi KARARA BAĞLANMIŞ sayıyoruz (edge fonksiyon 200
      -- dönüp mağazayı sonsuz tekrardan kurtaracak); sessiz değil.
      raise warning 'apply_subscription: bilinmeyen makbuz (%, %)',
                    p_platform, p_original_txn;
      return false;
    end if;
  end if;

  v_product := coalesce(p_product, v_product);
  if v_product is null then
    select s.product_id into v_product from public.subscriptions s
     where s.user_id = v_uid and s.platform = p_platform;
  end if;
  if v_product is null then
    return false;
  end if;

  -- Aynı kullanıcı + platform için TEK satır. `on conflict` ile idempotent:
  -- mağaza bildirimleri tekrar teslim edilebilir.
  insert into public.subscriptions as s
    (user_id, platform, product_id, original_txn_id, status, expires_at,
     auto_renewing, last_event_at, raw_event)
  values
    (v_uid, p_platform, v_product, p_original_txn, p_status, p_expires_at,
     p_auto_renewing, now(), p_raw)
  on conflict (user_id, platform) do update
     set product_id      = excluded.product_id,
         original_txn_id = excluded.original_txn_id,
         status          = excluded.status,
         expires_at      = excluded.expires_at,
         auto_renewing   = coalesce(excluded.auto_renewing, s.auto_renewing),
         last_event_at   = now(),
         raw_event       = coalesce(excluded.raw_event, s.raw_event);

  -- İZDÜŞÜM, AYNI İŞLEMDE. Kullanıcının BÜTÜN platformlarındaki en geç
  -- bitişi yazıyoruz: iki platformdan abone olan biri (nadir ama mümkün)
  -- ikisinin kısasıyla cezalandırılmasın.
  --
  -- İADE VE İPTAL FARKI: `refunded`/`revoked` HEMEN düşürüyor (para geri
  -- verildi, hak da gitmeli); `expired` zaten geçmiş bir tarih taşıyor;
  -- iptal (`auto_renewing = false`) ise DÜŞÜRMÜYOR — kullanıcı ödediği
  -- dönemin sonuna kadar premium kalır.
  select max(s.expires_at) into v_premium
    from public.subscriptions s
   where s.user_id = v_uid
     and s.status in ('trial', 'active', 'grace');

  update public.profiles p
     set premium_until = v_premium
   where p.id = v_uid
     and p.premium_until is distinct from v_premium;

  return true;
end
$fn$;

-- ÇIPLAK BOOLEAN DÖNÜYOR: hangi kontrolün düştüğünü söyleyen bir oracle yok.
revoke execute on function public.apply_subscription(
  text, text, text, text, timestamptz, boolean, text, uuid, jsonb)
  from public, authenticated;
grant execute on function public.apply_subscription(
  text, text, text, text, timestamptz, boolean, text, uuid, jsonb) to anon;

comment on function public.apply_subscription(
  text, text, text, text, timestamptz, boolean, text, uuid, jsonb) is
  'Abonelik defterini ve `profiles.premium_until` izdüşümünü AYNI İŞLEMDE '
  'yazan TEK yol. YALNIZCA anon çağırabilir (mağaza bildiriminde kullanıcı '
  'JWT''si yok); yetkilendirme app_config.iap_secret ile. Makbuz üzerinde '
  'idempotent. Sır yoksa abonelik YAZILMAZ (fail-closed).';

-- ====================================================== 3) durum yüzeyi
-- ABONELİK SÜTUNLARI `ai_state()`E EKLENMİYOR, BİLEREK. Task 12'de tam o OUT
-- listesini büyütme denemesi `db reset`i patlattı ("cannot change return type
-- of existing function"), ve Task 10 raporu zaten `ai_state()`in görünümün
-- sütun sırasını sabitlediğini bilinen bir sınır olarak yazmıştı. Ayrı bir
-- fonksiyon, görünümün `from` listesine üçüncü kaynak olarak giriyor —
-- `feature_flags()` ile aynı desen.
--
-- TEK `timestamptz` YETMİYOR: istemcinin "deneme mi, ne zaman bitiyor,
-- yenilenecek mi" sorularına cevap vermesi gerekiyor ve eksik veriyle karar
-- UYDURMASI deponun açıkça yasakladığı şey.
create or replace function public.subscription_state()
returns table (
  sub_status     text,
  sub_store      text,
  sub_expires_at timestamptz,
  sub_renews     boolean,
  sub_in_trial   boolean
)
language sql stable security definer set search_path = public
as $fn$
  select s.status,
         s.platform,
         s.expires_at,
         coalesce(s.auto_renewing, false),
         s.status = 'trial'
    from public.subscriptions s
   where s.user_id = auth.uid()
   order by s.expires_at desc nulls last
   limit 1;
$fn$;

revoke execute on function public.subscription_state() from public, anon;
grant  execute on function public.subscription_state() to authenticated;

comment on function public.subscription_state() is
  'Oturumdaki kullanıcının abonelik durumu — `my_daily_state`in kaynağı. '
  'Sıfır argümanlı ve `auth.uid()`e kilitli. `ai_state()`e EKLENMEDİ: o '
  'fonksiyonun OUT listesini büyütmek görünümün sütun sırasını kırıyor.';

-- ====================================================== 4) satın alma bayrağı
-- RİSKLİ HER ÖZELLİK UZAKTAN KAPATILABİLMELİ. Satın alma yanlış davranırsa
-- (mağaza tarafı arıza, fiyat sorgusu boş dönüyor, doğrulama düşüyor)
-- paywall'ın düğmesi SÜRÜM BEKLEMEDEN kapanabilmeli.
insert into public.app_config (key, value) values ('ff_iap', 'true')
on conflict (key) do nothing;

-- DROP + CREATE, `create or replace` DEĞİL. Postgres OUT parametrelerinin
-- tanımladığı satır tipini değiştirmeye HİÇ izin vermiyor — SONA sütun
-- EKLEMEK de dahil. 0083'ün kendi yorumu kuralı yazıyor: "yeni `call_id`
-- sütunu … `create or replace` ile YAPILAMIYOR". Ve görünüm bu fonksiyona
-- bağımlı olduğu için SIRA da önemli: önce görünüm düşmeli.
drop view if exists public.my_daily_state;
drop function if exists public.feature_flags();

create function public.feature_flags()
returns table (
  ff_pair_streak   boolean,
  ff_multi_capture boolean,
  ff_ad_reward     boolean,
  ff_iap           boolean
)
language sql stable security definer set search_path = public
as $fn$
  select public.config_bool('ff_pair_streak',   false),
         public.config_bool('ff_multi_capture', true),
         public.config_bool('ff_ad_reward',     true),
         public.config_bool('ff_iap',           true);
$fn$;

revoke execute on function public.feature_flags() from public, anon;
grant  execute on function public.feature_flags() to authenticated;

-- ====================================================== 5) görünüm
-- Görünüm YUKARIDA düşürüldü (`feature_flags()` ona bağımlıydı). `create or
-- replace view` zaten yetmezdi: yalnızca listenin SONUNA sütun eklemeye izin
-- veriyor, burada ise hem yeni bir KAYNAK hem yeni sütunlar var. 0079 aynı
-- dersi yazmıştı; Task 12 `received_questions`ta unutup `db reset`i
-- patlatmıştı. `tools/check_sql.py` artık ikisini de statik olarak yakalıyor.
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
  sub.sub_in_trial
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
  'İstemcinin HUD kaynağı: ilerleme, kota, özellik bayrakları ve abonelik '
  'durumu. İstemci hiçbir şey hesaplamıyor. Abonelik sütunları ayrı bir '
  'fonksiyondan geliyor (`subscription_state`) — `ai_state()`in OUT listesi '
  'büyütülemez.';

-- ====================================================== 6) gecelik mutabakat
-- İKİNCİ KATMAN. `store-notify` bildirimleri anında işliyor ama o yolun bozuk
-- olması FARK EDİLMEYEN türden bir arıza: konsolda geri çağrı adresi yanlış
-- girilmiş olabilir, Pub/Sub aboneliği silinmiş olabilir, bir bildirim
-- kaybolmuş olabilir. Hiçbirinde bir hata görünmez — yalnızca iade alan
-- kullanıcılar premium kalmaya devam eder.
--
-- Taban adres ve Vault'taki servis rolü sırrı girilmemişse sorgu NO-OP;
-- hata üretmiyor ve iş görünür kalıyor (0051'in `scan-photos-sweep` deseni).
do $cron$
begin
  perform cron.unschedule(jobid)
    from cron.job where jobname = 'subscriptions-reconcile';
exception when others then
  null;
end
$cron$;

-- Her gece 03:40 Istanbul = 00:40 UTC.
select cron.schedule(
  'subscriptions-reconcile',
  '40 0 * * *',
  $$
  select net.http_post(
           url := (select value from public.app_config
                    where key = 'edge_base_url') || '/reconcile-subscriptions',
           headers := jsonb_build_object(
             'Authorization',
             'Bearer ' || (select decrypted_secret
                             from vault.decrypted_secrets
                            where name = 'service_role_key'),
             'Content-Type', 'application/json'),
           body := '{}'::jsonb)
   where exists (select 1 from public.app_config where key = 'edge_base_url')
     and exists (select 1 from vault.decrypted_secrets
                  where name = 'service_role_key')
  $$
);
