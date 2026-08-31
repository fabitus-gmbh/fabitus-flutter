// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feature_access.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FeatureAccess<R extends Object> {

/// Roles that see the feature's entry in the navigation.
///
/// Kept apart from [read] on purpose: a feature can be reachable by a
/// deep link for a role that should not be advertised the module.
 Set<R> get navigation;/// Roles that may create.
 Set<R> get create;/// Roles that may read.
 Set<R> get read;/// Roles that may update.
 Set<R> get update;/// Roles that may delete.
 Set<R> get delete;
/// Create a copy of FeatureAccess
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeatureAccessCopyWith<R, FeatureAccess<R>> get copyWith => _$FeatureAccessCopyWithImpl<R, FeatureAccess<R>>(this as FeatureAccess<R>, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeatureAccess<R>&&const DeepCollectionEquality().equals(other.navigation, navigation)&&const DeepCollectionEquality().equals(other.create, create)&&const DeepCollectionEquality().equals(other.read, read)&&const DeepCollectionEquality().equals(other.update, update)&&const DeepCollectionEquality().equals(other.delete, delete));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(navigation),const DeepCollectionEquality().hash(create),const DeepCollectionEquality().hash(read),const DeepCollectionEquality().hash(update),const DeepCollectionEquality().hash(delete));

@override
String toString() {
  return 'FeatureAccess<$R>(navigation: $navigation, create: $create, read: $read, update: $update, delete: $delete)';
}


}

/// @nodoc
abstract mixin class $FeatureAccessCopyWith<R extends Object,$Res>  {
  factory $FeatureAccessCopyWith(FeatureAccess<R> value, $Res Function(FeatureAccess<R>) _then) = _$FeatureAccessCopyWithImpl;
@useResult
$Res call({
 Set<R> navigation, Set<R> create, Set<R> read, Set<R> update, Set<R> delete
});




}
/// @nodoc
class _$FeatureAccessCopyWithImpl<R extends Object,$Res>
    implements $FeatureAccessCopyWith<R, $Res> {
  _$FeatureAccessCopyWithImpl(this._self, this._then);

  final FeatureAccess<R> _self;
  final $Res Function(FeatureAccess<R>) _then;

/// Create a copy of FeatureAccess
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? navigation = null,Object? create = null,Object? read = null,Object? update = null,Object? delete = null,}) {
  return _then(_self.copyWith(
navigation: null == navigation ? _self.navigation : navigation // ignore: cast_nullable_to_non_nullable
as Set<R>,create: null == create ? _self.create : create // ignore: cast_nullable_to_non_nullable
as Set<R>,read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as Set<R>,update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as Set<R>,delete: null == delete ? _self.delete : delete // ignore: cast_nullable_to_non_nullable
as Set<R>,
  ));
}

}


/// Adds pattern-matching-related methods to [FeatureAccess].
extension FeatureAccessPatterns<R extends Object> on FeatureAccess<R> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeatureAccess<R> value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeatureAccess() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeatureAccess<R> value)  $default,){
final _that = this;
switch (_that) {
case _FeatureAccess():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeatureAccess<R> value)?  $default,){
final _that = this;
switch (_that) {
case _FeatureAccess() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Set<R> navigation,  Set<R> create,  Set<R> read,  Set<R> update,  Set<R> delete)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeatureAccess() when $default != null:
return $default(_that.navigation,_that.create,_that.read,_that.update,_that.delete);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Set<R> navigation,  Set<R> create,  Set<R> read,  Set<R> update,  Set<R> delete)  $default,) {final _that = this;
switch (_that) {
case _FeatureAccess():
return $default(_that.navigation,_that.create,_that.read,_that.update,_that.delete);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Set<R> navigation,  Set<R> create,  Set<R> read,  Set<R> update,  Set<R> delete)?  $default,) {final _that = this;
switch (_that) {
case _FeatureAccess() when $default != null:
return $default(_that.navigation,_that.create,_that.read,_that.update,_that.delete);case _:
  return null;

}
}

}

/// @nodoc


