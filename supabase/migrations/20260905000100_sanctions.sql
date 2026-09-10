-- 0062 — Yaptırım altyapısı: askıya alma, kalıcı yasak, kademeli içerik yaptırımı
--
-- BULGU (hukuki denetim A-3, Kritik). Yönetici yalnızca İÇERİK kaldırabiliyordu
-- (`admin_question_action`, `admin_review_photo_scan`). Bir kullanıcıyı
-- durduran hiçbir tablo, sütun, RPC ya da politika yoktu — `ban`, `suspend`,
-- `disable_user` taraması depoda tek bir yorum satırı dışında sonuçsuzdu.
-- App Store Review Guideline 1.2, kullanıcı içeriği barındıran uygulamalarda
-- dört şey arıyor: içerik filtreleme, şikâyet, engelleme ve **"the ability to
-- eject abusive users from the service"**. Dördüncüsü yoktu.
--
-- İKİNCİ BULGU (Task 07 §4.2). İçerik taraması çalışıyor (0050) ama:
--   • kullanıcıya HİÇBİR geri bildirim gitmiyor — fotoğrafı sessizce
--     paylaşıma çıkmıyor ve nedenini asla öğrenmiyor;
--   • tekrar edende hiçbir yaptırım yok — aynı kişi sınırsız deneyebilir.
--
-- ---------------------------------------------------------------- TASARIM
--
-- 1) SÜTUN DEĞİL, POLİTİKASIZ TABLO. `profiles`e sütun eklemek tam bir
--    `lockdown_v*` göçü zorunlu kılıyor (her lockdown bloğu KENDİ çalıştığı
--    andaki katalogla karşılaştırma yapıyor; sonradan eklenen sütun sessizce
--    kilitli kalır ama bir sonraki paketin lockdown'ı "sınıflandırılmamış
--    kolon" ile patlar). Ayrıca `public.admins` emsali daha güçlü: RLS açık +
--    POLİTİKA YOK = yapısal olarak deny-by-default; ileride biri yanlışlıkla
--    geniş bir GRANT yazsa bile kapı açılmaz.
--
-- 2) DEFTER, DURUM SÜTUNU DEĞİL. Yaptırımın geçmişi olmak zorunda: itiraz,
--    yönetici incelemesi ve "askıdan sonra tekrar ihlal" kuralı geçmişe bakar.
--    Bir sütunun tek bir güncel değeri olur, geçmişi olmaz (0037'nin gerekçesi).
--    Güncel durum en son satırdan TÜRETİLİYOR (`is_suspended`), saklanmıyor —
--    süreli askı kendiliğinden doluyor, cron gerekmiyor.
--
-- 3) SAYAÇ AYRI DEFTERDE, `mistakes`ten TÜRETİLMİYOR. "Kaç kez işaretlendi"
--    sorusu `mistakes where photo_scan='flagged'` ile de yanıtlanabilirdi,
--    ama kullanıcı kendi hatasını silebiliyor (politika var) ve A-9 gelirse
--    arayüzden de silebilecek — sayaç o an sıfırlanabilir hâle gelirdi.
--    `photo_violations.mistake_id` bu yüzden `on delete set null`: satır silinse
--    bile ihlal ayakta kalıyor.
--
-- 4) TETİKLEYİCİ, EDGE FONKSİYONU DEĞİL. Sayacı `scan-photos` içinden artırmak
--    kararı istemci-dışı tek bir yola bağlardı; oysa `photo_scan='flagged'`
--    yazan üç yol var (kullanıcı hızlı yolu, pg_cron süpürücüsü, elle bir
--    yönetici yazması). Tetikleyici hepsini tek kapıdan geçiriyor. `photo_scan`
--    zaten KİLİTLİ bir sütun (0053), yani istemci bu kapıyı çalamaz.
--
-- 5) MERDİVEN (onaylanan ürün kararı):
--      1. ihlal → yalnızca kayıt + nazik uyarı (istemcide)
--      2. ihlal → kayıt + sert uyarı
--      3. ihlal (180 GÜNLÜK KAYAN PENCERE içinde) → 7 GÜNLÜK OTOMATİK ASKI
--      askıdan sonra yeni ihlal → KALICI YASAK
--    Pencere neden ömür boyu değil: tetikleyen şey otomatik bir sınıflandırıcı
--    ve yanlış pozitifi var; üç yıla yayılmış üç kareyi bugünkü askının üçte
--    biri saymak orantısız. Defterin KENDİSİ ömür boyu duruyor — yönetici tam
--    geçmişi görüyor, yalnızca OTOMATİK eşik pencereye bakıyor.
--    Otomatik karar neden süreli: makine hatasının bedelini sınırlamak için.
--    Kalıcı yasağı ya tekrar (yani insan davranışı) ya da yönetici veriyor.
--
-- 6) YANLIŞ POZİTİF KULLANICIYI KİLİTLEMEZ. Yönetici bir fotoğrafı "temiz"
--    derse ilgili ihlal geçersiz kılınıyor; sayaç eşiğin altına düşerse
--    OTOMATİK askı da geri alınıyor ve deftere bir `lift` satırı yazılıyor.
--    Sahibin kendi fotoğrafına erişimi zaten hiçbir durumda kısıtlanmıyor
--    (`can_read_mistake_photo`'nun sahip dalı taramadan bağımsız) — engellenen
--    yalnızca PAYLAŞIM.
--
-- 7) OKUMA AÇIK KALIYOR. Askıdaki kullanıcı kendi arşivini görür, tekrar yapar,
--    ligde durur, şikâyet edebilir ve engelleyebilir. Kapanan tek şey ÜRETİM:
--    fotoğraf yükleme, soru gönderme, arkadaşlık isteği. Ceza uygulamadan
--    atmak değil, başkasına dokunmayı durdurmak.

