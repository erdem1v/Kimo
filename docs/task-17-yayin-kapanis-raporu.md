# Task 17 — Yayın öncesi kapanış

Task 15 ve 16 ürünü kullanılabilir hâle getirdi, ama ikisi de **bloke edici bir
hatayla** kapandı ve ikisinin bulgusu da depodaki **hiçbir kapıdan** geçememişti:
836 pgTAP iddiası, 58 mutasyon, 414 birim testi ve beş statik kapı yeşilken
"sınav yılı 2028 seçen kullanıcı ilk sorusunu kaydedemiyor" ayakta kalabildi.

Sebep yapısaldı: **her kapı bir parçayı tek başına doğruluyordu.** İki bloke
edici de istemci/sunucu sınırının iki yakasında bir **sıra** hatasıydı ve o
sınırı sınayan hiçbir test yoktu. İkinci bir desen daha vardı: istemci sunucu
kurallarının kopyalarını tutuyor ve kopyalar bayatlıyor.

Bu task o iki deseni kapatmak ve **yayın onayına göndermeden önceki son turu**
atmak için açıldı. Sekiz faz, hepsi tamamlandı — biri hariç: **sırların
döndürülmesi onay bekliyor** (§7).

---

## Özet

| | |
|---|---|
| Kapatılan bulgu | **25** (7'si yayını engelleyecek sınıfta) |
| Yeni göç | 6 (0098–0103) |
| Dart testi | 414 → **449** |
| pgTAP iddiası | 836 → **852** (38 dosya) |
| Mutasyon | 58 → **61** |
| Yeni Deno testi | 7 (ve depodaki 2 eski test ilk kez koşuyor) |
| Yeni CI işi | 2 (entegrasyon süiti, Android derlemesi) + Deno adımı |
| Hâlâ açık | Sır döndürme ve 0103'ün üretime basılması (ikisi de onay bekliyor) |

---

## 1. Entegrasyon ağı — depodaki ilk sınır testi

**Sorun.** `flutter test` istemciyi tek başına, pgTAP şemayı tek başına
doğruluyordu. Aradaki boşlukta — istemcinin sunucuya ne sorduğu, sunucunun ne
cevapladığı — hiçbir şey yoktu ve iki bloke edici hata tam orada yaşadı.

**Yapılan.** CI'ın `db` işi zaten tam bir yerel yığın (Postgres · GoTrue ·
storage-api) ayağa kaldırıyordu; eksik olan tek şey ona **istemci koduyla**
bağlanan testlerdi. `test_e2e/` geldi:

* `auth_claims_e2e_test.dart` — metadata → JWT → `my_curriculum()` →
  `mistakes.curriculum` → konu doğrulaması zinciri. **Task 15'in bloke edicisi
  bu testle üretime hiç çıkamazdı.** Ayrıca bir "davranış belgesi" testi:
  `updateUser` tek başına JETONU YENİLEMİYOR.
* `send_guard_e2e_test.dart` — fotoğraf taraması `pending` iken gönderim
  `not_sendable`; anonim gönderen `anonymous`; fotoğrafsız kayıt beklemeden
  gidiyor.

Süit **sessizce atlamıyor**: ortam değişkenleri yoksa gürültüyle düşüyor.
Yazıldığı gün bir şey de öğretti — e2e kullanıcıları anonim açılınca sunucu
`not_sendable` değil `anonymous` döndü; kural üçüncü bir sözleşme testine
dönüştü.

## 2. Sunucu değişiklikleri — tek göç dalgası

