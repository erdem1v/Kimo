-- 0018 — Ligden düşme
-- Supabase → SQL Editor'da çalıştır.
--
-- 0017'de yalnızca terfi vardı; kimse düşmediği için herkes zamanla Efsane'de
-- birikip yarış anlamsızlaşırdı. Artık hafta sonunda:
--   • İlk 5  → bir üst lige çıkar
--   • Son 5  → bir alt lige düşer
-- Bronz'un altı, Efsane'nin üstü yok; oralarda kalınır.
--
-- Hiç XP kazanmayanlar (xp = 0) her hâlükârda düşme bölgesindedir: sıralamada
-- en altta olurlar. Terfi için ise xp > 0 şartı korunur.

create or replace function public.settle_past_leagues()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_week date := (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
begin
  -- ------------------------------------------------------------ TERFİ
  -- Grup içinde kendisinden iyi durumda 5'ten az kişi olanlar (ilk 5).
  -- Beraberlikte user_id ile deterministik sıralama.
  update public.profiles p
     set league = case p.league
                    when 'bronz'  then 'gumus'
                    when 'gumus'  then 'altin'
                    when 'altin'  then 'elmas'
                    when 'elmas'  then 'efsane'
                    else 'efsane'
                  end
    from (
      select m.user_id
        from public.league_members m
        join public.league_cohorts c on c.id = m.cohort_id
       where c.settled_at is null
         and c.week_start < v_week
         and m.xp > 0
         and (
           select count(*) from public.league_members m2
            where m2.cohort_id = m.cohort_id
              and (m2.xp > m.xp or (m2.xp = m.xp and m2.user_id < m.user_id))
         ) < 5
    ) promoted
   where p.id = promoted.user_id;

  -- ------------------------------------------------------------ DÜŞME
  -- Grup içinde kendisinden kötü durumda 5'ten az kişi olanlar (son 5).
  -- Terfi edenlerle çakışmaması için grubun en az 6 kişilik olması aranır;
  -- daha küçük gruplarda kimse düşmez (yoksa aynı kişi hem çıkıp hem düşerdi).
  update public.profiles p
     set league = case p.league
                    when 'efsane' then 'elmas'
                    when 'elmas'  then 'altin'
                    when 'altin'  then 'gumus'
                    when 'gumus'  then 'bronz'
                    else 'bronz'
                  end
    from (
      select m.user_id
        from public.league_members m
        join public.league_cohorts c on c.id = m.cohort_id
       where c.settled_at is null
         and c.week_start < v_week
         and (
           select count(*) from public.league_members m3
            where m3.cohort_id = m.cohort_id
         ) > 5
         and (
           select count(*) from public.league_members m2
            where m2.cohort_id = m.cohort_id
              and (m2.xp < m.xp or (m2.xp = m.xp and m2.user_id > m.user_id))
         ) < 5
    ) demoted
   where p.id = demoted.user_id;

  -- Grupları kapat
  update public.league_cohorts
     set settled_at = now()
   where settled_at is null
     and week_start < v_week;
end;
$$;
