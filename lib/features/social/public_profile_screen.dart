import 'package:flutter/material.dart';

import '../../data/social_repository.dart';
import '../../models/social.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';

/// Başka bir kullanıcının profili: ligden ya da arkadaş listesinden açılır.
/// Yalnızca `profiles_public` görünümündeki güvenli alanlar gösterilir.
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.userId, this.initial});

  final String userId;

  /// Listede zaten elimizde olan bilgi: ekran boş açılmasın diye.
  final PublicProfile? initial;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  PublicProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _profile = widget.initial;
    _load();
  }

  Future<void> _load() async {
    final PublicProfile? p = await socialRepository.profileById(widget.userId);
    if (!mounted) return;
    setState(() {
      if (p != null) _profile = p;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final PublicProfile? p = _profile;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Profil')),
      body: p == null
          ? Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text(
                      'Profil bulunamadı.',
                      style: TextStyle(color: AppColors.inkLight),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: <Widget>[
                Center(
                  child: UserAvatar(
                    size: 108,
                    avatarPath: p.avatarPath,
                    mascot: p.mascot,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  p.nickname,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (p.mascot != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Koçu: ${p.mascot!.label}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.inkLight,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ProfileStatsRow(
                  xp: p.xp,
                  streak: p.streak,
                  friends: p.friendCount,
                ),
                const SizedBox(height: 16),
                LeagueBanner(league: p.league, xp: p.xp),
              ],
            ),
    );
  }
}

/// Toplam XP · seri · arkadaş sayısı. Hem kendi profilinde hem başkasınınkinde
/// aynı görünsün diye ortak.
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.xp,
    required this.streak,
    required this.friends,
  });

  final int xp;
  final int streak;
  final int friends;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _card('⚡', '$xp', 'Toplam XP', AppColors.gold)),
        const SizedBox(width: 12),
        Expanded(child: _card('🔥', '$streak', 'Gün seri', AppColors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _card('🤝', '$friends', 'Arkadaş', AppColors.teal)),
      ],
    );
  }

  Widget _card(String emoji, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.inkLight),
          ),
        ],
      ),
    );
  }
}

/// Lig şeridi (profil ekranlarında ortak).
class LeagueBanner extends StatelessWidget {
  const LeagueBanner({super.key, required this.league, required this.xp});

  final League league;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final League? next = league.next;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[league.color, league.color.withValues(alpha: 0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Text(league.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  league.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  next == null
                      ? 'En üst lig 👑'
                      : 'Grubunda ilk ${League.promotionCount} → ${next.label}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
