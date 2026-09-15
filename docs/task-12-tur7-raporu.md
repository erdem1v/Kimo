# Task 12 — Tur 7 paketi (bayraklar, gönderim, iade, ortak seri)

> **Bu rapor geriye dönük yazıldı.** Task 12'nin kodu çalışma ağacında
> commit edilmemiş hâlde duruyordu ve raporu yoktu; Task 13'ün ön koşul
> denetimi sırasında yedi kırık nokta bulundu. Rapor, paketin ne getirdiğini ve
> o yedi noktanın nasıl kapatıldığını kaydediyor.

**Dayanak:** `d451e4b` (Task 11) üstüne. **Göçler:** 0079-0087 (dokuz dosya).

---

## 1. Ne getirdi

| Paket | İş | Göç |
|---|---|---|
| P0 | **Uzaktan özellik bayrakları.** `app_config` → `config_bool()` → `feature_flags()` → `my_daily_state` → `DailyState` üç durumlu okuyucu. Üç bayrak: `ff_pair_streak` (varsayılan **false**), `ff_multi_capture`, `ff_ad_reward` | 0079 |
| P4 | **Soru gönderme kapıları.** Not 250 karakter, günlük tavan, arkadaş başına tavan, aynı soruyu tekrar gönderme yasağı, tek çağrıda çoklu gönderim (`send_question_to_friends`), gelen kutusunda gönderen avatarı | 0081 |
| P5 | **Hak iadesi.** Okunamayan fotoğraf hak harcamıyor: `ai_calls.refunded_at` (satır **silinmiyor**, maliyet defteri korunuyor) | 0083, 0084 |
| P6 | **Ortak seri** (`pair_streaks`). İki arkadaşın birlikte sürdürdüğü seri; küçükler için **varsayılan kapalı** (DSA Md. 28(1) Kılavuzu, 14 Temmuz 2025, par. 57(b)(viii)) | 0086 |
| — | Çoklu çekim ekranları (`batch_capture_screen`, `batch_result_screen`), gönderim ve ortak seri akışları | — |
| — | Dört yetki kapısı (`function_grants_recheck12-15`) | 0080, 0082, 0085, 0087 |

Ayrıca: iki yeni pgTAP dosyası (`310_feature_flags`, `320_pair_streaks`), altı
yeni mutasyon (`37`-`42`), dört yeni istemci ekranı/akışı ve beş yeni Dart testi.

---

## 2. Bulunan yedi kırık nokta ve onarımı

**Ortak nedeni tek: paket hiç koşturulmadı.** Bu makinede `docker`, `psql`,
`supabase` CLI ve `flutter` yok; `supabase db reset` bir kez denenmiş olsaydı
§2.1 ilk saniyede düşerdi.

Dördü tek bir fonksiyon yeniden yazımından çıktı ve o dosya kendi hakkında
şunu yazıyordu: *"Gövde 0075'ten **BİREBİR kopyalandı**; başka hiçbir satır
değişmedi."* (`0083:57`) — bu cümle doğru değildi.

### 2.1 `ai_state()` OUT sütun sırası → `db reset` patlıyordu

0075 `(ai_tier, ai_state, …)`, 0083 `(ai_state, ai_tier, …)`. PostgreSQL
`create or replace` ile OUT parametrelerinin tanımladığı satır tipini (ad **ve
sıra** dahil) değiştirmeye izin vermiyor:
`cannot change return type of existing function`.

**Onarım:** sıra 0075'teki hâline döndürüldü. `drop` gerekmedi —
`my_daily_state` sütunları **ada göre** seçiyor. Aynı dosya bu kuralı yirmi
satır aşağıda `consume_ai_use` için zaten doğru uyguluyordu (`drop + create`).

### 2.2 `ad_rewards_left` atanmıyordu → ödüllü reklam arayüzde ölüydü

0075 üç yerde atıyordu (anonim→0, premium→0, ücretsiz→hesap); 0083'te yalnızca
anonim dalı kalmıştı. Ücretsiz/premium dalında **NULL** → `ad_offer` NULL →
`credit_wall_screen`'in `_showAdRow`'u hiçbir zaman `true` olmuyordu. Üstelik
`_promote` her zaman true olup ilk çarpmada Plus kartını açıyordu.

**Sonuç:** Task 10'un bütün ödüllü reklam yatırımı sessizce devre dışıydı.
**Onarım:** 0075'in bloğu geri kondu.

### 2.3 `ai_next_at` sıfırlama bloğu düşmüştü

