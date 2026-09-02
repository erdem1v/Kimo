-- 0046 — Kayıt öncesi anonim oturum
--
-- MİMARİ KARAR (task §6.1 ve §6.2'nin cevabı):
--
-- Yeni karşılama akışında öğrenci ilk yanlışını HESAP AÇMADAN çekiyor. O
-- fotoğraf ve analiz bir yere ait olmak zorunda. Seçilen yol: kullanıcı "İlk
-- yanlışını çek"e bastığı anda `signInAnonymously()` çağrılıyor ve o andan
-- itibaren gerçek bir `auth.uid()` var. Fotoğraf `<uid>/...` altına yükleniyor,
-- `mistakes` satırı normal yoldan yazılıyor, yaş kapısındaki onay deftere
-- düşüyor, AI çağrısı JWT'li yapılıyor.
--
-- Kayıt adımında `auth.updateUser(email, password)` anonim kullanıcıyı kalıcı
-- hesaba çeviriyor ve **uid DEĞİŞMİYOR** — yani taşınacak hiçbir şey yok.
-- Depolama yolu, satır ve onay kaydı olduğu yerde kalıyor.
--
-- REDDEDİLEN ALTERNATİF — yerel evreleme: fotoğraf ve analiz cihazda tutulup
-- kayıttan sonra yüklenecekti. (a) AI çağrısı yine kimlik istiyor, yani asıl
-- sorunu çözmüyor; (b) "yerelden sunucuya taşıma" ikinci ve kırılgan bir yol
-- açıyor — yükleme yarıda kalırsa kullanıcı fotoğrafını kaybediyor;
-- (c) yaş kapısında verilen onayın yazılacağı bir kimlik yok.
--
-- BEDELİ, AÇIKÇA: anonim kullanıcılar Supabase MAU'suna sayılır. Denemede
-- vazgeçen her kullanıcı bir MAU'dur. Dashboard'da anonim oturum için captcha
-- ve oran sınırı AÇILMALI.
--
-- ANONİM KULLANICI SOSYAL YÜZEYE GİREMEZ: profiles_public'te görünmez, lig
-- kohortuna atanmaz, arkadaş isteği gönderemez, soru gönderemez. Kalıcı hesaba
-- dönüşünce bunların hepsi kendiliğinden açılır.

alter table public.profiles
  add column if not exists is_anonymous boolean not null default false;

comment on column public.profiles.is_anonymous is
  'auth.users.is_anonymous aynası. Sunucu tetikleyicisi yazar; istemci '
  'yazamaz. Anonim kullanıcı sosyal yüzeyin tamamından dışlanır.';

-- --------------------------------------------------- kaynak sütun var mı?
-- `auth.users.is_anonymous` Supabase'in anonim oturum özelliğiyle geldi.
-- Doğrudan `new.is_anonymous` yazmak, sütunun olmadığı bir sürümde
-- `handle_new_user` tetikleyicisini bozar ve KULLANICI OLUŞTURMAYI tamamen
-- kırardı. Bu yüzden tetikleyici gövdesi katalogdan üretiliyor.
--
-- Yedek ölçüt `new.email is null`: uygulama yalnızca e-posta ile kayıt
-- alıyor, dolayısıyla e-postasız kullanıcı anonimdir. Metadata KULLANILMIYOR —
-- orası kullanıcı-yazılabilir ve anonim biri kendini kalıcı gösterebilirdi.
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

  -- 0045'teki gövde korunuyor (arkadaş kodu üretimi dâhil), üstüne anonim
  -- bayrağı ekleniyor. Bu, `handle_new_user`'ın SON sürümü.
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

      if new.raw_user_meta_data ? 'guardian_consent' then
        insert into public.user_consents (user_id, kind, granted, source)
        values (
          new.id, 'guardian',
          coalesce((new.raw_user_meta_data->>'guardian_consent')::boolean, false),
          'signup'
        );
      end if;

      perform public.assign_friend_code(new.id);
      return new;
    end
    $fn$;
  $sql$, v_expr);

  -- Kalıcı hesaba dönüşüm: anonim kullanıcı e-posta/parola ekleyince
  -- `auth.users` GÜNCELLENİYOR, yeni satır oluşmuyor — INSERT tetikleyicisi
  -- bu anı hiç görmez. Bayrağın orada kalması kullanıcıyı sonsuza kadar
  -- sosyal yüzeyin dışında bırakırdı.
  execute format($sql$
    create or replace function public.sync_anonymous_flag()
    returns trigger
    language plpgsql
    security definer set search_path = public
    as $fn$
    begin
      update public.profiles set is_anonymous = %s where id = new.id;
      return new;
    end
    $fn$;
  $sql$, v_expr);
end
$mig$;

drop trigger if exists on_auth_user_anonymity on auth.users;
create trigger on_auth_user_anonymity
  after update on auth.users
  for each row
  execute function public.sync_anonymous_flag();

