import 'package:flutter/material.dart';

import '../features/inbox/inbox_screen.dart';
import '../features/practice/practice_screen.dart';

/// Bildirime dokunulduğunda hangi ekrana gidileceğini yönetir.
///
/// Hem yerel hatırlatmalar hem de sunucudan gelen push aynı anahtarları
/// kullanır (bkz. NotifyKind.payload ve veritabanındaki push_lines.kind).
///
/// Uygulama kapalıyken gelen dokunuşta gezinme ağacı henüz hazır olmayabilir;
/// bu yüzden istek saklanır ve kabuk hazır olduğunda uygulanır.
class NotificationRouter {
  const NotificationRouter._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Alt navigasyonda gidilmesi istenen sekme (HomeShell dinler).
  static final ValueNotifier<int?> tabRequest = ValueNotifier<int?>(null);

  // Sekme sırası: Bugün · Hatalarım · (kamera) · Lig · Profil.
  // Kamera bir sekme değil, o yüzden dizinlerde yeri yok.
  static const int tabToday = 0;
  static const int tabMistakes = 1;
  static const int tabLeague = 2;

  static String? _pending;
  static bool _ready = false;

  /// Kabuk kurulduğunda çağrılır; bekleyen istek varsa uygulanır.
  static void ready() {
    _ready = true;
    _flush();
  }

  /// Bildirime dokunuldu.
  static void handle(String? kind) {
    if (kind == null || kind.isEmpty) return;
    _pending = kind;
    _flush();
  }

  static void _flush() {
    final String? kind = _pending;
    if (!_ready || kind == null) return;
    _pending = null;

    // Gezinme, çerçeve çizildikten sonra güvenli.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final NavigatorState? nav = navigatorKey.currentState;
      switch (kind) {
        // Tekrar/seri/geri dönüş: doğrudan çözmeye götür.
        case 'reviews_due':
        case 'streak_risk':
        case 'comeback':
          tabRequest.value = tabToday;
          nav?.push(MaterialPageRoute<void>(
              builder: (_) => const PracticeScreen()));

        // Arkadaştan gelen soru: gelen sorular listesi.
        case 'question_received':
          tabRequest.value = tabToday;
          nav?.push(MaterialPageRoute<void>(
              builder: (_) => const InboxScreen()));

        // Lig ve arkadaşlıkla ilgili her şey sosyal sekmesinde.
        case 'league_last_day':
        case 'league_result':
        case 'friend_request':
        case 'question_solved':
        case 'friend_league_up':
        case 'friend_streak':
          tabRequest.value = tabLeague;

        default:
          tabRequest.value = tabToday;
      }
    });
  }
}
