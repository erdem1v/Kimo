-- test: supabase/tests/300_ad_reward.sql
--
-- MUTASYON: paylaşılan sır kontrolünü kaldır (fail-closed → fail-open).
-- BEKLENEN: 300'ün "YANLIŞ sırla ödül verilmiyor" ve "SIR YOKKEN ödül
-- verilmiyor" iddiaları kırmızı.
--
-- Kota sayıları fail-open, kimlik doğrulama sırrı FAIL-CLOSED. Bu mutasyon o
-- asimetriyi tersine çeviriyor: sır yoksa ya da yanlışsa ödül yine veriliyor.
-- Gerçek hayattaki karşılığı, `app_config.ad_reward_secret` girilmemiş bir
-- ortamın sessizce bedava hak basması olurdu.
--
-- NOT: aşağıdaki iki gövde de göç dosyasından ÜRETİLDİ (elle kopyalanmadı),
-- yani geri alma yürürlükteki tanımla birebir.
create or replace function public.grant_ad_reward(
  p_nonce          uuid,
  p_transaction_id text,
  p_secret         text
)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_secret  text;
  v_uid     uuid;
  v_daily   int;
  v_granted int;
begin
  if p_nonce is null then
    return false;
  end if;

  v_secret := p_secret;   -- MUTASYON: sır artık app_config'ten okunmuyor

  -- FAIL-CLOSED, ve SESSİZ DEĞİL. `signup_ip_salt`'ın tersi: orada tuz yoksa
  -- kayıt AKIYOR (yanlış yapılandırma kaydı kapatmasın), burada sır yoksa
  -- ödül VERİLMİYOR (yanlış yapılandırma bedava hak basmasın).
  -- MUTASYON: fail-closed sır kontrolü kaldırıldı.

  -- TEKRAR OYNATMA (replay), aynı nonce: AdMob geri çağrıyı yeniden denemiş.
  -- BAŞARI dönüyoruz ki edge fonksiyonu 200 dönsün ve AdMob sonsuz döngüye
  -- girmesin. İkinci bir hak verilmiyor.
  if p_transaction_id is not null and exists (
       select 1 from public.ad_rewards r
        where r.nonce = p_nonce
          and r.status = 'granted'
          and r.transaction_id = p_transaction_id) then
    return true;
  end if;

  -- Aynı işlem kimliği BAŞKA bir nonce'ta: meşru AdMob trafiğinde olmayan bir
  -- durum. Suistimal sinyali olarak loglanıp reddediliyor.
  if p_transaction_id is not null and exists (
       select 1 from public.ad_rewards r
        where r.transaction_id = p_transaction_id
          and r.nonce <> p_nonce) then
    raise warning 'grant_ad_reward: islem kimligi baska bir nonce ile kullanilmis';
    return false;
  end if;

  select r.user_id into v_uid
    from public.ad_rewards r
   where r.nonce = p_nonce and r.status = 'pending';
  if v_uid is null then
    return false;               -- bilinmeyen, süresi geçmiş ya da harcanmış
  end if;

  -- `consume_ai_use` ile AYNI kilit: ödül verme ile tüketim araya girmiyor,
  -- yani kullanıcı ödülü alırken aynı anda harcayamıyor.
  perform pg_advisory_xact_lock(hashtext('ai_quota'), hashtext(v_uid::text));

  -- Günlük tavan VERME ANINDA yeniden kontrol ediliyor: `start_ad_reward`
  -- ile geri çağrı arasında geçen sürede kullanıcı başka bir reklam
  -- tamamlamış olabilir.
  v_daily := public.config_int('ad_reward_daily', 3);
  select count(*)::int into v_granted
    from public.ad_rewards r
   where r.user_id = v_uid
     and r.status = 'granted'
     and (r.granted_at at time zone 'Europe/Istanbul')::date
         = public.istanbul_day();
  if v_granted >= v_daily then
    return false;
  end if;

  update public.ad_rewards r
     set status = 'granted',
         granted_at = now(),
         transaction_id = p_transaction_id
   where r.nonce = p_nonce and r.status = 'pending';

  return true;
