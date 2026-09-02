import 'package:ai_yks_coach/models/social.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('League — altı kademe', () {
    test('kademe veritabanı değerinden okunur (XP eşiği yok)', () {
      expect(League.fromDb('bronz'), League.bronz);
      expect(League.fromDb('gumus'), League.gumus);
      expect(League.fromDb('altin'), League.altin);
      expect(League.fromDb('platin'), League.platin);
      expect(League.fromDb('zumrut'), League.zumrut);
      expect(League.fromDb('elmas'), League.elmas);
      // Bilinmeyen/boş değer en alt kademeye düşer.
      expect(League.fromDb(null), League.bronz);
      expect(League.fromDb('saçma'), League.bronz);
      // 'efsane' ARTIK YOK: eski yapıdan gelen bir değer bronza düşer.
      // Göç onu 'zumrut'a çevirdiği için veritabanında kalmamış olmalı;
      // kalırsa arayüz çökmek yerine en alt kademeyi gösterir.
      expect(League.fromDb('efsane'), League.bronz);
    });

    test('tam altı kademe var ve sırası doğru', () {
      expect(League.values, <League>[
        League.bronz,
        League.gumus,
        League.altin,
        League.platin,
        League.zumrut,
        League.elmas,
      ]);
    });

    test('terfi zinciri doğru, en üstün sonrası yok', () {
      expect(League.bronz.next, League.gumus);
      expect(League.gumus.next, League.altin);
      expect(League.altin.next, League.platin);
      expect(League.platin.next, League.zumrut);
      expect(League.zumrut.next, League.elmas);
      expect(League.elmas.next, isNull);
    });

    test('düşme zinciri doğru, en altın öncesi yok', () {
      expect(League.elmas.previous, League.zumrut);
      expect(League.zumrut.previous, League.platin);
      expect(League.platin.previous, League.altin);
      expect(League.altin.previous, League.gumus);
      expect(League.gumus.previous, League.bronz);
      expect(League.bronz.previous, isNull);
    });

    test('next ve previous birbirinin tersi', () {
      for (final League l in League.values) {
        expect(l.next?.previous ?? l, l, reason: '${l.name} ileri-geri');
        expect(l.previous?.next ?? l, l, reason: '${l.name} geri-ileri');
      }
    });

    test('kohort, terfi ve düşme sayıları', () {
      // 30 kişilik kohort — sunucudaki league_cohort_size() ile aynı olmalı.
      expect(League.cohortSize, 30);
      expect(League.promotionCount, 5);
      expect(League.demotionCount, 5);
      // İlk 5 çıkar + son 5 düşer, kohort ikisini de barındıracak kadar
      // büyük olmalı; aksi hâlde aynı kişi hem çıkar hem düşer.
      expect(League.cohortSize,
          greaterThan(League.promotionCount + League.demotionCount));
    });

    test('her kademenin veritabanı değeri ve etiketi var', () {
      for (final League l in League.values) {
        expect(l.dbValue, isNotEmpty);
        expect(League.fromDb(l.dbValue), l, reason: 'gidiş-dönüş ${l.name}');
        expect(l.label, contains(l.shortLabel));
      }
    });
  });

  group('LeagueBoard.daysLeft', () {
    test('hafta başından itibaren geri sayar', () {
      final DateTime monday = weekStart(DateTime.now());
      LeagueBoard board(DateTime ws) =>
          LeagueBoard(tier: League.bronz, entries: const <LeagueEntry>[],
              weekStart: ws);
      // Bu haftanın pazartesisi → 7 güne kadar kalan gün pozitif olmalı.
      expect(board(monday).daysLeft, inInclusiveRange(1, 7));
      // Geçmiş hafta → 0
      expect(board(monday.subtract(const Duration(days: 14))).daysLeft, 0);
    });
  });

  group('weekStart', () {
    test('haftanın pazartesisine yuvarlar', () {
      // 2026-08-06 perşembe → 2026-08-03 pazartesi
      expect(weekStart(DateTime(2026, 8, 6, 23, 59)), DateTime(2026, 8, 3));
      // Pazartesinin kendisi değişmez
      expect(weekStart(DateTime(2026, 8, 3, 0, 1)), DateTime(2026, 8, 3));
      // Pazar aynı haftaya ait
      expect(weekStart(DateTime(2026, 8, 9)), DateTime(2026, 8, 3));
      // Bir sonraki pazartesi yeni hafta
      expect(weekStart(DateTime(2026, 8, 10)), DateTime(2026, 8, 10));
    });
  });

  group('Friendship', () {
    test('durum, isteği kimin gönderdiğine göre belirlenir', () {
      const Friendship pending =
          Friendship(requesterId: 'a', addresseeId: 'b', accepted: false);
      expect(pending.stateFor('a'), FriendState.outgoing);
      expect(pending.stateFor('b'), FriendState.incoming);
      expect(pending.otherId('a'), 'b');

      const Friendship accepted =
          Friendship(requesterId: 'a', addresseeId: 'b', accepted: true);
      expect(accepted.stateFor('a'), FriendState.friends);
      expect(accepted.stateFor('b'), FriendState.friends);
    });
  });
}
