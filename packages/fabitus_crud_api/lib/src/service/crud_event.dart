/// Something a [CrudService] did to an entity.
///
/// Listen to the stream to keep lists, caches and other screens in sync without
/// coupling them to the screen that performed the change:
///
/// ```dart
/// service.events.listen((event) {
///   switch (event) {
///     case CrudEntityCreated(:final entity):
///     case CrudEntityUpdated(:final entity):
///       _upsert(entity);
///     case CrudEntityDeleted(:final id):
///       _removeById(id);
///   }
/// });
/// ```
sealed class CrudEvent<T> {
  /// Creates an event.
  const CrudEvent();
}

/// An entity was created.
final class CrudEntityCreated<T> extends CrudEvent<T> {
  /// Creates a created event for [entity].
  const CrudEntityCreated(this.entity);

  /// The entity as it was stored, including the assigned id.
  final T entity;

  @override
  String toString() => 'CrudEntityCreated<$T>($entity)';
}

/// An entity was updated.
final class CrudEntityUpdated<T> extends CrudEvent<T> {
  /// Creates an updated event for [entity].
  const CrudEntityUpdated(this.entity);

  /// The entity as it was stored.
  final T entity;

  @override
  String toString() => 'CrudEntityUpdated<$T>($entity)';
}

/// An entity was deleted.
final class CrudEntityDeleted<T> extends CrudEvent<T> {
  /// Creates a deleted event for the entity with [id].
  const CrudEntityDeleted(this.id);

  /// The id of the entity that no longer exists.
  final Object id;

  @override
  String toString() => 'CrudEntityDeleted<$T>($id)';
}
