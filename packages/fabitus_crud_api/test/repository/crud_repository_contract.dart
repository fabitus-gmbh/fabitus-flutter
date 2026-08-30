import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

import '../support/todo.dart';

/// The behaviour every [PagingCrudRepository] in this package must show.
///
/// Running one suite against every implementation is what keeps the local and
/// the remote repository interchangeable from the caller's point of view.
void runCrudRepositoryContract(
  String description,
  PagingCrudRepository<Todo, String> Function() createRepository,
) {
  group('$description (contract)', () {
    late PagingCrudRepository<Todo, String> repository;

    setUp(() => repository = createRepository());

    Future<Todo> create(String title, {int? priority}) async {
      final result = await repository.create(
        Todo(title: title, priority: priority),
      );
      return result.getOrThrow();
    }

    test('create assigns an id and stores the entity', () async {
      final created = await create('Write docs');

      expect(created.id, isNotNull);
      expect(created.title, 'Write docs');
      expect((await repository.findById(created.id!)).getOrThrow(), created);
    });

    test('create keeps an id the caller supplied', () async {
      final created = (await repository.create(
        const Todo(id: 'fixed', title: 'Keep me'),
      )).getOrThrow();

      expect(created.id, 'fixed');
    });

    test('create rejects a duplicate id with a conflict', () async {
      await repository.create(const Todo(id: 'dup', title: 'First'));

      final result = await repository.create(
        const Todo(id: 'dup', title: 'Second'),
      );

      expect(result.errorOrNull, isA<CrudConflictException>());
    });

    test('findById reports not found for an unknown id', () async {
      final result = await repository.findById('missing');

      expect(result.errorOrNull, isA<CrudNotFoundException>());
      expect(result.dataOrNull, isNull);
    });

    test('findAll returns every entity', () async {
      await create('One');
      await create('Two');

      expect((await repository.findAll()).getOrThrow(), hasLength(2));
    });

    test('count reflects the number of entities', () async {
      expect((await repository.count()).getOrThrow(), 0);
      await create('One');
      expect((await repository.count()).getOrThrow(), 1);
    });

    test('existsById distinguishes present from absent', () async {
      final created = await create('One');

      expect((await repository.existsById(created.id!)).getOrThrow(), isTrue);
      expect((await repository.existsById('nope')).getOrThrow(), isFalse);
    });

    test('update overwrites the stored entity', () async {
      final created = await create('Before');

      final updated = (await repository.update(
        created.copyWith(title: 'After'),
      )).getOrThrow();

      expect(updated.title, 'After');
      expect(
        (await repository.findById(created.id!)).getOrThrow().title,
        'After',
      );
    });

    test('update without an id fails validation', () async {
      final result = await repository.update(const Todo(title: 'No id'));

      expect(result.errorOrNull, isA<CrudValidationException>());
    });

    test('update of an unknown id reports not found', () async {
      final result = await repository.update(
        const Todo(id: 'ghost', title: 'Nope'),
      );

      expect(result.errorOrNull, isA<CrudNotFoundException>());
    });

    test('save creates when the id is null and updates otherwise', () async {
      final created = (await repository.save(
        const Todo(title: 'Created'),
      )).getOrThrow();
      expect(created.id, isNotNull);

      final saved = (await repository.save(
        created.copyWith(title: 'Updated'),
      )).getOrThrow();

      expect(saved.title, 'Updated');
      expect((await repository.count()).getOrThrow(), 1);
    });

    test('deleteById removes the entity', () async {
      final created = await create('Delete me');

      expect((await repository.deleteById(created.id!)).isSuccess, isTrue);
      expect((await repository.count()).getOrThrow(), 0);
    });

    test('deleteById of an unknown id reports not found', () async {
      expect(
        (await repository.deleteById('missing')).errorOrNull,
        isA<CrudNotFoundException>(),
      );
    });

    test('delete without an id fails validation', () async {
      final result = await repository.delete(const Todo(title: 'No id'));

      expect(result.errorOrNull, isA<CrudValidationException>());
    });

    test('findPage slices and reports the total', () async {
      for (var i = 0; i < 5; i++) {
        await create('Todo $i', priority: i);
      }

      final page =
          (await repository.findPage(
                const OffsetPageRequest(page: 1, size: 2),
              )).getOrThrow()
              as OffsetPage<Todo>;

      expect(page.content, hasLength(2));
      expect(page.totalElements, 5);
      expect(page.page, 1);
      expect(page.hasNext, isTrue);
      expect(page.totalPages, 3);
    });

    test('findPage sorts by a property, descending', () async {
      await create('a', priority: 1);
      await create('b', priority: 3);
      await create('c', priority: 2);

      final page = (await repository.findPage(
        OffsetPageRequest(
          size: 10,
          sort: Sort.by('priority', SortDirection.desc),
        ),
      )).getOrThrow();

      expect(page.content.map((todo) => todo.title), ['b', 'c', 'a']);
    });

    test('findPage sorts null values last in both directions', () async {
      await create('none');
      await create('low', priority: 1);
      await create('high', priority: 9);

      final ascending = (await repository.findPage(
        OffsetPageRequest(size: 10, sort: Sort.by('priority')),
      )).getOrThrow();
      final descending = (await repository.findPage(
        OffsetPageRequest(
          size: 10,
          sort: Sort.by('priority', SortDirection.desc),
        ),
      )).getOrThrow();

      expect(ascending.content.last.title, 'none');
      expect(descending.content.last.title, 'none');
    });

    test('findPage past the end returns an empty page', () async {
      await create('only');

      final page = (await repository.findPage(
        const OffsetPageRequest(page: 4, size: 10),
      )).getOrThrow();

      expect(page.isEmpty, isTrue);
      expect(page.hasNext, isFalse);
    });

    test('findPage supports cursor requests', () async {
      for (var i = 0; i < 3; i++) {
        await create('Todo $i');
      }

      final first = (await repository.findPage(
        const CursorPageRequest(size: 2),
      )).getOrThrow();
      expect(first.content, hasLength(2));
      expect(first.hasNext, isTrue);

      final second = (await repository.findPage(
        first.nextPageRequest(const CursorPageRequest(size: 2))!,
      )).getOrThrow();

      expect(second.content, hasLength(1));
      expect(second.hasNext, isFalse);
    });
  });
}
