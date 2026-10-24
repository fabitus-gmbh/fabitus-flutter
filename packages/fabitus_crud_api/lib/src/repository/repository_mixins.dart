import 'package:meta/meta.dart';

import '../core/crud_entity.dart';
import '../error/crud_error_mapper.dart';
import '../error/crud_exception.dart';
import '../error/crud_result.dart';
import 'repository_fragment.dart';

/// Error mapping for a repository that implements only some fragments.
///
/// [BaseCrudRepository] bundles the same [guard] with the full
/// [CrudRepository] contract; this mixin carries it alone, so a repository
/// over a backend with less than full CRUD funnels its calls through an error
/// mapper without promising operations the backend does not have:
///
/// ```dart
/// class ProjectsRepository
///     with GuardedRepository, ExistsViaFindById<Project, String>, DeleteViaDeleteById<Project, String>
///     implements PagingRepository<Project, String> {
///   @override
///   CrudErrorMapper get errorMapper => const DioCrudErrorMapper();
///
///   @override
///   Future<CrudResult<Project>> findById(String id) => guard(() => _api.get(id));
///   // deleteById and findPage in the same shape
/// }
/// ```
mixin GuardedRepository {
  /// Translates thrown objects into [CrudException]s.
  CrudErrorMapper get errorMapper => const DefaultCrudErrorMapper();

  /// Runs [action] and converts anything it throws into a [CrudFailure].
  @protected
  Future<CrudResult<R>> guard<R>(Future<R> Function() action) => guardCrud<R>(action, errorMapper: errorMapper);
}

/// Derives [SaveRepository.save] from [CreateRepository.create] and
/// [UpdateRepository.update]: an entity without an id is created, one with an
/// id is updated.
mixin SaveViaCreateAndUpdate<T extends CrudEntity<ID>, ID extends Object>
    implements CreateRepository<T, ID>, UpdateRepository<T, ID>, SaveRepository<T, ID> {
  @override
  Future<CrudResult<T>> save(T entity) => entity.id == null ? create(entity) : update(entity);
}

/// Derives [DeleteRepository.delete] from [DeleteRepository.deleteById],
/// rejecting an entity that was never persisted.
mixin DeleteViaDeleteById<T extends CrudEntity<ID>, ID extends Object> implements DeleteRepository<T, ID> {
  @override
  Future<CrudResult<void>> delete(T entity) {
    final id = entity.id;
    if (id == null) {
      return Future<CrudResult<void>>.value(
        CrudFailure<void>(CrudValidationException('Cannot operate on a $T without an id'), StackTrace.current),
      );
    }
    return deleteById(id);
  }
}

/// Derives [FindByIdRepository.existsById] from [FindByIdRepository.findById]:
/// a [CrudNotFoundException] means `false`, any other failure stays a failure.
mixin ExistsViaFindById<T extends CrudEntity<ID>, ID extends Object> implements FindByIdRepository<T, ID> {
  @override
  Future<CrudResult<bool>> existsById(ID id) async => switch (await findById(id)) {
    CrudSuccess<T>() => const CrudSuccess<bool>(true),
    CrudFailure<T>(error: CrudNotFoundException()) => const CrudSuccess(false),
    final CrudFailure<T> failure => failure.cast<bool>(),
  };
}
