import 'package:flutter/material.dart';
import 'package:system_settings/system_settings.dart';

import '../../data/auth_repository.dart';
import '../../data/daily_state_repository.dart';
import '../../data/moderation_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/app_settings.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../admin/all_questions_screen.dart';
import '../admin/moderation_screen.dart';
import '../onboarding/exam_year_sheet.dart';
import '../onboarding/mascot_sheet.dart';
import '../settings/delete_account_screen.dart';

/// Tek ayarlar ekranı. Profilden sağ üstteki tek girişten açılıyor.
///
/// **Havuza paylaşım anahtarı kaldırıldı** (havuz arayüzden çıktı).
/// **Eklenenler:** tema seçimi, bildirim saatleri, kullanıcı tanımlı sessiz
/// aralık, doğum yılı/veli onayı durumu ve hesap silme.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAdmin = false;
  GuardianStatus? _guardian;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      _load();
    }
  }

  Future<void> _load() async {
    final bool admin = await moderationRepository.isAdmin();
    final GuardianStatus? g = await dailyStateRepository.guardianStatus();
    if (!mounted) return;
    setState(() {
      _isAdmin = admin;
      _guardian = g;
    });
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);

    return Scaffold(
      backgroundColor: c.page,
      appBar: AppBar(
        backgroundColor: c.page,
        surfaceTintColor: Colors.transparent,
        title: Text(l.settingsTitle, style: t.section),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: KimoIcon(KimoIcons.back, color: c.ink),
          tooltip: l.actionBack,
        ),
      ),
      body: ListenableBuilder(
        // Hem profil hem tercihler dinleniyor: tema ve ses `appSettings`'ten,
        // maskot ve sınav yılı `userProfile`'dan.
        listenable: Listenable.merge(<Listenable>[userProfile, appSettings]),
        builder: (BuildContext context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
              Gap.screen, Gap.md, Gap.screen, Gap.section),
          children: <Widget>[
            SectionHeader(title: l.settingsAppearance),
            const SizedBox(height: Gap.md),
            _themeCard(context, l),
            const SizedBox(height: Gap.sm),
            _soundCard(context, l),
            if (SupabaseConfig.isConfigured) ...<Widget>[
              const SizedBox(height: Gap.xl),
              SectionHeader(title: l.settingsNotifications),
              const SizedBox(height: Gap.md),
              _notifyCard(context, l),
              if (userProfile.notifyEnabled) ...<Widget>[
                const SizedBox(height: Gap.sm),
                _hourCard(
                  context,
                  label: l.settingsReviewHour,
                  hour: appSettings.reviewHour,
                  onPick: appSettings.setReviewHour,
                ),
                const SizedBox(height: Gap.sm),
                _hourCard(
                  context,
                  label: l.settingsStreakHour,
                  hour: appSettings.streakHour,
                  onPick: appSettings.setStreakHour,
                ),
                const SizedBox(height: Gap.sm),
                _quietCard(context, l),
              ],
              const SizedBox(height: Gap.xl),
              SectionHeader(title: l.settingsAccount),
              const SizedBox(height: Gap.md),
              _row(
                context,
                icon: KimoIcons.person,
                label: l.settingsMascot,
                value: userProfile.mascot?.label,
                onTap: () {
                  sound.tap();
                  showMascotSheet(context);
                },
              ),
              const SizedBox(height: Gap.sm),
              _row(
                context,
                icon: KimoIcons.notebook,
                label: l.settingsExamYear,
                value: userProfile.examYear?.toString(),
                onTap: () {
                  sound.tap();
                  showExamYearSheet(context);
                },
              ),
              const SizedBox(height: Gap.sm),
              _guardianRow(context, l),
              if (_isAdmin) ...<Widget>[
                const SizedBox(height: Gap.xl),
                SectionHeader(title: l.settingsAdmin),
                const SizedBox(height: Gap.md),
                _row(
                  context,
                  icon: KimoIcons.flag,
                  label: l.settingsModeration,
                  onTap: () => _push(const ModerationScreen()),
                ),
                const SizedBox(height: Gap.sm),
                _row(
                  context,
                  icon: KimoIcons.bars,
                  label: l.settingsAllQuestions,
                  onTap: () => _push(const AllQuestionsScreen()),
                ),
              ],
              const SizedBox(height: Gap.xl),
              KimoButton(
                label: l.settingsSignOut,
                kind: KimoButtonKind.tertiary,
                onPressed: () async {
                  sound.tap();
                  await authRepository.signOut();
                },
              ),
              const SizedBox(height: Gap.sm),
              // Silme en altta ve tek başına: yanlışlıkla dokunulacak bir
              // listenin ortasında durmuyor.
              KimoButton(
                label: l.settingsDeleteAccount,
                kind: KimoButtonKind.tertiary,
                onPressed: () => _push(const DeleteAccountScreen()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) {
    sound.tap();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  // ------------------------------------------------------------------ görünüm

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

  Widget _soundCard(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    return KimoCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: SwitchListTile(
        value: appSettings.soundEnabled,
        contentPadding: EdgeInsets.zero,
        title: Text(l.settingsSound, style: t.label),
        onChanged: (bool v) {
          // `setSoundEnabled` asenkron; setState geri çağrısı Future
          // döndüremez (debug'da assert patlar). Değer ilk `await` öncesinde
          // yazıldığı için ayrı bir setState yeterli — zaten `appSettings`
          // dinleniyor.
          appSettings.setSoundEnabled(v);
        },
      ),
    );
  }

  // -------------------------------------------------------------- bildirim

  Widget _notifyCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: SwitchListTile(
        value: userProfile.notifyEnabled,
        contentPadding: EdgeInsets.zero,
        title: Text(l.settingsNotifications, style: t.label),
        subtitle: userProfile.notifyEnabled
            ? null
            : Text(
                l.settingsNotifyOffNote,
                style: t.caption.copyWith(color: c.inkMuted),
              ),
        onChanged: (bool v) async {
          bool ok = v;
          if (v) ok = await notifications.requestPermission();
          await userProfile.setNotifyEnabled(ok);
          if (!ok) await notifications.cancelAll();
          if (!mounted) return;
          setState(() {});
          // İzin reddedildiyse sistem penceresi bir daha açılmaz; kullanıcıyı
          // telefonun ayarına yönlendiriyoruz.
          if (v && !ok) await _offerSystemSettings(l);
        },
      ),
    );
  }

  Future<void> _offerSystemSettings(L10n l) async {
    final KimoTypography t = context.t;
    final bool? go = await showModalBottomSheet<bool>(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.settingsNotifyOff, style: t.section),
            const SizedBox(height: Gap.sm),
            Text(l.settingsNotifyOffNote, style: t.body),
            const SizedBox(height: Gap.lg),
            KimoButton(
              label: l.settingsNotifyEnable,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: Gap.sm),
            KimoButton(
              label: l.actionCancel,
              kind: KimoButtonKind.tertiary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    );
    if (go == true) await SystemSettings.openNotificationSettings();
  }

  Widget _hourCard(
    BuildContext context, {
    required String label,
    required int hour,
    required Future<void> Function(int) onPick,
  }) {
    final L10n l = L10n.of(context);
    return _row(
      context,
      icon: KimoIcons.flame,
      label: label,
      value: l.settingsHourValue(hour),
      onTap: () async {
        final int? picked = await _pickHour(context, hour);
        if (picked != null) await onPick(picked);
      },
    );
  }

  Widget _quietCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(l.settingsQuietHours, style: t.bodyStrong)),
              Text(
                l.settingsQuietRange(
                    appSettings.quietStart, appSettings.quietEnd),
                style: t.numberSmall,
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            l.settingsQuietNote,
            style: t.caption.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: <Widget>[
              Expanded(
                child: KimoButton(
                  label: l.settingsHourValue(appSettings.quietStart),
                  kind: KimoButtonKind.secondary,
                  minHeight: Sizes.rowMin,
                  onPressed: () async {
                    final int? h =
                        await _pickHour(context, appSettings.quietStart);
                    if (h != null) {
                      await appSettings.setQuietRange(h, appSettings.quietEnd);
                    }
                  },
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: KimoButton(
                  label: l.settingsHourValue(appSettings.quietEnd),
                  kind: KimoButtonKind.secondary,
                  minHeight: Sizes.rowMin,
                  onPressed: () async {
                    final int? h =
                        await _pickHour(context, appSettings.quietEnd);
                    if (h != null) {
                      await appSettings.setQuietRange(appSettings.quietStart, h);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Saat seçici — 24 çip. `showTimePicker` dakika da soruyordu ama bütün
  /// zamanlama saat başına yuvarlanıyor; dakikayı sormak, uygulanmayacak bir
  /// hassasiyeti varmış gibi göstermekti.
  Future<int?> _pickHour(BuildContext context, int current) {
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    return showModalBottomSheet<int>(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.settingsHourValue(current), style: t.section),
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: <Widget>[
                for (int h = 0; h < 24; h++)
                  KimoChip(
                    label: '$h',
                    selected: h == current,
                    onTap: () {
                      sound.tap();
                      Navigator.of(ctx).pop(h);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- hesap

  Widget _guardianRow(BuildContext context, L10n l) {
    final GuardianStatus? g = _guardian;
    final String? value = g == null
        ? null
        : !g.birthYearSet
            ? l.settingsBirthYearUnset
            : g.consentGranted
                ? l.ageGuardianGranted
                : g.isMinor
                    ? l.guardianStatusNeeded
                    : l.settingsBirthYear;
    return _row(
      context,
      icon: KimoIcons.lock,
      label: (g?.isMinor ?? false) ? l.settingsGuardian : l.settingsBirthYear,
      value: value,
    );
  }

  Widget _row(
    BuildContext context, {
    required KimoIconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
  }) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg, vertical: Gap.md),
      radius: Radii.tile,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          KimoIcon(icon, size: 20, color: c.inkMuted),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(label, style: t.label)),
          if (value != null)
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: t.caption.copyWith(color: c.inkMuted),
              ),
            ),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: Gap.sm),
            KimoIcon(KimoIcons.back, size: 16, color: c.border),
          ],
        ],
      ),
    );
  }
}
