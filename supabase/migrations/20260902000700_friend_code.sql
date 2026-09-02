-- 0045 — Arkadaş kodu; takma ad aramasının kaldırılması
--
-- SIRA: bu göç `user_blocks` (0044) üzerine kuruluyor ve `profiles.is_anonymous`
-- (0046) sütununa ATIFTA BULUNUYOR. plpgsql gövdeleri adları çalışma anında
-- çözdüğü için sütun henüz yokken de yaratılabiliyor; ilk çağrı göçlerin
-- tamamı uygulandıktan sonra oluyor.
--
-- Buradaki `handle_new_user` sürümü GEÇİCİDİR: 0046 aynı fonksiyonu anonim
-- bayrağını da yazacak şekilde yeniden tanımlıyor ve SON SÖZ ONUNDUR. İki
-- göçün sırası bu yüzden önemli — ters çevrilirse anonim bayrağı hiç
-- yazılmaz ve her kullanıcı kalıcı görünürdü.
--
-- NEDEN: Task 01, dizinin toplu dökülebilirliğini açık bir risk olarak
-- bıraktı — `profiles_public` üzerinde `ilike '%q%'`, en az 2 karakter, hız
-- sınırı yok. "Sizin kararınızla sosyal/UX pass'ine ertelendi." Bu, o pass.
--
-- Arama tamamen kalkıyor, yerine arkadaş kodu geliyor. Kod bir sırdır:
-- paylaşmadığın kimse seni bulamaz. Takma ad artık bir arama anahtarı değil,
-- yalnızca bir görünen ad.
--
-- BİÇİM: 6 karakter, `XXX-XXX` gösterimi.
-- Alfabe 31 karakter: I, L, O, 0, 1 YOK — el yazısıyla ve sesli okumayla
-- karışan karakterler. 31^6 ≈ 887 milyon; saatte 20 denemelik sınırla kaba
-- kuvvet taraması kapalı.

alter table public.profiles
  add column if not exists friend_code text;

-- Tekillik kısıtı ayrı: `add column ... unique` tekrar çalıştırmada patlıyor.
create unique index if not exists profiles_friend_code_key
  on public.profiles (friend_code) where friend_code is not null;

comment on column public.profiles.friend_code is
  'Arkadaş kodu (tiresiz, büyük harf). Sunucu üretir, istemci yazamaz. '
  'Takma ad aramasının yerini aldı.';

-- ------------------------------------------------------------------ üretim
create or replace function public.generate_friend_code()
returns text
language plpgsql volatile set search_path = public
as $fn$
declare
  -- I, L, O, 0, 1 bilerek yok.
  c_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
  i int;
begin
  v_code := '';
  for i in 1..6 loop
    v_code := v_code || substr(
      c_alphabet,
      1 + floor(random() * length(c_alphabet))::int,
      1
    );
  end loop;
  return v_code;
end
$fn$;

revoke execute on function public.generate_friend_code()
  from public, anon, authenticated;

-- Çakışmada yeniden dene. 887 milyonluk uzayda 10 deneme fazlasıyla yeterli;
-- yine de sessizce vazgeçmiyoruz — kodsuz bir profil arkadaş ekleyemezdi.
create or replace function public.assign_friend_code(p_user uuid)
returns text
language plpgsql security definer set search_path = public
as $fn$
declare
  v_code text;
  i int;
begin
  for i in 1..10 loop
    v_code := public.generate_friend_code();
    begin
      update public.profiles set friend_code = v_code where id = p_user;
      return v_code;
    exception when unique_violation then
      -- döngü devam etsin
    end;
  end loop;
  raise exception 'Arkadaş kodu üretilemedi' using errcode = '55000';
end
$fn$;

revoke execute on function public.assign_friend_code(uuid)
  from public, anon, authenticated;

-- --------------------------------------------------------- mevcut kullanıcılar
-- Tek seferlik geri doldurma. Kodsuz kalan profil arkadaş ekleyemez.
do $mig$
declare r record;
begin
  for r in select id from public.profiles where friend_code is null loop
    perform public.assign_friend_code(r.id);
  end loop;
