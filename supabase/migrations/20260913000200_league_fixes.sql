-- 0089 — Lig: çakışan terfi/düşme, çift kohort, engel süzgeci, ölü tür
--        (Task 13 · Paket 1)
--
-- Task 12 araştırmasında çıkan dört bulgunun tamamı burada kapanıyor.
--
-- ==========================================================================
-- 1) TERFİ VE DÜŞME KÜMELERİ ÇAKIŞIYORDU
--
-- `settle_past_leagues` terfiyi "kohortta ilk 5 (xp>0)", düşmeyi "son 5"
-- olarak hesaplıyordu ve düşmenin tek koruması `count(*) > 5`'ti. Kohort
-- TAVANI 30 ama kademe nüfusunun 30'a bölümünden ARTAN grup düzenli olarak
-- 6-9 kişilik oluyor — ve o aralıkta ilk-5 ile son-5 KESİŞİYOR (n=6'da
-- 2.-5. sıra, n=9'da 5. sıra). Kesişim n=10'da bitiyor.
--
-- Üç ayrı zarar veriyordu:
--   a) Terfi ve düşme AYRI iki UPDATE'ti ve ikincisi BİRİNCİNİN yazdığı
--      değeri okuyordu (aynı işlem, sonraki komut) → orta kademelerde hak
--      edilmiş terfi sessizce iptal oluyordu (bronz→gumus→bronz).
--   b) Terfi `elmas`ta tavanlı (`else 'elmas'`) ama düşme `elmas→zumrut`:
--      6 kişilik elmas kohortunda 2. SIRADAKİ OYUNCU DÜŞÜYORDU.
--   c) `on_friend_milestone` terfi UPDATE'inde ateşlenip arkadaşlara
--      "yükseldi" push'u atıyor, sonra aynı işlemde kullanıcı geri iniyordu.
--
-- ÇÖZÜM: düşme kapısı `>= 11`. Böylece terfi (ilk 5) ve düşme (son 5)
-- kümeleri MATEMATİKSEL OLARAK kesişemez, en az bir kişi ortada kalır ve
-- elmas kenar durumu kapanır. Ve bu, İSTEMCİNİN ZATEN ÇİZDİĞİ kural:
-- `league_screen.dart:182-184` düşme çizgisini yalnızca `total >= 11` iken
-- çiziyordu — bugüne kadar arayüz ile sunucu AYRIŞIYORDU (7 kişilik kohortta
-- kullanıcı "düşme bölgesinde değilim" görüp hafta sonunda düşüyordu).
--
-- Hesap iki korele alt sorgudan TEK pencere ifadesine indi: çakışma kuralı
-- artık tek satırda görünür ve kohort başına O(n²) karşılaştırma düştü.
--
-- YENİ KULLANICI KORUMASI: ilk iki haftasında düşmüyor. Hafta ortasında
-- kaydolan kullanıcı 0 XP'yle son 5'e düşüp ilk haftasında kademe
-- kaybediyordu.
--
-- ==========================================================================
-- 2) AYNI HAFTADA İKİ KOHORT
--
-- İki yerleştirme yolu FARKLI advisory lock anahtarı alıyordu:
--   assign_week_cohorts      → hashtext('cohorts' || hafta)
--   ensure_league_membership → hashtext(kademe || hafta)
-- Birbirlerini dışlamıyorlardı; üstelik `ensure`in "zaten üye miyim"
-- kontrolü KİLİTTEN ÖNCE yapılıyordu. Pazartesi 00:05'te cron koşarken
-- uygulamayı açan kullanıcı "üye değilim" okuyup kendini İKİNCİ bir kohorta
-- yazabiliyordu; `on conflict do nothing` bunu yakalamıyor çünkü cohort_id
-- farklı. Ve "bir kullanıcı haftada tek kohort" diyen HİÇBİR kısıt yoktu.
--
-- ÇÖZÜM iki katmanlı: tek kilit anahtarı + kilitten SONRA tekrarlanan üyelik
-- kontrolü (double-checked locking), ve asıl savunma olarak
-- `unique (user_id, week_start)`. Advisory kilit bir sözleşme, kısıt bir
-- garanti.
--
-- ==========================================================================
-- 3) ENGEL SÜZGECİ
--
-- `my_league_board` engellenen kullanıcıyı hiç süzmüyordu: adı, XP'si, serisi
-- ve AVATARIYLA tabloda duruyordu. `can_read_avatar`ın kohort dalı da engelli
-- kişinin avatarına imzalı URL üretiyordu (bu bir DEPOLAMA erişimi, arayüz
-- ayrıntısı değil). Arayüz metni ise fazlasını vaat ediyor:
-- `app_tr.arb:933` "…listelerde seni göremez".
--
-- ÇÖZÜM: satır KALIYOR, kimlik maskeleniyor. Satırı düşürmek sıralamayı ve
-- üye sayısını bozardı (terfi/düşme bölgesi istemcide `total` üzerinden
-- çizilir) ve engellenen kişiye kohorttan birinin kaybolduğunu fark
-- ettirirdi — yani engeli ele verirdi.
--
-- ==========================================================================
-- 4) `league_result` TÜRÜ İKİ YERDE BİRDEN ÖLÜYDÜ
--
-- 4 persona × 5 metin = 20 cümle ve "Hafta kapandı 🏆" başlığı tabloda
-- duruyordu ama ne tetikleyici vardı ne de tür `send-push`in ALLOWED_KINDS
-- beyaz listesindeydi — bir tetikleyici yazılsa bile 400 ile düşerdi.
--
-- ÇÖZÜM: sonuç bildirimi settle'dan AYRI bir işte. Gerekçe SAAT: haftalık
-- devir Pazartesi 00:05 Istanbul'da koşuyor ve `send_push`te sessiz aralık
-- YOK — sonucu settle içinde göndermek 13-18 yaş kitlesine gece yarısı
-- bildirim atmak olurdu. `send_league_results()` ayrı bir cron'la sabah
-- 09:00'da koşuyor ve kapanmış ama bildirimi gitmemiş kohortları süpürüyor.
--
-- GERİ ALMA: `select cron.unschedule(jobid) from cron.job where jobname =
-- 'league-results-push';`, bu dosyadaki fonksiyonları 0051/0043/0053'teki
-- gövdeleriyle yeniden yaratın ve `drop index league_members_user_week_uniq`.

