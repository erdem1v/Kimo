-- 0036 — XP / seri / cevap sütunlarının kilitlenmesi (E4)
--
-- 0026 bu sütunları BİLEREK açık bırakmıştı: istemci onlara yazıyordu ve
-- RPC'ler henüz yoktu. 0034 RPC'leri ekledi, istemci onlara geçti; artık
-- kilitleniyorlar.
--
-- Kapanan saldırılar:
--   • update profiles set xp = 999999            → lig ve skor tablosu sahteciliği
--   • update profiles set weekly_xp = 999999     → grup sıralaması (trigger üzerinden)
--   • update profiles set streak = 365           → sahte seri + arkadaşlara bildirim
--   • insert into study_attempts (correct=true)  → uydurma konu haritası
--   • insert into question_attempts (correct)    → başkasının sorusunun istatistiği
--   • update question_sends set correct          → sahte çözüm kaydı
--   • update mistakes set is_public = true       → paylaşımın RPC dışı açılması
--
-- Bundan sonra `profiles` üzerinde istemcinin yazabildiği TEK sütun avatar_path
-- (ve o da CHECK kısıtıyla kendi klasörüne hapsedilmiş). nickname/mascot
-- upsert_my_profile RPC'sinden geçiyor — orada doğrulama da yapılıyor.
--
-- GERİ ALMA: 0026'daki liste. Uygulamadan önce mevcut ACL'i kaydedin.

do $mig$
declare
  v_cfg jsonb := $cfg$[
    {
      "table": "public.profiles",
      "insert": [],
      "update": ["avatar_path"],
      "locked": ["id","display_name","exam_track","grade","is_minor",
                 "guardian_consent","xp","streak","hearts","gems",
                 "last_activity_date","created_at","nickname","mascot",
                 "updated_at","weekly_xp","week_start","dismissed_reports",
                 "league","is_system","xp_today","xp_today_date",
                 "daily_goal_date"]
    },
    {
      "table": "public.mistakes",
      "insert": ["subject","concept","mistake_type","note","photo_path","options",
                 "correct_index","exam","is_public","extra_concepts"],
      "update": ["subject","concept","mistake_type","note","options","correct_index",
                 "exam","extra_concepts","step","lapses","is_leech","mastered",
                 "next_review_date","last_reviewed_at"],
      "locked": ["id","user_id","created_at","moderation","report_count",
                 "solved_correct","solved_wrong","source","source_year",
                 "source_session","correct_answer","review_count",
                 "photo_purged_at"]
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
      "locked": ["id","created_at","solved_at","correct"]
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

    select array_agg(distinct c) into v_bad
      from unnest(v_ins || v_upd || v_den) c where c <> all (v_all);
    if v_bad is not null then
      raise exception '%: listede olup tabloda olmayan kolon(lar): %', v_tbl, v_bad;
    end if;

    select array_agg(c) into v_bad
      from unnest(v_all) c where c <> all (v_ins || v_upd || v_den);
    if v_bad is not null then
      raise exception '%: sınıflandırılmamış kolon(lar): % — bu göçü güncelleyin',
                      v_tbl, v_bad;
    end if;

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
  'Kolon yazma izinleri 0036 göçünde beyaz listeyle yönetilir. İstemci yalnızca '
  'avatar_path yazabilir; nickname/mascot upsert_my_profile RPC''sinden, XP ve '
  'seri submit_* RPC''lerinden geçer. Yeni kolon eklerseniz o göçteki listeye de '
  'ekleyin, yoksa göç "sınıflandırılmamış kolon" diye patlar.';
