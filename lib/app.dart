import 'package:flutter/material.dart';

import 'package:ai_yks_coach/core/localization/gen/app_localizations.dart';
import 'package:ai_yks_coach/core/theme/app_theme.dart';
import 'package:ai_yks_coach/features/spaced_repetition/presentation/today_reviews_screen.dart';

/// Uygulamanın kök widget'ı. Tema ve Türkçe lokalizasyonu kurar.
class AiYksCoachApp extends StatelessWidget {
  const AiYksCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Uygulama şimdilik yalnızca Türkçe. Yeni dil eklendiğinde bu satır
      // kaldırılıp cihaz diline göre otomatik seçim yapılabilir.
      locale: const Locale('tr'),
      home: const TodayReviewsScreen(),
    );
  }
}
