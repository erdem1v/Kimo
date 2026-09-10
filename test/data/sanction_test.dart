import 'package:flutter_test/flutter_test.dart';

import 'package:kimo/data/sanction_repository.dart';

void main() {
  group('SanctionStatus.kind', () {
    test('yaptırım yoksa none', () {
      expect(SanctionStatus.none.kind, SanctionKind.none);
    });

    test('süreli askı temporary', () {
      final SanctionStatus s = SanctionStatus(
        suspended: true,
        permanent: false,
        until: DateTime(2026, 9, 20),
      );
      expect(s.kind, SanctionKind.temporary);
    });

    test('kalıcı yasak permanent', () {
      const SanctionStatus s =
          SanctionStatus(suspended: true, permanent: true);
      expect(s.kind, SanctionKind.permanent);
    });

    // Yönetici süre vermeden askıya alabiliyor (`until` null). Bunu "kalıcı"
    // göstermek kullanıcıya yanlış bir şey söylemek olurdu: karar geri
    // alınabilir ve ekran itiraz yolunu göstermeye devam etmeli.
    test('süresiz ama kalıcı olmayan askı yine temporary', () {
      const SanctionStatus s =
          SanctionStatus(suspended: true, permanent: false);
      expect(s.kind, SanctionKind.temporary);
      expect(s.until, isNull);
    });

    test('sunucu satırı okunuyor', () {
      final SanctionStatus s = SanctionStatus.fromRow(<String, dynamic>{
        'suspended': true,
        'permanent': false,
        'until': '2026-09-17T10:00:00Z',
        'reason_code': 'photo_repeat',
      });
      expect(s.suspended, isTrue);
      expect(s.reasonCode, 'photo_repeat');
      expect(s.until, isNotNull);
    });

    test('eksik alanlar askıya alınmış saymıyor', () {
      final SanctionStatus s =
          SanctionStatus.fromRow(const <String, dynamic>{});
      expect(s.suspended, isFalse);
      expect(s.kind, SanctionKind.none);
    });
  });

  group('PhotoWarning.tone', () {
    PhotoWarning w(int strike) =>
        PhotoWarning(id: 'x', strikeNo: strike, activeCount: strike);

    test('birinci ihlal nazik', () => expect(w(1).tone, WarningTone.gentle));
    test('ikinci ihlal sert', () => expect(w(2).tone, WarningTone.firm));
    test('üçüncü ihlal askı bildiriyor',
        () => expect(w(3).tone, WarningTone.suspended));
    test('üçüncüden sonrası da askı dilinde',
        () => expect(w(7).tone, WarningTone.suspended));

    // Sertlik KAYIT ANINDAKİ sıradan geliyor, güncel sayaçtan değil:
    // kullanıcının gördüğü metin uyarının yazıldığı ana ait olmalı. Bir
    // yönetici araya girip eski ihlalleri geçersiz kılsa bile, bekleyen
    // uyarının dili değişmiyor.
    test('sertlik güncel sayaçtan değil, kayıt anındaki sıradan geliyor', () {
      const PhotoWarning old =
          PhotoWarning(id: 'x', strikeNo: 1, activeCount: 5);
      expect(old.tone, WarningTone.gentle);
    });

    test('sunucu satırı okunuyor', () {
      final PhotoWarning p = PhotoWarning.fromRow(<String, dynamic>{
        'id': 'a1',
        'strike_no': 2,
        'active_count': 2,
        'mistake_id': 'm1',
      });
      expect(p.tone, WarningTone.firm);
      expect(p.mistakeId, 'm1');
    });
  });
}
