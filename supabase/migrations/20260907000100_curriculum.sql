-- 0071 — Konu ağacı veritabanına: tek çalışma zamanı kaynağı
--
-- SORUN. Ağaç yedi yerde duruyordu ve hiçbiri diğerini doğrulamıyordu:
-- `analyze-question/taxonomy.ts` (434 konu), `lib/data/yks_curriculum.dart`
-- (aynı 434 konu + 139 ünite), `lib/data/yks_subjects.dart` (ders adları),
-- `tools/bin/import_meb.dart` (ders adı Set'i), `mistake_style.dart`
-- (ders→renk), `tools/remap_konu.sql` (265 MEB etiketi) ve manifestler.
-- Senkronu garanti eden tek şey `yks_curriculum.dart:5-7`'deki bir yorumdu.
-- Üstelik `taxonomy.ts:2` kaynak olarak `YKS_TYT_AYT_Konulari.md` gösteriyordu
-- — o dosya git geçmişinde HİÇ commit edilmemiş, yani ağacın gerçek kaynağı
-- doğrulanamıyordu.
--
-- ÇÖZÜM İKİ KATMANLI:
--   • YAZIM kaynağı `taxonomy/yks-konulari.md` (insan düzenler, PR'da okunur)
--   • ÇALIŞMA ZAMANI kaynağı BU TABLOLAR — istem metni, doğrulama ve istemci
--     seçicisi hepsi buradan besleniyor.
-- Tohum `tools/build_taxonomy.py` ile üretiliyor (0072).
--
-- NEDEN VERİTABANI, NEDEN ÜRETİLEN İKİ DOSYA DEĞİL: istemcinin gösterdiği ağaç
-- ile sunucunun doğruladığı ağaç AYNI olmak zorunda. İki ayrı derleme
-- hedefine (Deno / Flutter bundle) gömülen iki kopya, sürümleri ayrıştığı anda
-- kullanıcıya "listeden seçtiğim konu reddedildi" diye görünür. Tek kopya
-- veritabanında; istemci onu çekip önbelleğe alıyor ve SÜRÜM pazarlığı
-- yapıyor.

-- =========================================================== normalizasyon
-- Türkçe duyarlı: "Atışlar" ≡ "atislar". Üç yerde AYNI sonucu vermek zorunda —
-- burada (etiket çözümü), `tools/build_taxonomy.py` (çakışma denetimi) ve
-- Dart'ta (istemci araması). Ayrışırlarsa kullanıcının yazdığı kelime
-- sunucunun bulduğuyla eşleşmez.
--
-- `translate` + `lower` sırası ÖNEMLİ: önce Türkçe harfler ASCII'ye
-- çevriliyor, sonra küçültülüyor. Ters sırada `lower('I')` C yerelinde 'i'
-- verir ama `lower('İ')` iki kod noktası üretir ve eşleşme kaçar.
--
-- `immutable` OLMAK ZORUNDA: `curriculum_aliases.alias_norm` üretilmiş bir
-- sütun ve birincil anahtarın parçası.
create or replace function public.tr_norm(p_value text)
returns text
language sql immutable strict
as $fn$
  select lower(translate(p_value,
                         'ÇĞİÖŞÜÂÎÛçğıöşüâîû',
                         'CGIOSUAIUcgiosuaiu'));
$fn$;

revoke execute on function public.tr_norm(text) from public, anon;
grant  execute on function public.tr_norm(text) to authenticated;

comment on function public.tr_norm(text) is
  'Türkçe duyarlı arama normalizasyonu. tools/build_taxonomy.py ve Dart '
  'tarafındaki trNorm ile aynı sonucu vermek zorunda.';

-- =============================================================== tablolar
-- Üçü de YALNIZCA-SUNUCU (`push_kinds` deseni): RLS açık, POLİTİKA YOK,
-- `revoke all`. Okuma tek kapıdan — `curriculum_tree()`.
--
-- Neden kullanıcıya doğrudan açılmıyor: ağaç herkes için aynı ve statik, yani
-- satır düzeyi bir kural yok; açık bir tablo yalnızca sürüm pazarlığını ve
-- gruplamayı istemciye bırakırdı. Tek RPC hem sürümü hem ağacı tek turda
-- veriyor.
create table if not exists public.curriculum_topics (
  curriculum  text not null,
  exam        text not null,
  subject     text not null,
  unit        text not null,
  topic       text not null,
  subject_ord int  not null,
  unit_ord    int  not null,
  topic_ord   int  not null,
  primary key (curriculum, exam, subject, topic)
);

create index if not exists curriculum_topics_order_idx
  on public.curriculum_topics (curriculum, exam, subject_ord, unit_ord, topic_ord);

create table if not exists public.curriculum_aliases (
  curriculum text not null,
  exam       text not null,
  subject    text not null,
  alias      text not null,
  -- ÜRETİLMİŞ SÜTUN: normalizasyon veritabanında hesaplanıyor, tohum
  -- tarafından yazılmıyor. Üretici ile veritabanının ayrışması böylece
  -- yapısal olarak imkânsız.
  alias_norm text not null generated always as (public.tr_norm(alias)) stored,
  topic      text not null,
  kind       text not null check (kind in ('ara', 'eski')),
  -- 'eski' türünde, kaydın ESKİ sınavı farklıysa. Tek gerçek örnek:
  -- TYT/Geometri 'Çember ve Daire' → AYT/Geometri 'Çemberde Temel Kavramlar'.
  src_exam   text,
  primary key (curriculum, exam, subject, alias_norm)
);

comment on table public.curriculum_aliases is
  'Konu arama etiketleri (kind=''ara'') ve eski adlar (kind=''eski''). '
  'Etiketler AI istemine GİRMEZ; yalnızca seçicide eşleşir ve kaydedilen '
  'değer her zaman kanonik konu adıdır.';

create table if not exists public.curriculum_meta (
  -- Tek satır garantisi: birincil anahtar sabit `true`.
  only_row     boolean primary key default true check (only_row),
  version      text not null,
  source_sha   text not null,
  generated_at timestamptz not null default now()
);

alter table public.curriculum_topics  enable row level security;
alter table public.curriculum_aliases enable row level security;
alter table public.curriculum_meta    enable row level security;

revoke all on public.curriculum_topics  from public, anon, authenticated;
revoke all on public.curriculum_aliases from public, anon, authenticated;
revoke all on public.curriculum_meta    from public, anon, authenticated;

-- ============================================================ okuma kapısı
-- TEK ÇAĞRI, TEK TUR. `p_known_version` istemcinin elindeki sürüm; eşleşirse
-- ağaç GÖNDERİLMEZ. 434 konu + 547 etiket her açılışta indirilmesin diye.
--
-- Dönüş jsonb: istemci ~1000 satırı yeniden gruplamak zorunda kalmasın.
-- Gruplama ve sıralama burada, yani "tek kaynak" gerçekten tek yerde.
create or replace function public.curriculum_tree(
  p_curriculum    text,
  p_known_version text default null
)
returns jsonb
language plpgsql stable security definer set search_path = public
as $fn$
declare
  v_cur     text := case when p_curriculum = 'maarif' then 'maarif' else 'eski' end;
  v_version text;
begin
  if auth.uid() is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  select m.version into v_version from public.curriculum_meta m;
  if v_version is null then
    raise exception 'konu ağacı tohumlanmamış' using errcode = '22023';
  end if;
  if p_known_version is not null and p_known_version = v_version then
    -- Taze: istemci elindekini kullanmaya devam etsin.
    return jsonb_build_object('version', v_version, 'fresh', true);
  end if;

  return jsonb_build_object(
    'version', v_version,
    'fresh', false,
    'curriculum', v_cur,
    'exams', (
      select coalesce(jsonb_object_agg(e.exam, e.subjects), '{}'::jsonb)
        from (
          select t.exam,
                 jsonb_agg(t.subject_obj order by t.subject_ord) as subjects
            from (
              select s.exam, s.subject_ord,
                     jsonb_build_object(
                       'subject', s.subject,
                       'units', jsonb_agg(s.unit_obj order by s.unit_ord)
                     ) as subject_obj
                from (
                  select u.exam, u.subject, u.subject_ord, u.unit_ord,
                         jsonb_build_object(
                           'unit', u.unit,
                           'topics', jsonb_agg(u.topic_obj order by u.topic_ord)
                         ) as unit_obj
                    from (
                      select c.exam, c.subject, c.unit,
                             c.subject_ord, c.unit_ord, c.topic_ord,
                             jsonb_build_object(
                               'topic', c.topic,
                               'aliases', coalesce((
                                 select jsonb_agg(a.alias order by a.alias)
                                   from public.curriculum_aliases a
                                  where a.curriculum = c.curriculum
                                    and a.exam = c.exam
                                    and a.subject = c.subject
                                    and a.topic = c.topic
                               ), '[]'::jsonb)
                             ) as topic_obj
                        from public.curriculum_topics c
                       where c.curriculum = v_cur
                    ) u
                   group by u.exam, u.subject, u.subject_ord, u.unit, u.unit_ord
                ) s
               group by s.exam, s.subject, s.subject_ord
            ) t
           group by t.exam
        ) e
    )
  );
end
$fn$;

revoke execute on function public.curriculum_tree(text, text) from public, anon;
grant  execute on function public.curriculum_tree(text, text) to authenticated;

-- ============================================================== doğrulama
-- Politika ve tetikleyici içinden çağrılıyor → `security definer` VE
-- `authenticated`'a açık olmak ZORUNDA (0052'nin dersi: politika ifadeleri
-- çağıranın yetkisiyle değerlendiriliyor, tablo görünmezse alt sorgu her zaman
-- boş döner ve kapı hiç ısırmaz).
create or replace function public.is_valid_topic(
  p_curriculum text,
  p_exam       text,
  p_subject    text,
  p_topic      text
)
returns boolean
language sql stable security definer set search_path = public
as $fn$
  select exists (
    select 1 from public.curriculum_topics c
     where c.curriculum = coalesce(p_curriculum, 'eski')
       and c.exam = p_exam
       and c.subject = p_subject
       and c.topic = p_topic
  );
$fn$;

revoke execute on function public.is_valid_topic(text, text, text, text)
  from public, anon;
grant  execute on function public.is_valid_topic(text, text, text, text)
  to authenticated;

-- Etiket / eski ad → kanonik konu. İçe aktarma ve tohumun remap'i kullanıyor.
create or replace function public.resolve_topic_alias(
  p_curriculum text,
  p_exam       text,
  p_subject    text,
  p_name       text
)
returns text
language sql stable security definer set search_path = public
as $fn$
  select coalesce(
    -- Önce kanonik ad: kendisi zaten geçerliyse etiket aramaya gerek yok.
    (select c.topic from public.curriculum_topics c
      where c.curriculum = coalesce(p_curriculum, 'eski')
        and c.exam = p_exam and c.subject = p_subject
        and public.tr_norm(c.topic) = public.tr_norm(p_name)),
    (select a.topic from public.curriculum_aliases a
      where a.curriculum = coalesce(p_curriculum, 'eski')
        and a.exam = p_exam and a.subject = p_subject
        and a.alias_norm = public.tr_norm(p_name))
  );
$fn$;

revoke execute on function public.resolve_topic_alias(text, text, text, text)
  from public, anon;
grant  execute on function public.resolve_topic_alias(text, text, text, text)
  to authenticated;

-- ================================================ satır hangi müfredattan?
-- Bugün bir `mistakes` satırı bunu KAYDETMİYOR ve sonucu somut:
-- ('Matematik', 'Kuvvet ve Hareket') hem eski AYT'de hem maarif TYT'de var,
-- ayırt edilemiyor. `all_questions_screen.dart:63` bu yüzden MODERATÖRÜN kendi
-- müfredatına göre doğruluyor — maarif öğrencisinin doğru kaydı, eski
-- müfredatlı bir moderatöre "müfredatta karşılığı yok" görünüyor.
--
-- Değer JWT metadata'sından geliyor (`user_metadata.curriculum`), yani
-- kullanıcının kendi beyanı — bir güvenlik sınırı değil, sınıflandırma alanı.
-- Beyaz liste dışındaki her değer 'eski'ye düşüyor.
create or replace function public.my_curriculum()
returns text
language sql stable
as $fn$
  select case
           when coalesce(auth.jwt() -> 'user_metadata' ->> 'curriculum', '') = 'maarif'
             then 'maarif'
           else 'eski'
         end;
$fn$;

revoke execute on function public.my_curriculum() from public, anon;
grant  execute on function public.my_curriculum() to authenticated;

-- `stable` bir DEFAULT: Postgres ALTER anında BİR KEZ değerlendirip mevcut
-- satırların hepsine yazıyor. Oturum yok (göç `postgres` olarak koşuyor) →
-- 'eski'. Bugüne kadarki tüm kayıtlar zaten eski müfredattan, doğru değer.
alter table public.mistakes
  add column if not exists curriculum text not null default public.my_curriculum();

comment on column public.mistakes.curriculum is
  'Satırın hangi müfredat ağacına ait olduğu. Sunucu yazar (my_curriculum()); '
  'istemciye kapalı. Doğrulama tetikleyicisi bu değere göre karar veriyor.';

-- ================================================== yazma yolunda doğrulama
-- "Serbest metin girilmez" bugüne kadar yalnızca İSTEMCİ kuralıydı:
-- `mistakes.subject/concept` serbest `text`, ne FK ne CHECK var; edge function
-- da AI'ın önerisini yalnızca `konu_valid` diye İŞARETLİYOR, reddetmiyor.
-- PostgREST'e doğrudan istek atan biri istediği konuyu yazabiliyordu.
--
-- SADECE DEĞİŞİNCE ATEŞLİYOR (`is distinct from`). Bu koşul kritik: aksi hâlde
-- henüz temizlenmemiş eski bir satıra dokunan HER `admin_update_question`
-- çağrısı — yani onları düzeltmek için var olan araç — reddedilirdi.
-- Dokunulmayan eski satır yerinde kalıyor; her DÜZENLEME geçerli bir konuya
-- inmek zorunda.
create or replace function public.mistakes_topic_check()
returns trigger
language plpgsql
as $fn$
declare
  v_extra text;
begin
  if tg_op = 'UPDATE'
     and new.exam is not distinct from old.exam
     and new.subject is not distinct from old.subject
     and new.concept is not distinct from old.concept
     and new.extra_concepts is not distinct from old.extra_concepts
  then
    return new;
  end if;

  if not public.is_valid_topic(new.curriculum, new.exam, new.subject, new.concept) then
    raise exception 'Konu müfredat ağacında yok: % / % / %',
      new.exam, new.subject, new.concept using errcode = 'KM022';
  end if;

  foreach v_extra in array coalesce(new.extra_concepts, array[]::text[]) loop
    if not public.is_valid_topic(new.curriculum, new.exam, new.subject, v_extra) then
      raise exception 'Ek konu müfredat ağacında yok: %', v_extra
        using errcode = 'KM022';
    end if;
  end loop;

  return new;
end
$fn$;

drop trigger if exists mistakes_topic_check on public.mistakes;
create trigger mistakes_topic_check
  before insert or update on public.mistakes
  for each row
  execute function public.mistakes_topic_check();

-- ==================================== AI önbelleği taksonomi sürümüne bağlandı
-- `ai_cache_get/put` (0060) `(sha_hex, curriculum)` ile anahtarlıyordu.
-- Taksonomi değişince önbellekteki eski yanıt ARTIK VAR OLMAYAN bir konu adı
-- döndürüyor ve yukarıdaki doğrulama onu reddediyor — üstelik kullanıcı hiçbir
-- şey yapmadan. Sürüm anahtara giriyor; eski satırlar doğal olarak ıskalanıyor
-- (TTL 24 saat zaten var, ayrıca temizlik gerekmiyor).
alter table public.ai_result_cache
  add column if not exists taxonomy_version text not null default '';

-- Gövdeler 0060'ın AYNISI; değişen tek şey anahtara sürümün girmesi. Oturum
-- ve hash doğrulamaları AYNEN korunuyor — birini düşürmek sessiz bir gerileme
-- olurdu (bozuk hash "isabet yok"a değil hataya gitmeli, 0060'ın gerekçesi).
--
-- Birincil anahtar DEĞİŞMİYOR: sürüm bir SÜZGEÇ. Bayat sürümlü satır `get`
-- tarafından görülmüyor, `put` onu aynı anahtarla üzerine yazıyor. Ayrı bir
-- temizlik gerekmiyor; 48 saatlik prune işi zaten var.
drop function if exists public.ai_cache_get(text, text);
create or replace function public.ai_cache_get(
  p_sha_hex          text,
  p_curriculum       text,
  p_taxonomy_version text default ''
)
returns jsonb
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_out jsonb;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_sha_hex !~ '^[0-9a-f]{64}$' then
    raise exception 'gecersiz hash' using errcode = '22023';
  end if;

  select c.result into v_out
    from public.ai_result_cache c
   where c.user_id = v_uid
     and c.photo_sha256 = decode(p_sha_hex, 'hex')
     and c.curriculum = p_curriculum
     and c.taxonomy_version = p_taxonomy_version
     and c.created_at > now() - interval '24 hours';

  return v_out;
end
$fn$;

revoke execute on function public.ai_cache_get(text, text, text) from public, anon;
grant  execute on function public.ai_cache_get(text, text, text) to authenticated;

drop function if exists public.ai_cache_put(text, text, jsonb);
create or replace function public.ai_cache_put(
  p_sha_hex          text,
  p_curriculum       text,
  p_result           jsonb,
  p_taxonomy_version text default ''
)
returns void
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_sha_hex !~ '^[0-9a-f]{64}$' then
    raise exception 'gecersiz hash' using errcode = '22023';
  end if;

  insert into public.ai_result_cache
    (user_id, photo_sha256, curriculum, result, taxonomy_version)
  values (v_uid, decode(p_sha_hex, 'hex'), p_curriculum, p_result,
          p_taxonomy_version)
  on conflict (user_id, photo_sha256, curriculum) do update
     set result = excluded.result,
         taxonomy_version = excluded.taxonomy_version,
         created_at = now();
end
$fn$;

revoke execute on function public.ai_cache_put(text, text, jsonb, text)
  from public, anon;
grant  execute on function public.ai_cache_put(text, text, jsonb, text)
  to authenticated;
