-- 0063 — Veli onayı kaldırıldı · 13 yaş sınırı zorlanıyor · koşul onayı deftere
--
-- ============================================================ 1) VELİ ONAYI
--
-- KARAR: 13-17 yaş için veli onayı hukuken zorunlu DEĞİL. COPPA 13 altı için
-- geçerli, KVKK'da çocuklara özel bir madde yok, Apple veli onayını Kids
-- Category'de arıyor, Play Families 13 altını hedefleyen uygulamalar için.
-- Sektör pratiği: koşullarda belirtilir, mekanizma kurulmaz.
--
-- Mekanizma ZATEN ÇALIŞMIYORDU (hukuki denetim A-1, Kritik): 0043 bağlantıyı
-- `?t=<token>` ile kuruyor, `guardian-confirm` edge fonksiyonu `token`
-- parametresini okuyordu. İsimler uyuşmadığı için token boş okunuyor, biçim
-- kontrolü düşüyor ve HER onay "bağlantı geçersiz" ile sonuçlanıyordu. Yani
-- bugüne kadar tek bir veli onayı bile tamamlanmadı. Düzeltmek yerine
-- kaldırıyoruz.
--
-- VERİ MİNİMİZASYONU: `profiles.guardian_email` ve `guardian_requests` DÜŞÜYOR.
-- İkisi de üçüncü bir kişinin (velinin) e-posta adresini tutuyordu ve
-- 0043 onay tamamlandıktan sonra bile silmiyordu. Ölü bir akış için kişisel
-- veri saklamanın savunulabilir bir gerekçesi yok (KVKK Md. 4/2-ç).
--
-- YERİNDE BIRAKILANLAR — bilinçli:
--   • `user_consents` satırları ve `kind` CHECK'indeki 'guardian', `source`
--     CHECK'indeki 'guardian_email'. Defter DEĞİŞTİRİLEMEZ (Değişmez 7);
--     geçmiş kayıtları geçersiz kılacak bir CHECK tam da o değişmezi bozardı.
--     Yazma yolu kapanıyor (`record_consent` artık kabul etmiyor), geçmiş
--     duruyor.
--   • `is_minor_now(uuid)` — artık HİÇBİR özelliği kapatmıyor ama yaş
--     derecelendirmesi ve ayarlardaki durum satırı için duruyor.
--   • `profiles.birth_year` — 13 sınırı için gerekli.
--
-- 18 ALTI ARKADAŞ EKLEME AÇILIYOR (onaylanan ürün kararı). Risk düşük çünkü
-- arkadaş eklemenin TEK yolu 6 haneli `friend_code`: keşif yok, takma adla
-- arama yok, saatte 20 deneme sınırı var, kod döndürülebiliyor (taciz kaçış
-- yolu) ve engelleme + şikâyet + 0062'nin askıya alması duruyor. Yabancıyla
-- temas yüzeyi yapısal olarak yok.
--
-- ======================================================== 2) 13 YAŞ SINIRI
--
-- BULGU (A-7): `set_birth_year` 5-100 yaş aralığını kabul ediyordu. Kullanım
-- Koşulları 13 yaş sınırı ilan edecekse kod bunu zorlamalı; aksi hâlde beyan
-- ile davranış ayrışır (App Store 5.1.1, Play Data Safety).
--
-- ==================================================== 3) KOŞUL VE GİZLİLİK
--
-- BULGU (A-4): onboarding'de kabul adımı YOKTU ve `user_consents` `terms`/
-- `privacy` türlerini kabul etmiyordu. Apple 1.2 kullanıcı içeriği barındıran
-- uygulamalarda koşul kabulü arıyor.
--
-- SÜRÜM ALANI: onay kaydı hangi METNİN onaylandığını da tutmalı (hukuki
-- belgedeki §7 Soru 4'ün teknik karşılığı). Sürümü İSTEMCİ BİLDİRMİYOR:
-- sunucu `app_config`'ten okuyor. Onayın ispat değeri, sürümü kullanıcının
-- beyan etmesine bağlı olamaz.

-- ==================================================== veli nesnelerinin sonu
-- Bağımlılık sırası: request_ → send_ (çağırır), confirm_ bağımsız.
drop function if exists public.request_guardian_consent(text);
drop function if exists public.confirm_guardian_consent(text);
drop function if exists public.send_guardian_email(text, text, text);
drop function if exists public.my_guardian_status();

drop table if exists public.guardian_requests;

alter table public.profiles drop column if exists guardian_email;

-- `app_config`'teki artık anahtarlar. E-posta sağlayıcısı BAŞKA bir iş için
-- kullanılmıyordu; anahtarları bırakmak "hangi sağlayıcıya ne gidiyor"
-- sorusunun yanıtını yanlış tutardı (hukuki metin §1.10 aktarım tablosu).
delete from public.app_config
 where key in ('guardian_confirm_url', 'email_api_url', 'email_api_key',
               'email_from');

-- ============================================== arkadaş ekleme kapısı (final)
-- Üç koşuldan biri kaldı, biri eklendi:
--   • anonim değil (kayıt öncesi kullanıcı sosyal yüzeye giremez — 0046)
--   • askıda/yasaklı değil (0062)
--   • reşitlik koşulu KALDIRILDI
--
-- Politika metnine dokunmak yerine tek yerden: `add_friend_by_code` SECURITY
-- DEFINER olduğu için RLS'i atlıyor ve kendi içinde bu fonksiyonu çağırıyor;
-- 0062'nin politikası doğrudan INSERT yolunu kapatıyor.
create or replace function public.can_add_friends(p_user uuid)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select not coalesce(
           (select p.is_anonymous from public.profiles p where p.id = p_user),
           true
         )
     and not public.is_suspended(p_user);
$fn$;

revoke execute on function public.can_add_friends(uuid) from public, anon;
grant  execute on function public.can_add_friends(uuid) to authenticated;

comment on function public.can_add_friends(uuid) is
  'Arkadaş ekleyebilir mi: anonim değil ve askıda değil. Veli onayı koşulu '
  '0063''te kaldırıldı (13+ rejimi); yaş artık arkadaşlığı etkilemiyor.';

-- `add_friend_by_code`'un reddi artık veli onayını değil askıyı anlatıyor:
-- 0045'teki metnin aynısı, yalnız reason dizesi 'onay_bekleniyor' → 'askida'.
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

  if not public.bump_rate_limit(
       'friend_code', 20,
       to_char(now() at time zone 'Europe/Istanbul', 'YYYY-MM-DD HH24')) then
    raise exception 'Çok fazla deneme yaptın, biraz sonra tekrar dene'
      using errcode = '54000';
  end if;

  if not public.can_add_friends(v_uid) then
    return query select false, 'askida'::text, null::uuid, null::text;
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

-- ============================================ yeni kullanıcı: veli dalı çıktı
-- 0046'daki metnin aynısı, `guardian_consent` metadata dalı SİLİNDİ. O dal
-- zaten ÖLÜYDÜ: istemci `signUp`'ı hiç çağırmıyor (0035'te silindi),
-- `signInAnonymously` + `updateUser` ile ilerliyor, yani `raw_user_meta_data`
-- hiçbir zaman dolmuyor.
--
-- Gövde YİNE KATALOGDAN üretiliyor: 0046'nın gerekçesi aynen geçerli —
-- `auth.users.is_anonymous` sütunu olmayan bir Supabase sürümünde sabit
-- kodlanmış bir `new.is_anonymous` tetikleyiciyi ve dolayısıyla KULLANICI
-- OLUŞTURMAYI çalışma anında kırardı.
do $mig$
declare
  v_has_col boolean;
  v_expr    text;
