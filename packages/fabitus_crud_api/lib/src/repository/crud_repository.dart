import 'package:meta/meta.dart';

import '../core/crud_entity.dart';
import '../error/crud_error_mapper.dart';
import '../error/crud_exception.dart';
import '../error/crud_result.dart';
import '../paging/page.dart';
import '../paging/page_request.dart';

/// Read only access to entities of type [T] identified by [ID].
///
/// The method names follow Spring Data's `CrudRepository`, so the contract is
/// familiar on both ends of a project.
abstract interface class ReadCrudRepository<T extends CrudEntity<ID>, ID extends Object> {
  /// Reads the entity with [id].
  ///
  /// Fails with [CrudNotFoundException] when no such entity exists.
  Future<CrudResult<T>> findById(ID id);

  /// Reads every entity.
  ///
  /// Remote repositories may report [CrudUnsupportedException] when the backend
  /// exposes no endpoint for this; use `findPage` there instead.
  Future<CrudResult<List<T>>> findAll();

  /// Whether an entity with [id] exists.
  Future<CrudResult<bool>> existsById(ID id);

  /// The total number of entities.
  Future<CrudResult<int>> count();
}

/// Read and write access to entities of type [T] identified by [ID].
abstract interface class CrudRepository<T extends CrudEntity<ID>, ID extends Object>
    implements ReadCrudRepository<T, ID> {
  /// Persists a new entity and returns it with the id assigned by the store.
  Future<CrudResult<T>> create(T entity);

  /// Overwrites the stored entity that has the same id as [entity].
  ///
  /// Fails with [CrudValidationException] when `entity.id` is `null`.
  Future<CrudResult<T>> update(T entity);

  /// Creates or updates [entity], depending on whether it already has an id.
  Future<CrudResult<T>> save(T entity);

  /// Deletes the entity with [id].
  Future<CrudResult<void>> deleteById(ID id);

  /// Deletes [entity].
  ///
  /// Fails with [CrudValidationException] when `entity.id` is `null`.
  Future<CrudResult<void>> delete(T entity);
}

/// A [CrudRepository] that can also read a single [Page] of entities.
///
/// The equivalent of Spring Data's `PagingAndSortingRepository`.
abstract interface class PagingCrudRepository<T extends CrudEntity<ID>, ID extends Object>
    implements CrudRepository<T, ID> {
  /// Reads the page described by [pageRequest].
  Future<CrudResult<Page<T>>> findPage(PageRequest pageRequest);
}

/// Shared behaviour for [CrudRepository] implementations.
///
/// Provides the derived operations - [save] and [delete] - and the [guard]
/// helper that funnels every thrown object through [errorMapper]. Extend this
/// instead of implementing [CrudRepository] from scratch.
abstract class BaseCrudRepository<T extends CrudEntity<ID>, ID extends Object> implements CrudRepository<T, ID> {
  /// Creates a repository that maps failures with [errorMapper].
  const BaseCrudRepository({this.errorMapper = const DefaultCrudErrorMapper()});

  /// Translates thrown objects into [CrudException]s.
  final CrudErrorMapper errorMapper;

  /// Runs [action] and converts anything it throws into a [CrudFailure].
  @protected
  Future<CrudResult<R>> guard<R>(Future<R> Function() action) => guardCrud<R>(action, errorMapper: errorMapper);

  /// Returns the id of [entity], or a failure when it has none.
  ///
  /// Use this in `update` and `delete` implementations to reject entities that
  /// were never persisted.
  @protected
  CrudResult<ID> requireId(T entity) {
    final id = entity.id;
    if (id == null) {
      return CrudFailure<ID>(CrudValidationException('Cannot operate on a $T without an id'), StackTrace.current);
    }
    return CrudSuccess<ID>(id);
  }

  @override
  Future<CrudResult<T>> save(T entity) => entity.id == null ? create(entity) : update(entity);

  @override
  Future<CrudResult<void>> delete(T entity) => switch (requireId(entity)) {
    CrudSuccess<ID>(:final data) => deleteById(data),
    final CrudFailure<ID> failure => Future<CrudResult<void>>.value(failure.cast<void>()),
  };

  @override
  Future<CrudResult<bool>> existsById(ID id) async => switch (await findById(id)) {
    CrudSuccess<T>() => const CrudSuccess<bool>(true),
    CrudFailure<T>(error: CrudNotFoundException()) => const CrudSuccess(false),
    final CrudFailure<T> failure => failure.cast<bool>(),
  };
}
