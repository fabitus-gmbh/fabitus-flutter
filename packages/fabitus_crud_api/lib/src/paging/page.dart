import 'package:freezed_annotation/freezed_annotation.dart';

import 'page_request.dart';

part 'page.freezed.dart';

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
@Freezed(fromJson: false, toJson: false, toStringOverride: false)
sealed class Page<T> with _$Page<T> {
  /// Creates an offset based page.
  const factory Page.offset({
    /// The entities on this page.
    @Default([]) List<T> content,

    /// The zero based index of this page.
    @Default(0) int page,

    /// The page size that was requested.
    required int size,

    /// The total number of entities across all pages, `null` when the backend
    /// does not report it.
    int? totalElements,
  }) = OffsetPage<T>;

  /// Creates a cursor based page.
  const factory Page.cursor({
    /// The entities on this page.
    @Default([]) List<T> content,

    /// The cursor to pass to the next request, `null` when this is the last
    /// page.
    String? nextCursor,
  }) = CursorPage<T>;

  const Page._();

  /// Reads a page from a decoded JSON body.
  ///
  /// The shape is detected from the keys that are present: a body carrying
  /// `cursor`, `nextCursor` or `nextPageToken` becomes a [CursorPage], anything
  /// else an [OffsetPage]. Both variants accept `content`, `items` or `data`
  /// for the element list, so Spring Data and hand rolled backends both work.
  factory Page.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) {
    final rawContent = json['content'] ?? json['items'] ?? json['data'];
    final content = rawContent is List ? rawContent.map(fromJsonT).toList(growable: false) : <T>[];
    if (json.containsKey('nextCursor') || json.containsKey('nextPageToken') || json.containsKey('cursor')) {
      return CursorPage<T>(
        content: content,
        nextCursor: (json['nextCursor'] ?? json['nextPageToken'] ?? json['cursor']) as String?,
      );
    }
    return OffsetPage<T>(
      content: content,
      page: ((json['page'] ?? json['number'] ?? 0) as num).toInt(),
      size: ((json['size'] ?? json['limit'] ?? content.length) as num).toInt(),
      totalElements: ((json['totalElements'] ?? json['totalSize'] ?? json['total']) as num?)?.toInt(),
    );
  }

  /// Whether a following page exists.
  bool get hasNext => switch (this) {
    final OffsetPage<T> page => switch (page.totalElements) {
      // Without a total the only reliable signal is a full page.
      null => page.size > 0 && page.content.length >= page.size,
      final total => page.offset + page.content.length < total,
    },
    CursorPage<T>(:final nextCursor) => nextCursor != null && nextCursor.isNotEmpty,
  };

  /// The request that reads the following page, or `null` when [hasNext] is
  /// `false`.
  ///
  /// [current] is the request that produced this page; its size and sort are
  /// carried over.
  PageRequest? nextPageRequest(PageRequest current) {
    if (!hasNext) return null;
    return switch (this) {
      OffsetPage<T>(:final page) => switch (current) {
        final OffsetPageRequest request => request.next(),
        CursorPageRequest(:final size, :final sort) => PageRequest.offset(page: page + 1, size: size, sort: sort),
      },
      CursorPage<T>(:final nextCursor) => switch (current) {
        final CursorPageRequest request => request.copyWith(cursor: nextCursor),
        OffsetPageRequest(:final size, :final sort) => PageRequest.cursor(size: size, cursor: nextCursor, sort: sort),
      },
    };
  }

  /// The number of entities on this page.
  int get length => content.length;

  /// Whether this page holds no entities.
  bool get isEmpty => content.isEmpty;

  /// Whether this page holds at least one entity.
  bool get isNotEmpty => content.isNotEmpty;

  /// This page with every element converted by [transform].
  ///
  /// The variant and its metadata are preserved; the static type widens to
  /// [Page], so cast when you need the variant back.
  Page<R> map<R>(R Function(T element) transform) {
    final converted = content.map(transform).toList(growable: false);
    return switch (this) {
      OffsetPage<T>(:final page, :final size, :final totalElements) => OffsetPage<R>(
        content: converted,
        page: page,
        size: size,
        totalElements: totalElements,
      ),
      CursorPage<T>(:final nextCursor) => CursorPage<R>(content: converted, nextCursor: nextCursor),
    };
  }

  /// The JSON representation of this page.
  Map<String, dynamic> toJson(Object? Function(T element) toJsonT) {
    final converted = content.map(toJsonT).toList(growable: false);
    return switch (this) {
      OffsetPage<T>(:final page, :final size, :final totalElements) => {
        'content': converted,
        'page': page,
        'size': size,
        'totalElements': ?totalElements,
      },
      CursorPage<T>(:final nextCursor) => {'content': converted, 'nextCursor': nextCursor},
    };
  }

  @override
  String toString() => switch (this) {
    OffsetPage<T>(:final page, :final size, :final totalElements) =>
      'OffsetPage(page: $page, size: $size, total: $totalElements, '
          'content: ${content.length})',
    CursorPage<T>(:final nextCursor) => 'CursorPage(nextCursor: $nextCursor, content: ${content.length})',
  };
}

/// Members that only an offset based page has.
extension OffsetPageX<T> on OffsetPage<T> {
  /// The number of entities that precede this page.
  int get offset => page * size;

  /// The total number of pages, `null` when [OffsetPage.totalElements] is
  /// unknown.
  int? get totalPages {
    final total = totalElements;
    if (total == null || size <= 0) return null;
    return (total / size).ceil();
  }

  /// Whether this is the last page.
  bool get isLast => !hasNext;
}
