import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../../data/submission_queue.dart';
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
      _needsOnboarding = _mustOnboard();
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

  /// Karşılama akışı gösterilmeli mi.
  ///
  /// ANONİM OTURUM HER ZAMAN AKIŞA GİRER. Tercihleri doldurup kaydı atlayan
  /// bir kullanıcı `onboardingComplete` ölçüsünü geçerdi ama hesabı olmazdı:
  /// cihazı değişince ya da oturum düşünce her şeyi kaybederdi. Kayıt akışın
  /// son adımı ve atlanabilir değil.
  bool _mustOnboard() =>
      !userProfile.onboardingComplete || authRepository.isAnonymous;

  void _applySession(Session? session) {
    final bool hasSession = session != null;
    if (hasSession) {
      userProfile.loadFromAuth();
    } else {
      userProfile.clear();
      // Bekleyen cevaplar diskte kalmasın: aynı cihazda başka bir hesap
      // açılırsa onlar YANLIŞ kullanıcıya yazılırdı. (Kuyruk ayrıca her kaydın
      // sahibini de tutuyor ve boşaltırken yabancı kayıtları atıyor — bu iki
      // katmanın ilki.)
      submissionQueue.clear();
    }

    bool needs = _needsOnboarding;
    if (!hasSession) {
      needs = false;
    } else if (!_hasSession) {
      // Yalnızca oturum YENİ açıldığında karar ver. Akış sürerken gelen
      // updateUser olayları (tercih kayıtları) akışı yarıda kapatmasın.
      needs = _mustOnboard();
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