-- ============================================================ yaptırım defteri
-- Sunucu-özel: RLS açık, POLİTİKA YOK, hiçbir uygulama rolüne grant yok.
-- Okuma `my_sanction()` / `admin_user_sanctions()` üzerinden.
create table if not exists public.user_sanctions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  action      text not null check (action in ('suspend', 'ban', 'lift')),
  -- null + 'suspend' = süresiz askı (yönetici yolu); null + 'ban' = kalıcı.
  until       timestamptz,
  reason_code text not null check (reason_code in
                ('photo_repeat', 'abuse', 'spam', 'other')),
  source      text not null check (source in ('auto_photo', 'admin')),
  -- Kararı veren yönetici. Otomatik kararda null — 0012'deki "kararı veren
  -- kişi kaydedilmiyor" eksiğini bu tabloda tekrarlamıyoruz.
  --
  -- ⚠️ CASCADE İSTİSNASI. 0048'in kapısı "auth.users'a bakan her yabancı
  -- anahtar `on delete cascade` olmalı" diyor. Bu sütun BİLEREK `set null`:
  -- kaydın SAHİBİ `user_id`, `actor_id` yalnızca kararı vereni gösteriyor.
  -- Cascade olsaydı bir yöneticinin hesabını silmesi, BAŞKALARI hakkındaki
  -- yaptırım kayıtlarını da silerdi. Hesap silme açısından da sorun yok:
  -- yönetici silindiğinde alan null'a düşüyor, geride kimlik kalmıyor.
  -- 0065'in cascade kapısı bu istisnayı SÜTUN ADINA göre tanıyor; YENİ bir
  -- cascade denetimi yazan da aynı istisnayı taşımalı.
  actor_id    uuid references auth.users(id) on delete set null,
  note        text,
  -- Yanlış pozitif anlaşıldığında satır SİLİNMİYOR, geçersiz kılınıyor:
  -- defterin bütünlüğü korunsun, ne olduğu görünsün.
  voided_at   timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists user_sanctions_user_idx
  on public.user_sanctions (user_id, created_at desc);

alter table public.user_sanctions enable row level security;
revoke all on public.user_sanctions from public, anon, authenticated;

comment on table public.user_sanctions is
  'Askıya alma / kalıcı yasak defteri. Yalnızca sunucu yazar (tetikleyici ve '
  'admin_suspend_user). Güncel durum en son satırdan türetilir: is_suspended().';

