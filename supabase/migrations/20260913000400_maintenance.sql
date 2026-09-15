-- 0091 — Bakım ve kapatılan yüzeyler (Task 13 · Paket 2)
--
-- Dört ayrı borç kapanıyor; hepsi "yazıldı ama bağlanmadı" sınıfından.

-- ========================================================== 1) budama işleri
-- `prune_ai_calls()` (0075) ve `prune_ad_rewards()` (0076) doğru yazılmış,
-- `authenticated`'a kapalı ve 92 günlük saklama politikasını uyguluyor —
-- AMA ONLARI ÇAĞIRAN HİÇBİR ŞEY YOK. `cron.schedule` deposunda altı kez
-- geçiyor (league-weekly-rollover, scan-photos-sweep, cleanup-anonymous-daily,
-- signup-throttle-prune, ai-cache-prune, pair-streak-daily) ve hiçbiri budama
-- işi değil.
--
-- BU BİR METİN-KOD UYUŞMAZLIĞI: `docs/hukuki-metinler.md:206-207` `ai_calls`
-- ve `ad_rewards` için 92 günlük saklama süresi BEYAN EDİYOR. Defterler
-- süresiz büyüyordu, yani beyan teknik olarak karşılanmıyordu.
--
-- Bunlar yerel SQL fonksiyonları — HTTP yok, Vault sırrı yok — yani CI'da ve
-- sır girilmemiş ortamda da gerçekten çalışırlar (`scan-photos-sweep`in
-- sessiz no-op deseninin tersi).
do $cron$
begin
  perform cron.unschedule(jobid)
    from cron.job where jobname = 'ledger-prune-daily';
exception when others then
  null; -- ilk kurulumda iş yok
end
$cron$;

-- 04:10 Istanbul = 01:10 UTC. Gece penceresindeki diğer işlerle (21:05, 21:20,
-- 22:30, 00:15, 00:45 UTC) çakışmayan bir saat.
select cron.schedule(
  'ledger-prune-daily',
  '10 1 * * *',
  $$select public.prune_ai_calls(); select public.prune_ad_rewards();$$
);

-- ================================================== 2) `are_friends` ve engel
-- KÖK DÜZELTME. `are_friends` 0008'den beri yalnızca `friendships`e bakıyordu
-- ve engelleme arkadaşlığı SİLMİYOR. Sonuç: "arkadaş olmak" ile "engellenmiş
-- olmak" çelişmiyordu ve engel kontrolü HER sosyal yüzeyde AYRICA yazılmak
-- zorundaydı. Unutulduğu yerlerde açık kalıyordu — `can_read_avatar`ın arkadaş
-- dalı ve `profiles_public.avatar_path` tam olarak böyle sızdırıyordu.
--
-- Task 12 bu borcu bir mutasyonun içine yazmıştı
-- (`mutations/42_pair_streak_ignores_block.sql`): "`are_friends` engelleri HİÇ
-- GÖRMÜYOR ve ENGELLEME ARKADAŞLIĞI SİLMİYOR."
--
-- ARKADAŞLIK SATIRI SİLİNMİYOR. Engel kalkınca ilişki geri geliyor: tersine
-- çevrilebilir ve veri kaybı yok. Alternatif (engellemenin arkadaşlığı
-- silmesi) kullanıcıya AÇIKÇA söylenmesi gereken bir ürün değişikliği olurdu
-- ve "engeli kaldırdım, arkadaşım geri gelmedi" sürprizini üretirdi.
--
-- MEVCUT İKİNCİ SAVUNMALAR KALDIRILMIYOR (`sends_insert_friend`,
-- `friendships_insert_own`, `my_pair_streaks`, `send_question_to_friends`):
-- fazlalık zararsız ve mutasyon süiti onlara dayanıyor.
create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $fn$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  ) and not public.is_blocked_between(a, b);
$fn$;

revoke execute on function public.are_friends(uuid, uuid) from public, anon;
-- Politika ifadelerinin İÇİNDEN çağrılıyor; politika ifadeleri ÇAĞIRANIN
-- yetkisiyle değerlendirildiği için authenticated'a açık kalmak ZORUNDA.
grant execute on function public.are_friends(uuid, uuid) to authenticated;

comment on function public.are_friends(uuid, uuid) is
  'İki kullanıcı arkadaş mı — ENGEL DAHİL. Engelli çiftte false döner ama '
  'friendships satırı DURUR: engel kalkınca ilişki geri gelir. Politika '
  'ifadelerinden çağrıldığı için authenticated''a açık olmak zorunda.';

