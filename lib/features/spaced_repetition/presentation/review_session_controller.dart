import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_yks_coach/core/constants/app_constants.dart';
import 'package:ai_yks_coach/features/spaced_repetition/data/mock_today_reviews_repository.dart';
import 'package:ai_yks_coach/features/spaced_repetition/domain/review_item.dart';
import 'package:ai_yks_coach/features/spaced_repetition/domain/spaced_repetition_scheduler.dart';
import 'package:ai_yks_coach/shared/models/models.dart';

/// "Bugünün Tekrarları" seansının anlık durumu (immutable).
class ReviewSessionState {
  const ReviewSessionState({
    this.isLoading = false,
    this.queue = const <ReviewItem>[],
    this.currentIndex = 0,
    this.answerRevealed = false,
    this.correctCount = 0,
    this.answeredCount = 0,
    this.hearts = AppConstants.initialHearts,
    this.xp = 0,
    this.streak = 0,
    this.lastScheduledDays,
  });

  final bool isLoading;
  final List<ReviewItem> queue;
  final int currentIndex;
  final bool answerRevealed;
  final int correctCount;
  final int answeredCount;
  final int hearts;
  final int xp;
  final int streak;

  /// Son cevaplanan sorunun planlanan bir sonraki tekrar aralığı (gün).
  final int? lastScheduledDays;

  bool get isEmpty => !isLoading && queue.isEmpty;

  bool get isComplete =>
      !isLoading && queue.isNotEmpty && currentIndex >= queue.length;

  ReviewItem? get current =>
      (!isLoading && currentIndex >= 0 && currentIndex < queue.length)
          ? queue[currentIndex]
          : null;

  int get total => queue.length;

  double get progress => queue.isEmpty ? 0 : answeredCount / queue.length;

  ReviewSessionState copyWith({
    bool? isLoading,
    List<ReviewItem>? queue,
    int? currentIndex,
    bool? answerRevealed,
    int? correctCount,
    int? answeredCount,
    int? hearts,
    int? xp,
    int? streak,
    int? lastScheduledDays,
  }) {
    return ReviewSessionState(
      isLoading: isLoading ?? this.isLoading,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      answerRevealed: answerRevealed ?? this.answerRevealed,
      correctCount: correctCount ?? this.correctCount,
      answeredCount: answeredCount ?? this.answeredCount,
      hearts: hearts ?? this.hearts,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      lastScheduledDays: lastScheduledDays ?? this.lastScheduledDays,
    );
  }
}

/// Tekrar seansını yöneten Riverpod denetleyicisi (Notifier).
///
/// Not: Buradaki oyunlaştırma sayaçları (can/XP) yalnızca ekranı canlandırmak
/// içindir; kalıcı oyunlaştırma mantığı ayrı `gamification` modülünde
/// geliştirilecektir. Cevap verildiğinde bir sonraki tekrar tarihi saf
/// [SpacedRepetitionScheduler] ile hesaplanır.
class ReviewSessionController extends Notifier<ReviewSessionState> {
  static const SpacedRepetitionScheduler _scheduler =
      SpacedRepetitionScheduler();

  @override
  ReviewSessionState build() {
    _load();
    return const ReviewSessionState(isLoading: true);
  }

  Future<void> _load() async {
    final repo = ref.read(todayReviewsRepositoryProvider);
    final items = await repo.dueReviews(today: DateTime.now());
    state = ReviewSessionState(
      queue: items,
      hearts: AppConstants.initialHearts,
      streak: AppConstants.demoStreak,
    );
  }

  /// Mevcut sorunun cevabını açığa çıkarır.
  void revealAnswer() {
    if (state.current == null) return;
    state = state.copyWith(answerRevealed: true);
  }

  /// Mevcut soruyu [grade] ile cevaplar, planı günceller ve sıradaki soruya
  /// geçer.
  void answer(ReviewGrade grade) {
    final item = state.current;
    if (item == null) return;

    final SrsState updated = _scheduler.schedule(
      current: SrsState(
        repetitions: item.schedule.repetitions,
        easeFactor: item.schedule.easeFactor,
        intervalDays: item.schedule.intervalDays,
        nextReviewDate: item.schedule.nextReviewDate,
      ),
      quality: grade.quality,
      reviewedAt: DateTime.now(),
    );

    final bool correct = grade.quality >= 3;
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      answerRevealed: false,
      answeredCount: state.answeredCount + 1,
      correctCount: state.correctCount + (correct ? 1 : 0),
      xp: state.xp + (correct ? AppConstants.xpPerCorrectAnswer : 0),
      hearts: correct ? state.hearts : (state.hearts > 0 ? state.hearts - 1 : 0),
      lastScheduledDays: updated.intervalDays,
    );
  }

  /// Seansı baştan başlatır.
  void restart() {
    state = const ReviewSessionState(isLoading: true);
    _load();
  }
}

final reviewSessionControllerProvider =
    NotifierProvider<ReviewSessionController, ReviewSessionState>(
  ReviewSessionController.new,
);
