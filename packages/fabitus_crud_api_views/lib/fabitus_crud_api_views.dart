/// Lists and tables over `fabitus_crud_api` repositories, with the design left
/// to you.
///
/// Four shapes, one for each way a collection reaches a screen:
///
/// * [CrudInfiniteList] - appends the next page as the user scrolls.
/// * [CrudLoadMoreList] - appends it when the user asks.
/// * [CrudPaginatedTable] - one page at a time, sorted by the backend, with a
///   footer you draw.
/// * [CrudLoadedTable] - the whole collection at once, sorted and filtered in
///   memory.
///
/// The paged three run on a `PaginationCubit`, the last on a `LoadCubit`, both
/// from `fabitus_crud_api_bloc`. [CrudTable] is the plain table underneath, for
/// rows that come from somewhere else entirely.
///
/// **Nothing here paints.** These widgets own the wiring, the column sizing and
/// the sort interaction; every colour, border, divider, padding and font comes
/// from a builder you pass. They import `package:flutter/widgets.dart`, not
/// `material.dart`, so they cannot accidentally acquire a look.
library;

/// Re-exported so the prefetch knob of [CrudInfiniteList] can be set without
/// reaching into `package:flutter/rendering.dart` for one class.
export 'package:flutter/rendering.dart' show ScrollCacheExtent;

export 'src/crud_table.dart';
export 'src/loaded_table.dart';
export 'src/page_request_sort.dart';
export 'src/paged_list.dart';
export 'src/paginated_table.dart';
export 'src/pagination_controls.dart';
export 'src/table_column.dart';
