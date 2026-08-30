import 'dart:async';

import '../core/crud_entity.dart';
import '../core/logging.dart';
import '../error/crud_result.dart';
import '../paging/page.dart';
import '../paging/page_request.dart';
import '../repository/crud_repository.dart';
import 'crud_event.dart';
import 'crud_event_listener.dart';

/// A [CrudRepository] that announces every successful write.
///
/// There are two ways to receive those announcements, and they work together:
///
/// * [events] is a broadcast stream, for listeners that live near the service.
/// * [listeners] are [CrudEventListener]s handed in at construction, for
///   forwarding the events to something that already exists - an application
///   wide event bus, analytics, a cache.
///
/// Register one instance per entity type in your service locator and let every
/// screen depend on it; a list can then refresh itself when a detail screen
/// saves, without the two knowing about each other.
///
/// ```dart
/// getIt.registerLazySingleton<CrudService<Todo, String>>(
///   () => CrudService(
///     TodoRepository(getIt()),
///     listeners: [CrudEventListener.fromCallback(getIt<EventBus>().fire)],
///   ),
///   dispose: (service) => service.dispose(),
/// );
/// ```
///
/// Failed operations announce nothing - the caller still gets the
/// [CrudFailure].
class CrudService<T extends CrudEntity<ID>, ID extends Object> implements CrudRepository<T, ID> {
  /// Wraps [delegate] and publishes its writes to [events] and to [listeners].
  CrudService(this.delegate, {Iterable<CrudEventListener<T>> listeners = const []})
    : listeners = List<CrudEventListener<T>>.unmodifiable(listeners);

  /// The repository that does the actual work.
  final CrudRepository<T, ID> delegate;

  /// The listeners this service pushes every event to, in order.
  ///
  /// Fixed for the lifetime of the service; to attach and detach at runtime,
  /// listen to [events] instead and cancel the subscription.
  final List<CrudEventListener<T>> listeners;

  final StreamController<CrudEvent<T>> _events = StreamController<CrudEvent<T>>.broadcast();

  /// Writes performed through this service, in the order they succeeded.
  ///
  /// The stream is a broadcast stream, so late listeners miss earlier events.
  Stream<CrudEvent<T>> get events => _events.stream;

  /// Whether [dispose] has been called.
  bool get isDisposed => _events.isClosed;

  /// Stops publishing and closes [events]. Call this when the service is no
  /// longer needed.
  ///
  /// Writes still work afterwards, they are simply no longer announced.
  Future<void> dispose() => _events.close();

  /// Publishes [event] to [events] and to every entry of [listeners].
  ///
  /// A listener that throws is logged and skipped: the write it describes has
  /// already succeeded, so a broken listener must not fail the operation, and
  /// it must not keep the remaining listeners from being told.
  void _emit(CrudEvent<T> event) {
    if (isDisposed) return;
    _events.add(event);
    for (final listener in listeners) {
      try {
        listener.onCrudEvent(event);
      } catch (error, stackTrace) {
        crudLogger.severe('${listener.runtimeType} failed to handle $event', error, stackTrace);
      }
    }
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
  /// Wraps [delegate] and publishes its writes to [events] and to [listeners].
  PagingCrudService(PagingCrudRepository<T, ID> super.delegate, {super.listeners});

  @override
  Future<CrudResult<Page<T>>> findPage(PageRequest pageRequest) =>
      (delegate as PagingCrudRepository<T, ID>).findPage(pageRequest);
}