exception
  when unique_violation then
    -- `ad_rewards_txn_uniq` çarptı: eşzamanlı bir tekrar. Hak verilmedi.
    raise warning 'grant_ad_reward: eszamanli tekrar (transaction_id cakismasi)';
    return false;
end
$fn$;
-- @UNDO
create or replace function public.grant_ad_reward(
  p_nonce          uuid,
  p_transaction_id text,
  p_secret         text
)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_secret  text;
  v_uid     uuid;
  v_daily   int;
  v_granted int;
begin
  if p_nonce is null or p_secret is null or p_secret = '' then
    return false;
  end if;

  select value into v_secret
    from public.app_config where key = 'ad_reward_secret';

  -- FAIL-CLOSED, ve SESSİZ DEĞİL. `signup_ip_salt`'ın tersi: orada tuz yoksa
  -- kayıt AKIYOR (yanlış yapılandırma kaydı kapatmasın), burada sır yoksa
  -- ödül VERİLMİYOR (yanlış yapılandırma bedava hak basmasın).
  if v_secret is null or v_secret = '' then
    raise warning 'grant_ad_reward: ad_reward_secret yok — odul VERILMIYOR';
    return false;
  end if;
  if p_secret <> v_secret then
    return false;
  end if;

  -- TEKRAR OYNATMA (replay), aynı nonce: AdMob geri çağrıyı yeniden denemiş.
  -- BAŞARI dönüyoruz ki edge fonksiyonu 200 dönsün ve AdMob sonsuz döngüye
  -- girmesin. İkinci bir hak verilmiyor.
  if p_transaction_id is not null and exists (
       select 1 from public.ad_rewards r
        where r.nonce = p_nonce
          and r.status = 'granted'
          and r.transaction_id = p_transaction_id) then
    return true;
  end if;

  -- Aynı işlem kimliği BAŞKA bir nonce'ta: meşru AdMob trafiğinde olmayan bir
  -- durum. Suistimal sinyali olarak loglanıp reddediliyor.
  if p_transaction_id is not null and exists (
       select 1 from public.ad_rewards r
        where r.transaction_id = p_transaction_id
          and r.nonce <> p_nonce) then
    raise warning 'grant_ad_reward: islem kimligi baska bir nonce ile kullanilmis';
    return false;
  end if;

  select r.user_id into v_uid
    from public.ad_rewards r
   where r.nonce = p_nonce and r.status = 'pending';
  if v_uid is null then
    return false;               -- bilinmeyen, süresi geçmiş ya da harcanmış
  end if;

  -- `consume_ai_use` ile AYNI kilit: ödül verme ile tüketim araya girmiyor,
  -- yani kullanıcı ödülü alırken aynı anda harcayamıyor.
  perform pg_advisory_xact_lock(hashtext('ai_quota'), hashtext(v_uid::text));

  -- Günlük tavan VERME ANINDA yeniden kontrol ediliyor: `start_ad_reward`
  -- ile geri çağrı arasında geçen sürede kullanıcı başka bir reklam
  -- tamamlamış olabilir.
  v_daily := public.config_int('ad_reward_daily', 3);
  select count(*)::int into v_granted
    from public.ad_rewards r
   where r.user_id = v_uid
     and r.status = 'granted'
     and (r.granted_at at time zone 'Europe/Istanbul')::date
         = public.istanbul_day();
  if v_granted >= v_daily then
    return false;
  end if;

  update public.ad_rewards r
     set status = 'granted',
         granted_at = now(),
         transaction_id = p_transaction_id
   where r.nonce = p_nonce and r.status = 'pending';

  return true;
exception
  when unique_violation then
    -- `ad_rewards_txn_uniq` çarptı: eşzamanlı bir tekrar. Hak verilmedi.
    raise warning 'grant_ad_reward: eszamanli tekrar (transaction_id cakismasi)';
    return false;
end
$fn$;
