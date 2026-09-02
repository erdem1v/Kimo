-- 0043 — Yaş kapısı ve veli onayı
--
-- BUGÜNKÜ DURUM (Task 01 raporundan): yaş kapısı tek bir onay kutusuydu
-- ("18 yaşından küçüğüm ve velimin izni var") ve HERKESE zorunluydu — reşit
-- kullanıcı da işaretlemek zorundaydı. `profiles.is_minor` ve
-- `profiles.guardian_consent` ölü sütunlardı; hiçbir kod okumuyor/yazmıyordu.
-- Onay defteri (0037) kaydı tutuyordu ama HİÇBİR ÖZELLİĞİ ZORLAMIYORDU:
-- "defter onayın denetlenebilir kaydı, paylaşımın zorlayıcısı değil".
--
-- BU GÖÇ O BOŞLUĞU KAPATIYOR — ama yalnızca bir özellik için: **arkadaş
-- ekleme**. Onaylanan tasarımın kuralı bu; başka hiçbir özellik onaya
-- bağlanmıyor. Kullanıcı onay beklerken uygulamayı tam kullanabiliyor.
--
-- TOPLANAN VERİ: yalnızca DOĞUM YILI. Tam tarih toplanmıyor — gereğinden
-- fazla kişisel veri olurdu ve yaş kapısı için yıl yeterli.
--
-- REŞİTLİK SAKLANMIYOR, TÜRETİLİYOR: `is_minor_now()` her çağrıda yılı
-- karşılaştırıyor. Saklansaydı kullanıcı 18'ine girdiğinde sütun eskirdi ve
-- onu güncelleyecek bir iş gerekirdi.

-- ------------------------------------------------------------------ sütunlar
alter table public.profiles
  add column if not exists birth_year     int,
  add column if not exists guardian_email text;

comment on column public.profiles.birth_year is
  'Doğum yılı. Yalnızca yasal gereklilik (yaş kapısı) için; profilde '
  'gösterilmez. set_birth_year RPC''sinden bir kez yazılır.';
comment on column public.profiles.guardian_email is
  'Veli e-postası. Yalnızca onay bağlantısını göndermek için tutulur; '
  'request_guardian_consent RPC''sinden yazılır.';

