-- 0028 — send-push kimlik doğrulaması: paylaşılan sır yerine gerçek JWT
--
-- SORUN (denetim H7): send-push `--no-verify-jwt` ile yayımlanmıştı, yani
-- kimlik doğrulamasız olarak internete açıktı. Tek sınır `x-push-secret`
-- başlığıydı ve fonksiyon o sınırı şöyle koruyordu:
--   • 401 gövdesi sunucudaki sırrın TAM UZUNLUĞUNU yayınlıyordu
--   • karşılaştırma `!==` ile yapılıyordu (sabit zamanlı değil)
--   • hiçbir deneme sınırı yoktu
--   • gövdeden gelen user_id/title/body/kind doğrulanmadan FCM'e gidiyordu
--   • fonksiyon servis rolü anahtarıyla çalışıyordu
--
-- ÇÖZÜM: sırrı sertleştirmek yerine SINIFI ORTADAN KALDIRMAK. verify_jwt geri
-- açılıyor (bkz. supabase/config.toml) ve veritabanı çağrıyı gerçek bir
-- service_role JWT'siyle imzalıyor. Doğrulamayı artık Supabase ağ geçidi,
-- fonksiyon HİÇ ÇALIŞMADAN yapıyor: uzunluk sızıntısı, zamanlama kanalı ve
-- kaba kuvvet denemeleri tek hamlede yok oluyor.
--
-- KURULUM (bu göçten sonra, bir kez):
--   insert into public.app_config (key, value)
--   values ('push_service_key', '<SUPABASE_SERVICE_ROLE_KEY>')
--   on conflict (key) do update set value = excluded.value;
--   delete from public.app_config where key = 'push_secret';   -- artık kullanılmıyor
--
-- Ve edge function yeniden yayımlanmalı — artık bayrak GEREKMİYOR:
--   supabase functions deploy send-push
--
-- NOT: servis jetonu app_config'te duruyor. Orada bugüne kadar duran
-- push_secret de fiilen aynı güce sahipti (herkese sahte bildirim). app_config
-- sıfır politikayla kilitli ve bir önceki göçte grant'ları da geri alındı.

-- --------------------------------------------------------------- net şeması
-- pg_net gönderdiği isteklerin BAŞLIKLARINI net şemasındaki kuyruk tablosunda
-- saklıyor — yani Authorization başlığı oraya da yazılıyor. Uygulama net.*
-- fonksiyonlarını hiç çağırmıyor (yalnızca definer olan send_push çağırıyor,
-- o da postgres olarak çalışıyor), dolayısıyla anon/authenticated erişimini
-- kaldırmak hiçbir şeyi kırmaz. service_role bilerek dokunulmadan bırakıldı.
--
-- Geri alma: grant usage on schema net to anon, authenticated;
do $mig$
begin
  if exists (select 1 from pg_namespace where nspname = 'net') then
    execute 'revoke all on schema net from public, anon, authenticated';
    execute 'revoke all on all tables in schema net from public, anon, authenticated';
    execute 'revoke all on all functions in schema net from public, anon, authenticated';
  end if;
end
$mig$;

-- ------------------------------------------------------------------ send_push
-- İmza 0023'teki ile AYNI (4 parametre). Farklı imza = ayrı fonksiyon demek
-- olurdu ve çağrılar belirsiz kalırdı (bkz. 0014/0015 dersi).
create or replace function public.send_push(
  p_user  uuid,
  p_kind  text,
  p_actor text,
  p_extra text default null
)
returns void
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_url    text;
  v_key    text;
  v_mascot text;
  v_line   text;
  v_title  text;
begin
  select value into v_url from public.app_config where key = 'push_url';
  select value into v_key from public.app_config where key = 'push_service_key';

  if v_url is null or v_key is null then
    -- Yapılandırılmadıysa bildirim gönderilmez; asıl işlem etkilenmez. Ama
    -- SESSİZ kalmıyor: eksik yapılandırma sunucu günlüğüne düşsün, yoksa
    -- "hiç bildirim gitmiyor" durumu teşhis edilemez hâle geliyor.
    raise warning 'send_push: app_config eksik (push_url ve/veya push_service_key)';
    return;
  end if;

  select coalesce(mascot, 'ev_hanimi') into v_mascot
    from public.profiles where id = p_user;

  select replace(
           replace(
             replace(line, '{ad}', coalesce(p_actor, 'Bir arkadaşın')),
             '{lig}', coalesce(p_extra, '')),
           '{n}', coalesce(p_extra, ''))
    into v_line
    from public.push_lines
   where kind = p_kind and mascot = coalesce(v_mascot, 'ev_hanimi')
   order by random()
   limit 1;

  if v_line is null then
    return;
  end if;

  v_title := case p_kind
               when 'question_received' then 'Sana soru geldi 📨'
               when 'friend_request'    then 'Arkadaşlık isteği 🤝'
               when 'question_solved'   then 'Soru çözüldü ✅'
               when 'friend_league_up'  then 'Arkadaşın yükseliyor 🏆'
               when 'friend_streak'     then 'Arkadaşın seri yapıyor 🔥'
               else 'AI YKS Coach'
             end;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 -- Ağ geçidi bunu doğrular; fonksiyon ayrıca role iddiasını
                 -- kontrol eder. x-push-secret KALDIRILDI.
                 'Authorization', 'Bearer ' || v_key
               ),
    body    := jsonb_build_object(
                 'user_id', p_user,
                 'title',   v_title,
                 'body',    v_line,
                 'kind',    p_kind
               )
  );
exception when others then
  -- Bildirim hatası asıl işlemi bozmasın (mevcut ve doğru karar), ama iz bıraksın.
  raise warning 'send_push başarısız: %', sqlerrm;
  return;
end
$fn$;

revoke execute on function public.send_push(uuid, text, text, text)
  from public, anon, authenticated;