-- ============================================================= ihlal defteri
create table if not exists public.photo_violations (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  -- SET NULL: kullanıcı hatasını silse bile ihlal kaydı ayakta kalır,
  -- yani sayaç kullanıcı tarafından sıfırlanamaz.
  mistake_id      uuid references public.mistakes(id) on delete set null,
  -- Kayıt anındaki sıra. Uyarının sertliğini istemci buradan seçiyor;
  -- sonradan yeniden hesaplanmıyor ki gösterilen metin geçmişe uysun.
  strike_no       int not null,
  -- Kullanıcının uyarıyı gördüğü an. TEK kullanıcı-yazılabilir alan
  -- (ack_photo_warnings); sayacı ya da geçersizliği etkilemiyor.
  acknowledged_at timestamptz,
  voided_at       timestamptz,
  created_at      timestamptz not null default now()
);

create index if not exists photo_violations_user_idx
  on public.photo_violations (user_id, created_at desc);

alter table public.photo_violations enable row level security;
revoke all on public.photo_violations from public, anon, authenticated;

comment on table public.photo_violations is
  'Uygunsuz içerik ihlali defteri. Yalnızca tetikleyici yazar. Kullanıcı '
  'yalnızca acknowledged_at alanını (ack_photo_warnings ile) işaretleyebilir.';

-- ======================================================== güncel askı durumu
-- POLİTİKA İÇİNDEN ÇAĞRILIYOR, dolayısıyla `security definer` VE
-- `authenticated`'a açık olmak ZORUNDA.
--
-- 0052'nin dersi: politika ifadeleri ÇAĞIRANIN yetkisiyle değerlendirilir.
-- Politikanın içine düz bir `not exists (select 1 from user_sanctions …)`
-- yazsaydık, tablo çağırana görünmediği için alt sorgu HER ZAMAN boş dönerdi
-- ve yasak hiç uygulanmazdı — engelleme kontrolü tam bu şekilde delikti.
create or replace function public.is_suspended(p_user uuid)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select coalesce(
    (
      select case s.action
               when 'lift'    then false
               when 'ban'     then true
               when 'suspend' then (s.until is null or s.until > now())
             end
        from public.user_sanctions s
       where s.user_id = p_user
         and s.voided_at is null
       order by s.created_at desc, s.id desc
       limit 1
    ),
    false
  );
$fn$;

revoke execute on function public.is_suspended(uuid) from public, anon;
grant  execute on function public.is_suspended(uuid) to authenticated;

comment on function public.is_suspended(uuid) is
  'Defterin en son (geçersiz kılınmamış) satırından türetilmiş askı durumu. '
  'Süreli askı kendiliğinden dolar; cron gerekmez.';

-- ==================================================== kademeli yaptırım kapısı
create or replace function public.mistakes_photo_violation()
returns trigger
language plpgsql security definer set search_path = public
as $fn$
declare
  v_n     int;
  v_prior boolean;
begin
  -- 180 günlük kayan pencere, geçersiz kılınmamış ihlaller + bu satır.
  select count(*) into v_n
    from public.photo_violations v
   where v.user_id = new.user_id
     and v.voided_at is null
     and v.created_at > now() - interval '180 days';
  v_n := v_n + 1;

  insert into public.photo_violations (user_id, mistake_id, strike_no)
  values (new.user_id, new.id, v_n);

  -- Zaten askıda ya da yasaklıysa yeni yaptırım YAZILMIYOR: askılar üst üste
  -- binip süreyi sessizce uzatmasın.
  if public.is_suspended(new.user_id) then
    return null;
  end if;

  -- Daha önce bir otomatik askı ÇEKMİŞ kullanıcının yeni ihlali → kalıcı yasak.
  -- Yalnızca geçersiz kılınmamış askılar sayılıyor: yanlış pozitif olduğu
  -- anlaşılıp geri alınan bir askı sicilde yer tutmaz.
  select exists (
    select 1 from public.user_sanctions s
     where s.user_id = new.user_id
       and s.source  = 'auto_photo'
       and s.action  = 'suspend'
       and s.voided_at is null
  ) into v_prior;

  if v_prior then
    insert into public.user_sanctions (user_id, action, until, reason_code, source)
    values (new.user_id, 'ban', null, 'photo_repeat', 'auto_photo');
  elsif v_n >= 3 then
    insert into public.user_sanctions (user_id, action, until, reason_code, source)
    values (new.user_id, 'suspend', now() + interval '7 days',
            'photo_repeat', 'auto_photo');
  end if;

  return null;
