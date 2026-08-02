// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gamification_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GamificationState {

 String get studentId; int get xp;/// Art arda çalışılan gün sayısı (günlük seri / streak).
 int get streak;/// Kalan can/kalp sayısı.
 int get hearts;/// Kazanılan rozet kimlikleri.
 List<String> get badges;/// Serinin hesaplanması için son aktivite günü (opsiyonel).
 DateTime? get lastActivityDate;
/// Create a copy of GamificationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GamificationStateCopyWith<GamificationState> get copyWith => _$GamificationStateCopyWithImpl<GamificationState>(this as GamificationState, _$identity);

  /// Serializes this GamificationState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GamificationState&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.xp, xp) || other.xp == xp)&&(identical(other.streak, streak) || other.streak == streak)&&(identical(other.hearts, hearts) || other.hearts == hearts)&&const DeepCollectionEquality().equals(other.badges, badges)&&(identical(other.lastActivityDate, lastActivityDate) || other.lastActivityDate == lastActivityDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,studentId,xp,streak,hearts,const DeepCollectionEquality().hash(badges),lastActivityDate);

@override
String toString() {
  return 'GamificationState(studentId: $studentId, xp: $xp, streak: $streak, hearts: $hearts, badges: $badges, lastActivityDate: $lastActivityDate)';
}


}

/// @nodoc
abstract mixin class $GamificationStateCopyWith<$Res>  {
  factory $GamificationStateCopyWith(GamificationState value, $Res Function(GamificationState) _then) = _$GamificationStateCopyWithImpl;
@useResult
$Res call({
 String studentId, int xp, int streak, int hearts, List<String> badges, DateTime? lastActivityDate
});




}
/// @nodoc
class _$GamificationStateCopyWithImpl<$Res>
    implements $GamificationStateCopyWith<$Res> {
  _$GamificationStateCopyWithImpl(this._self, this._then);

  final GamificationState _self;
  final $Res Function(GamificationState) _then;

/// Create a copy of GamificationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? studentId = null,Object? xp = null,Object? streak = null,Object? hearts = null,Object? badges = null,Object? lastActivityDate = freezed,}) {
  return _then(_self.copyWith(
studentId: null == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String,xp: null == xp ? _self.xp : xp // ignore: cast_nullable_to_non_nullable
as int,streak: null == streak ? _self.streak : streak // ignore: cast_nullable_to_non_nullable
as int,hearts: null == hearts ? _self.hearts : hearts // ignore: cast_nullable_to_non_nullable
as int,badges: null == badges ? _self.badges : badges // ignore: cast_nullable_to_non_nullable
as List<String>,lastActivityDate: freezed == lastActivityDate ? _self.lastActivityDate : lastActivityDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [GamificationState].
extension GamificationStatePatterns on GamificationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GamificationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GamificationState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GamificationState value)  $default,){
final _that = this;
switch (_that) {
case _GamificationState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GamificationState value)?  $default,){
final _that = this;
switch (_that) {
case _GamificationState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String studentId,  int xp,  int streak,  int hearts,  List<String> badges,  DateTime? lastActivityDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GamificationState() when $default != null:
return $default(_that.studentId,_that.xp,_that.streak,_that.hearts,_that.badges,_that.lastActivityDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String studentId,  int xp,  int streak,  int hearts,  List<String> badges,  DateTime? lastActivityDate)  $default,) {final _that = this;
switch (_that) {
case _GamificationState():
return $default(_that.studentId,_that.xp,_that.streak,_that.hearts,_that.badges,_that.lastActivityDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String studentId,  int xp,  int streak,  int hearts,  List<String> badges,  DateTime? lastActivityDate)?  $default,) {final _that = this;
switch (_that) {
case _GamificationState() when $default != null:
return $default(_that.studentId,_that.xp,_that.streak,_that.hearts,_that.badges,_that.lastActivityDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GamificationState implements GamificationState {
  const _GamificationState({required this.studentId, this.xp = 0, this.streak = 0, this.hearts = 5, final  List<String> badges = const <String>[], this.lastActivityDate}): _badges = badges;
  factory _GamificationState.fromJson(Map<String, dynamic> json) => _$GamificationStateFromJson(json);

@override final  String studentId;
@override@JsonKey() final  int xp;
/// Art arda çalışılan gün sayısı (günlük seri / streak).
@override@JsonKey() final  int streak;
/// Kalan can/kalp sayısı.
@override@JsonKey() final  int hearts;
/// Kazanılan rozet kimlikleri.
 final  List<String> _badges;
/// Kazanılan rozet kimlikleri.
@override@JsonKey() List<String> get badges {
  if (_badges is EqualUnmodifiableListView) return _badges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_badges);
}

/// Serinin hesaplanması için son aktivite günü (opsiyonel).
@override final  DateTime? lastActivityDate;

/// Create a copy of GamificationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GamificationStateCopyWith<_GamificationState> get copyWith => __$GamificationStateCopyWithImpl<_GamificationState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GamificationStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GamificationState&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.xp, xp) || other.xp == xp)&&(identical(other.streak, streak) || other.streak == streak)&&(identical(other.hearts, hearts) || other.hearts == hearts)&&const DeepCollectionEquality().equals(other._badges, _badges)&&(identical(other.lastActivityDate, lastActivityDate) || other.lastActivityDate == lastActivityDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,studentId,xp,streak,hearts,const DeepCollectionEquality().hash(_badges),lastActivityDate);

@override
String toString() {
  return 'GamificationState(studentId: $studentId, xp: $xp, streak: $streak, hearts: $hearts, badges: $badges, lastActivityDate: $lastActivityDate)';
}


}

/// @nodoc
abstract mixin class _$GamificationStateCopyWith<$Res> implements $GamificationStateCopyWith<$Res> {
  factory _$GamificationStateCopyWith(_GamificationState value, $Res Function(_GamificationState) _then) = __$GamificationStateCopyWithImpl;
@override @useResult
$Res call({
 String studentId, int xp, int streak, int hearts, List<String> badges, DateTime? lastActivityDate
});




}
/// @nodoc
class __$GamificationStateCopyWithImpl<$Res>
    implements _$GamificationStateCopyWith<$Res> {
  __$GamificationStateCopyWithImpl(this._self, this._then);

  final _GamificationState _self;
  final $Res Function(_GamificationState) _then;

/// Create a copy of GamificationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? studentId = null,Object? xp = null,Object? streak = null,Object? hearts = null,Object? badges = null,Object? lastActivityDate = freezed,}) {
  return _then(_GamificationState(
studentId: null == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String,xp: null == xp ? _self.xp : xp // ignore: cast_nullable_to_non_nullable
as int,streak: null == streak ? _self.streak : streak // ignore: cast_nullable_to_non_nullable
as int,hearts: null == hearts ? _self.hearts : hearts // ignore: cast_nullable_to_non_nullable
as int,badges: null == badges ? _self._badges : badges // ignore: cast_nullable_to_non_nullable
as List<String>,lastActivityDate: freezed == lastActivityDate ? _self.lastActivityDate : lastActivityDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
