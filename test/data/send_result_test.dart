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

    test('tarama sürüyorsa AYRI anlatılıyor — "gitmedi" DEĞİL', () {
      // Task 16 · C0-1. Sunucu `not_sendable` dönüyordu ve istemci onu
      // `blocked` sayıyordu: kullanıcı hiç göndermediği bir soru için
      // "yakında göndermiş olabilirsin" görüyordu. Gerçek sebep birkaç
      // saniye içinde kendiliğinden geçen fotoğraf taramasıydı.
      const SendResult r = SendResult(notSendable: true, scanPending: true);
      expect(r.ok, isFalse);
      expect(r.message, contains('kontrolü'));
      expect(r.message, isNot(contains('göndermiş olabilirsin')));
    });

    test('tarama bitmiş ama yine gönderilemiyorsa beklemeye çağırmıyor', () {
      const SendResult r = SendResult(notSendable: true);
      expect(r.message, isNot(contains('Birkaç saniye')));
      expect(r.message, contains('gönderilemiyor'));
    });

    test('not_sendable bir ALICI reddi değil: duplicate sayılmıyor', () {
      // `blocked`a karıştırmak "arkadaşın almadı" anlamına gelirdi.
      const SendResult r = SendResult(notSendable: true, scanPending: true);
      expect(r.duplicate, 0);
    });

    test('askı AYRI anlatılıyor — "gitmedi" değil, "sen gönderemiyorsun"', () {
      // Task 17 · T17-3. Sunucu DÖRT sebep döndürüyor; Task 16 yalnızca
      // `not_sendable`ı ayırmıştı, `suspended` ve `anonymous` hâlâ `blocked`a
      // karışıyordu. Askıdaki kullanıcı, C0-1'de düzeltilen cümlenin
      // birebir aynısını görüyordu — bu kez yaptırım yolunda.
      const SendResult r = SendResult(suspended: true);
      expect(r.ok, isFalse);
      expect(r.duplicate, 0, reason: 'gönderen reddi ALICI reddi değil');
      expect(r.message, contains('kısıtlı'));
      expect(r.message, isNot(contains('göndermiş olabilirsin')));
    });

    test('anonim kullanıcıya hesabını açması söyleniyor', () {
      const SendResult r = SendResult(anonymous: true);
      expect(r.duplicate, 0);
      expect(r.message, contains('hesabını'));
      expect(r.message, isNot(contains('göndermiş olabilirsin')));
    });
  });

  group('sunucu satırını sonuca çevirme', () {
    SendResult of(String reason, {int sent = 0, int blocked = 1}) =>
        SendResult.fromRow(<String, dynamic>{
          'sent': sent,
          'blocked': blocked,
          'reason': reason,
        });

    test('GÖNDEREN reddi duplicate SAYILMIYOR — üç sebep de', () {
      // Kırık olan tam buydu: sunucu dört sebep döndürüyor, istemci ikisini
      // tanıyordu ve kalan ikisi `blocked` üzerinden "arkadaşın almadı"
      // cümlesine düşüyordu.
      for (final String reason in <String>[
        'not_sendable',
        'suspended',
        'anonymous',
      ]) {
        expect(of(reason).duplicate, 0, reason: '$reason bir ALICI reddi değil');
        expect(of(reason).message, isNot(contains('göndermiş olabilirsin')),
            reason: '$reason kendi cümlesini almalı');
      }
    });

    test('her sebep kendi bayrağını kaldırıyor', () {
      expect(of('suspended').suspended, isTrue);
      expect(of('anonymous').anonymous, isTrue);
      expect(of('not_sendable').notSendable, isTrue);
      expect(of('daily_limit').dailyLimit, isTrue);
    });

    test('ALICI reddi duplicate olarak KALIYOR', () {
      // Tanınmayan/alıcı-tarafı sebepler (arkadaş değil, engel, tekrar
      // yasağı, arkadaş başına tavan) sunucuda bilerek ayrılmıyor.
      final SendResult r = of('', blocked: 3);
      expect(r.duplicate, 3);
      expect(r.message, contains('gitmedi'));
    });

    test('kısmi başarı sayıyı taşıyor', () {
      final SendResult r = of('', sent: 2, blocked: 1);
      expect(r.ok, isTrue);
      expect(r.message, contains('2 arkadaşına'));
    });
  });
}
