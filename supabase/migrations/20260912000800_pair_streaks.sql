-- 0086 — Ortak seri (Task 12 · P6 · Tur 7 · n6)
--
-- ÜRÜN KURALI (tasarımdan, aynen): "Her ikiniz de GÜNDE BİR SORU ÇÖZDÜKÇE sayı
-- büyür." Gönderim seriyi BAŞLATIYOR, SÜRDÜRMÜYOR.
--
-- BU AYRIM PLANIN EN ÖNEMLİ YAPISAL SONUCU. Karşılıklılık gönderimle ölçülse
-- "her gün soru göndermeliyim" baskısı doğar ve Snapchat'in belgelenmiş
-- patolojisi (streak snap: toplu snap, siyah fotoğraf — Hristova ve ark.,
-- GamiFIN 2020) Kimo'da tekrarlardı. Ölçüt kendi çalışman olduğu için ÇÖP
-- GÖNDERİM GÜDÜSÜ HİÇ DOĞMUYOR — bir kalite kapısı aramak yerine kalitenin
-- bozulabileceği mekanizma kurulmuyor.
--
-- KAYNAK OLAY KİŞİSEL SERİYLE AYNI: `profiles.last_activity_date`.
-- `apply_progress`e DOKUNULMUYOR — tek UPDATE kuralı var (bölünürse
-- `sync_league_member_xp` ve `on_friend_milestone` iki kez koşar) ve oraya bir
-- arkadaş döngüsü koymak `on_friend_milestone`ın ölçeklenmeme sorununu
-- büyütürdü.
--
-- NEDEN TABLO GEREKİYOR: "üst üste kaç gün" `profiles`tan TÜRETİLEMİYOR —
-- günlük geçmiş tutulmuyor. Haftalık/günlük İLERLEME türetilebilir, ZİNCİR
-- türetilemez.
--
-- AD `pair_streaks`, `friend_streaks` DEĞİL: `friend_streak` ZATEN bir bildirim
-- türü (`NotifyKind.friendStreak`) ve o, bir ARKADAŞIN KİŞİSEL serisinin
-- kilometre taşını anlatıyor. Aynı adı tabloya vermek iki farklı şeyi
-- karıştırırdı.
--
-- VARSAYILAN KAPALI: `ff_pair_streak` (0079) `false` tohumlanmış. AB
-- Komisyonu'nun DSA Md. 28(1) Kılavuzu (14 Temmuz 2025, par. 57(b)(viii))
-- "streaks"i küçükler için varsayılan kapalı istiyor. Türkiye DSA'ya tabi
-- değil ama bu şu an "küçükler için uygun tasarım"ın en güçlü üçüncü taraf
-- tanımı ve hedef kitle sınav kaygısı olan 14-18 yaş.
--
-- GERİ ALMA: `select cron.unschedule(jobid) from cron.job where jobname =
-- 'pair-streak-daily';` + `drop table public.pair_streaks cascade;`
-- İstemci tarafı `ff_pair_streak = false` ile zaten susuyor.

-- ====================================================== yapılandırma
insert into public.app_config (key, value) values
  ('pair_streak_max', '3')
on conflict (key) do nothing;

-- NEDEN 3: sınırsız olsa 20 arkadaşı olan kullanıcı her gün YİRMİ AYRI
-- başarısızlık yolu taşır ve bildirim hacmi N ile büyür. Duolingo düşük
-- riskli bir dil uygulamasında 5 kullanıyor; Kimo'da öğrenci ZATEN XP + altı
-- kademeli lig + kişisel seri + hak penceresi taşıyor, yani her ek partner
-- çarpımsal yükümlülük. `app_config`'te olduğu için göç gerektirmeden
-- artırılabilir.

-- ====================================================== tablo
create table if not exists public.pair_streaks (
  a_id       uuid not null references auth.users(id) on delete cascade,
  b_id       uuid not null references auth.users(id) on delete cascade,
  streak     int  not null default 0,
  best       int  not null default 0,
  last_day   date,
  started_at timestamptz not null default now(),
  primary key (a_id, b_id),
  -- KANONİK SIRA: "kim kime" sorusu ikili seride anlamsız ve iki satır tutmak
  -- iki doğruluk kaynağı demek. Kısıt, yanlış sırayla yazmayı VERİ
  -- KATMANINDA imkânsız kılıyor.
  constraint pair_streaks_canonical check (a_id < b_id)
);

create index if not exists pair_streaks_b_idx on public.pair_streaks (b_id);

alter table public.pair_streaks enable row level security;

-- Politika YOK = yalnızca definer fonksiyonlar erişir. Okuma
-- `my_pair_streaks()`ten; istemcinin tabloya yazması kendi serisini
-- şişirmesi demekti.
revoke all on public.pair_streaks from public, anon, authenticated;

comment on table public.pair_streaks is
  'İkili (ortak) seri. Bir gün sayılıyor çünkü İKİSİ DE o gün en az bir soru '
  'çözdü — gönderim seriyi başlatıyor, sürdürmüyor. Satır kanonik sırada '
  '(a_id < b_id). Yalnızca sunucu.';

