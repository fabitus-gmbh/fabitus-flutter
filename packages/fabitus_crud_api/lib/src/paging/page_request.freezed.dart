// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'page_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PageRequest {

/// How many entities the page should contain at most.
 int get size;/// The order the backend should apply before slicing.
 Sort get sort;
/// Create a copy of PageRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PageRequestCopyWith<PageRequest> get copyWith => _$PageRequestCopyWithImpl<PageRequest>(this as PageRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageRequest&&(identical(other.size, size) || other.size == size)&&(identical(other.sort, sort) || other.sort == sort));
}


@override
int get hashCode => Object.hash(runtimeType,size,sort);

@override
String toString() {
  return 'PageRequest(size: $size, sort: $sort)';
}


}

/// @nodoc
abstract mixin class $PageRequestCopyWith<$Res>  {
  factory $PageRequestCopyWith(PageRequest value, $Res Function(PageRequest) _then) = _$PageRequestCopyWithImpl;
@useResult
$Res call({
 int size, Sort sort
});


$SortCopyWith<$Res> get sort;

}
/// @nodoc
class _$PageRequestCopyWithImpl<$Res>
    implements $PageRequestCopyWith<$Res> {
  _$PageRequestCopyWithImpl(this._self, this._then);

  final PageRequest _self;
  final $Res Function(PageRequest) _then;

/// Create a copy of PageRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? size = null,Object? sort = null,}) {
  return _then(_self.copyWith(
size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as Sort,
  ));
}
/// Create a copy of PageRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SortCopyWith<$Res> get sort {
  
  return $SortCopyWith<$Res>(_self.sort, (value) {
    return _then(_self.copyWith(sort: value));
  });
}
}


/// Adds pattern-matching-related methods to [PageRequest].
extension PageRequestPatterns on PageRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( OffsetPageRequest value)?  offset,TResult Function( CursorPageRequest value)?  cursor,required TResult orElse(),}){
final _that = this;
switch (_that) {
case OffsetPageRequest() when offset != null:
return offset(_that);case CursorPageRequest() when cursor != null:
return cursor(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( OffsetPageRequest value)  offset,required TResult Function( CursorPageRequest value)  cursor,}){
final _that = this;
switch (_that) {
case OffsetPageRequest():
return offset(_that);case CursorPageRequest():
return cursor(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( OffsetPageRequest value)?  offset,TResult? Function( CursorPageRequest value)?  cursor,}){
final _that = this;
switch (_that) {
case OffsetPageRequest() when offset != null:
return offset(_that);case CursorPageRequest() when cursor != null:
return cursor(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int page,  int size,  Sort sort)?  offset,TResult Function( int size,  String? cursor,  Sort sort)?  cursor,required TResult orElse(),}) {final _that = this;
switch (_that) {
case OffsetPageRequest() when offset != null:
return offset(_that.page,_that.size,_that.sort);case CursorPageRequest() when cursor != null:
return cursor(_that.size,_that.cursor,_that.sort);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int page,  int size,  Sort sort)  offset,required TResult Function( int size,  String? cursor,  Sort sort)  cursor,}) {final _that = this;
switch (_that) {
case OffsetPageRequest():
return offset(_that.page,_that.size,_that.sort);case CursorPageRequest():
return cursor(_that.size,_that.cursor,_that.sort);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int page,  int size,  Sort sort)?  offset,TResult? Function( int size,  String? cursor,  Sort sort)?  cursor,}) {final _that = this;
switch (_that) {
case OffsetPageRequest() when offset != null:
return offset(_that.page,_that.size,_that.sort);case CursorPageRequest() when cursor != null:
return cursor(_that.size,_that.cursor,_that.sort);case _:
  return null;

}
}

}

/// @nodoc


