-- test: supabase/tests/216_quiet_hours.sql
--
-- MUTASYON: `send_push`ten sessiz saat suzgecini sok.
-- BEKLENEN: 216'nin "SESSIZ SAATTE bildirim GONDERILMIYOR" iddiasi kirmizi.
--
-- NEDEN BU BIR KORUMA: Ayarlar'daki "Bu aralikta bildirim gonderilmez" sozu
-- Task 17'ye kadar YALNIZCA cihazda planlanan hatirlatmalar icin geciyordu.
-- Aralik sadece shared_preferences'ta duruyor, sunucuya hic gitmiyor ve
-- send_push saat kontrolu yapmiyordu — arkadastan gelen her bildirim gecenin
-- ortasinda da gidiyordu. Suzgec dusunce iddia "imlec yazilmadi" diyemez.
--
-- SUZGEC DUSURUYOR, ERTELEMIYOR ve bu bilincli: bilgi kaybolmuyor (gelen soru
-- gelen kutusunda, arkadaslik istegi arkadaslar sekmesinde), yalnizca rahatsiz
-- etme bastiriliyor.
--
-- NOT: iki govde de goc dosyasindan URETILDI. Kaynak: 0100.
create or replace function public.send_push(
  p_user  uuid,
  p_kind  text,
  p_actor text,
  p_extra text default null
)
returns void
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_url    text;
  v_key    text;
  v_mascot text;
  v_line   text;
  v_idx    int;
  v_title  text;
begin
  select value into v_url from public.app_config where key = 'push_url';
  select value into v_key from public.app_config where key = 'push_service_key';
  if v_url is null or v_key is null then
    raise warning 'send_push: app_config eksik (push_url ve/veya push_service_key)';
    return;
  end if;

  -- Alıcının personası; profil satırı yoksa ya da boşsa şefkatli varsayılan.
  select coalesce(mascot, 'ev_hanimi') into v_mascot
    from public.profiles where id = p_user;
  v_mascot := coalesce(v_mascot, 'ev_hanimi');

  -- SON GÖNDERİLENİ DIŞLA. Aynı cümleyi üst üste gören kullanıcı bildirimi
  -- görmez oluyor; beş varyantta bunun olasılığı %20'ydi.
  select l.idx, l.line into v_idx, v_line
    from public.push_lines l
    left join public.push_cursors c
      on c.user_id = p_user and c.kind = p_kind
   where l.kind = p_kind
     and l.mascot = v_mascot
     and (c.idx is null or l.idx <> c.idx)
   order by random()
   limit 1;

  -- Tek varyant kalmışsa dışlama havuzu boşaltır. Bildirimi DÜŞÜRMEK yerine
  -- tekrara izin veriyoruz: tekrar etmiş bir hatırlatma, hiç gelmeyenden iyi.
  if v_line is null then
    select l.idx, l.line into v_idx, v_line
      from public.push_lines l
     where l.kind = p_kind and l.mascot = v_mascot
     order by random()
     limit 1;
  end if;

  -- Buraya düşmek artık yalnızca senaryonun hiç metni yoksa mümkün; pgTAP 240
  -- her (kind, mascot) hücresinde en az beş satır olduğunu iddia ediyor.
  if v_line is null then
    raise warning 'send_push: metin yok (kind=%, mascot=%)', p_kind, v_mascot;
    return;
  end if;

  v_line := replace(v_line, '{ad}',  coalesce(p_actor, 'Bir arkadaşın'));
  v_line := replace(v_line, '{lig}', coalesce(p_extra, ''));
  v_line := replace(v_line, '{n}',   coalesce(p_extra, ''));

  select title into v_title from public.push_kinds where kind = p_kind;
  v_title := coalesce(v_title, 'Kimo');

  insert into public.push_cursors (user_id, kind, idx)
  values (p_user, p_kind, v_idx)
  on conflict (user_id, kind) do update set idx = excluded.idx;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'Authorization', 'Bearer ' || v_key
               ),
    body    := jsonb_build_object(
                 'user_id', p_user,
                 'title',   v_title,
                 'body',    v_line,
                 'kind',    p_kind
               )
  );
exception when others then
  raise warning 'send_push başarısız: %', sqlerrm;
  return;
end
$fn$;
-- @UNDO
create or replace function public.send_push(
  p_user  uuid,
  p_kind  text,
  p_actor text,
  p_extra text default null
)
returns void
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_url    text;
  v_key    text;
  v_mascot text;
  v_line   text;
  v_idx    int;
  v_title  text;
