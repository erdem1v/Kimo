import 'package:kimo/services/crash_service.dart';
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

  // ---------------------------------------------------------------------
  // TASK 11'DE KAPATILAN İKİ DELİK
  //
  // Yukarıdaki dört test de temizleyicinin ZATEN çalışan yollarını sınıyordu
  // (user, request, breadcrumb.message, event.message). Uygulamanın gerçek
  // raporlama yolu ise `captureException` ve o, `exceptions[].value` alanını
  // dolduruyor — hiçbir test oraya bakmıyordu, temizleyici de bakmıyordu.
  // ---------------------------------------------------------------------
  group('scrubEvent — istisna gövdesi (gerçek raporlama yolu)', () {
    /// `reportError` → `Sentry.captureException` böyle bir olay üretir:
    /// metin `message`'a DEĞİL, `exceptions[].value`'ya gider.
    SentryEvent exceptionEvent(String value, {String type = 'StateError'}) =>
        SentryEvent(exceptions: <SentryException>[
          SentryException(type: type, value: value),
        ]);

    test('istisna metnindeki e-posta maskelenir', () {
      final SentryEvent? out = CrashService.scrubEvent(
        exceptionEvent('AuthApiException: user ogrenci@example.com not found'),
        Hint(),
      );
      final String v = out!.exceptions!.single.value!;
      expect(v, isNot(contains('ogrenci@example.com')));
      expect(v, contains('<e-posta>'));
    });

    test('istisna metnindeki JWT maskelenir', () {
      const String jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjMifQ.abc-DEF_123';
      final SentryEvent? out = CrashService.scrubEvent(
        exceptionEvent('PostgrestException: JWT $jwt expired'),
        Hint(),
      );
      final String v = out!.exceptions!.single.value!;
      expect(v, isNot(contains(jwt)));
      expect(v, contains('<jeton>'));
    });

    test('istisna metnindeki kullanıcı kimliği (UUID) maskelenir', () {
      const String uid = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';
      final SentryEvent? out = CrashService.scrubEvent(
        exceptionEvent('profil $uid bulunamadı'),
        Hint(),
      );
      final String v = out!.exceptions!.single.value!;
      expect(v, isNot(contains(uid)));
      expect(v, contains('<kimlik>'));
    });

    test('istisna metnindeki imzalı fotoğraf adresi tümüyle düşer', () {
      const String url =
          'https://abc.supabase.co/storage/v1/object/sign/mistake-photos/'
          '3f2504e0-4f89-11d3-9a0c-0305e82c3301/17.jpg?token=eyJhbGciOiJI.abc.d';
      final SentryEvent? out = CrashService.scrubEvent(
        exceptionEvent('StorageException indirme başarısız: $url'),
        Hint(),
      );
      final String v = out!.exceptions!.single.value!;
      expect(v, isNot(contains('mistake-photos')));
      expect(v, isNot(contains('3f2504e0')));
      expect(v, isNot(contains('token=')));
      expect(v, contains('<fotoğraf-adresi>'));
    });

    test('istisna TÜRÜ de temizlenir', () {
      final SentryEvent? out = CrashService.scrubEvent(
        exceptionEvent('x', type: 'Hata<ogrenci@example.com>'),
        Hint(),
      );
      expect(out!.exceptions!.single.type, isNot(contains('@example.com')));
    });

    test('zararsız istisna metni AYNEN kalır (yanlış pozitif kapısı)', () {
      const String temiz = 'RangeError: index 5 not in range 0..3';
      final SentryEvent? out =
          CrashService.scrubEvent(exceptionEvent(temiz), Hint());
      expect(out!.exceptions!.single.value, temiz);
    });
  });

  group('scrubEvent — breadcrumb data haritası', () {
    test('HTTP breadcrumb\'ının data.url\'i maskelenir (message null olsa da)',
        () {
      // Gerçek şekil: HTTP breadcrumb'ında `message` NULL, adres `data`'da.
      // Eski süzgeç yalnızca message'a baktığı için bu breadcrumb hiç
      // denetlenmeden gidiyordu.
      final SentryEvent event = SentryEvent(
        breadcrumbs: <Breadcrumb>[
          Breadcrumb(
            category: 'http',
            data: <String, dynamic>{
              'url': 'https://abc.supabase.co/storage/v1/object/sign/'
                  'mistake-photos/3f2504e0-4f89-11d3-9a0c-0305e82c3301/17.jpg',
              'method': 'GET',
              'status_code': 403,
            },
          ),
        ],
      );
      final SentryEvent? out = CrashService.scrubEvent(event, Hint());
      final Breadcrumb b = out!.breadcrumbs!.single;
      expect(b.data!['url'], '<fotoğraf-adresi>');
      // Teşhis değeri taşıyan alanlar korunur.
      expect(b.data!['method'], 'GET');
      expect(b.data!['status_code'], 403);
    });

    test('data içindeki e-posta ve JWT de maskelenir', () {
      final SentryEvent event = SentryEvent(
        breadcrumbs: <Breadcrumb>[
          Breadcrumb(category: 'auth', data: <String, dynamic>{
            'email': 'veli@ornek.com',
            'token': 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig_abc',
          }),
        ],
      );
      final SentryEvent? out = CrashService.scrubEvent(event, Hint());
      final Map<String, dynamic> d = out!.breadcrumbs!.single.data!;
      expect(d['email'], '<e-posta>');
      expect(d['token'], '<jeton>');
    });
  });

  group('scrubEvent — takma ad', () {
    test('takma ad SentryUser üzerinden gider ve o alan tümüyle düşer', () {
      // Takma ad serbest metin: desenle yakalanamaz. Tek güvence, takma adın
      // taşındığı alanın (SentryUser.username) hiç gönderilmemesi.
      final SentryEvent event = SentryEvent(
        user: SentryUser(id: 'u1', username: 'matematikci_ayse'),
      );
      final SentryEvent? out = CrashService.scrubEvent(event, Hint());
      expect(out!.user, isNull);
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
