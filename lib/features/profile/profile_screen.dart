import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/mock_data.dart';
import '../../data/social_repository.dart';
import '../../models/models.dart';
import '../../models/social.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/game_progress.dart';
import '../../state/refresh_bus.dart';
import '../../state/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_widgets.dart';
import '../../widgets/user_avatar.dart';
import '../social/public_profile_screen.dart';
import 'settings_screen.dart';

/// Kendi profilim: fotoğraf, takma ad, toplam XP, seri, arkadaş sayısı ve lig.
/// Tercihler ve yönetim girişleri [SettingsScreen] içinde — bu ekran kimliğe
/// ayrılmıştır, ayar listesine değil.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _friendCount = 0;
  bool _uploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      _loadFriendCount();
      refreshBus.addListener(_loadFriendCount);
    }
  }

  @override
  void dispose() {
    refreshBus.removeListener(_loadFriendCount);
    super.dispose();
  }

  /// Arkadaş sayısı kendi açık profilimden okunur (görünüm sayıyor).
  Future<void> _loadFriendCount() async {
    final PublicProfile? me = await socialRepository.myProfile();
    if (mounted && me != null) setState(() => _friendCount = me.friendCount);
  }

  /// Profil fotoğrafı seç → yükle → profile yaz.
  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _uploadingAvatar = true);
      final String? path = await socialRepository.uploadAvatar(bytes);
      if (path != null) await userProfile.setAvatarPath(path);
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf yüklenemedi. Tekrar dene.')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    await socialRepository.removeAvatar();
    await userProfile.setAvatarPath(null);
    if (mounted) setState(() {});
  }

  /// Fotoğraf kaynağı seçimi (kamera / galeri / kaldır).
  void _avatarSheet() {
    sound.tap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 12),
            const Text(
              'Profil fotoğrafı',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: AppColors.purple,
              ),
              title: const Text('Fotoğraf çek'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.blue,
              ),
              title: const Text('Galeriden seç'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAvatar(ImageSource.gallery);
              },
            ),
            if (userProfile.avatarPath != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.red,
                ),
                title: const Text('Fotoğrafı kaldır'),
                subtitle: const Text(
                  'Koçunun simgesi görünür',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _removeAvatar();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profil'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Ayarlar',
            onPressed: () {
              sound.tap();
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[gameProgress, userProfile]),
        builder: (BuildContext context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: <Widget>[
              _header(),
              const SizedBox(height: 22),
              ProfileStatsRow(
                xp: gameProgress.xp,
                streak: gameProgress.currentStreak,
                friends: _friendCount,
              ),
              const SizedBox(height: 16),
              LeagueBanner(league: gameProgress.league, xp: gameProgress.xp),
              const SizedBox(height: 24),
              const SectionTitle('Rozetler'),
              const SizedBox(height: 12),
              _badges(),
            ],
          );
        },
      ),
    );
  }

  Widget _header() {
    return Column(
      children: <Widget>[
        // Fotoğrafa dokununca değiştirme sayfası açılır.
        GestureDetector(
          onTap: _uploadingAvatar ? null : _avatarSheet,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: <Widget>[
              UserAvatar(
                size: 104,
                avatarPath: userProfile.avatarPath,
                mascot: userProfile.mascot,
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: _uploadingAvatar
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.photo_camera_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          userProfile.nickname ?? 'Öğrenci',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ],
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
              color: b.earned
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.line,
              shape: BoxShape.circle,
            ),
            child: Text(
              b.earned ? b.emoji : '🔒',
              style: const TextStyle(fontSize: 26),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            b.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