-- ==================================================== 1) şema: hafta + hareket
alter table public.league_members
  add column if not exists week_start date,
  add column if not exists move       text
    check (move is null or move in ('up', 'down', 'stay'));

comment on column public.league_members.week_start is
  'Kohortun haftası, DENORMALİZE. Tek amacı `unique (user_id, week_start)` '
  'kısıtını mümkün kılmak: kısıt league_cohorts üzerinden kurulamıyor.';
comment on column public.league_members.move is
  'Hafta kapanışında yazılan sonuç: up | down | stay. Sonuç bildirimini '
  'besliyor (settle ile bildirim AYRI işler — bkz. send_league_results).';

-- Mevcut satırlar için doldur; ardından NOT NULL.
update public.league_members m
   set week_start = c.week_start
  from public.league_cohorts c
 where c.id = m.cohort_id and m.week_start is null;

alter table public.league_members
  alter column week_start set not null;

-- Kohorttan otomatik doldurma: çağıranların hiçbiri bu sütunu yazmıyor ve
-- yazmak zorunda da olmamalı (tek doğruluk kaynağı kohortun kendisi).
create or replace function public.league_member_week()
returns trigger language plpgsql security definer set search_path = public
as $fn$
begin
  select c.week_start into new.week_start
    from public.league_cohorts c where c.id = new.cohort_id;
  return new;
end;
$fn$;

drop trigger if exists set_league_member_week on public.league_members;
create trigger set_league_member_week
  before insert on public.league_members
  for each row execute function public.league_member_week();

