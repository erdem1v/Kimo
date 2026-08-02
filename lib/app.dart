import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/home/home_shell.dart';
import 'theme/app_theme.dart';

/// Uygulamanın kök widget'ı. Beyaz temayı ve Türkçe yerelleştirmeyi kurar.
class AiYksCoachApp extends StatelessWidget {
  const AiYksCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI YKS Coach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('tr'), Locale('en')],
      locale: const Locale('tr'),
      home: const HomeShell(),
    );
  }
}
