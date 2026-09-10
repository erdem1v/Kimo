-- 0060 — Aynı fotoğraf iki kez ödenmesin: sonuç önbelleği
--
-- NEDEN: bugün aynı fotoğraf iki kez gönderilirse iki kez ödeniyor. Ne
-- bellekte ne veritabanında hiçbir önbellek yok. Bunun en sık tetikleyicisi
-- ürünün kendi akışı: kullanıcı "Vazgeç"e basıyor ama istek İPTAL EDİLMİYOR
-- (`functions.invoke` iptal kabul etmiyor), yani hak harcanıyor ve sonuç
-- çöpe gidiyor; kullanıcı aynı fotoğrafla devam edince ikinci kez ödüyoruz.
--
-- İstemci tarafındaki yarısı çözüldü (`capture_screen._pendingAnalysis` sonucu
-- oturum içinde saklıyor). Bu göç ikinci yarısı: oturumlar arası, cihazlar
-- arası ve istemci çöktüğünde de çalışan sunucu tarafı.
--
-- KONTROL KOTADAN ÖNCE OLMAK ZORUNDA. Önbellek isabetinde `consume_ai_use`
-- HİÇ çağrılmıyor: amaç ücretin çıkmasını engellemek, sonradan iade etmek
-- değil. Bu yüzden hash de istemcide değil sunucuda hesaplanıyor — istemcinin
-- söylediği bir hash'e güvenmek, başkasının sonucunu çekmeye çalışmak için
-- yüzey açardı (yine de kullanıcıya kilitli, ama tasarımı zayıflatırdı).
--
-- KAPSAM KULLANICIYA KİLİTLİ. Küresel bir önbellek daha çok tasarruf ederdi
-- (aynı test kitabı sorusu binlerce kez çekiliyor olabilir) ama bir kullanıcı,
-- elindeki bir fotoğrafın başkası tarafından analiz edilip edilmediğini
-- ölçebilirdi. Tasarruf o yüzeye değmez.
--
-- Geri alma:
--   drop function public.ai_cache_put(text, text, jsonb);
--   drop function public.ai_cache_get(text, text);
--   drop function public.prune_ai_result_cache();
--   drop table public.ai_result_cache;
--   select cron.unschedule(jobid) from cron.job where jobname = 'ai-cache-prune';

create table if not exists public.ai_result_cache (
  user_id      uuid  not null references auth.users(id) on delete cascade,
  photo_sha256 bytea not null,
  curriculum   text  not null,
  result       jsonb not null,
  created_at   timestamptz not null default now(),
  primary key (user_id, photo_sha256, curriculum)
);

create index if not exists ai_result_cache_created_idx
  on public.ai_result_cache (created_at);

alter table public.ai_result_cache enable row level security;
-- Politika YOK = yalnızca definer fonksiyonlar erişir. Kullanıcı kendi
-- satırını bile doğrudan okuyamaz: okuma yolu `ai_cache_get`, çünkü TTL
-- kararını da o veriyor.
revoke all on public.ai_result_cache from public, anon, authenticated;

comment on table public.ai_result_cache is
  'Fotoğraf hash''i → analiz sonucu. Aynı fotoğrafın ikinci kez ÜCRETLENMESİNİ '
  'engeller (iptal edilen istek, çöken istemci, cihaz değişimi). Kapsam '
  'kullanıcıya kilitli: küresel önbellek, bir fotoğrafın başkasınca analiz '
  'edilip edilmediğini ölçme yüzeyi açardı. 24 saat sonra bayat sayılır, '
  '48 saatte silinir.';

-- ---------------------------------------------------------------- okuma
-- Hash HEX METİN olarak alınıyor, bytea olarak değil: bytea'yı PostgREST
-- gövdesinden geçirmek kaçış kurallarına bağlı ve sessiz bozulmaya açık.
-- Dönüş `null` = isabet yok (hiç yazılmamış ya da bayatlamış).
create or replace function public.ai_cache_get(
  p_sha_hex    text,
  p_curriculum text
)
returns jsonb
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_out jsonb;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_sha_hex !~ '^[0-9a-f]{64}$' then
    -- Bozuk hash sessizce "isabet yok" olmuyor: çağıran bizim edge
    -- fonksiyonumuz, oraya geçersiz bir değer gidiyorsa bilmek istiyoruz.
    raise exception 'gecersiz hash' using errcode = '22023';
  end if;

  select c.result into v_out
    from public.ai_result_cache c
   where c.user_id = v_uid
     and c.photo_sha256 = decode(p_sha_hex, 'hex')
     and c.curriculum = p_curriculum
     and c.created_at > now() - interval '24 hours';

  return v_out;
end
$fn$;

revoke execute on function public.ai_cache_get(text, text) from public, anon;
grant  execute on function public.ai_cache_get(text, text) to authenticated;

-- ---------------------------------------------------------------- yazma
create or replace function public.ai_cache_put(
  p_sha_hex    text,
  p_curriculum text,
  p_result     jsonb
)
returns void
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_sha_hex !~ '^[0-9a-f]{64}$' then
    raise exception 'gecersiz hash' using errcode = '22023';
  end if;

  insert into public.ai_result_cache (user_id, photo_sha256, curriculum, result)
  values (v_uid, decode(p_sha_hex, 'hex'), p_curriculum, p_result)
  on conflict (user_id, photo_sha256, curriculum) do update
     set result = excluded.result,
         created_at = now();
end
$fn$;

revoke execute on function public.ai_cache_put(text, text, jsonb) from public, anon;
grant  execute on function public.ai_cache_put(text, text, jsonb) to authenticated;

-- --------------------------------------------------------------- budama
-- TTL 24 saat ama silme 48'de: bayat satır zaten okunmuyor, hemen silmek
-- gereksiz yazma yükü. Fotoğraf hash'i kişisel veri sayılabilir (bir
-- kullanıcının hangi fotoğrafı çektiğini işaretler), süresiz durmasın.
create or replace function public.prune_ai_result_cache()
returns void
language sql
security definer set search_path = public
as $fn$
  delete from public.ai_result_cache where created_at < now() - interval '48 hours';
$fn$;

revoke execute on function public.prune_ai_result_cache()
  from public, anon, authenticated;

do $cron$
begin
  perform cron.unschedule(jobid)
    from cron.job where jobname = 'ai-cache-prune';
exception when others then
  null;
end
$cron$;

-- Her gece 03:45 Istanbul = 00:45 UTC.
select cron.schedule(
  'ai-cache-prune',
  '45 0 * * *',
  $$select public.prune_ai_result_cache()$$
);
