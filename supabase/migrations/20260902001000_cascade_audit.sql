-- 0048 — Hesap silmenin gerçekten silmesi: cascade denetimi
--
-- NEDEN: hesap silme akışı (`delete-account` edge fonksiyonu) `auth.users`
-- satırını siliyor ve gerisini yabancı anahtarların cascade'ine bırakıyor.
-- Kullanıcıyı tanımlayan bir tablo bu zincirin dışında kalırsa silme SESSİZCE
-- eksik olur: satır kalır, kullanıcı "sildim" sanır. KVKK Md. 7 / GDPR Md. 17
-- açısından savunulabilir değil.
--
-- Bu göç ŞEMAYI DEĞİŞTİRMİYOR — bir KAPI. Bugün bütün bağlar zaten
-- `on delete cascade`; buradaki iş, ileride biri cascade'siz bir tablo
-- eklediğinde göçün gürültüyle patlaması.
--
-- İKİ AYRI KONTROL:
--   (a) auth.users'a bakan HER yabancı anahtar cascade olmalı.
--   (b) Kullanıcı verisi tutan tabloların auth.users'a bakan bir anahtarı
--       OLMALI. (a) tek başına yetmez: `user_id` sütununu FK'siz eklemek
--       kontrolü tamamen atlatırdı.

-- ---------------------------------------------------------- (a) cascade mi?
do $mig$
declare
  v_bad text[];
begin
  select array_agg(format('%s.%s (%s)', n.nspname, c.relname, con.conname)
                   order by c.relname)
    into v_bad
    from pg_constraint con
    join pg_class c   on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_class rc  on rc.oid = con.confrelid
    join pg_namespace rn on rn.oid = rc.relnamespace
   where con.contype = 'f'
     and n.nspname = 'public'
     and rn.nspname = 'auth'
     and rc.relname = 'users'
     and con.confdeltype <> 'c';   -- 'c' = cascade

  if v_bad is not null then
    raise exception
      'auth.users''a cascade OLMAYAN yabancı anahtar(lar): % — hesap silme '
      'bu tablolarda satır bırakır', v_bad;
  end if;
end
$mig$;

-- ------------------------------------------------- (b) bağ gerçekten var mı?
do $mig$
declare
  -- Kullanıcıya ait veri tutan tablolar. Yeni bir tablo eklerken buraya da
  -- eklenmeli; eklenmezse silme sessizce eksik kalır.
  v_owned text[] := array[
    'profiles', 'mistakes', 'user_consents', 'friendships', 'question_sends',
    'question_attempts', 'study_attempts', 'league_members', 'device_tokens',
    'submission_tokens', 'question_reports', 'rate_limits',
    'guardian_requests', 'user_blocks', 'admins'
  ];
  v_bad text[];
begin
  select array_agg(t order by t) into v_bad
    from unnest(v_owned) t
   where not exists (
     select 1
       from pg_constraint con
       join pg_class c   on c.oid = con.conrelid
       join pg_namespace n on n.oid = c.relnamespace
       join pg_class rc  on rc.oid = con.confrelid
       join pg_namespace rn on rn.oid = rc.relnamespace
      where con.contype = 'f'
        and n.nspname = 'public'
        and c.relname = t
        and rn.nspname = 'auth'
        and rc.relname = 'users'
   );

  if v_bad is not null then
    raise exception
      'Kullanıcı verisi tutan ama auth.users''a bağlı OLMAYAN tablo(lar): % '
      '— hesap silindiğinde bu satırlar kalır', v_bad;
  end if;
end
$mig$;

-- --------------------------------------------------------- depolama uyarısı
-- Cascade satırları siler, DOSYALARI SİLMEZ. `mistake-photos` ve `avatars`
-- kovalarındaki nesneler Storage API üzerinden kaldırılmak zorunda; bunu
-- `delete-account` edge fonksiyonu, auth kullanıcısını silmeden ÖNCE yapıyor.
-- Sıra tersine çevrilirse `<uid>/` önekini listeleyecek kimlik kalmaz.
comment on schema public is
  'Hesap silme: önce depolama nesneleri (Storage API), sonra auth.users. '
  'Satırlar cascade ile gider; 0048 göçü o zincirin bütünlüğünü doğrular.';
