# iOS'ta çalıştırma (macOS)

Bu depo Android'de test edildi. iOS tarafı **hiç derlenmedi** — aşağıdaki
adımlar sıfırdan bir macOS makinesini çalışır hâle getirir.

## 0. Disk yeri (ilk engel)

iOS geliştirme yığını yaklaşık **35-40 GB** ister:

| Bileşen | Yaklaşık boyut |
| --- | --- |
| Xcode 26 | ~15 GB |
| iOS Simulator runtime (ayrı indirilir) | ~10 GB |
| Flutter SDK + artefaktlar | ~3 GB |
| Pods + `build/` çıktıları | ~2-5 GB |

Ayrıca App Store, Xcode'u açarken geçici olarak fazladan yer ister. **Kuruluma
başlamadan önce en az 45 GB boş alan** olmalı. Kontrol:

```bash
df -h /System/Volumes/Data
```

> `df -h /` yanıltıcıdır: macOS'ta o mühürlü sistem birimini gösterir.
> Gerçek boş alan `/System/Volumes/Data` satırındadır.

## 1. Xcode

App Store'dan **Xcode** kurun (Apple ID gerekir), sonra:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
```

Simulator runtime'ı ayrıca inmelidir (Xcode 15'ten beri Xcode'la gelmiyor):

```bash
xcodebuild -downloadPlatform iOS
```

Doğrulama — en az bir simülatör görünmeli:

```bash
xcrun simctl list devices available | grep iPhone
```

## 2. Flutter SDK

Homebrew'un `flutter` cask'ı bu makinede API hatası veriyordu; git ile kurmak
daha güvenilir:

```bash
git clone --depth 1 -b stable https://github.com/flutter/flutter.git ~/development/flutter
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
flutter --version
```

`pubspec.yaml` **Dart SDK `^3.12.2`** istiyor. `flutter --version` çıktısındaki
Dart sürümü bundan küçükse `flutter upgrade` çalıştırın.

## 3. CocoaPods

```bash
brew install cocoapods
pod --version
```

> `sudo gem install cocoapods` kullanmayın: macOS'un sistem Ruby'si ile
> çakışır.

## 4. Doğrulama

```bash
cd ~/Desktop/kimo
flutter doctor -v        # "iOS toolchain" ve "Xcode" satırları ✓ olmalı
flutter pub get          # gen_l10n otomatik koşar (pubspec'te generate: true)
flutter analyze
flutter test
```

Kod üretimi (`build_runner`) **gerekmiyor** — bu depoda freezed/json_serializable
yok. Ana README'nin o bölümü eskidir.

## 5. Simülatörde çalıştırma

```bash
open -a Simulator
flutter devices
flutter run -d <cihaz-kimliği>
```

`supabase.json` yoksa uygulama **demo modunda** açılır: yerel mock veri, oturum
yok (bkz. `lib/services/supabase_config.dart` → `isConfigured`). Onboarding
akışını uçtan uca denemek için bu yeterlidir.

Gerçek sunucuya bağlanmak için:

```bash
cp supabase.example.json supabase.json   # değerleri doldurun
flutter run --dart-define-from-file=supabase.json
```

`supabase.json` `.gitignore`'dadır; commit edilmez.

## 6. Gerçek cihazda çalıştırma

Simülatör imza istemez, gerçek cihaz ister. Xcode'da
`ios/Runner.xcworkspace`'i açın (`.xcodeproj`'yi **değil**) ve:

1. Runner hedefi → **Signing & Capabilities**
2. **Team**: Apple ID'nizi ekleyin (ücretsiz hesap yeterli; profil 7 günde
   dolar)
3. **Bundle Identifier**: `com.stratejico.aiYksCoach` başkası tarafından
   alınmışsa benzersiz bir değerle değiştirin

Depoda `DEVELOPMENT_TEAM` tanımlı değildir — bilinçli, çünkü kişiye özeldir.

## Bilinen iOS notları

**Kamera / galeri izinleri.** `image_picker` kullanılıyor
(`capture_screen.dart`, `profile_screen.dart`; hem `ImageSource.camera` hem
`ImageSource.gallery`). iOS'ta izin açıklaması olmadan bu çağrılar uygulamayı
**çökertir**. `Info.plist`'e eklendi:

- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`

Mikrofon anahtarı bilinçli olarak eklenmedi: yalnızca `pickImage` kullanılıyor,
video seçilmiyor. Kullanıcı kitlesi ağırlıkla reşit değil, gereksiz izin
istenmiyor.

