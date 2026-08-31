// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'problem_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConstraintViolation {

/// Name of the offending property, for example `title` or `address.zip`.
 String get field;/// Human readable description of what is wrong with [field].
 String get message;
/// Create a copy of ConstraintViolation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConstraintViolationCopyWith<ConstraintViolation> get copyWith => _$ConstraintViolationCopyWithImpl<ConstraintViolation>(this as ConstraintViolation, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConstraintViolation&&(identical(other.field, field) || other.field == field)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,field,message);



}

/// @nodoc
abstract mixin class $ConstraintViolationCopyWith<$Res>  {
  factory $ConstraintViolationCopyWith(ConstraintViolation value, $Res Function(ConstraintViolation) _then) = _$ConstraintViolationCopyWithImpl;
@useResult
$Res call({
 String field, String message
});




}
/// @nodoc
class _$ConstraintViolationCopyWithImpl<$Res>
    implements $ConstraintViolationCopyWith<$Res> {
  _$ConstraintViolationCopyWithImpl(this._self, this._then);

  final ConstraintViolation _self;
  final $Res Function(ConstraintViolation) _then;

/// Create a copy of ConstraintViolation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? field = null,Object? message = null,}) {
  return _then(_self.copyWith(
field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ConstraintViolation].
extension ConstraintViolationPatterns on ConstraintViolation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConstraintViolation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConstraintViolation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConstraintViolation value)  $default,){
final _that = this;
switch (_that) {
case _ConstraintViolation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConstraintViolation value)?  $default,){
final _that = this;
switch (_that) {
case _ConstraintViolation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String field,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConstraintViolation() when $default != null:
return $default(_that.field,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String field,  String message)  $default,) {final _that = this;
switch (_that) {
case _ConstraintViolation():
return $default(_that.field,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String field,  String message)?  $default,) {final _that = this;
switch (_that) {
case _ConstraintViolation() when $default != null:
return $default(_that.field,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _ConstraintViolation extends ConstraintViolation {
  const _ConstraintViolation({required this.field, required this.message}): super._();
  

/// Name of the offending property, for example `title` or `address.zip`.
@override final  String field;
/// Human readable description of what is wrong with [field].
@override final  String message;

/// Create a copy of ConstraintViolation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConstraintViolationCopyWith<_ConstraintViolation> get copyWith => __$ConstraintViolationCopyWithImpl<_ConstraintViolation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConstraintViolation&&(identical(other.field, field) || other.field == field)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,field,message);



}

/// @nodoc
abstract mixin class _$ConstraintViolationCopyWith<$Res> implements $ConstraintViolationCopyWith<$Res> {
  factory _$ConstraintViolationCopyWith(_ConstraintViolation value, $Res Function(_ConstraintViolation) _then) = __$ConstraintViolationCopyWithImpl;
@override @useResult
$Res call({
 String field, String message
});




}
/// @nodoc
class __$ConstraintViolationCopyWithImpl<$Res>
    implements _$ConstraintViolationCopyWith<$Res> {
  __$ConstraintViolationCopyWithImpl(this._self, this._then);

  final _ConstraintViolation _self;
  final $Res Function(_ConstraintViolation) _then;

/// Create a copy of ConstraintViolation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field = null,Object? message = null,}) {
  return _then(_ConstraintViolation(
field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ProblemDetail {

/// URI identifying the problem type, for example
/// `https://fabit.us/problem/constraint-violation`.
 String? get type;/// Short, human readable summary of the problem type.
 String? get title;/// The HTTP status code the origin server generated for this occurrence.
 int? get status;/// Human readable explanation specific to this occurrence.
 String? get detail;/// URI identifying the specific occurrence of the problem.
 String? get instance;/// Field level validation errors, empty when the problem is not a
/// validation failure.
 List<ConstraintViolation> get violations;/// Members of the body that are not part of the standard.
 Map<String, dynamic> get extensions;
/// Create a copy of ProblemDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProblemDetailCopyWith<ProblemDetail> get copyWith => _$ProblemDetailCopyWithImpl<ProblemDetail>(this as ProblemDetail, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProblemDetail&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.instance, instance) || other.instance == instance)&&const DeepCollectionEquality().equals(other.violations, violations)&&const DeepCollectionEquality().equals(other.extensions, extensions));
}


@override
int get hashCode => Object.hash(runtimeType,type,title,status,detail,instance,const DeepCollectionEquality().hash(violations),const DeepCollectionEquality().hash(extensions));

@override
String toString() {
  return 'ProblemDetail(type: $type, title: $title, status: $status, detail: $detail, instance: $instance, violations: $violations, extensions: $extensions)';
}


}

/// @nodoc
abstract mixin class $ProblemDetailCopyWith<$Res>  {
  factory $ProblemDetailCopyWith(ProblemDetail value, $Res Function(ProblemDetail) _then) = _$ProblemDetailCopyWithImpl;
@useResult
$Res call({
 String? type, String? title, int? status, String? detail, String? instance, List<ConstraintViolation> violations, Map<String, dynamic> extensions
});




}
/// @nodoc
class _$ProblemDetailCopyWithImpl<$Res>
    implements $ProblemDetailCopyWith<$Res> {
  _$ProblemDetailCopyWithImpl(this._self, this._then);

  final ProblemDetail _self;
  final $Res Function(ProblemDetail) _then;

/// Create a copy of ProblemDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = freezed,Object? title = freezed,Object? status = freezed,Object? detail = freezed,Object? instance = freezed,Object? violations = null,Object? extensions = null,}) {
  return _then(_self.copyWith(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String?,instance: freezed == instance ? _self.instance : instance // ignore: cast_nullable_to_non_nullable
as String?,violations: null == violations ? _self.violations : violations // ignore: cast_nullable_to_non_nullable
as List<ConstraintViolation>,extensions: null == extensions ? _self.extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProblemDetail].
extension ProblemDetailPatterns on ProblemDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProblemDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProblemDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProblemDetail value)  $default,){
final _that = this;
switch (_that) {
case _ProblemDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProblemDetail value)?  $default,){
final _that = this;
switch (_that) {
case _ProblemDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? type,  String? title,  int? status,  String? detail,  String? instance,  List<ConstraintViolation> violations,  Map<String, dynamic> extensions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProblemDetail() when $default != null:
return $default(_that.type,_that.title,_that.status,_that.detail,_that.instance,_that.violations,_that.extensions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? type,  String? title,  int? status,  String? detail,  String? instance,  List<ConstraintViolation> violations,  Map<String, dynamic> extensions)  $default,) {final _that = this;
switch (_that) {
case _ProblemDetail():
return $default(_that.type,_that.title,_that.status,_that.detail,_that.instance,_that.violations,_that.extensions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? type,  String? title,  int? status,  String? detail,  String? instance,  List<ConstraintViolation> violations,  Map<String, dynamic> extensions)?  $default,) {final _that = this;
switch (_that) {
case _ProblemDetail() when $default != null:
return $default(_that.type,_that.title,_that.status,_that.detail,_that.instance,_that.violations,_that.extensions);case _:
  return null;

}
}

}

/// @nodoc


class _ProblemDetail extends ProblemDetail {
  const _ProblemDetail({this.type, this.title, this.status, this.detail, this.instance, final  List<ConstraintViolation> violations = const <ConstraintViolation>[], final  Map<String, dynamic> extensions = const <String, dynamic>{}}): _violations = violations,_extensions = extensions,super._();
  

/// URI identifying the problem type, for example
/// `https://fabit.us/problem/constraint-violation`.
@override final  String? type;
/// Short, human readable summary of the problem type.
@override final  String? title;
/// The HTTP status code the origin server generated for this occurrence.
@override final  int? status;
/// Human readable explanation specific to this occurrence.
@override final  String? detail;
/// URI identifying the specific occurrence of the problem.
@override final  String? instance;
/// Field level validation errors, empty when the problem is not a
/// validation failure.
 final  List<ConstraintViolation> _violations;
/// Field level validation errors, empty when the problem is not a
/// validation failure.
@override@JsonKey() List<ConstraintViolation> get violations {
  if (_violations is EqualUnmodifiableListView) return _violations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_violations);
}

/// Members of the body that are not part of the standard.
 final  Map<String, dynamic> _extensions;
/// Members of the body that are not part of the standard.
@override@JsonKey() Map<String, dynamic> get extensions {
  if (_extensions is EqualUnmodifiableMapView) return _extensions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extensions);
}


/// Create a copy of ProblemDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProblemDetailCopyWith<_ProblemDetail> get copyWith => __$ProblemDetailCopyWithImpl<_ProblemDetail>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProblemDetail&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.instance, instance) || other.instance == instance)&&const DeepCollectionEquality().equals(other._violations, _violations)&&const DeepCollectionEquality().equals(other._extensions, _extensions));
}


@override
int get hashCode => Object.hash(runtimeType,type,title,status,detail,instance,const DeepCollectionEquality().hash(_violations),const DeepCollectionEquality().hash(_extensions));

@override
String toString() {
  return 'ProblemDetail(type: $type, title: $title, status: $status, detail: $detail, instance: $instance, violations: $violations, extensions: $extensions)';
}


}

/// @nodoc
abstract mixin class _$ProblemDetailCopyWith<$Res> implements $ProblemDetailCopyWith<$Res> {
  factory _$ProblemDetailCopyWith(_ProblemDetail value, $Res Function(_ProblemDetail) _then) = __$ProblemDetailCopyWithImpl;
@override @useResult
$Res call({
 String? type, String? title, int? status, String? detail, String? instance, List<ConstraintViolation> violations, Map<String, dynamic> extensions
});




}
/// @nodoc
class __$ProblemDetailCopyWithImpl<$Res>
    implements _$ProblemDetailCopyWith<$Res> {
  __$ProblemDetailCopyWithImpl(this._self, this._then);

  final _ProblemDetail _self;
  final $Res Function(_ProblemDetail) _then;

/// Create a copy of ProblemDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = freezed,Object? title = freezed,Object? status = freezed,Object? detail = freezed,Object? instance = freezed,Object? violations = null,Object? extensions = null,}) {
  return _then(_ProblemDetail(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String?,instance: freezed == instance ? _self.instance : instance // ignore: cast_nullable_to_non_nullable
as String?,violations: null == violations ? _self._violations : violations // ignore: cast_nullable_to_non_nullable
as List<ConstraintViolation>,extensions: null == extensions ? _self._extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
