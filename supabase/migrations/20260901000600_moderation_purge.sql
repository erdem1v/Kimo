-- 0031 — "Kaldırıldı" gerçekten kaldırır (Değişmez 3'ün ikinci yarısı)
--
-- 0030 yeni imzalı bağlantı üretimini durdurdu (can_read_mistake_photo artık
-- moderation <> 'removed' arıyor). Ama HALİHAZIRDA DAĞITILMIŞ imzalı bağlantı
-- çalışmaya devam eder: Supabase imzayı üretim anında doğrular, her istekte
-- değil. Değişmez 3 bunu açıkça kapsıyor ("elinde önceden imzalı bağlantı olan
-- kullanıcı dahil"), dolayısıyla nesnenin kendisi silinmeli.
--
-- Silme işini kim yapıyor: moderatörün istemcisi, karar RPC'si döndükten hemen
-- sonra. Alternatif — veritabanından pg_net ile depolama API'sini çağıran yeni
-- bir Edge Function — daha sağlam olurdu ama yeni bir servis rolü yüzeyi ve yeni
-- bir sessiz hata kaynağı açardı; H7 tam da bu kalıptan çıktı. Bunun yerine:
-- istemci siler, `photo_purged_at` iz bırakır, ve aşağıdaki kuyruk fonksiyonu
-- yarım kalanları görünür kılar (sessizce kaybolmazlar).
--
-- ARTIK RİSK, açıkça: moderatörün istemcisi silme adımından önce çökerse nesne
-- kalır. O durumda yeni imzalı bağlantı ÜRETİLEMEZ (0030) ama eski bağlantı
-- ömrü dolana kadar çalışır. Kuyruk bu satırları listeler.

alter table public.mistakes
  add column if not exists photo_purged_at timestamptz;

comment on column public.mistakes.photo_purged_at is
  'Moderasyonla kaldırılan içeriğin depolama nesnesinin silindiği an. NULL + '
  'moderation=''removed'' = temizlik bekliyor (bkz. admin_photo_purge_queue).';

create index if not exists mistakes_purge_pending_idx
  on public.mistakes (moderation)
  where moderation = 'removed' and photo_purged_at is null;

-- ------------------------------------------------- moderatör silme politikası
-- Moderatör başkasının klasöründeki nesneyi silebilmeli; init'teki "Kendi
-- fotolarını sil" yalnızca kendi klasörünü kapsıyor.
drop policy if exists "moderator can purge mistake photos" on storage.objects;
create policy "moderator can purge mistake photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'mistake-photos' and public.is_admin());

-- ------------------------------------------------------------------- kuyruk
-- Kaldırılmış ama nesnesi hâlâ duran içerikler. Moderasyon ekranı bunu
-- yarım kalan temizlikleri tamamlamak için kullanır.
create or replace function public.admin_photo_purge_queue()
returns table (mistake_id uuid, photo_path text, removed_at timestamptz)
language sql stable security definer set search_path = public
as $fn$
  select m.id, m.photo_path, m.created_at
    from public.mistakes m
   where public.is_admin()
     and m.moderation = 'removed'
     and m.photo_path is not null
     and m.photo_purged_at is null
   order by m.created_at;
$fn$;

revoke execute on function public.admin_photo_purge_queue() from public, anon;
grant  execute on function public.admin_photo_purge_queue() to authenticated;

-- ------------------------------------------------------ temizlendi işareti
create or replace function public.admin_mark_photo_purged(p_id uuid)
returns void
language plpgsql security definer set search_path = public
as $fn$
begin
  if not public.is_admin() then
    raise exception 'yetkisiz';
  end if;
  update public.mistakes
     set photo_purged_at = now()
   where id = p_id;
end
$fn$;

revoke execute on function public.admin_mark_photo_purged(uuid) from public, anon;
grant  execute on function public.admin_mark_photo_purged(uuid) to authenticated;

-- ---------------------------------------------------- kuyruğa fotoğraf yolu
-- admin_pending_reports zaten photo_path döndürüyor, admin_all_questions da.
-- Yani moderatörün istemcisi karar anında yolu elinde tutuyor ve ek bir sorguya
-- ihtiyaç duymadan nesneyi silebiliyor. Buraya yeni bir kolon eklemiyorum.
