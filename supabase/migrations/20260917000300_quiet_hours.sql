-- 0100 — sessiz saatler SUNUCUDA (Task 17)
--
-- BULGU: Ayarlar'daki "Bu aralıkta bildirim gönderilmez" sözü yalnızca
-- CİHAZDA planlanan hatırlatmalar için geçiyordu. Aralık yalnızca
-- `shared_preferences`ta duruyor, hiçbir RPC ile sunucuya gitmiyor ve
-- `send_push` saat kontrolü YAPMIYOR. Yani arkadaştan gelen her bildirim —
-- soru geldi, soru çözüldü, arkadaşlık isteği, arkadaş serisi, lig sonucu —
-- sessiz aralığın tam ortasında da gidiyordu. Task 16 sözü daraltarak dürüst
-- hâle getirdi; bu göç sözü GERÇEK hâle getiriyor.
--
-- SÜTUNLAR KİLİTLİ, YAZMA RPC'DEN. `profiles`ın istemciye açık tek sütunu
-- `avatar_path` ve bu bilinçli; üstelik 05 ve 31 numaralı mutasyonların geri
-- alma yarıları o listeyi ELLE yeniden kuruyor (`grant update (avatar_path)`).
-- Yeni bir sütunu istemciye açmak, o mutasyonlar koştuktan sonra yetkinin
-- sessizce kaybolması demekti. Deponun kalıbı zaten RPC: nickname/mascot
-- `upsert_my_profile`, doğum yılı `set_birth_year`, arkadaş kodu
-- `assign_friend_code`.
--
-- VARSAYILAN 22–08: istemcinin bugünkü varsayılanıyla aynı
-- (`AppSettings.defaultQuietStart/End`). Mevcut kullanıcılar da o aralığı
-- alıyor, yani davranış istemcide gördükleriyle tutarlı.
alter table public.profiles
  add column if not exists quiet_start int not null default 22,
  add column if not exists quiet_end   int not null default 8;

alter table public.profiles
  drop constraint if exists profiles_quiet_range_ck;
alter table public.profiles
  add constraint profiles_quiet_range_ck
  check (quiet_start between 0 and 23 and quiet_end between 0 and 23);

comment on column public.profiles.quiet_start is
  'Sessiz aralığın başlangıç saati (Istanbul, 0-23). `send_push` bu aralıkta '
  'hiçbir bildirim göndermiyor (0100). Başlangıç ile bitiş EŞİTSE sessiz '
  'saat yok — istemcideki `AppSettings.isQuietHour` ile aynı kural.';
comment on column public.profiles.quiet_end is
  'Sessiz aralığın bitiş saati (Istanbul, 0-23). Bkz. quiet_start.';

-- ---------------------------------------------------------------- yazma yolu
create function public.set_quiet_hours(p_start int, p_end int)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  -- SINIR SUNUCUDA DA: CHECK kısıtı zaten var ama hata mesajı kullanıcıya
  -- anlamsız gelirdi; burada sessizce kırpmak yerine REDDEDİLİYOR, çünkü
  -- istemci zaten 0-23 arası bir seçiciden gönderiyor ve aralık dışı bir
  -- değer gelmesi bir hatanın işareti.
  if p_start is null or p_end is null
     or p_start < 0 or p_start > 23 or p_end < 0 or p_end > 23 then
    raise exception 'saat 0-23 aralığında olmalı' using errcode = '22023';
  end if;
  update public.profiles
     set quiet_start = p_start, quiet_end = p_end
   where id = v_uid;
end
$fn$;

revoke execute on function public.set_quiet_hours(int, int) from public, anon;
grant  execute on function public.set_quiet_hours(int, int) to authenticated;

comment on function public.set_quiet_hours(int, int) is
  'Kullanıcının sessiz saat aralığını yazar (0100). Sütunlar kilitli; tek '
  'yazma yolu bu. Başlangıç ile bitiş eşitse sessiz saat yok demektir.';

-- ------------------------------------------------------------- süzgeç
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

revoke execute on function public.send_push(uuid, text, text, text)
  from public, anon, authenticated;

comment on function public.send_push(uuid, text, text, text) is
  'Kişiselleştirilmiş push gönderir. SESSİZ SAATLERDE HİÇ GÖNDERMİYOR (0100): '
  'bilgi kaybolmuyor (gelen kutusu, arkadaşlar sekmesi yerinde duruyor), '
  'yalnızca rahatsız etme bastırılıyor. `authenticated` ÇAĞIRAMAZ.';

