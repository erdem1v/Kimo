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

    final NotificationTarget target = decide(kind);
    // Gezinme, çerçeve çizildikten sonra güvenli. `ensureVisualUpdate`: çerçeve
    // planlı değilse (soğuk açılışta bildirimle gelen kullanıcı, kabuk henüz
    // boşta) geri çağrı bir sonraki DOKUNUŞA kadar bekliyordu — testte de
    // görüldü: pompalanan kare geri çağrıyı çalıştırmıyordu.
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final NavigatorState? nav = navigatorKey.currentState;
      tabRequest.value = target.tab;
      switch (target.route) {
        case NotificationRoute.practice:
          nav?.push(MaterialPageRoute<void>(
              builder: (_) => const PracticeScreen()));
        case NotificationRoute.inbox:
          nav?.push(MaterialPageRoute<void>(
              builder: (_) => const InboxScreen()));
        case null:
          break;
      }
    });
  }

  /// Bildirim türü → sekme + itilecek rota. SAF: widget kurmuyor.
  ///
  /// Tablo buraya çıkarıldı (Task 18) ki `PracticeScreen`/`InboxScreen`
  /// kurmadan sınanabilsin — ikisi de `initState`te ağa çıkıyor ve testte
  /// `Supabase.instance` yok. Bir tür yanlış sekmeye düşerse ya da yeni bir
  /// tür `default`a kayarsa bu tablo kırmızı döner; eskiden kimse görmezdi.
  static NotificationTarget decide(String kind) => switch (kind) {
        // Tekrar/seri/geri dönüş: doğrudan çözmeye götür.
        'reviews_due' || 'streak_risk' || 'comeback' =>
          const NotificationTarget(tabToday, NotificationRoute.practice),
        // Arkadaştan gelen soru: gelen sorular listesi.
        'question_received' =>
          const NotificationTarget(tabToday, NotificationRoute.inbox),
        // Lig ve arkadaşlıkla ilgili her şey sosyal sekmesinde.
        'league_last_day' ||
        'league_result' ||
        'friend_request' ||
        'question_solved' ||
        'friend_league_up' ||
        'friend_streak' =>
          const NotificationTarget(tabLeague, null),
        _ => const NotificationTarget(tabToday, null),
      };

  /// Testler için: tampon ve hazır bayrağı sıfırlanır.
  @visibleForTesting
  static void resetForTest() {
    _pending = null;
    _ready = false;
    tabRequest.value = null;
  }
}

/// Bildirim dokunuşunun düştüğü yer.
class NotificationTarget {
  const NotificationTarget(this.tab, this.route);
  final int tab;
  final NotificationRoute? route;
}

enum NotificationRoute { practice, inbox }
