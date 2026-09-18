import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/services/notification_router.dart';

/// Bildirim yönlendirmesi (Task 18). İki sözleşme:
///
/// 1. TABLO: hangi tür hangi sekmeye ve hangi rotaya. Sunucunun `push_kinds`
///    listesindeki her tür burada bir satıra düşmeli; yeni bir tür sessizce
///    `default`a (Bugün, rota yok) kayarsa kullanıcı "tekrarın hazır"
///    bildirimine dokunup ana ekranda kalır.
/// 2. TAMPON: kabuk kurulmadan gelen dokunuş KAYBOLMAZ — `ready()` gelince
///    uygulanır. Soğuk açılışta bildirimle gelen kullanıcı hedefine ulaşmalı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(NotificationRouter.resetForTest);
  tearDown(NotificationRouter.resetForTest);

  test('tekrar/seri/geri dönüş → Bugün + Tekrar ekranı', () {
    for (final String k in <String>['reviews_due', 'streak_risk', 'comeback']) {
      final NotificationTarget t = NotificationRouter.decide(k);
      expect(t.tab, NotificationRouter.tabToday, reason: k);
      expect(t.route, NotificationRoute.practice, reason: k);
    }
  });

  test('gelen soru → Bugün + Gelen kutusu', () {
    final NotificationTarget t = NotificationRouter.decide('question_received');
    expect(t.tab, NotificationRouter.tabToday);
    expect(t.route, NotificationRoute.inbox);
  });

  test('lig ve arkadaşlık türleri → Lig sekmesi, rota yok', () {
    for (final String k in <String>[
      'league_last_day',
      'league_result',
      'friend_request',
      'question_solved',
      'friend_league_up',
      'friend_streak',
    ]) {
      final NotificationTarget t = NotificationRouter.decide(k);
      expect(t.tab, NotificationRouter.tabLeague, reason: k);
      expect(t.route, isNull, reason: k);
    }
  });

  test('bilinmeyen tür çökmüyor: Bugün, rota yok', () {
    final NotificationTarget t = NotificationRouter.decide('yeni_tur');
    expect(t.tab, NotificationRouter.tabToday);
    expect(t.route, isNull);
  });

  testWidgets('boş tür yok sayılıyor', (WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    NotificationRouter.ready();
    NotificationRouter.handle('');
    NotificationRouter.handle(null);
    await tester.pump();
    expect(NotificationRouter.tabRequest.value, isNull);
  });
  testWidgets('kabuk hazır olmadan gelen dokunuş TAMPONLANIYOR',
      (WidgetTester tester) async {
    // Çerçeve-sonu geri çağrısı için bir ağaç gerekiyor.
    await tester.pumpWidget(const SizedBox());
    NotificationRouter.handle('friend_request');
    await tester.pump();
    expect(NotificationRouter.tabRequest.value, isNull,
        reason: 'kabuk yokken sekme isteği uygulanmamalı');
    NotificationRouter.ready();
    // Çerçeve-sonu geri çağrısı: bir kare kur, bir kare çiz.
    await tester.pump();
    await tester.pump();
    expect(NotificationRouter.tabRequest.value, NotificationRouter.tabLeague,
        reason: 'ready() gelince bekleyen dokunuş uygulanmalı');
  });

}
