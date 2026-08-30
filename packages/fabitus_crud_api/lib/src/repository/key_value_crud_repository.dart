import 'dart:convert';

import 'package:collection/collection.dart';

import '../core/crud_entity.dart';
import '../core/id_generator.dart';
import '../error/crud_exception.dart';
import '../error/crud_result.dart';
import '../paging/page.dart';
import '../paging/page_request.dart';
import 'collection_query.dart';
import 'crud_repository.dart';
import 'key_value_store.dart';

/// A [PagingCrudRepository] that persists a whole collection as one JSON
/// document in a [KeyValueStore].
///
/// This is the local storage implementation: point it at a `shared_preferences`
/// or browser `localStorage` adapter and the collection survives a restart.
///
/// ```dart
/// final repository = KeyValueCrudRepository<Todo, String>(
///   store: SharedPreferencesKeyValueStore(prefs),
///   storageKey: 'todos',
///   codec: EntityCodec.forEntity(Todo.fromJson),
///   withId: (todo, id) => todo.copyWith(id: id),
/// );
/// ```
///
/// Every operation rewrites the full document, which keeps writes atomic and
/// the implementation simple. That is the right trade for the hundreds of
/// entities a device holds; for larger sets use a database instead.
class KeyValueCrudRepository<T extends CrudEntity<ID>, ID extends Object> extends BaseCrudRepository<T, ID>
    implements PagingCrudRepository<T, ID> {
  /// Creates a repository storing its collection under [storageKey].
  ///
  /// [generateId] defaults to [randomStringId] and may only be omitted when
  /// [ID] is [String].
  KeyValueCrudRepository({
    required this.store,
    required this.storageKey,
    required this.codec,
    required this.withId,
    IdGenerator<ID>? generateId,
    PropertyAccessor<T>? propertyAccessor,
    super.errorMapper,
  }) : generateId = generateId ?? defaultIdGenerator<ID>(),
       propertyAccessor = propertyAccessor ?? jsonPropertyAccessor<T>();

  /// Where the collection is persisted.
  final KeyValueStore store;

  /// The key the collection is stored under.
  final String storageKey;

  /// Converts entities from and to JSON.
  final EntityCodec<T> codec;

  /// Returns a copy of [T] carrying the given id.
  final T Function(T entity, ID id) withId;

  /// Produces ids for entities created through this repository.
  final IdGenerator<ID> generateId;

  /// Reads a sortable property from an entity.
  final PropertyAccessor<T> propertyAccessor;

  @override
  Future<CrudResult<T>> findById(ID id) => guard(() async {
    final entities = await _readAll();
    final match = entities.where((entity) => entity.id == id).firstOrNull;
    if (match == null) {
      throw CrudNotFoundException('No $T with id $id');
    }
    return match;
  });

  @override
  Future<CrudResult<List<T>>> findAll() => guard(_readAll);

  @override
  Future<CrudResult<int>> count() => guard(() async => (await _readAll()).length);

  @override
  Future<CrudResult<T>> create(T entity) => guard(() async {
    final entities = await _readAll();
    final id = entity.id ?? generateId();
    if (entities.any((stored) => stored.id == id)) {
      throw CrudConflictException('A $T with id $id already exists');
    }
    final created = withId(entity, id);
    await _writeAll([...entities, created]);
    return created;
  });

  @override
  Future<CrudResult<T>> update(T entity) => guard(() async {
    final id = entity.id;
    if (id == null) {
      throw CrudValidationException('Cannot update a $T without an id');
    }
    final entities = await _readAll();
    final index = entities.indexWhere((stored) => stored.id == id);
    if (index < 0) {
      throw CrudNotFoundException('No $T with id $id');
    }
    await _writeAll([...entities]..[index] = entity);
    return entity;
  });

  @override
  Future<CrudResult<void>> deleteById(ID id) => guard(() async {
    final entities = await _readAll();
    final remaining = entities.where((entity) => entity.id != id).toList(growable: false);
    if (remaining.length == entities.length) {
      throw CrudNotFoundException('No $T with id $id');
    }
    await _writeAll(remaining);
  });

  @override
  Future<CrudResult<Page<T>>> findPage(PageRequest pageRequest) => guard(() async {
    final sorted = sortEntities(await _readAll(), pageRequest.sort, propertyAccessor);
    return pageOf(sorted, pageRequest);
  });

  /// Removes the whole collection from the store.
  Future<CrudResult<void>> clear() => guard(() => store.remove(storageKey));

  Future<List<T>> _readAll() async {
    final raw = await store.read(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw CrudSerializationException('Stored value under "$storageKey" is not valid JSON', cause: error);
    }
    if (decoded is! List) {
      throw CrudSerializationException('Stored value under "$storageKey" is not a JSON array');
    }
    return decoded.whereType<Map<String, dynamic>>().map(codec.fromJson).toList(growable: false);
  }

  Future<void> _writeAll(List<T> entities) =>
      store.write(storageKey, jsonEncode(entities.map(codec.toJson).toList(growable: false)));
}
