import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/crash_service.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';

/// E-posta doğrulama bekleme adımı (Task 03, bulgu 5.3).
///
/// NEDEN VAR: `convertToPermanent` (anonim → kalıcı) sunucuda e-posta onayı
/// AÇIKKEN adresi askıda bırakır (`User.newEmail`). Eskiden hiçbir şey bunu
/// ele almıyordu: kullanıcı hesabı açıldı sanıyor, oturum düşünce o adresle
/// GİREMİYOR ve arşivi anonim kimlikte mahsur kalıyordu — veri kaybı yolu.
///
/// Bu adım üç şey yapar:
///  • BEKLER: onay başka cihazda/tarayıcıda verilir, push gelmez; 8 sn'de bir
///    oturum tazelenip sorulur + `userUpdated` olayı da dinlenir.
///  • YENİDEN GÖNDERİR: 60 sn istemci bekletmesiyle (sunucu sınırı saatte 2;
///    429'da özel mesaj gösterilir).
///  • KAÇIŞ BIRAKIR: adres yanlışsa bir önceki adıma dönülür; e-posta hiç
///    gelmiyorsa "şimdilik devam" ile uygulama kullanılmaya devam edilir —
///    doğrulama sonraki açılışta kaldığı yerden sorulur (akış kilitlemez).
///
/// Onay sunucuda KAPALIYSA `convertToPermanent` anında tamamlanır ve bu adım
/// ilk karede doğrulanmış görünür.
class EmailVerifyStep extends StatefulWidget {
  const EmailVerifyStep({
    super.key,
    required this.email,
    required this.onStatus,
    required this.onChangeAddress,
    required this.onContinueAnyway,
  });

  /// Onay bekleyen adres.
  final String email;

  /// Doğrulama durumu değişince çağrılır (akış ilerleme düğmesini açar).
  final ValueChanged<bool> onStatus;

  /// "Adresi değiştir": bir önceki (kayıt) adımına döner.
  final VoidCallback onChangeAddress;

  /// "Şimdilik devam et": akış doğrulama olmadan tamamlanır.
  final VoidCallback onContinueAnyway;

  @override
  State<EmailVerifyStep> createState() => _EmailVerifyStepState();
}

class _EmailVerifyStepState extends State<EmailVerifyStep> {
  Timer? _poll;
  Timer? _cooldownTicker;
  StreamSubscription<AuthState>? _authSub;
  bool _verified = false;
  bool _resending = false;
  int _cooldown = 0;

  /// Onay geldi mi: kalıcı kimlik + doğrulanmış adres + askıda değişiklik yok.
  bool get _confirmedNow =>
      !authRepository.isAnonymous &&
      authRepository.emailConfirmed &&
      authRepository.pendingEmail == null;

  @override
  void initState() {
    super.initState();
    if (_confirmedNow) {
      // Onay sunucuda kapalı (ya da çoktan verilmiş): bekleme yok.
      _verified = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onStatus(true));
      return;
    }
    _authSub = authRepository.authStateChanges.listen((AuthState s) {
      if (s.event == AuthChangeEvent.userUpdated ||
          s.event == AuthChangeEvent.tokenRefreshed) {
        _check(refresh: false);
      }
    });
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTicker?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _check({bool refresh = true}) async {
    if (_verified) return;
    if (refresh) {
      try {
        await authRepository.refreshUser();
      } catch (_) {
        // Çevrimdışı olabilir; bir sonraki turda yeniden sorulur. (Bilinçli
        // sessiz: bekleme ekranında her ağ hıçkırığını göstermek gürültü.)
        return;
      }
    }
    if (!mounted || !_confirmedNow) return;
    setState(() => _verified = true);
    _poll?.cancel();
    sound.correct();
    widget.onStatus(true);
  }

  Future<void> _resend() async {
    if (_resending || _cooldown > 0) return;
    final L10n l = L10n.of(context);
    sound.tap();
    setState(() => _resending = true);
    try {
      await authRepository.resendEmailChange(widget.email);
      if (!mounted) return;
      _startCooldown();
      _snack(l.verifyResendSent);
    } on AuthException catch (e, st) {
      if (!mounted) return;
      if (e.statusCode == '429' || e.code == 'over_email_send_rate_limit') {
        // Sunucu sınırı (varsayılan saatte 2). Bu bir kusur değil, bilinen
        // sınır — kullanıcıya süreyi söylüyoruz, rapora göndermiyoruz.
        _startCooldown();
        _snack(l.verifyRateLimited);
      } else {
        unawaited(reportError(e, st, context: 'verify.resend'));
        _snack(l.errorGeneric);
      }
    } catch (e, st) {
      unawaited(reportError(e, st, context: 'verify.resend'));
      if (mounted) _snack(l.errorGeneric);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    _cooldown = 60;
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (Timer tick) {
      if (!mounted) {
        tick.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) tick.cancel();
      });
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
      children: <Widget>[
        const Center(child: Kimo(size: 120)),
        const SizedBox(height: Gap.lg),
        Text(l.verifyTitle, textAlign: TextAlign.center, style: t.title),
        const SizedBox(height: Gap.sm),
        Text(
          l.verifyBody(widget.email),
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: c.inkSecondary),
        ),
        const SizedBox(height: Gap.lg),
        Center(
          child: StatusBadge(
            label: _verified ? l.verifyDone : l.verifyWaiting,
            tone: _verified ? BadgeTone.mastered : BadgeTone.pending,
          ),
        ),
        if (!_verified) ...<Widget>[
          const SizedBox(height: Gap.xl),
          KimoButton(
            label: _cooldown > 0
                ? l.verifyResendCooldown(_cooldown)
                : l.verifyResend,
            kind: KimoButtonKind.secondary,
            onPressed:
                (_resending || _cooldown > 0) ? null : () => unawaited(_resend()),
          ),
          const SizedBox(height: Gap.sm),
          KimoButton(
            label: l.verifyChangeAddress,
            kind: KimoButtonKind.tertiary,
            onPressed: widget.onChangeAddress,
          ),
          const SizedBox(height: Gap.xl),
          Text(
            l.verifyContinueNote,
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Gap.sm),
          KimoButton(
            label: l.verifyContinueAnyway,
            kind: KimoButtonKind.tertiary,
            onPressed: widget.onContinueAnyway,
          ),
        ],
      ],
    );
  }
}