-- ------------------------------------------------------------- okuma yolu
-- SONA EKLEME: `create or replace view` yalnızca sona sütun ekleyebiliyor ve
-- burada tam olarak o yapılıyor, yani görünümü düşürmek gerekmiyor (0099'un
-- zinciri tekrar kurulmuyor).
create or replace view public.my_daily_state
with (security_invoker = false) as
select
  p.id                                              as user_id,
  p.gems,
  p.xp,
  case when p.last_activity_date >= public.istanbul_day() - 1
       then p.streak else 0 end                     as streak,
  case when p.week_start = public.istanbul_week()
       then p.weekly_xp else 0 end                  as weekly_xp,
  p.league,
  p.last_activity_date,
  p.premium_until,
  public.istanbul_day()                             as today,
  public.istanbul_week()                            as week_start,
  (
    select count(*)::int from public.mistakes m
     where m.user_id = p.id
       and m.last_reviewed_at >=
           (public.istanbul_day())::timestamp at time zone 'Europe/Istanbul'
  )                                                 as reviewed_today_count,
  (
    select count(*)::int from public.mistakes m
     where m.user_id = p.id
       and not m.mastered
       and (
         m.next_review_at <= now()
         or (m.next_review_at is null
             and m.next_review_date <= public.istanbul_day())
       )
  )                                                 as due_count,
  (
    select count(*)::int from public.received_questions rq
     where rq.solved_at is null
  )                                                 as unsolved_received_count,
  s.ai_tier,
  s.ai_state,
  s.ai_left,
  s.ai_window_left,
  s.ai_window_limit,
  s.ai_month_left,
  s.ai_month_limit,
  s.ai_next_at,
  s.ai_next_at_hm,
  s.ai_month_resets_at,
  s.ai_month_resets_on,
  s.ai_window_hours,
  s.ad_rewards_left,
  s.ad_rewards_per_day,
  s.ad_offer,
  s.plus_window_limit,
  s.plus_month_limit,
  f.ff_pair_streak,
  f.ff_multi_capture,
  f.ff_ad_reward,
  f.ff_iap,
  sub.sub_status,
  sub.sub_store,
  sub.sub_expires_at,
  sub.sub_renews,
  sub.sub_in_trial,
  -- ÜCRETSİZ KATMANIN sınırları (0099). Paywall'ın "Ücretsiz" sütunu bunları
  -- kullanıyor; `ai_window_limit`/`ai_month_limit` ÇAĞIRANIN katmanını
  -- anlatıyor ve abonede/anonimde yanlış sütun oluyordu.
  s.free_window_limit,
  s.free_month_limit,
  -- GÜNLÜK HEDEF ÖDÜLÜ BUGÜN ALINDI MI (0099). Sunucuda zaten duruyordu ama
  -- yayınlanmıyordu: istemci yalnızca oturum-içi bir alana bakıyor ve
  -- `GameProgress.clear()` onu çıkışta sıfırlıyor. Kullanıcı uygulamayı
  -- yeniden kurar ya da ikinci cihazdan girerse istemci "ödül alınmadı"
  -- sanıyor, ilerleme halkasını eksik gösteriyor ve `claim_daily_goal`
  -- sessizce `gems_awarded = 0` döndürüyordu.
  p.daily_goal_date,
  -- SESSİZ SAATLER OKUNABİLİR OLMALI (0100). Yazma `set_quiet_hours`tan
  -- geçiyor ama istemcinin DEĞERİ de görmesi gerekiyor: yalnızca cihazda
  -- tutulsaydı ikinci cihaz kendi varsayılanını (22–08) gösterir, sunucu ise
  -- ilk cihazın yazdığını uygular — deponun iki turdur kapattığı "istemci bir
  -- yere yazıyor, okuyan başka yere bakıyor" sınıfının aynısı.
  p.quiet_start,
  p.quiet_end
from public.profiles p,
     public.ai_state() s,
     public.feature_flags() f
-- LEFT JOIN LATERAL: aboneliği olmayan kullanıcıda `subscription_state()`
-- SIFIR satır döndürüyor ve virgülle (cross join) yazılsaydı GÖRÜNÜMÜN
-- TAMAMI boş dönerdi — yani abonesi olmayan herkes HUD'unu kaybederdi.
left join lateral public.subscription_state() sub on true
where p.id = auth.uid();

comment on view public.my_daily_state is
  'Kullanıcının günlük durumu (yalnızca kendi satırı). Analiz hakkının TÜM '
  'gösterim değerleri, ücretsiz katman sınırları (0099), özellik bayrakları, '
  'abonelik durumu, günlük hedef ödülünün alındığı gün ve sessiz saat aralığı '
  '(0100). İstemci hiçbir şey hesaplamıyor.';
