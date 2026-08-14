-- 0023 — Arkadaş kilometre taşları bildirimi
-- Supabase → SQL Editor'da çalıştır.
--
-- İki yeni senaryo, ikisi de arkadaşlarına gider:
--   friend_league_up → arkadaşın bir üst lige çıktı
--   friend_streak    → arkadaşın seri kilometre taşına ulaştı (7/30/100/365)
--
-- Amaç sosyal baskı değil, sosyal kanıt: "arkadaşım yapıyorsa ben de yaparım".
-- Bu yüzden her gün değil, yalnızca gerçekten dikkate değer anlarda gönderilir.

-- --------------------------------------------------------------- yardımcılar
create or replace function public.league_rank(l text)
returns int language sql immutable as $$
  select case l
           when 'bronz'  then 1
           when 'gumus'  then 2
           when 'altin'  then 3
           when 'elmas'  then 4
           when 'efsane' then 5
           else 0
         end;
$$;

create or replace function public.league_label(l text)
returns text language sql immutable as $$
  select case l
           when 'bronz'  then 'Bronz'
           when 'gumus'  then 'Gümüş'
           when 'altin'  then 'Altın'
           when 'elmas'  then 'Elmas'
           when 'efsane' then 'Efsane'
           else 'Bronz'
         end;
$$;

-- ------------------------------------------------------ send_push genişletme
-- {lig} ve {n} yer tutucuları için dördüncü bir parametre gerekiyor. İmza
-- değiştiği için önce eski sürüm düşürülür: iki sürüm birlikte dursaydı
-- üç argümanlı çağrılar belirsiz kalırdı (bkz. 0014/0015 dersi).
drop function if exists public.send_push(uuid, text, text);

create or replace function public.send_push(
  p_user  uuid,
  p_kind  text,
  p_actor text,
  p_extra text default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_url    text;
  v_secret text;
  v_mascot text;
  v_line   text;
  v_title  text;
begin
  select value into v_url    from public.app_config where key = 'push_url';
  select value into v_secret from public.app_config where key = 'push_secret';
  if v_url is null or v_secret is null then
    return;   -- yapılandırılmadıysa sessizce geç
  end if;

  -- Alıcının maskotu; seçmediyse şefkatli varsayılan.
  select coalesce(mascot, 'ev_hanimi') into v_mascot
    from public.profiles where id = p_user;

  select replace(
           replace(
             replace(line, '{ad}', coalesce(p_actor, 'Bir arkadaşın')),
             '{lig}', coalesce(p_extra, '')),
           '{n}', coalesce(p_extra, ''))
    into v_line
    from public.push_lines
   where kind = p_kind and mascot = coalesce(v_mascot, 'ev_hanimi')
   order by random()
   limit 1;

  if v_line is null then
    return;
  end if;

  v_title := case p_kind
               when 'question_received' then 'Sana soru geldi 📨'
               when 'friend_request'    then 'Arkadaşlık isteği 🤝'
               when 'question_solved'   then 'Soru çözüldü ✅'
               when 'friend_league_up'  then 'Arkadaşın yükseliyor 🏆'
               when 'friend_streak'     then 'Arkadaşın seri yapıyor 🔥'
               else 'AI YKS Coach'
             end;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-push-secret', v_secret
               ),
    body    := jsonb_build_object(
                 'user_id', p_user,
                 'title',   v_title,
                 'body',    v_line,
                 'kind',    p_kind
               )
  );
exception when others then
  return;   -- bildirim hatası asıl işlemi bozmasın
end;
$$;

