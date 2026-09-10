-- 0064 — Kolon kilitlemesi v4 (Task 07 kolonları sınıflandırıldı)
--
-- 0036/0047/0053 ile aynı desen. NEDEN YENİ BİR GÖÇ: her lockdown bloğu
-- YALNIZCA kendi çalıştığı andaki katalogla karşılaştırma yapıyor. Daha sonra
-- eklenen bir tablo/sütun 0053 koşarken henüz yok; kilit yine de geçerli
-- (varsayılan reddet) ama hata göç zamanında değil ÇALIŞMA ANINDA sessiz bir
-- 42501 olarak beliriyor. Bu yüzden her paket kendi lockdown bloğunu yazıyor.
--
-- v3'ten farklar:
--   profiles.guardian_email      → SÜTUN DÜŞTÜ (0063)
--   public.guardian_requests     → TABLO DÜŞTÜ (0063)
--   public.user_sanctions        → YENİ, tamamı kilitli (0062)
--   public.photo_violations      → YENİ, tamamı kilitli (0062)
--
-- İki yeni tablo tamamen kilitli: `acknowledged_at` bile istemciden
-- yazılmıyor, `ack_photo_warnings()` definer fonksiyonundan geçiyor. Kilit
-- modelinin gerekçesi: kullanıcı kendi ihlal sayacına ya da askı kaydına
-- HİÇBİR biçimde dokunamamalı.
--
-- KAPSAM DIŞI, bilinçli: `ai_result_cache` ve `signup_throttle` (Task 06)
-- sınıflandırma döngüsünde değil. İkisi de `revoke all` ile tamamen kapalı ve
-- aşağıdaki "yalnızca-sunucu" bloğu + 0065'in kapısı onları ayrıca doğruluyor.

do $mig$
declare
  v_cfg jsonb := $cfg$[
    {
      "table": "public.profiles",
      "insert": [],
      "update": ["avatar_path"],
      "locked": ["id","display_name","exam_track","grade","xp","streak","gems",
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
                 "source_session","correct_answer","review_count",
                 "photo_purged_at","photo_scan","photo_scan_at"]
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

comment on table public.profiles is
  'Kolon yazma izinleri lockdown göçlerinde beyaz listeyle yönetilir; en '
  'güncel liste 0064''tedir. İstemci yalnızca avatar_path yazabilir; '
  'nickname/mascot upsert_my_profile, XP/seri/kombo submit_* , doğum yılı '
  'set_birth_year, arkadaş kodu assign_friend_code üzerinden yazılır. Yeni '
  'kolon eklerseniz YENİ bir lockdown göçü yazın — eskisini güncellemek '
  'yetmez, çünkü o göç kendi zamanındaki katalogla karşılaştırma yapar.';
