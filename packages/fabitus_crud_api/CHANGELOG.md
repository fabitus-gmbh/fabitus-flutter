# Changelog

## 0.3.0

- `CrudEventHub`: the publishing half of `CrudService` as a type of its own -
  the broadcast `events` stream, the listeners, and the guarantee that a
  throwing listener is logged and skipped. For announcing writes a service
  cannot see: a repository built from the fragments, or a write that is no
  repository call at all, such as an upload that ends in a new entity. Point
  `CrudPaginationProvider.refreshOn` at `hub.events` and lists reread
  themselves. `CrudService` now publishes through a hub internally; its API is
  unchanged (`listeners` turned from a field into a getter), but overriding
  `listeners` or `isDisposed` in a subclass no longer affects what is
  published.

## 0.2.0

- The repository contract is cut into fragments: `FindByIdRepository`,
  `ListRepository`, `PagingRepository`, `CreateRepository`, `UpdateRepository`,
  `SaveRepository` and `DeleteRepository`, plus `EntityRepository` (find, save,
  delete - what an entity screen needs). `ReadCrudRepository`, `CrudRepository`
  and `PagingCrudRepository` are now compositions of them with the same member
  set as before, so existing implementations and callers are unaffected; only a
  consumer file with its own type of one of the new names gains a clash, which
  is why this is 0.2.0 and not 0.1.2. A
  repository over a backend with less than full CRUD implements only the
  fragments the backend has, instead of failing the rest with
  `CrudUnsupportedException`.
- Mixins for such partial repositories: `GuardedRepository` carries `guard` and
  the error mapper without the full contract, `SaveViaCreateAndUpdate`,
  `DeleteViaDeleteById` and `ExistsViaFindById` derive the derived operations
  per fragment. `BaseCrudRepository` is unchanged and stays the base for full
  CRUD implementations.

## 0.1.1

- `Page.fromJson` reads a body with neither a cursor key nor an offset key
  (`page`, `number`, `size`, `limit`, `offset`, `totalElements`, `totalSize`,
  `total`, `totalPages`) as the last `CursorPage`. Backends that drop null
  fields omit `nextPageToken` on the last page, and such a body used to become
  an `OffsetPage` whose `hasNext` was `true` whenever it held anything, so a
  consumer kept asking for more. Bodies with any offset key parse as before.

## 0.1.0

Initial release.

- `CrudEntity` and `EntityCodec` as the entity contract.
- `CrudResult` with `CrudSuccess`/`CrudFailure`, a sealed `CrudException`
  hierarchy carrying transport agnostic `CrudViolation`s, and pluggable
  `CrudErrorMapper`s. Decoding a backend's error format is the mapper's job;
  `package:fabitus_problem_details` covers RFC 9457.
- `Sort`, `PageRequest` and `Page` in offset and cursor flavours, matching
  Spring Data's wire format.
- Value types (`Sort`, `SortOrder`, `PageRequest`, `Page`, `ProblemDetail`,
  `CrudViolation`, `CrudEvent`) are `freezed` classes, so they carry
  `copyWith` and value equality. The generated code is committed, so consumers
  need no `build_runner`. `fromJson`/`toJson` stay hand written to keep the
  tolerant parsing of both the RFC 9457 and the Spring Data wire formats.
- Ids for locally created entities default to a version 4 UUID (`newUuid`).
- `ReadCrudRepository`, `CrudRepository` and `PagingCrudRepository` contracts
  plus `BaseCrudRepository` for custom implementations.
- `InMemoryCrudRepository`, `KeyValueCrudRepository` with a `KeyValueStore`
  seam, and `RemoteCrudRepository`/`RemotePagingCrudRepository` over a
  retrofit compatible `CrudApi`.
- `CrudService`/`PagingCrudService` publishing `CrudEvent`s for every write,
  both on a broadcast stream and to any `CrudEventListener`s passed in at
  construction. `CrudEventListener.fromCallback` adapts a plain function, so an
  `EventBus.fire` tear-off can be handed in directly.
- `crudLogger`, the `package:logging` logger this package reports to.
