import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/auth_repository.dart';
import '../../data/moderation_repository.dart';
import '../../data/mock_data.dart';
import '../../data/social_repository.dart';
import '../../models/models.dart';
import '../../services/notification_service.dart';
import '../../services/push_service.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../services/system_settings.dart';
import '../../state/game_progress.dart';
import '../../state/refresh_bus.dart';
import '../../state/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_widgets.dart';
import '../../widgets/user_avatar.dart';
import '../social/public_profile_screen.dart';
import '../../models/mascot.dart';
import '../../models/social.dart';
import '../admin/all_questions_screen.dart';
import '../admin/moderation_screen.dart';
import '../onboarding/exam_year_sheet.dart';
import '../onboarding/mascot_sheet.dart';

/// Profil / oyunlaştırma vitrini: seviye, seri, lig ve rozetler.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isAdmin = false;
  int _friendCount = 0;
  bool _uploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      moderationRepository.isAdmin().then((bool v) {
        if (mounted && v) setState(() => _isAdmin = true);
      });
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
              const SizedBox(height: 24),
              _soundToggle(),
              if (SupabaseConfig.isConfigured) ...<Widget>[
                const SizedBox(height: 12),
                _mascotTile(),
                const SizedBox(height: 12),
                _notifyTile(),
                const SizedBox(height: 12),
                _shareConsentTile(),
                const SizedBox(height: 12),
                _curriculumTile(),
                if (_isAdmin) ...<Widget>[
                  const SizedBox(height: 12),
                  _moderationTile(),
                  const SizedBox(height: 12),
                  _allQuestionsTile(),
                ],
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

  Widget _soundToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: sound.enabled,
        title: const Text(
          'Ses efektleri',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        secondary: const Icon(Icons.volume_up_rounded, color: AppColors.green),
        onChanged: (bool v) => setState(() => sound.enabled = v),
      ),
    );
  }

  Widget _mascotTile() {
    return ListenableBuilder(
      listenable: userProfile,
      builder: (BuildContext context, _) {
        final Mascot? m = userProfile.mascot;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (m?.color ?? AppColors.purple).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                m?.emoji ?? '🐻',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            title: const Text(
              'Koçun',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              m?.label ?? 'Seçilmedi — dokunup seç',
              style: const TextStyle(color: AppColors.inkLight, fontSize: 13),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.inkLight,
            ),
            onTap: () => showMascotSheet(context),
          ),
        );
      },
    );
  }

  /// İzin alınamadığında: tek dokunuşla telefonun bildirim ayarına götür.
  Future<void> _offerSettings() async {
    final Mascot m = userProfile.mascot ?? Mascot.evHanimi;
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Row(
          children: <Widget>[
            Text(m.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Bildirimler kapalı')),
          ],
        ),
        content: const Text(
          'Telefonun bildirim iznini kapatmış. Ayarlarda "Bildirimleri göster" '
          'anahtarını açarsan seni tekrar zamanı geldiğinde dürtebilirim.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Şimdi değil'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ayarları aç'),
          ),
        ],
      ),
    );
    if (go == true) await SystemSettings.openNotificationSettings();
  }

  /// Maskot hatırlatmaları: açma/kapama ve saat ayarı.
  Widget _notifyTile() {
    final Mascot m = userProfile.mascot ?? Mascot.evHanimi;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          SwitchListTile(
            value: userProfile.notifyEnabled,
            activeThumbColor: m.color,
            secondary: Text(m.emoji, style: const TextStyle(fontSize: 22)),
            title: const Text(
              'Hatırlatmalar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              userProfile.notifyEnabled
                  ? 'Tekrar ${userProfile.reviewHour}:00 · '
                        'seri ${userProfile.streakHour}:00'
                  : 'Kapalı',
              style: const TextStyle(color: AppColors.inkLight, fontSize: 12.5),
            ),
            onChanged: (bool v) async {
              // Açarken sistem izni gerekebilir.
              bool ok = v;
              if (v) ok = await notifications.requestPermission();
              await userProfile.setNotifyEnabled(ok);
              if (!ok) await notifications.cancelAll();
              if (mounted) setState(() {});
              // İzin reddedildiyse (ya da daha önce kalıcı reddedilmişse)
              // sistem penceresi açılmaz; kullanıcıyı ayara yönlendir.
              if (v && !ok && mounted) await _offerSettings();
            },
          ),
          if (userProfile.notifyEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _hourPicker(
                      label: 'Tekrar',
                      value: userProfile.reviewHour,
                      onPick: (int h) => userProfile.setNotifyHours(review: h),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _hourPicker(
                      label: 'Seri',
                      value: userProfile.streakHour,
                      onPick: (int h) => userProfile.setNotifyHours(streak: h),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _hourPicker({
    required String label,
    required int value,
    required void Function(int) onPick,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          isExpanded: true,
          // Sessiz saat dışı: 08:00–21:00
          items: <DropdownMenuItem<int>>[
            for (int h = 8; h <= 21; h++)
              DropdownMenuItem<int>(
                value: h,
                child: Text(
                  '$h:00',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
          onChanged: (int? h) {
            if (h != null) onPick(h);
          },
        ),
      ),
    );
  }

  /// Soru havuzu paylaşım izni. Kapatınca sonraki yüklemeler paylaşılmaz.
  Widget _shareConsentTile() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: userProfile.shareConsent,
        onChanged: (bool v) => userProfile.setShareConsent(v),
        activeThumbColor: AppColors.purple,
        secondary: const Text('🌍', style: TextStyle(fontSize: 22)),
        title: const Text(
          'Sorularımı havuzda paylaş',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          userProfile.shareConsent
              ? 'Yeni yüklediğin sorular diğer öğrencilerce çözülebilir.'
              : 'Kapalı: yüklediğin sorular sana özel kalır.',
          style: const TextStyle(color: AppColors.inkLight, fontSize: 12.5),
        ),
      ),
    );
  }

  Widget _curriculumTile() {
    return ListenableBuilder(
      listenable: userProfile,
      builder: (BuildContext context, _) {
        final int? year = userProfile.examYear;
        final String subtitle = year == null
            ? 'Belirlenmedi — dokunup seç'
            : '$year · ${userProfile.curriculum == UserProfile.maarif ? 'Yeni müfredat (Maarif)' : 'Mevcut müfredat (2018)'}';
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const Icon(Icons.school_rounded, color: AppColors.blue),
            title: const Text(
              'Sınav yılı / müfredat',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(color: AppColors.inkLight, fontSize: 13),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.inkLight,
            ),
            onTap: () => showExamYearSheet(context),
          ),
        );
      },
    );
  }

  /// Yalnızca moderatörlere görünen şikayet kuyruğu girişi.
  Widget _moderationTile() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.30)),
      ),
      child: ListTile(
        leading: const Icon(Icons.shield_outlined, color: AppColors.red),
        title: const Text(
          'Moderasyon kuyruğu',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Bildirilen soruları incele',
          style: TextStyle(color: AppColors.inkLight, fontSize: 13),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.inkLight,
        ),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const ModerationScreen()),
        ),
      ),
    );
  }

  /// Moderatör: tüm soruları görüp düzeltme.
  Widget _allQuestionsTile() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.30)),
      ),
      child: ListTile(
        leading: const Icon(Icons.fact_check_outlined, color: AppColors.purple),
        title: const Text(
          'Tüm sorular',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Ders/konu/sınav düzelt, havuzdan çıkar, sil',
          style: TextStyle(color: AppColors.inkLight, fontSize: 13),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.inkLight,
        ),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AllQuestionsScreen()),
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          // Bu cihazın bildirim kaydını sil, sonra çık: başkasının
          // bildirimleri bu telefona düşmesin.
          await push.unregisterDevice();
          await notifications.cancelAll();
          await authRepository.signOut();
        },
        icon: const Icon(Icons.logout_rounded, color: AppColors.red),
        label: const Text(
          'Çıkış yap',
          style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
