import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bir konunun durumu. Harita "ne kadar biliyorsun"u değil "ne kadarını
/// ölçtük"ü gösterir; bu yüzden veri yokluğu ayrı bir durumdur (başarısızlık
/// değil).
enum TopicState {
  /// Hiç soru çözülmemiş — gri, davet.
  untouched,

  /// Başlanmış ama amblem dolmamış (yeterli veri yok).
  inProgress,

  /// Yeterli veri var, başarıya göre renklenir.
  measured,
}

/// Bir konuda ölçülen ilerleme.
class TopicProgress {
  const TopicProgress({
    required this.subject,
    required this.concept,
    this.attempts = 0,
    this.correct = 0,
    this.lastAt,
  });

  final String subject;
  final String concept;
  final int attempts;
  final int correct;
  final DateTime? lastAt;

  /// Amblemin tam dolması için gereken soru sayısı.
  static const int requiredAttempts = 15;

  /// Renk solmasının tamamlandığı gün sayısı (bu süreden sonra en soluk).
  static const int fadeDays = 30;

  factory TopicProgress.fromRow(Map<String, dynamic> row) {
    final Object? last = row['last_at'];
    return TopicProgress(
      subject: (row['subject'] as String?) ?? '',
      concept: (row['concept'] as String?) ?? '',
      attempts: (row['attempts'] as int?) ?? 0,
      correct: (row['correct'] as int?) ?? 0,
      lastAt: last is String ? DateTime.tryParse(last) : null,
    );
  }

  TopicState get state {
    if (attempts == 0) return TopicState.untouched;
    return attempts >= requiredAttempts
        ? TopicState.measured
        : TopicState.inProgress;
  }

  /// Amblem doluluğu (0–1). 15 soruda tamamlanır.
  double get fill => (attempts / requiredAttempts).clamp(0.0, 1.0);

  /// Tam dolması için kalan soru sayısı.
  int get remaining =>
      attempts >= requiredAttempts ? 0 : requiredAttempts - attempts;

  /// Başarı oranı (0–1). Ölçüm yoksa null.
  double? get successRate => attempts == 0 ? null : correct / attempts;

  int? get successPercent =>
      successRate == null ? null : (successRate! * 100).round();

  /// Son çalışmadan bu yana geçen gün.
  int get daysSince {
    final DateTime? d = lastAt;
    if (d == null) return 0;
    final DateTime today = DateTime.now();
    return DateTime(today.year, today.month, today.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
  }

  /// Tazelik (1 = bugün çalışıldı, 0 = [fadeDays] gün ve üzeri geçti).
  /// Renk bununla soldurulur: uzun süre dokunulmayan konu sönükleşir.
  double get freshness {
    if (attempts == 0) return 0;
    final double t = 1 - (daysSince / fadeDays);
    return t.clamp(0.0, 1.0);
  }

  /// Çok başarısız mı? (ünlem işareti için)
  bool get needsAttention =>
      state == TopicState.measured && (successRate ?? 1) < 0.4;

  /// Konu rengi. Ölçülmemişse gri; ölçülmüşse başarıya göre.
  Color get baseColor => switch (state) {
        TopicState.untouched => const Color(0xFFD9D9D9),
        TopicState.inProgress => AppColors.blue,
        TopicState.measured => switch (successRate!) {
            < 0.4 => AppColors.red,
            < 0.7 => AppColors.orange,
            _ => AppColors.green,
          },
      };

  /// Ekranda kullanılacak renk: solma uygulanmış hâli. Uzun süredir
  /// çalışılmayan konular griye doğru soluklaşır.
  Color get displayColor {
    if (state == TopicState.untouched) return baseColor;
    // En fazla %65 solar; tamamen griye dönüp "hiç çalışılmamış" gibi
    // görünmesin diye taban bırakılır.
    final double t = 0.35 + 0.65 * freshness;
    return Color.lerp(const Color(0xFFD9D9D9), baseColor, t)!;
  }

  /// Maskotun söyleyeceği kısa cümle.
  String get coachMessage {
    switch (state) {
      case TopicState.untouched:
        return 'Bu konuya hiç bakmadık. Birkaç soru çöz, seni tanıyayım!';
      case TopicState.inProgress:
        return 'Bu konuyu tam olarak anlaman için $remaining soru daha '
            'çözmen lazım!';
      case TopicState.measured:
        if (needsAttention) {
          return 'Burada zorlanıyorsun (%$successPercent). Konuyu baştan '
              'çalışmakta fayda var.';
        }
        if ((successRate ?? 0) < 0.7) {
          return 'Fena değil (%$successPercent) ama biraz daha çalışmalısın.';
        }
        if (daysSince >= fadeDays) {
          return 'Bu konu sağlamdı (%$successPercent) ama uzun zamandır '
              'bakmadın, tazelemekte fayda var.';
        }
        return 'Bu konu sağlam (%$successPercent). Böyle devam!';
    }
  }
}
