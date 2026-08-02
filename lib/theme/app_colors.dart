import 'package:flutter/material.dart';

/// Duolingo esintili, beyaz zemin üzerinde canlı renk paleti.
class AppColors {
  AppColors._();

  static const Color bg = Colors.white;
  static const Color ink = Color(0xFF3C3C3C);
  static const Color inkLight = Color(0xFF777777);
  static const Color line = Color(0xFFE5E5E5);
  static const Color disabled = Color(0xFFE5E5E5);
  static const Color disabledText = Color(0xFFAFAFAF);

  // Yeşil — birincil aksiyon / doğru
  static const Color green = Color(0xFF58CC02);
  static const Color greenDark = Color(0xFF58A700);
  static const Color greenBg = Color(0xFFD7FFB8);

  // Mavi — koç / bilgi
  static const Color blue = Color(0xFF1CB0F6);
  static const Color blueDark = Color(0xFF1899D6);
  static const Color blueBg = Color(0xFFDDF4FF);

  // Kırmızı — can / yanlış
  static const Color red = Color(0xFFFF4B4B);
  static const Color redDark = Color(0xFFEA2B2B);
  static const Color redBg = Color(0xFFFFDFE0);

  // Altın — XP
  static const Color gold = Color(0xFFFFC800);
  static const Color goldDark = Color(0xFFE6A700);

  // Turuncu — seri (streak)
  static const Color orange = Color(0xFFFF9600);
  static const Color orangeDark = Color(0xFFE08600);

  // Mor — rozet / özel
  static const Color purple = Color(0xFFCE82FF);
  static const Color purpleDark = Color(0xFFA560E8);
}
