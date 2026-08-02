import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'review_schedule.freezed.dart';
part 'review_schedule.g.dart';

/// Bir soru–öğrenci çiftinin aralıklı tekrar planı.
///
/// Alanlar `SpacedRepetitionScheduler`/`SrsState` ile birebir eşleşir; kalıcı
/// katman (drift) bu modeli saklar, hesaplama saf scheduler'da yapılır.
@freezed
abstract class ReviewSchedule with _$ReviewSchedule {
  const factory ReviewSchedule({
    required String id,
    required String studentId,
    required String questionId,
    @Default(0) int intervalDays,
    @Default(2.5) double easeFactor,
    @Default(0) int repetitions,
    required DateTime nextReviewDate,

    /// Son cevabın sonucu (sonSonuç).
    ReviewGrade? lastGrade,
  }) = _ReviewSchedule;

  factory ReviewSchedule.fromJson(Map<String, dynamic> json) =>
      _$ReviewScheduleFromJson(json);
}
