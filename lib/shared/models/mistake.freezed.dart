// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mistake.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Mistake {

 String get id; String get studentId; String get questionId; MistakeType get mistakeType; DateTime get createdAt;/// Öğrencinin/koçun eklediği opsiyonel not.
 String? get note;
/// Create a copy of Mistake
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MistakeCopyWith<Mistake> get copyWith => _$MistakeCopyWithImpl<Mistake>(this as Mistake, _$identity);

  /// Serializes this Mistake to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Mistake&&(identical(other.id, id) || other.id == id)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.mistakeType, mistakeType) || other.mistakeType == mistakeType)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,studentId,questionId,mistakeType,createdAt,note);

@override
String toString() {
  return 'Mistake(id: $id, studentId: $studentId, questionId: $questionId, mistakeType: $mistakeType, createdAt: $createdAt, note: $note)';
}


}

/// @nodoc
abstract mixin class $MistakeCopyWith<$Res>  {
  factory $MistakeCopyWith(Mistake value, $Res Function(Mistake) _then) = _$MistakeCopyWithImpl;
@useResult
$Res call({
 String id, String studentId, String questionId, MistakeType mistakeType, DateTime createdAt, String? note
});




}
/// @nodoc
class _$MistakeCopyWithImpl<$Res>
    implements $MistakeCopyWith<$Res> {
  _$MistakeCopyWithImpl(this._self, this._then);

  final Mistake _self;
  final $Res Function(Mistake) _then;

/// Create a copy of Mistake
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? studentId = null,Object? questionId = null,Object? mistakeType = null,Object? createdAt = null,Object? note = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,studentId: null == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String,questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,mistakeType: null == mistakeType ? _self.mistakeType : mistakeType // ignore: cast_nullable_to_non_nullable
as MistakeType,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Mistake].
extension MistakePatterns on Mistake {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Mistake value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Mistake() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Mistake value)  $default,){
final _that = this;
switch (_that) {
case _Mistake():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Mistake value)?  $default,){
final _that = this;
switch (_that) {
case _Mistake() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String studentId,  String questionId,  MistakeType mistakeType,  DateTime createdAt,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Mistake() when $default != null:
return $default(_that.id,_that.studentId,_that.questionId,_that.mistakeType,_that.createdAt,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String studentId,  String questionId,  MistakeType mistakeType,  DateTime createdAt,  String? note)  $default,) {final _that = this;
switch (_that) {
case _Mistake():
return $default(_that.id,_that.studentId,_that.questionId,_that.mistakeType,_that.createdAt,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String studentId,  String questionId,  MistakeType mistakeType,  DateTime createdAt,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _Mistake() when $default != null:
return $default(_that.id,_that.studentId,_that.questionId,_that.mistakeType,_that.createdAt,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Mistake implements Mistake {
  const _Mistake({required this.id, required this.studentId, required this.questionId, required this.mistakeType, required this.createdAt, this.note});
  factory _Mistake.fromJson(Map<String, dynamic> json) => _$MistakeFromJson(json);

@override final  String id;
@override final  String studentId;
@override final  String questionId;
@override final  MistakeType mistakeType;
@override final  DateTime createdAt;
/// Öğrencinin/koçun eklediği opsiyonel not.
@override final  String? note;

/// Create a copy of Mistake
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MistakeCopyWith<_Mistake> get copyWith => __$MistakeCopyWithImpl<_Mistake>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MistakeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Mistake&&(identical(other.id, id) || other.id == id)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.mistakeType, mistakeType) || other.mistakeType == mistakeType)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,studentId,questionId,mistakeType,createdAt,note);

@override
String toString() {
  return 'Mistake(id: $id, studentId: $studentId, questionId: $questionId, mistakeType: $mistakeType, createdAt: $createdAt, note: $note)';
}


}

/// @nodoc
abstract mixin class _$MistakeCopyWith<$Res> implements $MistakeCopyWith<$Res> {
  factory _$MistakeCopyWith(_Mistake value, $Res Function(_Mistake) _then) = __$MistakeCopyWithImpl;
@override @useResult
$Res call({
 String id, String studentId, String questionId, MistakeType mistakeType, DateTime createdAt, String? note
});




}
/// @nodoc
class __$MistakeCopyWithImpl<$Res>
    implements _$MistakeCopyWith<$Res> {
  __$MistakeCopyWithImpl(this._self, this._then);

  final _Mistake _self;
  final $Res Function(_Mistake) _then;

/// Create a copy of Mistake
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? studentId = null,Object? questionId = null,Object? mistakeType = null,Object? createdAt = null,Object? note = freezed,}) {
  return _then(_Mistake(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,studentId: null == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String,questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,mistakeType: null == mistakeType ? _self.mistakeType : mistakeType // ignore: cast_nullable_to_non_nullable
as MistakeType,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
