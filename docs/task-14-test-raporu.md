# Task 14 — CI doğrulaması ve uçtan uca test

**Tarih:** 2026-09-15/16 · **Dal:** `main` · **Son koşu:** `35037466441` ✅

> **İkinci tur (2026-09-16).** Göçler canlıya basıldı, hukuki adresler bağlandı,
> "görünürde bozuk" bulgular düzeltildi ve uçtan uca tur ortak seri dahil
> tamamlandı. O turda **üç yeni bloke edici hata** çıktı. Bkz. §8.

Üç task boyunca yazılan hiçbir şey çalıştırılmamıştı. Bu task onları ilk kez
çalıştırdı: 13 CI turu, 832→833 pgTAP iddiası, 56 mutasyon ve simülatörde
gerçek dokunuşlarla bir uçtan uca tur.

---

## 1. Sonuç tablosu

| Kapı | Durum | Sayı |
|---|---|---|
| `supabase db reset` | ✅ | 101 göç, atlanan yok |
| pgTAP süiti | ✅ PASS | **37 dosya · 833 iddia · 0 düşen** |
| Mutasyon kontrolü | ✅ | **56 / 56 ayırt edildi** |
| `flutter analyze` | ✅ | 0 sorun |
| `flutter test` | ✅ | **389 test** |
| Statik kapılar | ✅ | 19 adımın tamamı (5 kapının kendi sınaması dahil) |

**Başlangıç durumu:** `main` ucu 2026-09-07'deydi; Task 08→13'ün **44
commit'i** hiç push edilmemişti. Üstelik `5feeb02` (Task 10) `ci.yml`'i
geçersiz YAML yapmıştı — push edilselerdi de **hiçbir iş koşmayacaktı**.

**On üç tur sürdü.** Her tur bir öncekinin göremediği bir katmanı açtı:
göç uygulama → şema kurulumu → pgTAP → mutasyon. Aşağıdaki bulguların çoğu
ancak bir önceki katman yeşile döndükten sonra görünür oldu.

---

## 2. Simülatör aracı

**Seçilen: `idb` (Meta) + `xcrun simctl`, doğrudan Bash'ten.**

MCP sunucuları Claude Code oturumu açılırken yükleniyor, yani bu oturumda
yeni bir MCP kullanılamazdı. `idb` aynı yeteneği veriyor ve yeniden başlatma
gerektirmiyor: `idb ui describe-all` **erişilebilirlik ağacını** okuyor,
`idb ui tap/swipe/text/key` **gerçek dokunuş** üretiyor. Ekran görüntüsü
yalnızca görsel doğrulama için kullanıldı.

### Kurulum sorunları ve çözümleri

