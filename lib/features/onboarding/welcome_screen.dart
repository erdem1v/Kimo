import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../auth/login_screen.dart';

/// 3a — Karşılama.
///
/// Birincil yol **kayıt değil**: "İlk yanlışını çek". Dokunulduğu anda anonim
/// bir oturum açılıyor ve kullanıcı doğrudan çekim ekranına gidiyor; kayıt
/// akışın SONUNDA isteniyor.
///
/// Anonim oturum uygulama açılışında DEĞİL, tam bu düğmeye basıldığında
/// açılıyor: her açılışta açmak, uygulamayı yalnızca açıp kapatan herkes için
/// bir çöp hesap (ve faturaya yazılan bir MAU) üretirdi.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final KimoController _kimo = KimoController();
  bool _starting = false;

  @override
  void dispose() {
    _kimo.dispose();
    super.dispose();
  }

  /// Anonim oturumu açar. Oturum açılınca [AuthGate] karşılama akışını
  /// gösteriyor ve akışın ilk adımı çekim ekranını açıyor — yönlendirmeyi
  /// buradan yapmak, oturum olayı ile rota itmesini yarıştırırdı.
  Future<void> _start() async {
    if (_starting) return;
    sound.tap();
    _kimo.trigger(KimoReaction.tap);

    setState(() => _starting = true);
    try {
      await authRepository.signInAnonymously();
      // Başarılıysa AuthGate devralıyor; bu ekran ağaçtan kalkıyor.
    } catch (e) {
      debugPrint('anonim oturum açılamadı: $e');
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).welcomeStartFailed)),
      );
    }
  }

  void _openLogin() {
    sound.tap();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Kimo(
                        size: 168,
                        controller: _kimo,
                        onTap: () => _kimo.trigger(KimoReaction.tap),
                        semanticLabel: 'Kimo',
                      ),
                      const SizedBox(height: Gap.xl),
                      Text(
                        l.welcomeTitle,
                        textAlign: TextAlign.center,
                        style: t.display,
                      ),
                      const SizedBox(height: Gap.md),
                      Text(
                        l.welcomeBody,
                        textAlign: TextAlign.center,
                        style: t.body.copyWith(color: c.inkSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.screen, Gap.md, Gap.screen, Gap.screen),
              child: Column(
                children: <Widget>[
                  KimoButton(
                    label: l.welcomePrimary,
                    icon: const KimoIcon(KimoIcons.camera, size: 20),
                    onPressed: _starting ? null : _start,
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    l.welcomeNoAccountNote,
                    textAlign: TextAlign.center,
                    style: t.caption.copyWith(color: c.inkMuted),
                  ),
                  const SizedBox(height: Gap.md),
                  KimoButton(
                    label: l.welcomeSecondary,
                    kind: KimoButtonKind.tertiary,
                    onPressed:
                        _starting ? null : _openLogin,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
