# Soru havuzu içe aktarma aracı

MEB ÖDSGM kazanım testi PDF'lerini kesip soru havuzuna yükler. Uygulamadan
bağımsız bir Dart paketidir; `flutter pub get` ile ilgisi yoktur.

## Gereksinimler

- Dart SDK (Flutter kurulumundaki yeterli)
- **Poppler** — `pdftotext` ve `pdftoppm` PATH'te olmalı: `scoop install poppler`
- Veritabanında `0025_official_questions.sql` çalıştırılmış ve sistem hesabı
  `set_osym_account()` ile işaretlenmiş olmalı

```bash
cd tools
dart pub get
```

## Kullanım

Önce **her zaman** kuru çalıştır ve kesimlere gözünle bak:

```bash
dart run bin/import_meb.dart manifests/meb_12_matematik.json --dry-run
```

Kesimler `out/` altına düşer. İyi görünüyorsa yükle:

```bash
export SUPABASE_URL='https://xxxx.supabase.co'
export SUPABASE_SERVICE_KEY='...'     # service_role anahtarı
dart run bin/import_meb.dart manifests/meb_12_matematik.json
```

Tek bir testi denemek için: `--only 3,7`

Hepsini sırayla yüklemek için (PowerShell):

```powershell
foreach ($m in Get-ChildItem manifests/*.json) { dart run bin/import_meb.dart $m.FullName }
```

> **service_role anahtarı RLS'i tamamen atlar.** Yalnızca ortam değişkeninden
> okunur; dosyaya yazma, depoya ekleme, uygulamaya koyma. Bu araç senin
> bilgisayarında elle çalışır.

Fotoğraf yolu `<sistem hesabı>/meb/<manifest adı>/<konu>-<test>-<soru>.jpg`
biçimindedir. Manifest adı yola girer çünkü aynı konu birden çok sette
geçiyor: 11. ve 12. sınıfın "Roman" testleri de, iki sınıfın "Popülasyon
Ekolojisi" testleri de aynı numarayı taşıyor. Manifest adı olmadan ikincisi
birincinin kopyası sanılıp sessizce atlanıyordu.

Bu düzen 2026-08-24'te değişti. Daha önce yüklenmiş MEB soruları eski
yoldadır; hepsini yeniden yüklemeden önce SQL editöründe temizle, yoksa
havuzda çift kayıt kalır:

```sql
delete from storage.objects
 where bucket_id = 'mistake-photos' and name like '%/meb/%';
delete from public.mistakes where source = 'meb';
```

Betik aynı soruyu iki kez yüklemez (fotoğraf yolundan kontrol eder), yani
yarıda kalırsa tekrar çalıştırmak güvenlidir.

## Manifestler

21 manifest var, hepsi MEB kazanım testlerinden:

| Set | Test | Soru |
|---|---|---|
| 9. sınıf sayısal / sözel | 78 / 78 | 918 / 873 |
| 10. sınıf sayısal / sözel | 78 / 91 | 892 / 1034 |
| 11. sınıf mat / fiz / kim / biyo | 40 / 40 / 40 / 40 | 445 / 438 / 461 / 412 |
| 12. sınıf mat / fiz / kim / biyo | 40 / 39 / 40 / 40 | 465 / 438 / 457 / 414 |
| 11. sınıf edebiyat / tarih / coğrafya | 40 / 40 / 40 | 399 / 480 / 465 |
| 12. sınıf edebiyat / tarih / coğrafya | 40 / 40 / 40 | 387 / 480 / 459 |
| 11. sınıf felsefe / din | 32 / 32 | 360 / 374 |
| 12. sınıf din | 32 | 370 |

9 ve 10. sınıf setleri tek bir e-kitaptan geliyor, o yüzden testlerin
`pages` alanı var. Kalan setler test başına ayrı PDF.

Cevap anahtarları AYT setlerinde ayrı bir PDF olarak yayımlanıyor
(`<ders>_ca_mayis.pdf`); konu adları da odsgm.meb.gov.tr'deki resmî test
listesinden alındı — PDF'in kendi metin katmanındaki Türkçe harfler bozuk.

## Manifest

```json
{
  "source": "meb",
  "sourceYear": 2022,
  "sourceSession": "Kazanım Testi",
  "tests": [
    {
      "url": "https://cdn.eba.gov.tr/.../mat/1.pdf",
      "exam": "AYT",
      "subject": "Matematik",
      "concept": "Logaritma",
      "answers": "ABDDEEBCCCAD"
    }
  ]
}
```

`concept` değeri **`lib/data/yks_curriculum.dart` ile birebir aynı olmalı**,
yoksa soru haritada hiçbir konuya düşmez. `answers` cevap anahtarından gelir —
doğru şıkkı AI'ya sordurmuyoruz, güvenilmez.

## Nasıl çalışıyor

1. PDF indirilir (`.cache/`, ikinci kez indirilmez)
2. `pdftotext -bbox` ile kelime koordinatları çıkarılır — Türkçe harfler bu
   PDF'lerde bozuk okunuyor ama koordinatlar sağlam, bize o yetiyor
3. Soru numaraları bulunur. Aynı hizada duran sayılar kümelenir ve **en
   soldaki** küme seçilir — en kalabalık olan değil: sorunun içindeki
   "I. II. III." listeleri kimi zaman gerçek numaralardan çok olur ama hep
   daha sağda durur. Numaralar ayrıca yukarıdan aşağı artmak zorunda, bu da
   şekil etiketlerini ve tekrarları eler.
4. Sütun sınırı, ortadaki dikey MEB künyesinin solunda kesilir
5. `pdftoppm` 200 dpi PNG üretir, kutular kesilir, alttaki boşluk kırpılır
6. Numaralar `1..N` olarak eksiksiz çıkmazsa **o test atlanır** ve rapora
   yazılır. Yarısını sessizce yüklemek, havuza bozuk soru sokmaktan beterdir.
7. JPEG Storage'a, satır `mistakes` tablosuna yazılır (`source='meb'`)

Yüklemeden sonra uygulamadaki **Ayarlar → Tüm sorular** ekranından gözden
geçirebilirsin.

## Kaynak hakkında

MEB kazanım testleri EBA üzerinden öğrencilere ücretsiz yardımcı kaynak olarak
yayımlanıyor ve sayfalarında ÖDSGM künyesi var. Sitenin altında "Tüm Hakları
Saklıdır" ibaresi de var — yani açıkça izin verilmiş değil, açıkça
yasaklanmamış. ÖSYM çıkmış soruları bilerek kullanılmadı: onların her
sayfasında "izinsiz kullanılamaz" ibaresi basılı.