-- ------------------------------------------------------------- yeni metinler
-- Yeniden çalıştırılabilir olsun diye önce bu iki senaryo temizlenir
-- (0021'deki diğer metinlere dokunulmaz).
delete from public.push_lines
 where kind in ('friend_league_up', 'friend_streak');

insert into public.push_lines (kind, mascot, line) values
-- --------------------------------------------- arkadaş bir üst lige çıktı
('friend_league_up','ev_hanimi','{ad} çok çalışmış, {lig} ligine çıkmış. Sen de geri kalma canım.'),
('friend_league_up','ev_hanimi','Arkadaşın {ad} bu hafta ligi atladı, {lig}''e geçti. Maşallah.'),
('friend_league_up','ev_hanimi','{ad} yükselmiş {lig} ligine. Onu görünce içim açıldı, seni de bekliyorum.'),
('friend_league_up','arabeskci','{ad} çıktı {lig} ligine, biz burada kaldık dostum.'),
('friend_league_up','arabeskci','Duydun mu, {ad} bir üst lige uçtu. {lig} artık onun.'),
('friend_league_up','arabeskci','{ad} yükseldi {lig}''e… Sen de yükselirsin, inanıyorum.'),
('friend_league_up','sanayi_ustasi','{ad} tezgâhı sıkı çalıştırmış, {lig} ligine geçti.'),
('friend_league_up','sanayi_ustasi','Usta, {ad} bir üst lige çıktı. {lig}''de şimdi.'),
('friend_league_up','sanayi_ustasi','{ad} terfi etti: {lig}. Sen de kolları sıva.'),
('friend_league_up','akademisyen','{ad} bu hafta bir üst lige yükseldi: {lig}.'),
('friend_league_up','akademisyen','Arkadaşınız {ad} istikrarlı çalıştı ve {lig} ligine geçti.'),
('friend_league_up','akademisyen','{ad} sıralamada ilk beşe girdi; artık {lig} liginde.'),
('friend_league_up','ceo','{ad} bu hafta {lig} ligine terfi etti.'),
('friend_league_up','ceo','{ad} bir üst lige geçti: {lig}. Sen neredesin?'),
('friend_league_up','ceo','{ad} performansıyla {lig} ligine çıktı. Sıra sende.'),
-- ------------------------------------------ arkadaş seri kilometre taşında
('friend_streak','ev_hanimi','{ad} tam {n} gündür aksatmıyor. Ne çalışkan çocuk.'),
('friend_streak','ev_hanimi','Arkadaşın {ad} {n} günlük seriye ulaştı canım, sen de vakit ayır.'),
('friend_streak','ev_hanimi','{ad} {n} gündür her gün soru çözüyor. Helal olsun ona.'),
('friend_streak','arabeskci','{ad} {n} gündür hiç bırakmadı. Sen de bırakma.'),
('friend_streak','arabeskci','Dostun {ad} {n} günlük seri yaptı, yürek ister bu.'),
('friend_streak','arabeskci','{ad}''ın serisi {n} güne dayandı. Sen de dayan.'),
('friend_streak','sanayi_ustasi','{ad} {n} gündür tezgâhın başında. Adam gibi iş.'),
('friend_streak','sanayi_ustasi','Arkadaşın {ad} {n} gün aksatmadı. Sen kaçtasın?'),
('friend_streak','sanayi_ustasi','{ad} {n} günlük seriyi devirdi. Helal.'),
('friend_streak','akademisyen','{ad} {n} günlük kesintisiz çalışma serisine ulaştı.'),
('friend_streak','akademisyen','Arkadaşınız {ad} {n} gündür düzenli tekrar yapıyor.'),
('friend_streak','akademisyen','{ad}''ın serisi {n} güne ulaştı; süreklilik başarının belirleyicisidir.'),
('friend_streak','ceo','{ad} {n} gün üst üste hedefini tutturdu.'),
('friend_streak','ceo','Arkadaşın {ad} {n} günlük seride. Rekabet kızışıyor.'),
('friend_streak','ceo','{ad} {n} gündür istikrarlı. Sen de tempoyu koru.');

-- ------------------------------------------------------------ tetikleyici
-- Lig ve seri aynı tabloda; tek tetikleyicide toplanır. WHEN koşulu sayesinde
-- her XP senkronunda değil, yalnızca bu iki alan değiştiğinde çalışır.
create or replace function public.on_friend_milestone()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_kind   text;
  v_extra  text;
  v_friend uuid;
begin
  if public.league_rank(new.league) > public.league_rank(old.league) then
    v_kind  := 'friend_league_up';
    v_extra := public.league_label(new.league);
  elsif new.streak > coalesce(old.streak, 0)
        and new.streak in (7, 30, 100, 365) then
    v_kind  := 'friend_streak';
    v_extra := new.streak::text;
  else
    return new;
  end if;

  for v_friend in
    select case when f.requester_id = new.id
                then f.addressee_id else f.requester_id end
      from public.friendships f
     where f.status = 'accepted'
       and (f.requester_id = new.id or f.addressee_id = new.id)
  loop
    perform public.send_push(v_friend, v_kind, new.nickname, v_extra);
  end loop;

  return new;
end; $$;

drop trigger if exists push_on_friend_milestone on public.profiles;
create trigger push_on_friend_milestone
  after update on public.profiles
  for each row
  when (old.league is distinct from new.league
        or old.streak is distinct from new.streak)
  execute function public.on_friend_milestone();
