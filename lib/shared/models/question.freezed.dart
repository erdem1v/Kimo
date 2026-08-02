// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'question.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Question {

 String get id; String get text;/// Sorunun ait olduğu kavram/konu kimliği (aralıklı tekrar bunun üzerinden
/// gruplanır).
 String get conceptId; QuestionType get type; Difficulty get difficulty; String get correctAnswer;/// Çoktan seçmeli sorular için şıklar (opsiyonel).
 List<String>? get choices; List<String> get solutionSteps;/// Tip A çizim parametreleri (yalnızca Tip A'da dolu).
 Map<String, dynamic>? get drawingParams;/// Bu soru başka bir sorunun varyasyonuysa, kaynağın kimliği (ileri faz).
 String? get variantOf;
/// Create a copy of Question
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionCopyWith<Question> get copyWith => _$QuestionCopyWithImpl<Question>(this as Question, _$identity);

  /// Serializes this Question to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Question&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.conceptId, conceptId) || other.conceptId == conceptId)&&(identical(other.type, type) || other.type == type)&&(identical(other.difficulty, difficulty) || other.difficulty == difficulty)&&(identical(other.correctAnswer, correctAnswer) || other.correctAnswer == correctAnswer)&&const DeepCollectionEquality().equals(other.choices, choices)&&const DeepCollectionEquality().equals(other.solutionSteps, solutionSteps)&&const DeepCollectionEquality().equals(other.drawingParams, drawingParams)&&(identical(other.variantOf, variantOf) || other.variantOf == variantOf));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,text,conceptId,type,difficulty,correctAnswer,const DeepCollectionEquality().hash(choices),const DeepCollectionEquality().hash(solutionSteps),const DeepCollectionEquality().hash(drawingParams),variantOf);

@override
String toString() {
  return 'Question(id: $id, text: $text, conceptId: $conceptId, type: $type, difficulty: $difficulty, correctAnswer: $correctAnswer, choices: $choices, solutionSteps: $solutionSteps, drawingParams: $drawingParams, variantOf: $variantOf)';
}


}

