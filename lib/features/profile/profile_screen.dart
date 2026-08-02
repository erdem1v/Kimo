import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/game_progress.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_widgets.dart';

/// Profil / oyunlaştırma vitrini: seviye, seri, lig ve rozetler.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profil'),
      ),
      body: ListenableBuilder(
        listenable: gameProgress,
        builder: (BuildContext context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: <Widget>[
              _header(),
              const SizedBox(height: 20),
              _levelCard(),
              const SizedBox(height: 16),
              _statsRow(),
              const SizedBox(height: 16),
              _leagueCard(),
              const SizedBox(height: 24),
              const SectionTitle('Rozetler'),
              const SizedBox(height: 12),
              _badges(),
              const SizedBox(height: 24),
              _soundToggle(),
              if (SupabaseConfig.isConfigured) ...<Widget>[
                const SizedBox(height: 12),
                _logoutButton(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _header() {
    return Row(
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: AppColors.greenBg, shape: BoxShape.circle),
          child: const Text('🎓', style: TextStyle(fontSize: 30)),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Öğrenci',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('⚡ Seviye ${gameProgress.level}',
                  style: const TextStyle(
                      color: AppColors.goldDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _levelCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Seviye ilerlemesi',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(
                  '${gameProgress.xpIntoLevel} / ${GameProgress.xpPerLevel} XP',
                  style: const TextStyle(
                      color: AppColors.inkLight, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          RoundedProgressBar(
              value: gameProgress.levelProgress, color: AppColors.gold),
          const SizedBox(height: 8),
          Text('Seviye ${gameProgress.level + 1}\'e az kaldı!',
              style: const TextStyle(color: AppColors.inkLight, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: <Widget>[
        Expanded(
            child: _statCard('🔥', '${gameProgress.streak}', 'Gün seri',
                AppColors.orange)),
        const SizedBox(width: 12),
        Expanded(
            child:
                _statCard('💎', '${gameProgress.gems}', 'Elmas', AppColors.blue)),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard(
                '❤️', '${gameProgress.hearts}', 'Can', AppColors.red)),
      ],
    );
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.inkLight)),
        ],
      ),
    );
  }

  Widget _leagueCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.blue, AppColors.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          const Text('🏅', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text('Elmas Ligi',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Bu hafta 3. sıradasın · 340 XP',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badges() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: <Widget>[
        for (final AchievementBadge b in MockData.badges) _badge(b),
      ],
    );
  }

  Widget _badge(AchievementBadge b) {
    return Opacity(
      opacity: b.earned ? 1 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: b.earned ? AppColors.gold.withValues(alpha: 0.2) : AppColors.line,
              shape: BoxShape.circle,
            ),
            child: Text(b.earned ? b.emoji : '🔒',
                style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 6),
          Text(
            b.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  Widget _soundToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: sound.enabled,
        title: const Text('Ses efektleri',
            style: TextStyle(fontWeight: FontWeight.w700)),
        secondary: const Icon(Icons.volume_up_rounded, color: AppColors.green),
        onChanged: (bool v) => setState(() => sound.enabled = v),
      ),
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => authRepository.signOut(),
        icon: const Icon(Icons.logout_rounded, color: AppColors.red),
        label: const Text('Çıkış yap',
            style:
                TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
