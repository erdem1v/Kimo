-- test: supabase/tests/330_league_cohorts.sql
--
-- MUTASYON: lig tahtasindan TAKMA AD maskesini sok (avatar ve maskot maskesi
-- yerinde kaliyor — mutasyon tek korumayi bozmali).
-- BEKLENEN: 330'un "engellenen kullanicinin takma adi MASKELI" iddiasi kirmizi.
--
-- NEDEN BU BIR KORUMA: arayuz metni kullaniciya fazlasini vaat ediyor —
-- app_tr.arb:933 "{name} sana soru gonderemez, arkadas istegi atamaz ve
-- LISTELERDE SENI GOREMEZ". Lig tahtasi o sozu tutmayan yuzeylerden biriydi:
-- engellenen kisi adiyla, XP'siyle, serisiyle ve AVATARIYLA duruyordu.
--
-- SATIR NEDEN DUSURULMUYOR: dusurmek siralamayi ve uye sayisini bozar
-- (istemci terfi/dusme bolgesini `total` uzerinden ciziyor) ve engellenen
-- kisiye kohorttan birinin kayboldugunu fark ettirir — yani engeli ele verir.
--
-- NOT: iki govde de goc dosyasindan URETILDI. Kaynak: 0089.
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
           p.nickname,
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
-- @UNDO
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
