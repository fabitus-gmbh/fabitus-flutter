# Changelog

## 0.1.0

Initial release.

- `CrudEntity` and `EntityCodec` as the entity contract.
- `CrudResult` with `CrudSuccess`/`CrudFailure`, a sealed `CrudException`
  hierarchy, RFC 9457 `ProblemDetail` parsing and pluggable `CrudErrorMapper`s.
- `Sort`, `PageRequest` and `Page` in offset and cursor flavours, matching
  Spring Data's wire format.
- `ReadCrudRepository`, `CrudRepository` and `PagingCrudRepository` contracts
  plus `BaseCrudRepository` for custom implementations.
- `InMemoryCrudRepository`, `KeyValueCrudRepository` with a `KeyValueStore`
  seam, and `RemoteCrudRepository`/`RemotePagingCrudRepository` over a
  retrofit compatible `CrudApi`.
- `CrudService`/`PagingCrudService` publishing `CrudEvent`s for every write.
