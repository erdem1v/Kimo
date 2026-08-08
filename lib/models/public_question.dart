import 'models.dart';

/// Havuzdaki bir soru: başka bir kullanıcının paylaşıma açtığı hatası.
/// Sahibinden yalnızca takma ad taşınır (not/hata türü paylaşılmaz).
class PublicQuestion {
  const PublicQuestion({
    required this.id,
    required this.ownerNickname,
    required this.subject,
    required this.concept,
    required this.photoPath,
    required this.options,
    required this.correctIndex,
    this.exam,
    this.solvedCorrect = 0,
    this.solvedWrong = 0,
  });

  final String id;
  final String ownerNickname;
  final String subject;
  final String concept;
  final String? exam;
  final String photoPath;
  final List<QuestionOption> options;
  final int correctIndex;

  /// Havuzda kaç kişi doğru/yanlış çözdü.
  final int solvedCorrect;
  final int solvedWrong;

  int get totalAttempts => solvedCorrect + solvedWrong;

  /// Doğru çözenlerin yüzdesi (deneme yoksa null).
  int? get successRate => totalAttempts == 0
      ? null
      : (solvedCorrect / totalAttempts * 100).round();

  factory PublicQuestion.fromRow(Map<String, dynamic> row) {
    final dynamic raw = row['options'];
    final List<QuestionOption> options = raw is List
        ? raw
            .map((dynamic o) =>
                QuestionOption.fromJson((o as Map).cast<String, dynamic>()))
            .toList()
        : <QuestionOption>[];
    return PublicQuestion(
      id: row['id'] as String,
      ownerNickname: (row['owner_nickname'] as String?) ?? 'Bir öğrenci',
      subject: (row['subject'] as String?) ?? '',
      concept: (row['concept'] as String?) ?? '',
      exam: row['exam'] as String?,
      photoPath: (row['photo_path'] as String?) ?? '',
      options: options,
      correctIndex: (row['correct_index'] as int?) ?? 0,
      solvedCorrect: (row['solved_correct'] as int?) ?? 0,
      solvedWrong: (row['solved_wrong'] as int?) ?? 0,
    );
  }
}
