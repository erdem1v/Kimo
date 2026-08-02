// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_schedule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReviewSchedule _$ReviewScheduleFromJson(Map<String, dynamic> json) =>
    _ReviewSchedule(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      questionId: json['questionId'] as String,
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      nextReviewDate: DateTime.parse(json['nextReviewDate'] as String),
      lastGrade: $enumDecodeNullable(_$ReviewGradeEnumMap, json['lastGrade']),
    );

Map<String, dynamic> _$ReviewScheduleToJson(_ReviewSchedule instance) =>
    <String, dynamic>{
      'id': instance.id,
      'studentId': instance.studentId,
      'questionId': instance.questionId,
      'intervalDays': instance.intervalDays,
      'easeFactor': instance.easeFactor,
      'repetitions': instance.repetitions,
      'nextReviewDate': instance.nextReviewDate.toIso8601String(),
      'lastGrade': _$ReviewGradeEnumMap[instance.lastGrade],
    };

const _$ReviewGradeEnumMap = {
  ReviewGrade.bilemedim: 'bilemedim',
  ReviewGrade.zor: 'zor',
  ReviewGrade.iyi: 'iyi',
  ReviewGrade.kolay: 'kolay',
};
