import 'dart:async';

import '../core/logging.dart';
import 'crud_event.dart';
import 'crud_event_listener.dart';

/// Publishes [CrudEvent]s to a broadcast stream and to listeners.
///
/// This is the publishing half of `CrudService` as a type of its own, for
/// every write a service cannot see:
///
/// * a repository built from the fragment interfaces, which offers too little
///   of `CrudRepository` to be wrapped in a `CrudService`;
/// * a write that is no repository call at all - an upload against presigned
///   URLs, say, that ends in a new entity.
///
/// Whoever performs the write announces it; lists read [events] - directly,
/// or through `CrudPaginationProvider.refreshOn` - and reread themselves:
///
/// ```dart
/// final fileEvents = CrudEventHub<FileItem>();
///
/// // Where the upload completes:
/// fileEvents.announce(CrudEvent.created(file));
///
/// // Where the list lives:
/// CrudPaginationProvider<FileItem, String>(
///   refreshOn: fileEvents.events,
///   // ...
/// );
/// ```
///
/// `CrudService` publishes through a hub of its own, so a full repository
/// needs no extra wiring. Announcing is fire and forget: a listener that
/// throws is logged and skipped, and an announcement after [dispose] is
/// dropped.
class CrudEventHub<T> {
  /// Creates a hub pushing every event to [listeners] as well.
  CrudEventHub({Iterable<CrudEventListener<T>> listeners = const []})
    : listeners = List<CrudEventListener<T>>.unmodifiable(listeners);

  /// The listeners every event is pushed to, in order.
  ///
  /// Fixed for the lifetime of the hub; to attach and detach at runtime,
  /// listen to [events] instead and cancel the subscription.
  final List<CrudEventListener<T>> listeners;

  final StreamController<CrudEvent<T>> _events = StreamController<CrudEvent<T>>.broadcast();

  /// The announced events, in order.
  ///
  /// A broadcast stream, so late listeners miss earlier events.
  Stream<CrudEvent<T>> get events => _events.stream;

  /// Whether [dispose] has been called.
  bool get isDisposed => _events.isClosed;

  /// Stops publishing and closes [events]. Call this when the hub is no
  /// longer needed.
  Future<void> dispose() => _events.close();

  /// Publishes [event] to [events] and to every entry of [listeners].
  ///
  /// A listener that throws is logged and skipped: the write it describes has
  /// already succeeded, so a broken listener must not fail the operation, and
  /// it must not keep the remaining listeners from being told.
  void announce(CrudEvent<T> event) {
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
}