-- ASIL SAVUNMA. Advisory kilit bir sözleşme; bu bir garanti.
create unique index if not exists league_members_user_week_uniq
  on public.league_members (user_id, week_start);

-- Sonuç bildirimi settle'dan AYRI koştuğu için (bkz. aşağıdaki gerekçe)
-- "bu kohortun sonucu gönderildi mi" sorusunun bir yeri olmalı.
alter table public.league_cohorts
  add column if not exists results_pushed_at timestamptz;

comment on column public.league_cohorts.results_pushed_at is
  'Sonuç bildiriminin gönderildiği an. `settled_at` dolu ama bu boşsa '
  'send_league_results() o kohortu süpürür. İkisi AYRI çünkü devir gece '
  '00:05''te koşuyor, bildirim sabah 09:00''da gidiyor.';

-- ==================================================== 2) settle
create or replace function public.settle_past_leagues()
returns void
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_week date := public.istanbul_week();
begin
  -- KİLİT: `ensure_league_membership` authenticated'a açık ve bekleyen kohort
  -- varsa bu fonksiyonu çağırıyor. İki kullanıcı hafta başında aynı anda lig
  -- sekmesini açarsa ikisi de "bekleyen kohort var" kontrolünü geçip settle'ı
  -- çağırır; `profiles` UPDATE'inin qual'i `p.id = s.user_id` olduğu için
  -- kademe İKİNCİ KEZ kayabilirdi (READ COMMITTED'de çift-uygulama).
  perform pg_advisory_xact_lock(hashtext('league_settle'), hashtext(v_week::text));

  drop table if exists pg_temp._settle;
  create temp table _settle on commit drop as
  with ranked as (
    select m.cohort_id,
           m.user_id,
           c.week_start,
           p.league as old_league,
           -- Beraberlik `user_id` ile deterministik çözülüyor (0018 kararı).
           rank() over (partition by m.cohort_id
                        order by m.xp desc, m.user_id asc) as rnk,
           count(*)  over (partition by m.cohort_id)       as n,
           m.xp,
           p.created_at
      from public.league_members m
      join public.league_cohorts c on c.id = m.cohort_id
      join public.profiles       p on p.id = m.user_id
     where c.settled_at is null
       and c.week_start < v_week
  )
  select cohort_id,
         user_id,
         old_league,
         case
           -- TERFİ: ilk 5 ve gerçekten çalışmış olmak.
           when xp > 0 and rnk <= 5 then 'up'
           -- DÜŞME: son 5, AMA yalnızca kohort >= 11 ise. `> 5` olsaydı
           -- 6-9 kişilik kohortta bu küme terfi kümesiyle kesişirdi.
           when n >= 11
            and rnk > n - 5
            -- YENİ KULLANICI KORUMASI: ilk iki hafta düşme yok.
            and created_at < ((week_start - 7)::timestamp
                              at time zone 'Europe/Istanbul')
             then 'down'
           else 'stay'
         end as move
    from ranked;

  -- TEK UPDATE. İki ayrı UPDATE, aynı satırı iki kez güncelleyip
  -- `profiles` üzerindeki AFTER trigger'larını iki kez çalıştırıyordu —
  -- 0043'ün "puanlama TEK ifadeyle yazılır" kuralının ihlali.
  update public.profiles p
     set league = case
                    when s.move = 'up' then
                      case p.league
                        when 'bronz'  then 'gumus'
                        when 'gumus'  then 'altin'
                        when 'altin'  then 'platin'
                        when 'platin' then 'zumrut'
                        else 'elmas'
                      end
                    else
                      case p.league
                        when 'elmas'  then 'zumrut'
                        when 'zumrut' then 'platin'
                        when 'platin' then 'altin'
                        when 'altin'  then 'gumus'
                        else 'bronz'
                      end
                  end
    from _settle s
   where p.id = s.user_id
     and s.move in ('up', 'down');

  -- Sonucu üyelik satırına yaz: bildirim işi bunu okuyacak.
  update public.league_members m
     set move = s.move
    from _settle s
   where m.cohort_id = s.cohort_id and m.user_id = s.user_id;

  update public.league_cohorts
     set settled_at = now()
   where settled_at is null
     and week_start < v_week;
end;
$fn$;

revoke execute on function public.settle_past_leagues()
  from public, anon, authenticated;

-- ==================================================== 3) sonuç bildirimi
-- SETTLE'DAN AYRI, ÇÜNKÜ SAAT. Haftalık devir Pazartesi 00:05 Istanbul'da
-- koşuyor ve `send_push`te sessiz aralık YOK. Sonucu settle içinde
-- göndermek, 13-18 yaş kitlesine gece yarısı bildirim atmak olurdu.
create or replace function public.send_league_results()
returns void
language plpgsql
security definer set search_path = public
as $fn$
declare
  r        record;
  v_friend uuid;
