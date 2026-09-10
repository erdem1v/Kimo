import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../data/notification_lines.dart';
import '../../data/daily_state_repository.dart';
import '../../services/legal_links.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/mascot.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_progress.dart';
import '../capture/capture_screen.dart';
import 'age_gate_step.dart';
import 'persona_card.dart';

/// Karşılama akışı.
///
/// Adımlar: (ilk çekim) · yaş kapısı · takma ad + sınav yılı · persona ·
/// bildirim · (kayıt). Parantezliler yalnızca anonim oturumdan gelenler için.
/// Kaldırılanlar: üç "nasıl çalışır" anlatım sayfası (ürünün kendisi zaten
/// anlatıyor), "merhaba" sayfası (karşılama ekranına taşındı) ve e-posta
/// doğrulama adımı (Task 06).
///
/// **Kayıt SONDA.** Anonim oturumla gelen kullanıcı ilk yanlışını çoktan
/// çekmiş oluyor; son adımda `updateUser` ile aynı `uid` kalıcı hesaba
/// dönüşüyor, yani taşınacak veri yok. Koşul onayının kayıt adımında
/// alınabilmesinin nedeni de bu: `auth.uid()` o an ZATEN var ve dönüşümde
/// değişmiyor, yani onay doğru hesaba yazılıyor.
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
  AgeStatus? _age;

  /// Kullanım Koşulları ve Gizlilik Politikası kabul edildi mi (Apple 1.2).
  bool _termsAccepted = false;

  static const List<int> _examYears = <int>[2026, 2027, 2028, 2029, 2030];

  /// Kayıt öncesi geçici kimlikle mi geldik.
  bool get _anonymous => authRepository.isAnonymous;

  @override
  void initState() {
    super.initState();
    _nickname.text = userProfile.nickname ?? '';
    _year = userProfile.examYear;
    // Tasarım ilk seçeneği ÖN SEÇİLİ gösteriyor ve buton "Bu sesle devam
    // et" diyor: seçim zorunlu değil, atlayan kullanıcı da bir ses alıyor.
    // Sunucudaki `coalesce(mascot, 'ev_hanimi')` ile aynı varsayılan.
    _mascot = userProfile.mascot ?? Mascot.fallback;

    _steps = <_Step>[
      // Yalnızca "İlk yanlışını çek" yolundan gelenler için: hesabı olan biri
      // zaten arşivine sahip.
      if (_anonymous) _Step.firstCapture,
      _Step.age,
      _Step.profile,
      _Step.mascot,
      _Step.notifications,
      // Zaten kalıcı hesabı olan (giriş yapmış) kullanıcıya kayıt sorulmaz.
      if (_anonymous) _Step.signUp,
    ];

    // Persona adımının kilit ekranı önizlemesi canlı havuzdan okuyor; havuz
    // inmemişse karttaki örneğe düşer, ama denemeye değer.
    unawaited(notificationLines.refresh().then((_) {
      if (mounted) setState(() {});
    }));

    _nickname.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
    _email.addListener(() => setState(() {}));
    _loadAge();
  }

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    _password.dispose();
    _kimo.dispose();
    super.dispose();
  }

  Future<void> _loadAge() async {
    final AgeStatus? s = await dailyStateRepository.ageStatus();
    if (mounted) setState(() => _age = s);
  }

  _Step get _current => _steps[_index];

  // ------------------------------------------------------------- geçerlilik

  /// Adım tamamlanabilir mi.
  ///
  /// **YAŞ KAPISI ARTIK ZORUNLU (Task 07).** Eskiden durum okunamadığında
  /// (ağ hatası) geçişe izin veriliyordu; gerekçe "atlayan kullanıcı sunucuda
  /// reşit olmayan sayılır, arkadaş ekleme kapalı kalır"dı. Veli onayı
  /// kalkınca o kapalı taraf da kalktı ve bypass, 13 yaş sınırını atlatan bir
  /// deliğe dönüştü. Artık yıl yazılmadan ilerlenmiyor; ağ hatasında kullanıcı
  /// "Kaydet"e yeniden basıyor ve nedenini görüyor.
  bool get _canContinue => switch (_current) {
        _Step.firstCapture => true,
        _Step.age => _age?.birthYearSet ?? false,
        _Step.profile => _nickname.text.trim().length >= 2 && _year != null,
        // Ön seçili geldiği için kilitlenmez; sürtünme eklemeden geçilir.
        _Step.mascot => true,
        _Step.notifications => _notify != null,
        // Onay verilmeden kayıt TAMAMLANMIYOR (Apple 1.2).
        _Step.signUp => _emailOk && _passwordOk && _termsAccepted,
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
          await userProfile.setMascot(_mascot ?? Mascot.fallback);
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
  ///
  /// SIRA ÖNEMLİ: koşul onayı ÖNCE deftere yazılıyor, hesap SONRA kalıcı
  /// oluyor. Ters sırada, onay yazımı başarısız olsaydı ortada onayı olmayan
  /// kalıcı bir hesap kalırdı — "onay verilmeden kayıt tamamlanmasın"
  /// şartının gerçek karşılığı bu. Onay hatası yutulmuyor.
  Future<void> _register() async {
    await dailyStateRepository.acceptLegalTerms();
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
          const Spacer(),
          Text(
            l.onboardStep(_index + 1, _steps.length),
            style: t.captionStrong.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _page(BuildContext context, L10n l) {
    return switch (_current) {
      _Step.firstCapture => _firstCapturePage(context, l),
      _Step.age => AgeGateStep(status: _age, onChanged: _loadAge),
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
    final Mascot selected = _mascot ?? Mascot.fallback;
    // Kahraman maskot YOK. Ekranın tek işi dört tonun farkını beş saniyede
    // duyurmak; 120px'lik bir Kimo, karşılaştırılacak dört cümleyi ekranın
    // dışına iterdi. Maskot önizlemenin içinde, olması gereken boyutta duruyor.
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
      children: <Widget>[
        Text(l.mascotStepTitle, style: t.title),
        const SizedBox(height: Gap.xs),
        Text(
          l.mascotStepBody,
          style: t.caption.copyWith(color: c.inkSecondary),
        ),
        const SizedBox(height: Gap.md),
        PersonaPreview(mascot: selected),
        const SizedBox(height: Gap.md),
        for (final Mascot m in Mascot.values) ...<Widget>[
          PersonaCard(
            mascot: m,
            selected: selected == m,
            onTap: () {
              sound.tap();
              _kimo.trigger(KimoReaction.tap);
              setState(() => _mascot = m);
            },
          ),
          const SizedBox(height: Gap.sm),
        ],
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
        const SizedBox(height: Gap.lg),
        _termsRow(context, l),
      ],
    );
  }

  /// Koşul ve gizlilik onayı (Apple 1.2 · hukuki denetim A-4).
  ///
  /// Kutu ÖN SEÇİLİ DEĞİL ve "Kaydol" düğmesi işaretlenene kadar pasif:
  /// önceden işaretlenmiş bir onay kutusu onay sayılmaz.
  ///
  /// İki metin AYRI AYRI tıklanabilir. Adres verilmemişse (henüz
  /// yayınlanmadıysa) o parça düz metin olarak kalıyor — kırık bir bağlantı
  /// göstermek, bağlantı göstermemekten kötü.
  Widget _termsRow(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;

    TextSpan link(String label, String url) {
      if (!LegalLinks.has(url)) {
        return TextSpan(text: label, style: t.captionStrong);
      }
      return TextSpan(
        text: label,
        style: t.captionStrong.copyWith(
          color: c.actionText,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            sound.tap();
            unawaited(openLegalUrl(url));
          },
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Checkbox(
          value: _termsAccepted,
          onChanged: (bool? v) {
            sound.tap();
            setState(() => _termsAccepted = v ?? false);
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Text.rich(
              TextSpan(
                style: t.caption.copyWith(color: c.inkSecondary),
                children: <InlineSpan>[
                  link(l.consentTermsLink, LegalLinks.terms),
                  TextSpan(text: l.consentJoin),
                  link(l.consentPrivacyLink, LegalLinks.privacy),
                  TextSpan(text: l.consentTail),
                ],
              ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          KimoButton(
            label: _label(l, last),
            onPressed: (_saving || !_canContinue) ? null : _next,
          ),
          const SizedBox(height: Gap.md),
          StepDots(total: _steps.length, current: _index + 1),
        ],
      ),
    );
  }

  String _label(L10n l, bool last) {
    if (_saving) return l.actionSave;
    if (_current == _Step.mascot) return l.mascotContinue;
    if (_current == _Step.signUp) return l.signUpAction;
    if (last) return l.signUpDone;
    return l.actionContinue;
  }

}
