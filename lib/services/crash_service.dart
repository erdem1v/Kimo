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
  ///
  /// TASK 11'DE KAPATILAN İKİ DELİK. Temizleyici yalnızca `event.message`'a
  /// bakıyordu, oysa:
  ///
  ///  1. Uygulamanın TEK raporlama yolu [reportError] → `captureException`
  ///     ve o, hata metnini `message`'a DEĞİL `exceptions[].value` alanına
  ///     yazıyor. Yani pratikte mesaj maskesi hiç çalışmıyordu; e-posta ya da
  ///     JWT taşıyan bir istisna olduğu gibi gidiyordu.
  ///  2. Breadcrumb süzgeci `b.message`'a bakıyordu; HTTP breadcrumb'ında o
  ///     alan null ve asıl adres `b.data['url']` içinde — yani imzalı fotoğraf
  ///     adresi süzgeçten hiç geçmeden gidiyordu.
  ///
  /// `SentryException.toJson` yalnızca type/value/module/stacktrace/mechanism/
  /// threadId gönderiyor; `throwable` serileştirilmiyor, o yüzden `value` ile
  /// `type`'ı temizlemek istisna gövdesi için yeterli.
  static SentryEvent? scrubEvent(SentryEvent event, Hint hint) {
    // Kullanıcı kimliği/e-postası hiç gitmesin. Sentry 9'da olay NESNESİ
    // değiştirilebilir (copyWith kaldırıldı); alanlar doğrudan sıfırlanıyor.
    event.user = null;
    event.request = null;

    // (1) İstisna gövdesi — ASIL hata metninin yaşadığı yer.
    final List<SentryException>? exs = event.exceptions;
    if (exs != null) {
      for (final SentryException e in exs) {
        if (e.value != null) e.value = scrub(e.value!);
        if (e.type != null) e.type = scrub(e.type!);
      }
    }

    // (2) Breadcrumb'lar. Mesajı hassas görünenler ELENİYOR (eski davranış,
    // korundu); hayatta kalanların `data` haritasındaki her metin değeri
    // maskeleniyor.
    event.breadcrumbs = event.breadcrumbs
        ?.where((Breadcrumb b) => !_looksSensitive(b.message ?? ''))
        .map((Breadcrumb b) {
          if (b.message != null) b.message = scrub(b.message!);
          final Map<String, dynamic>? d = b.data;
          if (d != null) {
            for (final String k in d.keys.toList()) {
              final Object? v = d[k];
              if (v is String) d[k] = scrub(v);
            }
          }
          return b;
        })
        .toList();

    // Mesaj gövdesi (captureMessage yolu; bugün kullanılmıyor ama açık).
    final String? msg = event.message?.formatted;
    if (msg != null) {
      final String cleaned = scrub(msg);
      if (cleaned != msg) event.message = SentryMessage(cleaned);
    }
    return event;
  }

  /// Bir metindeki kişisel veri taşıyıcılarını maskeler.
  ///
  /// SIRA ÖNEMLİ: fotoğraf adresi hem kullanıcı kimliğini (yol parçası olarak)
  /// hem imza jetonunu içeriyor; önce adresin tamamı düşürülüyor, sonra kalan
  /// serbest metindeki jeton/e-posta/kimlik tek tek maskeleniyor.
  @visibleForTesting
  static String scrub(String text) {
    return text
        .replaceAll(_photoUrlRe, '<fotoğraf-adresi>')
        .replaceAll(_jwtRe, '<jeton>')
        .replaceAll(_emailRe, '<e-posta>')
        .replaceAll(_uuidRe, '<kimlik>');
  }

  static final RegExp _emailRe =
      RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+', caseSensitive: false);

  /// Supabase imzalı depolama adresi. Yol `<kova>/<uid>/...jpg` biçiminde
  /// kullanıcı kimliği, sorgu dizesi ise imza jetonu taşır.
  static final RegExp _photoUrlRe =
      RegExp(r'https?://[^\s"' "'" r']*(?:mistake-photos|avatars)[^\s"' "'" r']*');

  /// JWT: erişim jetonu, imzalı adres jetonu, service_role anahtarı.
  /// Üçü de kullanıcıyı ya da projeyi ele verir.
  static final RegExp _jwtRe =
      RegExp(r'eyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}');

  /// Çıplak UUID = `auth.uid()`. Depolama yolundan düşse bile hata metninde
  /// tek başına geçebiliyor (`profil <uuid> bulunamadı` gibi).
  static final RegExp _uuidRe = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );

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
