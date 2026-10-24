import 'package:meta/meta.dart';

import '../core/crud_entity.dart';
import '../error/crud_error_mapper.dart';
import '../error/crud_exception.dart';
import '../error/crud_result.dart';
import 'repository_fragment.dart';
import 'repository_mixins.dart';

/// Read only access to entities of type [T] identified by [ID].
///
/// The method names follow Spring Data's `CrudRepository`, so the contract is
/// familiar on both ends of a project.
abstract interface class ReadCrudRepository<T extends CrudEntity<ID>, ID extends Object>
    implements FindByIdRepository<T, ID>, ListRepository<T, ID> {}

/// Read and write access to entities of type [T] identified by [ID].
///
/// A composition of the repository fragments - [FindByIdRepository],
/// [ListRepository], [CreateRepository], [UpdateRepository], [SaveRepository]
/// and [DeleteRepository]. A repository over a backend with less than full
/// CRUD implements the fragments it has instead of this interface.
abstract interface class CrudRepository<T extends CrudEntity<ID>, ID extends Object>
    implements ReadCrudRepository<T, ID>, EntityRepository<T, ID>, CreateRepository<T, ID>, UpdateRepository<T, ID> {}

/// A [CrudRepository] that can also read a single page of entities.
///
/// The equivalent of Spring Data's `PagingAndSortingRepository`.
abstract interface class PagingCrudRepository<T extends CrudEntity<ID>, ID extends Object>
    implements CrudRepository<T, ID>, PagingRepository<T, ID> {}

/// Shared behaviour for [CrudRepository] implementations.
///
/// Composes [GuardedRepository], [SaveViaCreateAndUpdate], [DeleteViaDeleteById]
/// and [ExistsViaFindById], so the derived operations and the `guard` helper
/// exist exactly once, and adds [requireId]. Extend this instead of
/// implementing [CrudRepository] from scratch; a repository that offers only
/// part of the contract combines the fragment interfaces with those mixins
/// directly.
abstract class BaseCrudRepository<T extends CrudEntity<ID>, ID extends Object>
    with GuardedRepository, SaveViaCreateAndUpdate<T, ID>, DeleteViaDeleteById<T, ID>, ExistsViaFindById<T, ID>
    implements CrudRepository<T, ID> {
  /// Creates a repository that maps failures with [errorMapper].
  const BaseCrudRepository({this.errorMapper = const DefaultCrudErrorMapper()});

  /// Translates thrown objects into [CrudException]s.
  @override
  final CrudErrorMapper errorMapper;

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
}
