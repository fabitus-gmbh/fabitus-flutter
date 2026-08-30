import 'sort.dart';

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
sealed class PageRequest {
  /// Creates a page request of [size] entities, ordered by [sort].
  const PageRequest({required this.size, this.sort = const Sort.unsorted()})
    : assert(size > 0, 'size must be greater than zero');

  /// How many entities the page should contain at most.
  final int size;

  /// The order the backend should apply before slicing.
  final Sort sort;

  /// The query parameters representing this request.
  Map<String, dynamic> toQueryParameters();

  /// Alias for [toQueryParameters], so retrofit and `jsonEncode` can use it.
  Map<String, dynamic> toJson() => toQueryParameters();

  /// The sort entries, only present when [Sort.isSorted].
  Map<String, dynamic> get _sortParameter => {
    if (sort.isSorted) 'sort': sort.toQueryValue(),
  };
}

/// A page identified by its zero based [page] index, like Spring's `Pageable`.
final class OffsetPageRequest extends PageRequest {
  /// Requests page [page] of [size] entities.
  const OffsetPageRequest({
    this.page = 0,
    required super.size,
    super.sort = const Sort.unsorted(),
  }) : assert(page >= 0, 'page must not be negative');

  /// The zero based index of the requested page.
  final int page;

  /// The number of entities to skip, that is `page * size`.
  int get offset => page * size;

  /// The request for the following page.
  OffsetPageRequest next() => withPage(page + 1);

  /// The request for the preceding page, or this request when already on the
  /// first page.
  OffsetPageRequest previous() => page == 0 ? this : withPage(page - 1);

  /// This request pointing at [page].
  OffsetPageRequest withPage(int page) =>
      OffsetPageRequest(page: page, size: size, sort: sort);

  /// This request ordered by [sort].
  OffsetPageRequest withSort(Sort sort) =>
      OffsetPageRequest(page: page, size: size, sort: sort);

  @override
  Map<String, dynamic> toQueryParameters() => {
    'page': page,
    'size': size,
    ..._sortParameter,
  };

  @override
  String toString() =>
      'OffsetPageRequest(page: $page, size: $size, sort: $sort)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffsetPageRequest &&
          other.page == page &&
          other.size == size &&
          other.sort == sort;

  @override
  int get hashCode => Object.hash(page, size, sort);
}

/// A page identified by an opaque [cursor] handed out by the previous response.
final class CursorPageRequest extends PageRequest {
  /// Requests [size] entities starting after [cursor].
  ///
  /// A `null` cursor requests the first page.
  const CursorPageRequest({
    required super.size,
    this.cursor,
    super.sort = const Sort.unsorted(),
  });

  /// The position to continue from, `null` for the first page.
  final String? cursor;

  /// Whether this request asks for the first page.
  bool get isFirst => cursor == null;

  /// This request continuing after [cursor].
  CursorPageRequest withCursor(String? cursor) =>
      CursorPageRequest(size: size, cursor: cursor, sort: sort);

  @override
  Map<String, dynamic> toQueryParameters() => {
    'size': size,
    if (cursor != null) 'cursor': cursor,
    ..._sortParameter,
  };

  @override
  String toString() =>
      'CursorPageRequest(size: $size, cursor: $cursor, sort: $sort)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CursorPageRequest &&
          other.cursor == cursor &&
          other.size == size &&
          other.sort == sort;

  @override
  int get hashCode => Object.hash(cursor, size, sort);
}
