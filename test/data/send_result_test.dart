import 'package:flutter_test/flutter_test.dart';

import 'package:kimo/data/question_send_repository.dart';

/// Gönderim sonucunun kullanıcıya söylediği şey.
///
/// TASK 12: sunucu artık tek çağrıda `sent` / `blocked` / `reason` döndürüyor
/// (0081) ve `blocked` BİLEREK ayrım yapmıyor — "arkadaş değil", "engellendin",
/// "tekrar yasağı" ve "arkadaş başına tavan" hepsi aynı sayıda. Deponun
/// `add_friend_by_code`'daki tek-mesaj ilkesinin aynısı: hangi kapının
/// kapandığını söylemek bilgi sızdırır.
void main() {
  group('SendResult mesajı', () {
    test('gönderim başarılıysa sayıyı söyler', () {
      const SendResult r = SendResult(sent: 2);
      expect(r.ok, isTrue);
      expect(r.message, contains('2 arkadaşına'));
    });

    test('kısmi gönderimde gitmeyenleri de belirtir', () {
      const SendResult r = SendResult(sent: 1, duplicate: 2);
      expect(r.ok, isTrue);
      expect(r.message, contains('2 kişiye gitmedi'));
    });

    test('hiç gitmediyse bunu hata gibi göstermez', () {
      const SendResult r = SendResult(duplicate: 1);
      expect(r.ok, isFalse);
      expect(r.message, contains('gitmedi'));
      expect(r.error, isNull);
      // SEBEBİ SÖYLEMİYOR: "arkadaş değil" ile "engellendin" ayrımı sızmamalı.
      expect(r.message, isNot(contains('engel')));
      expect(r.message, isNot(contains('arkadaş değil')));
    });

    test('günlük tavan AYRI anlatılıyor — yarın tekrar denenebilir', () {
      const SendResult r = SendResult(dailyLimit: true, duplicate: 1);
      expect(r.ok, isFalse);
      expect(r.message, contains('Yarın'));
    });

    test('gerçek hata varsa sebebi yazar', () {
      const SendResult r = SendResult(error: 'Bağlantı hatası');
      expect(r.message, 'Gönderilemedi: Bağlantı hatası');
    });
  });
}
