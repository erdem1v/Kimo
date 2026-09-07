import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Çökme ve hata raporlama (Sentry).
///
/// NEDEN SENTRY, CRASHLYTICS DEĞİL: Firebase bu depoda KOŞULLU —
/// `google-services.json` yoksa Android derlemesi Firebase'siz çıkar ve iOS'ta
/// `GoogleService-Info.plist` hiç yok. Crashlytics o dosyalara sıkı sıkıya
/// bağlı; tam da en çok görünürlük gereken derlemelerde (yapılandırmasız CI
/// APK'sı, tüm iOS derlemeleri) sessizce devre dışı kalırdı. Sentry yalnızca
/// bir DSN ister ve DSN tanımlı değilken no-op'a düşer.
///
/// DSN derlemeye `--dart-define=SENTRY_DSN=...` ile verilir (SUPABASE_URL ile
/// aynı desen). Sır değildir ama yine de kaynağa gömülmez.
///
/// TRIYAJ POLİTİKASI (hata yakalayan her kod bu üç kovadan birine girmeli):
///  1. KULLANICIYA GÖRÜNÜR — kullanıcı eylemi başlattı ve başardığını
///     sanıyor, ya da verisi tehlikede: snackbar/hata durumu + [reportError].
///  2. YALNIZ TELEMETRİ — arka plan senkronu; yerel değerlerle devam etmek
///     doğru UX: catch kalır ama [reportError] çağrılır.
///  3. BİLİNÇLİ SESSİZ — kozmetik/en-iyi-çaba: sessiz kalabilir ama catch'in
///     yanında NEDENİNİ söyleyen bir yorum zorunlu.
class CrashService {
  const CrashService._();

  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  /// DSN tanımlı mı? Değilse tüm raporlama debugPrint'e düşer (dev/CI/test).
  static bool get enabled => _dsn.isNotEmpty;

  static String get dsn => _dsn;

  /// Bağlantı kaynaklı hatalar rapor edilmez: çevrimdışılık bir kusur değil.
  /// `dart:io` import edilmiyor (web hedefi); tür adına bakmak yeterli.
  static bool isConnectivityError(Object error) {
    final String type = error.runtimeType.toString();
    return type == 'SocketException' ||
        type == 'ClientException' ||
        type == 'TimeoutException' ||
        type == 'AuthRetryableFetchException' ||
        // supabase_flutter gerçek zamanlı/istek katmanı bağlantı hataları
        error.toString().contains('SocketException');
  }

  /// PII temizleyici (`beforeSend`). Hata raporlarına soru fotoğrafı,
  /// e-posta, takma ad veya kullanıcı kimliği DÜŞMEMELİ — kullanıcı kitlesi
  /// ağırlıkla reşit değil.
  static SentryEvent? scrubEvent(SentryEvent event, Hint hint) {
    // Kullanıcı kimliği/e-postası hiç gitmesin. `copyWith(user: null)` alanı
    // SIFIRLAMAZ (null = "dokunma"); bu yüzden alanlar boş nesnelerle
    // DEĞİŞTİRİLİYOR — rapora giden user/request içinde hiçbir kimlik kalmaz.
    SentryEvent scrubbed = event.copyWith(
      user: SentryUser(id: 'anonim'),
      request: SentryRequest(),
      breadcrumbs: event.breadcrumbs
          ?.where((Breadcrumb b) => !_looksSensitive(b.message ?? ''))
          .toList(),
    );
    // Mesaj gövdesinde e-posta geçiyorsa maskele.
    final String? msg = scrubbed.message?.formatted;
    if (msg != null && _emailRe.hasMatch(msg)) {
      scrubbed = scrubbed.copyWith(
        message: SentryMessage(msg.replaceAll(_emailRe, '<e-posta>')),
      );
    }
    return scrubbed;
  }

  static final RegExp _emailRe =
      RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+', caseSensitive: false);

  static bool _looksSensitive(String text) {
    if (_emailRe.hasMatch(text)) return true;
    // Depolama yolları `<uid>/...jpg` biçiminde kullanıcı kimliği taşır.
    if (text.contains('mistake-photos') || text.contains('avatars/')) {
      return true;
    }
    return false;
  }
}

/// Yakalanmış bir hatayı raporlar. Uygulamadaki TÜM catch blokları (bilinçli
/// sessiz olanlar hariç) buraya akar; böylece "hiçbir hata izsiz kaybolmaz".
///
/// [context] hatanın nerede olduğunu söyleyen kısa bir etikettir
/// (ör. `bootstrapSocial`). Kişisel veri İÇERMEMELİDİR.
Future<void> reportError(
  Object error,
  StackTrace stackTrace, {
  String? context,
}) async {
  // Çevrimdışılık kusur değil: rapor etme, yalnızca logla.
  if (CrashService.isConnectivityError(error)) {
    debugPrint('ağ hatası (${context ?? '-'}): $error');
    return;
  }
  debugPrint('hata (${context ?? '-'}): $error');
  if (!CrashService.enabled) return;
  try {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (Scope scope) {
        if (context != null) scope.setTag('app.context', context);
      },
    );
  } catch (_) {
    // Raporlayıcının kendisi patlarsa yapılabilecek bir şey yok; uygulamayı
    // asla raporlama yüzünden düşürme. (Bilinçli sessiz.)
  }
}
