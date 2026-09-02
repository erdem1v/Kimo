-- 0039 — Lig: 5 kademe → 6 kademe, 12 kişilik kohort → 30
--
-- Yeni yapı (onaylanan tasarım):
--   bronz · gümüş · altın · platin · zümrüt · elmas
--   30 kişilik haftalık kohort · ilk 5 yükselir · son 5 düşer
--
-- ESKİ YAPI: bronz · gümüş · altın · elmas · efsane, 12 kişilik kohort.
--
-- GEÇİŞ KARARI — SIRA KORUNUR (ürün kararı):
--   4. sıra `elmas`  → 4. sıra `platin`
--   5. sıra `efsane` → 5. sıra `zumrut`
-- Kimse yükselmiyor, kimse düşmüyor; yalnızca iki kademenin adı değişiyor.
-- Yeni tepe kademe `elmas` ancak terfiyle kazanılıyor.
--
-- DİKKAT — `elmas` adı iki yapıda da var ama ANLAMI değişiyor: eskiden 4.,
-- şimdi 6. kademe. Bu yüzden eşleme SIRAYA göre ve TEK YÖNDE yapılmak
-- zorunda: önce `elmas` → `platin`, sonra `efsane` → `zumrut`. Ters sırada
-- yapılırsa `efsane`den gelenler bir sonraki ifadede yeniden taşınırdı.
--
-- KOHORT BOYUTU: 30 yalnızca YENİ açılan kohortlara uygulanır. Açık haftanın
-- 12'lik kohortları eski hâlleriyle kapanır; `settle_past_leagues` zaten kohort
-- başına ilk 5 / son 5 hesaplıyor ve "6'dan küçük kohortta kimse düşmez"
-- koşulunu taşıyor, dolayısıyla geçiş haftası tutarlı kalıyor.
--
-- GERİ ALMA: bu göç geri alınamaz veri dönüşümü içeriyor (kademe adları).
-- Geri almak isterseniz `platin` → `elmas`, `zumrut` → `efsane` eşlemesini
-- uygulayın ve `elmas`ta kimse kalmadığından emin olun.

-- ------------------------------------------------------------ 1) kısıtı aç
-- CHECK kısıtı satır içi tanımlandığı için adı otomatik üretildi. Adı
-- varsaymak yerine tanımından buluyoruz: farklı bir ortamda farklı adlanmış
-- olabilir ve `drop constraint if exists profiles_league_check` sessizce
-- hiçbir şey yapmazdı — sonra da genişletme adımı patlardı.
do $mig$
declare v_name text;
begin
  select con.conname into v_name
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname = 'profiles'
     and con.contype = 'c'
     and pg_get_constraintdef(con.oid) ilike '%league%'
   limit 1;

  if v_name is not null then
    execute format('alter table public.profiles drop constraint %I', v_name);
  end if;
end
$mig$;

-- Geçiş sırasında hem eski hem yeni değerler geçerli olmalı.
alter table public.profiles
  add constraint profiles_league_check
  check (league in ('bronz','gumus','altin','platin','zumrut','elmas','efsane'));

-- ------------------------------------------------------- 2) sırayı koruyarak eşle
update public.profiles set league = 'platin' where league = 'elmas';
update public.profiles set league = 'zumrut' where league = 'efsane';

update public.league_cohorts set tier = 'platin' where tier = 'elmas';
update public.league_cohorts set tier = 'zumrut' where tier = 'efsane';

-- ------------------------------------------------------------ 3) kısıtı daralt
alter table public.profiles drop constraint profiles_league_check;
alter table public.profiles
  add constraint profiles_league_check
  check (league in ('bronz','gumus','altin','platin','zumrut','elmas'));

comment on column public.profiles.league is
  'Kademe: bronz < gumus < altin < platin < zumrut < elmas. Sunucu belirler '
  '(settle_past_leagues); istemci yazamaz. XP eşiğiyle kademe atlama YOKTUR.';

-- --------------------------------------------------------- 4) sıra/etiket
create or replace function public.league_rank(l text)
returns int language sql immutable as $$
  select case l
           when 'bronz'  then 1
           when 'gumus'  then 2
           when 'altin'  then 3
           when 'platin' then 4
           when 'zumrut' then 5
           when 'elmas'  then 6
           else 0
         end;