-- --------------------------------------------------------------- reşitlik
-- Bilinmiyorsa **reşit değil** kabul edilir (kapalı taraf). Yaş bilinmeden
-- arkadaş eklemenin açılması, yaş kapısını atlamanın en kolay yolu olurdu.
create or replace function public.is_minor_now(p_user uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce(
    (
      select (extract(year from (now() at time zone 'Europe/Istanbul'))::int
                - p.birth_year) < 18
        from public.profiles p
       where p.id = p_user and p.birth_year is not null
    ),
    true
  );
$$;

comment on function public.is_minor_now(uuid) is
  'Doğum yılından türetilmiş reşitlik. Yıl bilinmiyorsa TRUE (kapalı taraf).';

-- ------------------------------------------------------- doğum yılı yazımı
-- TEK YAZIMLIK. İkinci çağrı reddediliyor: 18 altı bir kullanıcı kısıtı aşmak
-- için yılını büyütebilirdi. Yanlış girilen yıl destek üzerinden düzeltilir —
-- bu bilinçli bir sürtünme.
create or replace function public.set_birth_year(p_year int)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_now  int  := extract(year from (now() at time zone 'Europe/Istanbul'))::int;
  v_have int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  -- 5 ile 100 yaş arası: dışı veri girişi hatasıdır.
  if p_year is null or p_year > v_now - 5 or p_year < v_now - 100 then
    raise exception 'Doğum yılı geçersiz' using errcode = '22023';
  end if;

  select p.birth_year into v_have
    from public.profiles p where p.id = v_uid for update;

  if v_have is not null then
    raise exception 'Doğum yılı zaten kayıtlı' using errcode = '22023';
  end if;

  update public.profiles set birth_year = p_year where id = v_uid;
end
$fn$;

revoke execute on function public.set_birth_year(int) from public, anon;
grant  execute on function public.set_birth_year(int) to authenticated;

-- ------------------------------------------------------------ onay defteri
-- 0037'nin CHECK'i yalnızca 'signup' ve 'settings' kabul ediyordu. Veli onayı
-- kullanıcının kendi oturumundan değil, velinin tıkladığı bağlantıdan geliyor;
-- kaynağı ayırt edilebilir olmalı.
do $mig$
declare v_name text;
begin
  select con.conname into v_name
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'user_consents'
     and con.contype = 'c'
     and pg_get_constraintdef(con.oid) ilike '%source%'
   limit 1;
  if v_name is not null then
    execute format('alter table public.user_consents drop constraint %I', v_name);
  end if;
end
$mig$;

alter table public.user_consents
  add constraint user_consents_source_check
  check (source in ('signup', 'settings', 'guardian_email'));

-- ------------------------------------------------------------- onay istekleri
-- Sunucu-özel: RLS açık, politika yok, grant yok.
--
-- Token HASH'İ saklanıyor, kendisi değil. Veritabanı okuma yetkisi olan biri
-- (yedek, log, destek) token'ları görüp başkasının hesabına veli onayı
-- veremesin diye.
create table if not exists public.guardian_requests (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  email        text not null,
  token_hash   text not null unique,
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null,
  confirmed_at timestamptz
);

create index if not exists guardian_requests_user_idx
  on public.guardian_requests (user_id, created_at desc);

alter table public.guardian_requests enable row level security;
revoke all on public.guardian_requests from public, anon, authenticated;

comment on table public.guardian_requests is
  'Veli onayı bağlantıları. Token yalnızca hash olarak saklanır, tek '
  'kullanımlıktır ve süresi dolar. Yalnızca sunucu erişir.';

-- ------------------------------------------------------------ e-posta gönderimi
-- `send_push` ile BİREBİR AYNI DESEN: sağlayıcı anahtarı `app_config`te,
-- gönderim `net.http_post` ile. Yeni bir servis, yeni bir sır yönetimi ve yeni
-- bir dağıtım adımı eklenmiyor. `net` şeması zaten uygulama rollerine kapalı
-- (0028), yani bu fonksiyon dışından çağrılamaz.
--
-- KURULUM (elle, bir kez):
--   insert into public.app_config (key, value) values
--     ('email_api_url',  'https://api.resend.com/emails'),
--     ('email_api_key',  '<sağlayıcı anahtarı>'),
--     ('email_from',     'Kimo <onay@alanadi>'),
--     ('guardian_confirm_url', 'https://<proje>.supabase.co/functions/v1/guardian-confirm');
create or replace function public.send_guardian_email(
  p_email text,
  p_token text,
  p_child text
)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_url    text;
  v_key    text;
  v_from   text;
  v_link   text;
  v_base   text;
begin
  select value into v_url  from public.app_config where key = 'email_api_url';
  select value into v_key  from public.app_config where key = 'email_api_key';
  select value into v_from from public.app_config where key = 'email_from';
  select value into v_base from public.app_config where key = 'guardian_confirm_url';

  if v_url is null or v_key is null or v_from is null or v_base is null then
    -- Sessiz kalmak yerine uyarı: eksik yapılandırmada fonksiyon hiçbir şey
    -- yapmadan başarılı görünürdü ve veli e-postayı hiç almazdı.
    raise warning 'e-posta yapılandırması eksik (app_config): guardian consent gönderilemedi';
    return;
  end if;

  v_link := v_base || '?t=' || p_token;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body := jsonb_build_object(
      'from', v_from,
      'to', jsonb_build_array(p_email),
      'subject', 'Kimo — çocuğunuzun hesabı için onayınız gerekiyor',
      'text',
        coalesce(p_child, 'Çocuğunuz') || ' Kimo uygulamasında bir hesap açtı.' ||
        E'\n\n' ||
        'Kimo, yanlış yaptığı soruları arşivleyip doğru günde tekrar karşısına ' ||
        'çıkaran bir çalışma uygulaması.' || E'\n\n' ||
        'Arkadaş ekleme özelliği, siz onaylayana kadar KAPALI kalıyor. ' ||
        'Onaylamak için:' || E'\n' || v_link || E'\n\n' ||
        'Bu bağlantı 7 gün geçerlidir ve bir kez kullanılabilir. ' ||
        'Bu e-postayı beklemiyorsanız dikkate almayın; hiçbir işlem yapılmaz.'
    )
  );