begin
  for r in
    select m.user_id, m.move, m.cohort_id, p.league, p.nickname
      from public.league_members m
      join public.league_cohorts c on c.id = m.cohort_id
      join public.profiles       p on p.id = m.user_id
     where c.settled_at is not null
       and c.results_pushed_at is null
       and m.move is not null
       and not p.is_anonymous
       and not p.is_system
  loop
    -- Kullanıcının kendi sonucu. Metinler terfi/sabit/düşme üçünü de
    -- karşılıyor; `{lig}` yer tutucusu `p_extra`dan besleniyor.
    perform public.send_push(r.user_id, 'league_result', null,
                             public.league_label(r.league));

    -- Arkadaşlara "yükseldi" — YALNIZCA NİHAİ sonuç terfiyse. Eskiden bu
    -- push `profiles.league` üzerindeki tetikleyiciden çıkıyordu ve terfi
    -- UPDATE'inde ateşlenip düşme UPDATE'inden habersiz kalıyordu: lig
    -- değişmemiş bir kullanıcı için arkadaşları "X {lig} ligine çıktı"
    -- bildirimi alıyordu.
    if r.move = 'up' then
      for v_friend in
        select case when f.requester_id = r.user_id
                    then f.addressee_id else f.requester_id end
          from public.friendships f
         where f.status = 'accepted'
           and (f.requester_id = r.user_id or f.addressee_id = r.user_id)
      loop
        -- ENGEL: `are_friends` engelleri görmüyor ve engelleme arkadaşlığı
        -- silmiyor; kontrol her sosyal yüzeyde ayrıca yazılmak zorunda.
        -- Eski tetikleyici bunu HİÇ yapmıyordu: engellediğin kişinin takma
        -- adı sana bildirimle gelmeye devam ediyordu.
        if not public.is_blocked_between(r.user_id, v_friend) then
          perform public.send_push(v_friend, 'friend_league_up',
                                   r.nickname, public.league_label(r.league));
        end if;
      end loop;
    end if;
  end loop;

  update public.league_cohorts
     set results_pushed_at = now()
   where settled_at is not null and results_pushed_at is null;
end;
$fn$;

revoke execute on function public.send_league_results()
  from public, anon, authenticated;

comment on function public.send_league_results() is
  'Kapanmış ama sonucu bildirilmemiş kohortları süpürür: kullanıcıya '
  '`league_result`, terfi edenlerin arkadaşlarına `friend_league_up`. '
  'Settle''dan AYRI çünkü devir gece 00:05''te koşuyor ve send_push''te '
  'sessiz aralık yok. Yalnızca pg_cron çağırır.';

