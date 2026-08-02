import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'question.freezed.dart';
part 'question.g.dart';

/// Bir soruyu temsil eder.
///
/// [drawingParams] yalnızca [QuestionType.tipA] sorularda doludur ve şeklin
/// parametrelerini (ör. üçgen kenarları, açı, yarıçap) taşır; çizim istemci
/// tarafında `CustomPainter` ile yapılır.
///
/// [variantOf] ve [conceptId] varyasyon motoru için ileriye dönük alanlardır;
/// MVP'de varyasyon üretilmez, tüm tekrarlar birebir aynı sorudur.
@freezed
abstract class Question with _$Question {
  const factory Question({
    required String id,
    required String text,

    /// Sorunun ait olduğu kavram/konu kimliği (aralıklı tekrar bunun üzerinden
    /// gruplanır).
    required String conceptId,
    required QuestionType type,
    @Default(Difficulty.orta) Difficulty difficulty,
    required String correctAnswer,

    /// Çoktan seçmeli sorular için şıklar (opsiyonel).
    List<String>? choices,
    @Default(<String>[]) List<String> solutionSteps,

    /// Tip A çizim parametreleri (yalnızca Tip A'da dolu).
    Map<String, dynamic>? drawingParams,

    /// Bu soru başka bir sorunun varyasyonuysa, kaynağın kimliği (ileri faz).
    String? variantOf,
  }) = _Question;

  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);
}
