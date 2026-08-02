// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReviewSchedule {

 String get id; String get studentId; String get questionId; int get intervalDays; double get easeFactor; int get repetitions; DateTime get nextReviewDate;/// Son cevabın sonucu (sonSonuç).
 ReviewGrade? get lastGrade;
/// Create a copy of ReviewSchedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewScheduleCopyWith<ReviewSchedule> get copyWith => _$ReviewScheduleCopyWithImpl<ReviewSchedule>(this as ReviewSchedule, _$identity);

  /// Serializes this ReviewSchedule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewSchedule&&(identical(other.id, id) || other.id == id)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.intervalDays, intervalDays) || other.intervalDays == intervalDays)&&(identical(other.easeFactor, easeFactor) || other.easeFactor == easeFactor)&&(identical(other.repetitions, repetitions) || other.repetitions == repetitions)&&(identical(other.nextReviewDate, nextReviewDate) || other.nextReviewDate == nextReviewDate)&&(identical(other.lastGrade, lastGrade) || other.lastGrade == lastGrade));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,studentId,questionId,intervalDays,easeFactor,repetitions,nextReviewDate,lastGrade);

@override
String toString() {
  return 'ReviewSchedule(id: $id, studentId: $studentId, questionId: $questionId, intervalDays: $intervalDays, easeFactor: $easeFactor, repetitions: $repetitions, nextReviewDate: $nextReviewDate, lastGrade: $lastGrade)';
}


}

