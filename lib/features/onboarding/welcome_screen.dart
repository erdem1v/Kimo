import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';
import '../auth/login_screen.dart';

/// Uygulamanın karşılama (landing) ekranı: ne işe yaradığını anlatır ve
/// kayıt/giriş akışına yönlendirir.
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  children: <Widget>[
                    _hero(),
                    const SizedBox(height: 26),
                    const Text(
                      'Hatalarından öğren,\nbir daha unutma.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Yanlış yaptığın soruyu çek, gerisini bize bırak.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.inkLight, fontSize: 15),
                    ),
                    const SizedBox(height: 26),
                    _bullet('📸', 'Soruyu çek', 'AI şıkları, dersi ve konuyu çıkarsın.',
                        AppColors.purple),
                    _bullet('🔁', 'Doğru zamanda tekrar',
                        '1 → 3 → 7 → 30 gün aralıklarla karşına gelsin.',
                        AppColors.blue),
                    _bullet('🏆', 'Seri ve XP kazan',
                        'Her gün küçük hedefler, kalıcı öğrenme.',
                        AppColors.gold),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Column(
                children: <Widget>[
                  GameButton(
                    label: 'HADİ BAŞLAYALIM',
                    onPressed: () => _open(context, signUp: true),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _open(context, signUp: false),
                    child: const Text(
                      'Zaten hesabım var',
                      style: TextStyle(
                          color: AppColors.blueDark,
                          fontWeight: FontWeight.w700),
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

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.purple, AppColors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        children: <Widget>[
          // Maskot görseli sonra eklenecek.
          Text('🐻', style: TextStyle(fontSize: 76)),
          SizedBox(height: 8),
          Text(
            'AI YKS Coach',
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 2),
          Text(
            'Kişisel hata bankan',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String emoji, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.inkLight, fontSize: 13, height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
