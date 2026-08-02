import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';

/// Giriş / kayıt ekranı. Kayıt akışında yaş/veli onayı kutucuğu (reşit olmayan
/// kullanıcılar için UI iskeleti). Başarılı oturumda AuthGate otomatik geçiş
/// yapar.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();

  bool _isSignUp = false;
  bool _guardianConsent = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        await authRepository.signUp(
          email: email,
          password: password,
          displayName: _name.text.trim().isEmpty ? 'Öğrenci' : _name.text.trim(),
          guardianConsent: _guardianConsent,
        );
        if (authRepository.currentSession == null && mounted) {
          _snack('Kayıt alındı. E-posta onayı açıksa gelen kutunu kontrol et.');
        }
      } else {
        await authRepository.signIn(email: email, password: password);
      }
      // Oturum açılırsa AuthGate otomatik olarak uygulamaya geçirir.
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
                const SizedBox(height: 12),
                const Text('🦉', style: TextStyle(fontSize: 64), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text(
                  'AI YKS Coach',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSignUp ? 'Hesap oluştur' : 'Tekrar hoş geldin',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkLight, fontSize: 15),
                ),
                const SizedBox(height: 28),
                if (_isSignUp) ...<Widget>[
                  _field(_name, 'Adın', TextInputType.name),
                  const SizedBox(height: 12),
                ],
                _field(_email, 'E-posta', TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(_password, 'Şifre', TextInputType.visiblePassword,
                    obscure: true),
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
                        color: AppColors.blueDark, fontWeight: FontWeight.w700),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