-- ==================================================== 4) tek kilit anahtarı
-- İKİ YERLEŞTİRME YOLU ARTIK AYNI KİLİDİ ALIYOR. Eskiden
-- `assign_week_cohorts` `hashtext('cohorts'||hafta)`, `ensure_league_membership`
-- `hashtext(kademe||hafta)` alıyordu ve birbirlerini dışlamıyorlardı.
-- İki argümanlı biçim bilinçli: `ai_quota` ailesi de öyle yazılmış, ayrı
-- kilit uzayı.
create or replace function public.assign_week_cohorts()
returns void
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_week date := public.istanbul_week();
  v_size int  := public.league_cohort_size();
begin
  perform pg_advisory_xact_lock(hashtext('league_cohorts'),
                                hashtext(v_week::text));

  drop table if exists pg_temp._pending;
  drop table if exists pg_temp._seats;
  drop table if exists pg_temp._overflow;
  drop table if exists pg_temp._new_cohorts;
  create temp table _pending on commit drop as
    select p.id,
           p.league,
           case when p.week_start = v_week then p.weekly_xp else 0 end as xp,
           row_number() over (partition by p.league order by p.id) - 1 as seq
      from public.profiles p
     where not p.is_anonymous
       and not p.is_system
       and not exists (
         select 1 from public.league_members m
          where m.user_id = p.id and m.week_start = v_week
       );

  if not exists (select 1 from _pending) then
    return;
  end if;

  create temp table _seats on commit drop as
    select tier,
           cohort_id,
           row_number() over (partition by tier
                              order by created_at, seat_no) - 1 as seat_seq
      from (
        select c.tier, c.id as cohort_id, c.created_at,
               generate_series(1, v_size - x.n) as seat_no
          from public.league_cohorts c
          join lateral (
            select count(*)::int as n
              from public.league_members m
             where m.cohort_id = c.id
          ) x on true
         where c.week_start = v_week
           and x.n < v_size
      ) seats;

  insert into public.league_members (cohort_id, user_id, xp)
  select s.cohort_id, p.id, coalesce(p.xp, 0)
    from _pending p
    join _seats s on s.tier = p.league and s.seat_seq = p.seq
  on conflict do nothing;

  create temp table _overflow on commit drop as
    select p.id, p.league, p.xp,
           row_number() over (partition by p.league order by p.seq) - 1 as oseq
      from _pending p
      left join _seats s on s.tier = p.league and s.seat_seq = p.seq
     where s.cohort_id is null;

  create temp table _new_cohorts on commit drop as
    select gen_random_uuid() as id, league, grp
      from (
        select distinct league, (oseq / v_size) as grp from _overflow
      ) g;

  insert into public.league_cohorts (id, tier, week_start)
  select id, league, v_week from _new_cohorts;

  insert into public.league_members (cohort_id, user_id, xp)
  select nc.id, o.id, coalesce(o.xp, 0)
    from _overflow o
    join _new_cohorts nc
      on nc.league = o.league and nc.grp = (o.oseq / v_size)
  on conflict do nothing;
end;
$fn$;

revoke execute on function public.assign_week_cohorts()
  from public, anon, authenticated;

create or replace function public.ensure_league_membership()
returns uuid
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_uid    uuid := auth.uid();
  v_week   date := public.istanbul_week();
  v_size   int  := public.league_cohort_size();
  v_tier   text;
  v_cohort uuid;
  v_xp     int;
