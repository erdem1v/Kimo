import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/curriculum_repository.dart';
import 'data/notification_lines.dart';
import 'services/ads/ad_service.dart';
import 'features/plus/plus_plans.dart';
import 'services/crash_service.dart';
import 'services/purchase_service.dart';
import 'services/store_purchase_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/supabase_config.dart';
import 'state/app_settings.dart';
import 'state/user_profile.dart';

Future<void> main() async {
  // Yapılandırma yoksa uygulama AÇILMAZ: eski mock/demo modu kaldırıldı.
  // Yanlış paketlenmiş bir yayın derlemesi kimlik doğrulamasız sahte veriyle
  // açılacağına, ne eksik olduğunu söyleyen bir ekran göstersin.
  if (!SupabaseConfig.isConfigured) {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const ConfigErrorApp());
    return;
  }

  if (CrashService.enabled) {
    // SentryFlutter.init kendi runZonedGuarded'ını, FlutterError.onError ve
    // PlatformDispatcher.onError kancalarını kurar.
    await SentryFlutter.init((SentryFlutterOptions o) {
      o.dsn = CrashService.dsn;
      o.beforeSend = CrashService.scrubEvent;
      // Fotoğraflar sınav sorusu = kullanıcı içeriği; ekran görüntüsü ve
      // widget ağacı raporlara ASLA eklenmez.
      o.attachScreenshot = false;
      // attachViewHierarchy zaten varsayılan olarak kapalı; deneysel API'yi
      // çağırmadan kapalı bıraktığımızı burada beyan ediyoruz.
      o.sendDefaultPii = false;
      o.tracesSampleRate = 0.0;
      // ORTAM ETİKETİ (Task 18). `release` ve `dist` zaten otomatik:
      // sentry_flutter'ın LoadReleaseIntegration'ı package_info_plus ile
      // `com.stratejico.kimo@1.0.0+1` yazıyor. Ama `environment` verilmezse
      // simülatör turundan gelen bir hata ile mağazadan gelen aynı kovaya
      // düşüyor; yayın çökmelerini ayırmanın tek yolu bu.
      o.environment = kReleaseMode ? 'production' : 'development';
    }, appRunner: _run);
  } else {
    // DSN yok (dev/CI): raporlar debugPrint'e düşer ama kancalar yine kurulur
    // ki hata yolları iki modda da aynı davransın.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      reportError(details.exception, details.stack ?? StackTrace.current,
          context: 'FlutterError');
    };
    PlatformDispatcher.instance.onError = (Object e, StackTrace st) {
      reportError(e, st, context: 'PlatformDispatcher');
      return true;
    };
    await _run();
  }
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installFriendlyErrorWidget();
  // Tema ve ses tercihi ilk kareden ÖNCE okunur; aksi hâlde koyu mod seçmiş
  // kullanıcı bir kare beyaz görürdü. Bu üç hazırlık adımının hiçbiri
  // uygulamanın açılmasını ENGELLEYEMEZ: eskiden korumasız await'lerdi ve
  // birinin fırlatması runApp'e hiç ulaşılamaması (telemetrisiz beyaz ekran)
  // demekti.
  try {
    await appSettings.load();
  } catch (e, st) {
    await reportError(e, st, context: 'appSettings.load');
  }
  try {
    // Bildirim altyapısı (izin ayrıca istenir; burada yalnızca hazırlanır).
    await notifications.init();
  } catch (e, st) {
    await reportError(e, st, context: 'notifications.init');
  }
  await push.init(); // kendi içinde try/catch'li
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  } catch (e, st) {
    // Supabase olmadan uygulamanın hiçbir ekranı çalışamaz; kullanıcıya
    // durumu söyleyen ekranı göster ve raporla.
    await reportError(e, st, context: 'Supabase.initialize');
    runApp(const ConfigErrorApp());
    return;
  }
  // Ödüllü reklam SDK'sı (Task 10). Diğer hazırlık adımlarıyla aynı kural:
  // `runApp`'i BLOKLAYAMAZ. Kendi içinde try/catch'li ve desteklenmeyen
  // platformda (web, masaüstü, testler) hiçbir şey yapmadan dönüyor —
  // `AdService` orada stub uygulamayı seçiyor.
  //
  // Reklam yolu açılmazsa hak duvarı reklam satırını hiç çizmiyor: hata yok,
  // diyalog yok. Üç sessiz neden (doluluk, platform, yapılandırma) tek bir
  // görünmeyen satıra düşüyor.
  unawaited(AdService.instance.init());

  // SATIN ALMA (Task 14). Task 13 katmanın tamamını yazmış ama eklentiyi
  // ekleyememişti; burası "değişecek tek satır" olarak bırakılan yer.
  //
  // Aynı kural: `runApp`'i BLOKLAMIYOR. `start()` yalnızca mağaza akışını
  // dinlemeye başlıyor — uygulama kapalıyken tamamlanan bir satın alma
  // (Play'de banka onayı, App Store'da aile onayı) sonucu bir sonraki
  // açılışta veriyor ve dinleyici olmadan o sonuç KAYBOLURDU.
  //
  // Ürün sorgusu da await EDİLMİYOR: mağaza yanıtı gelene kadar
  // `PlusPlans.current` boş kalıyor, yani paywall fiyat İÇERMEYEN dürüst
  // hâlinde çiziliyor. Yanıt gelince liste doluyor.
  Purchases.instance = StorePurchaseService.instance;
  StorePurchaseService.instance.start();
  unawaited(
    StorePurchaseService.instance.products().then(PlusPlans.setProducts),
  );

  // Bildirim metinleri veritabanında; önbellek diskten okunur (ucuz, ağsız).
  // Tazeleme Supabase kurulduktan SONRA ve await EDİLMEDEN yapılır: ağ
  // beklemek ilk kareyi geciktirirdi, eski önbellek zaten iş görüyor.
  try {
    await notificationLines.load();
  } catch (e, st) {
    await reportError(e, st, context: 'notify.linesLoad');
  }
  unawaited(notificationLines.refresh());

  // Konu ağacı da aynı desende: önbellek diskten (ağsız), tazeleme ağdan ve
  // AWAIT EDİLMEDEN. Fark şu — ağaç yoksa kullanıcı KONU SEÇEMEZ, yani soru
  // kaydedemez; bu yüzden `load()` önbellek boşsa gömülü yedeğe düşüyor ve
  // çekirdek akış ilk açılışta/çevrimdışıyken de çalışıyor.
  //
  // Tazeleme burada oturum GERİ YÜKLENMEDEN çalışmış olabilir; ikinci deneme
  // `home_shell` içinde, oturum kesinleştikten sonra (notification_lines'ın
  // aynı gerekçesi).
  try {
    await curriculumRepository.load();
  } catch (e, st) {
    await reportError(e, st, context: 'curriculum.load');
  }
  unawaited(curriculumRepository.refresh(userProfile.curriculum));
  runApp(const KimoApp());
}

