-- test: supabase/tests/320_pair_streaks.sql
--
-- MUTASYON: okuma RPC'sinden engel süzgecini sök.
-- BEKLENEN: 320'nin "ENGELLENEN ikili listede GÖRÜNMÜYOR" iddiası kırmızı.
--
-- NEDEN BU BİR KORUMA: `are_friends` engelleri HİÇ GÖRMÜYOR (0008'den beri) ve
-- ENGELLEME ARKADAŞLIĞI SİLMİYOR. Yani "arkadaş" olmak engellenmiş olmakla
-- çelişmiyor ve engel kontrolü her sosyal yüzeyde AYRICA yazılmak zorunda.
-- Bu mutasyon o ikinci savunmayı söküyor: engellediği kişi kullanıcının
-- arkadaş listesinde ortak seri rozetiyle geri geliyor.
create or replace function public.my_pair_streaks()
returns table (
  friend_id     uuid,
  nickname      text,
  mascot        text,
  avatar_path   text,
  streak        int,
  best          int,
  me_today      boolean,
  friend_today  boolean
)
language sql stable security definer set search_path = public
as $fn$
  select p.id,
         p.nickname,
         p.mascot,
         case when public.are_friends(p.id, auth.uid()) then p.avatar_path end,
         case when s.last_day >= public.istanbul_day() - 1
              then s.streak else 0 end,
         s.best,
         (select me.last_activity_date = public.istanbul_day()
            from public.profiles me where me.id = auth.uid()),
         p.last_activity_date = public.istanbul_day()
    from public.pair_streaks s
    join public.profiles p
      on p.id = case when s.a_id = auth.uid() then s.b_id else s.a_id end
   where auth.uid() in (s.a_id, s.b_id)
     and not p.is_anonymous
     and not p.is_system
   order by 5 desc, p.nickname;
$fn$;
revoke execute on function public.my_pair_streaks() from public, anon;
grant  execute on function public.my_pair_streaks() to authenticated;
-- @UNDO
create or replace function public.my_pair_streaks()
returns table (
  friend_id     uuid,
  nickname      text,
  mascot        text,
  avatar_path   text,
  streak        int,
  best          int,
  me_today      boolean,
  friend_today  boolean
)
language sql stable security definer set search_path = public
as $fn$
  select p.id,
         p.nickname,
         p.mascot,
         case when public.are_friends(p.id, auth.uid()) then p.avatar_path end,
         case when s.last_day >= public.istanbul_day() - 1
              then s.streak else 0 end,
         s.best,
         (select me.last_activity_date = public.istanbul_day()
            from public.profiles me where me.id = auth.uid()),
         p.last_activity_date = public.istanbul_day()
    from public.pair_streaks s
    join public.profiles p
      on p.id = case when s.a_id = auth.uid() then s.b_id else s.a_id end
   where auth.uid() in (s.a_id, s.b_id)
     -- Anonim ve sistem hesapları sosyal yüzeye HİÇ girmiyor (0046/0047).
     and not p.is_anonymous
     and not p.is_system
     -- ENGELLEME ARKADAŞLIĞI SİLMİYOR ve `are_friends` engelleri HİÇ
     -- GÖRMÜYOR; kontrol bu yüzden ayrıca yazılmak zorunda.
     and not public.is_blocked_between(auth.uid(), p.id)
   order by 5 desc, p.nickname;
$fn$;

revoke execute on function public.my_pair_streaks() from public, anon;
grant  execute on function public.my_pair_streaks() to authenticated;
