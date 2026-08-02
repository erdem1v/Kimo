import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'student.freezed.dart';
part 'student.g.dart';

/// Uygulamayı kullanan öğrenci.
@freezed
abstract class Student with _$Student {
  const factory Student({
    required String id,
    required String name,
    required ExamTrack examTrack,

    /// AYT için alan (TYT'de null olabilir).
    StudyField? field,
    required DateTime createdAt,
  }) = _Student;

  factory Student.fromJson(Map<String, dynamic> json) =>
      _$StudentFromJson(json);
}
