-- 0037 — Onay defteri: zaman damgalı ve değiştirilemez (Değişmez 7)
--
-- BULGU, denetim raporundakinden FARKLI BİR YERDE. Rapor "guardian_consent /
-- share_consent kullanıcının kendi düzenleyebildiği alanda duruyor" diyordu ve
-- profiles sütununu işaret ediyordu. Doğrulamada çıktı ki:
--
--   • public.profiles.guardian_consent ÖLÜ BİR SÜTUN — hiçbir Dart kodu onu
--     okumuyor ya da yazmıyor. Kilitlemek güvenlik kazancı sağlamıyor.
--   • Gerçek onay kaydı AUTH KULLANICI METADATA'SINDA:
--       auth_repository.dart:29  → signUp(data: {'guardian_consent': ...})
--       user_profile.dart:91-94  → auth.updateUser(data: {'share_consent': ...})
--     Auth metadata TAMAMEN kullanıcı-yazılabilir ve zaman damgası yok. Yani
--     kullanıcı onayını geriye dönük değiştirebiliyor ve ne zaman verildiği
--     hiçbir yerde durmuyor.
--
-- ÇÖZÜM: yalnızca EKLEME yapılabilen bir defter. Burada ayrı tablo doğru araç —
-- Küme A'da ayrı tabloyu reddetmiştim çünkü orada sütun ayrıcalığı yetiyordu;
-- burada gereksinim "değiştirilemez ve zaman damgalı", yani yapısal olarak bir
-- DEFTER. Bir sütunun tek bir güncel değeri olur, geçmişi olmaz.
--
-- KAPSAM SINIRI (görev metnine uyarak): yalnızca sahiplik ve değiştirilemezlik.
-- Yaş kapısı yeniden tasarımı, is_minor mantığı ve hukuki metinler KAPSAM DIŞI.

create table if not exists public.user_consents (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid()
                references auth.users(id) on delete cascade,
  kind        text not null check (kind in ('guardian', 'share')),
  granted     boolean not null,
  recorded_at timestamptz not null default now(),
  source      text not null default 'settings'
                check (source in ('signup', 'settings'))
);

create index if not exists user_consents_user_kind_idx
  on public.user_consents (user_id, kind, recorded_at desc);

alter table public.user_consents enable row level security;

-- Kendi kayıtlarını GÖREBİLİR.
drop policy if exists consents_select_own on public.user_consents;
create policy consents_select_own on public.user_consents
  for select to authenticated using (auth.uid() = user_id);

-- Yazma yalnızca RPC'den. UPDATE ve DELETE hiçbir role verilmiyor — defterin
-- değiştirilemez olmasının tek gerçek garantisi bu.
revoke all    on public.user_consents from public, anon, authenticated;
grant  select on public.user_consents to authenticated;

comment on table public.user_consents is
  'Yalnızca ekleme yapılan onay defteri. UPDATE/DELETE hiçbir uygulama rolüne '
  'verilmez; kayıtlar record_consent() ile eklenir ve geriye dönük değiştirilemez.';

-- ------------------------------------------------------------------ yazma
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
  if p_kind not in ('guardian', 'share') then
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

  -- Aynı değer üst üste yazılmasın; defter gürültüsüz kalsın. (Kayıt yoksa
  -- v_last NULL olur ve `is not distinct from` doğru davranır.)
  if v_last is not distinct from p_granted then
    return;
  end if;

  insert into public.user_consents (user_id, kind, granted, source)
  values (v_uid, p_kind, p_granted, 'settings');
end
$fn$;

revoke execute on function public.record_consent(text, boolean) from public, anon;
grant  execute on function public.record_consent(text, boolean) to authenticated;

-- ------------------------------------------------------------------ okuma
-- Her tür için EN SON kayıt. security_invoker = true: user_consents'in RLS'i
-- uygulanır, yani herkes yalnızca kendi onaylarını görür.
create or replace view public.my_consents
  with (security_invoker = true)
  as select distinct on (kind)
       kind, granted, recorded_at, source
     from public.user_consents
    order by kind, recorded_at desc;

grant select on public.my_consents to authenticated;

-- ------------------------------------------------------- kayıt anındaki onay
-- Veli onayı kayıt formunda veriliyor ve o anda henüz oturum (auth.uid()) yok,
-- dolayısıyla istemci RPC'yi çağıramaz. Bu yüzden signUp metadata'sından
-- SUNUCU TARAFINDA deftere yazılıyor: değer kullanıcının beyanı (doğru olan da
-- bu), ama kaydın kendisi zaman damgalı ve artık geriye dönük değiştirilemez.
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

  return new;
end
$fn$;
