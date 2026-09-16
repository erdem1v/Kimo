import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../../data/sanction_repository.dart';
import '../../data/photo_queue.dart';
import '../../data/submission_queue.dart';
import '../../state/game_progress.dart';
import '../../state/user_profile.dart';
import '../home/home_shell.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/welcome_screen.dart';
import '../settings/suspended_screen.dart';

/// Oturum ve profil durumuna göre yönlendirir:
/// oturum yok → karşılama (landing) · profil eksik → karşılama akışı ·
/// askıda → [SuspendedScreen] · tamam → uygulama.
///
/// Not: profil yüklemesi build sırasında değil, oturum değişiminde yapılır
/// (build içinde notifyListeners çağırmak "!_dirty" hatasına yol açar).
///
/// **Askı ekranı bir DUVAR DEĞİL.** Kullanıcı "Uygulamaya dön" ile geçebiliyor;
/// yasağı zorlayan şey bu ekran değil, veri katmanındaki politikalar (göç
/// 0062). Buradaki tek iş kullanıcıya NE olduğunu ve itiraz yolunu söylemek —
/// aksi hâlde reddedilen her yükleme açıklanamayan bir hataya dönerdi.
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

  /// Askı durumu. `null` = henüz okunmadı ya da OKUNAMADI; ikisi de ekranı
  /// göstermiyor — ağ hatası bir yaptırım değildir.
  SanctionStatus? _sanction;

  /// Kullanıcı askı ekranını kapattı; bu oturumda tekrar gösterilmiyor.
  bool _sanctionDismissed = false;

  @override
  void initState() {
    super.initState();
    // İlk durum: setState olmadan doğrudan ata.
    final Session? session = authRepository.currentSession;
    _hasSession = session != null;
    if (_hasSession) {
      userProfile.loadFromAuth();
      _needsOnboarding = _mustOnboard();
      unawaited(_loadSanction());
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

  /// Askı durumunu okur. Anonim oturumda çağrılmıyor: henüz hesap yok.
  Future<void> _loadSanction() async {
    if (authRepository.isAnonymous) return;
    final SanctionStatus? s = await sanctionRepository.mySanction();
    if (mounted && s != null) setState(() => _sanction = s);
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
      // İLERLEME DE SIFIRLANIYOR (Task 14). Eskiden burada yoktu ve aynı
      // cihazda açılan İKİNCİ hesap, öncekinin XP'sini, serisini ve günlük
      // sayacını görüyordu. Kendiliğinden düzelmiyordu: `syncDailyDone`
      // yalnızca yukarı hareket ediyor, `hydrate` ise ancak sunucu okuması
      // başarılıysa çalışıyor.
      gameProgress.clear();
      // Bekleyen cevaplar diskte kalmasın: aynı cihazda başka bir hesap
      // açılırsa onlar YANLIŞ kullanıcıya yazılırdı. (Kuyruk ayrıca her kaydın
      // sahibini de tutuyor ve boşaltırken yabancı kayıtları atıyor — bu iki
      // katmanın ilki.)
      submissionQueue.clear();
      // Aynı gerekçe fotoğraflar için de geçerli, üstelik daha güçlü: kuyruk
      // diskte JPEG tutuyor. Başka bir hesap açıldığında hem yanlış arşive
      // yazılırlar hem de o kullanıcının cihazında yabancı bir fotoğraf kalır.
      photoQueue.clear();
    }

    if (!hasSession) {
      _sanction = null;
      _sanctionDismissed = false;
    } else if (!_hasSession) {
      unawaited(_loadSanction());
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

    // OTURUM DÜŞTÜYSE YIĞINI KÖKE İNDİR (Task 14).
    //
    // Bu kapı MaterialApp'in `home`'u; `setState` yalnızca KÖK rotanın
    // içeriğini değiştiriyor. Ayarlar, profil alt ekranları ve benzerleri
    // Navigator'a İTİLMİŞ rotalar, yani kökün ÜSTÜNDE duruyorlar ve kapı
    // karşılama ekranına dönse bile ekranda kalmaya devam ediyorlardı.
    //
    // Görünen hâli: "Çıkış yap"a basan kullanıcı Ayarlar ekranında kalıyor ve
    // hâlâ giriş yapmış gibi görünüyordu — oysa oturum gerçekten kapanmıştı
    // (`supabase.auth: Signing out user`, saklanan jeton siliniyor). Sonraki
    // her istek sessizce yetkisiz düşerdi. Simülatörde üretildi: çıkıştan
    // sonra Ayarlar açık kalıyor, saklanan `auth-token` anahtarı ise yok.
    //
    // Hesap silme yolu da aynı kapıdan geçiyor (`delete-account` sonrası
    // `signOut`), yani orada da geçerli.
    if (!hasSession) {
      final NavigatorState nav = Navigator.of(context);
      if (nav.canPop()) nav.popUntil((Route<dynamic> r) => r.isFirst);
    }

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
        onDone: () {
          setState(() => _needsOnboarding = false);
          unawaited(_loadSanction());
        },
      );
    }
    final SanctionStatus? s = _sanction;
    if (s != null && s.suspended && !_sanctionDismissed) {
      return SuspendedScreen(
        status: s,
        onContinue: () => setState(() => _sanctionDismissed = true),
      );
    }
    return const HomeShell();
  }
}
