-- 0079 — Uzaktan özellik bayrakları (Task 12 · P0)
--
-- NEDEN VAR: bu depoda bir arayüz özelliğini mağaza güncellemesi olmadan
-- kapatmanın HİÇBİR yolu yoktu. `lib/state/features.dart` tek bayraklı ve
-- DERLEME ZAMANI (`bool.fromEnvironment`), `app_config` ise istemciye bilinçli
-- olarak kapalı (bkz. `lib/services/legal_links.dart`). Uzaktan
-- değiştirilebilen tek şey SUNUCU DAVRANIŞI (kota, reklam tavanı, TTL) idi;
-- çizilen bir yüzey değil.
--
-- Task 12 üç riskli yüzey getiriyor (ortak seri, çoklu çekim, ödüllü reklamın
-- kendisi) ve hedef kitle sınav kaygısı olan 14-18 yaş. Ölçüm kötü çıkarsa
-- geri almanın yolu bir sürüm beklemek olmamalı.
--
-- TEK ÖZELLİK İÇİN DEĞİL: bayrak kümesi genişletilebilir yazıldı. Yeni riskli
-- özelliğin bedeli = `feature_flags()` gövdesine bir satır + `app_config`'e bir
-- tohum + görünüme bir sütun + istemcide bir alan. FONKSİYON ADI VE GRANT'I
-- DEĞİŞMİYOR, yani `function_grants_recheck` bir kez yazıldı.
--
-- BAYRAK NEREDEN OKUNUYOR: `my_daily_state`. İstemci o görünümü zaten her
-- açılışta okuyor, yani yeni bir istemci yüzeyi (RPC, ekran, istek) gerekmedi.
-- Bedeli: görünüme sütun eklemek `create or replace` ile YAPILAMIYOR, DROP +
-- CREATE gerekiyor ve göç ile istemci BİRLİKTE dağıtılmak zorunda (0075'in
-- aynı notu).
--
-- FAIL-OPEN/FAIL-CLOSED: `config_bool` anahtar yoksa ÇAĞIRANIN VERDİĞİ
-- VARSAYILANA düşüyor, yani politika kodda duruyor. 0075'in asimetrisi
-- korunuyor: kota/özellik sayıları fail-open, kimlik doğrulama sırrı
-- fail-closed (`ad_reward_secret` yoksa ödül verilmez).
--
-- GERİ ALMA: `delete from public.app_config where key like 'ff\_%';` bayrakları
-- koddaki varsayılanlara döndürür. Görünümü eski hâline almak isterseniz bu
-- göçün DROP+CREATE bloğunu 0075'teki gövdeyle tekrarlamanız gerekir.

-- ====================================================== boolean yapılandırma
-- `config_int` (0075) ile aynı desen, boolean için. ÜÇ biçim kabul ediliyor
-- ('true'/'t'/'1' ve karşıtları) çünkü değeri elle SQL Editor'dan giren bir
-- insan hangisini yazacağını hatırlamak zorunda kalmasın; TANINMAYAN değer
-- `null` üretiyor ve `coalesce` varsayılana düşüyor — yani yazım hatası
-- özelliği sessizce KAPATMIYOR, varsayılana bırakıyor.
create or replace function public.config_bool(p_key text, p_default boolean)
returns boolean language sql stable security definer set search_path = public
as $fn$
  select coalesce(
    (select case
              when lower(btrim(value)) in ('true',  't', '1') then true
              when lower(btrim(value)) in ('false', 'f', '0') then false
            end
       from public.app_config where key = p_key),
    p_default);
$fn$;

-- HERKESTEN REVOKE: yalnızca `feature_flags()` çağırıyor ve o tanımlayıcı
-- yetkisiyle koştuğu için EXECUTE'a ihtiyaç duymuyor (`config_int` ve
-- `bump_rate_limit` ile aynı durum). İstemciye açılması, istemcinin
-- `app_config`'teki HERHANGİ bir anahtarı yoklayabilmesi demekti — orada
-- `push_service_key` duruyor.
revoke execute on function public.config_bool(text, boolean)
  from public, anon, authenticated;

comment on function public.config_bool(text, boolean) is
  'app_config''ten boolean okur; anahtar yok ya da değer tanınmıyorsa '
  'çağıranın verdiği varsayılan (fail-open). Yalnızca definer fonksiyonlar '
  'çağırır — app_config istemciye kapalı.';

