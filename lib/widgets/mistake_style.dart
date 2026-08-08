import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';

/// Hata türüne göre renk (etiket/çip renklendirmesi için).
Color mistakeColor(MistakeType type) => switch (type) {
      MistakeType.kavramEksikligi => AppColors.purple,
      MistakeType.islemHatasi => AppColors.orange,
      MistakeType.dikkatsizlik => AppColors.blue,
    };

/// Derse göre renk — "Bugün" ve "Hatalarım" ekranlarında ortak kullanılır.
const Map<String, Color> _subjectColors = <String, Color>{
  'Türkçe': AppColors.red,
  'Matematik': AppColors.blue,
  'Geometri': AppColors.indigo,
  'Fizik': AppColors.purple,
  'Kimya': AppColors.teal,
  'Biyoloji': AppColors.green,
  'Edebiyat': AppColors.pink,
  'Tarih': AppColors.orange,
  'Coğrafya': AppColors.cyan,
  'Felsefe': AppColors.gold,
  'Felsefe Grubu': AppColors.gold,
  'Din Kültürü': AppColors.indigo,
};

Color subjectColor(String subject) => _subjectColors[subject] ?? AppColors.blue;

const Map<String, String> _subjectEmojis = <String, String>{
  'Türkçe': '📕', 'Matematik': '➗', 'Geometri': '📐', 'Fizik': '🧲',
  'Kimya': '⚗️', 'Biyoloji': '🧬', 'Edebiyat': '📖', 'Tarih': '🏛️',
  'Coğrafya': '🌍', 'Felsefe': '🤔', 'Felsefe Grubu': '🤔', 'Din Kültürü': '🕌',
};

String subjectEmoji(String subject) => _subjectEmojis[subject] ?? '📚';

/// Kısa Türkçe tarih (ör. "30 Tem").
String formatShortDate(DateTime d) {
  const List<String> months = <String>[
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  return '${d.day} ${months[d.month - 1]}';
}
