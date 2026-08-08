import 'package:ai_yks_coach/models/social.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('League.fromXp', () {
    test('eşiklere göre doğru lige yerleştirir', () {
      expect(League.fromXp(0), League.bronz);
      expect(League.fromXp(499), League.bronz);
      expect(League.fromXp(500), League.gumus);
      expect(League.fromXp(1499), League.gumus);
      expect(League.fromXp(1500), League.altin);
      expect(League.fromXp(3500), League.elmas);
      expect(League.fromXp(7500), League.efsane);
      expect(League.fromXp(999999), League.efsane);
    });

    test('en üst ligin sonrası yoktur', () {
      expect(League.efsane.next, isNull);
      expect(League.bronz.next, League.gumus);
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
