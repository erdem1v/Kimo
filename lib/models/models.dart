/// Prototip için sade, kod-üretimi gerektirmeyen veri modelleri.
///
/// Not: Backend kuralları, soru tipleri (Tip A/B/C) ve kalıcı katman bilinçli
/// olarak yok — bunlar ileride ayrıca kurgulanacak. Burada sadece arayüzü
/// beslemek için düz Dart sınıfları var.
library;

import 'dart:typed_data';

/// Bir hatanın türü.
enum MistakeType {
  kavramEksikligi,
  islemHatasi,
  dikkatsizlik;

  String get label => switch (this) {
        MistakeType.kavramEksikligi => 'Kavram eksikliği',
        MistakeType.islemHatasi => 'İşlem hatası',
        MistakeType.dikkatsizlik => 'Dikkatsizlik',
      };

  String get emoji => switch (this) {
        MistakeType.kavramEksikligi => '💡',
        MistakeType.islemHatasi => '✖️',
        MistakeType.dikkatsizlik => '👀',
      };

  /// Veritabanındaki enum değeri.
  String get dbValue => switch (this) {
        MistakeType.kavramEksikligi => 'kavram_eksikligi',
        MistakeType.islemHatasi => 'islem_hatasi',
        MistakeType.dikkatsizlik => 'dikkatsizlik',
      };

  static MistakeType fromDb(String value) => switch (value) {
        'kavram_eksikligi' => MistakeType.kavramEksikligi,
        'islem_hatasi' => MistakeType.islemHatasi,
        _ => MistakeType.dikkatsizlik,
      };
}

/// Çoktan seçmeli pratik sorusu.
class PracticeQuestion {
  const PracticeQuestion({
    required this.subject,
    required this.concept,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String subject;
  final String concept;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

/// Sohbet mesajı (koç veya kullanıcı).
class ChatMessage {
  const ChatMessage(this.text, {this.isUser = false});

  final String text;
  final bool isUser;
}

/// Bir sorunun çoktan seçmeli şıkkı (AI ile fotoğraftan çıkarılır).
class QuestionOption {
  const QuestionOption({required this.label, required this.text});

  final String label; // 'A', 'B', ...
  final String text;

  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
        label: (json['label'] ?? '') as String,
        text: (json['text'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{'label': label, 'text': text};
}

/// AI foto analizinin sonucu. [ok] true ise fotoğrafta okunabilir bir soru +
/// şıklar var demektir; değilse [reason] kısa bir Türkçe sebep içerir.
class QuestionAnalysis {
  const QuestionAnalysis({required this.ok, required this.options, this.reason});

  final bool ok;
  final List<QuestionOption> options;
  final String? reason;
}

/// Hata bankası kaydı.
class MistakeEntry {
  const MistakeEntry({
    required this.subject,
    required this.concept,
    required this.type,
    required this.note,
    required this.date,
    this.hasPhoto = false,
    this.imageBytes,
    this.photoUrl,
    this.options,
    this.correctIndex,
  });

  final String subject;
  final String concept;
  final MistakeType type;
  final String note;
  final DateTime date;
  final bool hasPhoto;

  /// Yeni seçilen fotoğrafın ham baytları (yerel önizleme için).
  final Uint8List? imageBytes;

  /// Supabase Storage'daki fotoğrafın imzalı URL'i (uzak kayıtlar için).
  final String? photoUrl;

  /// AI ile çıkarılan şıklar (varsa).
  final List<QuestionOption>? options;

  /// [options] içindeki doğru şıkkın 0-tabanlı indeksi (varsa).
  final int? correctIndex;

  bool get hasOptions => options != null && options!.isNotEmpty;
}

/// Profil vitrinindeki rozet.
class AchievementBadge {
  const AchievementBadge({
    required this.emoji,
    required this.title,
    required this.earned,
  });

  final String emoji;
  final String title;
  final bool earned;
}

/// Ana ekrandaki konu/ünite kartı.
class TopicCard {
  const TopicCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  final String emoji;
  final String title;
  final String subtitle;

  /// 0–1 arası tamamlanma.
  final double progress;
}
