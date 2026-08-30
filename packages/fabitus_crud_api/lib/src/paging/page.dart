import 'package:collection/collection.dart';

import 'page_request.dart';

/// One slice of a larger result set.
///
/// The two variants mirror [PageRequest]: [OffsetPage] knows its index and, if
/// the backend reports it, the total number of elements; [CursorPage] only
/// knows how to continue.
///
/// ```dart
/// @GET('/todos')
/// Future<Page<Todo>> findPage(@Queries() PageRequest? pageRequest);
/// ```
///
/// Retrofit generates `Page.fromJson(json, (o) => Todo.fromJson(o))` for that
/// signature, which is exactly what [Page.fromJson] provides.
sealed class Page<T> {
  /// Creates a page holding [content].
  const Page({required this.content});

  /// Reads a page from a decoded JSON body.
  ///
  /// The shape is detected from the keys that are present: a body carrying
  /// `cursor`, `nextCursor` or `nextPageToken` becomes a [CursorPage], anything
  /// else an [OffsetPage]. Both variants accept `content`, `items` or `data`
  /// for the element list, so Spring Data and hand rolled backends both work.
  factory Page.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    final rawContent = (json['content'] ?? json['items'] ?? json['data']);
    final content = rawContent is List
        ? rawContent.map(fromJsonT).toList(growable: false)
        : <T>[];
    final cursor =
        (json['nextCursor'] ?? json['nextPageToken'] ?? json['cursor'])
            as String?;
    if (json.containsKey('nextCursor') ||
        json.containsKey('nextPageToken') ||
        json.containsKey('cursor')) {
      return CursorPage<T>(content: content, nextCursor: cursor);
    }
    return OffsetPage<T>(
      content: content,
      page: ((json['page'] ?? json['number'] ?? 0) as num).toInt(),
      size: ((json['size'] ?? json['limit'] ?? content.length) as num).toInt(),
      totalElements:
          ((json['totalElements'] ?? json['totalSize'] ?? json['total'])
                  as num?)
              ?.toInt(),
    );
  }

  /// The entities on this page.
  final List<T> content;

  /// Whether a following page exists.
  bool get hasNext;

  /// The request that reads the following page, or `null` when [hasNext] is
  /// `false`.
  ///
  /// [current] is the request that produced this page; its size and sort are
  /// carried over.
  PageRequest? nextPageRequest(PageRequest current);

  /// The number of entities on this page.
  int get length => content.length;

  /// Whether this page holds no entities.
  bool get isEmpty => content.isEmpty;

  /// Whether this page holds at least one entity.
  bool get isNotEmpty => content.isNotEmpty;

  /// This page with every element converted by [transform].
  Page<R> map<R>(R Function(T element) transform);

  /// The JSON representation of this page.
  Map<String, dynamic> toJson(Object? Function(T element) toJsonT);
}

/// A page identified by its zero based index.
final class OffsetPage<T> extends Page<T> {
  /// Creates an offset based page.
  const OffsetPage({
    required super.content,
    this.page = 0,
    required this.size,
    this.totalElements,
  });

  /// An empty page, useful as an initial state.
  const OffsetPage.empty({int size = 0})
    : this(content: const [], size: size, totalElements: 0);

  /// The zero based index of this page.
  final int page;

  /// The page size that was requested.
  final int size;

  /// The total number of entities across all pages, `null` when the backend
  /// does not report it.
  final int? totalElements;

  /// The number of entities that precede this page.
  int get offset => page * size;

  /// The total number of pages, `null` when [totalElements] is unknown.
  int? get totalPages {
    final total = totalElements;
    if (total == null || size <= 0) return null;
    return (total / size).ceil();
  }

  /// Whether this is the last page.
  bool get isLast => !hasNext;

  @override
  bool get hasNext {
    final total = totalElements;
    // Without a total the only reliable signal is a full page.
    if (total == null) return content.length >= size && size > 0;
    return offset + content.length < total;
  }

  @override
  OffsetPageRequest? nextPageRequest(PageRequest current) {
    if (!hasNext) return null;
    return switch (current) {
      OffsetPageRequest() => current.next(),
      CursorPageRequest() => OffsetPageRequest(
        page: page + 1,
        size: current.size,
        sort: current.sort,
      ),
    };
  }

  @override
  OffsetPage<R> map<R>(R Function(T element) transform) => OffsetPage<R>(
    content: content.map(transform).toList(growable: false),
    page: page,
    size: size,
    totalElements: totalElements,
  );

  @override
  Map<String, dynamic> toJson(Object? Function(T element) toJsonT) => {
    'content': content.map(toJsonT).toList(growable: false),
    'page': page,
    'size': size,
    if (totalElements != null) 'totalElements': totalElements,
  };

  @override
  String toString() =>
      'OffsetPage(page: $page, size: $size, total: $totalElements, '
      'content: ${content.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffsetPage<T> &&
          other.page == page &&
          other.size == size &&
          other.totalElements == totalElements &&
          const DeepCollectionEquality().equals(other.content, content);

  @override
  int get hashCode => Object.hash(
    page,
    size,
    totalElements,
    const DeepCollectionEquality().hash(content),
  );
}

/// A page that continues from an opaque cursor.
final class CursorPage<T> extends Page<T> {
  /// Creates a cursor based page.
  const CursorPage({required super.content, this.nextCursor});

  /// An empty page, useful as an initial state.
  const CursorPage.empty() : this(content: const []);

  /// The cursor to pass to the next request, `null` when this is the last page.
  final String? nextCursor;

  @override
  bool get hasNext => nextCursor != null && nextCursor!.isNotEmpty;

  @override
  CursorPageRequest? nextPageRequest(PageRequest current) {
    if (!hasNext) return null;
    return switch (current) {
      CursorPageRequest() => current.withCursor(nextCursor),
      OffsetPageRequest() => CursorPageRequest(
        size: current.size,
        cursor: nextCursor,
        sort: current.sort,
      ),
    };
  }

  @override
  CursorPage<R> map<R>(R Function(T element) transform) => CursorPage<R>(
    content: content.map(transform).toList(growable: false),
    nextCursor: nextCursor,
  );

  @override
  Map<String, dynamic> toJson(Object? Function(T element) toJsonT) => {
    'content': content.map(toJsonT).toList(growable: false),
    'nextCursor': nextCursor,
  };

  @override
  String toString() =>
      'CursorPage(nextCursor: $nextCursor, content: ${content.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CursorPage<T> &&
          other.nextCursor == nextCursor &&
          const DeepCollectionEquality().equals(other.content, content);

  @override
  int get hashCode =>
      Object.hash(nextCursor, const DeepCollectionEquality().hash(content));
}
