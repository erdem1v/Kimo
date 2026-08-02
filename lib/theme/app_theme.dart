import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Beyaz zeminli, yuvarlak ve canlı Material 3 teması.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.green,
      surface: Colors.white,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      textTheme: base.textTheme
          .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
          .copyWith(
            headlineSmall: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.ink),
            titleLarge: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.ink),
            titleMedium: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
      dividerColor: AppColors.line,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
