import 'package:flutter_test/flutter_test.dart';

import 'package:ai_yks_coach/data/question_pool_repository.dart';

void main() {
  group('SendResult mesajı', () {
    test('gönderim başarılıysa sayıyı söyler', () {
      const SendResult r = SendResult(sent: 2);
      expect(r.ok, isTrue);
      expect(r.message, contains('2 arkadaşına'));
    });

    test('kısmi gönderimde zaten gidenleri de belirtir', () {
      const SendResult r = SendResult(sent: 1, duplicate: 2);
      expect(r.ok, isTrue);
      expect(r.message, contains('2 kişide zaten vardı'));
    });

    test('yalnızca tekrar varsa bunu hata gibi göstermez', () {
      const SendResult r = SendResult(duplicate: 1);
      expect(r.ok, isFalse);
      expect(r.message, 'Bu soruyu ona zaten göndermiştin.');
      expect(r.error, isNull);
    });

    test('gerçek hata varsa sebebi yazar', () {
      const SendResult r = SendResult(error: 'Bağlantı hatası');
      expect(r.message, 'Gönderilemedi: Bağlantı hatası');
    });
  });
}
