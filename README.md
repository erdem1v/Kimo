# Kimo

YKS'ye hazırlanan lise öğrencileri için Türkçe bir **hata arşivi ve aralıklı
tekrar** uygulaması. Uygulamanın kalbi şu döngüdür:

> Öğrenci bir soruyu yanlış çözer → fotoğrafı çekilir, yapay zekâ soruyu
> okur → hata **hata bankasına** kaydedilir → **aralıklı tekrar** ile zaman
> içinde tekrar tekrar sorulur → tüm döngü **oyunlaştırma** (XP, seri, lig,
> analiz hakkı) ile sarmalanır.

Arayüz, AI yanıtları ve bildirimler **%100 Türkçe**dir. Başka dil planlanmıyor;
yine de metinler `.arb` dosyaları üzerinden yönetilir.

---

## Teknik yığın

| Katman | Seçim |
| --- | --- |
| Framework | Flutter (stable, Android/iOS) |
| Durum yönetimi | **Kod üretimi ve DI çerçevesi YOK.** `ChangeNotifier` / `ValueListenable` ve dosya sonundaki singleton depolar (`lib/data/`, `lib/state/`) |
| Veri modelleri | Elle yazılmış saf Dart sınıfları (`lib/models/`). `fromRow` haritalayıcıları elle yazılır |
| Arka uç | **Supabase** — Postgres + RLS, Edge Functions (Deno), Storage, Auth |
| Yerel kalıcılık | `shared_preferences` (üstveri) + `path_provider` (fotoğraf baytları) |
| Lokalizasyon | `flutter_localizations` + `gen_l10n` (`lib/l10n/app_tr.arb`) |
| Bildirim | `flutter_local_notifications` (cihazda) + FCM (sunucudan) |
| Reklam | AdMob, **yalnızca ödüllü** — banner/interstitial/açılış YOK |
| Çökme raporlama | Sentry |

> **Not:** AI çağrıları hiçbir zaman istemciden doğrudan yapılmaz ve sağlayıcı
> anahtarı asla istemci kodunda bulunmaz. Çağrılar `analyze-question` Edge
> Function'ı üzerinden geçer; anahtar yalnızca Supabase fonksiyon ortamındadır.

### Neden kod üretimi yok

`build_runner`, `freezed`, `json_serializable` ve `drift` bu depoda **yoktur**.
README uzun süre bunların kullanıldığını yazıyordu ve bu yanlıştı; Task 13'te
düzeltildi. Üretilen tek dosya `gen_l10n` çıktısı ve o da depoya işleniyor.

## Klasör yapısı

```
lib/
  main.dart · app.dart
  data/        # Supabase depoları, kuyruklar (fotoğraf, gönderim)
  features/    # admin auth capture credit home inbox league mistakes
               # onboarding plus practice profile reviews settings social
  l10n/        # app_tr.arb + üretilen AppLocalizations
  models/      # saf Dart modeller
  services/    # bildirim, push, ses, reklam, satın alma, hukuki bağlantılar
  state/       # uygulama ayarları, kullanıcı profili, özellik bayrakları
  theme/       # tasarım token'ları ve tipografi
  widgets/     # Kimo maskotu (CustomPainter) ve tasarım kiti
  _archive/    # ARŞİV: havuz (ortak soru havuzu) ekranları. Analizden hariç,
               # canlı koddan import EDİLMİYOR. Sunucu yüzeyi Task 13'te
               # kapatıldı; geri açma reçetesi lib/_archive/README.md'de.
supabase/
  migrations/  # 101 zaman damgalı göç — şemanın tek kaynağı
  functions/   # 10 Edge Function (+ _shared)
  tests/       # 37 pgTAP dosyası, 831 iddia
  mutations/   # 55 mutasyon: her korumanın testi GERÇEKTEN ayırt ediyor mu
tools/         # Docker'sız çalışan statik kapılar (aşağıda)
```

## Kurulum

```bash
flutter pub get
cp supabase.example.json supabase.json     # değerleri doldurun
flutter run --dart-define-from-file=supabase.json
```

**`supabase.json` ZORUNLUDUR.** Yoksa uygulama açılmaz: `main.dart` eksik
yapılandırmayı anlatan bir hata ekranı gösterip çıkar (`ConfigErrorApp`).
Eskiden bir "demo/mock modu" vardı; **Task 03'te kaldırıldı.**

`.arb` dosyasını düzenledikten sonra `flutter gen-l10n` çalıştırın ve üretilen
dosyayı commit'leyin.

## Test

```bash
flutter test
```

### Statik kapılar (Docker'sız, saniyeler)

Geliştirme makinesinde Flutter ya da Docker olmayabilir; bu betikler oradaki
tek geri bildirim yolu ve CI'da da koşuyorlar.