-- ============================================================ bayrak kümesi
-- TEK FONKSİYON, bilinçli. `security_invoker = false` bir görünümün SELECT
-- listesinde DOĞRUDAN çağrılan her fonksiyonun EXECUTE'u ÇAĞIRANA karşı
-- denetleniyor (0040'ın 121-125. satırlarındaki ders, 0078'in ilk maddesi).
-- Bayrak başına ayrı fonksiyon açmak, bayrak başına bir `grant` ve bir
-- `function_grants_recheck` satırı demekti. Tek fonksiyon → tek grant.
--
-- SIFIR ARGÜMANLI ve kullanıcıya özel hiçbir şey okumuyor: bayraklar
-- kullanıcıdan bağımsız. `auth.uid()` bile gerekmiyor, yani doğrudan
-- çağrılsa bile sızdıracak bir şey yok.
create or replace function public.feature_flags()
returns table (
  ff_pair_streak   boolean,
  ff_multi_capture boolean,
  ff_ad_reward     boolean
) language sql stable security definer set search_path = public
as $fn$
  select
    -- VARSAYILAN KAPALI. AB Komisyonu'nun DSA Md. 28(1) Kılavuzu (14 Temmuz
    -- 2025) "streaks"i ismen sayıyor ve küçükler için varsayılan olarak kapalı
    -- olmasını istiyor (par. 57(b)(viii)). Türkiye DSA'ya tabi değil ama bu şu
    -- an "küçükler için uygun tasarım"ın en güçlü üçüncü taraf tanımı.
    public.config_bool('ff_pair_streak',   false),
    -- VARSAYILAN AÇIK: bayrak bir KILL SWITCH. Premium kapısı ayrı bir
    -- mekanizma (`profiles.premium_until`); bu bayrak özelliğin tümünü
    -- kapatıyor, ücretsiz/premium ayrımını yapmıyor.
    public.config_bool('ff_multi_capture', true),
    -- VARSAYILAN AÇIK: 0076 ile sevk edildi ve çalışıyor. Bayrak, AdMob
    -- tarafında bir sorun çıktığında (SSV kesintisi, politika uyarısı)
    -- reklam yüzeyini sürüm beklemeden kapatmak için.
    public.config_bool('ff_ad_reward',     true);
$fn$;

revoke execute on function public.feature_flags() from public, anon;
grant  execute on function public.feature_flags() to authenticated;

comment on function public.feature_flags() is
  'Uzaktan açılıp kapanan arayüz yüzeyleri. Değerler app_config''ten '
  'fail-open okunuyor; varsayılanlar gövdede. `my_daily_state` görünümünün '
  'SELECT listesinde DOĞRUDAN çağrıldığı için authenticated''a açık olmak '
  'ZORUNDA. Yeni bayrak = bu gövdeye bir satır + görünüme bir sütun.';

-- ============================================================ tohum
-- `do nothing`: üretimde elle girilmiş bir değer varsa göç onu EZMEMELİ
-- (0075'in aynı gerekçesi). Satırların VAR OLMASI, bayrağın nereden
-- değiştirileceğini SQL Editor'da arayan kişiye anahtar adlarını gösteriyor.
insert into public.app_config (key, value) values
  ('ff_pair_streak',   'false'),
  ('ff_multi_capture', 'true'),
  ('ff_ad_reward',     'true')
on conflict (key) do nothing;

-- ====================================================== günlük durum v4
-- DROP + CREATE: `create or replace view` SÜTUN EKLEYEMİYOR. Gövde 0075'ten
-- BİREBİR kopyalandı ve yalnızca üç şey değişti:
--   1. `from` listesine `public.feature_flags() f` eklendi,
--   2. SELECT listesinin sonuna üç bayrak sütunu eklendi,
--   3. bu yorum.
-- Üç alt sorgu (reviewed_today_count / due_count / unsolved_received_count)
-- ve kota sütunlarının SIRASI bilerek korundu: bu paketteki en olası regresyon
-- onları yeniden yazarken bir süzgeci sessizce değiştirmek olurdu.
drop view if exists public.my_daily_state;

create view public.my_daily_state
with (security_invoker = false) as
select
  p.id                                              as user_id,
  p.gems,
  p.xp,
  case when p.last_activity_date >= public.istanbul_day() - 1
       then p.streak else 0 end                     as streak,
  case when p.week_start = (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date
       then p.weekly_xp else 0 end                  as weekly_xp,
  p.league,
  p.last_activity_date,
  p.premium_until,
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
    select count(*)::int from public.received_questions rq
     where rq.solved_at is null
  )                                                 as unsolved_received_count,
  s.ai_tier,
  s.ai_state,
  s.ai_left,
  s.ai_window_left,
  s.ai_window_limit,
  s.ai_month_left,
  s.ai_month_limit,
  s.ai_next_at,
  s.ai_next_at_hm,
  s.ai_month_resets_at,
  s.ai_month_resets_on,
  s.ai_window_hours,
  s.ad_rewards_left,
  s.ad_rewards_per_day,
  s.ad_offer,
  s.plus_window_limit,
  s.plus_month_limit,
  f.ff_pair_streak,
  f.ff_multi_capture,
  f.ff_ad_reward
from public.profiles p, public.ai_state() s, public.feature_flags() f
where p.id = auth.uid();

revoke all on public.my_daily_state from public, anon;
grant select on public.my_daily_state to authenticated;

comment on view public.my_daily_state is
  'Kullanıcının günlük durumu (yalnızca kendi satırı). Analiz hakkının TÜM '
  'gösterim değerleri burada: durum, kalan, sonraki hakkın saati, ayın '
  'yenilenme günü, reklam hakkı. Ayrıca uzaktan açılıp kapanan özellik '
  'bayrakları (ff_*). İstemci hiçbir şey hesaplamıyor.';
