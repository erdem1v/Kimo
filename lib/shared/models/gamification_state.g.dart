// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gamification_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GamificationState _$GamificationStateFromJson(Map<String, dynamic> json) =>
    _GamificationState(
      studentId: json['studentId'] as String,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      hearts: (json['hearts'] as num?)?.toInt() ?? 5,
      badges:
          (json['badges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      lastActivityDate: json['lastActivityDate'] == null
          ? null
          : DateTime.parse(json['lastActivityDate'] as String),
    );

Map<String, dynamic> _$GamificationStateToJson(_GamificationState instance) =>
    <String, dynamic>{
      'studentId': instance.studentId,
      'xp': instance.xp,
      'streak': instance.streak,
      'hearts': instance.hearts,
      'badges': instance.badges,
      'lastActivityDate': instance.lastActivityDate?.toIso8601String(),
    };
