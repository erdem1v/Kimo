import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';

/// Giriş / kayıt ekranı. Yalnızca hesabın teknik gereği (e-posta, şifre)
/// burada sorulur; takma ad dahil bütün kişisel sorular karşılama akışında
/// Kimo'nun ağzından gelir. Başarılı oturumda AuthGate otomatik geçiş yapar.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.startWithSignUp = false});

  /// Karşılama ekranından "başlayalım" ile gelindiğinde kayıt formu açılır.
  final bool startWithSignUp;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  late bool _isSignUp = widget.startWithSignUp;
  bool _guardianConsent = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final String email = _email.text.trim();
    final String password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _snack('E-posta ve şifre gerekli.');
      return;
    }
    if (_isSignUp && !_guardianConsent) {
      _snack('Devam etmek için veli onayını işaretle.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isSignUp) {
        // Takma ad burada sorulmaz; Kimo karşılama akışında sorar.
        await authRepository.signUp(
          email: email,
          password: password,
          guardianConsent: _guardianConsent,
        );
        if (authRepository.currentSession == null && mounted) {
          _snack('Kayıt alındı. E-posta onayı açıksa gelen kutunu kontrol et.');
        }
      } else {
        await authRepository.signIn(email: email, password: password);
      }
      // Oturum açıldıysa bu ekran (ve karşılama) yığından kalkmalı; arkadaki
      // AuthGate zaten uygulamaya/karşılama akışına geçmiş olur.
      if (authRepository.currentSession != null && mounted) {
        Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        return;
      }
    } on AuthException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Bir hata oluştu. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 128,
                    height: 128,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.purple.withValues(alpha: 0.30),
                        width: 2,
                      ),
                    ),
                    child: const Text('🐻', style: TextStyle(fontSize: 68)),
                  ),
                ),
                const SizedBox(height: 18),
                // Kimo bu ekranda da konuşur; asıl sorular hemen ardından.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.30),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _isSignUp
                        ? 'Önce kapıyı açalım:\nbir e-posta ve şifre yeter.'
                        : 'Tekrar hoş geldin!\nSeni bekliyordum.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      height: 1.4,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (_isSignUp) ...<Widget>[
                  const SizedBox(height: 8),
                  const Text(
                    'Adını, sınav yılını ve gerisini birazdan ben soracağım.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.inkLight,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                _field(_email, 'E-posta', TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(
                  _password,
                  'Şifre',
                  TextInputType.visiblePassword,
                  obscure: true,
                ),
                if (_isSignUp) ...<Widget>[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _guardianConsent,
                    onChanged: (bool? v) =>
                        setState(() => _guardianConsent = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.green,
                    title: const Text(
                      '18 yaşından küçüğüm ve velimin izni var.',
                      style: TextStyle(fontSize: 13, color: AppColors.ink),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                GameButton(
                  label: _loading
                      ? 'Lütfen bekle...'
                      : (_isSignUp ? 'KAYIT OL' : 'GİRİŞ YAP'),
                  enabled: !_loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'Zaten hesabın var mı? Giriş yap'
                        : 'Hesabın yok mu? Kayıt ol',
                    style: const TextStyle(
                      color: AppColors.blueDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    TextInputType type, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF4F4F4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
