# Changelog

## 0.1.0

Initial release. Generalised from the Toolbox's paginated table and list widgets,
with the design system taken out.

- `TableColumn` and `ColumnSortState`: a column is a header builder, a cell
  builder, a `sortKey` for the backend and a `sortValue` for in-memory sorting.
  Sizing is `width` or `flex`; nothing else about it is visual.
- `CrudTable`, the table underneath: sizes the cells, turns a header tap into the
  next `Sort`, and paints nothing.
- `CrudPaginatedTable` over a `PaginationCubit`, sorting on the server and
  starting over at the first page when the ordering changes.
- `PaginationControls`, everything a footer needs to know and can do, with
  callbacks that are `null` when the action is unavailable.
- `CrudInfiniteList` and `CrudLoadMoreList`, accumulating lists that read the
  next page on scroll or on demand. `cacheExtent` is the prefetch knob.
- `CrudLoadedTable` over a `LoadCubit`, sorting and filtering the whole
  collection in memory.
- `CrudPaginationProvider` and `CrudLoadProvider`, which create, own and close
  the cubit, turn the filter into a widget property so a search field only has to
  rebuild, and reread the view when a `CrudService.events` stream announces a
  write - coalescing a burst into one request. Composed with a view rather than
  fused into one widget per view, so a builder added to a table does not have to
  be forwarded through a second class.
- Nothing imports `material.dart`, so none of it can acquire a look by accident.
