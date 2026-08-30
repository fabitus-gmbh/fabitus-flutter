import 'dart:async';

import '../core/crud_entity.dart';
import '../error/crud_result.dart';
import '../paging/page.dart';
import '../paging/page_request.dart';
import '../repository/crud_repository.dart';
import 'crud_event.dart';

/// A [CrudRepository] that announces every successful write on [events].
///
/// Register one instance per entity type in your service locator and let every
/// screen depend on it; a list can then refresh itself when a detail screen
/// saves, without the two knowing about each other.
///
/// ```dart
/// getIt.registerLazySingleton<CrudService<Todo, String>>(
///   () => CrudService(TodoRepository(getIt())),
///   dispose: (service) => service.dispose(),
/// );
/// ```
///
/// Failed operations emit nothing - the caller still gets the [CrudFailure].
class CrudService<T extends CrudEntity<ID>, ID extends Object> implements CrudRepository<T, ID> {
  /// Wraps [delegate] and publishes its writes.
  CrudService(this.delegate);

  /// The repository that does the actual work.
  final CrudRepository<T, ID> delegate;

  final StreamController<CrudEvent<T>> _events = StreamController<CrudEvent<T>>.broadcast();

  /// Writes performed through this service, in the order they succeeded.
  ///
  /// The stream is a broadcast stream, so late listeners miss earlier events.
  Stream<CrudEvent<T>> get events => _events.stream;

  /// Whether [dispose] has been called.
  bool get isDisposed => _events.isClosed;

  /// Closes [events]. Call this when the service is no longer needed.
  Future<void> dispose() => _events.close();

  /// Publishes [event] to [events] unless the service is already disposed.
  void _emit(CrudEvent<T> event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Future<CrudResult<T>> findById(ID id) => delegate.findById(id);

  @override
  Future<CrudResult<List<T>>> findAll() => delegate.findAll();

  @override
  Future<CrudResult<bool>> existsById(ID id) => delegate.existsById(id);

  @override
  Future<CrudResult<int>> count() => delegate.count();

  @override
  Future<CrudResult<T>> create(T entity) async {
    final result = await delegate.create(entity);
    if (result case CrudSuccess<T>(:final data)) {
      _emit(CrudEntityCreated<T>(data));
    }
    return result;
  }

  @override
  Future<CrudResult<T>> update(T entity) async {
    final result = await delegate.update(entity);
    if (result case CrudSuccess<T>(:final data)) {
      _emit(CrudEntityUpdated<T>(data));
    }
    return result;
  }

  @override
  Future<CrudResult<T>> save(T entity) => entity.id == null ? create(entity) : update(entity);

  @override
  Future<CrudResult<void>> deleteById(ID id) async {
    final result = await delegate.deleteById(id);
    if (result.isSuccess) _emit(CrudEntityDeleted<T>(id));
    return result;
  }

  @override
  Future<CrudResult<void>> delete(T entity) {
    final id = entity.id;
    // Fall through to the delegate so it produces the "missing id" failure.
    return id == null ? delegate.delete(entity) : deleteById(id);
  }
}

/// A [CrudService] for a [PagingCrudRepository].
class PagingCrudService<T extends CrudEntity<ID>, ID extends Object> extends CrudService<T, ID>
    implements PagingCrudRepository<T, ID> {
  /// Wraps [delegate] and publishes its writes.
  PagingCrudService(PagingCrudRepository<T, ID> super.delegate);

  @override
  Future<CrudResult<Page<T>>> findPage(PageRequest pageRequest) =>
      (delegate as PagingCrudRepository<T, ID>).findPage(pageRequest);
}
