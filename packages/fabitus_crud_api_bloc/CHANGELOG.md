# Changelog

## 0.1.0

Initial release. Generalised from the Toolbox's `core/bloc`, as cubits.

- `LoadCubit`/`LoadState` for showing one value. Covers a single entity and a
  list alike, so the three classes it replaces - a bloc, a cubit and a list
  cubit - become one. `refresh()` keeps the current value on screen, and a failed
  refresh keeps it beside the error.
- `PaginationCubit.updateQuery`, applying a new request and a new filter
  together: `updateRequest` alone keeps the current filter, and calling both in
  turn reads the first page twice.
- `PaginationCubit`/`PaginationState` for walking a paged collection, offset or
  cursor based, exposing both the current page and everything read so far. Pages
  already read are kept, so going back needs no cursor.
- `EntityCubit`/`EntityState` for one entity, holding the stored copy and the
  draft separately, so `isDirty`, `reset()` and a failed save that keeps the
  form filled all work.
- `LoadBuilder` and `CrudErrorView` for the loading and failure shapes.
- Overlapping calls are safe: every cubit drops a response that a newer call has
  overtaken, which is the `sequential()` transformer's job done without events.
