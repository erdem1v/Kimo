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
    namespace = "com.stratejico.ai_yks_coach"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.stratejico.ai_yks_coach"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
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
