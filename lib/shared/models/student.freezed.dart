// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'student.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Student {

 String get id; String get name; ExamTrack get examTrack;/// AYT için alan (TYT'de null olabilir).
 StudyField? get field; DateTime get createdAt;
/// Create a copy of Student
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudentCopyWith<Student> get copyWith => _$StudentCopyWithImpl<Student>(this as Student, _$identity);

  /// Serializes this Student to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Student&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.examTrack, examTrack) || other.examTrack == examTrack)&&(identical(other.field, field) || other.field == field)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,examTrack,field,createdAt);

@override
String toString() {
  return 'Student(id: $id, name: $name, examTrack: $examTrack, field: $field, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $StudentCopyWith<$Res>  {
  factory $StudentCopyWith(Student value, $Res Function(Student) _then) = _$StudentCopyWithImpl;
@useResult
$Res call({
 String id, String name, ExamTrack examTrack, StudyField? field, DateTime createdAt
});




}
/// @nodoc
class _$StudentCopyWithImpl<$Res>
    implements $StudentCopyWith<$Res> {
  _$StudentCopyWithImpl(this._self, this._then);

  final Student _self;
  final $Res Function(Student) _then;

/// Create a copy of Student
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? examTrack = null,Object? field = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,examTrack: null == examTrack ? _self.examTrack : examTrack // ignore: cast_nullable_to_non_nullable
as ExamTrack,field: freezed == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as StudyField?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Student].
extension StudentPatterns on Student {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Student value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Student() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Student value)  $default,){
final _that = this;
switch (_that) {
case _Student():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Student value)?  $default,){
final _that = this;
switch (_that) {
case _Student() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  ExamTrack examTrack,  StudyField? field,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Student() when $default != null:
return $default(_that.id,_that.name,_that.examTrack,_that.field,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  ExamTrack examTrack,  StudyField? field,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Student():
return $default(_that.id,_that.name,_that.examTrack,_that.field,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  ExamTrack examTrack,  StudyField? field,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Student() when $default != null:
return $default(_that.id,_that.name,_that.examTrack,_that.field,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Student implements Student {
  const _Student({required this.id, required this.name, required this.examTrack, this.field, required this.createdAt});
  factory _Student.fromJson(Map<String, dynamic> json) => _$StudentFromJson(json);

@override final  String id;
@override final  String name;
@override final  ExamTrack examTrack;
/// AYT için alan (TYT'de null olabilir).
@override final  StudyField? field;
@override final  DateTime createdAt;

/// Create a copy of Student
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudentCopyWith<_Student> get copyWith => __$StudentCopyWithImpl<_Student>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Student&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.examTrack, examTrack) || other.examTrack == examTrack)&&(identical(other.field, field) || other.field == field)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,examTrack,field,createdAt);

@override
String toString() {
  return 'Student(id: $id, name: $name, examTrack: $examTrack, field: $field, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$StudentCopyWith<$Res> implements $StudentCopyWith<$Res> {
  factory _$StudentCopyWith(_Student value, $Res Function(_Student) _then) = __$StudentCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, ExamTrack examTrack, StudyField? field, DateTime createdAt
});




}
/// @nodoc
class __$StudentCopyWithImpl<$Res>
    implements _$StudentCopyWith<$Res> {
  __$StudentCopyWithImpl(this._self, this._then);

  final _Student _self;
  final $Res Function(_Student) _then;

/// Create a copy of Student
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? examTrack = null,Object? field = freezed,Object? createdAt = null,}) {
  return _then(_Student(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,examTrack: null == examTrack ? _self.examTrack : examTrack // ignore: cast_nullable_to_non_nullable
as ExamTrack,field: freezed == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as StudyField?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
