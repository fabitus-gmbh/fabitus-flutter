// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'crud_violation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CrudViolation {

/// Name of the offending property, for example `title` or `address.zip`.
 String get field;/// Human readable description of what is wrong with [field].
 String get message;
/// Create a copy of CrudViolation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CrudViolationCopyWith<CrudViolation> get copyWith => _$CrudViolationCopyWithImpl<CrudViolation>(this as CrudViolation, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CrudViolation&&(identical(other.field, field) || other.field == field)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,field,message);



}

/// @nodoc
abstract mixin class $CrudViolationCopyWith<$Res>  {
  factory $CrudViolationCopyWith(CrudViolation value, $Res Function(CrudViolation) _then) = _$CrudViolationCopyWithImpl;
@useResult
$Res call({
 String field, String message
});




}
/// @nodoc
class _$CrudViolationCopyWithImpl<$Res>
    implements $CrudViolationCopyWith<$Res> {
  _$CrudViolationCopyWithImpl(this._self, this._then);

  final CrudViolation _self;
  final $Res Function(CrudViolation) _then;

/// Create a copy of CrudViolation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? field = null,Object? message = null,}) {
  return _then(_self.copyWith(
field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CrudViolation].
extension CrudViolationPatterns on CrudViolation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CrudViolation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CrudViolation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CrudViolation value)  $default,){
final _that = this;
switch (_that) {
case _CrudViolation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CrudViolation value)?  $default,){
final _that = this;
switch (_that) {
case _CrudViolation() when $default != null:
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
case _CrudViolation() when $default != null:
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
case _CrudViolation():
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
case _CrudViolation() when $default != null:
return $default(_that.field,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _CrudViolation extends CrudViolation {
  const _CrudViolation({required this.field, required this.message}): super._();
  

/// Name of the offending property, for example `title` or `address.zip`.
@override final  String field;
/// Human readable description of what is wrong with [field].
@override final  String message;

/// Create a copy of CrudViolation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CrudViolationCopyWith<_CrudViolation> get copyWith => __$CrudViolationCopyWithImpl<_CrudViolation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CrudViolation&&(identical(other.field, field) || other.field == field)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,field,message);



}

/// @nodoc
abstract mixin class _$CrudViolationCopyWith<$Res> implements $CrudViolationCopyWith<$Res> {
  factory _$CrudViolationCopyWith(_CrudViolation value, $Res Function(_CrudViolation) _then) = __$CrudViolationCopyWithImpl;
@override @useResult
$Res call({
 String field, String message
});




}
/// @nodoc
class __$CrudViolationCopyWithImpl<$Res>
    implements _$CrudViolationCopyWith<$Res> {
  __$CrudViolationCopyWithImpl(this._self, this._then);

  final _CrudViolation _self;
  final $Res Function(_CrudViolation) _then;

/// Create a copy of CrudViolation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field = null,Object? message = null,}) {
  return _then(_CrudViolation(
field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
