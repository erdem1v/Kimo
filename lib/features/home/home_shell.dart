import 'package:flutter/material.dart';

import '../../data/social_repository.dart';
import '../../data/submission_queue.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/social.dart';
import '../../services/notification_router.dart';
import '../../services/notification_service.dart';
import '../../services/push_service.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/game_progress.dart';
import '../../state/refresh_bus.dart';
import '../../state/user_profile.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_nav_bar.dart';
import '../capture/capture_screen.dart';
import '../mistakes/mistakes_screen.dart';
import '../profile/profile_screen.dart';
import '../league/league_screen.dart';
import 'today_screen.dart';

/// Alt navigasyonlu ana kabuk.
///
/// Sekmeler: **Bugün · Hatalarım · (kamera) · Lig · Profil**.
///
/// Kamera bir sekme değil, ortadaki kalıcı eylem: ürünün çekirdek işi (yanlışını
/// çek) artık her ekrandan tek dokunuş uzakta. Sahte "Koç" sekmesi kaldırıldı.
///
/// Sekmeler [IndexedStack] ile canlı tutulur; dönüşte ekranlar kendini
/// [refreshBus] üzerinden tazeler.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cihaz kaydı ilk denemede düşmüş olabilir (ağ yok, Play Servisleri geç
    // hazır olmuş vb.); uygulama öne geldikçe sessizce tekrar dene.
    if (state == AppLifecycleState.resumed && SupabaseConfig.isConfigured) {
      push.registerDevice();
      _syncNotifyPermission();
      // Çevrimdışıyken verilen cevaplar burada gönderiliyor. Bu olmadan kuyruk
      // yalnızca SOĞUK AÇILIŞTA boşalıyordu: kullanıcı çevrimdışı çözüp
      // bağlantı geri geldiğinde, uygulamayı kapatıp açana kadar hiçbir cevap
      // gitmiyordu — kuyruğun varlık sebebini boşa çıkaran bir boşluktu.
      _drainQueue();
    }
  }

  /// Bekleyen cevapları gönderir ve sunucudan dönen toplamları uygular.
  Future<void> _drainQueue() async {
    try {
      final Map<String, dynamic>? totals = await submissionQueue.flush();
      // gameProgress küresel bir tekil; dispose sonrası uygulamak güvenli ve
      // sunucunun gerçeğini atmaktan iyidir.
      gameProgress.applyServerTotals(totals);
    } catch (e) {
      debugPrint('kuyruk boşaltılamadı: $e');
    }
  }

  /// Kullanıcı telefon ayarlarından bildirimleri kapatmış olabilir; uygulama
  /// içindeki anahtar gerçeği göstersin (yoksa "açık" der ama bildirim gelmez).
  Future<void> _syncNotifyPermission() async {
    if (!userProfile.notifyEnabled) return;
    final bool enabled = await notifications.areEnabled();
    if (!enabled) await userProfile.setNotifyEnabled(false);
  }

  @override
  void initState() {
    super.initState();
    // Profil tercihleri (müfredat, maskot) karşılama akışında alınır; burada
    // yalnızca oturumdaki değerleri belleğe yükleriz.
    if (SupabaseConfig.isConfigured) {
      userProfile.loadFromAuth();
      _bootstrapSocial();
      // Bu cihazı bildirim için kaydet (oturum açıkken).
      push.registerDevice();
    }
    // Bildirimden gelen sekme isteklerini dinle ve bekleyeni uygula.
    NotificationRouter.tabRequest.addListener(_onTabRequest);
    NotificationRouter.ready();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationRouter.tabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final int? tab = NotificationRouter.tabRequest.value;
    if (tab == null || !mounted) return;
    NotificationRouter.tabRequest.value = null;
    if (tab == _index || tab < 0 || tab >= _pages.length) return;
    setState(() => _index = tab);
    refreshBus.ping();
  }

  /// Herkese açık profil satırını hazırlar ve XP/seriyi sunucudan yükler.
  Future<void> _bootstrapSocial() async {
    try {
      // Kuyruk EN BAŞTA boşalmalı ve KENDİ try'ında olmalı. ensureProfile
      // kalıcı olarak da patlayabiliyor (geçersiz takma ad → 22023); o
      // kullanıcıda flush hiçbir açılışta çalışmazdı.
      await _drainQueue();
      await socialRepository.ensureProfile(
        nickname: userProfile.nickname ?? 'Öğrenci',
        mascot: userProfile.mascot,
      );
      // Onaylar artık auth metadata yerine user_consents defterinden okunuyor.
      await userProfile.loadConsents();
      final Map<String, dynamic>? stats = await socialRepository.myStats();
      if (stats != null && mounted) {
        final Object? last = stats['last_activity_date'];
        gameProgress.hydrate(
          xp: (stats['xp'] as int?) ?? 0,
          streak: (stats['streak'] as int?) ?? 0,
          weeklyXp: _weeklyXpFor(stats),
          lastActive: last is String ? DateTime.tryParse(last) : null,
          league: League.fromDb(stats['league'] as String?),
        );
      }
    } catch (_) {
      // Çevrimdışı olabilir; oyunlaştırma yerel değerlerle devam eder.
    }
  }

  /// Haftalık XP yalnızca içinde bulunduğumuz haftaya aitse geçerlidir.
  int _weeklyXpFor(Map<String, dynamic> stats) {
    final Object? ws = stats['week_start'];
    final DateTime? stored = ws is String ? DateTime.tryParse(ws) : null;
    if (stored == null) return 0;
    return stored == weekStart(DateTime.now())
        ? ((stats['weekly_xp'] as int?) ?? 0)
        : 0;
  }

  static const List<Widget> _pages = <Widget>[
    TodayScreen(),
    MistakesScreen(),
    LeagueScreen(),
    ProfileScreen(),
  ];

  void _select(int i) {
    if (_index == i) return;
    sound.tap();
    setState(() => _index = i);
    // Sekmeler canlı tutulduğu için ekranlar kendiliğinden yenilenmez;
    // dönüşte tazeleme sinyali yayınla (gelen istek/soru anında görünsün).
    refreshBus.ping();
  }

  /// Ortadaki kamera düğmesi. Sekme değiştirmez, üstte bir ekran açar:
  /// hangi sekmedeysen oradan çekip aynı yere dönersin.
  Future<void> _capture() async {
    sound.tap();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CaptureScreen()),
    );
    if (!mounted) return;
    refreshBus.ping();
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: KimoNavBar(
        selectedIndex: _index,
        onSelect: _select,
        onCapture: _capture,
        captureLabel: l.navCapture,
        items: <KimoNavItem>[
          KimoNavItem(icon: KimoIcons.home, label: l.navToday),
          KimoNavItem(icon: KimoIcons.notebook, label: l.navMistakes),
          KimoNavItem(icon: KimoIcons.bars, label: l.navLeague),
          KimoNavItem(icon: KimoIcons.person, label: l.navProfile),
        ],
      ),
    );
  }
}