-- ============================================ 3) havuz sunucu yüzeyi kapanıyor
-- Havuz arayüzden çıktı (Task 02) ama sunucu kullanıcıya açık kaldı. İki
-- somut zarar vardı:
--
--   a) GİZLİLİK. `is_public` INSERT ile yazılabiliyordu (0090 kapattı) ve
--      `set_question_sharing` hâlâ `authenticated`'a açıktı — kullanıcı kendi
--      soru fotoğrafını takma adıyla tüm kullanıcılara açabiliyordu, üstelik
--      hiçbir onay defteri kaydı oluşmadan (`setShareConsent` istemcide HİÇ
--      çağrılmıyor).
--   b) XP/LİG ŞİŞİRME. `submit_pool_answer` doğru cevapta 10 XP + seri
--      veriyordu. İki hesapla (biri paylaşır, diğeri çözer) sıralama
--      şişirilebiliyordu — Kullanım Koşulları §6'nın "oyunlaştırma
--      mekanizmalarını hile ile manipüle etmek" yasağı veri katmanında
--      ZORLANMIYORDU.
--
-- FONKSİYONLAR DÜŞÜRÜLMÜYOR, yalnızca yetkileri geri alınıyor:
-- `public_questions` görünümüne bağlı üç fonksiyon zaten düşürülemiyor ve
-- havuz v2'de dönerse geri açma tek göç. Kapı esas olarak 0096'nın
-- `v_keep` listesinden çıkarılmalarıyla kuruluyor; burada AÇIKÇA da yazıyoruz
-- ki niyet katalogda değil kodda görünsün.
revoke execute on function public.set_question_sharing(uuid, boolean)
  from public, anon, authenticated;
revoke execute on function public.submit_pool_answer(uuid, int)
  from public, anon, authenticated;
revoke execute on function public.random_public_questions(int)
  from public, anon, authenticated;
revoke execute on function public.random_questions_by_topic(text, text, int)
  from public, anon, authenticated;
revoke execute on function public.available_question_counts()
  from public, anon, authenticated;

-- `sends_delete_own` POLİTİKASI DÜŞÜRÜLMÜYOR (0090 tablo düzeyi DELETE'i
-- geri aldı). Gerekçe 0084'ün `mistakes` için yazdığının aynısı: definer
-- yollar (`delete-account`) RLS'i zaten atlıyor ve politikayı silmek
-- katalogda "silme hiç düşünülmemiş" izlenimi bırakırdı.

-- ============================================ 4) anonim tespitinin yedek dalı
-- Yürürlükteki ölçüt `auth.users.is_anonymous` ve DOĞRU. Yedek dal
-- (`new.email is null`) yalnızca o sütunun BULUNMADIĞI bir Supabase sürümünde
-- devreye giriyor ve orada tehlikeli: telefon ya da OAuth girişi eklenirse
-- KALICI hesaplar anonim işaretlenir ve sosyal yüzeyin tamamı onlara kapanır
-- (dizin, lig kohortu, soru gönderme, arkadaş ekleme).
--
-- Yedek dal `phone`u da soruyor ve uyarı sertleşiyor. Bugün OAuth
-- sağlayıcılarının hepsi `config.toml`'da kapalı, yani senaryo teorik — ama
-- ölçüt sessizce yanlış olmaktansa açıkça dar olmalı.
do $mig$
declare
  v_has_col boolean;
begin
  select exists (
    select 1 from pg_attribute a
     where a.attrelid = 'auth.users'::regclass
       and a.attname = 'is_anonymous'
       and not a.attisdropped
  ) into v_has_col;

  if v_has_col then
    raise notice 'anonim tespiti auth.users.is_anonymous üzerinden (doğru dal)';
  else
    raise warning
      'auth.users.is_anonymous YOK. Anonim tespiti e-posta VE telefon '
      'yokluğuna düşüyor. DİKKAT: OAuth girişi açılırsa kalıcı hesaplar '
      'anonim işaretlenir ve sosyal yüzeyin tamamı onlara kapanır. OAuth '
      'açmadan önce Supabase sürümünü yükseltin.';
  end if;
end
$mig$;

-- ============================================ 5) istanbul_week() indirgemesi
-- Yürürlükteki KOPYALAR tek kaynağa iniyor. Tarihsel göçler, testler ve
-- mutasyonlar ELLENMİYOR (bkz. 0088).
--
-- Sütun listesi DEĞİŞMİYOR, bu yüzden `create or replace view` yeterli.
create or replace view public.profiles_public
with (security_invoker = false) as
select
  p.id,
  p.nickname,
  p.mascot,
  p.xp,
  case when p.last_activity_date >= public.istanbul_day() - 1
       then p.streak else 0 end as streak,
  p.league,
  case when p.week_start = public.istanbul_week()
       then p.weekly_xp else 0 end as weekly_xp,
  -- `are_friends` ARTIK ENGEL-FARKINDA (yukarıda): engellediğin eski
  -- arkadaşının avatar yolu burada da null dönüyor.
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

-- YETKİ 0068'İN BIRAKTIĞI YERDE KALIYOR: `authenticated` bu görünümü DOĞRUDAN
-- OKUYAMAZ. Bu paketin ilk sürümü buraya `grant select ... to authenticated`
-- yazmıştı — 0074'ten kopyalanan, 0068 dizin kilidinden ÖNCEki biçim — ve
-- serbest select ile bütün kullanıcı dizinini yeniden dökülebilir hâle
-- getiriyordu. recheck16'nın göç zamanı kapısı ilk gerçek CI koşusunda tam da
-- bunu yakalayıp `db reset`i durdurdu; kapı tasarlandığı iş için çalıştı.
--
-- Tek istemci kapısı `profiles_by_ids(uuid[])` ve `my_league_board()` olmayı
-- sürdürüyor. `create or replace view` grant'ları KORUDUĞU için aslında bu üç
-- satırın hiçbiri şart değil; yine de açıkça yazılıyorlar ki görünümü bir
-- sonraki yeniden tanımlayan göç, yetkinin ne olması gerektiğini tanımın
-- yanında görsün.
revoke all on public.profiles_public from public, anon;
revoke select on public.profiles_public from authenticated;
