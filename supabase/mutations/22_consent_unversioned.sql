-- test: supabase/tests/065_consents.sql
--
-- MUTASYON: koşul onayını SÜRÜMSÜZ yaz.
-- BEKLENEN: 065'in "onay kaydı METİN SÜRÜMÜNÜ taşıyor" ve "sürüm değişince
-- YENİ satır yazılıyor" iddiaları kırmızı.
--
-- Neden bu mutasyon: sürüm alanı defterin tek ispat değeri. Sütun dolu ama
-- null yazılıyorsa hiçbir yapı bozulmaz — kayıt görünüşte durur, ama metin
-- değiştiğinde geçmiş onayların hangi sürüme ait olduğu söylenemez. Bu sessiz
-- kaybı yakalayan tek şey testin sürümü GERÇEKTEN okuması.
create or replace function public.accept_legal_terms()
returns text
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  k     text;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  foreach k in array array['terms', 'privacy'] loop
    if not exists (
      select 1 from public.user_consents c
       where c.user_id = v_uid and c.kind = k and c.granted
    ) then
      insert into public.user_consents
        (user_id, kind, granted, source, text_version)
      values (v_uid, k, true, 'signup', null);
    end if;
  end loop;

  return null;
end
$fn$;
-- @UNDO
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
