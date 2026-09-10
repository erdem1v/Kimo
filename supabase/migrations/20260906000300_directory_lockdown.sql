-- 0068 — Kullanıcı dizini kapanıyor + engellenenler listesi + profiles WITH CHECK
--
-- ÜÇ İŞ, ORTAK KONU: `profiles_public` görünümüne kimin, nasıl eriştiği.
--
-- 1) DİZİN DÖKÜLEBİLİRLİĞİ. Takma ad araması 0045'te kaldırıldı ve arkadaş
--    ekleme 6 haneli koda bağlandı; ama görünümün KENDİSİ `authenticated`'a
--    açık kaldı. 0045 bunu "bilinen ve kabul edilen sınır" diye not etmişti.
--    Uygulamayı hiç çalıştırmadan, yalnız anon anahtar + bir oturumla
--    `select * from profiles_public` sayfa sayfa bütün dizini döküyor — yani
--    aramayı kaldırmak yüzeyi kapatmamış, sadece arayüzden gizlemiş.
--
--    İstemcideki ÜÇ okuma da kimliğe göre (`social_repository.dart`:
--    myProfile / profilesByIds / profileById); lig tahtası zaten
--    `my_league_board` RPC'sinden geliyor. Yani serbest okumaya gerek yok:
--    görünüm kapanıyor, yerine üst sınırlı bir RPC geliyor.
--
-- 2) ENGELLENENLER LİSTESİ (A-8). Sunucu tarafı 0044'te hazırdı
--    (`unblock_user`, `blocks_select_own`) ama isimleri getiren bir yol yoktu.
--    `profiles_public` üzerinden okumak İKİ nedenle yanlış olurdu: görünüm
--    anonim ve sistem hesaplarını süzüyor (0047) — engellediğin anonim biri
--    listede boşluk olarak görünürdü — ve (1) ile artık okunamıyor.
--
-- 3) `profiles` UPDATE POLİTİKASINDA `WITH CHECK`.

-- ============================================ 1) görünüm kapanıyor, RPC açılıyor
create or replace function public.profiles_by_ids(p_ids uuid[])
returns table (
  id           uuid,
  nickname     text,
  mascot       text,
  xp           int,
  streak       int,
  league       text,
  weekly_xp    int,
  avatar_path  text,
  friend_count int
)
language plpgsql stable security definer set search_path = public
as $fn$
declare
  v_n int := coalesce(array_length(p_ids, 1), 0);
begin
  if auth.uid() is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  -- ÜST SINIR: dizini sayfalayarak dökmenin ucuz yolunu kapatıyor. 60, en
  -- büyük gerçek çağrının (12 kişilik lig kohortu + arkadaş listesi) rahat
  -- üstünde; arayüzde bu sınıra dayanan bir ekran yok.
  if v_n > 60 then
    raise exception 'En fazla 60 kimlik sorulabilir' using errcode = '22023';
  end if;
  if v_n = 0 then
    return;
  end if;

  -- Görünümün KENDİSİ okunuyor: avatar_path'in yalnız kendine/arkadaşına
  -- açılması ve sistem/anonim süzgeci orada tanımlı. Kuralı burada tekrar
  -- yazmak ikinci bir kopya yaratırdı.
  return query
    select v.id, v.nickname, v.mascot, v.xp, v.streak, v.league,
           v.weekly_xp, v.avatar_path, v.friend_count
      from public.profiles_public v
     where v.id = any (p_ids);
end
$fn$;

revoke execute on function public.profiles_by_ids(uuid[]) from public, anon;
grant  execute on function public.profiles_by_ids(uuid[]) to authenticated;

comment on function public.profiles_by_ids(uuid[]) is
  'Kimliğe göre herkese açık profiller. profiles_public görünümünün TEK '
  'istemci kapısı: görünüm 0068''de authenticated''a kapatıldı, çünkü serbest '
  'select ile bütün dizin dökülebiliyordu.';

revoke select on public.profiles_public from authenticated, anon, public;

comment on view public.profiles_public is
  'Herkese açık profil alanları. İSTEMCİ DOĞRUDAN OKUYAMAZ (0068): tek kapı '
  'profiles_by_ids(uuid[]) ve my_league_board(). Serbest metin araması yok; '
  'arkadaş ekleme add_friend_by_code ile yapılır.';

-- Arama kalktığında unutulan yetim index (0005). Hiçbir sorgu kullanmıyor.
drop index if exists public.profiles_nickname_lower_idx;

-- ================================================ 2) engellenenler listesi (A-8)
-- `profiles` TABLOSUNDAN okuyor, görünümden değil: engellediğin kişi anonim
-- ya da sistem hesabı olsa bile listede görünmeli, yoksa kullanıcı kaldıramaz.
-- Avatar BİLEREK dönmüyor: engellenen kişinin fotoğrafını göstermek için bir
-- sebep yok, baş harf yeterli.
create or replace function public.my_blocked_users()
returns table (
  id         uuid,
  nickname   text,
  mascot     text,
  blocked_at timestamptz
)
language sql stable security definer set search_path = public
as $fn$
  select p.id,
         coalesce(p.nickname, 'Öğrenci'),
         p.mascot,
         b.created_at
    from public.user_blocks b
    join public.profiles p on p.id = b.blocked_id
   where b.blocker_id = auth.uid()
   order by b.created_at desc;
$fn$;

revoke execute on function public.my_blocked_users() from public, anon;
grant  execute on function public.my_blocked_users() to authenticated;

comment on function public.my_blocked_users() is
  'Çağıranın engellediği kişiler. auth.uid()''e kilitli, parametre almıyor — '
  'kimin kimi engellediği sorulamaz.';

-- ======================================== 3) profiles UPDATE: WITH CHECK eklendi
-- BUGÜN İSTİSMAR EDİLEBİLİR DEĞİL: koruma sütun düzeyi ayrıcalıklarda ve
-- `id` yazılabilir değil. Ama savunma tek katmana dayanıyordu.
--
-- TUZAK (Task 01, 0030:44-49): `WITH CHECK`''i olmayan bir UPDATE
-- politikasında `USING` YENİ satır için de uygulanır. `with check` eklendiği
-- anda o örtük koruma kaybolur — bu yüzden sahiplik koşulu AÇIKÇA yeniden
-- yazılıyor. Task 01 bu tuzağa girmemek için o gün eklemeyi reddetmişti;
-- burada tuzağın kendisi kapatılıyor.
--
-- DOĞRULAMA KATALOG DÜZEYİNDE: `WITH CHECK`''in ısırdığı tek senaryo satırın
-- `id`''sini başkasına çevirmek ve `id` sütun ayrıcalığında kilitli, yani
-- çalışma zamanında tetiklenemez. `tests/010` bu yüzden pg_policies''i
-- okuyor; mutasyon 26 politikayı `with check (true)` ile yeniden yazıp
-- iddianın gerçekten ayırt ettiğini kanıtlıyor.
drop policy if exists "Kendi profilini güncelle" on public.profiles;
create policy "Kendi profilini güncelle"
  on public.profiles for update
  using      (auth.uid() = id)
  with check (auth.uid() = id);