-- ====================================================== okuma
-- Parametresiz (Task 01 değişmezi: hiçbir RPC `user_id` parametresi almaz).
--
-- `streak` TEMBEL MASKEDEN geçiyor: kişisel serinin `last_activity_date >=
-- istanbul_day() - 1` kuralının aynısı. Cron düşse bile bayat bir sayı
-- gösterilmiyor — Task 03'ün seri kararının ruhu korunuyor.
--
-- İKİ CANLI BAYRAK: `me_today` ve `friend_today`. Tasarımın risk satırı
-- ("Ortak serin bugün bekliyor · Bir soru çözersen 6 günlük seriniz devam
-- eder") bunlardan üretiliyor ve KİMİN çözmediğini YAZMIYOR — arayüz yalnızca
-- kendi payını söylüyor.
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

-- ====================================================== başlatma
-- Tasarım (n6, 2. an): çağrı ancak Y, X'in sorusunu ÇÖZDÜKTEN sonra çıkıyor.
-- Seri gerçekten başlıyorsa iki yönde de çözülmüş bir gönderim olmalı —
-- yoksa "ortak" bir şey yok.
--
-- ÜST SINIR BURADA: `pair_streak_max`. Aşımda istisna ATMIYOR, `false`
-- dönüyor; arayüz "şimdilik bu kadar" diyebilsin diye.
create or replace function public.start_pair_streak(p_friend uuid)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_a   uuid;
  v_b   uuid;
  v_n   int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_friend is null or p_friend = v_uid then
    return false;
  end if;
  if not public.are_friends(v_uid, p_friend) then
    return false;
  end if;
  if public.is_blocked_between(v_uid, p_friend) then
    return false;
  end if;

  -- İKİ YÖNDE DE çözülmüş gönderim şartı.
  if not exists (
    select 1 from public.question_sends s
     where s.sender_id = v_uid and s.receiver_id = p_friend
       and s.solved_at is not null
  ) or not exists (
    select 1 from public.question_sends s
     where s.sender_id = p_friend and s.receiver_id = v_uid
       and s.solved_at is not null
  ) then
    return false;
  end if;

  v_a := least(v_uid, p_friend);
  v_b := greatest(v_uid, p_friend);

  if exists (select 1 from public.pair_streaks s
              where s.a_id = v_a and s.b_id = v_b) then
    return false;   -- zaten var
  end if;

  select count(*)::int into v_n
    from public.pair_streaks s
   where v_uid in (s.a_id, s.b_id);
  if v_n >= public.config_int('pair_streak_max', 3) then
    return false;
  end if;

  insert into public.pair_streaks (a_id, b_id, streak, best, last_day)
  values (v_a, v_b, 1, 1, public.istanbul_day())
  on conflict do nothing;
  return true;
end
$fn$;

revoke execute on function public.start_pair_streak(uuid) from public, anon;
grant  execute on function public.start_pair_streak(uuid) to authenticated;

-- ====================================================== çıkış
-- Tek dokunuşla çıkış (DSA kılavuzunun istediği) ve ÇIKIŞ KARŞI TARAFA
-- BİLDİRİLMİYOR: bildirilirse ayrılmak sosyal olarak cezalandırılır.
create or replace function public.leave_pair_streak(p_friend uuid)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_hit int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  delete from public.pair_streaks s
   where s.a_id = least(v_uid, p_friend)
     and s.b_id = greatest(v_uid, p_friend)
     and v_uid in (s.a_id, s.b_id);
  get diagnostics v_hit = row_count;
  return v_hit > 0;
end
$fn$;

revoke execute on function public.leave_pair_streak(uuid) from public, anon;
grant  execute on function public.leave_pair_streak(uuid) to authenticated;

-- ====================================================== gecelik devir
-- İkisi de DÜN aktifse +1, değilse 0. Tek geçiş, idempotent: aynı gün için
-- ikinci koşu `last_day` zaten dünse hiçbir şey yapmıyor.
create or replace function public.pair_streak_rollover()
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_yday date := public.istanbul_day() - 1;
begin
  -- İLERLET: ikisi de dün aktifti.
  update public.pair_streaks s
     set streak   = s.streak + 1,
         best     = greatest(s.best, s.streak + 1),
         last_day = v_yday
    from public.profiles pa, public.profiles pb
   where pa.id = s.a_id
     and pb.id = s.b_id
     and s.last_day is distinct from v_yday
     and pa.last_activity_date = v_yday
     and pb.last_activity_date = v_yday;

  -- SIFIRLA: en az biri dün çalışmadı ve seri hâlâ açık görünüyor.
  -- Tasarım kırılmayı sıfırlama olarak istiyor ("Ortak seriniz sıfırlandı");
  -- DİL suçlamıyor ve davetle bitiyor, ama SAYI sıfırlanıyor.
  update public.pair_streaks s
     set streak = 0
    from public.profiles pa, public.profiles pb
   where pa.id = s.a_id
     and pb.id = s.b_id
     and s.streak > 0
     and s.last_day is distinct from v_yday
     and (pa.last_activity_date is distinct from v_yday
          or pb.last_activity_date is distinct from v_yday);
end
$fn$;

revoke execute on function public.pair_streak_rollover()
  from public, anon, authenticated;

comment on function public.pair_streak_rollover() is
  'Gecelik ikili seri devri: ikisi de dün aktifse +1, değilse 0. İdempotent. '
  'Yalnızca cron çağırır.';

-- ====================================================== zamanlama
-- 00:20 Istanbul = 21:20 UTC. pg_cron UTC çalışır; depo "Istanbul DST
-- uygulamıyor, sabit +3" varsayımını kodda yazılı tutuyor (0051).
--
-- NEDEN `league_weekly_rollover`IN İÇİNE GÖMÜLMEDİ: iki özelliği tek definer
-- fonksiyona bağlamak, birinin hatasının diğerini de düşürmesi demekti ve
-- Task 01'in "tek iş, tek işlem" disiplinini bozardı.
do $cron$
begin
  perform cron.unschedule(jobid)
    from cron.job where jobname = 'pair-streak-daily';
exception when others then
  null; -- ilk kurulumda tablo boş; sorun değil
end
$cron$;

select cron.schedule(
  'pair-streak-daily',
  '20 21 * * *',
  $$select public.pair_streak_rollover()$$
);
