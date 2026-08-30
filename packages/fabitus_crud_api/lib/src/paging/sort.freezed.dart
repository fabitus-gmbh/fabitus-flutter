// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sort.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SortOrder {

/// The name of the property to sort by, as the backend knows it.
 String get property;/// Whether to sort ascending or descending.
 SortDirection get direction;
/// Create a copy of SortOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SortOrderCopyWith<SortOrder> get copyWith => _$SortOrderCopyWithImpl<SortOrder>(this as SortOrder, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SortOrder&&(identical(other.property, property) || other.property == property)&&(identical(other.direction, direction) || other.direction == direction));
}


@override
int get hashCode => Object.hash(runtimeType,property,direction);



}

/// @nodoc
abstract mixin class $SortOrderCopyWith<$Res>  {
  factory $SortOrderCopyWith(SortOrder value, $Res Function(SortOrder) _then) = _$SortOrderCopyWithImpl;
@useResult
$Res call({
 String property, SortDirection direction
});




}
/// @nodoc
class _$SortOrderCopyWithImpl<$Res>
    implements $SortOrderCopyWith<$Res> {
  _$SortOrderCopyWithImpl(this._self, this._then);

  final SortOrder _self;
  final $Res Function(SortOrder) _then;

/// Create a copy of SortOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? property = null,Object? direction = null,}) {
  return _then(_self.copyWith(
property: null == property ? _self.property : property // ignore: cast_nullable_to_non_nullable
as String,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as SortDirection,
  ));
}

}


/// Adds pattern-matching-related methods to [SortOrder].
extension SortOrderPatterns on SortOrder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SortOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SortOrder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SortOrder value)  $default,){
final _that = this;
switch (_that) {
case _SortOrder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SortOrder value)?  $default,){
final _that = this;
switch (_that) {
case _SortOrder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String property,  SortDirection direction)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SortOrder() when $default != null:
return $default(_that.property,_that.direction);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String property,  SortDirection direction)  $default,) {final _that = this;
switch (_that) {
case _SortOrder():
return $default(_that.property,_that.direction);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String property,  SortDirection direction)?  $default,) {final _that = this;
switch (_that) {
case _SortOrder() when $default != null:
return $default(_that.property,_that.direction);case _:
  return null;

}
}

}

/// @nodoc


class _SortOrder extends SortOrder {
  const _SortOrder(this.property, [this.direction = SortDirection.asc]): super._();
  

/// The name of the property to sort by, as the backend knows it.
@override final  String property;
/// Whether to sort ascending or descending.
@override@JsonKey() final  SortDirection direction;

/// Create a copy of SortOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SortOrderCopyWith<_SortOrder> get copyWith => __$SortOrderCopyWithImpl<_SortOrder>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SortOrder&&(identical(other.property, property) || other.property == property)&&(identical(other.direction, direction) || other.direction == direction));
}


@override
int get hashCode => Object.hash(runtimeType,property,direction);



}

/// @nodoc
abstract mixin class _$SortOrderCopyWith<$Res> implements $SortOrderCopyWith<$Res> {
  factory _$SortOrderCopyWith(_SortOrder value, $Res Function(_SortOrder) _then) = __$SortOrderCopyWithImpl;
@override @useResult
$Res call({
 String property, SortDirection direction
});




}
/// @nodoc
class __$SortOrderCopyWithImpl<$Res>
    implements _$SortOrderCopyWith<$Res> {
  __$SortOrderCopyWithImpl(this._self, this._then);

  final _SortOrder _self;
  final $Res Function(_SortOrder) _then;

/// Create a copy of SortOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? property = null,Object? direction = null,}) {
  return _then(_SortOrder(
null == property ? _self.property : property // ignore: cast_nullable_to_non_nullable
as String,null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as SortDirection,
  ));
}


}

/// @nodoc
mixin _$Sort {

/// The orders, applied from first to last.
 List<SortOrder> get orders;
/// Create a copy of Sort
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SortCopyWith<Sort> get copyWith => _$SortCopyWithImpl<Sort>(this as Sort, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Sort&&const DeepCollectionEquality().equals(other.orders, orders));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(orders));



}

/// @nodoc
abstract mixin class $SortCopyWith<$Res>  {
  factory $SortCopyWith(Sort value, $Res Function(Sort) _then) = _$SortCopyWithImpl;
@useResult
$Res call({
 List<SortOrder> orders
});




}
/// @nodoc
class _$SortCopyWithImpl<$Res>
    implements $SortCopyWith<$Res> {
  _$SortCopyWithImpl(this._self, this._then);

  final Sort _self;
  final $Res Function(Sort) _then;

/// Create a copy of Sort
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orders = null,}) {
  return _then(_self.copyWith(
orders: null == orders ? _self.orders : orders // ignore: cast_nullable_to_non_nullable
as List<SortOrder>,
  ));
}

}


/// Adds pattern-matching-related methods to [Sort].
extension SortPatterns on Sort {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Sort value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Sort() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Sort value)  $default,){
final _that = this;
switch (_that) {
case _Sort():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Sort value)?  $default,){
final _that = this;
switch (_that) {
case _Sort() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<SortOrder> orders)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Sort() when $default != null:
return $default(_that.orders);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<SortOrder> orders)  $default,) {final _that = this;
switch (_that) {
case _Sort():
return $default(_that.orders);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<SortOrder> orders)?  $default,) {final _that = this;
switch (_that) {
case _Sort() when $default != null:
return $default(_that.orders);case _:
  return null;

}
}

}

/// @nodoc


class _Sort extends Sort {
  const _Sort(final  List<SortOrder> orders): _orders = orders,super._();
  

/// The orders, applied from first to last.
 final  List<SortOrder> _orders;
/// The orders, applied from first to last.
@override List<SortOrder> get orders {
  if (_orders is EqualUnmodifiableListView) return _orders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_orders);
}


/// Create a copy of Sort
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SortCopyWith<_Sort> get copyWith => __$SortCopyWithImpl<_Sort>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Sort&&const DeepCollectionEquality().equals(other._orders, _orders));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_orders));



}

/// @nodoc
abstract mixin class _$SortCopyWith<$Res> implements $SortCopyWith<$Res> {
  factory _$SortCopyWith(_Sort value, $Res Function(_Sort) _then) = __$SortCopyWithImpl;
@override @useResult
$Res call({
 List<SortOrder> orders
});




}
/// @nodoc
class __$SortCopyWithImpl<$Res>
    implements _$SortCopyWith<$Res> {
  __$SortCopyWithImpl(this._self, this._then);

  final _Sort _self;
  final $Res Function(_Sort) _then;

/// Create a copy of Sort
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orders = null,}) {
  return _then(_Sort(
null == orders ? _self._orders : orders // ignore: cast_nullable_to_non_nullable
as List<SortOrder>,
  ));
}


}

// dart format on