begin
  if v_uid is null then
    return null;
  end if;

  if exists (
    select 1 from public.league_cohorts
     where settled_at is null and week_start < v_week
  ) then
    perform public.settle_past_leagues();
  end if;

  select m.cohort_id into v_cohort
    from public.league_members m
   where m.user_id = v_uid and m.week_start = v_week
   limit 1;
  if v_cohort is not null then
    return v_cohort;
  end if;

  -- Anonim/sistem hesabı kohorta girmez (0046 kararı).
  select p.league,
         case when p.week_start = v_week then p.weekly_xp else 0 end
    into v_tier, v_xp
    from public.profiles p
   where p.id = v_uid and not p.is_anonymous and not p.is_system;
  if v_tier is null then
    return null;
  end if;

  -- `assign_week_cohorts` ile AYNI ANAHTAR.
  perform pg_advisory_xact_lock(hashtext('league_cohorts'),
                                hashtext(v_week::text));

  -- DOUBLE-CHECKED LOCKING. Yukarıdaki kontrol kilitten ÖNCEYDİ: cron
  -- koşarken araya giren bir çağrı "üye değilim" okuyup kilidi bekledikten
  -- sonra kendini İKİNCİ bir kohorta yazabiliyordu.
  select m.cohort_id into v_cohort
    from public.league_members m
   where m.user_id = v_uid and m.week_start = v_week
   limit 1;
  if v_cohort is not null then
    return v_cohort;
  end if;

  select c.id into v_cohort
    from public.league_cohorts c
   where c.tier = v_tier and c.week_start = v_week
     and (select count(*) from public.league_members m
           where m.cohort_id = c.id) < v_size
   order by c.created_at
   limit 1;

  if v_cohort is null then
    insert into public.league_cohorts (tier, week_start)
    values (v_tier, v_week)
    returning id into v_cohort;
  end if;

  insert into public.league_members (cohort_id, user_id, xp)
  values (v_cohort, v_uid, coalesce(v_xp, 0))
  on conflict do nothing;

  return v_cohort;
end;
$fn$;

revoke execute on function public.ensure_league_membership() from public, anon;
grant  execute on function public.ensure_league_membership() to authenticated;

-- ==================================================== 5) lig tahtası
-- SATIR KALIYOR, KİMLİK MASKELENİYOR. Satırı düşürmek sıralamayı ve üye
-- sayısını bozardı (istemci terfi/düşme bölgesini `total` üzerinden çiziyor)
-- ve engellenen kişiye kohorttan birinin kaybolduğunu fark ettirirdi — yani
-- engeli ele verirdi. Maskeleme hem sıralamayı hem engelin gizliliğini koruyor.
create or replace function public.my_league_board()
returns table (
  user_id     uuid,
  nickname    text,
  mascot      text,
  xp          int,
  streak      int,
  tier        text,
  members     int,
  week_start  date,
  avatar_path text
)
language plpgsql stable security definer set search_path = public
as $fn$
declare
  v_cohort uuid;
begin
  select m.cohort_id into v_cohort
    from public.league_members m
   where m.user_id = auth.uid()
     and m.week_start = public.istanbul_week()
   limit 1;

  if v_cohort is null then
    return;
  end if;

  return query
    select m.user_id,
           case when public.is_blocked_between(auth.uid(), m.user_id)
                then null else p.nickname end,
           case when public.is_blocked_between(auth.uid(), m.user_id)
                then null else p.mascot end,
           m.xp,
           case when p.last_activity_date >= public.istanbul_day() - 1
                then p.streak else 0 end,
           c.tier,
           (select count(*)::int from public.league_members x
             join public.profiles xp2 on xp2.id = x.user_id
            where x.cohort_id = v_cohort
              and not xp2.is_anonymous and not xp2.is_system),
           c.week_start,
           case when public.is_blocked_between(auth.uid(), m.user_id)
                then null else p.avatar_path end
      from public.league_members m
      join public.profiles p on p.id = m.user_id
      join public.league_cohorts c on c.id = m.cohort_id
     where m.cohort_id = v_cohort
       -- `profiles_public` bu süzgeci taşıyordu, lig RPC'si taşımıyordu.
       -- Üye SAYIMI da aynı süzgeci alıyor, yoksa sayı ile satır ayrışırdı.
       and not p.is_anonymous
       and not p.is_system
     order by m.xp desc, p.nickname asc;
end;
$fn$;

revoke execute on function public.my_league_board() from public, anon;
grant  execute on function public.my_league_board() to authenticated;

