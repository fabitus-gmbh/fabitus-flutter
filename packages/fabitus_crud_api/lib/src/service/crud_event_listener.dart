import '../core/logging.dart';
import 'crud_event.dart';

/// Receives the events a `CrudService` publishes.
///
/// A service always exposes its own broadcast stream, which is enough when the
/// listener lives in the same part of the app. A [CrudEventListener] is for the
/// other case: handing the events to something that already exists, such as an
/// application wide event bus, an analytics client or a cache, at the point
/// where the service is constructed.
///
/// ```dart
/// CrudService(
///   repository,
///   listeners: [
///     CrudEventListener.fromCallback(eventBus.fire),
///     AnalyticsCrudEventListener(analytics),
///   ],
/// );
/// ```
///
/// Listeners are called synchronously, in the order they were given, after the
/// write has already succeeded. A listener that throws is logged to
/// [crudLogger] and skipped: it can never turn a successful write into a
/// failure, and it can never stop the listeners behind it.
abstract interface class CrudEventListener<T> {
  /// Adapts a plain callback, which is all an event bus needs:
  ///
  /// ```dart
  /// CrudEventListener<Todo>.fromCallback(eventBus.fire)
  /// ```
  ///
  /// `EventBus.fire` takes an `Object`, and a `void Function(Object)` is a
  /// valid `void Function(CrudEvent<Todo>)`, so the tear-off fits as is - one
  /// bus can serve the services of every entity type.
  factory CrudEventListener.fromCallback(void Function(CrudEvent<T> event) onEvent) = _CallbackCrudEventListener<T>;

  /// Handles [event]. Called after the write it describes has succeeded.
  void onCrudEvent(CrudEvent<T> event);
}

class _CallbackCrudEventListener<T> implements CrudEventListener<T> {
  const _CallbackCrudEventListener(this._onEvent);

  final void Function(CrudEvent<T> event) _onEvent;

  @override
  void onCrudEvent(CrudEvent<T> event) => _onEvent(event);
}
