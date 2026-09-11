-- 0076 — Ödüllü reklam: sunucu tarafı doğrulanmış ödül (Task 10)
--
-- ÜRÜN: hak bittiğinde kullanıcı İSTEYEREK bir ödüllü reklam izleyip 1 analiz
-- hakkı kazanabiliyor. Günde en fazla 3. Interstitial, banner ve açılış
-- reklamı YOK.
--
-- KİLİT ŞART: "reklamı izledim" iddiası İSTEMCİDEN GELEMEZ. Task 01'in
-- değişmezi — hiçbir sayaç istemciden yazılmaz — burada da geçerli.
-- AdMob'un sunucu tarafı doğrulaması (SSV) kullanılıyor:
--
--   istemci                      sunucu                            AdMob
--     │ start_ad_reward() ─────────►│  pending satır + nonce
--     │◄──────────── nonce (uuid)   │
--     │ customData = nonce          │
--     │ reklamı göster ──────────────────────────────────────────────►│
--     │                             │◄── GET /ad-reward?…&signature=…&key_id=…
--     │                             │    ECDSA imzası doğrulanır →
--     │                             │    grant_ad_reward(nonce, txid, secret)
--     │ my_daily_state'i yoklar ───►│
--
-- Nonce SUNUCUNUN ürettiği bir uuid: istemci uyduramıyor. AdMob'un `userId`
-- alanı istemciden geldiği için tek başına güvenilmez; bağlayıcı olan
-- `custom_data`'daki nonce. (Edge fonksiyonu Supabase kullanıcı kimliğini
-- AdMob'a HİÇ göndermiyor — ham bir uid reklam ağının sorgu dizesinde
-- hukuki metinlerde sayılması gereken bir veri paylaşımı olurdu.)
--
-- ========================= NEDEN SERVİS ROLÜ DEĞİL =========================
--
-- `delete-account/index.ts`'teki "bu depodaki TEK servis rolü yüzeyi" yorumu
-- BAYAT: `delete-question`, `cleanup-anonymous`, `scan-photos` ve `send-push`
-- de servis rolü anahtarını okuyor (beş fonksiyon). Korunmaya değer değişmez
-- "tek servis rolü yüzeyi" değil:
--
--     HİÇBİR DOĞRULAMASIZ (verify_jwt = false) FONKSİYON
--     SERVİS ROLÜ İSTEMCİSİ KURMAZ.
--
-- `ad-reward` depodaki ilk doğrulamasız fonksiyon olacak. Orada bir hata
-- (loglanan bir istemci yapılandırması, kopyalanmış bir yardımcı, başlık
-- ileten bir SSRF) servis rolü anahtarıyla TÜM veritabanına dönüşürdü.
-- Bu yüzden ödül verme yolu `anon`-çağrılabilir TEK bir RPC ve paylaşılan
-- bir sır:
--
--   sır sızarsa hasar  : bedava reklam hakkı.
--   anahtar sızarsa    : her satır + auth.admin.deleteUser.
--
-- DÜRÜST KAYIT: Supabase servis rolü anahtarını HER edge fonksiyonunun
-- ortamına enjekte ediyor ve bunu kapatmak mümkün değil. "Fonksiyon anahtarı
-- taşımıyor" ifadesi yalnızca "hiçbir kod yolu onu okumuyor" anlamında doğru;
-- isolate içinde rastgele kod yürütmeye karşı YALITIM DEĞİL. Kazanç kazara
-- yolları kaldırmak. Bu yüzden `ad-reward` minik ve bağımlılıksız kalacak:
-- `createClient` import etmiyor, `analyze-question` gibi çıplak `fetch`.
--
-- ========================== SIR: app_config, FAIL-CLOSED ====================
--
-- `ad_reward_secret` TOHUMLANMIYOR — bir sırrın göç dosyasında yeri yok.
-- Elle girilmeli:
--
--   insert into public.app_config (key, value)
--   values ('ad_reward_secret', '<uzun rastgele dize>')
--   on conflict (key) do update set value = excluded.value;
--
-- Aynı değer edge fonksiyonuna `AD_REWARD_SECRET` gizlisi olarak verilmeli.
-- ANAHTAR YOKSA ÖDÜL VERİLMİYOR (fail-closed) — `signup_ip_salt`'ın (0058)
-- tam TERSİ ve bilinçli: kota sayıları fail-open çünkü yanlış yapılandırılmış
-- bir ortam analizi kapatmasın; kimlik doğrulama sırrı fail-closed çünkü
-- açık kalmak bedava hak basmak olurdu.

