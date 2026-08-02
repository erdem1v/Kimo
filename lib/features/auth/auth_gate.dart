import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../home/home_shell.dart';
import 'login_screen.dart';

/// Oturum durumuna göre giriş ekranı ya da uygulamayı gösterir.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authRepository.authStateChanges,
      builder: (BuildContext context, AsyncSnapshot<AuthState> snapshot) {
        final Session? session = authRepository.currentSession;
        if (session != null) return const HomeShell();
        return const LoginScreen();
      },
    );
  }
}
