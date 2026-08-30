import '../core/crud_entity.dart';
import '../core/id_generator.dart';
import '../error/crud_exception.dart';
import '../error/crud_result.dart';
import '../paging/page.dart';
import '../paging/page_request.dart';
import 'collection_query.dart';
import 'crud_repository.dart';

/// A [PagingCrudRepository] that keeps everything in a map.
///
/// Useful as a fake in widget and bloc tests, and as a stand in while a backend
/// is still being built. Entities are stored in insertion order; sorting reads
/// the properties from [CrudEntity.toJson] unless a [propertyAccessor] is given.
///
/// ```dart
/// final repository = InMemoryCrudRepository<Todo, String>(
///   withId: (todo, id) => todo.copyWith(id: id),
///   initial: [const Todo(id: '1', title: 'Write docs')],
/// );
/// ```
class InMemoryCrudRepository<T extends CrudEntity<ID>, ID extends Object> extends BaseCrudRepository<T, ID>
    implements PagingCrudRepository<T, ID> {
  /// Creates a repository seeded with [initial].
  ///
  /// [withId] returns a copy of an entity carrying the given id; it is called
  /// on [create] with the value produced by [generateId]. [generateId] defaults
  /// to [randomStringId] and may only be omitted when [ID] is [String].
  InMemoryCrudRepository({
    required this.withId,
    IdGenerator<ID>? generateId,
    PropertyAccessor<T>? propertyAccessor,
    Iterable<T> initial = const [],
    super.errorMapper,
  }) : generateId = generateId ?? defaultIdGenerator<ID>(),
       propertyAccessor = propertyAccessor ?? jsonPropertyAccessor<T>() {
    for (final entity in initial) {
      final id = entity.id;
      if (id == null) {
        throw ArgumentError.value(entity, 'initial', 'Seeded entities must already have an id');
      }
      _entities[id] = entity;
    }
  }

  final Map<ID, T> _entities = <ID, T>{};

  /// Returns a copy of [T] carrying the given id.
  final T Function(T entity, ID id) withId;

  /// Produces ids for entities created through this repository.
  final IdGenerator<ID> generateId;

  /// Reads a sortable property from an entity.
  final PropertyAccessor<T> propertyAccessor;

  /// The stored entities in insertion order.
  List<T> get entities => List<T>.unmodifiable(_entities.values);

  /// Removes every stored entity.
  void clear() => _entities.clear();

  @override
  Future<CrudResult<T>> findById(ID id) async {
    final entity = _entities[id];
    if (entity == null) {
      return CrudFailure<T>(CrudNotFoundException('No $T with id $id'), StackTrace.current);
    }
    return CrudSuccess<T>(entity);
  }

  @override
  Future<CrudResult<List<T>>> findAll() async => CrudSuccess<List<T>>(entities);

  @override
  Future<CrudResult<int>> count() async => CrudSuccess<int>(_entities.length);

  @override
  Future<CrudResult<T>> create(T entity) => guard(() async {
    final id = entity.id ?? generateId();
    if (_entities.containsKey(id)) {
      throw CrudConflictException('A $T with id $id already exists');
    }
    final created = withId(entity, id);
    _entities[id] = created;
    return created;
  });

  @override
  Future<CrudResult<T>> update(T entity) => guard(() async {
    final id = entity.id;
    if (id == null) {
      throw CrudValidationException('Cannot update a $T without an id');
    }
    if (!_entities.containsKey(id)) {
      throw CrudNotFoundException('No $T with id $id');
    }
    _entities[id] = entity;
    return entity;
  });

  @override
  Future<CrudResult<void>> deleteById(ID id) => guard(() async {
    if (_entities.remove(id) == null) {
      throw CrudNotFoundException('No $T with id $id');
    }
  });

  @override
  Future<CrudResult<Page<T>>> findPage(PageRequest pageRequest) => guard(() async {
    final sorted = sortEntities(_entities.values.toList(growable: false), pageRequest.sort, propertyAccessor);
    return pageOf(sorted, pageRequest);
  });
}
