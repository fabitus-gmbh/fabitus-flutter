# Changelog

## 0.2.0

- `EntityCubit` takes an `EntityRepository` (find, save, delete) instead of a
  full `CrudRepository`. Every `CrudRepository` is one, so call sites keep
  working; a repository over a backend with less than full CRUD now qualifies
  by implementing just those fragments. Code that uses `cubit.repository` as a
  `CrudRepository` - reading `findAll` or `create` off it, or passing it on as
  one - must keep its own typed reference. Needs `fabitus_crud_api` 0.2.0.

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
