-- test: supabase/tests/330_league_cohorts.sql
--
-- MUTASYON: dusme kapisini `n >= 11` yerine eski `n > 5` haline dondur.
-- BEKLENEN: 330'un "6 kisilik kohortta KIMSE dusmedi" ve "kucuk ELMAS
-- kohortunda kimse dusmedi" iddialari kirmizi.
--
-- NEDEN BU BIR KORUMA: kohort TAVANI 30 ama kademe nufusunun 30'a bolumunden
-- ARTAN grup duzenli olarak 6-9 kisilik oluyor. O aralikta terfi (ilk 5) ile
-- dusme (son 5) KESISIYOR ve iki ayri UPDATE oldugu icin ikincisi birincisini
-- eziyor: orta kademelerde hak edilmis terfi sessizce iptal oluyor, tepe
-- kademe `elmas`ta ise terfi tavanli oldugu icin ilk-5 oyuncusu NET DUSUYOR.
-- Ayrica esik, istemcinin ZATEN cizdigi kural: league_screen.dart:182-184
-- dusme cizgisini yalnizca total >= 11 iken ciziyor.
--
-- NOT: iki govde de goc dosyasindan URETILDI, elle kopyalanmadi. Kaynak:
-- supabase/migrations/20260913000200_league_fixes.sql (0089).
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
           when n > 5
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
-- @UNDO
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