| Göç | Ne değişti | Neden |
|---|---|---|
| 0098 | `start_pair_streak` artık **sebep** döndürüyor | Yedi farklı sonucu tek `false`a katlıyordu; serisi zaten başlamış ikiliye "başlatın" çağrısı çıkıyordu |
| 0099 | `ai_state()` ücretsiz katman sınırlarını ayrı yayınlıyor | Paywall'daki kıyas tablosu abonede "Ücretsiz 50 \| Plus 50" yazıyordu |
| 0100 | Sessiz saatler **sunucuya** taşındı | Söz uygulamanın her yerinde veriliyordu ama `send_push` saate hiç bakmıyordu: arkadaş bildirimleri gece 03:00'te gidiyordu |
| 0101/0102 | Yetki ve kilit tazelemesi | Yeni sütun ve fonksiyonlar kapıların dışında kalmasın |
| 0103 | Çakışan makbuz artık istisna değil karar | §5, T17-8 |

Göç yazarken iki tuzağa daha düşüldü ve ikisi de **kapılar tarafından
yakalandı**: `create or replace` OUT sütununu değiştiremiyor (0099 `drop` +
`create` oldu) ve bir mutasyonun `@UNDO`su bayatlayınca korumayı sessizce
kaldırıyor (0098'in ilk taslağı iki kapıyı birden düşürmüştü — `check_sql`
durdurdu).

## 3. Ortak seri — düzeltildi ve açıldı

Sunucu sebebi ayırdıktan sonra istemci üç dalı üç farklı şekilde ele alıyor:
davet yalnızca **`needs_solved`**'de çıkıyor, `started`'da kutlama var,
`exists`'te **sessizlik**. Davet metni de gerçeğe çekildi: seri "gönderince"
değil **arkadaş o soruyu çözünce** başlıyor.

Risk kartı eylem aldı ("Tekrara başla" → tekrar ekranı); eskiden durum bildirip
hiçbir kontrol taşımıyordu.

Üç dal da **iki simülatörle üretime karşı** doğrulandı. `ff_pair_streak`
**açık** bırakıldı.

## 4. Kalan istemci maddeleri

| Bulgu | Ne yapıldı |
|---|---|
| **U6** · Hatalarım her tazelemede tam ekran çemberle sıfırlanıyor, kaydırma konumu kayboluyordu | Tazeleme sessiz; çember yalnızca ilk yüklemede. Düşen bir tazeleme dolu listeyi hata metniyle değiştirmiyor |
| **Android geri tuşu** onboarding'in her adımında uygulamadan çıkıyordu | `PopScope` ile ekrandaki okla aynı davranış; ilk adımda çıkış serbest (kök davranışı) |
| **B8** · Persona kartlarındaki örnek cümleler üründe hiç gönderilmeyen cümlelerdi | Kart önce **canlı havuzu** okuyor; ARB yedeği havuzun 0. varyantının birebir kopyası ve bir test bunu **göçten okuyarak** sabitliyor |
| **B7** · "Günde en fazla iki kez" sözü yanlıştı | Lig haftasının son günü üçüncü bir bildirim planlanıyor; metin gerçeğe çekildi |
| **Gelen kutusunda tam ekran yoktu** | Tekrar ekranındaki görüntüleyici ortak bileşene çıkarıldı, gelen kutusuna rozetle eklendi |
| **Lig kuralı örtüşüyordu** | İstemci 6+ kişilik gruba düşme vaat ediyordu, sunucu 11+'te uyguluyor; dokuz kişilik grupta beşinci sıra iki kümedeydi. Eşik sunucudan okunuyor |
| **D7 kozmetik** | Hak duvarı düğmesi paywall'ın satın alma düğmesiyle aynı cümleyi taşıyordu · tema kartı iki ekranda birebir kopyaydı · doğum yılı satırı neden kilitli olduğunu söylemiyordu · engelleme onayı kimi engellediğini yazmıyordu · "Veri ve gizlilik" yazımı |
| **K6** · Dört personanın taban ayısı aynı | **Değiştirilmedi.** Ürünün kendi kararı bu: "maskot tek, değişen ses tonu". Aksesuar ayrımı (çiçek+örgü, kasket, gözlük+papyon, ceket+zincir) küçük boyutta da okunuyor |

## 5. Gezilmemiş akışlar — denetim

Turların hiç girmediği altı akış iki mercekle (sıra · kaynak) denetlendi.

