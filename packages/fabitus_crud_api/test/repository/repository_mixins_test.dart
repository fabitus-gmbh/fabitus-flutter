import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

import '../support/todo.dart';

/// Records what it was handed and maps everything to one marker exception.
class RecordingErrorMapper implements CrudErrorMapper {
  final List<Object> mapped = [];

  @override
  CrudException map(Object error, StackTrace stackTrace) {
    mapped.add(error);
    return CrudServerException('mapped: $error');
  }
}

/// A repository over a backend that can only read one todo and delete one -
/// the partial shape the fragments and mixins exist for.
class PartialTodoRepository with GuardedRepository, ExistsViaFindById<Todo, String>, DeleteViaDeleteById<Todo, String> {
  PartialTodoRepository(this.todos, {RecordingErrorMapper? mapper}) : _mapper = mapper;

  final Map<String, Todo> todos;
  final RecordingErrorMapper? _mapper;

  /// The next call throws this instead of doing its work.
  Object? nextError;

  @override
  CrudErrorMapper get errorMapper => _mapper ?? const DefaultCrudErrorMapper();

  @override
  Future<CrudResult<Todo>> findById(String id) => guard(() async {
    _throwPending();
    final todo = todos[id];
    if (todo == null) throw CrudNotFoundException('No Todo with id $id');
    return todo;
  });

  @override
  Future<CrudResult<void>> deleteById(String id) => guard(() async {
    _throwPending();
    if (todos.remove(id) == null) throw CrudNotFoundException('No Todo with id $id');
  });

  void _throwPending() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }
}

/// Nothing overridden, so the mixin's own default error mapper is in effect.
/// `guard` is protected, hence the forwarding method.
class BareGuardedRepository with GuardedRepository {
  Future<CrudResult<R>> run<R>(Future<R> Function() action) => guard(action);
}

/// Create and update recorded, save derived by the mixin under test.
class SavingTodoRepository with SaveViaCreateAndUpdate<Todo, String> {
  final List<String> calls = [];

  @override
  Future<CrudResult<Todo>> create(Todo entity) async {
    calls.add('create');
    return CrudSuccess<Todo>(entity.copyWith(id: 'assigned'));
  }

  @override
  Future<CrudResult<Todo>> update(Todo entity) async {
    calls.add('update');
    return CrudSuccess<Todo>(entity);
  }
}

void main() {
  group('GuardedRepository', () {
    test('funnels what the action throws through the error mapper', () async {
      final mapper = RecordingErrorMapper();
      final repository = PartialTodoRepository({}, mapper: mapper)..nextError = StateError('backend down');

      final result = await repository.findById('1');

      expect(mapper.mapped.single, isA<StateError>());
      expect(result.errorOrNull, isA<CrudServerException>());
    });

    test('passes successes through untouched', () async {
      final repository = PartialTodoRepository({'1': const Todo(id: '1', title: 'Keep')});

      expect((await repository.findById('1')).getOrThrow().title, 'Keep');
    });

    test('defaults to the DefaultCrudErrorMapper', () async {
      final result = await BareGuardedRepository().run<void>(() async => throw StateError('boom'));

      expect(result.errorOrNull, isA<CrudUnknownException>());
    });

    test('the default mapper passes a thrown CrudException through unchanged', () async {
      final thrown = CrudConflictException('taken');

      final result = await BareGuardedRepository().run<void>(() async => throw thrown);

      expect(result.errorOrNull, same(thrown));
    });
  });

  group('ExistsViaFindById', () {
    test('answers true when findById succeeds', () async {
      final repository = PartialTodoRepository({'1': const Todo(id: '1', title: 'There')});

      expect((await repository.existsById('1')).getOrThrow(), isTrue);
    });

    test('answers false when findById reports not found', () async {
      final repository = PartialTodoRepository({});

      expect((await repository.existsById('1')).getOrThrow(), isFalse);
    });

    test('keeps any other failure a failure', () async {
      final repository = PartialTodoRepository({})..nextError = CrudTimeoutException('slow');

      expect((await repository.existsById('1')).errorOrNull, isA<CrudTimeoutException>());
    });
  });

  group('DeleteViaDeleteById', () {
    test('delegates to deleteById', () async {
      final repository = PartialTodoRepository({'1': const Todo(id: '1', title: 'Gone soon')});

      expect((await repository.delete(const Todo(id: '1', title: 'Gone soon'))).isSuccess, isTrue);
      expect(repository.todos, isEmpty);
    });

    test('rejects an entity without an id', () async {
      final repository = PartialTodoRepository({});

      final result = await repository.delete(const Todo(title: 'Never stored'));

      expect(result.errorOrNull, isA<CrudValidationException>());
    });
  });

  group('SaveViaCreateAndUpdate', () {
    test('creates an entity without an id', () async {
      final repository = SavingTodoRepository();

      final result = await repository.save(const Todo(title: 'New'));

      expect(repository.calls, ['create']);
      expect(result.getOrThrow().id, 'assigned');
    });

    test('updates an entity with an id', () async {
      final repository = SavingTodoRepository();

      await repository.save(const Todo(id: '1', title: 'Known'));

      expect(repository.calls, ['update']);
    });
  });

  group('fragment composition', () {
    test('a CrudRepository is every fragment it is composed of', () {
      final repository = InMemoryCrudRepository<Todo, String>(withId: assignTodoId);

      expect(repository, isA<FindByIdRepository<Todo, String>>());
      expect(repository, isA<ListRepository<Todo, String>>());
      expect(repository, isA<CreateRepository<Todo, String>>());
      expect(repository, isA<UpdateRepository<Todo, String>>());
      expect(repository, isA<SaveRepository<Todo, String>>());
      expect(repository, isA<DeleteRepository<Todo, String>>());
      expect(repository, isA<EntityRepository<Todo, String>>());
      expect(repository, isA<PagingRepository<Todo, String>>());
    });

    test('a partial repository is only what it implements', () {
      final repository = PartialTodoRepository({});

      expect(repository, isA<FindByIdRepository<Todo, String>>());
      expect(repository, isA<DeleteRepository<Todo, String>>());
      expect(repository, isNot(isA<CrudRepository<Todo, String>>()));
      expect(repository, isNot(isA<SaveRepository<Todo, String>>()));
    });
  });
}
