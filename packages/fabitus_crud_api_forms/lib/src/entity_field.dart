import 'package:fabitus_crud_api/fabitus_crud_api.dart';

/// Binds one form field to one property of an entity.
///
/// Three things, and nothing visual: what the property is called, how to read it
/// off an entity, and how to put a new value back. The entity stays immutable -
/// [write] returns a new one, which is what a `freezed` `copyWith` does.
///
/// ```dart
/// const title = EntityField<Todo, String>(
///   name: 'title',
///   read: (todo) => todo.title,
///   write: (todo, value) => todo.copyWith(title: value ?? ''),
/// );
/// ```
///
/// [name] is what ties the field to the backend's answer: a
/// [CrudViolation] naming `title` lands on this field and nowhere else. Spell it
/// the way the backend does.
class EntityField<T, V> {
  /// Binds the property called [name].
  const EntityField({required this.name, required this.read, required this.write});

  /// Binds a property that only exists on one variant of a sealed entity.
  ///
  /// A union entity - a page that is either a dossier or an article - has fields
  /// that belong to one variant. Declaring those against the union would mean
  /// casting in every accessor, and a wrong cast throws while the user is
  /// typing. This keeps the cast in one place and makes it total: on the wrong
  /// variant, reading gives `null` and writing leaves the entity alone.
  ///
  /// ```dart
  /// EntityField.ofSubtype<DossierPage, Page, String>(
  ///   name: 'dossierId',
  ///   read: (page) => page.dossierId,
  ///   write: (page, value) => page.copyWith(dossierId: value),
  /// );
  /// ```
  static EntityField<T, V> ofSubtype<S extends T, T, V>({
    required String name,
    required V? Function(S entity) read,
    required S Function(S entity, V? value) write,
  }) => EntityField<T, V>(
    name: name,
    read: (entity) => entity is S ? read(entity) : null,
    write: (entity, value) => entity is S ? write(entity, value) : entity,
  );

  /// The property name, as the backend spells it in a [CrudViolation].
  final String name;

  /// Reads the current value off an entity.
  final V? Function(T entity) read;

  /// Returns a copy of [entity] carrying [value].
  final T Function(T entity, V? value) write;

  @override
  String toString() => 'EntityField<$T, $V>($name)';
}
