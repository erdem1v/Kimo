-- 0026 — Sütun düzeyi yazma yetkileri + yönetici rolünün ayrı tabloya taşınması
--
-- SORUN: `profiles` ve `mistakes` üzerindeki update politikaları (bkz. init göçü)
-- yalnızca SATIR sahipliğini kontrol ediyor, SÜTUN kısıtı yok. Yani kullanıcı kendi
-- satırındaki her sütunu yazabiliyor:
--   • is_admin          → tek istekle tam moderasyon devralma
--   • league            → anında en üst lig (+ arkadaşlara sahte terfi bildirimi)
--   • moderation        → kaldırılmış içeriği havuza geri sokma
--   • report_count      → şikayet eşiğini sıfırlama
--   • dismissed_reports → haksız-şikayetçi yaptırımını sıfırlama
--   • solved_*          → havuz istatistiklerini şişirme
--   • source/source_*   → kendi sorusunu "ÖSYM çıkmış sorusu" gibi gösterme
--   • question_sends'te alıcının sender_id/mistake_id/note'u yeniden yazması
--
-- ÇÖZÜM: sütun düzeyi GRANT. RLS'ten önce, executor'da, her erişim yolunda
-- (PostgREST dahil) geçerli; ihlal 42501 ile GÜRÜLTÜLÜ başarısız olur.
--
-- KAPSAM: bu göç YALNIZCA istemcinin bugün hiç yazmadığı sütunları kilitler,
-- yani hiçbir Dart yazma yolu kırılmaz. xp / weekly_xp / streak / week_start /
-- last_activity_date / photo_path(update) / avatar_path / updated_at bilerek AÇIK
-- bırakıldı; onlar RPC'ler eklendikten sonra ayrı bir göçte kilitlenecek.
--
-- GERİ ALMA: aşağıdaki blok ACL'i sıfırdan yazar. Uygulamadan ÖNCE mevcut ACL'i
-- kaydedin; geri alma tam olarak onu geri yüklemektir:
--   select relname, relacl from pg_class
--    where oid in ('public.profiles'::regclass, 'public.mistakes'::regclass,
--                  'public.study_attempts'::regclass,
--                  'public.question_attempts'::regclass,
--                  'public.question_sends'::regclass,
--                  'public.push_lines'::regclass);

-- =========================================================== 1) yönetici rolü
-- is_admin, kullanıcının kendi yazabildiği satırda duruyordu. Sütun grant'ı da
-- yeterdi, ama bu en yüksek değerli hedef: politikasız bir tabloya taşıyoruz ki
-- ileride biri yanlışlıkla geniş bir GRANT yazsa bile kapı açılmasın.
create table if not exists public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  granted_at timestamptz not null default now()
);

alter table public.admins enable row level security;
-- Politika YOK = authenticated/anon için hem okuma hem yazma kapalı.
-- (app_config'teki kalıbın aynısı; yalnızca definer fonksiyonlar okur.)
revoke all on public.admins from public, anon, authenticated;

-- Mevcut yöneticileri taşı (sütun hâlâ varsa; göç tekrar çalıştırılırsa atlanır).
do $mig$
begin
  if exists (
    select 1 from pg_attribute
     where attrelid = 'public.profiles'::regclass
       and attname = 'is_admin' and attnum > 0 and not attisdropped
  ) then
    execute 'insert into public.admins (user_id)
             select id from public.profiles where is_admin
             on conflict (user_id) do nothing';
  end if;
end $mig$;

-- Okuyucuyu yeni tabloya çevir. İmza aynı kaldığı için Dart tarafı
-- (rpc('is_admin')) ve tüm admin RPC'leri değişmeden çalışır.
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select exists (select 1 from public.admins a where a.user_id = auth.uid());
$fn$;

revoke execute on function public.is_admin() from public, anon;
grant  execute on function public.is_admin() to authenticated;

-- Artık okunmuyor; düşür.
alter table public.profiles drop column if exists is_admin;

-- ==================================================== 2) updated_at sunucuda
-- Bugün istemci yazıyor. Sütunu ileride kilitleyebilmek için önce sunucu
-- tarafında doldurulmalı. Trigger'ın atadığı değer için çağırandan ayrıcalık
-- istenmez (ayrıcalık kontrolü zaten daha önce yapılır), yani sütun sonradan
-- güvenle kilitlenebilir. Şimdilik grant listesinde kalıyor ki mevcut istemci
-- 403 almasın.
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $fn$
begin
  new.updated_at := now();
  return new;
end
$fn$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
  before insert or update on public.profiles
  for each row execute function public.touch_updated_at();

