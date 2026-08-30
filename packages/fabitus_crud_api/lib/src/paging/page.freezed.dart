// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'page.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Page<T> {

/// The entities on this page.
 List<T> get content;
/// Create a copy of Page
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PageCopyWith<T, Page<T>> get copyWith => _$PageCopyWithImpl<T, Page<T>>(this as Page<T>, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Page<T>&&const DeepCollectionEquality().equals(other.content, content));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(content));



}

/// @nodoc
abstract mixin class $PageCopyWith<T,$Res>  {
  factory $PageCopyWith(Page<T> value, $Res Function(Page<T>) _then) = _$PageCopyWithImpl;
@useResult
$Res call({
 List<T> content
});




}
/// @nodoc
class _$PageCopyWithImpl<T,$Res>
    implements $PageCopyWith<T, $Res> {
  _$PageCopyWithImpl(this._self, this._then);

  final Page<T> _self;
  final $Res Function(Page<T>) _then;

/// Create a copy of Page
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? content = null,}) {
  return _then(_self.copyWith(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as List<T>,
  ));
}

}


/// Adds pattern-matching-related methods to [Page].
extension PagePatterns<T> on Page<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( OffsetPage<T> value)?  offset,TResult Function( CursorPage<T> value)?  cursor,required TResult orElse(),}){
final _that = this;
switch (_that) {
case OffsetPage() when offset != null:
return offset(_that);case CursorPage() when cursor != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( OffsetPage<T> value)  offset,required TResult Function( CursorPage<T> value)  cursor,}){
final _that = this;
switch (_that) {
case OffsetPage():
return offset(_that);case CursorPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( OffsetPage<T> value)?  offset,TResult? Function( CursorPage<T> value)?  cursor,}){
final _that = this;
switch (_that) {
case OffsetPage() when offset != null:
return offset(_that);case CursorPage() when cursor != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<T> content,  int page,  int size,  int? totalElements)?  offset,TResult Function( List<T> content,  String? nextCursor)?  cursor,required TResult orElse(),}) {final _that = this;
switch (_that) {
case OffsetPage() when offset != null:
return offset(_that.content,_that.page,_that.size,_that.totalElements);case CursorPage() when cursor != null:
return cursor(_that.content,_that.nextCursor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<T> content,  int page,  int size,  int? totalElements)  offset,required TResult Function( List<T> content,  String? nextCursor)  cursor,}) {final _that = this;
switch (_that) {
case OffsetPage():
return offset(_that.content,_that.page,_that.size,_that.totalElements);case CursorPage():
return cursor(_that.content,_that.nextCursor);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<T> content,  int page,  int size,  int? totalElements)?  offset,TResult? Function( List<T> content,  String? nextCursor)?  cursor,}) {final _that = this;
switch (_that) {
case OffsetPage() when offset != null:
return offset(_that.content,_that.page,_that.size,_that.totalElements);case CursorPage() when cursor != null:
return cursor(_that.content,_that.nextCursor);case _:
  return null;

}
}

}

/// @nodoc


class OffsetPage<T> extends Page<T> {
  const OffsetPage({final  List<T> content = const [], this.page = 0, required this.size, this.totalElements}): _content = content,super._();
  

/// The entities on this page.
 final  List<T> _content;
/// The entities on this page.
@override@JsonKey() List<T> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

/// The zero based index of this page.
@JsonKey() final  int page;
/// The page size that was requested.
 final  int size;
/// The total number of entities across all pages, `null` when the backend
/// does not report it.
 final  int? totalElements;

/// Create a copy of Page
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OffsetPageCopyWith<T, OffsetPage<T>> get copyWith => _$OffsetPageCopyWithImpl<T, OffsetPage<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OffsetPage<T>&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.page, page) || other.page == page)&&(identical(other.size, size) || other.size == size)&&(identical(other.totalElements, totalElements) || other.totalElements == totalElements));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_content),page,size,totalElements);



}

/// @nodoc
abstract mixin class $OffsetPageCopyWith<T,$Res> implements $PageCopyWith<T, $Res> {
  factory $OffsetPageCopyWith(OffsetPage<T> value, $Res Function(OffsetPage<T>) _then) = _$OffsetPageCopyWithImpl;
@override @useResult
$Res call({
 List<T> content, int page, int size, int? totalElements
});




}
/// @nodoc
class _$OffsetPageCopyWithImpl<T,$Res>
    implements $OffsetPageCopyWith<T, $Res> {
  _$OffsetPageCopyWithImpl(this._self, this._then);

  final OffsetPage<T> _self;
  final $Res Function(OffsetPage<T>) _then;

/// Create a copy of Page
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? page = null,Object? size = null,Object? totalElements = freezed,}) {
  return _then(OffsetPage<T>(
content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<T>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,totalElements: freezed == totalElements ? _self.totalElements : totalElements // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc


class CursorPage<T> extends Page<T> {
  const CursorPage({final  List<T> content = const [], this.nextCursor}): _content = content,super._();
  

/// The entities on this page.
 final  List<T> _content;
/// The entities on this page.
@override@JsonKey() List<T> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

/// The cursor to pass to the next request, `null` when this is the last
/// page.
 final  String? nextCursor;

/// Create a copy of Page
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CursorPageCopyWith<T, CursorPage<T>> get copyWith => _$CursorPageCopyWithImpl<T, CursorPage<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CursorPage<T>&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_content),nextCursor);



}

/// @nodoc
abstract mixin class $CursorPageCopyWith<T,$Res> implements $PageCopyWith<T, $Res> {
  factory $CursorPageCopyWith(CursorPage<T> value, $Res Function(CursorPage<T>) _then) = _$CursorPageCopyWithImpl;
@override @useResult
$Res call({
 List<T> content, String? nextCursor
});




}
/// @nodoc
class _$CursorPageCopyWithImpl<T,$Res>
    implements $CursorPageCopyWith<T, $Res> {
  _$CursorPageCopyWithImpl(this._self, this._then);

  final CursorPage<T> _self;
  final $Res Function(CursorPage<T>) _then;

/// Create a copy of Page
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? nextCursor = freezed,}) {
  return _then(CursorPage<T>(
content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<T>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
