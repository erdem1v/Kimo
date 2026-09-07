-- 0049 — Tekrar zamanlaması: aynı gün ilk tekrar + bakım basamağı (Task 03,
-- bulgu 9.1 ve 9.2).
--
-- İKİ SORUN:
--  (a) SOĞUK BAŞLANGIÇ: yeni hataya `current_date + 1` (üstelik UTC!) vade
--      atanıyordu; ilk gün beş soru fotoğraflayan öğrenci ana ekranı yine boş
--      görüyordu. İlk tekrar artık AYNI GÜN, kayıttan ~3 saat sonra — yeni
--      öğrenilen bir şey için pedagojik olarak da doğrusu bu.
--  (b) MERDİVEN SONU: son adımı geçen soru `mastered = true` ile kuyruktan
--      KALICI çıkıyordu (toplam ömür ~41 gün). Eylülde öğrenilen konu haziran
--      sınavına kadar bir daha sorulmuyordu. Merdiven değişmiyor; sonuna
--      sınava kadar 45 günde bir dönen bir bakım basamağı ekleniyor
--      (istemcideki ReviewScheduler) ve mahsur kalmış mevcut kayıtlar burada
--      döngüye geri alınıyor.
--
-- Vade artık `next_review_at timestamptz`; `next_review_date` GÖLGE olarak
-- kalıyor (eski istemci kuyruklarının yalnızca tarih yazan kayıtları ve tarih
-- bazlı istatistikler için) ve tetikleyici tarafından damgadan türetiliyor.

-- ------------------------------------------------------------------ kolon
alter table public.mistakes
  add column if not exists next_review_at timestamptz;

-- Mevcut kayıtlar: vade günü Istanbul geceyarısı olarak damgalanır — bugünkü
-- sıralama birebir korunur.
update public.mistakes
   set next_review_at = (next_review_date::timestamp) at time zone 'Europe/Istanbul'
 where next_review_at is null
   and next_review_date is not null;

-- Eski UTC varsayılanı kalksın; ilk vadeyi artık tetikleyici atıyor.
alter table public.mistakes
  alter column next_review_date drop default;

-- ------------------------------------------------------- mahsur kayıtlar
-- Merdiveni bitirip kalıcı çıkmış sorular bakıma alınır: 45 gün + kayda göre
-- 0-13 gün saçılım (jitter) — hepsinin aynı güne yığılıp o günü boğmaması
-- için. `step` olduğu gibi kalıyor (istemci >= 4'ü bakım sayar; eski 3 de
-- doğru cevapta bakıma ilerler).
update public.mistakes
   set mastered = false,
       next_review_at = now() + interval '45 days'
                        + (abs(hashtext(id::text)) % 14) * interval '1 day',
       next_review_date = ((now() + interval '45 days'
                        + (abs(hashtext(id::text)) % 14) * interval '1 day')
                          at time zone 'Europe/Istanbul')::date
 where mastered;

-- ------------------------------------------------------------- tetikleyici
-- INSERT: vade verilmemişse aynı gün +3 saat. Her iki yönde de tarih gölgesi
-- damgadan türetilir; istemci iki alanı ayrı ayrı tutarlı yazmak zorunda
-- değil (ve yazamaz — tek doğruluk kaynağı damga).
create or replace function public.mistakes_review_timing()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    if new.next_review_at is null then
      if new.next_review_date is not null then
        -- Tarih verilmiş (ör. servis içe aktarımı): damga o günün Istanbul
        -- geceyarısı.
        new.next_review_at :=
          (new.next_review_date::timestamp) at time zone 'Europe/Istanbul';
      else
        -- Normal akış: ilk tekrar AYNI GÜN, ~3 saat sonra.
        new.next_review_at := now() + interval '3 hours';
      end if;
    end if;
  else
    if new.next_review_at is distinct from old.next_review_at
       and new.next_review_at is not null then
      -- Damga açıkça değişti: tarih aşağıda ondan türetilir.
      null;
    elsif new.next_review_date is distinct from old.next_review_date
          and new.next_review_date is not null then
      -- Yalnızca tarih değişti (eski istemcinin kuyruk kaydı): damga tarihten.
      new.next_review_at :=
        (new.next_review_date::timestamp) at time zone 'Europe/Istanbul';
    end if;
    if new.next_review_at is null then
      new.next_review_at := old.next_review_at;
    end if;
  end if;
  if new.next_review_at is not null then
    new.next_review_date :=
      (new.next_review_at at time zone 'Europe/Istanbul')::date;
  end if;
  return new;
end;
$$;

drop trigger if exists mistakes_review_timing on public.mistakes;
create trigger mistakes_review_timing
  before insert or update of next_review_at, next_review_date
  on public.mistakes
  for each row
  execute function public.mistakes_review_timing();

-- ------------------------------------------------------------------ dizin
create index if not exists mistakes_due_at_idx
  on public.mistakes (user_id, mastered, next_review_at);

-- ------------------------------------------------------------------- yetki
-- İstemci takvimi yazarken artık damgayı gönderiyor (tarih gölgesini
-- tetikleyici türetiyor). Sütun sınıflandırması 0053'te (lockdown v3)
-- katalog doğrulamalı listeye ekleniyor.
grant update (next_review_at) on public.mistakes to authenticated;

-- ------------------------------------------------- my_daily_state.due_count
-- Sayaç zamana çevrilir: bugün eklenen soru 3 saat dolunca due_count'a girer.
-- Sütun listesi 0048 ile birebir aynı → `create or replace` yeterli.
create or replace view public.my_daily_state
with (security_invoker = false) as
select
  p.id                                              as user_id,
  greatest(public.daily_ai_quota() - coalesce(r.n, 0), 0) as ai_left,
  public.daily_ai_quota()                           as ai_quota,
  public.istanbul_day_reset()                       as ai_resets_at,
  p.gems,
  p.xp,
  case when p.last_activity_date >= public.istanbul_day() - 1
       then p.streak else 0 end                     as streak,
  case when p.week_start = (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date
       then p.weekly_xp else 0 end                  as weekly_xp,
  p.league,
  p.last_activity_date,
  public.istanbul_day()                             as today,
  (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date
                                                    as week_start,
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
       and (m.next_review_at <= now()
            or (m.next_review_at is null
                and m.next_review_date <= public.istanbul_day()))
  )                                                 as due_count,
  (
    select count(*)::int from public.received_questions rq
     where rq.solved_at is null
  )                                                 as unsolved_received_count
from public.profiles p
left join public.rate_limits r
       on r.user_id = p.id
      and r.bucket = 'ai'
      and r.window_key = public.istanbul_day()::text
where p.id = auth.uid();

revoke all on public.my_daily_state from public, anon;
grant select on public.my_daily_state to authenticated;