/// @nodoc
abstract mixin class $QuestionCopyWith<$Res>  {
  factory $QuestionCopyWith(Question value, $Res Function(Question) _then) = _$QuestionCopyWithImpl;
@useResult
$Res call({
 String id, String text, String conceptId, QuestionType type, Difficulty difficulty, String correctAnswer, List<String>? choices, List<String> solutionSteps, Map<String, dynamic>? drawingParams, String? variantOf
});




}
/// @nodoc
class _$QuestionCopyWithImpl<$Res>
    implements $QuestionCopyWith<$Res> {
  _$QuestionCopyWithImpl(this._self, this._then);

  final Question _self;
  final $Res Function(Question) _then;

/// Create a copy of Question
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = null,Object? conceptId = null,Object? type = null,Object? difficulty = null,Object? correctAnswer = null,Object? choices = freezed,Object? solutionSteps = null,Object? drawingParams = freezed,Object? variantOf = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,conceptId: null == conceptId ? _self.conceptId : conceptId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as QuestionType,difficulty: null == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as Difficulty,correctAnswer: null == correctAnswer ? _self.correctAnswer : correctAnswer // ignore: cast_nullable_to_non_nullable
as String,choices: freezed == choices ? _self.choices : choices // ignore: cast_nullable_to_non_nullable
as List<String>?,solutionSteps: null == solutionSteps ? _self.solutionSteps : solutionSteps // ignore: cast_nullable_to_non_nullable
as List<String>,drawingParams: freezed == drawingParams ? _self.drawingParams : drawingParams // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,variantOf: freezed == variantOf ? _self.variantOf : variantOf // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Question].
extension QuestionPatterns on Question {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Question value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Question() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Question value)  $default,){
final _that = this;
switch (_that) {
case _Question():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Question value)?  $default,){
final _that = this;
switch (_that) {
case _Question() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String text,  String conceptId,  QuestionType type,  Difficulty difficulty,  String correctAnswer,  List<String>? choices,  List<String> solutionSteps,  Map<String, dynamic>? drawingParams,  String? variantOf)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Question() when $default != null:
return $default(_that.id,_that.text,_that.conceptId,_that.type,_that.difficulty,_that.correctAnswer,_that.choices,_that.solutionSteps,_that.drawingParams,_that.variantOf);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String text,  String conceptId,  QuestionType type,  Difficulty difficulty,  String correctAnswer,  List<String>? choices,  List<String> solutionSteps,  Map<String, dynamic>? drawingParams,  String? variantOf)  $default,) {final _that = this;
switch (_that) {
case _Question():
return $default(_that.id,_that.text,_that.conceptId,_that.type,_that.difficulty,_that.correctAnswer,_that.choices,_that.solutionSteps,_that.drawingParams,_that.variantOf);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String text,  String conceptId,  QuestionType type,  Difficulty difficulty,  String correctAnswer,  List<String>? choices,  List<String> solutionSteps,  Map<String, dynamic>? drawingParams,  String? variantOf)?  $default,) {final _that = this;
switch (_that) {
case _Question() when $default != null:
return $default(_that.id,_that.text,_that.conceptId,_that.type,_that.difficulty,_that.correctAnswer,_that.choices,_that.solutionSteps,_that.drawingParams,_that.variantOf);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Question implements Question {
  const _Question({required this.id, required this.text, required this.conceptId, required this.type, this.difficulty = Difficulty.orta, required this.correctAnswer, final  List<String>? choices, final  List<String> solutionSteps = const <String>[], final  Map<String, dynamic>? drawingParams, this.variantOf}): _choices = choices,_solutionSteps = solutionSteps,_drawingParams = drawingParams;
  factory _Question.fromJson(Map<String, dynamic> json) => _$QuestionFromJson(json);

@override final  String id;
@override final  String text;
/// Sorunun ait olduğu kavram/konu kimliği (aralıklı tekrar bunun üzerinden
/// gruplanır).
@override final  String conceptId;
@override final  QuestionType type;
@override@JsonKey() final  Difficulty difficulty;
@override final  String correctAnswer;
/// Çoktan seçmeli sorular için şıklar (opsiyonel).
 final  List<String>? _choices;
/// Çoktan seçmeli sorular için şıklar (opsiyonel).
@override List<String>? get choices {
  final value = _choices;
  if (value == null) return null;
  if (_choices is EqualUnmodifiableListView) return _choices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<String> _solutionSteps;
@override@JsonKey() List<String> get solutionSteps {
  if (_solutionSteps is EqualUnmodifiableListView) return _solutionSteps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_solutionSteps);
}

/// Tip A çizim parametreleri (yalnızca Tip A'da dolu).
 final  Map<String, dynamic>? _drawingParams;
/// Tip A çizim parametreleri (yalnızca Tip A'da dolu).
@override Map<String, dynamic>? get drawingParams {
  final value = _drawingParams;
  if (value == null) return null;
  if (_drawingParams is EqualUnmodifiableMapView) return _drawingParams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

/// Bu soru başka bir sorunun varyasyonuysa, kaynağın kimliği (ileri faz).
@override final  String? variantOf;

/// Create a copy of Question
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuestionCopyWith<_Question> get copyWith => __$QuestionCopyWithImpl<_Question>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Question&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.conceptId, conceptId) || other.conceptId == conceptId)&&(identical(other.type, type) || other.type == type)&&(identical(other.difficulty, difficulty) || other.difficulty == difficulty)&&(identical(other.correctAnswer, correctAnswer) || other.correctAnswer == correctAnswer)&&const DeepCollectionEquality().equals(other._choices, _choices)&&const DeepCollectionEquality().equals(other._solutionSteps, _solutionSteps)&&const DeepCollectionEquality().equals(other._drawingParams, _drawingParams)&&(identical(other.variantOf, variantOf) || other.variantOf == variantOf));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,text,conceptId,type,difficulty,correctAnswer,const DeepCollectionEquality().hash(_choices),const DeepCollectionEquality().hash(_solutionSteps),const DeepCollectionEquality().hash(_drawingParams),variantOf);

@override
String toString() {
  return 'Question(id: $id, text: $text, conceptId: $conceptId, type: $type, difficulty: $difficulty, correctAnswer: $correctAnswer, choices: $choices, solutionSteps: $solutionSteps, drawingParams: $drawingParams, variantOf: $variantOf)';
}


}

/// @nodoc
abstract mixin class _$QuestionCopyWith<$Res> implements $QuestionCopyWith<$Res> {
  factory _$QuestionCopyWith(_Question value, $Res Function(_Question) _then) = __$QuestionCopyWithImpl;
@override @useResult
$Res call({
 String id, String text, String conceptId, QuestionType type, Difficulty difficulty, String correctAnswer, List<String>? choices, List<String> solutionSteps, Map<String, dynamic>? drawingParams, String? variantOf
});




}
/// @nodoc
class __$QuestionCopyWithImpl<$Res>
    implements _$QuestionCopyWith<$Res> {
  __$QuestionCopyWithImpl(this._self, this._then);

  final _Question _self;
  final $Res Function(_Question) _then;

/// Create a copy of Question
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,Object? conceptId = null,Object? type = null,Object? difficulty = null,Object? correctAnswer = null,Object? choices = freezed,Object? solutionSteps = null,Object? drawingParams = freezed,Object? variantOf = freezed,}) {
  return _then(_Question(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,conceptId: null == conceptId ? _self.conceptId : conceptId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as QuestionType,difficulty: null == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as Difficulty,correctAnswer: null == correctAnswer ? _self.correctAnswer : correctAnswer // ignore: cast_nullable_to_non_nullable
as String,choices: freezed == choices ? _self._choices : choices // ignore: cast_nullable_to_non_nullable
as List<String>?,solutionSteps: null == solutionSteps ? _self._solutionSteps : solutionSteps // ignore: cast_nullable_to_non_nullable
as List<String>,drawingParams: freezed == drawingParams ? _self._drawingParams : drawingParams // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,variantOf: freezed == variantOf ? _self.variantOf : variantOf // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
