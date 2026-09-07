import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'services/crash_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/supabase_config.dart';
import 'state/app_settings.dart';

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
  runApp(const AiYksCoachApp());
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
