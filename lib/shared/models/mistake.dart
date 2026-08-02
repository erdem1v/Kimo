import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'mistake.freezed.dart';
part 'mistake.g.dart';

/// Öğrencinin yanlış çözdüğü bir sorunun hata bankası kaydı.
@freezed
abstract class Mistake with _$Mistake {
  const factory Mistake({
    required String id,
    required String studentId,
    required String questionId,
    required MistakeType mistakeType,
    required DateTime createdAt,

    /// Öğrencinin/koçun eklediği opsiyonel not.
    String? note,
  }) = _Mistake;

  factory Mistake.fromJson(Map<String, dynamic> json) =>
      _$MistakeFromJson(json);
}
