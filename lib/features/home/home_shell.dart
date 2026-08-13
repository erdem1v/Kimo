import 'package:flutter/material.dart';

import '../../data/social_repository.dart';
import '../../models/social.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/game_progress.dart';
import '../../state/refresh_bus.dart';
import '../../state/user_profile.dart';
import '../../theme/app_colors.dart';
import '../chat/chat_screen.dart';
import '../mistakes/mistakes_screen.dart';
import '../profile/profile_screen.dart';
import '../social/social_screen.dart';
import 'home_dashboard.dart';

/// Alt navigasyonlu ana kabuk. Sekmeler [IndexedStack] ile canlı tutulur
/// (sohbet ve durum sekme değişince kaybolmaz).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Profil tercihleri (müfredat, maskot) karşılama akışında alınır; burada
    // yalnızca oturumdaki değerleri belleğe yükleriz.
    if (SupabaseConfig.isConfigured) {
      userProfile.loadFromAuth();
      _bootstrapSocial();
    }
  }

  /// Herkese açık profil satırını hazırlar ve XP/seriyi sunucudan yükler.
  Future<void> _bootstrapSocial() async {
    try {
      await socialRepository.ensureProfile(
        nickname: userProfile.nickname ?? 'Öğrenci',
        mascot: userProfile.mascot,
      );
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
    HomeDashboard(),
    MistakesScreen(),
    SocialScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  static const List<({IconData icon, String label})> _items =
      <({IconData icon, String label})>[
    (icon: Icons.bolt, label: 'Bugün'),
    (icon: Icons.menu_book_rounded, label: 'Hatalarım'),
    (icon: Icons.groups_rounded, label: 'Sosyal'),
    (icon: Icons.forum_rounded, label: 'Koç'),
    (icon: Icons.person_rounded, label: 'Profil'),
  ];

  void _select(int i) {
    if (_index == i) return;
    sound.tap();
    setState(() => _index = i);
    // Sekmeler canlı tutulduğu için ekranlar kendiliğinden yenilenmez;
    // dönüşte tazeleme sinyali yayınla (gelen istek/soru anında görünsün).
    refreshBus.ping();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < _items.length; i++)
                  Expanded(child: _navItem(i)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i) {
    final bool selected = _index == i;
    final Color color = selected ? AppColors.green : AppColors.inkLight;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _select(i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(_items[i].icon, color: color, size: 26),
          const SizedBox(height: 3),
          Text(
            _items[i].label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
