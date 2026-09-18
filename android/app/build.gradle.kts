import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Yayın imzalama anahtarı (Task 03, bulgu 3.2).
//
// `key.properties` ve keystore dosyası DEPODA YOK (.gitignore) — google-
// services.json ile aynı desen: dosya varsa gerçek anahtar kullanılır, yoksa
// derleme debug anahtarına düşer ve bunu GÜNLÜĞE YAZAR. Sessiz kalmıyoruz:
// debug imzalı bir "release" yan yükleme testi için çalışır ama Play Store'a
// YÜKLENEMEZ ve debug anahtarı tüm Flutter makinelerinde ortaktır.
//
// key.properties biçimi (android/ dizinine konur; storeFile yolu app
// modülüne — android/app — göre çözülür, android/kimo-release.jks için
// "../kimo-release.jks" yazın):
//   storeFile=../kimo-release.jks
//   storePassword=...
//   keyAlias=kimo
//   keyPassword=...
// Üretim komutu (bir kez): keytool -genkey -v -keystore kimo-release.jks \
//   -alias kimo -keyalg RSA -keysize 2048 -validity 10000
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// Firebase (anlık bildirimler) KOŞULLU uygulanıyor.
//
// `google-services.json` bir gizli yapılandırma dosyası: `.gitignore`'da ve
// depoda YOK. Plugin koşulsuz uygulandığında Gradle
// "File google-services.json is missing" diyerek derlemeyi tamamen durduruyordu
// — yani depoyu klonlayan hiç kimse APK üretemiyordu.
//
// Şimdi: dosya varsa Firebase kurulur, yoksa uygulama bildirimsiz derlenir.
// Bildirim ZAMANLAMASI yerel (`flutter_local_notifications`) ve Firebase'e
// bağlı değil; kaybolan yalnızca sunucudan gelen push.
//
// CI'da gerçek dosya `GOOGLE_SERVICES_JSON` deposu sırrından yazılıyor
// (bkz. .github/workflows/android.yml). Sır tanımlı değilse derleme yine
// başarılı olur, üretilen APK'da push çalışmaz.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    logger.lifecycle("google-services.json bulundu: Firebase push etkin.")
} else {
    logger.lifecycle(
        "google-services.json YOK: Firebase push devre dışı derleniyor.",
    )
}

android {
    namespace = "com.stratejico.kimo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications, eski Android sürümlerinde modern
        // tarih/saat API'lerini kullanabilmek için desugaring ister.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.stratejico.kimo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // SDK SÜRÜMLERİ AÇIK SAYILARLA SABİT (Task 14). Eskiden
        // `flutter.minSdkVersion` / `flutter.targetSdkVersion`e bırakılmıştı;
        // o değerler Flutter SDK'sıyla birlikte SESSİZCE değişiyor.
        //
        // Neden şimdi önemli: Play Billing Library'nin bir taban minSdk şartı
        // var ve Play'in targetSdk politikası her yıl tabanı yükseltiyor. İkisi
        // de "bir gün Flutter güncellendi ve derleme başka bir şey üretti"
        // sınıfından sürpriz üretmemeli — uygulamanın hangi Android
        // sürümlerinde çalıştığı DEPODAN okunabilmeli.
        //
        // Bugünkü Flutter 3.47.2 varsayılanlarıyla AYNI değerler; yani bu
        // değişiklik davranışı değiştirmiyor, yalnızca sabitliyor.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ADMOB UYGULAMA KİMLİĞİ (Task 10). Manifest'teki `${admobAppId}`
        // yer tutucusunu besliyor ve EKSİKSE UYGULAMA AÇILIŞTA ÇÖKER.
        //
        // Varsayılan Google'ın AÇIK TEST kimliği: gerçek AdMob hesabı
        // açılmadan önce de derleme çalışıyor ve hiçbir derleme gerçek reklam
        // göstermiyor. `google-services.json` ve `key.properties` ile aynı
        // koşullu desen — gerçek değer ortamdan/özellikten geliyor:
        //
        //   flutter build apk -Padmob.appId=ca-app-pub-XXXXXXXX~YYYYYYYY
        //
        // ya da CI'da ADMOB_APP_ID sırrı üzerinden. Verilmezse test kimliği
        // kalıyor ve bu durum derleme çıktısına YAZILIYOR (sessiz değil).
        val admobAppId = (project.findProperty("admob.appId") as String?)
            ?: System.getenv("ADMOB_APP_ID")
            ?: "ca-app-pub-3940256099942544~3347511713"
        if (admobAppId.startsWith("ca-app-pub-3940256099942544")) {
            println("UYARI: AdMob TEST uygulama kimligi kullaniliyor. " +
                    "Yayin derlemesinde -Padmob.appId=... verilmeli.")
        }
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                // PKCS12: keystore Task 18'de openssl ile üretildi (geliştirme
                // makinesinde JDK/keytool yok). AGP her iki türü de okuyor;
                // türü açıkça yazmak "JKS bekliyordum" sürprizini kapatıyor.
                storeType = "PKCS12"
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                logger.lifecycle("key.properties bulundu: YAYIN anahtarıyla imzalanıyor.")
                signingConfigs.getByName("release")
            } else {
                logger.lifecycle(
                    "key.properties YOK: release, DEBUG anahtarıyla imzalanıyor — " +
                        "yan yükleme testi için uygundur, Play Store'a YÜKLENEMEZ.",
                )
                signingConfigs.getByName("debug")
            }

            // Küçültme + karartma (Task 03): Dart tarafı zaten AOT; burada
            // kazanç Kotlin/Java eklenti yüzeyi ve APK boyutu. Kural dosyası
            // eklentilerin bilinen R8 kırılmalarını (özellikle
            // flutter_local_notifications'ın Gson serileştirmesi) koruyor.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // Desugaring kütüphanesi (yukarıdaki isCoreLibraryDesugaringEnabled ile
    // birlikte gerekir).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
