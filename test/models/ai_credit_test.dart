import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/models/ai_credit.dart';

void main() {
  group('AiState.fromDb', () {
    test('sunucunun altı değeri birebir çevriliyor', () {
      expect(AiState.fromDb('ok'), AiState.ok);
      expect(AiState.fromDb('low'), AiState.low);
      expect(AiState.fromDb('window_full'), AiState.windowFull);
      expect(AiState.fromDb('month_full'), AiState.monthFull);
      expect(AiState.fromDb('lifetime_full'), AiState.lifetimeFull);
      expect(AiState.fromDb('suspended'), AiState.suspended);
    });

    // Bu iddia bir davranışı değil bir DEĞİŞMEZİ koruyor: bilinmeyen bir durum
    // "okunamadı"dır. Varsayılan vermek, arayüzün uydurma bir sayı göstermesine
    // yol açardı — eski `?? 5` / `?? 0` yedeklerinin ürettiği hatanın aynısı.
    test('tanınmayan ve eksik değer null — VARSAYILAN DEĞİL', () {
      expect(AiState.fromDb(null), isNull);
      expect(AiState.fromDb(''), isNull);
      expect(AiState.fromDb('OK'), isNull);
      expect(AiState.fromDb('windowFull'), isNull);
      expect(AiState.fromDb('yeni_bir_durum'), isNull);
    });

    test('hasCredit yalnızca ok ve low için doğru', () {
      expect(AiState.ok.hasCredit, isTrue);
      expect(AiState.low.hasCredit, isTrue);
      expect(AiState.windowFull.hasCredit, isFalse);
      expect(AiState.monthFull.hasCredit, isFalse);
      expect(AiState.lifetimeFull.hasCredit, isFalse);
      expect(AiState.suspended.hasCredit, isFalse);
    });

    test('isWall duvarı açan üç durum için doğru', () {
      expect(AiState.windowFull.isWall, isTrue);
      expect(AiState.monthFull.isWall, isTrue);
      expect(AiState.lifetimeFull.isWall, isTrue);
      expect(AiState.ok.isWall, isFalse);
      expect(AiState.low.isWall, isFalse);
      // Askıya alınmış kullanıcı duvarı değil askı ekranını görüyor.
      expect(AiState.suspended.isWall, isFalse);
    });
  });

  group('AiTier.fromDb', () {
    test('üç katman çevriliyor, bilinmeyen null', () {
      expect(AiTier.fromDb('anonymous'), AiTier.anonymous);
      expect(AiTier.fromDb('free'), AiTier.free);
      expect(AiTier.fromDb('premium'), AiTier.premium);
      expect(AiTier.fromDb('plus'), isNull);
      expect(AiTier.fromDb(null), isNull);
    });
  });
}