end
$fn$;

revoke execute on function public.send_guardian_email(text, text, text)
  from public, anon, authenticated;

-- ------------------------------------------------------------- onay isteme
create or replace function public.request_guardian_consent(p_email text)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid   uuid := auth.uid();
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_token text;
  v_child text;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  -- Kaba biçim kontrolü. Amaç doğrulamak değil, yazım hatasını yakalamak;
  -- gerçek doğrulama e-postanın ulaşıp ulaşmadığıyla oluyor.
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'E-posta adresi geçersiz' using errcode = '22023';
  end if;
  if not public.is_minor_now(v_uid) then
    raise exception 'Veli onayı yalnızca 18 yaşından küçük hesaplar için gerekli'
      using errcode = '22023';
  end if;

  -- Günde 3 deneme: yanlış adres girilebilir ama bu uç nokta bir e-posta
  -- gönderme makinesine dönüşmemeli.
  if not public.bump_rate_limit(
       'guardian_mail', 3,
       to_char(now() at time zone 'Europe/Istanbul', 'YYYY-MM-DD')) then
    raise exception 'Bugün için deneme hakkın doldu, yarın tekrar dene'
      using errcode = '54000';
  end if;

  -- Rastgele token. `pgcrypto` (gen_random_bytes/digest) BİLEREK
  -- kullanılmıyor: Supabase onu `extensions` şemasına kuruyor ve bu fonksiyon
  -- `search_path = public` ile çalışıyor; şemayı genişletmek definer bir
  -- fonksiyonda gereksiz bir yüzey açardı. `gen_random_uuid` ve `sha256`
  -- çekirdekte (pg_catalog), yani uzantı bağımlılığı yok.
  -- İki UUIDv4 = 244 bit entropi.
  v_token := replace(gen_random_uuid()::text, '-', '')
          || replace(gen_random_uuid()::text, '-', '');

  select p.nickname into v_child from public.profiles p where p.id = v_uid;

  update public.profiles set guardian_email = v_email where id = v_uid;

  insert into public.guardian_requests (user_id, email, token_hash, expires_at)
  values (v_uid, v_email, encode(sha256(convert_to(v_token, 'UTF8')), 'hex'),
          now() + interval '7 days');

  perform public.send_guardian_email(v_email, v_token, v_child);
end
$fn$;

revoke execute on function public.request_guardian_consent(text) from public, anon;
grant  execute on function public.request_guardian_consent(text) to authenticated;

-- ------------------------------------------------------------ onayın gelmesi
-- Veliyi tıklayan kişi olarak DOĞRULAMIYORUZ — velinin hesabı yok. Güvence
-- token'ın kendisinde: 32 bayt rastgele, hash'li, tek kullanımlık, 7 gün.
--
-- `user_id` PARAMETRESİ YOK: kullanıcı token'dan çözülüyor. Task 01'in
-- "hiçbir RPC user_id almaz" değişmezi burada da geçerli — parametre olsaydı
-- bu, servis rolü anahtarını ele geçiren biri için doğrudan bir kimliğe
-- bürünme primitifi olurdu.
--
-- Deftere `record_consent` ile DEĞİL doğrudan yazılıyor: o fonksiyon
-- `auth.uid()` kullanıyor ve burada oturum yok (çağrı edge fonksiyondan,
-- servis rolüyle geliyor).
create or replace function public.confirm_guardian_consent(p_token text)
returns table (ok boolean, reason text)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_hash text;
  g      public.guardian_requests%rowtype;
