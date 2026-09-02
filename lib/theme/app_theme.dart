import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

/// Uygulamanın açık ve koyu teması.
///
/// Renk ve tipografi değerleri burada YAZILMAZ; ikisi de `KimoColors` ve
/// `KimoTypography` uzantılarından gelir. Buradaki iş yalnızca o token'ları
/// Material bileşenlerine bağlamak.
class AppTheme {
  const AppTheme._();

  // Her çağrıda yeni bir ThemeData kurmak, `AppSettings` her bildirimde
  // (ör. ses anahtarı) MaterialApp'e farklı bir tema örneği vermek demekti;
  // ThemeData eşitliği kırıldığı için AnimatedTheme 200 ms'lik bir geçiş
  // başlatıyordu. Paletler sabit, tema da sabit olabilir.
  static final ThemeData _light = _build(KimoColors.light, Brightness.light);
  static final ThemeData _dark = _build(KimoColors.dark, Brightness.dark);

  static ThemeData light() => _light;

  static ThemeData dark() => _dark;

  static ThemeData _build(KimoColors c, Brightness brightness) {
    final KimoTypography type = KimoTypography.from(c);

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: c.action,
      brightness: brightness,
    ).copyWith(
      primary: c.action,
      onPrimary: c.onAction,
      surface: c.card,
      onSurface: c.ink,
      error: c.actionTextStrong,
    );

    // Küresel `fontFamily` BİLEREK atanmıyor. Atansaydı henüz yeniden
    // yazılmamış ekranlardaki çıplak `TextStyle`'lar da DMSans'a düşerdi ve o
    // ekranlarda 96 yerde kullanılan `FontWeight.w800` ailede olmayan bir
    // ağırlığa denk gelirdi (DMSans 400–700 gömüldü). Yeni bileşenler zaten
    // aileyi `KimoTypography` üzerinden adlandırıyor; küresel atama son dalgada,
    // bütün ekranlar taşındıktan sonra yapılacak.
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );

    return base.copyWith(
      scaffoldBackgroundColor: c.page,
      canvasColor: c.page,
      dividerColor: c.border,
      // Duolingo tarzı kabartma butonlar kendi basma animasyonunu taşıyor;
      // Material dalgası üstüne binince iki farklı geri bildirim oluyordu.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: c.page,
        surfaceTintColor: c.page,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: c.ink,
        titleTextStyle: type.title,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: c.card,
        modalBarrierColor: c.overlay,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: Radii.all(Radii.card)),
        titleTextStyle: type.section,
        contentTextStyle: type.body,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: type.body.copyWith(color: c.page),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Radii.all(Radii.pill)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.action,
        selectionColor: c.actionTintStrong,
        selectionHandleColor: c.action,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        hintStyle: type.body.copyWith(color: c.inkMuted),
        labelStyle: type.captionStrong,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: Radii.all(Radii.pill),
          borderSide: BorderSide(color: c.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.all(Radii.pill),
          borderSide: BorderSide(color: c.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.all(Radii.pill),
          borderSide: BorderSide(color: c.action, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.all(Radii.pill),
          borderSide: BorderSide(color: c.actionTextStrong, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.all(Radii.pill),
          borderSide: BorderSide(color: c.actionTextStrong, width: 1.8),
        ),
      ),
      textTheme: base.textTheme
          .apply(bodyColor: c.ink, displayColor: c.ink)
          .copyWith(
            headlineLarge: type.display,
            headlineMedium: type.title,
            headlineSmall: type.heading,
            titleLarge: type.section,
            titleMedium: type.label,
            bodyLarge: type.body,
            bodyMedium: type.body,
            bodySmall: type.caption,
            labelLarge: type.buttonSmall,
            labelSmall: type.overline,
          ),
      extensions: <ThemeExtension<dynamic>>[c, type],
    );
  }
}
