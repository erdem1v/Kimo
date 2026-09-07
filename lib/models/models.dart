/// Kod üretimi gerektirmeyen sade veri modelleri.
///
/// Sunucu tarafı ve kalıcı katman Supabase'te; buradaki sınıflar yalnızca satır
/// haritalarını arayüzün okuyabileceği biçime çeviriyor.
library;

import 'dart:typed_data';

/// Bir hatanın türü.
enum MistakeType {
  /// Tasarımın dört sebebi.
  bilgiEksigi,
  dikkatsizlik,
  sureYetmedi,
  yanlisOkudum,

  /// ESKİ KAYITLAR İÇİN. Arayüzde seçenek olarak GÖSTERİLMİYOR ama eski
  /// satırlar bu değeri taşıyor ve onları başka bir sebebe eşlemek veriyi
  /// bozardı.
  islemHatasi;

  /// Kullanıcıya sunulan sebepler, tasarımdaki sırayla.
  static const List<MistakeType> choices = <MistakeType>[
    MistakeType.dikkatsizlik,
    MistakeType.bilgiEksigi,
    MistakeType.sureYetmedi,
    MistakeType.yanlisOkudum,
  ];

  String get label => switch (this) {
    MistakeType.bilgiEksigi => 'Bilgi eksiği',
    MistakeType.dikkatsizlik => 'Dikkatsizlik',
    MistakeType.sureYetmedi => 'Süre yetmedi',
    MistakeType.yanlisOkudum => 'Yanlış okudum',
    MistakeType.islemHatasi => 'İşlem hatası',
  };

  /// Veritabanındaki enum değeri.
  ///
  /// `bilgiEksigi` eski `kavram_eksikligi` değerine yazılıyor: aynı şeyin iki
  /// adı olmasın diye yeni bir enum değeri EKLENMEDİ, yalnızca etiketi
  /// tasarımın diline çevrildi.
  String get dbValue => switch (this) {
    MistakeType.bilgiEksigi => 'kavram_eksikligi',
    MistakeType.dikkatsizlik => 'dikkatsizlik',
    MistakeType.sureYetmedi => 'sure_yetmedi',
    MistakeType.yanlisOkudum => 'yanlis_okudum',
    MistakeType.islemHatasi => 'islem_hatasi',
  };

  /// Bilinmeyen değer `null` döner: sütun artık isteğe bağlı ve "belirtilmedi"
  /// gerçek bir durum. Uydurma bir tür yazmıyoruz.
  static MistakeType? fromDb(String? value) => switch (value) {
    'kavram_eksikligi' => MistakeType.bilgiEksigi,
    'dikkatsizlik' => MistakeType.dikkatsizlik,
    'sure_yetmedi' => MistakeType.sureYetmedi,
    'yanlis_okudum' => MistakeType.yanlisOkudum,
    'islem_hatasi' => MistakeType.islemHatasi,
    _ => null,
  };
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
/// şıklar var demektir; değilse [failure] nedeni söyler.
///
/// **Modelden gelen serbest metin YOK (Task 03):** eski `reason` alanı
/// modelin yazdığı Türkçe cümleyi taşıyordu. Hazırlanmış bir görsel o alana
/// istediği metni yazdırabilirdi; sunucu artık yalnızca enum kod döndürüyor
/// ve istemci kendi yerelleştirilmiş metnini gösteriyor.
///
/// Geçerliyse AI ayrıca soruyu sınıflandırır: [exam] (TYT/AYT), [subject]
/// (ders) ve [concept] (konu). [conceptValid] true ise konu taksonomideki bir
/// adla birebir eşleşmiştir; false ise AI'nın en yakın tahminidir.
/// Analizin başarısızlık nedeni — sunucudaki `reason_code` enum'unun
/// istemci karşılığı + yalnızca istemcide oluşan `network`.
enum AnalysisFailure {
  /// Fotoğraf okunaklı değil (bulanık, karanlık, kesik).
  unreadable,

  /// Görselde bir soru ifadesi yok (ör. yalnızca şıklar).
  noQuestion,

  /// Şıklar görünmüyor.
  noOptions,

  /// Sunucuya hiç ulaşılamadı (çevrimdışı / zaman aşımı). Sunucudan gelmez.
  network,

  /// Sunucu tanımadığımız bir kod döndürdü ya da gövde bozuktu.
  unknown;

