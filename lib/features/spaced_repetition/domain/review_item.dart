import '../../../shared/models/models.dart';

/// Tekrar seansında gösterilen bir birim: bir soru ve o sorunun tekrar planı.
class ReviewItem {
  const ReviewItem({required this.question, required this.schedule});

  final Question question;
  final ReviewSchedule schedule;
}