-- -------------------------------------------------- mevcut satırların tazelenmesi
-- Göç öncesi kullanıcılar kalıcı hesap: bayrak zaten false. Yine de kaynağı
-- olan ortamda gerçekle eşitleyelim.
do $mig$
begin
  if exists (
    select 1 from pg_attribute a
     where a.attrelid = 'auth.users'::regclass
       and a.attname = 'is_anonymous'
       and not a.attisdropped
  ) then
    execute $sql$
      update public.profiles p
         set is_anonymous = coalesce(u.is_anonymous, false)
        from auth.users u
       where u.id = p.id
         and p.is_anonymous is distinct from coalesce(u.is_anonymous, false)
    $sql$;
  end if;
end
$mig$;

-- ------------------------------------------------------ sosyal yüzeyden dışla
-- `profiles_public` görünümü 0032'de son hâlini almıştı (avatar_path ilişkiye
-- bağlı). Sütun listesi DEĞİŞMİYOR — yalnızca bir süzgeç ekleniyor — bu yüzden
-- `create or replace` yeterli.
create or replace view public.profiles_public
with (security_invoker = false) as
select
  p.id,
  p.nickname,
  p.mascot,
  p.xp,
  p.streak,
  p.league,
  case when p.week_start = (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date
       then p.weekly_xp else 0 end as weekly_xp,
  case
    when p.id = auth.uid() or public.are_friends(p.id, auth.uid())
      then p.avatar_path
    else null
  end as avatar_path,
  (
    select count(*)::int from public.friendships f
     where f.status = 'accepted'
       and (f.requester_id = p.id or f.addressee_id = p.id)
  ) as friend_count
from public.profiles p
where not p.is_system
  and not p.is_anonymous;

revoke all on public.profiles_public from public, anon;
grant select on public.profiles_public to authenticated;

-- ------------------------------------------------------------ lig dışında
-- Anonim kullanıcı kohorta girerse gerçek kullanıcıların sıralamasını 0 XP'yle
-- kirletir ve hafta sonunda birinin haksız yere düşmesine yol açar.
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
     where not p.is_anonymous
       and not p.is_system
       and not exists (
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

revoke execute on function public.assign_week_cohorts()
  from public, anon, authenticated;

-- ---------------------------------------------------- soru gönderimi dışında
-- Arkadaşlık zaten şart ve anonim kullanıcı arkadaş edinemiyor; yine de
-- ikinci bir katman: politikalar tek bir koşula dayanmasın.
drop policy if exists sends_insert_friend on public.question_sends;
create policy sends_insert_friend on public.question_sends
  for insert to authenticated
  with check (
    auth.uid() = sender_id
    and not exists (
      select 1 from public.profiles p
       where p.id = auth.uid() and p.is_anonymous
    )
    and public.are_friends(sender_id, receiver_id)
    and not exists (
      select 1 from public.user_blocks b
       where (b.blocker_id = receiver_id and b.blocked_id = sender_id)
          or (b.blocker_id = sender_id   and b.blocked_id = receiver_id)
    )
  );

-- ------------------------------------------------- arkadaş eklemenin dışında
-- 0043'ün `can_add_friends` fonksiyonu anonimliği de kapsasın: politika
-- metnini değiştirmek yerine tek yerden.
create or replace function public.can_add_friends(p_user uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select not coalesce(
           (select p.is_anonymous from public.profiles p where p.id = p_user),
           true
         )
     and (
       not public.is_minor_now(p_user)
       or coalesce(
            (
              select c.granted
                from public.user_consents c
               where c.user_id = p_user and c.kind = 'guardian'
               order by c.recorded_at desc
               limit 1
            ),
            false
          )
     );
$$;

revoke execute on function public.can_add_friends(uuid) from public, anon;
grant  execute on function public.can_add_friends(uuid) to authenticated;

-- ------------------------------------------------------------ temizlik
-- Hesap hiç açılmazsa anonim kullanıcı 7 gün sonra silinir.
--
-- BURADA YALNIZCA ADAYLARI LİSTELİYORUZ. Silme işlemi depolama nesnelerini de
-- kaldırmak zorunda ve o yalnızca Storage API üzerinden yapılabiliyor
-- (`storage.objects` satırını silmek bulut ortamında dosyayı bırakır).
-- Bu yüzden asıl silme `cleanup-anonymous` edge fonksiyonunda; bu fonksiyon
-- ona listeyi veriyor.
create or replace function public.stale_anonymous_users(p_days int default 7)
returns table (user_id uuid)
language sql stable security definer set search_path = public
as $$
  select p.id
    from public.profiles p
   where p.is_anonymous
     and p.created_at < now() - make_interval(days => greatest(p_days, 1));
$$;

revoke execute on function public.stale_anonymous_users(int)
  from public, anon, authenticated;

comment on function public.stale_anonymous_users(int) is
  'Süresi dolmuş anonim hesapların kimlikleri. Yalnızca servis rolü çağırır '
  '(cleanup-anonymous edge fonksiyonu); silme orada yapılır çünkü depolama '
  'nesneleri Storage API üzerinden kaldırılmak zorunda.';
