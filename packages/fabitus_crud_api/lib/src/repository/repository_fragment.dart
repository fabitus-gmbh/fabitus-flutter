import '../core/crud_entity.dart';
import '../error/crud_exception.dart';
import '../error/crud_result.dart';
import '../paging/page.dart';
import '../paging/page_request.dart';

/// Reads single entities of type [T] identified by [ID].
///
/// The repository contract is cut into fragments - this interface and its
/// siblings [ListRepository], [PagingRepository], [CreateRepository],
/// [UpdateRepository], [SaveRepository] and [DeleteRepository] - so that a
/// repository over a backend with less than full CRUD implements only what the
/// backend has, instead of failing the rest with [CrudUnsupportedException].
/// [CrudRepository] and the other established interfaces are compositions of
/// these fragments, so everything written against them keeps working.
abstract interface class FindByIdRepository<T extends CrudEntity<ID>, ID extends Object> {
  /// Reads the entity with [id].
  ///
  /// Fails with [CrudNotFoundException] when no such entity exists.
  Future<CrudResult<T>> findById(ID id);

  /// Whether an entity with [id] exists.
  Future<CrudResult<bool>> existsById(ID id);
}

/// Reads the whole collection of entities of type [T].
abstract interface class ListRepository<T extends CrudEntity<ID>, ID extends Object> {
  /// Reads every entity.
  ///
  /// A repository over a backend without a list endpoint does not implement
  /// [ListRepository] at all. Types that promise the full [CrudRepository]
  /// anyway - `RemoteCrudRepository`, for example - report
  /// [CrudUnsupportedException] here and offer `findPage` instead.
  Future<CrudResult<List<T>>> findAll();

  /// The total number of entities.
  Future<CrudResult<int>> count();
}

/// Reads one [Page] of entities of type [T] at a time.
abstract interface class PagingRepository<T extends CrudEntity<ID>, ID extends Object> {
  /// Reads the page described by [pageRequest].
  Future<CrudResult<Page<T>>> findPage(PageRequest pageRequest);
}

/// Creates entities of type [T].
abstract interface class CreateRepository<T extends CrudEntity<ID>, ID extends Object> {
  /// Persists a new entity and returns it with the id assigned by the store.
  Future<CrudResult<T>> create(T entity);
}

/// Updates entities of type [T].
abstract interface class UpdateRepository<T extends CrudEntity<ID>, ID extends Object> {
  /// Overwrites the stored entity that has the same id as [entity].
  ///
  /// Fails with [CrudValidationException] when `entity.id` is `null`.
  Future<CrudResult<T>> update(T entity);
}

/// Creates or updates entities of type [T] in one call.
abstract interface class SaveRepository<T extends CrudEntity<ID>, ID extends Object> {
  /// Creates or updates [entity], depending on whether it already has an id.
  Future<CrudResult<T>> save(T entity);
}

/// Deletes entities of type [T].
abstract interface class DeleteRepository<T extends CrudEntity<ID>, ID extends Object> {
  /// Deletes the entity with [id].
  Future<CrudResult<void>> deleteById(ID id);

  /// Deletes [entity].
  ///
  /// Fails with [CrudValidationException] when `entity.id` is `null`.
  Future<CrudResult<void>> delete(T entity);
}

/// What a screen around one entity needs: read it, save it, delete it.
///
/// This is the contract `EntityCubit` in `fabitus_crud_api_bloc` works with.
/// Every [CrudRepository] is one; a repository over a backend with less than
/// full CRUD can implement just this.
abstract interface class EntityRepository<T extends CrudEntity<ID>, ID extends Object>
    implements FindByIdRepository<T, ID>, SaveRepository<T, ID>, DeleteRepository<T, ID> {}
