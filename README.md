# AI YKS Coach

YKS'ye hazırlanan lise öğrencileri için Türkçe bir **AI koçluk ve sınav
hazırlık** uygulaması. Uygulamanın kalbi şu döngüdür:

> Öğrenci bir soruyu yanlış çözer → hata **hata bankasına** kaydedilir →
> **aralıklı tekrar (spaced repetition)** ile zaman içinde tekrar tekrar
> sorulur → tüm döngü **Duolingo tarzı oyunlaştırma** (can, XP, seri, lig,
> rozet) ile sarmalanır.

Arayüz, AI yanıtları ve bildirimler **%100 Türkçe**dir. Başka dil şimdilik
planlanmıyor; yine de metinler `.arb` dosyaları üzerinden yönetilir.

---

## Teknik yığın (stack)

| Katman | Seçim |
| --- | --- |
| Framework | Flutter (stable, Android/iOS/Web) |
| State management | Riverpod (v3) |
| Veri modelleri | Freezed + json_serializable |
| Yerel veritabanı | drift (SQL) — *bağımlılık eklendi, kalıcı katman sonraki fazda* |
| Lokalizasyon | flutter_localizations + gen_l10n (`.arb`) |
| Backend | **Şimdilik yok — tamamen yerel.** İleride Supabase düşünülüyor |

> **Not:** AI çağrıları hiçbir zaman istemciden doğrudan yapılmaz ve API
> anahtarı asla istemci kodunda bulunmaz. Backend eklendiğinde çağrılar
> sunucu tarafı bir "AI Gateway" üzerinden geçer.

## Klasör yapısı

Feature-first; her özellik altında `data / domain / presentation` ayrımı:

```
lib/
  core/            # tema, sabitler, yardımcılar, lokalizasyon
  features/
    auth/ onboarding/ mistake_bank/
    spaced_repetition/   # SM-2 scheduler + "Bugünün Tekrarları" ekranı  ✅ (MVP)
    question_bank/ gamification/ coach_chat/
    progress_dashboard/ notifications/
  shared/
    models/        # Student, Question, Mistake, ReviewSchedule, GamificationState
    widgets/       # ör. Tip A şekil çizimi (CustomPainter)
  main.dart / app.dart
```

## Kurulum

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build
flutter run
```

### ⚠️ Kod üretimi (build_runner) hakkında önemli not

Bu makinedeki kullanıcı yolu Türkçe karakter (`ö`) içerdiğinden, Dart'ın
AOT snapshot yazıcısı `build_runner`'ı doğrudan çalıştırırken hata veriyor
(`Unable to write file ... build.dart.aot`). Geçici çözüm: projeye **ASCII
bir junction** üzerinden erişip codegen'i oradan çalıştırın:

```bash
# Yönetici GEREKMEZ:
cmd /c mklink /J C:\aiyks "C:\Users\Taha Karagöz\Desktop\aiykscoach"
cd C:\aiyks
dart run build_runner build
```

Üretilen dosyalar gerçek proje klasörüne yazılır (junction aynı yeri gösterir).
`flutter test`, `flutter run`, `dart analyze` gerçek yoldan sorunsuz çalışır;
yalnızca `build_runner` bu junction'a ihtiyaç duyar.

> `flutter` PowerShell'de PATH'te değilse: `C:\src\flutter\bin` klasörünü
> kullanıcı PATH'ine ekleyin ve terminali/uygulamayı yeniden başlatın. Ayrıca
> `git` PATH'te olmalıdır (`C:\Program Files\Git\cmd`).

## Test

```bash
flutter test
```

- `SpacedRepetitionScheduler` için saf birim testleri
  (`test/features/spaced_repetition/...`).
- "Bugünün Tekrarları" ekranı için widget testi (`test/widget_test.dart`).

## Veritabanı ve güvenlik testleri

Şema `supabase/migrations/` altında, zaman damgalı dosyalar hâlinde ve sırayla
uygulanır. Temel şema `20240101000000_init.sql` (eskiden `supabase/schema.sql`
idi ve `migrations/` dışında olduğu için `supabase db reset` tarafından hiç
uygulanmıyordu).

### Yerel yığın + pgTAP

```bash
npm install supabase --save-dev        # Docker Desktop (WSL2) gerekir
npx supabase start                     # -x storage-api KULLANMAYIN:
                                       # storage.objects şeması o konteynerden gelir
npx supabase db reset                  # göçler + seed.sql (pgTAP + tests.* yardımcıları)
npx supabase test db                   # supabase/tests/ altındaki pgTAP süiti
```

`db reset` çıktısında **`skipped` satırı olmamalı.** Supabase CLI, adı
`<14 haneli zaman damgası>_ad.sql` biçimine uymayan göçleri atlar ve yine de
0 çıkış kodu döndürür — yani boş bir veritabanına karşı yeşil test alabilirsiniz.

### ⚠️ Üretime uygulama

Göçler tarihsel olarak **elle SQL Editor'a yapıştırılarak** uygulandı, yani
`supabase_migrations.schema_migrations` tablosu üretimde muhtemelen boş.
**`supabase db push` üretime karşı ÇALIŞTIRILMAMALI** — her şeyi baştan
uygulamaya kalkar. `db reset` yalnızca yerel/test veritabanı içindir.

### Edge function'lar

JWT doğrulaması artık `supabase/config.toml` içinde beyan ediliyor
(`[functions.send-push] verify_jwt = true`), yani dağıtım bayrak gerektirmez:

```bash
supabase functions deploy send-push
supabase functions deploy analyze-question
```

`send-push` çalışmadan önce `app_config` doldurulmalı:

```sql
insert into public.app_config (key, value) values
  ('push_url',         '<edge function adresi>'),
  ('push_service_key', '<SUPABASE_SERVICE_ROLE_KEY>')
on conflict (key) do update set value = excluded.value;
delete from public.app_config where key = 'push_secret';   -- artık kullanılmıyor
```

## Aralıklı tekrar (SM-2)

`SpacedRepetitionScheduler` **saf Dart** bir sınıftır (UI/DB bağımsız,
kolayca test edilebilir):

- Öğrenme adımları: **1 → 3 → 7 → 14 → 30** gün, sonrası `easeFactor` ile
  çarpımsal büyür.
- `easeFactor` başlangıç **2.5**, alt sınır **1.3**.
- Yanlış cevap: seri sıfırlanır, aralık 1 güne döner.

## Güvenlik ve gizlilik (reşit olmayan kullanıcılar)

- Kullanıcı kitlesi ağırlıkla 14–18 yaş. Kayıt akışına **yaş/veli onayı**
  adımı baştan tasarlanacaktır (UI iskeleti sonraki fazda).
- Gereksiz kişisel veri (konum, kişi listesi vb.) toplanmaz.
- Sırlar `.env` ile yönetilir ve `.gitignore`'dadır; `.env.example`'a bakın.

> ⚖️ **Yasal uyarı:** Tam **KVKK uyumluluğu** ayrı bir hukuki inceleme
> gerektirir; bu depo teknik iskeleti sağlar, hukuki uygunluğu garanti etmez.

## Yol haritası (özet)

- [x] Proje iskeleti, SM-2 scheduler + testler, veri modelleri
- [x] "Bugünün Tekrarları" ekranı (mock veri)
- [ ] drift kalıcı katmanı + hata bankası
- [ ] Oyunlaştırma modülü (kalıcı can/XP/seri/lig/rozet)
- [ ] Tip A şekil kütüphanesinin genişletilmesi, statik soru bankası
- [ ] Onboarding + yaş/veli onayı, AI koçluk sohbeti (sunucu gateway ile)