-- ================================================= 3) sütun düzeyi yetkiler
-- Her tablo için üç liste: insert-edilebilir, update-edilebilir, kilitli.
-- Blok listeleri CANLI KATALOĞA karşı doğrular:
--   (a) listede olup tabloda olmayan kolon  → göç eskimiş, gürültülü hata
--   (b) tabloda olup hiçbir listede olmayan → sınıflandırılmamış kolon, hata
--   (c) hem kilitli hem yazılabilir         → çelişkili liste, hata
-- Böylece ileride biri kolon eklediğinde sessizce "yazılamaz" olmaz; göç patlar.
--
-- Yakınsama: `revoke insert, update` tablo düzeyi VE sütun düzeyi grant'ların
-- ikisini birden siler, sonraki grant ACL'i sıfırdan yazar → tekrar çalıştırmak
-- etkisiz. service_role bilerek kapsam dışı (tools/bin/supabase_admin.dart
-- içe aktarıcısı user_id / photo_path / is_public / source yazmaya devam etmeli).
do $mig$
declare
  v_cfg jsonb := $cfg$[
    {
      "table": "public.profiles",
      "insert": ["id","nickname","mascot","updated_at","xp","streak"],
      "update": ["id","nickname","mascot","updated_at","avatar_path",
                 "xp","streak","weekly_xp","week_start","last_activity_date"],
      "locked": ["display_name","exam_track","grade","is_minor","guardian_consent",
                 "hearts","gems","created_at","dismissed_reports","league","is_system"]
    },
    {
      "table": "public.mistakes",
      "insert": ["subject","concept","mistake_type","note","photo_path","options",
                 "correct_index","exam","is_public","extra_concepts"],
      "update": ["subject","concept","mistake_type","note","options","correct_index",
                 "exam","is_public","extra_concepts","step","lapses","is_leech",
                 "mastered","next_review_date","last_reviewed_at"],
      "locked": ["id","user_id","created_at","moderation","report_count",
                 "solved_correct","solved_wrong","source","source_year",
                 "source_session","correct_answer","review_count"]
    },
    {
      "table": "public.study_attempts",
      "insert": ["subject","concept","exam","correct","source","mistake_id"],
      "update": [],
      "locked": ["id","user_id","created_at"],
      "revoke_delete": true
    },
    {
      "table": "public.question_attempts",
      "insert": ["mistake_id","user_id","correct"],
      "update": [],
      "locked": ["created_at"],
      "revoke_delete": true
    },
    {
      "table": "public.question_sends",
      "insert": ["sender_id","receiver_id","mistake_id","note"],
      "update": ["solved_at","correct"],
      "locked": ["id","created_at"]
    }
  ]$cfg$::jsonb;
  r     jsonb;
  v_tbl regclass;
  v_ins text[];
  v_upd text[];
  v_den text[];
  v_all text[];
  v_bad text[];
begin
  for r in select value from jsonb_array_elements(v_cfg) loop
    v_tbl := (r->>'table')::regclass;
    v_ins := array(select jsonb_array_elements_text(r->'insert'));
    v_upd := array(select jsonb_array_elements_text(r->'update'));
    v_den := array(select jsonb_array_elements_text(r->'locked'));

    select array_agg(attname order by attnum) into v_all
      from pg_attribute
     where attrelid = v_tbl and attnum > 0 and not attisdropped;

    -- (a)
    select array_agg(distinct c) into v_bad
      from unnest(v_ins || v_upd || v_den) c where c <> all (v_all);
    if v_bad is not null then
      raise exception '%: listede olup tabloda olmayan kolon(lar): %', v_tbl, v_bad;
    end if;

    -- (b)
    select array_agg(c) into v_bad
      from unnest(v_all) c where c <> all (v_ins || v_upd || v_den);
    if v_bad is not null then
      raise exception '%: sınıflandırılmamış kolon(lar): % — bu göçü güncelleyin',
                      v_tbl, v_bad;
    end if;

    -- (c)
    select array_agg(distinct c) into v_bad
      from unnest(v_den) c where c = any (v_ins || v_upd);
    if v_bad is not null then
      raise exception '%: hem kilitli hem yazılabilir kolon(lar): %', v_tbl, v_bad;
    end if;

    execute format('revoke insert, update on %s from public, anon, authenticated', v_tbl);
    if coalesce((r->>'revoke_delete')::boolean, false) then
      execute format('revoke delete on %s from public, anon, authenticated', v_tbl);
    end if;

    if array_length(v_ins, 1) > 0 then
      execute format('grant insert (%s) on %s to authenticated',
        (select string_agg(quote_ident(c), ', ') from unnest(v_ins) c), v_tbl);
    end if;
    if array_length(v_upd, 1) > 0 then
      execute format('grant update (%s) on %s to authenticated',
        (select string_agg(quote_ident(c), ', ') from unnest(v_upd) c), v_tbl);
    end if;
  end loop;
end
$mig$;

comment on table public.profiles is
  'Kolon yazma izinleri 0026 göçünde beyaz listeyle yönetilir. Yeni kolon eklerseniz '
  'o göçteki listeye de ekleyin, yoksa göç "sınıflandırılmamış kolon" diye patlar.';
comment on table public.mistakes is
  'Kolon yazma izinleri 0026 göçünde beyaz listeyle yönetilir (bkz. profiles yorumu).';
