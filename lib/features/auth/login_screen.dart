import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/sound_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';

/// Var olan hesaba giriş.
///
/// **Kayıt buradan KALKTI.** Yeni kullanıcı artık anonim oturumla başlıyor ve
/// hesabını karşılama akışının son adımında açıyor (`convertToPermanent`).
/// İki ayrı kayıt yolu tutmak, ikisinin zamanla ayrışması demekti — ve
/// buradaki yol yaş kapısından geçmiyordu.
///
/// Buradaki "veli onayı" onay kutusu da kaldırıldı. Task 01 onun tamamen
/// kullanıcı-yazılabilir ve zaman damgasız olduğunu ölçmüştü; yerini yaş
/// kapısı, `user_consents` defteri ve `can_add_friends` kısıtı aldı.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final L10n l = L10n.of(context);
    final String email = _email.text.trim();
    final String password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _snack(l.signInFailed);
      return;
    }
    sound.tap();
    setState(() => _loading = true);
    try {
      await authRepository.signIn(email: email, password: password);
      // Oturum açıldıysa bu ekran (ve karşılama) yığından kalkmalı; arkadaki
      // AuthGate zaten uygulamaya/karşılama akışına geçmiş olur.
      if (authRepository.currentSession != null && mounted) {
        Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        return;
      }
    } on AuthException catch (e) {
      debugPrint('giriş reddedildi: ${e.code} ${e.message}');
      if (!mounted) return;
      // "E-posta doğrulanmamış" diğer retlerden AYRILIYOR: kullanıcının
      // yapabileceği şey farklı (gelen kutusuna bakmak / yeniden göndermek),
      // genel "giriş başarısız" bunu asla söylemiyordu.
      if (e.code == 'email_not_confirmed') {
        _snack(l.signInEmailNotConfirmed);
        unawaited(
          authRepository.resendSignUp(email).catchError((Object err) {
            // Oran sınırına takılmış olabilir (saatte 2 e-posta); giriş
            // ekranında ikinci bir hata göstermek kafa karıştırırdı.
            debugPrint('doğrulama postası yeniden gönderilemedi: $err');
          }),
        );
      } else {
        _snack(l.signInFailed);
      }
    } catch (e) {
      debugPrint('giriş başarısız: $e');
      if (mounted) _snack(l.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

    return Scaffold(
      backgroundColor: c.page,
      appBar: AppBar(
        backgroundColor: c.page,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: KimoIcon(KimoIcons.back, color: c.ink),
          tooltip: l.actionBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
                children: <Widget>[
                  const Center(child: Kimo(size: 110)),
                  const SizedBox(height: Gap.lg),
                  Text(
                    l.signInTitle,
                    textAlign: TextAlign.center,
                    style: t.title,
                  ),
                  const SizedBox(height: Gap.xl),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: t.body,
                    decoration: InputDecoration(
                      labelText: l.signUpEmail,
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
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l.signUpPassword,
                      filled: true,
                      fillColor: c.sunken,
                      border: OutlineInputBorder(
                        borderRadius: Radii.all(Radii.tile),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.screen, Gap.md, Gap.screen, Gap.screen),
              child: KimoButton(
                label: l.signInAction,
                onPressed: _loading ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