class OffsetPageRequest extends PageRequest {
  const OffsetPageRequest({this.page = 0, required this.size, this.sort = Sort.unsorted}): assert(size > 0, 'size must be greater than zero'),assert(page >= 0, 'page must not be negative'),super._();
  

/// The zero based index of the requested page.
@JsonKey() final  int page;
/// How many entities the page should contain at most.
@override final  int size;
/// The order the backend should apply before slicing.
@override@JsonKey() final  Sort sort;

/// Create a copy of PageRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OffsetPageRequestCopyWith<OffsetPageRequest> get copyWith => _$OffsetPageRequestCopyWithImpl<OffsetPageRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OffsetPageRequest&&(identical(other.page, page) || other.page == page)&&(identical(other.size, size) || other.size == size)&&(identical(other.sort, sort) || other.sort == sort));
}


@override
int get hashCode => Object.hash(runtimeType,page,size,sort);

@override
String toString() {
  return 'PageRequest.offset(page: $page, size: $size, sort: $sort)';
}


}

/// @nodoc
abstract mixin class $OffsetPageRequestCopyWith<$Res> implements $PageRequestCopyWith<$Res> {
  factory $OffsetPageRequestCopyWith(OffsetPageRequest value, $Res Function(OffsetPageRequest) _then) = _$OffsetPageRequestCopyWithImpl;
@override @useResult
$Res call({
 int page, int size, Sort sort
});


@override $SortCopyWith<$Res> get sort;

}
/// @nodoc
class _$OffsetPageRequestCopyWithImpl<$Res>
    implements $OffsetPageRequestCopyWith<$Res> {
  _$OffsetPageRequestCopyWithImpl(this._self, this._then);

  final OffsetPageRequest _self;
  final $Res Function(OffsetPageRequest) _then;

/// Create a copy of PageRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? page = null,Object? size = null,Object? sort = null,}) {
  return _then(OffsetPageRequest(
page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as Sort,
  ));
}

/// Create a copy of PageRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SortCopyWith<$Res> get sort {
  
  return $SortCopyWith<$Res>(_self.sort, (value) {
    return _then(_self.copyWith(sort: value));
  });
}
}

/// @nodoc


class CursorPageRequest extends PageRequest {
  const CursorPageRequest({required this.size, this.cursor, this.sort = Sort.unsorted}): assert(size > 0, 'size must be greater than zero'),super._();
  

/// How many entities the page should contain at most.
@override final  int size;
/// The position to continue from, `null` for the first page.
 final  String? cursor;
/// The order the backend should apply before slicing.
@override@JsonKey() final  Sort sort;

/// Create a copy of PageRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorPageRequestCopyWith<CursorPageRequest> get copyWith => _$CursorPageRequestCopyWithImpl<CursorPageRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorPageRequest&&(identical(other.size, size) || other.size == size)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.sort, sort) || other.sort == sort));
}


@override
int get hashCode => Object.hash(runtimeType,size,cursor,sort);

@override
String toString() {
  return 'PageRequest.cursor(size: $size, cursor: $cursor, sort: $sort)';
}


}

/// @nodoc
abstract mixin class $CursorPageRequestCopyWith<$Res> implements $PageRequestCopyWith<$Res> {
  factory $CursorPageRequestCopyWith(CursorPageRequest value, $Res Function(CursorPageRequest) _then) = _$CursorPageRequestCopyWithImpl;
@override @useResult
$Res call({
 int size, String? cursor, Sort sort
});


@override $SortCopyWith<$Res> get sort;

}
/// @nodoc
class _$CursorPageRequestCopyWithImpl<$Res>
    implements $CursorPageRequestCopyWith<$Res> {
  _$CursorPageRequestCopyWithImpl(this._self, this._then);

  final CursorPageRequest _self;
  final $Res Function(CursorPageRequest) _then;

/// Create a copy of PageRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? size = null,Object? cursor = freezed,Object? sort = null,}) {
  return _then(CursorPageRequest(
size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String?,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as Sort,
  ));
}

/// Create a copy of PageRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SortCopyWith<$Res> get sort {
  
  return $SortCopyWith<$Res>(_self.sort, (value) {
    return _then(_self.copyWith(sort: value));
  });
}
}

// dart format on
