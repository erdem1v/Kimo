import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/friend_repository.dart';

/// Ortak serinin İSTEMCİ TARAFI KARARLARI (Tur 7 · n6).
///
/// BU DOSYANIN KONUSU TEK BİR DİL KURALI: arayüz KİMİN ÇÖZMEDİĞİNİ söylemiyor.
/// `friendToday` alanı modelde var ama "arkadaşın çözmedi" diye gösterilmiyor;
/// risk satırı yalnızca KULLANICININ KENDİ PAYI eksikken çıkıyor. "Arkadaşın
/// seni bekliyor" ifadesi arkadaşı baskı aracına çevirirdi.
PairStreak p({
  int streak = 5,
  bool me = true,
  bool friend = true,
}) =>
    PairStreak(
      friendId: 'f1',
      nickname: 'Mert',
      streak: streak,
      best: 9,
      meToday: me,
      friendToday: friend,
    );

void main() {
  group('myTurn — risk satırının tek koşulu', () {
    test('kendi payım eksikse benim sıram', () {
      expect(p(me: false).myTurn, isTrue);
    });

    test('kendi payımı yaptıysam risk satırı ÇIKMIYOR', () {
      // Arkadaş çözmemiş olsa BİLE: onun eksiği bana bir uyarı olarak
      // gösterilmiyor.
      expect(p(me: true, friend: false).myTurn, isFalse);
    });
  });

  group('safeToday', () {
    test('ikisi de çözdüyse gün tamam', () {
      expect(p().safeToday, isTrue);
    });

    test('biri eksikse gün tamam DEĞİL', () {
      expect(p(me: false).safeToday, isFalse);
      expect(p(friend: false).safeToday, isFalse);
    });
  });

  group('fromRow', () {
    test('sunucu alanları birebir okunuyor', () {
      final PairStreak s = PairStreak.fromRow(<String, dynamic>{
        'friend_id': 'u2',
        'nickname': 'Deniz',
        'streak': 12,
        'best': 30,
        'me_today': true,
        'friend_today': false,
        'avatar_path': 'u2/a.jpg',
      });
      expect(s.friendId, 'u2');
      expect(s.streak, 12);
      expect(s.best, 30);
      expect(s.meToday, isTrue);
      expect(s.friendToday, isFalse);
      expect(s.avatarPath, 'u2/a.jpg');
    });

    test('eksik alanlar UYDURULMUYOR: sayılar 0, bayraklar false', () {
      final PairStreak s = PairStreak.fromRow(<String, dynamic>{
        'friend_id': 'u3',
      });
      expect(s.streak, 0);
      expect(s.meToday, isFalse);
      expect(s.avatarPath, isNull);
      // Seri 0 ise arkadaş satırında rozet ÇİZİLMİYOR — boş durum
      // gösterilmiyor.
      expect(s.streak > 0, isFalse);
    });
  });
}