begin
  if p_token is null or btrim(p_token) = '' then
    return query select false, 'gecersiz'; return;
  end if;

  v_hash := encode(sha256(convert_to(p_token, 'UTF8')), 'hex');

  select * into g from public.guardian_requests
   where token_hash = v_hash
     for update;

  if not found then
    return query select false, 'gecersiz'; return;
  end if;
  if g.confirmed_at is not null then
    -- Aynı bağlantıya ikinci tıklama: hata değil, zaten onaylı.
    return query select true, 'zaten_onayli'; return;
  end if;
  if g.expires_at < now() then
    return query select false, 'suresi_doldu'; return;
  end if;

  update public.guardian_requests
     set confirmed_at = now()
   where id = g.id;

  insert into public.user_consents (user_id, kind, granted, source)
  values (g.user_id, 'guardian', true, 'guardian_email');

  return query select true, 'onaylandi';
end
$fn$;

-- Yalnızca servis rolü (guardian-confirm edge fonksiyonu) çağırabilir.
revoke execute on function public.confirm_guardian_consent(text)
  from public, anon, authenticated;

-- --------------------------------------------------------- onayın zorlanması
-- Arkadaş ekleyebilir mi? Üç koşul:
--   • anonim değil (kayıt öncesi kullanıcı sosyal yüzeye giremez — 0046)
--   • reşit, YA DA
--   • deftere düşmüş, geri alınmamış bir veli onayı var
--
-- Defterin EN SON kaydına bakılıyor: onay geri alınabilir ve geri alındığında
-- arkadaş ekleme yeniden kapanmalı.
create or replace function public.can_add_friends(p_user uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select not public.is_minor_now(p_user)
      or coalesce(
           (
             select c.granted
               from public.user_consents c
              where c.user_id = p_user and c.kind = 'guardian'
              order by c.recorded_at desc
              limit 1
           ),
           false
         );
$$;

revoke execute on function public.can_add_friends(uuid) from public, anon;
grant  execute on function public.can_add_friends(uuid) to authenticated;

-- Politika içinden çağrıldığı için açık kalmalı.
revoke execute on function public.is_minor_now(uuid) from public, anon;
grant  execute on function public.is_minor_now(uuid) to authenticated;

-- İstek gönderme artık onaya bağlı. Kabul etme (UPDATE) ve silme (DELETE)
-- DEĞİŞMEDİ: onay beklerken gelen bir isteği kabul edememek, kullanıcının
-- kendi verisi üzerindeki kontrolünü gereksiz yere kısıtlardı ve tasarımda
-- kapalı olan tek şey "arkadaş EKLEME".
drop policy if exists friendships_insert_own on public.friendships;
create policy friendships_insert_own on public.friendships
  for insert to authenticated
  with check (
    auth.uid() = requester_id
    and public.can_add_friends(auth.uid())
  );

-- ------------------------------------------------------------ istemci okuma
-- Arayüzün "veli onayı bekleniyor" durumunu gösterebilmesi için. Yaşın
-- kendisini DÖNDÜRMÜYOR — istemcinin ihtiyacı olan tek şey kapının açık olup
-- olmadığı.
create or replace function public.my_guardian_status()
returns table (
  is_minor       boolean,
  birth_year_set boolean,
  guardian_email text,
  consent_granted boolean,
  can_add_friends boolean
)
language sql stable security definer set search_path = public
as $$
  select
    public.is_minor_now(auth.uid()),
    (select p.birth_year is not null from public.profiles p where p.id = auth.uid()),
    (select p.guardian_email from public.profiles p where p.id = auth.uid()),
    coalesce(
      (select c.granted from public.user_consents c
        where c.user_id = auth.uid() and c.kind = 'guardian'
        order by c.recorded_at desc limit 1),
      false),
    public.can_add_friends(auth.uid());
$$;

revoke execute on function public.my_guardian_status() from public, anon;
grant  execute on function public.my_guardian_status() to authenticated;
