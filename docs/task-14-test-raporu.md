# Task 14 — CI doğrulaması ve uçtan uca test

**Tarih:** 2026-09-15 · **Dal:** `main` · **Son koşu:** `35015455347` ✅

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

1. **Servis rolü anahtarı döndürülmeli.** Önceki oturumda sohbete
   yapıştırılmıştı. Hiçbir dosyaya, commit'e ya da bu rapora yazılmadı.
2. **`supabase db push` gerekiyor** — 44 commit'lik göç canlıya basılmadı
   (B3). Basılmadan `main`'deki uygulama canlı projeye karşı çalışamaz.
3. **`LEGAL_TERMS_URL`, `LEGAL_PRIVACY_URL`, `LEGAL_KVKK_URL`,
   `LEGAL_DELETE_URL`, `SUPPORT_EMAIL` doldurulmalı** (B4, G2).
4. **`ff_multi_capture` IAP bağlanana kadar kapalı kalmalı.**
5. **Mağaza ürünleri tanımlanmalı**: `kimo_plus_monthly`, `kimo_plus_yearly`.
   Tanımlanana kadar paywall dürüst hâlinde kalıyor — bu doğrulandı.
6. **iOS'ta StoreKit akışını denemek için** uygulama Xcode'un Run eylemiyle
   başlatılmalı; `flutter run` `Configuration.storekit`i uygulamıyor.