-- ==================================================== 6) avatar erişimi
-- TEK SATIR, İKİ DALI BİRDEN KAPATIYOR. `exists()` bloğunun sonuna eklenen
-- engel kontrolü hem ARKADAŞ dalını (engelleme arkadaşlığı silmiyor, yani
-- engelli "eski arkadaş" avatarı açık kalıyordu) hem KOHORT dalını kapatıyor.
-- Kendi klasörün dalı ve `p.id = auth.uid()` dalı ETKİLENMİYOR.
create or replace function public.can_read_avatar(p_name text)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select
    (storage.foldername(p_name))[1] = auth.uid()::text
    or exists (
      select 1
        from public.profiles p
       where p.avatar_path = p_name
         and (
           p.id = auth.uid()
           or public.are_friends(p.id, auth.uid())
           or exists (
             select 1
               from public.league_members m1
               join public.league_members m2
                 on m2.cohort_id = m1.cohort_id
              where m1.user_id = p.id
                and m2.user_id = auth.uid()
                and m1.week_start = public.istanbul_week()
           )
         )
         and not public.is_blocked_between(p.id, auth.uid())
    );
$fn$;

revoke execute on function public.can_read_avatar(text) from public, anon;
-- Politika ifadeleri ÇAĞIRANIN yetkisiyle değerlendirilir; authenticated bunu
-- çalıştırabilmeli, yoksa hiçbir avatar görünmez.
grant execute on function public.can_read_avatar(text) to authenticated;

-- ==================================================== 7) arkadaş kilometre taşı
-- LİG DALI ÇIKARILDI. `friend_league_up` artık `send_league_results()`ten
-- çıkıyor: "her satır güncellemesinde push at" kalıbı, aynı işlemde iki kez
-- güncellenen bir satırda kaçınılmaz olarak yalan söylüyordu. Seri dalı
-- duruyor ve ona da engel süzgeci ekleniyor.
create or replace function public.on_friend_milestone()
returns trigger language plpgsql security definer set search_path = public
as $fn$
declare
  v_friend uuid;
begin
  if not (new.streak > coalesce(old.streak, 0)
          and new.streak in (7, 30, 100, 365)) then
    return new;
  end if;

  for v_friend in
    select case when f.requester_id = new.id
                then f.addressee_id else f.requester_id end
      from public.friendships f
     where f.status = 'accepted'
       and (f.requester_id = new.id or f.addressee_id = new.id)
  loop
    if not public.is_blocked_between(new.id, v_friend) then
      perform public.send_push(v_friend, 'friend_streak', new.nickname,
                               new.streak::text);
    end if;
  end loop;

  return new;
end;
$fn$;

-- WHEN koşulu da daraldı: lig değişimi artık bu tetikleyiciyi ilgilendirmiyor.
drop trigger if exists push_on_friend_milestone on public.profiles;
create trigger push_on_friend_milestone
  after update on public.profiles
  for each row
  when (old.streak is distinct from new.streak)
  execute function public.on_friend_milestone();

-- ==================================================== 8) haftalık XP senkronu
create or replace function public.sync_league_member_xp()
returns trigger
language plpgsql security definer set search_path = public
as $fn$
begin
  if new.weekly_xp is distinct from old.weekly_xp then
    update public.league_members m
       set xp = new.weekly_xp
      from public.league_cohorts c
     where m.user_id = new.id
       and m.cohort_id = c.id
       and c.settled_at is null
       and m.week_start = public.istanbul_week();
  end if;
  return new;
end;
$fn$;

-- ==================================================== 9) sonuç bildirimi işi
do $cron$
begin
  perform cron.unschedule(jobid)
    from cron.job where jobname = 'league-results-push';
exception when others then
  null; -- ilk kurulumda iş yok
end
$cron$;

-- Her gün 09:00 Istanbul = 06:00 UTC. Pazartesi devri gece 00:05'te koşuyor;
-- sonuç sabah gidiyor. Günlük çalışıyor ki hafta ortası kapanan bir kohortun
-- sonucu da bir sonraki sabah teslim edilsin.
select cron.schedule(
  'league-results-push',
  '0 6 * * *',
  $$select public.send_league_results()$$
);