end
$fn$;

-- `when` yan tümcesi: yalnızca pending/clear → flagged GEÇİŞİ sayılıyor.
-- Aynı satırın ikinci kez 'flagged' yazılması (yarış, yeniden koşum) ihlal
-- üretmiyor. Fotoğraf DEĞİŞİRSE 0050'nin tetikleyicisi durumu 'pending'e
-- döndürüyor; yeniden işaretlenirse bu YENİ bir ihlaldir — işaretlenmiş
-- içeriği yeniden yüklemek başlı başına ihlal.
drop trigger if exists mistakes_photo_violation on public.mistakes;
create trigger mistakes_photo_violation
  after update of photo_scan on public.mistakes
  for each row
  when (new.photo_scan = 'flagged' and old.photo_scan is distinct from new.photo_scan)
  execute function public.mistakes_photo_violation();

-- ============================================================ istemci kapıları
-- Askı ekranının ihtiyacı olan her şey, fazlası değil: yaptırımın gerekçe
-- KODU dönüyor (serbest metin değil), istemci kendi yerelleştirilmiş metnine
-- çeviriyor. `note` DÖNMÜYOR — yönetici notu iç kayıttır.
create or replace function public.my_sanction()
returns table (
  suspended   boolean,
  until       timestamptz,
  permanent   boolean,
  reason_code text
)
language sql stable security definer set search_path = public
as $fn$
  select
    public.is_suspended(auth.uid()),
    case when l.action = 'lift' then null else l.until end,
    coalesce(l.action = 'ban', false),
    case when l.action = 'lift' then null else l.reason_code end
  from (select 1) d(x)
  left join lateral (
    select s.action, s.until, s.reason_code
      from public.user_sanctions s
     where s.user_id = auth.uid()
       and s.voided_at is null
     order by s.created_at desc, s.id desc
     limit 1
  ) l on true;
$fn$;

revoke execute on function public.my_sanction() from public, anon;
grant  execute on function public.my_sanction() to authenticated;

-- Gösterilmemiş uyarılar + güncel pencere sayacı.
create or replace function public.my_photo_warnings()
returns table (
  id           uuid,
  mistake_id   uuid,
  strike_no    int,
  created_at   timestamptz,
  active_count int
)
language sql stable security definer set search_path = public
as $fn$
  select v.id, v.mistake_id, v.strike_no, v.created_at,
         (select count(*)::int
            from public.photo_violations w
           where w.user_id = auth.uid()
             and w.voided_at is null
             and w.created_at > now() - interval '180 days')
    from public.photo_violations v
   where v.user_id = auth.uid()
     and v.voided_at is null
     and v.acknowledged_at is null
   order by v.created_at;
$fn$;

revoke execute on function public.my_photo_warnings() from public, anon;
grant  execute on function public.my_photo_warnings() to authenticated;

-- Kullanıcının deftere dokunabildiği TEK yer. Sayacı, sırayı ve geçersizliği
-- değiştiremiyor; yalnızca "bu uyarıyı gördüm" diyor.
create or replace function public.ack_photo_warnings()
returns void
language plpgsql security definer set search_path = public
as $fn$
begin
  if auth.uid() is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  update public.photo_violations
     set acknowledged_at = now()
   where user_id = auth.uid()
     and acknowledged_at is null;
end
$fn$;

revoke execute on function public.ack_photo_warnings() from public, anon;
grant  execute on function public.ack_photo_warnings() to authenticated;