end
$mig$;

-- --------------------------------------------------------- yeni kullanıcılar
-- `handle_new_user` 0037'de yeniden yazılmıştı; onay defteri bölümü aynen
-- korunuyor, üstüne kod üretimi ekleniyor.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $fn$
begin
  insert into public.profiles (id, display_name, nickname)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', 'Öğrenci'),
    coalesce(new.raw_user_meta_data->>'nickname',
             new.raw_user_meta_data->>'display_name', 'Öğrenci')
  );

  -- Metadata'da onay varsa deftere geçir. Yoksa satır yazılmaz: "onay yok"
  -- ile "onay reddedildi" ayrı şeyler, uydurmuyoruz.
  if new.raw_user_meta_data ? 'guardian_consent' then
    insert into public.user_consents (user_id, kind, granted, source)
    values (
      new.id, 'guardian',
      coalesce((new.raw_user_meta_data->>'guardian_consent')::boolean, false),
      'signup'
    );
  end if;

  -- Arkadaş kodu doğumda veriliyor: sonradan üretilseydi "kodun henüz yok"
  -- diye bir ara durum olurdu ve arayüzün onu da anlatması gerekirdi.
  perform public.assign_friend_code(new.id);

  return new;
end
$fn$;

-- ------------------------------------------------------------- normalizasyon
-- Kullanıcı kodu tireli, küçük harfle ya da boşluklu yazabilir.
create or replace function public.normalize_friend_code(p_code text)
returns text
language sql immutable set search_path = public
as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
$$;

revoke execute on function public.normalize_friend_code(text)
  from public, anon, authenticated;

-- ------------------------------------------------------------- kodla ekleme
-- İKİ TASARIM KARARI, ikisi de bir saldırıyı kapatıyor:
--
-- 1) HATA MESAJLARI AYNI. "kod yok" ile "kod var ama engellisin" farklı mesaj
--    verseydi, kod uzayını taramak için bir sızıntı kanalı olurdu.
--
-- 2) BAŞARISIZLIK İSTİSNA DEĞİL, DÖNÜŞ DEĞERİ. Bu kritik: PostgreSQL'de
--    istisna işlemi geri alır ve GERİ ALMA ORAN SINIRI SAYACINI DA SİLER.
--    Yani "kod bulunamadı" diye `raise` edilseydi, geçersiz denemeler hiç
--    sayılmaz ve 887 milyonluk uzayı taramak BEDAVA olurdu — oran sınırı
--    yalnızca BAŞARILI eklemeleri sınırlardı. Sayaç artışının kalıcı olması
--    için çağrının başarıyla dönmesi (commit etmesi) şart.
--
--    İstisna yalnızca sayaç artışından ÖNCEKİ yapısal hatalarda atılıyor
--    (oturum yok, kod uzunluğu yanlış) ve sınır aşımında — orada zaten
--    kaydedilecek bir artış yok.
create or replace function public.add_friend_by_code(p_code text)
returns table (ok boolean, reason text, friend_id uuid, nickname text)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_code   text := public.normalize_friend_code(p_code);
  v_target public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if length(v_code) <> 6 then
    raise exception 'Kod 6 karakter olmalı' using errcode = '22023';
  end if;

  -- Kaba kuvvet taraması: saatte 20 deneme. Sayaç GEÇERSİZ denemelerde de
  -- işliyor (bkz. yukarıdaki 2. karar).
  if not public.bump_rate_limit(
       'friend_code', 20,
       to_char(now() at time zone 'Europe/Istanbul', 'YYYY-MM-DD HH24')) then
    raise exception 'Çok fazla deneme yaptın, biraz sonra tekrar dene'
      using errcode = '54000';
  end if;

  if not public.can_add_friends(v_uid) then
    return query select false, 'onay_bekleniyor'::text, null::uuid, null::text;
    return;
  end if;

  select * into v_target from public.profiles p where p.friend_code = v_code;

  if not found
     or v_target.id = v_uid
     or v_target.is_system
     or v_target.is_anonymous
     or exists (
       select 1 from public.user_blocks b
        where (b.blocker_id = v_uid and b.blocked_id = v_target.id)
           or (b.blocker_id = v_target.id and b.blocked_id = v_uid)
     )
  then
    -- TEK MESAJ: kod yok / kendi kodun / engelli / anonim ayrımı yapılmıyor.
    return query select false, 'bulunamadi'::text, null::uuid, null::text;
    return;
  end if;

  insert into public.friendships (requester_id, addressee_id, status)
  values (v_uid, v_target.id, 'pending')
  on conflict do nothing;

  return query select true, 'eklendi'::text, v_target.id, v_target.nickname;
