import 'package:ai_yks_coach/models/social.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('League', () {
    test('lig veritabanı değerinden okunur (XP eşiği yok)', () {
      expect(League.fromDb('bronz'), League.bronz);
      expect(League.fromDb('gumus'), League.gumus);
      expect(League.fromDb('altin'), League.altin);
      expect(League.fromDb('elmas'), League.elmas);
      expect(League.fromDb('efsane'), League.efsane);
      // Bilinmeyen/boş değer en alt lige düşer.
      expect(League.fromDb(null), League.bronz);
      expect(League.fromDb('saçma'), League.bronz);
    });

    test('terfi zinciri doğru, en üstün sonrası yok', () {
      expect(League.bronz.next, League.gumus);
      expect(League.gumus.next, League.altin);
      expect(League.altin.next, League.elmas);
      expect(League.elmas.next, League.efsane);
      expect(League.efsane.next, isNull);
    });

    test('grup ve terfi sayıları', () {
      expect(League.cohortSize, 15);
      expect(League.promotionCount, 5);
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