  static AnalysisFailure? fromCode(String? code) => switch (code) {
        'ok' => null,
        'unreadable' => AnalysisFailure.unreadable,
        'no_question' => AnalysisFailure.noQuestion,
        'no_options' => AnalysisFailure.noOptions,
        _ => AnalysisFailure.unknown,
      };
}

class QuestionAnalysis {
  const QuestionAnalysis({
    required this.ok,
    required this.options,
    this.failure,
    this.exam,
    this.subject,
    this.concept,
    this.conceptValid = false,
    this.outOfCredit = false,
    this.creditResetsAt,
    this.creditRemaining,
  });

  /// Günlük yapay zekâ hakkı bittiği için analiz HİÇ YAPILMADI.
  ///
  /// Bu bir HATA DEĞİL: fotoğraf duruyor, kullanıcı şıkları ve konuyu elle
  /// girip kaydediyor. Kaydetme yolu asla kapanmıyor.
  const QuestionAnalysis.outOfCredit({this.creditResetsAt})
      : ok = false,
        options = const <QuestionOption>[],
        failure = null,
        exam = null,
        subject = null,
        concept = null,
        conceptValid = false,
        outOfCredit = true,
        creditRemaining = 0;

  final bool ok;
  final List<QuestionOption> options;
  /// Analiz neden başarısız oldu (`ok == false` iken); `null` = bilinmiyor.
  final AnalysisFailure? failure;

  /// 'TYT' | 'AYT' | null.
  final String? exam;

  /// AI'nın önerdiği ders (ör. 'Matematik').
  final String? subject;

  /// AI'nın önerdiği konu (ör. 'Türev').
  final String? concept;

  /// Konu, taksonomideki bir adla birebir eşleşti mi?
  final bool conceptValid;

  /// Hak bitti mi (analiz yapılmadı).
  final bool outOfCredit;

  /// Hakların tazeleneceği an. Arayüzde geri sayım GÖSTERİLMEZ; yalnızca
  /// "yarın yenilenecek" bilgisi için.
  final DateTime? creditResetsAt;

  /// Bu çağrıdan sonra kalan hak (sunucu söyledi).
  final int? creditRemaining;
}

/// Hata bankası kaydı.
class MistakeEntry {
  const MistakeEntry({
    required this.subject,
    required this.concept,
    this.type,
    required this.note,
    required this.date,
    this.hasPhoto = false,
    this.imageBytes,
    this.photoPath,
    this.options,
    this.correctIndex,
    this.id,
    this.step = 0,
    this.lapses = 0,
    this.mastered = false,
    this.isLeech = false,
    this.nextReviewDate,
    this.exam,
    this.extraConcepts = const <String>[],
  });

  /// Supabase satır kimliği (tekrar güncellemesi için).
  final String? id;

  /// Aralıklı tekrar durumu.
  final int step;
  final int lapses;
  final bool mastered;
  final bool isLeech;

  /// Bir sonraki tekrarın planlandığı gün. `null` = plan bilinmiyor (yerel
  /// kayıt).
  ///
  /// "Hatalarım" ekranındaki **Bugün** sayısı bunu kullanıyor. `step == 0`'dan
  /// tahmin etmek daha ucuzdu ama sayıyı etiketinden farklı bir şey yapardı:
  /// bugün eklenmiş bir soru da `step == 0` taşıyor ve tekrarı yarın.
  final DateTime? nextReviewDate;

  final String subject;
  final String concept;
  /// Hatanın sebebi — İSTEĞE BAĞLI (tasarım kararı). `null` = belirtilmedi.
  /// Varsayılan bir tür yazmak, ölçülmemiş veriyi ölçülmüş gibi gösterirdi.
  final MistakeType? type;
  final String note;
  final DateTime date;
  final bool hasPhoto;

  /// Sınav türü: 'TYT' | 'AYT' | null (AI belirler).
  final String? exam;

  /// Sorunun ayrıca değdiği konular. Soru [concept] altında gruplanır ama
  /// çözüldüğünde ölçüm bu konulara da yazılır (ör. hem mitoz hem mayoz).
  final List<String> extraConcepts;

  /// Ana konu + ek konular.
  List<String> get allConcepts => <String>[concept, ...extraConcepts];

  /// Yeni seçilen fotoğrafın ham baytları (yerel önizleme için).
  final Uint8List? imageBytes;

  /// Supabase Storage yolu (imzalı URL gösterim anında üretilir).
  final String? photoPath;

  /// AI ile çıkarılan şıklar (varsa).
  final List<QuestionOption>? options;

  /// [options] içindeki doğru şıkkın 0-tabanlı indeksi (varsa).
  final int? correctIndex;

  bool get hasOptions => options != null && options!.isNotEmpty;
}

