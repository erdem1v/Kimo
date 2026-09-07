-- 0052 — Anonim temizlik, askıdaki e-posta dönüşümünü ESİRGEMELİ (Task 03,
-- bulgu 5.3'ün sunucu ayağı).
--
-- SENARYO: kullanıcı 6. gün kayıt olur (`convertToPermanent`), sunucuda
-- e-posta onayı açık olduğu için adres `email_change` alanında askıda kalır
-- ve `profiles.is_anonymous` doğrulama tamamlanana dek true kalır. 7. gün
-- temizlik koşarsa bu kullanıcı "hiç hesap açmamış anonim" ile aynı listeye
-- düşer ve ARŞİVİYLE BİRLİKTE silinir — dönüşümü BAŞLATMIŞ bir kullanıcının
-- verisi kaybolur.
--
-- ÇÖZÜM: aday listesi `auth.users`'a bakarak dönüşüm girişimi olanları dışarır.
-- Süresiz de esirgemiyoruz: değişiklik postası 30 günden eskiyse kullanıcı
-- dönmemiştir; aday olmaya geri döner.
create or replace function public.stale_anonymous_users(p_days int default 7)
returns table (user_id uuid)
language sql stable security definer set search_path = public
as $$
  select p.id
    from public.profiles p
    join auth.users u on u.id = p.id
   where p.is_anonymous
     and p.created_at < now() - make_interval(days => greatest(p_days, 1))
     -- Kalıcı adresi olan (dönüşümü bitmiş) kullanıcı zaten anonim sayılmaz;
     -- yine de kemer-askı: e-postası oluşmuşsa listeye girmesin.
     and u.email is null
     -- Dönüşüm GİRİŞİMİ olanlar (askıdaki adres) korunur…
     and (
       coalesce(u.email_change, '') = ''
       -- …ama sonsuza dek değil: 30 günde onaylanmamış girişim terk edilmiştir.
       or u.email_change_sent_at < now() - interval '30 days'
     );
$$;

revoke execute on function public.stale_anonymous_users(int)
  from public, anon, authenticated;

comment on function public.stale_anonymous_users(int) is
  'Süresi dolmuş anonim hesapların kimlikleri. Yalnızca servis rolü çağırır '
  '(cleanup-anonymous edge fonksiyonu). Askıda e-posta dönüşümü olan hesaplar '
  '30 güne kadar esirgenir (0052).';
