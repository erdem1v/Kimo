import 'package:freezed_annotation/freezed_annotation.dart';

part 'gamification_state.freezed.dart';
part 'gamification_state.g.dart';

/// Bir öğrencinin oyunlaştırma (gamification) durumu: XP, seri, can ve rozetler.
///
/// Çekirdek öğrenme mantığından (aralıklı tekrar) bağımsız tutulur.
@freezed
abstract class GamificationState with _$GamificationState {
  const factory GamificationState({
    required String studentId,
    @Default(0) int xp,

    /// Art arda çalışılan gün sayısı (günlük seri / streak).
    @Default(0) int streak,

    /// Kalan can/kalp sayısı.
    @Default(5) int hearts,

    /// Kazanılan rozet kimlikleri.
    @Default(<String>[]) List<String> badges,

    /// Serinin hesaplanması için son aktivite günü (opsiyonel).
    DateTime? lastActivityDate,
  }) = _GamificationState;

  factory GamificationState.fromJson(Map<String, dynamic> json) =>
      _$GamificationStateFromJson(json);
}