`ai_state in ('month_full','lifetime_full','suspended')` iken pencere saati
gösterilmez (ürün kuralı). Blok 0083'e taşınmamıştı; `my_daily_state` yorumu ve
`DailyState.aiNextAtHm` dokümanı hâlâ "sunucu bunu null yapıyor" diyordu.
**Onarım:** blok geri kondu.

### 2.4 `refund_ai_use`'un tavanı istemciden kapatılabiliyordu

`refund_ai_use(p_call_id bigint, p_capped boolean default true)` fonksiyonu
`authenticated`'a açıktı ve `p_capped` **tamamen istemcinin elindeydi**.
PostgREST'e `{"p_capped": false}` gönderen bir istemci `ai_refund_daily`
tavanını atlayıp kendi bütün çağrılarını iade edebiliyordu. İade edilen satır
`refunded_at is null` süzgeci yüzünden hem kayan pencereden hem **aylık
cap**'ten düştüğü için sonuç şuydu: OpenAI çağrısı yapıldıktan **sonra** kota
geri veriliyor — yani sert maliyet tavanı diye bir şey kalmıyordu.

**Onarım — iki ayrı yüzey (`grant_ad_reward`/0076 deseninin aynısı):**

| Yüzey | Kim çağırır | Tavan |
|---|---|---|
| `refund_ai_use(bigint)` | `authenticated` (edge fonksiyon kullanıcının JWT'siyle) | **her zaman** |
| `refund_ai_use_infra(text, bigint)` | yalnızca `anon`, paylaşılan sırla | yok |

"Bu bizim hatamızdı" diyebilecek tek taraf sunucu; sır onu kanıtlıyor.
Kullanıcı kimliği parametre **değil** — `ai_calls` satırı zaten `user_id`
taşıyor (Task 01'in "hiçbir RPC `user_id` parametresi almaz" değişmezi).

**Sır:** `app_config.ai_refund_secret` + edge gizlisi `AI_REFUND_SECRET`.
Tohumlanmıyor; yoksa iade **verilmiyor** (fail-closed) ve günlüğe yazılıyor.

### 2.5 `send_question_to_friends` RLS'i atlıyordu

Fonksiyon `security definer`, yani `question_sends` ve `mistakes` üzerindeki
RLS **değerlendirilmiyor**. Yorumu tersini iddia ediyordu:

> *"RLS BURADA ATLANMIYOR … politikanın kendisini çalıştırıyoruz."*

Depo bu gerçeği başka iki yerde zaten yazıyor (`0062:517`, `0063:79-81`) ve
hiçbir yerde `force row level security` yok. Sonuç: politikanın **altı koşulu**
(arkadaşlık, engel, askı, anonimlik, satırın **sahipliği**, moderasyon/tarama)
hiç çalışmıyordu ve `exception when insufficient_privilege` dalı ateşlenemezdi.

**En ağırı sahiplik:** `p_mistake` keyfi bir uuid — kullanıcı **başkasının**
(ya da moderasyonda işaretlenmiş, ya da taraması bitmemiş) bir hata satırını
arkadaşlarına gönderebiliyordu.

**Onarım:** altı koşul gövdede açıkça tekrarlandı — `add_friend_by_code`'un
aynı sorunu çözdüğü yol. Gönderen tarafı üç koşul döngünün dışında (alıcı
değiştikçe değişmiyorlar), alıcı tarafı iki koşul döngü içinde.

### 2.6 `received_questions` görünümü → `db reset` patlıyordu

`create or replace view` yalnızca listenin **sonuna** sütun eklemeye izin
veriyor; `sender_avatar_path` 5. sıraya, `note`'un yerine giriyordu:
`cannot change name of view column "note" to "sender_avatar_path"`.

**Onarım:** `drop view` + `create view` + grant'ların yeniden yazılması
(0079'un `my_daily_state` için yazdığı ders).

### 2.7 `mutations/36` bayatlamıştı → mutasyon koşusu duruyordu

Mutasyon 36 hem gövdesinde hem `@UNDO`'sunda `ai_state()`'i **Task 12 öncesi**
hâliyle kuruyordu: dosyada `refunded_at` hiç geçmiyordu. `100_ai_quota.sql`'in
üç yeni iade iddiası doğrudan `ai_state()` okuduğu için `@UNDO`'dan sonra da
kırmızı kalıyor, `tools/mutation_check.sh` FAZ 3'te `exit 1` ile **tüm koşuyu**
durduruyordu.

**Onarım:** iki gövde de 0083'ün nihai gövdesinden **yeniden üretildi**.

---

## 3. Eklenen korumalar

| Ne | Nerede |
|---|---|
| `refund_ai_use` tek aşırı yükleme; tavanı kaldıran parametre yok | `100_ai_quota.sql` |
| `refund_ai_use_infra` `authenticated`'a kapalı, yalnızca `anon` | `100_ai_quota.sql` + `recheck15` `v_anon_only` |
| Doğru sırla altyapı iadesi çalışıyor (aşırı kilitleme karşı-iddiası) | `100_ai_quota.sql` |
| Sır girilmemişse iade verilmiyor (fail-closed) | `100_ai_quota.sql` |
| Başkasının sorusu gönderilemiyor; red sebebi `not_sendable` | `085_question_sends.sql` |
| Mutasyon: gönderimden sahiplik koşulu sökülürse 085 kırmızı | `mutations/43` |
| Mutasyon: tavansız iade istemciye açılırsa 100 kırmızı | `mutations/44` |

**Ve yeni bir kalıcı kapı:** `tools/check_sql.py` artık iki hata sınıfını
statik olarak yakalıyor —

5. `create or replace function` ile OUT sütun listesini değiştiren göçler,
6. `create or replace view` ile sütun listesinin ortasına ekleyen göçler.

Kapı, düzeltme öncesi ağaca karşı koşturularak **ikisini de yakaladığı
doğrulandı**; düzeltilmiş ağaçta temiz. Bu hata sınıfı depoda dört kez yaşandı
(0014/0015, 0016/0024, ve Task 12'de iki kez) — artık `ci.yml`'in `static` işi
onu Docker'sız yakalıyor.

---

## 4. Bayrak × özellik matrisi (devralınan durum)

| Bayrak | Varsayılan | Gerçekten kapatıyor mu |
|---|---|---|
| `ff_multi_capture` | `true` | ✅ evet (`capture_screen.dart:462`) |
| `ff_pair_streak` | `false` | ⚠️ yalnızca **arayüzü**. Sunucudaki `start_pair_streak`/`leave_pair_streak` bayraktan bağımsız açık; `pair-streak-daily` cron'u kapalıyken de serileri ilerletiyor |
| `ff_ad_reward` | `true` | ❌ **hayır.** `DailyState.adRewardEnabled`'ın üretim kodunda tek çağıranı yok — `app_config`'e `false` yazmak hiçbir şeyi değiştirmiyor |

**Geri alma reçetesi:** `delete from public.app_config where key like 'ff\_%';`
(varsayılanlar `feature_flags()` gövdesinde, göç gerekmiyor.)

> `ff_pair_streak` ve `ff_ad_reward`'ın sunucuya indirilmesi **Task 13'e**
> bırakıldı; bu paketin kapsamı yedi kırık noktanın kapatılmasıydı.

---

## 5. Doğrulanmayanlar

| İş | Sebep |
|---|---|
| pgTAP süiti (`supabase test db`) | Bu makinede **Docker/psql/Supabase CLI yok** — yalnızca CI |
| Mutasyon kontrolü | Aynı |
| `flutter analyze` / `flutter test` | Bu makinede **Flutter yok** — yalnızca CI |
| Ortak seri, çoklu çekim, gönderim akışlarının arayüzü | Derleme yapılamadı |
| Altyapı iadesi yolu (`refund_ai_use_infra`) | `ai_refund_secret` girilmedi; uçtan uca hiç koşmadı |

**Yerelde koşan ve temiz geçen tek kapı:** `python3 tools/check_sql.py`
(93 göç, 0 sorun) ile `check_symbols.py`, `check_imports.py`,
`build_taxonomy.py --check` ve CI'ın dört metin kapısı.

---

## 6. Dağıtımda atlanırsa sessizce çalışmayacak adımlar

1. **`ai_refund_secret`** — `app_config`'e ve edge gizlisine **aynı** değer:
   ```sql
   insert into public.app_config (key, value)
   values ('ai_refund_secret', '<uzun rastgele dize>')
   on conflict (key) do update set value = excluded.value;
   ```
   ```bash
   supabase secrets set AI_REFUND_SECRET='<aynı dize>'
   supabase functions deploy analyze-question
   ```
   Girilmezse altyapı kaynaklı iadeler **hiç verilmez** (kullanıcı hakkını
   kaybeder). Günlüğe yazılıyor, sessiz değil.
2. **Görünüm + istemci birlikte** dağıtılmalı: `my_daily_state` ve
   `received_questions` sütun kazandı.
3. `ff_*` anahtarları `app_config`'te yoksa `feature_flags()` varsayılanlara
   düşer — `ff_pair_streak` **kapalı** doğar.