-- ============================================================ yönetici kapıları
-- Hedef `user_id` parametre olarak alınıyor. Task 01'in "hiçbir RPC user_id
-- almaz" değişmezi ÇAĞIRANIN başka bir kimliğe bürünmesini engellemek içindi;
-- yönetici yolu `admin_question_action(uuid, text)` emsaliyle aynı — yetki
-- `is_admin()` ile SUNUCUDA doğrulanıyor, parametre yalnızca hedefi gösteriyor.
create or replace function public.admin_user_sanctions(p_user uuid)
returns table (
  id              uuid,
  action          text,
  until           timestamptz,
  reason_code     text,
  source          text,
  note            text,
  voided_at       timestamptz,
  created_at      timestamptz,
  violations_180d int,
  violations_all  int
)
language sql stable security definer set search_path = public
as $fn$
  select s.id, s.action, s.until, s.reason_code, s.source, s.note,
         s.voided_at, s.created_at,
         (select count(*)::int from public.photo_violations v
           where v.user_id = p_user and v.voided_at is null
             and v.created_at > now() - interval '180 days'),
         -- Yönetici ÖMÜR BOYU sayacı da görüyor: otomatik eşik pencereye
         -- bakıyor, insan kararı tam geçmişe bakabilmeli.
         (select count(*)::int from public.photo_violations v
           where v.user_id = p_user and v.voided_at is null)
    from public.user_sanctions s
   where public.is_admin()
     and s.user_id = p_user
   order by s.created_at desc;
$fn$;

revoke execute on function public.admin_user_sanctions(uuid) from public, anon;
grant  execute on function public.admin_user_sanctions(uuid) to authenticated;

create or replace function public.admin_suspend_user(
  p_user   uuid,
  p_action text,
  p_days   int  default null,
  p_reason text default 'abuse',
  p_note   text default null
)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_until timestamptz;
begin
  if not public.is_admin() then
    raise exception 'yetkisiz' using errcode = '42501';
  end if;
  -- Yönetici kendini kilitleyemez: dört kişilik bir ekipte tek moderatörün
  -- kendi hesabını kapatması geri dönüşü olmayan bir kaza olurdu.
  if p_user is null or p_user = auth.uid() then
    raise exception 'geçersiz hedef' using errcode = '22023';
  end if;
  if p_action not in ('suspend', 'ban', 'lift') then
    raise exception 'geçersiz eylem' using errcode = '22023';
  end if;
  if p_reason not in ('photo_repeat', 'abuse', 'spam', 'other') then
    raise exception 'geçersiz gerekçe' using errcode = '22023';
  end if;

  -- Süre verilmezse askı SÜRESİZ olur (yönetici kaldırana kadar).
  if p_action = 'suspend' and p_days is not null then
    if p_days < 1 or p_days > 3650 then
      raise exception 'geçersiz süre' using errcode = '22023';
    end if;
    v_until := now() + make_interval(days => p_days);
  end if;

  insert into public.user_sanctions
    (user_id, action, until, reason_code, source, actor_id, note)
  values (p_user, p_action, v_until, p_reason, 'admin', auth.uid(), p_note);
end
$fn$;

revoke execute on function public.admin_suspend_user(uuid, text, int, text, text)
  from public, anon;
grant  execute on function public.admin_suspend_user(uuid, text, int, text, text)
  to authenticated;

-- ==================================== yanlış pozitifin ihlali de geri alması
-- 0050'deki metnin aynısı; `clear` dalı artık ihlali de geçersiz kılıyor ve
-- gerekiyorsa otomatik askıyı kaldırıyor. Aksi hâlde yönetici "bu temiz" dese
-- bile sayaç kullanıcıyı askıda tutmaya devam ederdi.
create or replace function public.admin_review_photo_scan(
  p_id     uuid,
  p_action text
)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_owner uuid;
  v_n     int;
