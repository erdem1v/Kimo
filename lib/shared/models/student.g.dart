// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Student _$StudentFromJson(Map<String, dynamic> json) => _Student(
  id: json['id'] as String,
  name: json['name'] as String,
  examTrack: $enumDecode(_$ExamTrackEnumMap, json['examTrack']),
  field: $enumDecodeNullable(_$StudyFieldEnumMap, json['field']),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$StudentToJson(_Student instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'examTrack': _$ExamTrackEnumMap[instance.examTrack]!,
  'field': _$StudyFieldEnumMap[instance.field],
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$ExamTrackEnumMap = {ExamTrack.tyt: 'TYT', ExamTrack.ayt: 'AYT'};

const _$StudyFieldEnumMap = {
  StudyField.sayisal: 'sayisal',
  StudyField.esitAgirlik: 'esit_agirlik',
  StudyField.sozel: 'sozel',
  StudyField.dil: 'dil',
};
