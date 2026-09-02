plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
