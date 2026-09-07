-- 0048 — my_daily_state v2: günün TEK tanımı sunucuda (Task 03, bulgu 8.2 + 10.3).
--
-- İki sorunu birden kapatıyor:
--
--  (a) SAAT DİLİMİ: istemci "bugün kaç tekrar yapıldı"yı, saat dilimi
--      bilgisi taşımayan yerel bir zaman damgasını `timestamptz` sütunuyla
--      karşılaştırarak sayıyordu; Türkiye'de gün sınırı fiilen 03:00'a
--      kayıyordu. Gece 00-03 arası yapılan tekrarlar günlük hedefe
--      sayılmıyordu. Sayım artık SUNUCUDA, Istanbul gününe göre.
--
--  (b) SATIR İNDİREN SAYAÇLAR: `reviewedTodayCount` ve `unsolvedCount`
--      satırları çekip uzunluğuna bakıyordu — tek bir tam sayı için 1000
--      satıra kadar veri. Sayılar artık bu görünümün sütunları; istemcinin
--      zaten her açılışta yaptığı TEK sorguya biniyorlar.
--
-- Ek sütunlar geldiği için görünüm DROP + CREATE (or replace sütun ekleyemez).
-- Görünümde veri yok; pencere alt saniyelik ve migration tek işlemde koşuyor.
--
-- Yeni sütunlar:
--   streak                → ETKİN seri (0047'deki kapılamanın aynısı; eski
--                           sürüm ham p.streak veriyordu ve istemcideki bozuk
--                           maskeyi besliyordu)
--   weekly_xp             → hafta kapılı (profiles_public zaten böyleydi;
--                           burada değildi — haftanın ilk açılışında geçen
--                           haftanın XP'si HUD'a sızıyordu)
--   last_activity_date    → istemci "bugün aktif miyim"i artık sunucunun
--                           söylediğinden türetiyor
--   today / week_start    → Istanbul günü ve ISO haftası; istemci cihaz
--                           saatinden gün üretmeyi bırakıyor
--   reviewed_today_count  → (a)'nın çözümü
--   due_count             → vadesi gelen tekrar sayısı (0049 zamana çevirir)
--   unsolved_received_count → (b)'nin ikinci sayacı

drop view if exists public.my_daily_state;

create view public.my_daily_state
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
       and m.next_review_date <= public.istanbul_day()
  )                                                 as due_count,
  (
    -- Ham `question_sends` DEĞİL: gelen kutusunun kendisiyle aynı süzgeç
    -- (moderasyon, engel, şikâyet, kaldırılanlar). Aksi hâlde rozet, kutuda
    -- görünmeyen soruları sayardı. `received_questions` zaten
    -- `receiver_id = auth.uid()` süzgeçli ve bu görünümün satırı da yalnızca
    -- auth.uid() için üretiliyor — ikisi aynı kullanıcı.
    select count(*)::int from public.received_questions rq
     where rq.solved_at is null
  )                                                 as unsolved_received_count
from public.profiles p
left join public.rate_limits r
       on r.user_id = p.id
      and r.bucket = 'ai'
      and r.window_key = public.istanbul_day()::text
where p.id = auth.uid();

-- DROP grant'ları düşürdü; yeniden ver.
revoke all on public.my_daily_state from public, anon;
grant select on public.my_daily_state to authenticated;

-- DROP, 0040'taki görünüm yorumunu da düşürmüştü; güncellenmiş hâliyle geri.
-- (Bağımlılık denetimi: bu görünümden select eden ya da onu dönüş tipi olarak
-- kullanan HİÇBİR fonksiyon/görünüm yok — drop'un düşürdüğü tek şey buydu.)
comment on view public.my_daily_state is
  'Kullanıcının günlük durumu (yalnızca kendi satırı): kalan AI hakkı, XP, '
  'ETKİN seri (0047 kapılaması), hafta-kapılı weekly_xp, Istanbul today/'
  'week_start ve gün sayaçları. Günün tek tanımı bu görünümdür; istemci '
  'cihaz saatinden gün üretmez (0048).';