class _FeatureAccess<R extends Object> extends FeatureAccess<R> {
  const _FeatureAccess({final  Set<R> navigation = const <Never>{}, final  Set<R> create = const <Never>{}, final  Set<R> read = const <Never>{}, final  Set<R> update = const <Never>{}, final  Set<R> delete = const <Never>{}}): _navigation = navigation,_create = create,_read = read,_update = update,_delete = delete,super._();
  

/// Roles that see the feature's entry in the navigation.
///
/// Kept apart from [read] on purpose: a feature can be reachable by a
/// deep link for a role that should not be advertised the module.
 final  Set<R> _navigation;
/// Roles that see the feature's entry in the navigation.
///
/// Kept apart from [read] on purpose: a feature can be reachable by a
/// deep link for a role that should not be advertised the module.
@override@JsonKey() Set<R> get navigation {
  if (_navigation is EqualUnmodifiableSetView) return _navigation;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_navigation);
}

/// Roles that may create.
 final  Set<R> _create;
/// Roles that may create.
@override@JsonKey() Set<R> get create {
  if (_create is EqualUnmodifiableSetView) return _create;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_create);
}

/// Roles that may read.
 final  Set<R> _read;
/// Roles that may read.
@override@JsonKey() Set<R> get read {
  if (_read is EqualUnmodifiableSetView) return _read;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_read);
}

/// Roles that may update.
 final  Set<R> _update;
/// Roles that may update.
@override@JsonKey() Set<R> get update {
  if (_update is EqualUnmodifiableSetView) return _update;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_update);
}

/// Roles that may delete.
 final  Set<R> _delete;
/// Roles that may delete.
@override@JsonKey() Set<R> get delete {
  if (_delete is EqualUnmodifiableSetView) return _delete;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_delete);
}


/// Create a copy of FeatureAccess
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeatureAccessCopyWith<R, _FeatureAccess<R>> get copyWith => __$FeatureAccessCopyWithImpl<R, _FeatureAccess<R>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeatureAccess<R>&&const DeepCollectionEquality().equals(other._navigation, _navigation)&&const DeepCollectionEquality().equals(other._create, _create)&&const DeepCollectionEquality().equals(other._read, _read)&&const DeepCollectionEquality().equals(other._update, _update)&&const DeepCollectionEquality().equals(other._delete, _delete));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_navigation),const DeepCollectionEquality().hash(_create),const DeepCollectionEquality().hash(_read),const DeepCollectionEquality().hash(_update),const DeepCollectionEquality().hash(_delete));

@override
String toString() {
  return 'FeatureAccess<$R>(navigation: $navigation, create: $create, read: $read, update: $update, delete: $delete)';
}


}

/// @nodoc
abstract mixin class _$FeatureAccessCopyWith<R extends Object,$Res> implements $FeatureAccessCopyWith<R, $Res> {
  factory _$FeatureAccessCopyWith(_FeatureAccess<R> value, $Res Function(_FeatureAccess<R>) _then) = __$FeatureAccessCopyWithImpl;
@override @useResult
$Res call({
 Set<R> navigation, Set<R> create, Set<R> read, Set<R> update, Set<R> delete
});




}
/// @nodoc
class __$FeatureAccessCopyWithImpl<R extends Object,$Res>
    implements _$FeatureAccessCopyWith<R, $Res> {
  __$FeatureAccessCopyWithImpl(this._self, this._then);

  final _FeatureAccess<R> _self;
  final $Res Function(_FeatureAccess<R>) _then;

/// Create a copy of FeatureAccess
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? navigation = null,Object? create = null,Object? read = null,Object? update = null,Object? delete = null,}) {
  return _then(_FeatureAccess<R>(
navigation: null == navigation ? _self._navigation : navigation // ignore: cast_nullable_to_non_nullable
as Set<R>,create: null == create ? _self._create : create // ignore: cast_nullable_to_non_nullable
as Set<R>,read: null == read ? _self._read : read // ignore: cast_nullable_to_non_nullable
as Set<R>,update: null == update ? _self._update : update // ignore: cast_nullable_to_non_nullable
as Set<R>,delete: null == delete ? _self._delete : delete // ignore: cast_nullable_to_non_nullable
as Set<R>,
  ));
}


}

// dart format on