begin
  -- SESSİZ SAATLER SUNUCUDA DA (0100).
  --
  -- Ayarlardaki "Bu aralıkta bildirim gönderilmez" sözü yalnızca CİHAZDA
  -- planlanan hatırlatmalar için geçiyordu: aralık `shared_preferences`ta
  -- duruyor, `send_push` onu hiç bilmiyordu. Arkadaştan gelen her bildirim
  -- (soru geldi, soru çözüldü, arkadaşlık isteği, seri, lig) gece 03:00'te de
  -- gidiyordu.
  --
  -- DÜŞÜRÜLÜYOR, ERTELENMİYOR — ve bu bilinçli. Ertelemek bir kuyruk ve onu
  -- boşaltan bir cron demekti; kazancı ise sınırlı, çünkü bilginin KENDİSİ
  -- kaybolmuyor: gelen soru gelen kutusunda, arkadaşlık isteği arkadaşlar
  -- sekmesinde duruyor. Sessiz saatlerde bastırılan şey BİLGİ değil, RAHATSIZ
  -- ETME. Kullanıcının o ayarla istediği de tam olarak bu.
  --
  -- BOŞ ARALIK: başlangıç ile bitiş eşitse sessiz saat YOK. İstemcideki
  -- `AppSettings.isQuietHour` ile birebir aynı kural — iki yerde yaşayan bir
  -- kuralın ayrışmasını bu depo iki kez yaşadı.
  declare
    v_qs int;
    v_qe int;
    v_h  int;
  begin
    select quiet_start, quiet_end into v_qs, v_qe
      from public.profiles where id = p_user;
    if v_qs is not null and v_qe is not null and v_qs <> v_qe then
      v_h := extract(hour from now() at time zone 'Europe/Istanbul')::int;
      if (v_qs < v_qe and v_h >= v_qs and v_h < v_qe)
         or (v_qs > v_qe and (v_h >= v_qs or v_h < v_qe)) then
        return;
      end if;
    end if;
  end;

  select value into v_url from public.app_config where key = 'push_url';
  select value into v_key from public.app_config where key = 'push_service_key';
  if v_url is null or v_key is null then
    raise warning 'send_push: app_config eksik (push_url ve/veya push_service_key)';
    return;
  end if;

  -- Alıcının personası; profil satırı yoksa ya da boşsa şefkatli varsayılan.
  select coalesce(mascot, 'ev_hanimi') into v_mascot
    from public.profiles where id = p_user;
  v_mascot := coalesce(v_mascot, 'ev_hanimi');

  -- SON GÖNDERİLENİ DIŞLA. Aynı cümleyi üst üste gören kullanıcı bildirimi
  -- görmez oluyor; beş varyantta bunun olasılığı %20'ydi.
  select l.idx, l.line into v_idx, v_line
    from public.push_lines l
    left join public.push_cursors c
      on c.user_id = p_user and c.kind = p_kind
   where l.kind = p_kind
     and l.mascot = v_mascot
     and (c.idx is null or l.idx <> c.idx)
   order by random()
   limit 1;

  -- Tek varyant kalmışsa dışlama havuzu boşaltır. Bildirimi DÜŞÜRMEK yerine
  -- tekrara izin veriyoruz: tekrar etmiş bir hatırlatma, hiç gelmeyenden iyi.
  if v_line is null then
    select l.idx, l.line into v_idx, v_line
      from public.push_lines l
     where l.kind = p_kind and l.mascot = v_mascot
     order by random()
     limit 1;
  end if;

  -- Buraya düşmek artık yalnızca senaryonun hiç metni yoksa mümkün; pgTAP 240
  -- her (kind, mascot) hücresinde en az beş satır olduğunu iddia ediyor.
  if v_line is null then
    raise warning 'send_push: metin yok (kind=%, mascot=%)', p_kind, v_mascot;
    return;
  end if;

  v_line := replace(v_line, '{ad}',  coalesce(p_actor, 'Bir arkadaşın'));
  v_line := replace(v_line, '{lig}', coalesce(p_extra, ''));
  v_line := replace(v_line, '{n}',   coalesce(p_extra, ''));

  select title into v_title from public.push_kinds where kind = p_kind;
  v_title := coalesce(v_title, 'Kimo');

  insert into public.push_cursors (user_id, kind, idx)
  values (p_user, p_kind, v_idx)
  on conflict (user_id, kind) do update set idx = excluded.idx;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'Authorization', 'Bearer ' || v_key
               ),
    body    := jsonb_build_object(
                 'user_id', p_user,
                 'title',   v_title,
                 'body',    v_line,
                 'kind',    p_kind
               )
  );
exception when others then
  raise warning 'send_push başarısız: %', sqlerrm;
  return;
end
$fn$;