**Deployment target.** `IPHONEOS_DEPLOYMENT_TARGET` 13.0'dan **15.0**'a
çıkarıldı. Sebep: `firebase_core 4.13.0` (Firebase iOS SDK 12.x) iOS 15 altını
desteklemiyor; 13.0'da `pod install` hata verir. `pod install` yine de bir
sürüm çakışmasından şikâyet ederse, hata mesajı gereken en düşük sürümü
söyler — üç `IPHONEOS_DEPLOYMENT_TARGET` satırını da o değere çekin.

**Firebase.** `ios/Runner/GoogleService-Info.plist` depoda **yok** (sır). Bu
sorun değil: `PushService.init()` `Firebase.initializeApp()` çağrısını
try/catch içine alır, dosya yokken uygulama açılır ve yalnızca push bildirimi
çalışmaz. Onboarding E2E testi bundan etkilenmez.

Push'u da denemek isterseniz Firebase konsolundan iOS uygulaması ekleyip
`GoogleService-Info.plist`'i `ios/Runner/` altına koyun ve Xcode'da Runner
hedefine dahil edin. Android tarafındaki koşullu kurgunun
(`android/app/build.gradle.kts`, `google-services.json` varsa eklentiyi uygula)
iOS karşılığı yoktur; iOS'ta dosyanın yokluğu derlemeyi zaten durdurmaz.

**Podfile.** `ios/Podfile` depoda yok; ilk `flutter run`/`flutter build ios`
sırasında Flutter üretir. Eksik olması bir hata değildir. **İlk başarılı
derlemeden sonra `ios/Podfile` ve `ios/Podfile.lock` commit edilmelidir** —
kilit dosyası olmadan pod sürümleri makineden makineye kayar (tekrarlanabilir
derleme yok).

## iOS push bildirimleri (Task 03 durumu)

Kod tarafı hazır olan: `Info.plist`'e `UIBackgroundModes: remote-notification`
eklendi; `PushService` zaten Firebase'siz derlemede sessizce devre dışı
kalıyor. **Push'un iOS'ta gerçekten çalışması için sizin yapmanız
gerekenler:**

1. **Ücretli Apple Developer hesabı** (99$/yıl) — push yetkisi
   (`aps-environment`) ücretsiz hesapla VERİLMEZ. Ücretsiz hesapla uygulama
   cihazda çalışır ama push asla kaydolmaz; E2E onboarding testi için bu
   engel değildir.
2. Firebase konsolu → iOS uygulaması ekle → `GoogleService-Info.plist` indir →
   `ios/Runner/` altına koy ve Xcode'da Runner hedefine dahil et
   (gitignore'da; commit edilmez).
3. Xcode → Runner → Signing & Capabilities → **+ Capability → Push
   Notifications** (bu, `Runner.entitlements` dosyasını ve `aps-environment`
   anahtarını Xcode'a ÜRETTİRİR — elle eklemeyin; ücretsiz hesapta imzalama
   hatası verir).
4. Apple Developer portalında APNs anahtarı üretip Firebase'e yükleyin
   (Cloud Messaging ayarları).

## E2E davranış kontrol listesi (gerçek cihazda)

- [ ] Çentikli cihazda tüm ekranlar SafeArea içinde (özellikle çekim ve onay
      ekranlarının alt çubukları)
- [ ] Geri kaydırma jesti ekranları doğru kapatıyor (onboarding'in kendi geri
      düğmesiyle çakışmıyor)
- [ ] Klavye açıkken giriş/kayıt/not alanları görünür kalıyor
      (`adjustResize` karşılığı iOS'ta otomatik; taşma olmamalı)
- [ ] Ayarlar → Erişilebilirlik → Daha Büyük Metin EN BÜYÜK boyutta: gezinme
      çubuğu, çipler ve butonlar kırpılmadan okunuyor
- [ ] Bildirim izni yalnızca uygulama içi onaydan SONRA isteniyor
- [ ] iOS Ayarlar'dan bildirim izni kapatılınca uygulamadaki anahtar bir
      sonraki açılışta kendini kapatıyor (`checkPermissions` — Task 03'te
      eklendi)
- [ ] Kamera ve galeri akışı izin metinleriyle açılıyor; çekilen fotoğraf
      analizden geçiyor (HEIC→JPEG dönüşümü `imageQuality: 85` ile zorunlu —
      o parametreyi kaldırmayın)
- [ ] Arka plana alıp dönünce Bugün ekranı tazeleniyor
- [ ] Uygulama tamamen kapatılıp açılınca oturum ve onboarding kaldığı yerden