/// Yayında build aşaması hatası gri kutu yerine dostane bir kart göstersin.
/// Debug'da standart kırmızı ekran kalır (geliştirici için daha bilgilendirici).
void _installFriendlyErrorWidget() {
  if (!kReleaseMode) return;
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // L10n bu kadar erken hazır olmayabilir; metin bilinçli olarak sabit.
    return const ColoredBox(
      color: Color(0xFFFFF8F0),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Bir şeyler ters gitti.\nLütfen uygulamayı yeniden başlat.',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 16, color: Color(0xFF5C4A3D)),
          ),
        ),
      ),
    );
  };
}

/// Supabase yapılandırması eksikken gösterilen tanı ekranı.
///
/// Kasıtlı olarak yerelleştirme altyapısına bağlanmadı: bu ekran ancak
/// derleme hatalıysa görünür ve o durumda gen_l10n çıktısına güvenmek yerine
/// en yalın yol tercih edildi.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFFFFF8F0),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Uygulama yapılandırması eksik.\n\n'
              'Bu derleme sunucu bilgileri olmadan paketlenmiş '
              '(SUPABASE_URL tanımlı değil). Lütfen uygulamayı '
              'mağazadan güncelleyin ya da geliştiriciyseniz '
              '--dart-define-from-file=supabase.json ile derleyin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF5C4A3D)),
            ),
          ),
        ),
      ),
    );
  }
}
