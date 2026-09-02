-- 0032 — Avatar kovası yetkisi + profiles_public'ten yol sızıntısının kapatılması
--
-- SORUN (H5): `avatars readable` politikası şuydu:
--     using (bucket_id = 'avatars')
-- Sahiplik ya da ilişki kontrolü yok — oturum açmış HERKES tüm kovayı
-- listeleyebiliyor ve içindeki her nesneye imzalı URL üretebiliyordu. Buna
-- kullanıcının "sildiği" avatarlar da dahil: removeAvatar yalnızca DB sütununu
-- null'lıyor, nesneyi hiç silmiyordu (Değişmez 4 ihlali).
--
-- İkinci yarısı: profiles_public görünümü avatar_path'i HERKES için döndürüyordu
-- ve görünüm authenticated'a doğrudan SELECT açık. Yani `select * from
-- profiles_public` tüm kullanıcı tabanının depolama nesne yollarını birlikte
-- döküyordu.
--
-- ÇÖZÜM — ve buradaki tercih PLANDAN SAPIYOR, sebebini yazıyorum:
-- Plan "avatar_path'i görünümden tamamen çıkar" diyordu. Uygularken kontrol
-- ettim: arkadaş listesi (social_screen.dart:82) profilleri profilesByIds ile,
-- yani TAM DA bu görünümden çekiyor. Kolonu tümden çıkarmak arkadaş listesindeki
-- ve profil kartlarındaki avatarları da söndürürdü — planda "arkadaş listesi
-- etkilenmez" demiştim, o yanlıştı.
--
-- Bunun yerine kolon İLİŞKİYE BAĞLANDI: kendin ve kabul edilmiş arkadaşların
-- için dolu, yabancılar için null. Güvenlik amacı aynen sağlanıyor (toplu döküm
-- artık yol sızdırmıyor) ama ürün gerilemiyor. Lig sıralaması avatarı zaten
-- ayrı bir yerden (my_league_board) alıyor, o da etkilenmiyor.

-- ======================================================= avatar okuma yetkisi
-- Sahiplik yolun KENDİSİNDEN türetiliyor (mistake-photos'taki ilkenin aynısı).
-- Başkasının avatarı yalnızca PROFİLDE O AN DURAN dosyaysa ve aranızda bir
-- ilişki varsa okunabilir — yani kullanıcının değiştirdiği/sildiği eski dosya
-- kimseye açılmaz, kova listelenemez.
create or replace function public.can_read_avatar(p_name text)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select
    -- kendi klasörün
    (storage.foldername(p_name))[1] = auth.uid()::text
    or exists (
      select 1
        from public.profiles p
       where p.avatar_path = p_name          -- yalnızca GÜNCEL avatar
         and (
           p.id = auth.uid()
           or public.are_friends(p.id, auth.uid())
           -- bu haftaki lig grubundaki kişiler (my_league_board avatar döndürüyor)
           or exists (
             select 1
               from public.league_members m1
               join public.league_members m2 on m2.cohort_id = m1.cohort_id
               join public.league_cohorts c  on c.id = m1.cohort_id
              where m1.user_id = p.id
                and m2.user_id = auth.uid()
                and c.week_start = (date_trunc('week',
                      now() at time zone 'Europe/Istanbul'))::date
           )
         )
    );
$fn$;

revoke execute on function public.can_read_avatar(text) from public, anon;
-- Politika ifadeleri ÇAĞIRANIN yetkisiyle değerlendirilir; authenticated bunu
-- çalıştırabilmeli, yoksa hiçbir avatar görünmez.
grant execute on function public.can_read_avatar(text) to authenticated;

drop policy if exists "avatars readable" on storage.objects;
create policy "avatars readable" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and public.can_read_avatar(name));

-- Yükleme / güncelleme / silme politikaları (0024) DEĞİŞMEDİ: zaten kendi
-- klasörüyle sınırlıydılar ve kullanıcının kendi dosyasını silebilmesi
-- (KVKK Md. 7 / GDPR Md. 17) için şart.

-- ==================================================== profiles_public görünümü
-- Kolon çıkarmıyoruz, İLİŞKİYE bağlıyoruz (yukarıdaki gerekçe). Kolon adı, sırası
-- ve tipi korunuyor, dolayısıyla PublicProfile.fromRow (social.dart:180)
-- değişmeden çalışıyor.
--
-- Görünüme bağlı FONKSİYON YOK (bağımlılık public_questions'ta, o ayrı) —
-- 0017'de de bir kez drop edilmişti, drop + create güvenli.
drop view if exists public.profiles_public;
create view public.profiles_public
  with (security_invoker = false)
  as select
       p.id, p.nickname, p.mascot, p.xp, p.streak, p.league,
       case
         when p.week_start = (date_trunc('week',
                now() at time zone 'Europe/Istanbul'))::date
           then p.weekly_xp
         else 0
       end as weekly_xp,
       -- Yalnızca kendin ve kabul edilmiş arkadaşların için. Yabancılar null
       -- görür: toplu döküm artık depolama yolu sızdırmıyor.
       case
         when p.id = auth.uid() or public.are_friends(p.id, auth.uid())
           then p.avatar_path
         else null
       end as avatar_path,
       (select count(*)::int
          from public.friendships f
         where f.status = 'accepted'
           and (f.requester_id = p.id or f.addressee_id = p.id)
       ) as friend_count
     from public.profiles p
    where not p.is_system;

grant select on public.profiles_public to authenticated;
