-- 0069 — Ölü sütunlar düşüyor + kolon kilidi v5 + mistakes DELETE kapanıyor
--
-- 0026/0036/0047/0053/0064 ile aynı desen. NEDEN YENİ BİR GÖÇ: her lockdown
-- bloğu YALNIZCA kendi çalıştığı andaki katalogla karşılaştırma yapıyor
-- (0064:178-184'teki not).
--
-- v4'ten farklar:
--   profiles.exam_track       → SÜTUN DÜŞTÜ (ölü)
--   profiles.grade            → SÜTUN DÜŞTÜ (ölü)
--   profiles.display_name     → SÜTUN DÜŞTÜ (nickname ile çift kayıt)
--   mistakes.correct_answer   → SÜTUN DÜŞTÜ (ölü)
--   mistakes.review_count     → SÜTUN DÜŞTÜ (ölü)
--   mistakes                  → revoke_delete: true (tek silme kapısı artık
--                               `delete-question` edge function'ı)
--
-- ÖLÜ SÜTUN TESPİTİ NASIL YAPILDI: her aday için lib/ (Dart),
-- supabase/migrations (view / trigger / policy / function / index / grant) ve
-- supabase/functions tarandı; lockdown ve recheck listelerindeki adlar
-- SAYILMADI (orada olmak "kullanılıyor" demek değil, "sınıflandırıldı"
-- demek). Beşinin de lockdown dışında sıfır referansı çıktı.
--
-- KARŞI ÖRNEKLER (ölü SANILIP ölü ÇIKMAYANLAR, kayda geçsin):
--   profiles.dismissed_reports → moderation.sql:61,67,194 canlı kullanıyor
--   mistakes.photo_purged_at   → moderation_purge.sql kuyruk mantığı
--   mistakes.source*           → official_questions.sql (ÖSYM içe aktarımı)

-- ============================================ display_name yazan trigger önce
-- SIRA ÖNEMLİ: sütunu önce düşürürsek trigger çalışma anında patlar ve HİÇ
-- KİMSE kayıt olamaz. 0063'ün gövdesinin aynısı, yalnız display_name çifti
-- çıkarıldı. `is_anonymous` dalı ve `assign_friend_code` çağrısı AYNEN
-- korunuyor — ikincisi düşerse yeni kullanıcı arkadaş kodsuz doğar ve
-- arkadaş eklemenin tek yolu kapanır.
do $mig$
declare
  v_has_col boolean;
  v_expr    text;
begin
  select exists (
    select 1 from pg_attribute a
     where a.attrelid = 'auth.users'::regclass
       and a.attname = 'is_anonymous'
       and not a.attisdropped
  ) into v_has_col;

  v_expr := case when v_has_col
                 then 'coalesce(new.is_anonymous, false)'
                 else '(new.email is null)'
            end;

  if not v_has_col then
    raise warning
      'auth.users.is_anonymous yok; anonim tespiti e-posta yokluğuna göre '
      'yapılacak. Supabase sürümünüz anonim oturumu desteklemiyor olabilir.';
  end if;

  execute format($sql$
    create or replace function public.handle_new_user()
    returns trigger
    language plpgsql
    security definer set search_path = public
    as $fn$
    begin
      insert into public.profiles (id, nickname, is_anonymous)
      values (
        new.id,
        coalesce(new.raw_user_meta_data->>'nickname',
                 new.raw_user_meta_data->>'display_name', 'Öğrenci'),
        %s
      );

      perform public.assign_friend_code(new.id);
      return new;
    end
    $fn$;
  $sql$, v_expr);
end
$mig$;

-- `raw_user_meta_data->>'display_name'` OKUMA yedeği duruyor: eski hesapların
-- auth metadata'sında o alan var ve takma adı oradan kurtarmak ücretsiz.
-- Giden yalnızca profiles TABLOSUNDAKİ kopya.

-- ------------------------------------------------------------ sütunlar düşüyor
alter table public.profiles drop column if exists exam_track;
alter table public.profiles drop column if exists grade;
alter table public.profiles drop column if exists display_name;

alter table public.mistakes drop column if exists correct_answer;
alter table public.mistakes drop column if exists review_count;

-- ---------------------------------------------------------- kolon kilidi v5
do $mig$
declare
  v_cfg jsonb := $cfg$[
    {
      "table": "public.profiles",
      "insert": [],
      "update": ["avatar_path"],
      "locked": ["id","xp","streak","gems",
                 "last_activity_date","created_at","nickname","mascot",
                 "updated_at","weekly_xp","week_start","dismissed_reports",
                 "league","is_system","xp_today","xp_today_date",
                 "daily_goal_date","combo","combo_at","birth_year",
                 "friend_code","is_anonymous"]
    },
    {
      "table": "public.mistakes",
      "insert": ["subject","concept","mistake_type","note","photo_path","options",
                 "correct_index","exam","is_public","extra_concepts"],
      "update": ["subject","concept","mistake_type","note","options","correct_index",
                 "exam","extra_concepts","step","lapses","is_leech","mastered",
                 "next_review_date","next_review_at","last_reviewed_at"],
      "locked": ["id","user_id","created_at","moderation","report_count",
                 "solved_correct","solved_wrong","source","source_year",
                 "source_session","photo_purged_at","photo_scan","photo_scan_at"],
      "revoke_delete": true
    },
    {
      "table": "public.study_attempts",
      "insert": [],
      "update": [],
      "locked": ["id","user_id","subject","concept","exam","correct","source",
                 "created_at","mistake_id"],
      "revoke_delete": true
    },
    {
      "table": "public.question_attempts",
      "insert": [],
      "update": [],
      "locked": ["mistake_id","user_id","correct","created_at"],
      "revoke_delete": true
    },
    {
      "table": "public.question_sends",
      "insert": ["sender_id","receiver_id","mistake_id","note"],
      "update": [],
      "locked": ["id","created_at","solved_at","correct","dismissed_at"]
    },
    {
      "table": "public.friendships",
      "insert": ["requester_id","addressee_id","status"],
      "update": ["status"],
      "locked": ["created_at"]
    },
    {
      "table": "public.question_reports",
      "insert": ["mistake_id","reporter_id","reason","note"],
      "update": [],
      "locked": ["id","created_at","status","reviewed_at"]
    },
    {
      "table": "public.user_blocks",
      "insert": ["blocker_id","blocked_id"],
      "update": [],
      "locked": ["created_at"]
    },
    {
      "table": "public.rate_limits",
      "insert": [],
      "update": [],
      "locked": ["user_id","bucket","window_key","n","updated_at"],
      "revoke_delete": true
    },
    {
      "table": "public.user_sanctions",
      "insert": [],
      "update": [],
      "locked": ["id","user_id","action","until","reason_code","source",
                 "actor_id","note","voided_at","created_at"],
      "revoke_delete": true
    },
    {
      "table": "public.photo_violations",
      "insert": [],
      "update": [],
      "locked": ["id","user_id","mistake_id","strike_no","acknowledged_at",
                 "voided_at","created_at"],
      "revoke_delete": true
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

    -- (a) listede olup tabloda olmayan kolon → göç eskimiş
    select array_agg(distinct c) into v_bad
      from unnest(v_ins || v_upd || v_den) c where c <> all (v_all);
    if v_bad is not null then
      raise exception '%: listede olup tabloda olmayan kolon(lar): %', v_tbl, v_bad;
    end if;

    -- (b) tabloda olup hiçbir listede olmayan → sınıflandırılmamış kolon
    select array_agg(c) into v_bad
      from unnest(v_all) c where c <> all (v_ins || v_upd || v_den);
    if v_bad is not null then
      raise exception '%: sınıflandırılmamış kolon(lar): % — bu göçü güncelleyin',
                      v_tbl, v_bad;
    end if;

    -- (c) hem kilitli hem yazılabilir → çelişkili liste
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

-- `user_blocks` DELETE'i politikayla yönetiliyor (kendi engelini kaldırma).
grant select, delete on public.user_blocks to authenticated;

-- Sunucu-özel tablolar hiçbir uygulama rolüne açılmıyor.
revoke all on public.rate_limits      from public, anon, authenticated;
revoke all on public.user_sanctions   from public, anon, authenticated;
revoke all on public.photo_violations from public, anon, authenticated;

-- ------------------------------------------------------- mistakes DELETE kapısı
-- "Kendi hatanı sil" politikası (0001) DURUYOR ama tablo düzeyi DELETE yetkisi
-- gitti, yani istemcinin doğrudan silme yolu kapalı.
--
-- NEDEN: silme İKİ nesneye dokunuyor — satır ve depodaki dosya. İstemci satırı
-- silerse `photo_path` kaybolur ve dosya yetim kalır; "kaldırıldı gerçekten
-- kaldırır" değişmezi (Task 01) yalnız ikisi birlikte gittiğinde doğru. Tek
-- kapı `delete-question` edge function'ı: sahipliği doğruluyor, önce nesneyi
-- sonra satırı siliyor.
--
-- Politikanın kendisi DÜŞÜRÜLMÜYOR: definer yollar (admin_question_action,
-- delete-account) zaten RLS'i atlıyor; politikayı silmek katalogda "silme
-- hiç düşünülmemiş" izlenimi bırakırdı.
comment on table public.mistakes is
  'Kolon yazma izinleri lockdown göçlerinde beyaz listeyle yönetilir; en '
  'güncel liste 0069''dadır. İstemcinin DELETE yetkisi 0069''da geri alındı — '
  'tek silme kapısı delete-question edge function''ı (satır + depo nesnesi '
  'birlikte). Yeni kolon eklerseniz YENİ bir lockdown göçü yazın.';

comment on table public.profiles is
  'Kolon yazma izinleri lockdown göçlerinde beyaz listeyle yönetilir; en '
  'güncel liste 0069''dadır. İstemci yalnızca avatar_path yazabilir; '
  'nickname/mascot upsert_my_profile, XP/seri/kombo submit_* , doğum yılı '
  'set_birth_year, arkadaş kodu assign_friend_code üzerinden yazılır. Yeni '
  'kolon eklerseniz YENİ bir lockdown göçü yazın — eskisini güncellemek '
  'yetmez, çünkü o göç kendi zamanındaki katalogla karşılaştırma yapar.';