begin
  select exists (
    select 1 from pg_attribute a
     where a.attrelid = 'auth.users'::regclass
       and a.attname = 'is_anonymous'
       and not a.attisdropped
  ) into v_has_col;

  v_expr := case when v_has_col
                 then 'coalesce(new.is_anonymous, false)'
                 else '(new.email is null)'
            end;

  if not v_has_col then
    raise warning
      'auth.users.is_anonymous yok; anonim tespiti e-posta yokluğuna göre '
      'yapılacak. Supabase sürümünüz anonim oturumu desteklemiyor olabilir.';
  end if;

  execute format($sql$
    create or replace function public.handle_new_user()
    returns trigger
    language plpgsql
    security definer set search_path = public
    as $fn$
    begin
      insert into public.profiles (id, display_name, nickname, is_anonymous)
      values (
        new.id,
        coalesce(new.raw_user_meta_data->>'display_name', 'Öğrenci'),
        coalesce(new.raw_user_meta_data->>'nickname',
                 new.raw_user_meta_data->>'display_name', 'Öğrenci'),
        %s
      );

      perform public.assign_friend_code(new.id);
      return new;
    end
    $fn$;
  $sql$, v_expr);
end
$mig$;

-- ================================================== 13 yaş alt sınırı zorlanıyor
-- ÜST SINIR 5 → 13. Alt sınır (100 yaş) korunuyor.
--
-- 13 altı reddi AYRI BİR SQLSTATE ile (`KM013`) veriliyor: istemcinin "geçersiz
-- yıl" (yazım hatası) ile "çok küçüksün" (yaş kapısı) arasını ayırt edip nazik
-- bir açıklama gösterebilmesi için. Aynı hata koduyla dönseydi ya iki durum tek
-- metinde birleşirdi ya da istemci Türkçe mesaj eşleştirmek zorunda kalırdı.
--
-- TEK YAZIMLIK KURALI KORUNUYOR: reddedilen deneme bir YAZMA değil, dolayısıyla
-- 13 altı bir yıl giren kullanıcının hesabı KİLİTLENMİYOR — başka bir yıl
-- girebilir. Nötr yaş kapısının bilinen sınırı bu; alternatifi (reddedilen yılı
-- kaydedip hesabı kapatmak) çarkta yanlış kaydırmayı kalıcı cezaya çevirirdi.
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
  -- 100 yaştan eski ya da boş: veri girişi hatası.
  if p_year is null or p_year < v_now - 100 then
    raise exception 'Doğum yılı geçersiz' using errcode = '22023';
  end if;
  -- 13 yaş sınırı. Kullanım Koşulları bunu ilan ediyor; kod zorluyor.
  if p_year > v_now - 13 then
    raise exception 'Kimo 13 yaş ve üzeri için' using errcode = 'KM013';
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

