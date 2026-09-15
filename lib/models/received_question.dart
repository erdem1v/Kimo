import 'mascot.dart';
import 'models.dart';

/// Bir arkadaşın sana gönderdiği soru.
class ReceivedQuestion {
  const ReceivedQuestion({
    required this.sendId,
    required this.senderId,
    required this.senderNickname,
    required this.subject,
    required this.concept,
    required this.photoPath,
    required this.options,
    this.correctIndex,
    this.senderMascot,
    this.senderAvatarPath,
    this.exam,
    this.note,
    this.solved = false,
    this.correct,
  });

  final String sendId;

  /// Gönderenin kimliği.
  ///
  /// Görünüm bunu Task 08'den beri döndürüyordu ama model okumuyordu: hiçbir
  /// ekran ihtiyaç duymamıştı. Ortak seri (Tur 7 · n6) çözümden sonra
  /// gönderene bir çağrı gösterdiği için artık gerekiyor.
  final String senderId;

  final String senderNickname;
  final Mascot? senderMascot;

  /// Gönderenin avatar yolu (0081).
  ///
  /// GÖNDEREN ZORUNLU OLARAK ARKADAŞ (`sends_insert_friend` politikası
  /// `are_friends` istiyor), yani bu alan avatarı yabancıya AÇMIYOR — ilişki
  /// kapısı zaten sağlanmış durumda. İmzalı URL ayrıca `can_read_avatar`ın
  /// arkadaşlık dalından geçiyor; sütun tek başına dosya erişimi vermiyor.
  final String? senderAvatarPath;

  final String subject;
  final String concept;
  final String? exam;
  final String? note;
  final String photoPath;
  final List<QuestionOption> options;
  /// Doğru şıkkın indeksi.
  ///
  /// ÇÖZÜLMEDEN ÖNCE null: cevabı istemciye önceden vermek, doğruluğu sunucuya
  /// taşımayı anlamsız kılardı (bkz. 0035 göçü). Çözdükten sonra görünüm bunu
  /// döndürüyor, böylece kullanıcı geri dönüp cevabına bakabiliyor.
  final int? correctIndex;

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
      senderId: (row['sender_id'] as String?) ?? '',
      senderNickname: (row['sender_nickname'] as String?) ?? 'Bir arkadaşın',
      senderMascot: Mascot.fromDb(row['sender_mascot'] as String?),
      senderAvatarPath: row['sender_avatar_path'] as String?,
      subject: (row['subject'] as String?) ?? '',
      concept: (row['concept'] as String?) ?? '',
      exam: row['exam'] as String?,
      note: row['note'] as String?,
      photoPath: (row['photo_path'] as String?) ?? '',
      options: options,
      // Yalnızca ÇÖZÜLMÜŞ gönderilerde dolu gelir (bkz. 0035 göçü).
      correctIndex: (row['correct_index'] as num?)?.toInt(),
      solved: row['solved_at'] != null,
      correct: row['correct'] as bool?,
    );
  }
}