1. **Homebrew 6 üçüncü parti tap'e güven istiyor.**
   `brew trust --formula facebook/fb/idb-companion` (tap'in tamamı değil).

2. **`brew install idb-companion` "Command Line Tools too outdated" ile
   reddetti.** CLT paketi 16.4, Xcode 26.6. Formül aslında **önceden
   derlenmiş bir tarball açıyor**, hiçbir şey derlemiyor — yani kontrol bu
   vakada yersizdi. Çözüm: aynı sürüm elle, **formülün kendi sha256'sı
   doğrulanarak** `~/.local/opt`'a kuruldu; formülün `test do` bloğu elle
   koşuldu (altı kaynak dosyası da yerinde).

3. **`pipx` ve `venv` "No module named pip" ile düştü.** Kök sebep:
   Homebrew'un `python@3.11` ve `python@3.14` şişelerinde **`pyexpat` bozuk**
   — sistem `libexpat`ına bağlanıyorlar ve macOS 26'da eksik bir sembol
   arıyorlar. Zinciri: `pyexpat` → `plistlib` → `platform.mac_ver()` boş →
   pip'in `truststore`'u `int('')` ile patlıyor.
   Çözüm: `brew install expat` + `DYLD_LIBRARY_PATH=/opt/homebrew/opt/expat/lib`.
   `~/.local/bin/idb` bu değişkeni kendi ayarlayan bir sarmalayıcı.

4. **Erişilebilirlik ağacı ham hâlde ~20 KB tek satır.** `~/.local/bin/axtree`
   onu `rol (x,y) etiket` biçiminde okunur listeye indiriyor; dokunmak için
   gereken koordinat doğrudan çıktıda.

**Geri çekilmeye gerek kalmadı** — `idb` Xcode 26 / iOS 26.2 ile çalıştı.

---

## 3. Üç yeni kapı — kanıtla doğrulandı

Yeşil bir koşu tek başına kanıt değil. Her kapıya **bilerek bozuk girdi**
verilip kırmızı döndüğü, sonra düzeltilmiş ikiziyle yeşil döndüğü gösterildi.

| Kapı | Kanıt |
|---|---|
| `check_workflows.py` | `--selftest` her koşuda; ayrıca aşağıdaki tavuk-yumurta gösterimi |
| `check_sql.py` #5, #6, #8, #9 | `--selftest` içinde dört fikstür çifti (bozuk → kırmızı, düzeltilmiş → yeşil) |
| `check_sql.py` #7, #10 | Canlı ağaçta: iki mutasyonun bayat geri alması geçici olarak eski hâline döndürüldü, ikisi de kırmızı işaretlendi |
| ARB kaçış kapısı (yeni) | Düzeltilmiş ARB'ye bozuk değer geri kondu: `temiz` → `['plusBatchTitle']` |

### Tavuk-yumurta gösterimi

Geçici bir dalda `ci.yml` bilerek geçersiz YAML yapılıp push edildi.

* **Yerel kapı:** `check_workflows.py` → `sorun: 1`, çıkış kodu 1. ✅
* **GitHub:** koşu **0 saniyede** düştü, `"This run likely failed because of a
  workflow file issue"` — **hiçbir iş başlamadı**, dolayısıyla o dosyanın
  içindeki `check_workflows` adımı da koşmadı.

Yani CI'daki kopya ancak **bir sonraki** bozulmayı yakalar; gerçek koruma
yerel koşumdur. Dal silindi.

> Plandaki ifadeyi düzeltiyorum: GitHub workflow'u "hiç başlatmıyor" değil —
> bir koşu kaydı açıp anında düşürüyor. Sonuç aynı, mekanizma farklı.

### Kapıya dönüşen bulgular

Bu turda çıkan üç hata sınıfı kalıcı kapıya bağlandı:

* **#8 — bağımlı görünümü olan `drop view`.** #6'nın kör noktası: ortaya sütun
  eklemeyi yakalıyordu ama önerdiği düzeltmenin (`drop + create`) yaprak
  olmayan bir görünümü düşürdüğünü göremiyordu.
* **#9 — geri alınmış yetkiyi dirilten `grant`.** Kaçış kapısı: `-- @REGRANT`.
* **#10 — bayat `@UNDO` politikası/grant'ı.** #7 yalnız fonksiyon gövdelerine
  bakıyordu; politikalar ve grant'lar denetimsizdi.
* **ARB'de çözülmemiş ICU kaçışı.**
* `check_sql.py` artık `--selftest` taşıyor — depodaki **beş denetleyiciden
  kendi sınaması olmayan tekiydi**, ve tam da bu turda yarım olduğu görüldü.

---

## 4. Bulgular

### 🔴 Bloke eder

#### B1 · Hiçbir fotoğraf yüklenemiyordu (`upsert: true`) — DÜZELTİLDİ

* **Nerede:** `lib/data/mistake_repository.dart` · yükleme çağrısı
* **Ne oluyor:** Her kayıt denemesi
  `StorageException(new row violates row-level security policy, 403)` ile
  düşüyor, uygulama kuyruğa düşüyordu ("internet varken kuyruğa alma" tam
  olarak bu). Kuruluş akışında daha ağır: `PhotoQueue.flush`in
  `StorageException` dalı kaydı **düşürüp fotoğrafı siliyor** — yeni
  kullanıcının ilk fotoğrafı sessizce yok oluyordu.
* **Sebep:** `upsert: true`, Supabase'de `x-upsert` başlığına çevriliyor ve
  sunucu isteği UPSERT olarak işleyip `storage.objects` üzerinde bir **UPDATE
  politikası** arıyor. `mistake-photos` kovasının böyle bir politikası
  **hiç olmadı**.
* **Kanıt:** Uzak projeye karşı birebir üretildi — aynı dosya, aynı yol, aynı
  jeton: `x-upsert` **yokken HTTP 200**, **varken 403** ve birebir aynı mesaj.
* **Ne olmalıydı:** Yükleme geçmeli, soru arşive düşmeliydi.
* **Düzeltme yönü önemli:** `upsert` **istemciden kaldırıldı**; storage'a
  UPDATE politikası **eklenmedi**. Eklenseydi taraması `clear` çıkmış bir
  fotoğrafın üzerine başka bir görsel yazılabilir ve `mistakes.photo_path`in
  yaz-bir-kez olması (0020) anlamsızlaşırdı. Yanlış yol kapıya bağlandı:
  030'a "`mistake-photos` için UPDATE politikası yok" iddiası, mutasyon 56'ya
  o politikayı ekleyen bozma.
* **Doğrulandı:** Düzeltilmiş derleme kuruldu → kuyrukta bekleyen fotoğraf
  kendiliğinden işlendi → arşivde "Hareket ve Kuvvet · Fizik" göründü.

> `avatars` kovası etkilenmedi: `"avatars update own"` (0024) politikası
> bilerek var ve orada doğru. İlk teşhisimde avatar yüklemesinin de bozuk
> olduğunu yazmıştım; CI iddiayı kırmızıya çevirerek düzeltti.

#### B2 · Kaydetme yolunun tamamı 42501 ile kapalıydı (`is_public`) — DÜZELTİLDİ

* **Nerede:** `lib/data/mistake_repository.dart` · insert yükü
* **Ne oluyor:** İstemci yüke `'is_public': isPublic` koymaya devam
  ediyordu; 0090 o sütunun INSERT yetkisini geri almıştı. Her insert 42501.
* **Ne olmalıydı:** Sütun hiç gönderilmemeliydi (sunucu varsayılanı `false`).
* **Nasıl bulundu:** pgTAP 020'nin adında yazan iddia
  ("mistake_repository.dart yolu") — CI'ın ilk gerçek pgTAP koşusunda.
  `flutter analyze` ve 389 birim testi bunu göremez: hata PostgREST yükünde.

#### B3 · Uzak veritabanı 44 commit geride — DÜZELTİLMEDİ (dağıtım kararı)

* **Nerede:** Supabase projesi `trlmenjuzvlgglsxohph`
* **Ne oluyor:** Uygulamanın konuştuğu canlı proje Task 12 öncesinde. REST
  ile doğrulandı: `subscriptions` **404**, `pair_streaks` **404**,
  `feature_flags` **404**, `config_bool` **404**, `istanbul_week` **404**;
  `league_cohorts` 200.
* **Ne olmalıydı:** `main`'deki göçler dağıtılmış olmalıydı.
* **Etkisi:** `main` üzerindeki uygulama bu şemaya karşı **tam çalışamaz**.
  Ortak seri, abonelik ve sunucu tarafı bayrak kapıları uzakta yok.
* **Neden ben yapmadım:** 44 commit'lik göçü canlıya basmak geri alınması zor
  ve açıkça yetki isteyen bir iş. Kararı size bırakıyorum.

#### B4 · Okunamayan metne onay — DÜZELTİLMEDİ (yapılandırma)

* **Nerede:** Kurulum 6/6 · onay kutusu; Ayarlar → Veri ve Gizlilik
* **Ne oluyor:** Kutu "Kullanım Koşulları'nı ve Gizlilik Politikası'nı
  **okudum**, kabul ediyorum" diyor. `LEGAL_*` adresleri **boş** olduğu için
  iki metin de **kalın ama tıklanamaz** çiziliyor ve uygulamanın hiçbir
  yerinden okunamıyor.
* **Ne olmalıydı:** Onay istenen metin okunabilir olmalı.
* **Not:** Satırların gizlenmesi **bilinçli** (`legal_links.dart`: adres
  yoksa satır hiç çizilmiyor; "Hazırlanıyor" yer tutucusu mağaza incelemesi
  yüzünden kaldırılmış). Yani kod doğru davranıyor; eksik olan
  yapılandırma — ama yayın için bloke edici.

### 🟠 Görünürde bozuk

#### G1 · Paywall'da çözülmemiş ICU kaçışı — DÜZELTİLDİ
* **Nerede:** Kimo Plus ekranı, başlık
* **Ne oluyor:** "Çoklu çekim **Plus''ta**" — çift kesme ekranda.
* **Sebep:** `intl` bir iletiyi ancak `{placeholder}` içeriyorsa ICU olarak
  ayrıştırıp `''`yi tek kesmeye indiriyor. `plusBatchTitle`ın yer tutucusu
  yok. Aynı dosyadaki `sendEntryTitle`/`sendArchiveTitle` doğru: `{name}` var.
* **Kapıya bağlandı:** ARB'de yer tutucusuz iletide `''` varsa CI kırmızı.

#### G2 · 13 altı reddinde "bize yazabilirsin" — ama yazacak yer yok
* **Nerede:** Kurulum 2/6 · yaş reddi kartı
* **Ne oluyor:** Metin "Bir yanlışlık olduğunu düşünüyorsan bize
  yazabilirsin" diyor; kart yalnızca başlık + gövde çiziyor, **hiçbir iletişim
  yolu yok**. `SUPPORT_EMAIL` de boş.
* **Ne olmalıydı:** Reddedilen kullanıcı çıkmaz bir ekranda; itiraz yolu
  görünür olmalı (e-posta satırı ya da adres).

#### G3 · Profil kaydı ilk denemede düştü
* **Nerede:** Kurulum 3/6 · "Devam et"
* **Ne oluyor:** İlk dokunuşta "Kaydedilemedi. Tekrar dene."; **ikinci
  dokunuş sorunsuz geçti.**
* **Ne olmalıydı:** İlk denemede geçmeliydi.
* **Durum:** Bir kez gözlendi; o anda günlük akışı bağlı olmadığı için sebep
  saptanamadı. Yeni hesabın ilk yazma isteğinde bir yarış olabilir.

#### G4 · `is_suspended` beraberlikte rastgele karar veriyor
* **Nerede:** `is_suspended(uuid)` — `order by created_at desc, id desc`
* **Ne oluyor:** `created_at` varsayılanı `now()` (işlem zamanı) ve `id`
  rastgele bir uuid. Aynı işlemde yazılan iki yaptırım **eşit damga** taşıyor
  ve ikinci anahtar sıralamayı belirli hâle getirmiyor.
* **Üretimde nasıl olur:** Tek bir `update ... set photo_scan='flagged'`
  ifadesi birden çok ihlali **aynı işlemde** tetikleyebilir; o zaman
  kullanıcının askılı mı yasaklı mı olduğu rastgele belirlenir.
* **Kanıt:** pgTAP 270'in aynı desendeki iddiası 3. turda tesadüfen yeşil,
  4. turda kırmızı döndü.
* **Durum:** **Düzeltilmedi.** Testler belirli hâle getirildi. Kalıcı çözüm
  `user_sanctions`a monoton bir sıra sütunu eklemek; bu yaptırım semantiğine
  dokunuyor ve lockdown sınıflandırma listelerini de değiştiriyor, o yüzden
  bir test görevinin içinde tek taraflı yapmadım.

### 🟡 Küçük

* **K1 · Onay kutusunda yalnızca kare tıklanabilir.** Kurulum 6/6'da etikete
  dokunmak kutuyu değiştirmiyor; alışılmış davranış satırın tamamının
  değiştirmesi.
* **K2 · Ayarlar'da doğum yılı değeri görünmüyor.** "Sınav yılı 2027" değerini
  gösteriyor, "Doğum yılı" yalnızca "bir kez yazılır" notunu gösteriyor —
  kullanıcı kayıtlı yılını göremiyor.
* **K3 · Sınav yılı seçiminin "seçili" durumu erişilebilirlik ağacında yok.**
  Görsel olarak net (koyu çip) ama beş yıl da ağaçta ayrımsız `StaticText`.
* **K4 · Yaş çarkında seçim göstergesi yok.** Açılışta hiçbir yıl seçili
  değil, "Kaydet" kapalı ve kullanıcıya ne yapması gerektiğine dair işaret
  yok; ancak çark kaydırılınca düğme açılıyor.
* **K5 · Oturum sonunda +10 XP → +60 XP sıçraması açıklanmıyor.** Cevap
  ekranı "+10 XP" diyor, özet "+60 XP". Günlük hedef ödülü olduğu anlaşılıyor
  ama dökümü ekranda yok.
* **K6 · Dört persona görseli birbirine çok yakın.** Metinler net ayrışıyor;
  çizimler gösterim boyutunda yalnız küçük aksesuarlarla ayrılıyor.
* **K8 · CI'da sürüm sabitlenmemiş bir eylem var.**
  `supabase/setup-cli@v1` `version: latest` ile çağrılıyor ve en son sürümü
  **GitHub API'sinden** çözüyor. Bu turda bir koşu tam da bu yüzden
  `Failed to resolve latest Supabase CLI release: rate limit exceeded` ile
  **5 saniyede** düştü; yeniden çalıştırınca geçti. Yani depo kodu doğruyken
  CI kırmızı görünebiliyor. Sürümü sabitlemek hem bu takılmayı hem de CLI'ın
  altımızdan sessizce değişmesini kapatır.
* **K7 · Hata ayıklama derlemesinde `!semantics.parentDataDirty` iddiası
  akıyor.** Erişilebilirlik ağacı okunurken onlarca kez düşüyor. Yalnızca
  debug'da; ürün davranışını etkilemiyor, ama semantics ağacının bir yerde
  düzen sırasında güncellendiğini gösteriyor.

### Geliştirme kalitesi bulguları (CI turlarında çıkan)

Bunlar kullanıcıya görünmüyor ama **testlerin kanıt değerini** doğrudan
etkiliyordu:

1. **Üç bayat `@UNDO` sessizce koruma düşürüyordu.** `10_photo_scan_sends`
   askı koşulunu, `08_streak_gate` dizin kilidini, `19_ban_not_enforced` yaş
   kapısını politikadan kaldırıyordu. Her biri, kendisiyle ilgisi olmayan
   mutasyonların sonucunu geçersiz kılıyordu (beş mutasyon "zaten kırmızı"
   diye raporlanıyordu).
2. **Üç test doğru cümleyi yanlış sebeple geçiyordu** (mutasyon 43/54/55
   FAZ 2'de yeşil kaldı): sahiplik iddiası `null` kimlikle çağırıyordu,
   reklam bayrağı iddiası teklif zaten mümkün değilken soruyordu, askı
   iddiası zaten var olan bir ikiliyi deniyordu.
3. **Fikstür yanlış rolde** deseni üç dosyada (010, 085, 270): RLS yüzünden
   alt sorgu boş dönüyor, RPC `null` ile çağrılıyor ve **sessizce hiçbir şey
   yapmıyor** — sonra mekanizma bozukmuş gibi görünüyor.
4. **Kilit sonrası güncellenmemiş iddialar** (060, 098, 260): arşive alınmış
   havuz RPC'lerinin "AÇIK" olduğunu savunuyorlardı.
5. **Beraberlikte belirsiz sıralama** (065, 270): aynı işlemde yazılan satırlar
   eşit `created_at` taşıyor.
6. **Denetleyicinin kendisi yarım olabilir:** #10 ilk yazımında politika adı
   kalıbı `\w+`'ydi ve bu depodaki `"Kendi hatanı ekle"` gibi **tırnaklı,
   boşluklu** adları hiç görmüyordu. "Hiçbir şey bulmuyor" ile "bakamıyor"
   aynı şey değil.

---

## 5. Test edilemeyenler

| Konu | Neden |
|---|---|
| Kamera ile çekim | Simülatörde kamera yok — **galeriden seçim** kullanıldı, akışın geri kalanı aynı |
| Uzaktan bildirim (push) | Simülatörde `aps-environment` yetkisi yok; günlükte de görüldü. **Yerel bildirim izni akışı çalıştı** (sistem izin uyarısı çıktı, kabul edildi), yerel bildirimin kendisi tetiklenmedi |
| Gerçek IAP satın alma | App Store Connect hesabı ve tanımlı ürün yok. `Configuration.storekit` yazıldı ve scheme'e bağlandı, ama **`flutter run` StoreKit yapılandırmasını uygulamıyor** (Xcode'un Run eylemi gerekiyor). Günlükte `storekit_no_response` + `mağazada bulunamayan ürün` — paywall **dürüst hâlinde kaldı**, ki test edilmek istenen de buydu |
| Gerçek AdMob ödüllü reklam | Hesap yok |
| Ortak seri (`ff_pair_streak`) | **İki ayrı engel:** (a) uzak projede `feature_flags` ve `pair_streaks` **yok** (B3), (b) bayrağı REST'ten açmak için gereken servis rolü anahtarı bu oturumun bağlamında değil |
| Arkadaş akışı (iki hesap), şikâyet, engelleme | İki hesaplı tur kurulmadı; giriş yüzeyleri (arkadaş kodu, kopyala, yenile, kodla ekleme, boş liste) doğrulandı |
| Hak göstergesinin dört durumu | Pencereyi doldurmak **gerçek OpenAI kotası** harcardı; yalnız "9 hakkın kaldı" durumu görüldü |
| Çoklu çekim / parti sonuç / iade satırı | `ff_multi_capture` bilinçli kapalı — **yüzeyin çizilmediği doğrulandı** (çekim ekranında yalnız kamera/galeri/fotoğrafsız) |
| Hesap silme | Ekran girişi var; yıkıcı olduğu için tetiklenmedi |

---

## 6. Uçtan uca turda çalıştığı doğrulananlar

* Temiz kurulumda karşılama → 6 adımlı kurulum → hesap açma
* **13 altı reddi** (2024 seçildi → nazik ret, "Devam et" kapandı)
* Fotoğraf aktarım onayı **yüklemeden önce** soruluyor; reddedilirse elle
  giriş yolu açık
* Analiz: fotoğraftan **ders (Fizik) + konu (Hareket ve Kuvvet) + şık sayısı**
  çıkarıldı
* Arşive kayıt, kart üzerinde "Arkadaşına gönder" / "Soruyu sil"
* **Tekrar akışı:** çizim tuvali (kalem/silgi/yakınlaştırma), şık seçimi,
  "Yakaladın!", **+10 XP**, "3 gün sonra yeniden soracağım", oturum sonu
  (seri 1'e çıktı, +60 XP, seviye çubuğu) — **sunucuda kalıcı** (profilde
  60 XP, seri 1)
* **Paywall dürüst hâlinde:** fiyat yok, "7 gün ücretsiz dene" **kapalı**,
  "Plus henüz açılmadı" notu, karşılaştırma tablosu sunucu rakamlarıyla
  (8 saatte 10/50, ayda 300/1000)
* Lig tahtası, arkadaş kodu ekranı, ayarların bütün satırları, **açık kaynak
  lisansları ekranı**, tema değiştirme (koyu tema doğru çiziliyor)
* **Elmas hiçbir ekranda görünmedi**

---

## 7. Dağıtım notları

1. **ÜÇ SIR DÖNDÜRÜLMELİ.** Hiçbiri dosyaya, commit'e ya da bu rapora
   yazılmadı; yalnızca çalışma anında ortam değişkeni olarak kullanıldı:
   * servis rolü anahtarı (önceki oturumda verilmişti),
   * Supabase kişisel erişim jetonu (`sbp_…`),
   * proje veritabanı parolası.
2. ~~`supabase db push` gerekiyor~~ — **YAPILDI** (§8.1): 18 + 1 göç
   uygulandı, doğrulandı.
3. ~~`LEGAL_*` ve `SUPPORT_EMAIL` doldurulmalı~~ — **YAPILDI** (§8.2).
   `supabase.json` izlenmeyen dosya, yani değerler depoya girmedi; **derleme
   yapan her ortamda ayrıca ayarlanmalı** (CI/CD, imzalı yapı).
4. **`ff_multi_capture` IAP bağlanana kadar kapalı kalmalı.** Şema canlıya
   gelince açık çıktı ve kapatıldı; bir daha açılmadığından emin olun.
5. **Mağaza ürünleri tanımlanmalı**: `kimo_plus_monthly`, `kimo_plus_yearly`.
   Tanımlanana kadar paywall dürüst hâlinde kalıyor — bu doğrulandı.
6. **iOS'ta StoreKit akışını denemek için** uygulama Xcode'un Run eylemiyle
   başlatılmalı; `flutter run` `Configuration.storekit`i uygulamıyor.


---

## 8. İkinci tur — dağıtım ve tamamlanan uçtan uca test (2026-09-16)

### 8.1 Göç dağıtımı

**Ön kontrol (göçlerden ÖNCE, talimat gereği):** `birth_year is null` olan
**üç** hesap bulundu ve durduruldu. Üçü de sıfır içerikli: iki yarıda
bırakılmış anonim oturum ve bir `@example.com` test hesabı; hiçbirinde soru,
depo nesnesi, arkadaşlık ya da gönderim yok. Kişisel hesap
(`erdemsalman1@gmail.com`, doğum yılı 2010) listede değildi.

Silme **üretimde yıkıcı işlem güvenlik kapısına takıldı**. Kontrol sırasında
şu da doğrulandı: **hiçbir göç `birth_year`'ı zorunlu kılmıyor** — ne
`not null`, ne check, ne backfill; `birth_year is not null` yalnızca
`has_birth_year` gövdesinde, çalışma anında kullanıcı başına değerlendiriliyor.
Yani üç hesap göçü engellemiyordu. Kararınızla silmeden devam edildi.

Silmek isterseniz, panodaki SQL Editor'da:

```sql
delete from auth.users u
 where u.id in (select p.id from public.profiles p where p.birth_year is null);
```

**Göç:** Uzak geçmiş temizdi, ıraksama yoktu — uzak `20260908000400`'de
duruyordu. **18 göç uygulandı** (Task 12 + 13 + 0095), hata yok. Ardından 0096
de basıldı. Doğrulama: `subscriptions` ve `pair_streaks` REST'te **404 → 401**
(tablo var ve `anon`'a kapalı), `config_bool`/`istanbul_week`/
`start_pair_streak` yerinde, `profiles_public` hâlâ `authenticated`'a kapalı.

**`legal_version` zaten `1.3`'tü** — sitedeki metinlerin sürümüyle (Sürüm: 1.3)
ve `docs/hukuki-metinler.md` ile uyumlu. En sona bırakma şartı sağlandı:
göçlerden sonra bakıldı, doğru değerdeydi, yazılmasına gerek kalmadı.

**Bayraklar:** `ff_multi_capture` şema canlıya gelince **açık** çıktı.
`capture_screen.dart:462` bayrak açıkken çoklu çekim yüzeyini çiziyor (üstelik
katman kontrolü olmadan), yani satın alınamayan bir özellik görünür olacaktı.
Duran karar gereği **kapatıldı**. `ff_pair_streak` test için açılıp sonra
kapatıldı. Son durum: `pair_streak=false`, `multi_capture=false`,
`ad_reward=true`, `iap=true`, `legal_version=1.3`.

### 8.2 Hukuki adresler

`LEGAL_TERMS_URL`, `LEGAL_PRIVACY_URL`, `LEGAL_KVKK_URL`, `LEGAL_DELETE_URL`
ve `SUPPORT_EMAIL` bağlandı. Destek adresi sitede Cloudflare ile gizlenmişti;
`data-cfemail` çözülerek alındı: `kimo.iletisim@gmail.com`. Dört sayfa da
HTTP 200 ve üçünün de künyesi **Sürüm: 1.3**.

**B4 kapandı:** kayıt adımında "Kullanım Koşulları" ve "Gizlilik Politikası"
artık erişilebilirlik ağacında `Link` düğümü — önce düz kalın metindi.

### 8.3 İkinci turda çıkan YENİ bloke ediciler

#### B5 · "Çıkış yap" oturumu kapatıp ekranda bırakıyordu — DÜZELTİLDİ

* **Nerede:** Ayarlar → Çıkış yap (hesap silme yolu da aynı kapıdan geçiyor)
* **Ne oluyor:** Günlükte `supabase.auth: Signing out user with scope: local`
  çıkıyor, saklanan `auth-token` anahtarı **gerçekten siliniyor** — ama
  uygulama Ayarlar ekranında kalıyor, hâlâ giriş yapılmış gibi. Kullanıcı
  hiçbir şey olmadı sanıyor; sonraki her istek sessizce yetkisiz düşerdi.
* **Sebep:** `AuthGate` MaterialApp'in `home`'u. `setState` yalnızca KÖK
  rotanın içeriğini değiştiriyor; Ayarlar Navigator'a **itilmiş** bir rota,
  yani kökün üstünde duruyor ve yerinde kalıyor. Davranışın "bazen çalışıyor"
  görünmesinin sebebi buydu: kök ekrandayken çalışıyor, Ayarlar'dan çıkınca
  çalışmıyordu.
* **Düzeltme:** oturum düşünce yığın köke indiriliyor.

#### B6 · Yeni kullanıcı kendisine gönderilen soruyu HİÇ göremiyordu — DÜZELTİLDİ

* **Nerede:** Bugün sekmesi, arşiv boşken
* **Ne oluyor:** B hesabının gelen kutusunda A'dan gelen soru var
  (`received_questions` bir satır dönüyor) ama ekran "Arşivin henüz boş"
  diyor ve başka hiçbir şey göstermiyordu.
* **Sebep:** `today_screen.dart`ta `if (_archiveEmpty) return _emptyArchive(...)`
  panonun tamamını kısa devre yapıyor; gelen soru kartı panonun içinde.
* **Neden önemli:** Bu, gönderim özelliğinin **en olası alıcısı** — arkadaşı
  tarafından davet edilmiş, henüz kendi sorusunu çekmemiş yeni kullanıcı.
  Arkadaş "gönderdim" diyor, alıcının ekranında hiçbir şey yok.
* **Not:** Aynı sınıfın bir örneği bu ekranda ZATEN çözülmüştü (bekleyen
  fotoğraf şeridi boş durumda da çiziliyor, yorumu da bunu yazıyor). Gelen
  soru kartı aynı gözden kaçışın bir adım ötesiydi.

#### B7 · HUD tekrar sayacı gün bazlıydı — DÜZELTİLDİ

* **Nerede:** `my_daily_state.due_count`
* **Ne oluyor:** Sayaç vadeyi yalnızca TARİHTEN okuyordu
  (`next_review_date <= istanbul_day()`), oysa 0049'dan beri vade bir ZAMAN
  DAMGASI ve yeni soru aynı gün +3 saate vadeleniyor. İstemci de zaman bazlı
  süzüyor. Sonuç: gece yarısından itibaren, o gün ilerisi için vadelenmiş bir
  soru HUD'da "1 tekrar" olarak sayılıyor ama oturumun listesine girmiyordu.
* **Nasıl bulundu:** CI'ın **gece yarısını geçen ilk koşusunda** kırmızı döndü.
  İddia (`tests/215`) doğruydu; saate bağlı olarak gizleniyordu: vade
  `now() + 3 saat`, İstanbul saatiyle 21:00'den sonra ertesi güne taşıyor ve
  tarih karşılaştırması tesadüfen doğru cevabı veriyordu. Bu tasktaki bütün
  önceki koşular 20:56–22:5x aralığına denk gelmişti — **test günün 21
  saatinde kanıt üretmiyordu.**
* **Düzeltme:** 0096 sayacı istemcinin süzgecine eşitliyor; mutasyon 58 yanlış
  yolu kapıya bağlıyor.

### 8.4 Görünürde bozuk bulguların durumu

| | Durum |
|---|---|
| G1 · paywall'da `Plus''ta` | ✅ düzeltildi + ARB kapısı |
| G2 · yaş reddinde iletişim yolu yok | ✅ "Bize yaz" düğmesi eklendi, simülatörde doğrulandı |
| G3 · profil kaydı ilk denemede düşüyor | ✅ tek tura indirildi; **tekrarlanmadı** (günlük bağlıyken ilk dokunuşta geçti). Kök sebep kanıtlanmadı — iki ayrı `updateUser` turu yerine tek yazım, yarış yüzeyini kaldırıyor |
| G4 · `is_suspended` beraberlikte rastgele | ✅ 0095: `created_at` varsayılanı `clock_timestamp()`; `photo_violations` ve `user_consents` de aynı kusuru taşıyordu |

### 8.5 Ortak seri — dört an da doğrulandı

Fikstür: iki test hesabı arkadaş yapıldı (**gerçek akış**: B kodu girdi, A
"Gelen istekler"den kabul etti), A sorusunu arayüzden gönderdi, iki yönde de
çözülmüş gönderim kuruldu.

| An | Sonuç |
|---|---|
| Bayrak KAPALI | `start_pair_streak` → `false`, `my_pair_streaks` → `[]`, arkadaş kartında **hiçbir yüzey çizilmiyor** ✅ |
| 1 · Başlatma | `true`; seri 1, en iyi 1, karşı tarafın kimliği/maskotu dönüyor ✅ |
| 1b · Kopya | ikinci çağrı `false` — ikinci satır yok ✅ |
| 2 · İlerleme | devir sonrası seri 2, en iyi 2 ✅ |
| 2b · İdempotans | aynı devir tekrar koştu, sayı değişmedi ✅ |
| 3 · Kırılma | biri dün çalışmadı → seri 0, **en iyi 2 korundu** ✅ |
| 4 · Çıkış | bayrak kapatıldı, fikstür temizlendi ✅ |

Not: devir "dün"ü işliyor ve `last_day` zaten dünse dokunmuyor — kurulum
gününün ikinci kez sayılmaması bu kapıdan geliyor.

### 8.6 İkinci turun test edilemeyenleri

* **Mail oluşturma ekranı:** simülatörde Mail uygulaması yok. "Bize yaz"
  düğmesi yedek mesajı GÖSTERMİYOR, yani adresin bağlı olduğu doğrulandı;
  oluşturma ekranının kendisi açılamadı.
* **Hesap silme:** yıkıcı olduğu için tetiklenmedi.
* **Yerel bildirimin kendisi:** izin akışı çalıştı, bildirim tetiklenmedi.
* **Gerçek IAP satın alma:** ürünler hâlâ tanımlı değil; günlükte
  `storekit_no_response` + `mağazada bulunamayan ürün`, paywall dürüst hâlinde.

### 8.7 Ortam notu

Bu turun sonlarında makine **takas alanını tüketti** (6 GB'ın 5.4 GB'ı dolu;
simülatör + Xcode derlemesi). Bir Xcode derlemesi 0% CPU'da ~50 dakika takıldı
ve öldürüldü; statik kapılar yerelde dakikalarca sürdü. Kapılar bozuk değildi
— `0096` commit'inin doğrulaması bu yüzden CI'a bırakıldı ve CI yeşil döndü.