$$;

create or replace function public.league_label(l text)
returns text language sql immutable as $$
  select case l
           when 'bronz'  then 'Bronz'
           when 'gumus'  then 'Gümüş'
           when 'altin'  then 'Altın'
           when 'platin' then 'Platin'
           when 'zumrut' then 'Zümrüt'
           when 'elmas'  then 'Elmas'
           else 'Bronz'
         end;
$$;

-- `create or replace` mevcut ACL'i koruyor (ikisi de 0029'da kapatılmıştı) ama
-- açıkça yazmak, denetim betiğinin "yetkisi hiç yönetilmemiş fonksiyon"
-- uyarısını da kapatıyor. İkisi de yalnızca definer fonksiyonlardan çağrılıyor.
revoke execute on function public.league_rank(text)
  from public, anon, authenticated;
revoke execute on function public.league_label(text)
  from public, anon, authenticated;

-- ------------------------------------------------------- 5) terfi ve düşme
-- 0018'deki mantık aynen korunuyor; yalnızca kademe zincirleri altı değere
-- genişledi. Beraberlikte `user_id` ile deterministik sıralama, "6'dan küçük
-- kohortta düşme yok" koruması ve terfi için `xp > 0` şartı değişmedi.
create or replace function public.settle_past_leagues()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_week date := (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
begin
  -- ------------------------------------------------------------ TERFİ
  update public.profiles p
     set league = case p.league
                    when 'bronz'  then 'gumus'
                    when 'gumus'  then 'altin'
                    when 'altin'  then 'platin'
                    when 'platin' then 'zumrut'
                    when 'zumrut' then 'elmas'
                    else 'elmas'
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
  update public.profiles p
     set league = case p.league
                    when 'elmas'  then 'zumrut'
                    when 'zumrut' then 'platin'
                    when 'platin' then 'altin'
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

  update public.league_cohorts
     set settled_at = now()
   where settled_at is null
     and week_start < v_week;
end;
$$;

-- ----------------------------------------------------------- 6) kohort boyutu
-- Tek değişiklik: 12 → 30. Doluluk eşiği tek yerde dursun diye sabit yerine
-- immutable bir fonksiyondan okunuyor; istemcideki `League.cohortSize` ile
-- birlikte değişmesi gereken sayı budur.
create or replace function public.league_cohort_size()
returns int language sql immutable as $$
  select 30;
$$;

create or replace function public.assign_week_cohorts()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_week   date := (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
  v_size   int  := public.league_cohort_size();
  v_cohort uuid;
  r        record;
begin
  for r in
    select p.id,
           p.league,
           case when p.week_start = v_week then p.weekly_xp else 0 end as xp
      from public.profiles p
     where not exists (
       select 1
         from public.league_members m
         join public.league_cohorts c on c.id = m.cohort_id
        where m.user_id = p.id and c.week_start = v_week
     )
     order by p.league, p.id
  loop
    select c.id into v_cohort
      from public.league_cohorts c
     where c.tier = r.league
       and c.week_start = v_week
       and (select count(*) from public.league_members m
             where m.cohort_id = c.id) < v_size
     order by c.created_at
     limit 1;

    if v_cohort is null then
      insert into public.league_cohorts (tier, week_start)
      values (r.league, v_week)
      returning id into v_cohort;
    end if;

    insert into public.league_members (cohort_id, user_id, xp)
    values (v_cohort, r.id, coalesce(r.xp, 0))
    on conflict do nothing;
  end loop;
end;
$$;

-- Yeni fonksiyon PUBLIC'e açık doğar; kapıyı hemen kapat (Task 01 kuralı 4).
-- İstemci bunu ÇAĞIRMIYOR (Dart tarafında `League.cohortSize` sabiti var);
-- yalnızca definer `assign_week_cohorts` okuyor ve o postgres olarak çalışıyor.
-- Bu yüzden authenticated'a da açılmıyor ve beyaz listeye girmiyor.
revoke execute on function public.league_cohort_size()
  from public, anon, authenticated;

revoke execute on function public.settle_past_leagues()
  from public, anon, authenticated;
revoke execute on function public.assign_week_cohorts()
  from public, anon, authenticated;