end
$fn$;

revoke execute on function public.add_friend_by_code(text) from public, anon;
grant  execute on function public.add_friend_by_code(text) to authenticated;

-- ---------------------------------------------------------------- kod yenileme
-- Taciz durumunda kaçış yolu: kodu değiştir, eski kod ölür. Günde bir kez —
-- kod uzayını hızlıca taramak için kendi kodunu döndürmenin faydası olmasın.
create or replace function public.rotate_friend_code()
returns text
language plpgsql security definer set search_path = public
as $fn$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if not public.bump_rate_limit(
       'friend_code_rotate', 1,
       to_char(now() at time zone 'Europe/Istanbul', 'YYYY-MM-DD')) then
    raise exception 'Kodunu bugün zaten yeniledin' using errcode = '54000';
  end if;
  return public.assign_friend_code(v_uid);
end
$fn$;

revoke execute on function public.rotate_friend_code() from public, anon;
grant  execute on function public.rotate_friend_code() to authenticated;

-- ------------------------------------------------------------ ortak arkadaş
-- Gelen istek kartındaki "2 ortak arkadaş" satırı için. Sayı döndürüyor,
-- KİMLİK döndürmüyor: ortak arkadaşların listesi istenmeyen bir sosyal
-- grafik sızıntısı olurdu.
create or replace function public.mutual_friend_count(p_user uuid)
returns int
language sql stable security definer set search_path = public
as $$
  select count(*)::int
    from (
      select case when f.requester_id = auth.uid()
                  then f.addressee_id else f.requester_id end as other
        from public.friendships f
       where f.status = 'accepted'
         and (f.requester_id = auth.uid() or f.addressee_id = auth.uid())
    ) mine
   where mine.other in (
     select case when f2.requester_id = p_user
                 then f2.addressee_id else f2.requester_id end
       from public.friendships f2
      where f2.status = 'accepted'
        and (f2.requester_id = p_user or f2.addressee_id = p_user)
   );
$$;

revoke execute on function public.mutual_friend_count(uuid) from public, anon;
grant  execute on function public.mutual_friend_count(uuid) to authenticated;

-- ------------------------------------------------------- aramanın kaldırılması
-- `profiles_public` görünümü DURUYOR: arkadaş listesi ve lig tahtası kimliğe
-- göre okuma yapıyor. Kaldırılan şey serbest metin ARAMASI — istemci artık
-- `ilike` sorgusu göndermiyor (bkz. social_repository.search kaldırıldı).
--
-- Görünümün kendisi hâlâ `authenticated`a açık ve teorik olarak
-- `select * from profiles_public` ile dökülebilir. Bunu kapatmak görünümü
-- fonksiyona çevirmeyi gerektirir ve arkadaş listesi/lig tahtası yollarını
-- yeniden yazar; kapsamı aşıyor. Kod tabanlı ekleme, dökülen veriyi
-- "eklenebilir" olmaktan çıkarıyor: kodu bilmeden istek gönderilemiyor.
comment on view public.profiles_public is
  'Kimliğe göre herkese açık profil alanları. SERBEST METİN ARAMASI İÇİN '
  'KULLANILMAZ — arkadaş ekleme arkadaş koduyla yapılır (add_friend_by_code). '
  'Görünümün toplu okunabilirliği bilinen ve kabul edilen bir sınırdır.';
