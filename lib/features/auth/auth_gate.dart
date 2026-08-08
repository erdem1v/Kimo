import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../../state/user_profile.dart';
import '../home/home_shell.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/welcome_screen.dart';

/// Oturum ve profil durumuna göre yönlendirir:
/// oturum yok → karşılama (landing) · profil eksik → karşılama akışı ·
/// tamam → uygulama.
///
/// Not: profil yüklemesi build sırasında değil, oturum değişiminde yapılır
/// (build içinde notifyListeners çağırmak "!_dirty" hatasına yol açar).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;
  bool _hasSession = false;
  // Karşılama akışı gösterilsin mi? Oturum açıldığında BİR KEZ belirlenir;
  // akış içindeki tercih kayıtları ekranı erkenden değiştirmesin diye.
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    // İlk durum: setState olmadan doğrudan ata.
    final Session? session = authRepository.currentSession;
    _hasSession = session != null;
    if (_hasSession) {
      userProfile.loadFromAuth();
      _needsOnboarding = !userProfile.onboardingComplete;
    }
    _sub = authRepository.authStateChanges.listen((AuthState _) {
      if (mounted) _applySession(authRepository.currentSession);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _applySession(Session? session) {
    final bool hasSession = session != null;
    if (hasSession) {
      userProfile.loadFromAuth();
    } else {
      userProfile.clear();
    }

    bool needs = _needsOnboarding;
    if (!hasSession) {
      needs = false;
    } else if (!_hasSession) {
      // Yalnızca oturum YENİ açıldığında karar ver. Akış sürerken gelen
      // updateUser olayları (tercih kayıtları) akışı yarıda kapatmasın.
      needs = !userProfile.onboardingComplete;
    }

    if (hasSession == _hasSession && needs == _needsOnboarding) return;
    setState(() {
      _hasSession = hasSession;
      _needsOnboarding = needs;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasSession) return const WelcomeScreen();
    if (_needsOnboarding) {
      return OnboardingFlow(
        onDone: () => setState(() => _needsOnboarding = false),
      );
    }
    return const HomeShell();
  }
}
