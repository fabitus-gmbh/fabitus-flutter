import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

import '../support/todo.dart';
import 'crud_repository_contract.dart';

void main() {
  runCrudRepositoryContract(
    'InMemoryCrudRepository',
    () => InMemoryCrudRepository<Todo, String>(withId: assignTodoId),
  );

  group('InMemoryCrudRepository', () {
    test('is seeded from initial', () async {
      final repository = InMemoryCrudRepository<Todo, String>(
        withId: assignTodoId,
        initial: const [Todo(id: '1', title: 'Seeded')],
      );

      expect((await repository.findById('1')).getOrThrow().title, 'Seeded');
    });

    test('rejects seeded entities without an id', () {
      expect(
        () => InMemoryCrudRepository<Todo, String>(
          withId: assignTodoId,
          initial: const [Todo(title: 'No id')],
        ),
        throwsArgumentError,
      );
    });

    test('clear removes everything', () async {
      final repository = InMemoryCrudRepository<Todo, String>(
        withId: assignTodoId,
        initial: const [Todo(id: '1', title: 'Seeded')],
      );

      repository.clear();

      expect((await repository.count()).getOrThrow(), 0);
    });

    test('entities is an unmodifiable snapshot', () {
      final repository = InMemoryCrudRepository<Todo, String>(
        withId: assignTodoId,
        initial: const [Todo(id: '1', title: 'Seeded')],
      );

      expect(
        () => repository.entities.add(const Todo(id: '2', title: 'Nope')),
        throwsUnsupportedError,
      );
    });

    test('uses a custom id generator', () async {
      var next = 0;
      final repository = InMemoryCrudRepository<Todo, String>(
        withId: assignTodoId,
        generateId: () => 'id-${next++}',
      );

      final created = (await repository.create(
        const Todo(title: 'One'),
      )).getOrThrow();

      expect(created.id, 'id-0');
    });

    test('requires an explicit generator for non String ids', () {
      expect(
        () => InMemoryCrudRepository<IntKeyed, int>(
          withId: (entity, id) => IntKeyed(id),
        ),
        throwsArgumentError,
      );
    });

    test('uses a custom property accessor for sorting', () async {
      final repository = InMemoryCrudRepository<Todo, String>(
        withId: assignTodoId,
        // Sort by title length instead of by the JSON value.
        propertyAccessor: (todo, property) =>
            property == 'length' ? todo.title.length : todo.toJson()[property],
        initial: const [
          Todo(id: '1', title: 'looooong'),
          Todo(id: '2', title: 'ab'),
        ],
      );

      final page = (await repository.findPage(
        OffsetPageRequest(size: 10, sort: Sort.by('length')),
      )).getOrThrow();

      expect(page.content.first.title, 'ab');
    });

    test('sorting by an incomparable property fails', () async {
      final repository = InMemoryCrudRepository<Todo, String>(
        withId: assignTodoId,
        propertyAccessor: (todo, property) => Object(),
        initial: const [
          Todo(id: '1', title: 'a'),
          Todo(id: '2', title: 'b'),
        ],
      );

      final result = await repository.findPage(
        OffsetPageRequest(size: 10, sort: Sort.by('anything')),
      );

      expect(result.errorOrNull, isA<CrudUnsupportedException>());
    });
  });
}

class IntKeyed implements CrudEntity<int> {
  const IntKeyed(this.id);

  @override
  final int? id;

  @override
  Map<String, dynamic> toJson() => {'id': id};
}
