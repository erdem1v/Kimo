import 'mascot.dart';
import 'models.dart';

/// Bir arkadaşın sana gönderdiği soru.
class ReceivedQuestion {
  const ReceivedQuestion({
    required this.sendId,
    required this.senderNickname,
    required this.subject,
    required this.concept,
    required this.photoPath,
    required this.options,
    required this.correctIndex,
    this.senderMascot,
    this.exam,
    this.note,
    this.solved = false,
    this.correct,
  });

  final String sendId;
  final String senderNickname;
  final Mascot? senderMascot;
  final String subject;
  final String concept;
  final String? exam;
  final String? note;
  final String photoPath;
  final List<QuestionOption> options;
  final int correctIndex;

  /// Çözüldü mü ve sonucu.
  final bool solved;
  final bool? correct;

  factory ReceivedQuestion.fromRow(Map<String, dynamic> row) {
    final dynamic raw = row['options'];
    final List<QuestionOption> options = raw is List
        ? raw
            .map((dynamic o) =>
                QuestionOption.fromJson((o as Map).cast<String, dynamic>()))
            .toList()
        : <QuestionOption>[];
    return ReceivedQuestion(
      sendId: row['send_id'] as String,
      senderNickname: (row['sender_nickname'] as String?) ?? 'Bir arkadaşın',
      senderMascot: Mascot.fromDb(row['sender_mascot'] as String?),
      subject: (row['subject'] as String?) ?? '',
      concept: (row['concept'] as String?) ?? '',
      exam: row['exam'] as String?,
      note: row['note'] as String?,
      photoPath: (row['photo_path'] as String?) ?? '',
      options: options,
      correctIndex: (row['correct_index'] as int?) ?? 0,
      solved: row['solved_at'] != null,
      correct: row['correct'] as bool?,
    );
  }
}
