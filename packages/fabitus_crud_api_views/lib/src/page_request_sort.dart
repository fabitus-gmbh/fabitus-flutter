import 'package:fabitus_crud_api/fabitus_crud_api.dart';

/// Changing the ordering or the size of a page request, whichever flavour it is.
///
/// Both reset the position: a different sort or a different page size makes the
/// page the user was on meaningless, and a cursor issued under the old ordering
/// is not valid under the new one.
extension PageRequestSorting on PageRequest {
  /// This request ordered by [sort], back at the first page.
  PageRequest withSort(Sort sort) => switch (this) {
    final OffsetPageRequest request => request.copyWith(sort: sort, page: 0),
    final CursorPageRequest request => request.copyWith(sort: sort, cursor: null),
  };

  /// This request with [size] entities per page, back at the first page.
  PageRequest withSize(int size) => switch (this) {
    final OffsetPageRequest request => request.copyWith(size: size, page: 0),
    final CursorPageRequest request => request.copyWith(size: size, cursor: null),
  };

  /// The zero based page number, for a request that can name one.
  ///
  /// `null` for a cursor request: a cursor says where to continue, not how far
  /// along it is.
  int? get pageNumber => switch (this) {
    OffsetPageRequest(:final page) => page,
    CursorPageRequest() => null,
  };
}
