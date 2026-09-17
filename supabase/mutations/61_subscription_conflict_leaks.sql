-- test: supabase/tests/340_subscriptions.sql
--
-- MUTASYON: `apply_subscription`daki `unique_violation` dalini kaldir —
-- baska hesaba bagli makbuz yine ISTISNA firlatsin.
-- BEKLENEN: 340'in "ayni makbuz IKINCI bir hesaba baglanamiyor — false,
-- istisna DEGIL" iddiasi kirmizi (dosya hatayla duser).
--
-- NEDEN BU BIR KORUMA (Task 17 · T17-8): istisna cagirana siziyor ve
-- `verify-purchase`in genel catch'inde 503'e donusuyor. 503 "gecici ariza,
-- yine dene" demek; durum ise KALICI — makbuz baskasinin. Istemci satin
-- almayi tamamlamiyor, magaza teslimi tekrarliyor, kullanici ayni anlamsiz
-- hatayi tekrar tekrar goruyor. Fonksiyonun sozlesmesi zaten "karara
-- baglandiysa false".
--
-- NOT: iki govde de goc dosyasindan URETILDI. Kaynak: 0103
-- (20260918000100_subscription_conflict.sql).
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
  --
  -- ÇAKIŞMA DALI (Task 17 · T17-8): `on conflict` YALNIZCA birincil anahtarı
  -- (user_id, platform) karşılıyor. Makbuzun kendisi ayrı bir tekil indeksle
  -- korunuyor (`subscriptions_txn_uniq`) ve o ihlal buraya `unique_violation`
  -- olarak geliyordu — ele alınmadığı için çağıran edge fonksiyonunda 503'e
  -- dönüşüyordu. Durum kalıcı: bu makbuz BAŞKA bir hesaba bağlı.
  -- MUTASYON: cakisma dali KALDIRILDI — 23505 yine cagirana sizsin.
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

-- @UNDO
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
  --
  -- ÇAKIŞMA DALI (Task 17 · T17-8): `on conflict` YALNIZCA birincil anahtarı
  -- (user_id, platform) karşılıyor. Makbuzun kendisi ayrı bir tekil indeksle
  -- korunuyor (`subscriptions_txn_uniq`) ve o ihlal buraya `unique_violation`
  -- olarak geliyordu — ele alınmadığı için çağıran edge fonksiyonunda 503'e
  -- dönüşüyordu. Durum kalıcı: bu makbuz BAŞKA bir hesaba bağlı.
  begin
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
  exception when unique_violation then
    -- SESSİZ DEĞİL: hangi makbuzun hangi platformda çakıştığı günlüğe yazılıyor.
    raise warning 'apply_subscription: makbuz BAŞKA hesaba bağlı (%, %)',
                  p_platform, p_original_txn;
    return false;
  end;

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
