-- 0090 — Kolon kilidi v9 (havuz kapanışı, question_sends DELETE, lig ve
--        ortak seri tabloları) — Task 13 · Paket 2
--
-- 0026/0036/0047/0053/0064/0069/0073/0077/0084 ile aynı desen. NEDEN YENİ BİR
-- GÖÇ: her lockdown bloğu YALNIZCA kendi çalıştığı andaki katalogla
-- karşılaştırma yapıyor. Eskisini güncellemek YETMEZ — (b) kontrolü
-- "sınıflandırılmamış kolon" diye patlar ve `db reset`i tümden kırar.
--
-- v8'den DÖRT fark:
--
-- 1) `public.mistakes.is_public` → KİLİTLİ (eskiden INSERT ile yazılabilirdi).
--
--    HAVUZ ARAYÜZDEN ÇIKTI (Task 02, `lib/_archive/`) ama SUNUCU AÇIK KALDI.
--    Kullanıcı doğrudan PostgREST ile `is_public = true` yazarak kendi soru
--    FOTOĞRAFINI takma adıyla birlikte TÜM oturumlu kullanıcılara açabiliyordu:
--    `public_questions` görünümü `is_public and moderation='ok' and
--    photo_scan='clear'` koşullarıyla herkese okunur ve `moderation`
--    varsayılanı `'ok'`; `can_read_mistake_photo` da `or m.is_public` dalını
--    taşıyor.
--
--    VE HİÇBİR ONAY KAYDI OLUŞMUYORDU: paylaşım onayını yazan `setShareConsent`
--    istemcide HİÇ çağrılmıyor, ayarlardaki anahtar kaldırılmış. Gizlilik
--    Politikası ise havuzu "şu an kullanımda değil" diye anlatıyor.
--
-- 2) `public.question_sends` → DELETE KAPALI.
--
--    `sends_delete_own` politikası 0008'den beri hem gönderene hem alıcıya
--    satır silme hakkı veriyordu ve hiçbir lockdown göçü bu tablo için
--    `revoke_delete` yazmamıştı. Bu, 0050a'nın "satır DURUYOR, moderasyon izi
--    kaybolmaz" değişmezini deliyordu: taciz eden bir gönderen, alıcı şikâyet
--    etmeden önce satırı silerse `report_received_question` "bu gönderim sana
--    ait değil" ile patlar ve şikâyet HİÇ açılamazdı.
--
--    İSTEMCİ BU YOLU KULLANMIYOR: `question_send_repository.dart` yalnızca
--    `dismiss_received_question` RPC'sini çağırıyor, hiçbir yerde `.delete()`
--    yok. Yani kapatmanın ürüne maliyeti sıfır.
--
-- 3) `public.pair_streaks` sözleşmeye girdi. 0084 ondan ÖNCE geldiği için
--    tablo hiçbir lockdown kapısından geçmemişti: ileride eklenecek bir sütun
--    sessizce sınıflandırılmamış kalırdı. Koruma bugün "politikasızlık +
--    revoke all" ile sağlanıyor; bu, onu sözleşmeye de yazıyor.
--
-- 4) `league_cohorts` / `league_members` aynı gerekçeyle sözleşmeye girdi —
--    0089 ikisine de yeni sütun ekledi (`week_start`, `move`,
--    `results_pushed_at`).
--
-- GERİ ALMA (havuz v2'de dönerse): `is_public`i `insert` listesine geri alan
-- bir lockdown v10 yazın ve `set_question_sharing` / `submit_pool_answer`
-- grant'larını geri verin. Tek göç; bkz. `lib/_archive/README.md`.

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
                 "friend_code","is_anonymous","premium_until"]
    },
    {
      "table": "public.mistakes",
      "insert": ["subject","concept","mistake_type","note","photo_path","options",
                 "correct_index","exam","extra_concepts"],
      "update": ["subject","concept","mistake_type","note","options","correct_index",
                 "exam","extra_concepts","step","lapses","is_leech","mastered",
                 "next_review_date","next_review_at","last_reviewed_at"],
      "locked": ["id","user_id","created_at","moderation","report_count",
                 "solved_correct","solved_wrong","source","source_year",
                 "source_session","photo_purged_at","photo_scan","photo_scan_at",
                 "curriculum","is_public"],
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
      "locked": ["id","created_at","solved_at","correct","dismissed_at"],
      "revoke_delete": true
    },
    {
      "table": "public.pair_streaks",
      "insert": [], "update": [],
      "locked": ["a_id","b_id","streak","best","last_day","started_at"],
      "revoke_delete": true
    },
    {
      "table": "public.league_cohorts",
      "insert": [], "update": [],
      "locked": ["id","tier","week_start","settled_at","created_at",
                 "results_pushed_at"],
      "revoke_delete": true
    },
    {
      "table": "public.league_members",
      "insert": [], "update": [],
      "locked": ["cohort_id","user_id","xp","week_start","move"],
      "revoke_delete": true
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
      "table": "public.ai_calls",
      "insert": [],
      "update": [],
      "locked": ["id","user_id","at","tier","photo_sha256","from_reward",
                 "refunded_at"],
      "revoke_delete": true
    },
    {
      "table": "public.ad_rewards",
      "insert": [],
      "update": [],
      "locked": ["id","user_id","nonce","status","transaction_id",
                 "created_at","granted_at","consumed_at"],
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
revoke all on public.ai_calls         from public, anon, authenticated;
revoke all on public.ad_rewards       from public, anon, authenticated;
revoke all on public.pair_streaks     from public, anon, authenticated;

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
  'güncel liste 0090''dadır. İstemcinin DELETE yetkisi 0069''da geri alındı — '
  'tek silme kapısı delete-question edge function''ı (satır + depo nesnesi '
  'birlikte). Yeni kolon eklerseniz YENİ bir lockdown göçü yazın.';

comment on table public.profiles is
  'Kolon yazma izinleri lockdown göçlerinde beyaz listeyle yönetilir; en '
  'güncel liste 0090''dadır. İstemci yalnızca avatar_path yazabilir; '
  'nickname/mascot upsert_my_profile, XP/seri/kombo submit_* , doğum yılı '
  'set_birth_year, arkadaş kodu assign_friend_code üzerinden yazılır. Yeni '
  'kolon eklerseniz YENİ bir lockdown göçü yazın — eskisini güncellemek '
  'yetmez, çünkü o göç kendi zamanındaki katalogla karşılaştırma yapar.';