```bash
python3 tools/check_workflows.py    # is akışı dosyaları AYRIŞTIRILABİLİR mi
python3 tools/check_sql.py          # göç dengesi, plan(n), yetki, OUT sütunu
python3 tools/check_symbols.py      # tasarım token'ı / kit sembolleri
python3 tools/check_imports.py      # eksik/kullanılmayan import
python3 tools/build_taxonomy.py --check
```

Her betiğin bir `--selftest`i var: uydurma bir ihlali yakalayamazsa kırmızı
döner. Bu depoda bir denetleyici **iki kez** sessizce hiçbir şey bulmama
hatasına düştü; selftest o dersin karşılığı.

> `tools/check_workflows.py` Task 13'te eklendi. `ci.yml` Task 10'dan Task
> 13'e kadar **geçersiz YAML** idi ve GitHub onu hiç koşturmadı — yani pgTAP,
> mutasyon ve `flutter test` o aralıkta hiç çalışmadı.

## Veritabanı ve güvenlik testleri

Şema `supabase/migrations/` altında, zaman damgalı dosyalar hâlinde ve sırayla
uygulanır.

```bash
npm install supabase --save-dev        # Docker gerekir
npx supabase start                     # -x storage-api KULLANMAYIN:
                                       # storage.objects şeması o konteynerden gelir
npx supabase db reset                  # göçler + seed.sql (pgTAP + tests.* yardımcıları)
npx supabase test db                   # pgTAP süiti
bash tools/mutation_check.sh           # testler gerçekten ayırt ediyor mu
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

JWT doğrulaması `supabase/config.toml` içinde beyan ediliyor, yani dağıtım
bayrak gerektirmez:

```bash
supabase functions deploy analyze-question send-push scan-photos \
  delete-account delete-question cleanup-anonymous ad-reward \
  verify-purchase store-notify reconcile-subscriptions
```

`verify_jwt = false` olan **yalnızca iki** fonksiyon var — `ad-reward` ve
`store-notify` — ve ikisi de kullanıcı JWT'si taşımayan bir dış geri çağrıdan
besleniyor. **Hiçbir doğrulamasız fonksiyon servis rolü istemcisi kurmaz.**

Sırlar ve kurulum adımları için `docs/task-13-kapanis-raporu.md`.

## Aralıklı tekrar

`ReviewScheduler` **saf Dart** bir sınıftır (UI/DB bağımsız, kolayca test
edilebilir) — `lib/features/reviews/domain/review_scheduler.dart`:

- Öğrenme adımları: **1 → 3 → 7 → 30** gün.
- Son adımdan sonra soru kuyruğu TERK ETMEZ: **45 gün** arayla seyrek döner.
- `lapses >= 4` → `isLeech` ("kavramı baştan çalış" sinyali).
- Yanlış cevap adımı geri alır.

SM-2 **değil**: `easeFactor` diye bir kavram yok. FSRS değerlendirmesi kapsam
dışı.

## Güvenlik ve gizlilik (reşit olmayan kullanıcılar)

- **Uygulama 13 yaş ve üzeri içindir** ve bu sınır kodda zorlanır: 13 yaşından
  küçük bir doğum yılı `KM013` ile reddedilir.
- **Veli onayı mekanizması YOKTUR** (Task 07'de kaldırıldı). 13–17 yaş için
  hukuken zorunlu değil; koşullarda belirtilir, mekanizma kurulmaz.
- Kayıt adımında **Kullanım Koşulları ve Gizlilik Politikası onayı** alınır ve
  metin sürümüyle birlikte `user_consents` defterine yazılır.
- Kötüye kullanan kullanıcı **askıya alınabilir ya da kalıcı olarak
  yasaklanabilir** (`user_sanctions`); uygunsuz içerikte üç ihlalde otomatik
  askı devreye girer. Yasak **veri katmanında** zorlanır, istemci kapısı
  değildir.
- Gereksiz kişisel veri (konum, kişi listesi vb.) toplanmaz.
- İstemci yapılandırması `supabase.json` ile `--dart-define-from-file`
  üzerinden gelir (`supabase.example.json`'a bakın). **Sunucu sırları asla
  istemciye gitmez**; Supabase fonksiyon ortamında dururlar.

> ⚖️ **Yasal uyarı:** Tam **KVKK uyumluluğu** ayrı bir hukuki inceleme
> gerektirir; bu depo teknik iskeleti sağlar, hukuki uygunluğu garanti etmez.

## Lisans

Kapalı kaynak — bkz. `LICENSE`. Kullanılan açık kaynak bileşenlerin lisansları
uygulama içinde **Ayarlar → Açık kaynak lisansları** ekranında gösterilir.
