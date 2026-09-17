import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/models/models.dart';

/// S6 — GÖNDERİLEBİLİRLİK ÖLÇÜTÜ SUNUCUYLA AYNI OLMAK ZORUNDA.
///
/// `send_question_to_friends` beş koşul arıyor: satır bana ait, fotoğraf var,
/// şıklar var, doğru şık var, `moderation = 'ok'` ve `photo_scan = 'clear'`.
/// Arşiv listesi bunlardan yalnızca ÜÇÜNE bakıyordu: damgalanmış bir fotoğraf
/// listede gönderilebilir görünüyor, kullanıcı dokunuyor ve ancak sunucudan
/// dönen hatayla öğreniyordu.
void main() {
  MistakeEntry e({
    String? id = 'm1',
    String? photoPath = 'u/1.jpg',
    List<QuestionOption>? options,
    int? correctIndex = 0,
    String? moderation = 'ok',
    String? photoScan = 'clear',
  }) =>
      MistakeEntry(
        id: id,
        subject: 'Matematik',
        concept: 'Türev',
        note: '',
        date: DateTime(2026, 9, 1),
        photoPath: photoPath,
        hasPhoto: photoPath != null,
        options: options ??
            <QuestionOption>[
              const QuestionOption(label: 'A', text: '1'),
              const QuestionOption(label: 'B', text: '2'),
            ],
        correctIndex: correctIndex,
        moderation: moderation,
        photoScan: photoScan,
      );

  test('beş koşulu da sağlayan soru gönderilebilir', () {
    expect(e().sendable, isTrue);
  });

  test('DAMGALANMIŞ fotoğraf gönderilemez', () {
    expect(e(moderation: 'flagged').sendable, isFalse);
    expect(e(photoScan: 'flagged').sendable, isFalse);
  });

  test('taraması bitmemiş fotoğraf gönderilemez — ve bu GEÇİCİ', () {
    final MistakeEntry p = e(photoScan: 'pending');
    expect(p.sendable, isFalse);
    expect(p.scanPending, isTrue,
        reason: 'ekran geçici sebebe kalıcıdan FARKLI cümle yazıyor');
    expect(e(moderation: 'flagged').scanPending, isFalse);
  });

  test('eksik içerik gönderilemez', () {
    expect(e(photoPath: null).sendable, isFalse);
    expect(e(options: const <QuestionOption>[]).sendable, isFalse);
    expect(e(correctIndex: null).sendable, isFalse);
    expect(e(id: null).sendable, isFalse);
  });

  test('sütunlar OKUNAMADIYSA ölçüt engellemiyor (fail-open)', () {
    // Gerçek kapı sunucuda; buradaki yalnızca ekranın dürüst durması. Eski
    // bir sunucu sütunları vermiyorsa listeyi boşaltmak daha kötü olurdu.
    expect(e(moderation: null, photoScan: null).sendable, isTrue);
  });
}
