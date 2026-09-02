import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../data/daily_state_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/mascot.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kimo/kimo_pose.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_progress.dart';
import '../capture/capture_screen.dart';
import 'age_gate_step.dart';

/// Karşılama akışı — **on bir adımdan beşe**.
///
/// Adımlar: yaş kapısı · takma ad + sınav yılı · maskot · bildirim · kayıt.
/// Kaldırılanlar: üç "nasıl çalışır" anlatım sayfası (ürünün kendisi zaten
/// anlatıyor: çekim ekranı ne yapacağını, cevap paneli tekrarın ne zaman
/// geleceğini söylüyor) ve "merhaba" sayfası (karşılama ekranına taşındı).
///
/// **Kayıt SONDA.** Anonim oturumla gelen kullanıcı ilk yanlışını çoktan
/// çekmiş oluyor; son adımda `updateUser` ile aynı `uid` kalıcı hesaba
/// dönüşüyor, yani taşınacak veri yok.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Step { firstCapture, age, profile, mascot, notifications, signUp }

class _OnboardingFlowState extends State<OnboardingFlow> {
  final TextEditingController _nickname = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final KimoController _kimo = KimoController();

  late final List<_Step> _steps;
  int _index = 0;

  int? _year;
  Mascot? _mascot;
  bool? _notify;
  bool _saving = false;
  GuardianStatus? _guardian;

  static const List<int> _examYears = <int>[2026, 2027, 2028, 2029, 2030];

  bool get _remote => SupabaseConfig.isConfigured;

  /// Kayıt öncesi geçici kimlikle mi geldik.
  bool get _anonymous => _remote && authRepository.isAnonymous;

