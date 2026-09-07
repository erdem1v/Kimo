import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/daily_state_repository.dart';
import '../../data/social_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/social.dart';
import '../../services/sound_service.dart';
import '../../state/app_settings.dart';
import '../../state/game_progress.dart';
import '../../state/refresh_bus.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_progress.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../../widgets/user_avatar.dart';
import 'settings_screen.dart';

/// Profil sekmesi.
///
/// Kimliğe ayrılmış: fotoğraf, takma ad, seviye şeridi, üç sayı ve lig.
/// Ayarlar **tek girişten** (sağ üst) açılıyor; tasarımın istediği bu.
/// Tema anahtarı ayrıca burada da var — en sık değiştirilen tercih ve onun
/// için ayrı bir ekrana girmek gereksiz.
///
/// **Sahte rozet ızgarası kaldırıldı.** Eski profilde altı rozet vardı
/// (üçü "kazanılmış", üçü "kilitli") ve hepsi `MockData` sabitiydi — hiçbiri
/// gerçek bir başarıya bağlı değildi. Gerçek bir rozet sistemi ayrı bir iş.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  int _friendCount = 0;
  bool _uploading = false;
  DailyState? _state;

  @override
  void initState() {
    super.initState();
    _load();
    refreshBus.addListener(_load);
  }

  @override
  void dispose() {
    refreshBus.removeListener(_load);
    super.dispose();
  }

  /// Üst üste binen yüklemelere karşı kilit: `refreshBus` her sekme
  /// geçişinde ping'liyor ve bu ekranda kilit yoktu — hızlı sekme geçişleri
  /// yarışan yüklemeler üretiyordu.
  bool _loadingProfile = false;

  Future<void> _load() async {
    if (_loadingProfile) return;
    _loadingProfile = true;
    try {
      // İki sorgu bağımsız: paralel (Task 03, 10.2 deseni).
      final List<Object?> parts = await Future.wait<Object?>(<Future<Object?>>[
        socialRepository.myProfile(),
        dailyStateRepository.read(),
      ]);
      if (!mounted) return;
      final PublicProfile? me = parts[0] as PublicProfile?;
      final DailyState? s = parts[1] as DailyState?;
      setState(() {
        if (me != null) _friendCount = me.friendCount;
        _state = s;
      });
    } finally {
      _loadingProfile = false;
    }
  }

  // -------------------------------------------------------------- fotoğraf

  Future<void> _pickAvatar(ImageSource source) async {
    final L10n l = L10n.of(context);
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        // imageQuality YÜK TAŞIYOR: iOS'ta HEIC→JPEG dönüşümünü bu zorluyor
        // (bkz. capture_screen'deki not).
        imageQuality: 85,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _uploading = true);
      final String path = await socialRepository.uploadAvatar(bytes);
      await userProfile.setAvatarPath(path);
      if (!mounted) return;
      setState(() => _uploading = false);
    } on AvatarException catch (e) {
      // Sebebi kullanıcıya söylüyoruz: bu akış eskiden sessizce başarısız
      // oluyordu ve "yükledim ama görünmüyor" durumu teşhis edilemiyordu.
      if (!mounted) return;
      setState(() => _uploading = false);
      _snack(e.message);
    } catch (e) {
      debugPrint('avatar yüklenemedi: $e');
      if (!mounted) return;
      setState(() => _uploading = false);
      _snack(l.profileAvatarFailed);
    }
  }

  Future<void> _removeAvatar() async {
    try {
      await socialRepository.removeAvatar();
      await userProfile.setAvatarPath(null);
      if (mounted) setState(() {});
    } on AvatarException catch (e) {
      // Dosya gerçekten silinemediyse kullanıcı bunu bilmeli — "kaldırdım"
      // deyip dosyayı depoda bırakmak, düzeltmeye çalıştığımız davranışın ta
      // kendisi.
      if (mounted) _snack(e.message);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _avatarSheet() {
    sound.tap();
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.screen,
          Gap.screen,
          Gap.screen + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l.profileAvatarChange, style: t.section),
            const SizedBox(height: Gap.lg),
            KimoButton(
              label: l.profileAvatarCamera,
              icon: const KimoIcon(KimoIcons.camera, size: 20),
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickAvatar(ImageSource.camera);
              },
            ),
            const SizedBox(height: Gap.sm),
            KimoButton(
              label: l.profileAvatarGallery,
              kind: KimoButtonKind.secondary,
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickAvatar(ImageSource.gallery);
              },
            ),
            if (userProfile.avatarPath != null) ...<Widget>[
              const SizedBox(height: Gap.sm),
              KimoButton(
                label: l.profileAvatarRemove,
                kind: KimoButtonKind.tertiary,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _removeAvatar();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- yapı

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge(
              <Listenable>[gameProgress, userProfile, appSettings]),
          builder: (BuildContext context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(
                Gap.screen, 0, Gap.screen, Gap.section),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(l.profileTitle, style: t.title)),
                  IconButton(
                    onPressed: () {
                      sound.tap();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: KimoIcon(KimoIcons.settings, color: c.ink),
                    tooltip: l.profileSettings,
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              _header(context, l),
              const SizedBox(height: Gap.xl),
              _levelCard(context, l),
              const SizedBox(height: Gap.md),
              _stats(context, l),
              const SizedBox(height: Gap.md),
              _leagueCard(context),
              const SizedBox(height: Gap.md),
              _themeCard(context, l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: _uploading ? null : _avatarSheet,
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
                  color: c.action,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.page, width: 2.5),
                ),
                child: _uploading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.onAction,
                        ),
                      )
                    : KimoIcon(KimoIcons.camera, size: 14, color: c.onAction),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        Text(
          userProfile.nickname ?? l.defaultNickname,
          textAlign: TextAlign.center,
          style: t.heading,
        ),
      ],
    );
  }

  /// Seviye şeridi. Seviye ayrı bir sayaç değil, toplam XP'nin okunuşu:
  /// `xp ~/ 1000 + 1`.
  Widget _levelCard(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    final DailyState? s = _state;
    // Sunucu okunamadıysa yerel (iyimser) XP kullanılıyor; ikisi de aynı
    // formülü uyguluyor, dolayısıyla gösterilen seviye tutarlı.
    final int xp = s?.xp ?? gameProgress.xp;
    final int level = xp ~/ DailyState.xpPerLevel + 1;
    final int inLevel = xp % DailyState.xpPerLevel;
    return KimoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l.profileLevelProgress(level, inLevel, DailyState.xpPerLevel),
            style: t.bodyStrong,
          ),
          const SizedBox(height: Gap.sm),
          KimoProgressBar(value: inLevel / DailyState.xpPerLevel),
        ],
      ),
    );
  }

  Widget _stats(BuildContext context, L10n l) {
    final DailyState? s = _state;
    return Row(
      children: <Widget>[
        Expanded(
          child: _stat(context, '${s?.xp ?? gameProgress.xp}', l.profileXp),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: _stat(
            context,
            '${s?.streak ?? gameProgress.currentStreak}',
            l.profileStreak,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(child: _stat(context, '$_friendCount', l.profileFriends)),
      ],
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
      child: Column(
        children: <Widget>[
          Text(value, style: t.numberLarge),
          const SizedBox(height: Gap.xxs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _leagueCard(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final League league = _state?.league ?? gameProgress.league;
    return KimoCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: league.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(league.label, style: t.bodyStrong)),
          if (_state != null)
            StatusBadge(
              label: '${_state!.gems}',
              tone: BadgeTone.mastered,
            )
          else
            KimoIcon(KimoIcons.gem, size: 18, color: c.inkMuted),
        ],
      ),
    );
  }

  /// Tema anahtarı burada da var (tasarım kararı): en sık değiştirilen
  /// tercih, ayarlara girmeden ulaşılabilsin.
  Widget _themeCard(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    const List<ThemeMode> modes = <ThemeMode>[
      ThemeMode.system,
      ThemeMode.light,
      ThemeMode.dark,
    ];
    return KimoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.settingsTheme, style: t.bodyStrong),
          const SizedBox(height: Gap.md),
          SegmentedTabs(
            labels: <String>[l.themeSystem, l.themeLight, l.themeDark],
            selectedIndex: modes.indexOf(appSettings.themeMode),
            onChanged: (int i) {
              sound.tap();
              appSettings.setThemeMode(modes[i]);
            },
          ),
        ],
      ),
    );
  }
}
