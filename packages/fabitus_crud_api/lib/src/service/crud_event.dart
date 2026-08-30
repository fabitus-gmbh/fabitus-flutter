import 'package:freezed_annotation/freezed_annotation.dart';

part 'crud_event.freezed.dart';

/// Something a `CrudService` did to an entity.
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
@freezed
sealed class CrudEvent<T> with _$CrudEvent<T> {
  /// An entity was created.
  const factory CrudEvent.created(
    /// The entity as it was stored, including the assigned id.
    T entity,
  ) = CrudEntityCreated<T>;

  /// An entity was updated.
  const factory CrudEvent.updated(
    /// The entity as it was stored.
    T entity,
  ) = CrudEntityUpdated<T>;

  /// An entity was deleted.
  const factory CrudEvent.deleted(
    /// The id of the entity that no longer exists.
    Object id,
  ) = CrudEntityDeleted<T>;
}
