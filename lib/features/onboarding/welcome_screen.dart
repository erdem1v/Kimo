import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';
import '../auth/login_screen.dart';

/// Uygulamanın karşılama (landing) ekranı. Kimo kendini tanıtır ve ilk soruyu
/// kendisi sorar: yeni misin, yoksa hesabın var mı?
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _open(BuildContext context, {required bool signUp}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(startWithSignUp: signUp),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 12),
                    _kimo(),
                    const SizedBox(height: 22),
                    const Text(
                      'Merhaba, ben Kimo!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Bir ayıyım, biraz da koçun.\n'
                      'Yanlışlarını toplarım, tam unutacakken\n'
                      'karşına çıkarırım.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.inkLight,
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 26),
                    // İlk soruyu da Kimo sorar.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.purple.withValues(alpha: 0.30),
                          width: 1.5,
                        ),
                      ),
                      child: const Text(
                        'Seninle yeni mi tanışıyoruz,\nyoksa hesabın var mı?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.4,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                children: <Widget>[
                  GameButton(
                    label: 'YENİYİM, TANIŞALIM',
                    onPressed: () => _open(context, signUp: true),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _open(context, signUp: false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.line, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'HESABIM VAR',
                        style: TextStyle(
                          color: AppColors.inkLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kimo'nun kendisi: büyük, ortada, gözden kaçmaz.
  Widget _kimo() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (BuildContext context, double v, Widget? child) =>
          Transform.scale(scale: v, child: child),
      child: Container(
        width: 168,
        height: 168,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppColors.purple, AppColors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        // Maskot görseli sonra eklenecek.
        child: const Text('🐻', style: TextStyle(fontSize: 92)),
      ),
    );
  }
}