-- ====================================================== ödül başlat
-- BEKLEYEN SATIRLAR 3/GÜN BÜTÇESİNİ TÜKETMİYOR — yalnızca `granted` satırlar.
-- Yani reklamı açıp vazgeçmek BEDAVA; kullanıcı bir slot yakmıyor. Betik
-- suistimali üç ayrı katmanla kapalı:
--
--   1. `ad_rewards_one_pending` KISMİ TEKİL İNDEKSİ (0075) — "kullanıcı
--      başına en fazla bir canlı bekleyen satır" bir ŞEMA değişmezi, fonksiyon
--      mantığı değil. Taze bir bekleyen satır varsa AYNI nonce dönüyor, yani
--      ağ kesintisine karşı idempotent ve tablo bekleyen satırdan büyüyemiyor.
--   2. `bump_rate_limit` ile başlangıç hız sınırı — deponun MEVCUT primitifi
--      (0040). Yeni bir sayaç icat etmiyoruz.
--   3. İŞE YARAMAYACAKSA REDDETME — `ai_state()` okunuyor.
create or replace function public.start_ad_reward()
returns table (ok boolean, ad_nonce uuid, reason text)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid      uuid := auth.uid();
  v_s        record;
  v_ttl      int;
  v_existing uuid;
  v_new      uuid;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  v_ttl := public.config_int('ad_pending_ttl_min', 5);

  -- Süresi geçmiş kendi bekleyen satırlarını temizle. Yalnızca KENDİ
  -- satırları: başkasının bekleyenini silmek bir yarış penceresi açardı.
  delete from public.ad_rewards r
   where r.user_id = v_uid
     and r.status = 'pending'
     and r.created_at < now() - make_interval(mins => v_ttl);

  -- Taze bekleyen varsa aynı nonce. İSTİSNA DEĞİL: kullanıcı reklamı
  -- yüklerken bağlantısı koptuysa ikinci dokunuş çalışmalı.
  select r.nonce into v_existing
    from public.ad_rewards r
   where r.user_id = v_uid and r.status = 'pending'
   limit 1;
  if v_existing is not null then
    return query select true, v_existing, 'pending'::text;
    return;
  end if;

  select * into v_s from public.ai_state();
  if v_s is null then
    return query select false, null::uuid, 'no_state'::text;
    return;
  end if;

  -- REDDETME SEBEPLERİ. İstisna değil ÜRÜN DURUMU dönüyor — `consume_ai_use`
  -- ile aynı disiplin. `ad_offer` (0075) arayüzde düğmeyi zaten çizmiyor;
  -- burası İKİNCİ katman, çünkü bir düğmenin çizilmemesi bir güvenlik
  -- kontrolü değil.
  if v_s.ai_state = 'suspended' then
    return query select false, null::uuid, 'suspended'::text;
    return;
  end if;
  if v_s.ai_tier <> 'free' then
    -- premium reklam görmemek için ödedi; anonim bir para kazanma yüzeyi
    -- değil (yeni anonim oturum bedava, ödül vermek sıfırlama yolu olurdu).
    return query select false, null::uuid, 'not_free_tier'::text;
    return;
  end if;
  if v_s.ai_month_left <= 0 then
    -- KULLANILAMAYACAK BİR ÖDÜL İÇİN REKLAM GÖSTERİLMİYOR. Aylık cap sert
    -- maliyet tavanı; ödül pencereyi açıyor, cap'i AÇMIYOR.
    return query select false, null::uuid, 'month_full'::text;
    return;
  end if;
  if v_s.ad_rewards_left <= 0 then
    return query select false, null::uuid, 'no_rewards_left'::text;
    return;
  end if;
  if v_s.ai_window_left > 0 then
    -- Elinde hak varken reklam teklif etmek reklam hasadı olurdu.
    return query select false, null::uuid, 'not_needed'::text;
    return;
  end if;

  -- Günlük tavanın dört katı başlangıç: vazgeçmek bedava kalsın ama bir
  -- betik sonsuz nonce üretmesin. `bump_rate_limit` herkesten revoke
  -- (0040:171) ve yalnızca definer fonksiyonlardan çağrılabiliyor.
  if not public.bump_rate_limit(
           'ad_start',
           public.config_int('ad_reward_daily', 3) * 4,
           public.istanbul_day()::text) then
    return query select false, null::uuid, 'too_many_attempts'::text;
    return;
  end if;

  begin
    insert into public.ad_rewards (user_id, nonce)
    values (v_uid, gen_random_uuid())
    returning public.ad_rewards.nonce into v_new;
  exception
    when unique_violation then
      -- Eşzamanlı iki `start` çağrısı; kısmi tekil indeks kazananı seçti.
      select r.nonce into v_new
        from public.ad_rewards r
       where r.user_id = v_uid and r.status = 'pending'
       limit 1;
      if v_new is null then
        return query select false, null::uuid, 'race'::text;
        return;
      end if;
  end;

  return query select true, v_new, 'ok'::text;