  @override
  void initState() {
    super.initState();
    _nickname.text = userProfile.nickname ?? '';
    _year = userProfile.examYear;
    _mascot = userProfile.mascot;

    _steps = <_Step>[
      // Yalnızca "İlk yanlışını çek" yolundan gelenler için: hesabı olan biri
      // zaten arşivine sahip.
      if (_anonymous) _Step.firstCapture,
      if (_remote) _Step.age,
      _Step.profile,
      _Step.mascot,
      _Step.notifications,
      // Zaten kalıcı hesabı olan (giriş yapmış) kullanıcıya kayıt sorulmaz.
      if (_anonymous) _Step.signUp,
    ];

    _nickname.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
    _email.addListener(() => setState(() {}));
    if (_remote) _loadGuardian();
  }

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    _password.dispose();
    _kimo.dispose();
    super.dispose();
  }

  Future<void> _loadGuardian() async {
    final GuardianStatus? s = await dailyStateRepository.guardianStatus();
    if (mounted) setState(() => _guardian = s);
  }

  _Step get _current => _steps[_index];

  // ------------------------------------------------------------- geçerlilik

  /// Adım tamamlanabilir mi.
  ///
  /// **Yaş kapısı ilerlemeyi ENGELLEMİYOR.** Doğum yılı yazıldıysa geçilir;
  /// veli onayı beklemek bir engel değil — onay yalnızca arkadaş eklemeyi
  /// kapatıyor ve o kısıt SUNUCUDA (`can_add_friends`). Kullanıcıyı burada
  /// bekletmek, veliye ulaşamayan bir öğrenciyi uygulamadan tamamen dışarıda
  /// bırakırdı.
  bool get _canContinue => switch (_current) {
        _Step.firstCapture => true,
        // Durum OKUNAMADIYSA (ağ hatası, ilk yükleme sürüyor) ilerlemeye
        // izin veriliyor. Bu bir boşluk değil: `is_minor_now` bilinmeyen
        // doğum yılını REŞİT OLMAYAN sayıyor, yani atlayan kullanıcıda
        // arkadaş ekleme sunucuda kapalı kalıyor. Kilitlenmek ise gerçekten
        // zarar verirdi — kullanıcı uygulamaya hiç giremezdi.
        _Step.age => _guardian == null || _guardian!.birthYearSet,
        _Step.profile => _nickname.text.trim().length >= 2 && _year != null,
        _Step.mascot => _mascot != null,
        _Step.notifications => _notify != null,
        _Step.signUp => _emailOk && _passwordOk,
      };

  bool get _emailOk {
    final String v = _email.text.trim();
    final int at = v.indexOf('@');
    final int dot = v.lastIndexOf('.');
    return at > 0 && dot > at + 1 && dot < v.length - 1 && !v.contains(' ');
  }

  // Supabase'in varsayılan alt sınırı 6; 8 bizim kararımız ve `config.toml`
  // ile aynı olmak zorunda değil (daha katı olması sorun değil).
  bool get _passwordOk => _password.text.length >= 8;

  // ------------------------------------------------------------------ akış

  Future<void> _next() async {
    if (_saving || !_canContinue) return;
    final L10n l = L10n.of(context);
    sound.tap();
    setState(() => _saving = true);
    try {
      switch (_current) {
        case _Step.firstCapture:
          break;
        case _Step.age:
          break;
        case _Step.profile:
          await userProfile.setNickname(_nickname.text.trim());
          await userProfile.setExamYear(_year!);
        case _Step.mascot:
          await userProfile.setMascot(_mascot!);
        case _Step.notifications:
          bool granted = false;
          if (_notify == true) {
            granted = await notifications.requestPermission();
            if (!granted && mounted) _snack(l.notifyDenied);
          }
          await userProfile.setNotifyEnabled(granted);
        case _Step.signUp:
          await _register();
      }
    } catch (e) {
      debugPrint('adım kaydedilemedi: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(_current == _Step.signUp
          ? _signUpMessage(l, e)
          : l.onboardSaveFailed);
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    if (_index >= _steps.length - 1) {
      sound.levelUp();
      _kimo.trigger(KimoReaction.levelUp);
      widget.onDone();
      return;
    }
    setState(() => _index++);
  }

  /// Anonim oturumu kalıcıya çevirir. **Yeni hesap AÇMIYOR**: `uid` aynı
  /// kalıyor, dolayısıyla çekilen fotoğraf, kaydedilen soru ve onay kaydı
  /// olduğu yerde duruyor.
  Future<void> _register() async {
    await authRepository.convertToPermanent(
      email: _email.text.trim(),
      password: _password.text,
    );
  }

  String _signUpMessage(L10n l, Object e) {
    final String s = e.toString().toLowerCase();
    if (s.contains('already') || s.contains('registered') ||
        s.contains('exists')) {
      return l.signUpEmailTaken;
    }
    return l.signUpFailed;
  }

  void _back() {
    if (_index == 0) return;
    sound.tap();
    setState(() => _index--);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _capture() async {
    sound.tap();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CaptureScreen()),
    );
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------------- yapı

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final L10n l = L10n.of(context);
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _progress(context, l),
            Expanded(child: _page(context, l)),
            _footer(context, l),
          ],
        ),
      ),
    );
  }

  Widget _progress(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, Gap.screen, Gap.md),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: _index == 0 ? null : _back,
            icon: KimoIcon(
              KimoIcons.back,
              color: _index == 0 ? c.border : c.ink,
            ),
            tooltip: l.onboardBack,
          ),
          Expanded(
            child: KimoProgressBar(value: (_index + 1) / _steps.length),
          ),
          const SizedBox(width: Gap.md),
          Text(
            l.onboardStep(_index + 1, _steps.length),
            style: t.numberSmall.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _page(BuildContext context, L10n l) {
    return switch (_current) {
      _Step.firstCapture => _firstCapturePage(context, l),
      _Step.age => AgeGateStep(status: _guardian, onChanged: _loadGuardian),
      _Step.profile => _profilePage(context, l),
      _Step.mascot => _mascotPage(context, l),
      _Step.notifications => _notifyPage(context, l),
      _Step.signUp => _signUpPage(context, l),
    };
  }

  Widget _firstCapturePage(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
      children: <Widget>[
        Center(
          child: Kimo(
            size: 130,
            controller: _kimo,
            onTap: () => _kimo.trigger(KimoReaction.tap),
          ),
        ),
        const SizedBox(height: Gap.lg),
        Text(l.captureEmptyTitle, textAlign: TextAlign.center, style: t.title),
        const SizedBox(height: Gap.sm),
        Text(
          l.captureEmptyBody,
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: c.inkSecondary),
        ),
        const SizedBox(height: Gap.xl),
        KimoButton(
          label: l.welcomePrimary,
          icon: const KimoIcon(KimoIcons.camera, size: 20),
          onPressed: _capture,
        ),
      ],
    );
  }

  Widget _profilePage(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
      children: <Widget>[
        Text(l.profileStepTitle, style: t.title),
        const SizedBox(height: Gap.lg),
        TextField(
          controller: _nickname,
          maxLength: 24,
          style: t.body,
          decoration: InputDecoration(
            hintText: l.profileNicknameHint,
            counterText: '',
            filled: true,
            fillColor: c.sunken,
            border: OutlineInputBorder(
              borderRadius: Radii.all(Radii.tile),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: Gap.xl),
        Text(l.profileExamYearTitle, style: t.section),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: <Widget>[
            for (final int y in _examYears)
              KimoChip(
                label: '$y',
                selected: _year == y,
                onTap: () {
                  sound.tap();
                  setState(() => _year = y);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _mascotPage(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
      children: <Widget>[
        Center(child: Kimo(size: 120, controller: _kimo)),
        const SizedBox(height: Gap.lg),
        Text(l.mascotStepTitle, textAlign: TextAlign.center, style: t.title),
        const SizedBox(height: Gap.sm),
        Text(
          l.mascotStepBody,
          textAlign: TextAlign.center,
          style: t.caption.copyWith(color: c.inkSecondary),
        ),
        const SizedBox(height: Gap.xl),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final Mascot m in Mascot.values)
              KimoChip(
                label: m.label,
                selected: _mascot == m,
                onTap: () {
                  sound.tap();
                  _kimo.trigger(KimoReaction.tap);
                  setState(() => _mascot = m);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _notifyPage(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
      children: <Widget>[
        Text(l.notifyStepTitle, style: t.title),
        const SizedBox(height: Gap.sm),
        Text(l.notifyStepBody, style: t.body.copyWith(color: c.inkSecondary)),
        const SizedBox(height: Gap.xl),
        KimoButton(
          label: l.notifyYes,
          onPressed: () {
            sound.tap();
            setState(() => _notify = true);
          },
          kind: _notify == true
              ? KimoButtonKind.primary
              : KimoButtonKind.secondary,
        ),
        const SizedBox(height: Gap.sm),
        KimoButton(
          label: l.notifyNo,
          kind: _notify == false
              ? KimoButtonKind.secondary
              : KimoButtonKind.tertiary,
          onPressed: () {
            sound.tap();
            setState(() => _notify = false);
          },
        ),
      ],
    );
  }

  Widget _signUpPage(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
      children: <Widget>[
        Text(l.signUpTitle, style: t.title),
        const SizedBox(height: Gap.sm),
        Text(
          _anonymous ? l.signUpBodyAnonymous : l.signUpBody,
          style: t.body.copyWith(color: c.inkSecondary),
        ),
        const SizedBox(height: Gap.xl),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: t.body,
          decoration: InputDecoration(
            labelText: l.signUpEmail,
            errorText: (_email.text.isEmpty || _emailOk)
                ? null
                : l.signUpEmailInvalid,
            filled: true,
            fillColor: c.sunken,
            border: OutlineInputBorder(
              borderRadius: Radii.all(Radii.tile),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _password,
          obscureText: true,
          style: t.body,
          decoration: InputDecoration(
            labelText: l.signUpPassword,
            errorText: (_password.text.isEmpty || _passwordOk)
                ? null
                : l.signUpPasswordShort,
            filled: true,
            fillColor: c.sunken,
            border: OutlineInputBorder(
              borderRadius: Radii.all(Radii.tile),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context, L10n l) {
    final bool last = _index == _steps.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Gap.screen, Gap.md, Gap.screen, Gap.screen),
      child: KimoButton(
        label: _label(l, last),
        onPressed: (_saving || !_canContinue) ? null : _next,
      ),
    );
  }

  String _label(L10n l, bool last) {
    if (_saving) return l.actionSave;
    if (_current == _Step.signUp) return l.signUpAction;
    if (last) return l.signUpDone;
    return l.actionContinue;
  }
}