begin
  if not public.is_admin() then
    raise exception 'yetkisiz' using errcode = '42501';
  end if;

  if p_action = 'clear' then
    update public.mistakes
       set photo_scan = 'clear', photo_scan_at = now()
     where id = p_id
    returning user_id into v_owner;

    if v_owner is null then
      return;
    end if;

    update public.photo_violations
       set voided_at = now()
     where mistake_id = p_id
       and voided_at is null;

    select count(*) into v_n
      from public.photo_violations v
     where v.user_id = v_owner
       and v.voided_at is null
       and v.created_at > now() - interval '180 days';

    if v_n < 3 then
      update public.user_sanctions s
         set voided_at = now()
       where s.user_id = v_owner
         and s.source  = 'auto_photo'
         and s.voided_at is null;

      if found then
        insert into public.user_sanctions
          (user_id, action, reason_code, source, actor_id, note)
        values (v_owner, 'lift', 'photo_repeat', 'admin', auth.uid(),
                'yanlis pozitif: tarama karari geri alindi');
      end if;
    end if;

  elsif p_action = 'remove' then
    update public.mistakes
       set moderation = 'removed'
     where id = p_id;
  else
    raise exception 'geçersiz eylem' using errcode = '22023';
  end if;
end
$fn$;

revoke execute on function public.admin_review_photo_scan(uuid, text)
  from public, anon;
grant  execute on function public.admin_review_photo_scan(uuid, text)
  to authenticated;

-- ======================================================= yasağın ZORLANMASI
-- Dört yazma yolu da VERİ KATMANINDA kapanıyor. İstemci kapısı yeterli değil:
-- PostgREST'e doğrudan istek atan biri arayüzü hiç görmez.

-- 1) Hata satırı (fotoğrafın kendisi de buradan geliyor).
drop policy if exists "Kendi hatanı ekle" on public.mistakes;
create policy "Kendi hatanı ekle"
  on public.mistakes for insert
  with check (
    auth.uid() = user_id
    and not public.is_suspended(auth.uid())
  );

-- 2) Depolama nesnesi. Satır ve nesne AYRI yollar: yalnızca birini kapatmak
--    diğerini açık bırakırdı (0031'in aynı gerekçesi).
drop policy if exists "Kendi fotolarını yükle" on storage.objects;
create policy "Kendi fotolarını yükle"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'mistake-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and not public.is_suspended(auth.uid())
  );

-- 3) Soru gönderimi. 0052'deki metnin aynısı + askı koşulu.
drop policy if exists sends_insert_friend on public.question_sends;
create policy sends_insert_friend on public.question_sends
  for insert to authenticated
  with check (
    auth.uid() = sender_id
    and not public.is_suspended(auth.uid())
    and not exists (
      select 1 from public.profiles p
       where p.id = auth.uid() and p.is_anonymous
    )
    and public.are_friends(sender_id, receiver_id)
    and not public.is_blocked_between(sender_id, receiver_id)
    and exists (
      select 1 from public.mistakes m
       where m.id = mistake_id
         and m.user_id = auth.uid()
         and m.moderation = 'ok'
         and m.photo_scan = 'clear'
    )
  );

-- 4) Arkadaşlık isteği. 0052'deki metnin aynısı + askı koşulu.
--    `can_add_friends` de 0063'te askıyı kapsıyor; ikisi birden duruyor çünkü
--    `add_friend_by_code` SECURITY DEFINER ve RLS'i atlıyor — politika doğrudan
--    INSERT yolunu, fonksiyondaki kontrol RPC yolunu kapatıyor.
drop policy if exists friendships_insert_own on public.friendships;
create policy friendships_insert_own on public.friendships
  for insert to authenticated
  with check (
    auth.uid() = requester_id
    and not public.is_suspended(auth.uid())
    and public.can_add_friends(auth.uid())
    and not public.is_blocked_between(requester_id, addressee_id)
  );

-- DEĞİŞMEYEN, BİLİNÇLİ: okuma, tekrar, lig, şikâyet ve engelleme yolları.
-- Askıdaki kullanıcı kendi verisine erişebilir (KVKK Md. 11) ve kendini
-- korumaya devam edebilir; şikâyet/engelleme bir güvenlik supabıdır, ceza
-- aracı değil. Kabul EDİLEN arkadaşlık isteği de kapatılmadı: kendi verisi
-- üzerindeki kontrolü gereksiz yere kısıtlardı (0043'ün aynı gerekçesi).