-- ------------------------------------------------------------- yaş durumu
-- `my_guardian_status`ın yerini alıyor. Yaşın KENDİSİNİ döndürmüyor —
-- istemcinin ihtiyacı yılın yazılıp yazılmadığı ve (ayarlar satırı için)
-- reşitlik. `can_add_friends` artık burada DÖNMÜYOR: arkadaş ekleme yaşla
-- ilgisiz hâle geldi, askı durumu ise `my_sanction()`ın işi.
create or replace function public.my_age_status()
returns table (
  birth_year_set boolean,
  is_minor       boolean
)
language sql stable security definer set search_path = public
as $fn$
  select
    coalesce((select p.birth_year is not null
                from public.profiles p where p.id = auth.uid()), false),
    public.is_minor_now(auth.uid());
$fn$;

revoke execute on function public.my_age_status() from public, anon;
grant  execute on function public.my_age_status() to authenticated;

-- ============================================== onay defteri: koşul ve gizlilik
-- 'guardian' TÜRÜ CHECK'te KALIYOR (geçmiş kayıtlar geçerli olmalı), yazma
-- yolundan çıkıyor.
alter table public.user_consents
  drop constraint if exists user_consents_kind_check;
alter table public.user_consents
  add constraint user_consents_kind_check
  check (kind in ('guardian', 'share', 'ai_upload', 'terms', 'privacy'));

-- Hangi METNİN onaylandığı. Eski kayıtlarda null: o gün bir sürüm tutulmuyordu
-- ve uydurmak, defterin tek işi olan doğruluğu bozardı.
alter table public.user_consents
  add column if not exists text_version text;

