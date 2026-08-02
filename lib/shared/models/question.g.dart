// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Question _$QuestionFromJson(Map<String, dynamic> json) => _Question(
  id: json['id'] as String,
  text: json['text'] as String,
  conceptId: json['conceptId'] as String,
  type: $enumDecode(_$QuestionTypeEnumMap, json['type']),
  difficulty:
      $enumDecodeNullable(_$DifficultyEnumMap, json['difficulty']) ??
      Difficulty.orta,
  correctAnswer: json['correctAnswer'] as String,
  choices: (json['choices'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  solutionSteps:
      (json['solutionSteps'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  drawingParams: json['drawingParams'] as Map<String, dynamic>?,
  variantOf: json['variantOf'] as String?,
);

Map<String, dynamic> _$QuestionToJson(_Question instance) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'conceptId': instance.conceptId,
  'type': _$QuestionTypeEnumMap[instance.type]!,
  'difficulty': _$DifficultyEnumMap[instance.difficulty]!,
  'correctAnswer': instance.correctAnswer,
  'choices': instance.choices,
  'solutionSteps': instance.solutionSteps,
  'drawingParams': instance.drawingParams,
  'variantOf': instance.variantOf,
};

const _$QuestionTypeEnumMap = {
  QuestionType.tipA: 'A',
  QuestionType.tipB: 'B',
  QuestionType.tipC: 'C',
};

const _$DifficultyEnumMap = {
  Difficulty.kolay: 'kolay',
  Difficulty.orta: 'orta',
  Difficulty.zor: 'zor',
};
