// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mistake.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Mistake _$MistakeFromJson(Map<String, dynamic> json) => _Mistake(
  id: json['id'] as String,
  studentId: json['studentId'] as String,
  questionId: json['questionId'] as String,
  mistakeType: $enumDecode(_$MistakeTypeEnumMap, json['mistakeType']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  note: json['note'] as String?,
);

Map<String, dynamic> _$MistakeToJson(_Mistake instance) => <String, dynamic>{
  'id': instance.id,
  'studentId': instance.studentId,
  'questionId': instance.questionId,
  'mistakeType': _$MistakeTypeEnumMap[instance.mistakeType]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'note': instance.note,
};

const _$MistakeTypeEnumMap = {
  MistakeType.kavramEksikligi: 'kavram_eksikligi',
  MistakeType.islemHatasi: 'islem_hatasi',
  MistakeType.dikkatsizlik: 'dikkatsizlik',
};