/// @nodoc
abstract mixin class $ReviewScheduleCopyWith<$Res>  {
  factory $ReviewScheduleCopyWith(ReviewSchedule value, $Res Function(ReviewSchedule) _then) = _$ReviewScheduleCopyWithImpl;
@useResult
$Res call({
 String id, String studentId, String questionId, int intervalDays, double easeFactor, int repetitions, DateTime nextReviewDate, ReviewGrade? lastGrade
});




}
/// @nodoc
class _$ReviewScheduleCopyWithImpl<$Res>
    implements $ReviewScheduleCopyWith<$Res> {
  _$ReviewScheduleCopyWithImpl(this._self, this._then);

  final ReviewSchedule _self;
  final $Res Function(ReviewSchedule) _then;

/// Create a copy of ReviewSchedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? studentId = null,Object? questionId = null,Object? intervalDays = null,Object? easeFactor = null,Object? repetitions = null,Object? nextReviewDate = null,Object? lastGrade = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,studentId: null == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String,questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,intervalDays: null == intervalDays ? _self.intervalDays : intervalDays // ignore: cast_nullable_to_non_nullable
as int,easeFactor: null == easeFactor ? _self.easeFactor : easeFactor // ignore: cast_nullable_to_non_nullable
as double,repetitions: null == repetitions ? _self.repetitions : repetitions // ignore: cast_nullable_to_non_nullable
as int,nextReviewDate: null == nextReviewDate ? _self.nextReviewDate : nextReviewDate // ignore: cast_nullable_to_non_nullable
as DateTime,lastGrade: freezed == lastGrade ? _self.lastGrade : lastGrade // ignore: cast_nullable_to_non_nullable
as ReviewGrade?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewSchedule].
extension ReviewSchedulePatterns on ReviewSchedule {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewSchedule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewSchedule() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewSchedule value)  $default,){
final _that = this;
switch (_that) {
case _ReviewSchedule():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewSchedule value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewSchedule() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String studentId,  String questionId,  int intervalDays,  double easeFactor,  int repetitions,  DateTime nextReviewDate,  ReviewGrade? lastGrade)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewSchedule() when $default != null:
return $default(_that.id,_that.studentId,_that.questionId,_that.intervalDays,_that.easeFactor,_that.repetitions,_that.nextReviewDate,_that.lastGrade);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String studentId,  String questionId,  int intervalDays,  double easeFactor,  int repetitions,  DateTime nextReviewDate,  ReviewGrade? lastGrade)  $default,) {final _that = this;
switch (_that) {
case _ReviewSchedule():
return $default(_that.id,_that.studentId,_that.questionId,_that.intervalDays,_that.easeFactor,_that.repetitions,_that.nextReviewDate,_that.lastGrade);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String studentId,  String questionId,  int intervalDays,  double easeFactor,  int repetitions,  DateTime nextReviewDate,  ReviewGrade? lastGrade)?  $default,) {final _that = this;
switch (_that) {
case _ReviewSchedule() when $default != null:
return $default(_that.id,_that.studentId,_that.questionId,_that.intervalDays,_that.easeFactor,_that.repetitions,_that.nextReviewDate,_that.lastGrade);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReviewSchedule implements ReviewSchedule {
  const _ReviewSchedule({required this.id, required this.studentId, required this.questionId, this.intervalDays = 0, this.easeFactor = 2.5, this.repetitions = 0, required this.nextReviewDate, this.lastGrade});
  factory _ReviewSchedule.fromJson(Map<String, dynamic> json) => _$ReviewScheduleFromJson(json);

@override final  String id;
@override final  String studentId;
@override final  String questionId;
@override@JsonKey() final  int intervalDays;
@override@JsonKey() final  double easeFactor;
@override@JsonKey() final  int repetitions;
@override final  DateTime nextReviewDate;
/// Son cevabın sonucu (sonSonuç).
@override final  ReviewGrade? lastGrade;

/// Create a copy of ReviewSchedule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewScheduleCopyWith<_ReviewSchedule> get copyWith => __$ReviewScheduleCopyWithImpl<_ReviewSchedule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReviewScheduleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewSchedule&&(identical(other.id, id) || other.id == id)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.intervalDays, intervalDays) || other.intervalDays == intervalDays)&&(identical(other.easeFactor, easeFactor) || other.easeFactor == easeFactor)&&(identical(other.repetitions, repetitions) || other.repetitions == repetitions)&&(identical(other.nextReviewDate, nextReviewDate) || other.nextReviewDate == nextReviewDate)&&(identical(other.lastGrade, lastGrade) || other.lastGrade == lastGrade));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,studentId,questionId,intervalDays,easeFactor,repetitions,nextReviewDate,lastGrade);

@override
String toString() {
  return 'ReviewSchedule(id: $id, studentId: $studentId, questionId: $questionId, intervalDays: $intervalDays, easeFactor: $easeFactor, repetitions: $repetitions, nextReviewDate: $nextReviewDate, lastGrade: $lastGrade)';
}


}

/// @nodoc
abstract mixin class _$ReviewScheduleCopyWith<$Res> implements $ReviewScheduleCopyWith<$Res> {
  factory _$ReviewScheduleCopyWith(_ReviewSchedule value, $Res Function(_ReviewSchedule) _then) = __$ReviewScheduleCopyWithImpl;
@override @useResult
$Res call({
 String id, String studentId, String questionId, int intervalDays, double easeFactor, int repetitions, DateTime nextReviewDate, ReviewGrade? lastGrade
});




}
/// @nodoc
class __$ReviewScheduleCopyWithImpl<$Res>
    implements _$ReviewScheduleCopyWith<$Res> {
  __$ReviewScheduleCopyWithImpl(this._self, this._then);

  final _ReviewSchedule _self;
  final $Res Function(_ReviewSchedule) _then;

/// Create a copy of ReviewSchedule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? studentId = null,Object? questionId = null,Object? intervalDays = null,Object? easeFactor = null,Object? repetitions = null,Object? nextReviewDate = null,Object? lastGrade = freezed,}) {
  return _then(_ReviewSchedule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,studentId: null == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String,questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,intervalDays: null == intervalDays ? _self.intervalDays : intervalDays // ignore: cast_nullable_to_non_nullable
as int,easeFactor: null == easeFactor ? _self.easeFactor : easeFactor // ignore: cast_nullable_to_non_nullable
as double,repetitions: null == repetitions ? _self.repetitions : repetitions // ignore: cast_nullable_to_non_nullable
as int,nextReviewDate: null == nextReviewDate ? _self.nextReviewDate : nextReviewDate // ignore: cast_nullable_to_non_nullable
as DateTime,lastGrade: freezed == lastGrade ? _self.lastGrade : lastGrade // ignore: cast_nullable_to_non_nullable
as ReviewGrade?,
  ));
}


}

// dart format on
