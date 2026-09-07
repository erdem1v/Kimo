import 'package:ai_yks_coach/services/crash_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// PII temizleyicinin sözleşmesi: hata raporlarına e-posta, kullanıcı kimliği
/// veya depolama yolu (uid taşır) DÜŞMEZ. Kullanıcı kitlesi ağırlıkla reşit
/// değil; bu bir tercih değil zorunluluk.
void main() {
  group('CrashService.scrubEvent', () {
    test('kullanıcı kimliğini ve isteği düşürür', () {
      final SentryEvent event = SentryEvent(
        user: SentryUser(id: 'uid-123', email: 'ogrenci@example.com'),
        request: SentryRequest(url: 'https://x.example/api'),
      );
      final SentryEvent? out = CrashService.scrubEvent(event, Hint());
      expect(out, isNotNull);
      expect(out!.user, isNull);
      expect(out.request, isNull);
    });

    test('e-posta içeren breadcrumb atılır, temiz olan kalır', () {
      final SentryEvent event = SentryEvent(
        breadcrumbs: <Breadcrumb>[
          Breadcrumb(message: 'giriş denendi: ogrenci@example.com'),
          Breadcrumb(message: 'sekme değişti: Lig'),
        ],
      );
      final SentryEvent? out = CrashService.scrubEvent(event, Hint());
      expect(out!.breadcrumbs, hasLength(1));
      expect(out.breadcrumbs!.single.message, 'sekme değişti: Lig');
    });

    test('depolama yolu içeren breadcrumb atılır', () {
      final SentryEvent event = SentryEvent(
        breadcrumbs: <Breadcrumb>[
          Breadcrumb(message: 'GET mistake-photos/abc-uid/17.jpg'),
        ],
      );
      final SentryEvent? out = CrashService.scrubEvent(event, Hint());
      expect(out!.breadcrumbs, isEmpty);
    });

    test('mesaj gövdesindeki e-posta maskelenir', () {
      final SentryEvent event = SentryEvent(
        message: SentryMessage('AuthException for veli@ornek.com failed'),
      );
      final SentryEvent? out = CrashService.scrubEvent(event, Hint());
      expect(out!.message!.formatted, isNot(contains('veli@ornek.com')));
      expect(out.message!.formatted, contains('<e-posta>'));
    });
  });

  group('CrashService.isConnectivityError', () {
    test('ağ hataları raporlanmaz olarak sınıflanır', () {
      expect(
        CrashService.isConnectivityError(
            Exception('SocketException: Failed host lookup')),
        isTrue,
      );
    });
    test('sıradan hata bağlantı hatası sayılmaz', () {
      expect(CrashService.isConnectivityError(StateError('x')), isFalse);
    });
  });
}