### Düzeltilen

| # | Bulgu | Neden ağır |
|---|---|---|
| **T17-6** | Gecelik abonelik mutabakatı **yenilemeleri atlıyordu**: karar yalnızca `status`a bakıyordu, yenileme ise durumu değiştirmiyor, `expires_at`i ileri atıyor | İşin tek varlık sebebi "webhook hiç kurulmasa bile doğru kal"dı. `premium_until` eski tarihte donuyor, ödeme yapan kullanıcı premium'unu kaybediyordu. İptal ve plan değişimi de aynı kör noktadaydı |
| **T17-7** | Kaydını yeni tamamlamış kullanıcının jetonunda `is_anonymous` ~1 saat `true` kalıyor; `verify-purchase` onu 401 ile reddediyor | "Kaydol, hemen Plus al" sessizce düşüyordu. Task 15'in müfredat hatasıyla **aynı sınıf** |
| **T17-8** | Başka hesaba bağlı makbuz `unique_violation` fırlatıyor, edge fonksiyonun genel `catch`inde **503**'e dönüşüyordu | 503 "geçici arıza, yine dene" demek; durum ise kalıcı. İstemci satın almayı tamamlamıyor, mağaza teslimi tekrarlıyor |
| **T17-5** | Abonelik durumu sunucudan geliyor, model okuyor, **hiçbir ekran kullanmıyordu** | Parasını ödemiş kullanıcı Kimo Plus'ı açınca satış sayfasını ve "7 gün ücretsiz dene" düğmesini görüyordu. Mağaza kuralına da aykırı: mevcut aboneye deneme teklif edilemez |
| **T17-10** | Hesap silme yerel hatırlatmaları iptal etmiyordu (çıkış yolu ediyordu) | Hesabını silen kullanıcı günlerce "Serin tehlikede" bildirimi almaya devam ediyordu — silinmiş bir hesabın serisi için |
| **S6** | Arşiv listesi gönderilebilirliği üç koşulla ölçüyordu, sunucu beş | Damgalanmış fotoğraf listede gönderilebilir görünüyor, kullanıcı ancak sunucu hatasıyla öğreniyordu |

### Denetlendi, bulgu çıkmadı

* **Reklam ödülü** — belirteç sunucudan, ödül yalnızca imzalı geri çağrıyla,
  işlem kimliği üzerinde idempotent, sır yoksa fail-closed, tekrar teslim
  dalı doğru.
* **Çoklu çekim** — ekran kendi kapısını taşıyor (bayrak + katman), sınır
  cihaz belleği ile kuyruk boşluğunun küçüğü.
* **Oturum** — çıkışta jeton silme, yerel bildirim iptali, ilerleme sıfırlama
  ve kuyruk temizliği hepsi yerinde.

### Bulgu ama bilerek değiştirilmedi

* `stale_anonymous_users` ölçütü **oluşturma tarihi**, son etkinlik değil.
  Kurulum kaydı zorunlu kıldığı için pratikte yalnızca terk edilmiş hesaplar
  siliniyor; veri silme semantiğini bir denetim turunda sessizce değiştirmek
  doğru olmazdı. **Karar sizin.**
* `SendResult.message` cümleleri ARB'de değil repository'de. Uygulama tek
  dilli, işlevsel kırık yok; taşıma ayrı bir iş.

## 6. Yayın hazırlığı

### Kapatılanlar

* **Uygulama ikonu Flutter'ın varsayılanıydı** — 19 iOS yuvasında ve beş
  Android yoğunluğunda mavi Flutter logosu. İki mağaza da yer tutucu varlıkla
  gönderilen yapıyı reddeder. İkon artık **çiziliyor**: `tool/gen_app_icons.dart`
  maskotu `KimoPainter` ile marka yeşiline basıyor. Tek kaynak.