end
$fn$;

revoke execute on function public.start_ad_reward() from public, anon;
grant  execute on function public.start_ad_reward() to authenticated;

comment on function public.start_ad_reward() is
  'Ödüllü reklam için sunucu tarafı nonce üretir (AdMob customData). Bekleyen '
  'satır günlük tavanı TÜKETMEZ; yalnızca verilmiş ödüller sayılır. İşe '
  'yaramayacaksa (ay dolu, premium, anonim, hak var) reddeder.';

-- ====================================================== ödülü ver
-- YALNIZCA `anon`: AdMob'un geri çağrısında kullanıcı JWT'si yok. Paylaşılan
-- sır yetkilendirme, nonce ise hangi kullanıcıya hangi ödülün gideceğini
-- belirleyen bağ. İkisi ayrı işler ve ikisi de gerekli.
--
-- `authenticated`'tan REVOKE edilmesi bu paketin EN ÖNEMLİ tek satırı:
-- açık olsaydı istemci kendi hakkını basar ve tüm SSV tasarımı dekora
-- dönerdi. `supabase/tests/300_ad_reward.sql` ve
-- `supabase/mutations/32_grant_ad_reward_open.sql` tam bunu sınıyor.
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

-- ÇIPLAK BOOLEAN DÖNÜYOR: hangi kontrolün düştüğünü söyleyen bir oracle yok.
revoke execute on function public.grant_ad_reward(uuid, text, text)
  from public, authenticated;
grant  execute on function public.grant_ad_reward(uuid, text, text) to anon;

comment on function public.grant_ad_reward(uuid, text, text) is
  'AdMob SSV geri çağrısının ödülü verdiği tek yol. YALNIZCA anon çağırabilir '
  '(geri çağrıda kullanıcı JWT''si yok); yetkilendirme app_config.'
  'ad_reward_secret ile. transaction_id üzerinde idempotent. Sır yoksa '
  'ödül VERİLMEZ (fail-closed).';

-- ====================================================== budama
create or replace function public.prune_ad_rewards()
returns void language sql security definer set search_path = public
as $fn$
  delete from public.ad_rewards r
   where (r.status = 'pending' and r.created_at < now() - interval '1 day')
      or (r.status = 'granted' and r.granted_at < now() - interval '92 days');
$fn$;

revoke execute on function public.prune_ad_rewards()
  from public, anon, authenticated;

comment on function public.prune_ad_rewards() is
  'Bir günden eski bekleyen ve 92 günden eski verilmiş ödül satırlarını siler.';
