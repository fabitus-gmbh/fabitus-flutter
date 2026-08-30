# Changelog

## 0.1.0

Initial release.

- `CrudEntity` and `EntityCodec` as the entity contract.
- `CrudResult` with `CrudSuccess`/`CrudFailure`, a sealed `CrudException`
  hierarchy, RFC 9457 `ProblemDetail` parsing and pluggable `CrudErrorMapper`s.
- `Sort`, `PageRequest` and `Page` in offset and cursor flavours, matching
  Spring Data's wire format.
- Value types (`Sort`, `SortOrder`, `PageRequest`, `Page`, `ProblemDetail`,
  `ConstraintViolation`, `CrudEvent`) are `freezed` classes, so they carry
  `copyWith` and value equality. The generated code is committed, so consumers
  need no `build_runner`. `fromJson`/`toJson` stay hand written to keep the
  tolerant parsing of both the RFC 9457 and the Spring Data wire formats.
- Ids for locally created entities default to a version 4 UUID (`newUuid`).
- `ReadCrudRepository`, `CrudRepository` and `PagingCrudRepository` contracts
  plus `BaseCrudRepository` for custom implementations.
- `InMemoryCrudRepository`, `KeyValueCrudRepository` with a `KeyValueStore`
  seam, and `RemoteCrudRepository`/`RemotePagingCrudRepository` over a
  retrofit compatible `CrudApi`.
- `CrudService`/`PagingCrudService` publishing `CrudEvent`s for every write.