* **Android uyarlanabilir ikon** (8.0+) eklendi.
* **Açılış ekranı** iki platformda da varsayılandı (iOS'ta 1×1 beyaz piksel);
  artık ortada maskot var, zemini saydam olduğu için açık ve karanlık temada
  aynı şekilde doğru.
* **`PrivacyInfo.xcprivacy` yoktu.** İçeriği uydurulmadı: her satır
  `docs/hukuki-metinler.md`deki App Store gizlilik etiketi tablosundan geliyor.
  iOS derlemesiyle bildirimin pakete girdiği doğrulandı.
* **`ITSAppUsesNonExemptEncryption = false`** — anahtar olmadan App Store
  Connect her yüklemede aynı soruyu elle soruyor.
* **ATT notu düzeltildi.** Info.plist "ATT hiç çağrılmıyor" diyordu; cihaz
  günlüğünde AdMob SDK'sının `trackingAuthorizationStatus` çağrısı görünüyor.
  Bu izin İSTEMEK değil, durumu OKUMAK — kullanım metni gerektirmiyor,
  pencere çıkarmıyor, "Used to Track: Hayır" cevabını değiştirmiyor. Yorum
  artık tam olarak bunu söylüyor; mağaza formunu dolduran kişinin günlükte
  o satırı görüp tereddüt etmesi gereksiz olurdu.
* **Android hiç derlenmemişti** (bu makinede SDK yok, CI'da da iş yoktu).
  CI'a `flutter build apk --release` işi eklendi — ve **ilk koşusunda yayın
  yapısının kırık olduğunu buldu**:

  > `ERROR: Missing classes detected while running R8.`
  > `Missing class com.google.android.play.core.splitcompat.SplitCompatApplication`

  R8 yalnızca `--release`te çalışıyor ve eksik sınıfı **hataya** yükseltiyor.
  Yani `flutter build appbundle --release` — Play'e yüklenecek yapının ta
  kendisi — hiç üretilemiyordu. Uygulama ertelenmiş bileşen kullanmadığı için
  doğru cevap Play Core'u pakete sokmak değil, R8'e bu sınıfların yokluğunun
  beklendiğini söylemek: iki `-dontwarn` kuralı.

### Sizde kalan (mağaza hesabı gerektiriyor)

| Mağaza | Adım | Not |
|---|---|---|
| App Store | Gizlilik etiketi formu | `hukuki-metinler.md` §"App Store Connect" tablosu birebir girilecek; `PrivacyInfo.xcprivacy` ile **çelişmemeli** |
| App Store | IAP ürünleri: `kimo_plus_monthly`, `kimo_plus_yearly` | Deneme **7 gün (P1W)** olmalı — `PlusPlans.trialDays = 7` ve paywall metni bu sayıyı yazıyor |
| App Store | Yaş derecelendirmesi | 13+ (uygulama içi yaş kapısı zaten var) |
| App Store | Ekran görüntüleri, açıklama, destek adresi | — |
| Play | Veri güvenliği formu | "Reklam kimliği: HAYIR" — AD_ID izni manifestten kaldırıldı |
| Play | Abonelik ürünleri, aynı kimlikler ve aynı deneme süresi | — |
| Play | İmzalama: `android/key.properties` | Yoksa yapı debug anahtarıyla imzalanıyor ve derleme günlüğüne yazıyor |
| Play | Hesap silme sayfası | `docs/hesap-silme-sayfasi.md` hazır; adres `LEGAL_DELETE_URL` ile geliyor |
| İkisi | Yayın derlemesinde `ADMOB_APP_ID` | Verilmezse Google'ın **test** kimliği kalıyor ve derleme uyarı basıyor |

## 7. Sırların döndürülmesi — ONAY BEKLİYOR

Üç sır sohbete yapıştırıldığı için artık oturum dökümünde duruyor; döndürme
gerekçesi bir arttı. Sıra ve etkisi:

```
1. sbp_ erişim jetonu    → en zararsız, yalnızca yönetim API'si
2. DB parolası           → yalnızca doğrudan bağlantılar
3. service_role anahtarı → EDGE FONKSİYONLARINI KIRAR
   ↓ hemen ardından
4. supabase functions deploy × 11
5. her fonksiyon çağrılıp 200/401 beklendiği gibi mi
```

Üçüncü adım **kırıcı**: yeni anahtar dağıtılana kadar analiz, tarama, silme,
satın alma doğrulaması ve push çalışmaz. Onayınızla başlatılacak.

Yeni değerler hiçbir dosyaya, commit'e ve bu rapora yazılmayacak.

## 8. Kapanış turu

Değişen her yüzey, üretime bağlı bir simülatörle gezildi (`ada@kimo.test`).

| Yüzey | Sonuç |
|---|---|
| Hatalarım · sekme değişimi | Kaydırma konumu **korunuyor**, çember yok |
| Gelen kutusu | "Tam ekran" rozeti çıkıyor, dokunuş tam ekranı açıyor |
| Lig · 9 kişilik kohort | "ilk 5 yükselir; **bu hafta kimse düşmüyor**" — eski metin aynı grupta "son 5 düşer" diyordu |
| Arkadaş · engelleme | Onay başlığı **"Efe engellensin mi?"** |
| Ayarlar · doğum yılı | Yıl **ve** gerekçesi: "bir kez yazılır, sonradan değiştirilemez" |
| Ayarlar · "Veri ve Gizlilik" | Yazım ekran başlığıyla aynı |
| Persona kartları | Dört cümle de **havuzun 0. varyantı** — üründe duyulacak cümlenin ta kendisi |
| Kimo Plus | Düğme kapalı ve **nedeni yazıyor**; koşullar ve gizlilik bağlantıları yerinde |
| Uygulama ikonu | Ana ekranda maskot, marka yeşili zeminde |

### Turda çıkan YENİ hata — düzeltildi

Hatalarım'ın "Son 7 gün" grafiğinde ekranda **"BOTTOM OVERFLOWED BY 10
PIXELS"** şeridi vardı: sütunlar sabit 72 piksellik bir kutuya sığdırılmıştı
ama içerik (sayı + sütun + gün adı) ~82 piksel. Yayın derlemesinde şerit
çizilmez, içerik yine de kırpılır.

Neden hiçbir test görmemişti: mevcut testler tarihi geçmiş bir kayıt
kullanıyordu, yani grafik hiç çizilmiyor, "bu hafta kayıt yok" metnine
düşüyordu. Yeni test bugünün tarihiyle kayıt veriyor; sabit yükseklik geri
konduğunda **kırmızıya dönüyor**.

## 9. Doğrulama

* CI yeşil: pgTAP · mutasyon · statik kapılar · analyze + test · **entegrasyon
  süiti** · **Android derlemesi**
* Her sunucu değişikliğinin **ayırt eden** pgTAP testi ve mutasyon girdisi var;
  mutasyon uygulanınca ilgili test kırmızıya dönüyor
* iOS yayın derlemesi başarılı, gizlilik bildirimi pakette
* Beş göç üretime **tek tek** basıldı ve her birinden sonra doğrulandı;
  0103 henüz basılmadı (§Kalanlar)

### Kalanlar

1. **0103 üretime basılmalı** (çakışan makbuz dalı). Üretimde kontrol edildi:
   fonksiyon hâlâ eski gövdede.
2. **Sır döndürme** — onayınızla.
3. Android geri tuşu düzeltmesi **iOS simülatöründe doğrulanamaz**; donanım
   tuşu yok. Gerçek bir Android cihazda ya da emülatörde bakılmalı.
4. **Üretimde altı test hesabı duruyor**: `ada@kimo.test`, `efe@kimo.test`
   (bu turun hesapları) ve Task 11/14'ten kalan `kimo-t14-a@`, `kimo-t14-c@`,
   `task14a@`, `kimo-model-test@`. Silinmeleri sizin onayınıza bağlı —
   hesap silme geri alınamıyor ve listede sizin kendi adresleriniz de var.
