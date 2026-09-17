import 'dart:async';

import 'package:flutter/material.dart';
// Takma ad ZORUNLU: bu paket de `AppSettings` adinda bir sinif yayiyor ve
// bizim `state/app_settings.dart` icindeki tercih deposuyla ayni ada sahip.
import 'package:app_settings/app_settings.dart' as android_settings;

import '../../data/auth_repository.dart';
import '../../data/daily_state_repository.dart';
import '../../data/moderation_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/notification_service.dart';
import '../../services/push_service.dart';
import '../../services/sound_service.dart';
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
import '../onboarding/persona_card.dart';
import '../settings/delete_account_screen.dart';
import '../settings/blocked_users_screen.dart';
import '../plus/plus_screen.dart';
import '../settings/licenses_screen.dart';
import '../settings/privacy_screen.dart';

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
  AgeStatus? _age;

  /// Bildirim anahtarı işlem sırasında kilitli (Task 14).
  bool _notifyBusy = false;

  /// Plus satırının rakamları — SUNUCUDAN. `null` ise satır çizilmiyor:
  /// paywall bir RAKAM VAADİ taşıyor ve uydurma sayıyla açılamaz.
  DailyState? _daily;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Bağımsız iki sorgu: paralel (Task 03, 10.2 deseni).
    final List<Object?> parts = await Future.wait<Object?>(<Future<Object?>>[
      moderationRepository.isAdmin(),
      dailyStateRepository.ageStatus(),
      dailyStateRepository.read(),
    ]);
    final bool admin = parts[0]! as bool;
    final AgeStatus? age = parts[1] as AgeStatus?;
    final DailyState? daily = parts[2] as DailyState?;
    if (!mounted) return;
    setState(() {
      _isAdmin = admin;
      _age = age;
      _daily = daily;
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
            Gap.screen,
            Gap.md,
            Gap.screen,
            Gap.section,
          ),
          children: <Widget>[
            SectionHeader(title: l.settingsAppearance),
            const SizedBox(height: Gap.md),
            _themeCard(context, l),
            const SizedBox(height: Gap.sm),
            _soundCard(context, l),
            ...<Widget>[
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
                  onPick: (int h) async {
                    await appSettings.setReviewHour(h);
                    await notifications.replanFromCache(
                      enabled: userProfile.notifyEnabled,
                    );
                  },
                ),
                const SizedBox(height: Gap.sm),
                _hourCard(
                  context,
                  label: l.settingsStreakHour,
                  hour: appSettings.streakHour,
                  onPick: (int h) async {
                    await appSettings.setStreakHour(h);
                    await notifications.replanFromCache(
                      enabled: userProfile.notifyEnabled,
                    );
                  },
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
                value: userProfile.mascot == null
                    ? null
                    : personaName(l, userProfile.mascot!),
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
              _birthYearRow(context, l),
              const SizedBox(height: Gap.sm),
              // Engellenenler (A-8). Engelleme `friends_view` ve gelen kutusu
              // şikâyet sayfasından yapılıyordu ama geri alınamıyordu.
              _row(
                context,
                icon: KimoIcons.close,
                label: l.settingsBlocked,
                onTap: () => _push(const BlockedUsersScreen()),
              ),
              const SizedBox(height: Gap.sm),
              // Kimo Plus. RAKAMLAR SUNUCUDAN: eskiden `const PlusScreen()`
              // ile parametresiz açılıyordu ve ekran koddaki 8/10/300/50/1000
              // yedeğine düşüyordu — Task 12 bu kusuru hak duvarında
              // düzeltmiş ama ÜÇÜNCÜ girişe (burası) uygulamamıştı. Sonuç:
              // `app_config` sınırları gevşetilince aynı ekran iki girişte
              // iki farklı rakam gösteriyordu.
              //
              // DEĞER OKUNAMADIYSA SATIR HİÇ ÇİZİLMİYOR: rakam vaadi taşıyan
              // bir ekranı uydurma sayılarla açmak, deponun yasakladığı şey.
              if (_daily != null)
                _row(
                  context,
                  icon: KimoIcons.spark,
                  label: l.settingsPlus,
                  onTap: () => _push(
                    PlusScreen(
                      freeLimitsKnown: !_daily!.hasSubscription &&
                          !authRepository.isAnonymous,
                      freeWindowLimit: _daily!.aiWindowLimit,
                      freeMonthLimit: _daily!.aiMonthLimit,
                      plusWindowLimit: _daily!.plusWindowLimit,
                      plusMonthLimit: _daily!.plusMonthLimit,
                      windowHours: _daily!.aiWindowHours,
                    ),
                  ),
                ),
              const SizedBox(height: Gap.sm),
              // Veri aktarımı bildirimi ve hukuki metinlerin yuvası (Task 03).
              _row(
                context,
                icon: KimoIcons.lock,
                label: l.settingsPrivacy,
                onTap: () => _push(const PrivacyScreen()),
              ),
              const SizedBox(height: Gap.sm),
              // AÇIK KAYNAK LİSANSLARI (Task 13). Flutter'ın kendisi,
              // supabase_flutter, google_mobile_ads, sentry_flutter ve gömülü
              // Baloo 2 / DM Sans (SIL OFL 1.1) atıf gerektiriyor ve depoda
              // bunu gösteren hiçbir yer yoktu.
              _row(
                context,
                icon: KimoIcons.notebook,
                label: l.settingsLicenses,
                onTap: () => _push(const LicensesScreen()),
              ),
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
                  // SIRALAMA ÖNEMLİ: jeton silme oturum gerektirir. Eskiden
                  // yalnızca signOut çağrılıyordu ve device_tokens satırı
                  // kalıyordu — aynı telefonda açılan BİR SONRAKİ hesap,
                  // önceki kullanıcının push bildirimlerini alıyordu.
                  await push.unregisterDevice();
                  await notifications.cancelAll();
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
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
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
        // `_notifyBusy`: anahtar async ve `SwitchListTile` her dokunuşta
        // ateşliyor. Koruma yokken hızlı çift dokunuş iki `requestPermission`
        // + iki `setNotifyEnabled` + birbirine karışan
        // `registerDevice`/`unregisterDevice` çifti üretiyordu; kaybeden yarış
        // "profil KAPALI diyor ama `device_tokens` jetonu hâlâ tutuyor"
        // durumunu bırakıyor — çıkış yolunda 0043'te düzeltilen hatanın
        // aynısı (Task 14).
        onChanged: _notifyBusy
            ? null
            : (bool v) async {
                setState(() => _notifyBusy = true);
                try {
                  bool ok = v;
                  if (v) ok = await notifications.requestPermission();
                  await userProfile.setNotifyEnabled(ok);
                  if (ok) {
                    // Anahtar AÇILDI: yerel plan hemen kurulsun (eskiden bir sonraki
                    // ekran yüklemesini bekliyordu) ve cihaz push için kaydolsun.
                    await notifications.replanFromCache(enabled: true);
                    unawaited(push.registerDevice());
                  } else {
                    // Anahtar KAPANDI: yalnızca yerel hatırlatmalar değil, sunucu
                    // push'u da dursun. Eskiden jeton silinmiyordu ve bildirimi
                    // kapatan kullanıcı arkadaşlık isteği push'larını almaya devam
                    // ediyordu (Task 03, bulgu 7.1).
                    await notifications.cancelAll();
                    await push.unregisterDevice();
                  }
                  if (!mounted) return;
                  setState(() {});
                  // İzin reddedildiyse sistem penceresi bir daha açılmaz; kullanıcıyı
                  // telefonun ayarına yönlendiriyoruz.
                  if (v && !ok) await _offerSystemSettings(l);
                } catch (e) {
                  // YAZIM DÜŞTÜ (çoğunlukla ağ). `setNotifyEnabled` alanı geri
                  // aldı; kullanıcıya da söylüyoruz, yoksa anahtar geri kayıyor ve
                  // sebebi hiçbir yerde görünmüyor.
                  debugPrint('bildirim ayarı kaydedilemedi: $e');
                  if (!mounted) return;
                  setState(() {});
                  _snack(l.settingsSaveFailed);
                } finally {
                  if (mounted) setState(() => _notifyBusy = false);
                }
              },
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            // YAPRAK İŞLETİM SİSTEMİ İZNİ REDDEDİLDİĞİNDE AÇILIYOR, o yüzden
            // metin de onu anlatıyor (Task 15 · D5). Eskiden gövde
            // `settingsNotifyOffNote` ("Saatleri değiştirmek için önce
            // bildirimleri aç") idi: uygulama içi bir anahtarı tarif ediyordu,
            // oysa engel telefonun ayarındaydı ve düğme de oraya gidiyordu.
            Text(l.settingsNotifyBlocked, style: t.section),
            const SizedBox(height: Gap.sm),
            Text(l.settingsNotifyBlockedNote, style: t.body),
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
    // Uygulamanin KENDI bildirim sayfasi aciliyor; cihazin genel ayarlarina
    // birakmak kullaniciyi dogru anahtari aramaya mecbur ederdi.
    //
    // Paket notu: burada eskiden `system_settings` vardi ve o paket 2020'den
    // beri guncellenmemis (AGP 3.5, jcenter). Gradle 9 `jcenter()` desteğini
    // kaldirdigi icin ANDROID DERLEMESINI TAMAMEN KIRIYORDU.
    if (go == true) {
      await android_settings.AppSettings.openAppSettings(
        type: android_settings.AppSettingsType.notification,
      );
    }
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
                  appSettings.quietStart,
                  appSettings.quietEnd,
                ),
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
                    final int? h = await _pickHour(
                      context,
                      appSettings.quietStart,
                    );
                    if (h != null) {
                      await appSettings.setQuietRange(h, appSettings.quietEnd);
                      await notifications.replanFromCache(
                        enabled: userProfile.notifyEnabled,
                      );
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
                    final int? h = await _pickHour(
                      context,
                      appSettings.quietEnd,
                    );
                    if (h != null) {
                      await appSettings.setQuietRange(
                        appSettings.quietStart,
                        h,
                      );
                      await notifications.replanFromCache(
                        enabled: userProfile.notifyEnabled,
                      );
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

  /// Doğum yılı durumu — ARTIK YILIN KENDİSİNİ GÖSTERİYOR (Task 14 · K2).
  ///
  /// Eskiden yalnızca "bir kez yazılır, sonradan değiştirilemez" notunu
  /// çiziyordu ve yılın kendisi uygulamanın HİÇBİR yerinde görünmüyordu —
  /// hemen üstündeki "Sınav yılı" satırı ise değerini gösteriyor. Değeri
  /// değiştiremeyen kullanıcının onu görebilmesi daha da gerekli.
  ///
  /// Sebep istemcide değil sunucudaydı: `my_age_status` yılı hiç döndürmüyordu
  /// (0097 ekledi). Eski sunucu sürümüne karşı dayanıklı: `birthYear` null
  /// gelirse satır eski hâlindeki nota düşüyor.
  ///
  /// Task 07: veli onayı satırının yerini aldı. Yaş artık hiçbir özelliği
  /// kapatmıyor, dolayısıyla burada gösterilecek bir "bekleniyor" durumu yok.
  Widget _birthYearRow(BuildContext context, L10n l) {
    final AgeStatus? a = _age;
    final String? value;
    if (a == null) {
      value = null;
    } else if (!a.birthYearSet) {
      value = l.settingsBirthYearUnset;
    } else {
      value = a.birthYear?.toString() ?? l.ageWriteOnceNote;
    }
    return _row(
      context,
      icon: KimoIcons.lock,
      label: l.settingsBirthYear,
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
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
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
            KimoIcon(KimoIcons.forward, size: 16, color: c.border),
          ],
        ],
      ),
    );
  }
}