comment on column public.user_consents.text_version is
  'Onaylanan hukuki metnin sürümü. Yalnızca terms/privacy kayıtlarında dolu; '
  'değeri SUNUCU yazar (app_config.legal_version), istemci bildiremez.';

-- `my_consents` sürümü de göstersin (0037'deki metnin aynısı + bir sütun).
drop view if exists public.my_consents;
create view public.my_consents
  with (security_invoker = true)
  as select distinct on (kind)
       kind, granted, recorded_at, source, text_version
     from public.user_consents
    order by kind, recorded_at desc;

grant select on public.my_consents to authenticated;

-- `record_consent` artık 'guardian' KABUL ETMİYOR (o türü yazan tek yol
-- `confirm_guardian_consent`'ti ve o düştü), 'terms'/'privacy' de kabul
-- etmiyor — onlar sürüm damgası gerektiriyor ve `accept_legal_terms`ten
-- geçiyorlar. Sürümsüz bir koşul onayı, ispat değeri olmayan bir kayıttır.
create or replace function public.record_consent(
  p_kind    text,
  p_granted boolean
)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_last boolean;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_kind not in ('share', 'ai_upload') then
    raise exception 'geçersiz onay türü' using errcode = '22023';
  end if;
  if p_granted is null then
    raise exception 'onay değeri boş olamaz' using errcode = '22023';
  end if;

  select c.granted into v_last
    from public.user_consents c
   where c.user_id = v_uid and c.kind = p_kind
   order by c.recorded_at desc
   limit 1;

  if v_last is not distinct from p_granted then
    return;
  end if;

  insert into public.user_consents (user_id, kind, granted, source)
  values (v_uid, p_kind, p_granted, 'settings');
end
$fn$;

revoke execute on function public.record_consent(text, boolean) from public, anon;
grant  execute on function public.record_consent(text, boolean) to authenticated;

-- --------------------------------------------------------- koşul kabulü
-- İKİ SATIR TEK ÇAĞRIDA: kullanıcı tek bir kutuyu işaretliyor ama iki ayrı
-- belgeyi kabul ediyor; defterde ikisi ayrı ayrı görünmeli ki biri
-- güncellendiğinde diğerinin onayı bozulmasın.
--
-- `source = 'signup'`: onay kayıt adımında alınıyor. `auth.uid()` o an ZATEN
-- var — kullanıcı anonim oturumla geliyor ve `updateUser` ile kalıcıya
-- dönüşüyor, yani `uid` değişmiyor ve onay doğru hesaba yazılıyor.
--
-- Sürüm `app_config`ten. Anahtar girilmemişse '1.0' varsayılıyor ve UYARI
-- yazılıyor: sessizce yanlış bir sürüm damgalamak, damgalamamaktan kötüdür.
create or replace function public.accept_legal_terms()
returns text
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_ver text;
  k     text;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  select value into v_ver from public.app_config where key = 'legal_version';
  if v_ver is null or btrim(v_ver) = '' then
    raise warning 'accept_legal_terms: app_config.legal_version yok, 1.0 varsayildi';
    v_ver := '1.0';
  end if;

  foreach k in array array['terms', 'privacy'] loop
    -- Aynı sürüm zaten onaylıysa yeni satır yazılmıyor: defter gürültüsüz
    -- kalsın. Sürüm DEĞİŞTİYSE yeni satır yazılır — onay metne bağlıdır.
    if not exists (
      select 1 from public.user_consents c
       where c.user_id = v_uid
         and c.kind = k
         and c.granted
         and c.text_version is not distinct from v_ver
    ) then
      insert into public.user_consents
        (user_id, kind, granted, source, text_version)
      values (v_uid, k, true, 'signup', v_ver);
    end if;
  end loop;

  return v_ver;
end
$fn$;

revoke execute on function public.accept_legal_terms() from public, anon;
grant  execute on function public.accept_legal_terms() to authenticated;

comment on function public.accept_legal_terms() is
  'Kullanım Koşulları + Gizlilik Politikası onayını sürüm damgasıyla deftere '
  'yazar. Sürümü sunucu belirler (app_config.legal_version).';
