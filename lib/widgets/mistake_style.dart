import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';

/// Hata türüne göre renk (etiket/çip renklendirmesi için).
Color mistakeColor(MistakeType type) => switch (type) {
      MistakeType.kavramEksikligi => AppColors.purple,
      MistakeType.islemHatasi => AppColors.orange,
      MistakeType.dikkatsizlik => AppColors.blue,
    };

/// Kısa Türkçe tarih (ör. "30 Tem").
String formatShortDate(DateTime d) {
  const List<String> months = <String>[
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  return '${d.day} ${months[d.month - 1]}';
}
