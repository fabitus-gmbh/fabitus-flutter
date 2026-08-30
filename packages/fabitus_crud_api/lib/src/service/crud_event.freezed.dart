// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'crud_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CrudEvent<T> {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CrudEvent<T>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CrudEvent<$T>()';
}


}

/// @nodoc
class $CrudEventCopyWith<T,$Res>  {
$CrudEventCopyWith(CrudEvent<T> _, $Res Function(CrudEvent<T>) __);
}


/// Adds pattern-matching-related methods to [CrudEvent].
extension CrudEventPatterns<T> on CrudEvent<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CrudEntityCreated<T> value)?  created,TResult Function( CrudEntityUpdated<T> value)?  updated,TResult Function( CrudEntityDeleted<T> value)?  deleted,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CrudEntityCreated() when created != null:
return created(_that);case CrudEntityUpdated() when updated != null:
return updated(_that);case CrudEntityDeleted() when deleted != null:
return deleted(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CrudEntityCreated<T> value)  created,required TResult Function( CrudEntityUpdated<T> value)  updated,required TResult Function( CrudEntityDeleted<T> value)  deleted,}){
final _that = this;
switch (_that) {
case CrudEntityCreated():
return created(_that);case CrudEntityUpdated():
return updated(_that);case CrudEntityDeleted():
return deleted(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CrudEntityCreated<T> value)?  created,TResult? Function( CrudEntityUpdated<T> value)?  updated,TResult? Function( CrudEntityDeleted<T> value)?  deleted,}){
final _that = this;
switch (_that) {
case CrudEntityCreated() when created != null:
return created(_that);case CrudEntityUpdated() when updated != null:
return updated(_that);case CrudEntityDeleted() when deleted != null:
return deleted(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( T entity)?  created,TResult Function( T entity)?  updated,TResult Function( Object id)?  deleted,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CrudEntityCreated() when created != null:
return created(_that.entity);case CrudEntityUpdated() when updated != null:
return updated(_that.entity);case CrudEntityDeleted() when deleted != null:
return deleted(_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( T entity)  created,required TResult Function( T entity)  updated,required TResult Function( Object id)  deleted,}) {final _that = this;
switch (_that) {
case CrudEntityCreated():
return created(_that.entity);case CrudEntityUpdated():
return updated(_that.entity);case CrudEntityDeleted():
return deleted(_that.id);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( T entity)?  created,TResult? Function( T entity)?  updated,TResult? Function( Object id)?  deleted,}) {final _that = this;
switch (_that) {
case CrudEntityCreated() when created != null:
return created(_that.entity);case CrudEntityUpdated() when updated != null:
return updated(_that.entity);case CrudEntityDeleted() when deleted != null:
return deleted(_that.id);case _:
  return null;

}
}

}

/// @nodoc


class CrudEntityCreated<T> implements CrudEvent<T> {
  const CrudEntityCreated(this.entity);
  

/// The entity as it was stored, including the assigned id.
 final  T entity;

/// Create a copy of CrudEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CrudEntityCreatedCopyWith<T, CrudEntityCreated<T>> get copyWith => _$CrudEntityCreatedCopyWithImpl<T, CrudEntityCreated<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CrudEntityCreated<T>&&const DeepCollectionEquality().equals(other.entity, entity));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(entity));

@override
String toString() {
  return 'CrudEvent<$T>.created(entity: $entity)';
}


}

/// @nodoc
abstract mixin class $CrudEntityCreatedCopyWith<T,$Res> implements $CrudEventCopyWith<T, $Res> {
  factory $CrudEntityCreatedCopyWith(CrudEntityCreated<T> value, $Res Function(CrudEntityCreated<T>) _then) = _$CrudEntityCreatedCopyWithImpl;
@useResult
$Res call({
 T entity
});




}
/// @nodoc
class _$CrudEntityCreatedCopyWithImpl<T,$Res>
    implements $CrudEntityCreatedCopyWith<T, $Res> {
  _$CrudEntityCreatedCopyWithImpl(this._self, this._then);

  final CrudEntityCreated<T> _self;
  final $Res Function(CrudEntityCreated<T>) _then;

/// Create a copy of CrudEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entity = freezed,}) {
  return _then(CrudEntityCreated<T>(
freezed == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as T,
  ));
}


}

/// @nodoc


class CrudEntityUpdated<T> implements CrudEvent<T> {
  const CrudEntityUpdated(this.entity);
  

/// The entity as it was stored.
 final  T entity;

/// Create a copy of CrudEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CrudEntityUpdatedCopyWith<T, CrudEntityUpdated<T>> get copyWith => _$CrudEntityUpdatedCopyWithImpl<T, CrudEntityUpdated<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CrudEntityUpdated<T>&&const DeepCollectionEquality().equals(other.entity, entity));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(entity));

@override
String toString() {
  return 'CrudEvent<$T>.updated(entity: $entity)';
}


}

/// @nodoc
abstract mixin class $CrudEntityUpdatedCopyWith<T,$Res> implements $CrudEventCopyWith<T, $Res> {
  factory $CrudEntityUpdatedCopyWith(CrudEntityUpdated<T> value, $Res Function(CrudEntityUpdated<T>) _then) = _$CrudEntityUpdatedCopyWithImpl;
@useResult
$Res call({
 T entity
});




}
/// @nodoc
class _$CrudEntityUpdatedCopyWithImpl<T,$Res>
    implements $CrudEntityUpdatedCopyWith<T, $Res> {
  _$CrudEntityUpdatedCopyWithImpl(this._self, this._then);

  final CrudEntityUpdated<T> _self;
  final $Res Function(CrudEntityUpdated<T>) _then;

/// Create a copy of CrudEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entity = freezed,}) {
  return _then(CrudEntityUpdated<T>(
freezed == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as T,
  ));
}


}

/// @nodoc


class CrudEntityDeleted<T> implements CrudEvent<T> {
  const CrudEntityDeleted(this.id);
  

/// The id of the entity that no longer exists.
 final  Object id;

/// Create a copy of CrudEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CrudEntityDeletedCopyWith<T, CrudEntityDeleted<T>> get copyWith => _$CrudEntityDeletedCopyWithImpl<T, CrudEntityDeleted<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CrudEntityDeleted<T>&&const DeepCollectionEquality().equals(other.id, id));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(id));

@override
String toString() {
  return 'CrudEvent<$T>.deleted(id: $id)';
}


}

/// @nodoc
abstract mixin class $CrudEntityDeletedCopyWith<T,$Res> implements $CrudEventCopyWith<T, $Res> {
  factory $CrudEntityDeletedCopyWith(CrudEntityDeleted<T> value, $Res Function(CrudEntityDeleted<T>) _then) = _$CrudEntityDeletedCopyWithImpl;
@useResult
$Res call({
 Object id
});




}
/// @nodoc
class _$CrudEntityDeletedCopyWithImpl<T,$Res>
    implements $CrudEntityDeletedCopyWith<T, $Res> {
  _$CrudEntityDeletedCopyWithImpl(this._self, this._then);

  final CrudEntityDeleted<T> _self;
  final $Res Function(CrudEntityDeleted<T>) _then;

/// Create a copy of CrudEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(CrudEntityDeleted<T>(
null == id ? _self.id : id ,
  ));
}


}

// dart format on
