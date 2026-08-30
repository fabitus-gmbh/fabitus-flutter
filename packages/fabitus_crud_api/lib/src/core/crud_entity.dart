/// A domain object that can be stored and retrieved through a repository.
///
/// The contract mirrors what Spring Data expects from an entity: it is
/// identified by an [id] which is `null` as long as the entity has not been
/// persisted yet, and it knows how to serialise itself to JSON.
///
/// ```dart
/// class Todo implements CrudEntity<String> {
///   const Todo({this.id, required this.title, this.done = false});
///
///   factory Todo.fromJson(Map<String, dynamic> json) => Todo(
///     id: json['id'] as String?,
///     title: json['title'] as String,
///     done: json['done'] as bool? ?? false,
///   );
///
///   @override
///   final String? id;
///   final String title;
///   final bool done;
///
///   @override
///   Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
/// }
/// ```
abstract interface class CrudEntity<ID extends Object> {
  /// The primary key of this entity, or `null` if it has never been persisted.
  ID? get id;

  /// The JSON representation used by remote APIs and local stores.
  Map<String, dynamic> toJson();
}

/// Converts entities of type [T] from and to JSON.
///
/// Local repositories need both directions, so they take a codec instead of
/// relying on [CrudEntity.toJson] alone. Use [EntityCodec.forEntity] when the
/// entity already implements [CrudEntity].
class EntityCodec<T> {
  /// Creates a codec from an explicit pair of conversion functions.
  const EntityCodec({required this.fromJson, required this.toJson});

  /// Creates a codec for a [CrudEntity], reusing its `toJson` implementation.
  static EntityCodec<E> forEntity<E extends CrudEntity<Object>>(
    E Function(Map<String, dynamic> json) fromJson,
  ) => EntityCodec<E>(fromJson: fromJson, toJson: (entity) => entity.toJson());

  /// Reconstructs an entity from its JSON representation.
  final T Function(Map<String, dynamic> json) fromJson;

  /// Serialises an entity to its JSON representation.
  final Map<String, dynamic> Function(T entity) toJson;
}
