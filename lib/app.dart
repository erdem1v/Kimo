import 'package:flutter/material.dart';

import 'features/auth/auth_gate.dart';
import 'features/home/home_shell.dart';
import 'l10n/generated/app_localizations.dart';
import 'services/notification_router.dart';
import 'services/supabase_config.dart';
import 'state/app_settings.dart';
import 'theme/app_theme.dart';

/// Uygulamanın kök widget'ı.
///
/// Tema modu `AppSettings`'ten gelir ve varsayılanı **sistem**: cihaz koyu
/// moddaysa uygulama koyu açılır, kullanıcı elle seçim yapana kadar sistemi
/// takip eder.
class AiYksCoachApp extends StatelessWidget {
  const AiYksCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Supabase yapılandırılmışsa giriş kapısı, değilse doğrudan mock uygulama.
    final Widget home =
        SupabaseConfig.isConfigured ? const AuthGate() : const HomeShell();

    // Yalnızca tema modu dinleniyor; `home` sabit tutulup child olarak
    // geçiliyor ki tercih değiştiğinde ekran ağacı baştan kurulmasın.
    return ListenableBuilder(
      listenable: appSettings,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          onGenerateTitle: (BuildContext context) => L10n.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          // Bildirimden gelen yönlendirmeler widget ağacının dışından çağrılır.
          navigatorKey: NotificationRouter.navigatorKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: appSettings.themeMode,
          localizationsDelegates: L10n.localizationsDelegates,
          // Tek dil: Türkçe. `en` bilinçli olarak kaldırıldı — İngilizce cihazda
          // kullanıcı zaten Türkçe görüyordu, desteklenmeyen bir dili beyan
          // etmek yanlıştı.
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('tr'),
          home: child,
        );
      },
      child: home,
    );
  }
}
