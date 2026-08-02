import 'package:json_annotation/json_annotation.dart';

/// Sorunun görsel üretim tipi (ürün spesifikasyonundaki Tip A/B/C ayrımı).
///
/// * [tipA] Parametrik/vektörel şekiller — `CustomPainter` ile matematiksel
///   olarak doğru çizilir.
/// * [tipB] Kompozit ama tanıdık şekiller — şablon aileleri (sonraki faz).
/// * [tipC] Bağlamsal/özgün görseller — statik soru bankasından çekilir.
enum QuestionType {
  @JsonValue('A')
  tipA,
  @JsonValue('B')
  tipB,
  @JsonValue('C')
  tipC,
}

/// Bir hatanın kök nedeni.
enum MistakeType {
  @JsonValue('kavram_eksikligi')
  kavramEksikligi,
  @JsonValue('islem_hatasi')
  islemHatasi,
  @JsonValue('dikkatsizlik')
  dikkatsizlik,
}

/// Öğrencinin hedeflediği sınav aşaması.
enum ExamTrack {
  @JsonValue('TYT')
  tyt,
  @JsonValue('AYT')
  ayt,
}

/// AYT alanı / öğrencinin çalışma alanı.
enum StudyField {
  @JsonValue('sayisal')
  sayisal,
  @JsonValue('esit_agirlik')
  esitAgirlik,
  @JsonValue('sozel')
  sozel,
  @JsonValue('dil')
  dil,
}

/// Soru zorluk seviyesi.
enum Difficulty {
  @JsonValue('kolay')
  kolay,
  @JsonValue('orta')
  orta,
  @JsonValue('zor')
  zor,
}

/// Kullanıcının bir tekrar sorusuna verdiği cevabın kalitesi.
///
/// [quality] alanı, SM-2 algoritmasının beklediği 0–5 başarı notuna eşlenir
/// (bkz. `SpacedRepetitionScheduler`). 3'ün altı "yanlış" kabul edilir.
enum ReviewGrade {
  @JsonValue('bilemedim')
  bilemedim(2),
  @JsonValue('zor')
  zor(3),
  @JsonValue('iyi')
  iyi(4),
  @JsonValue('kolay')
  kolay(5);

  const ReviewGrade(this.quality);

  /// SM-2 başarı notu (0–5).
  final int quality;
}
