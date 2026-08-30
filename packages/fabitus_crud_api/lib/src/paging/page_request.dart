import 'package:freezed_annotation/freezed_annotation.dart';

import 'sort.dart';

part 'page_request.freezed.dart';

/// What a caller asks for when reading one page of entities.
///
/// Two flavours are supported, because backends use both:
///
/// * [OffsetPageRequest] - `page` and `size`, like Spring's `Pageable`.
/// * [CursorPageRequest] - `size` plus an opaque `cursor` handed out by the
///   previous response, for keyset pagination.
///
/// [toQueryParameters] produces the map that goes on the query string. With
/// retrofit you pass the request straight through:
///
/// ```dart
/// @GET('/todos')
/// Future<Page<Todo>> findPage(@Queries() PageRequest? pageRequest);
/// ```
@freezed
sealed class PageRequest with _$PageRequest {
  /// Requests page [page] of [size] entities.
  @Assert('size > 0', 'size must be greater than zero')
  @Assert('page >= 0', 'page must not be negative')
  const factory PageRequest.offset({
    /// The zero based index of the requested page.
    @Default(0) int page,

    /// How many entities the page should contain at most.
    required int size,

    /// The order the backend should apply before slicing.
    @Default(Sort.unsorted) Sort sort,
  }) = OffsetPageRequest;

  /// Requests [size] entities starting after `cursor`.
  ///
  /// A `null` cursor requests the first page.
  @Assert('size > 0', 'size must be greater than zero')
  const factory PageRequest.cursor({
    /// How many entities the page should contain at most.
    required int size,

    /// The position to continue from, `null` for the first page.
    String? cursor,

    /// The order the backend should apply before slicing.
    @Default(Sort.unsorted) Sort sort,
  }) = CursorPageRequest;

  const PageRequest._();

  /// The query parameters representing this request.
  Map<String, dynamic> toQueryParameters() => switch (this) {
    OffsetPageRequest(:final page, :final size) => {'page': page, 'size': size, ..._sortParameter},
    CursorPageRequest(:final size, :final cursor) => {'size': size, 'cursor': ?cursor, ..._sortParameter},
  };

  /// Alias for [toQueryParameters], so retrofit and `jsonEncode` can use it.
  Map<String, dynamic> toJson() => toQueryParameters();

  Map<String, dynamic> get _sortParameter => {if (sort.isSorted) 'sort': sort.toQueryValue()};
}

/// Members that only an offset based request has.
extension OffsetPageRequestX on OffsetPageRequest {
  /// The number of entities to skip, that is `page * size`.
  int get offset => page * size;

  /// The request for the following page.
  OffsetPageRequest next() => copyWith(page: page + 1);

  /// The request for the preceding page, or this request when already on the
  /// first page.
  OffsetPageRequest previous() => page == 0 ? this : copyWith(page: page - 1);
}

/// Members that only a cursor based request has.
extension CursorPageRequestX on CursorPageRequest {
  /// Whether this request asks for the first page.
  bool get isFirst => cursor == null;
}
