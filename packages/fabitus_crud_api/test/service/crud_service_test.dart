import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

import '../support/todo.dart';

void main() {
  group('CrudService', () {
    late InMemoryCrudRepository<Todo, String> delegate;
    late CrudService<Todo, String> service;

    setUp(() {
      delegate = InMemoryCrudRepository<Todo, String>(withId: assignTodoId);
      service = CrudService<Todo, String>(delegate);
    });

    tearDown(() => service.dispose());

    test('emits a created event carrying the stored entity', () async {
      final events = <CrudEvent<Todo>>[];
      service.events.listen(events.add);

      final created = (await service.create(
        const Todo(title: 'One'),
      )).getOrThrow();
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single, isA<CrudEntityCreated<Todo>>());
      expect((events.single as CrudEntityCreated<Todo>).entity, created);
    });

    test('emits an updated event', () async {
      final created = (await service.create(
        const Todo(title: 'One'),
      )).getOrThrow();
      final events = <CrudEvent<Todo>>[];
      service.events.listen(events.add);

      await service.update(created.copyWith(title: 'Two'));
      await pumpEventQueue();

      expect(events.single, isA<CrudEntityUpdated<Todo>>());
    });

    test('emits a deleted event with the id', () async {
      final created = (await service.create(
        const Todo(title: 'One'),
      )).getOrThrow();
      final events = <CrudEvent<Todo>>[];
      service.events.listen(events.add);

      await service.deleteById(created.id!);
      await pumpEventQueue();

      expect((events.single as CrudEntityDeleted<Todo>).id, created.id);
    });

    test('delete(entity) emits the same event as deleteById', () async {
      final created = (await service.create(
        const Todo(title: 'One'),
      )).getOrThrow();
      final events = <CrudEvent<Todo>>[];
      service.events.listen(events.add);

      await service.delete(created);
      await pumpEventQueue();

      expect(events.single, isA<CrudEntityDeleted<Todo>>());
    });

    test('save routes to create and to update', () async {
      final events = <CrudEvent<Todo>>[];
      service.events.listen(events.add);

      final created = (await service.save(
        const Todo(title: 'One'),
      )).getOrThrow();
      await service.save(created.copyWith(title: 'Two'));
      await pumpEventQueue();

      expect(events, [
        isA<CrudEntityCreated<Todo>>(),
        isA<CrudEntityUpdated<Todo>>(),
      ]);
    });

    test('emits nothing when the operation fails', () async {
      final events = <CrudEvent<Todo>>[];
      service.events.listen(events.add);

      final result = await service.update(const Todo(id: 'ghost', title: 'x'));
      await service.delete(const Todo(title: 'no id'));
      await pumpEventQueue();

      expect(result.isFailure, isTrue);
      expect(events, isEmpty);
    });

    test('forwards read operations to the delegate', () async {
      final created = (await delegate.create(
        const Todo(title: 'One'),
      )).getOrThrow();

      expect((await service.findById(created.id!)).getOrThrow(), created);
      expect((await service.findAll()).getOrThrow(), [created]);
      expect((await service.count()).getOrThrow(), 1);
      expect((await service.existsById(created.id!)).getOrThrow(), isTrue);
    });

    test('dispose closes the stream and silences later writes', () async {
      await service.dispose();

      expect(service.isDisposed, isTrue);
      // Must not throw even though the controller is closed.
      expect(
        (await service.create(const Todo(title: 'One'))).isSuccess,
        isTrue,
      );
    });

    test('the stream is a broadcast stream', () {
      expect(service.events.isBroadcast, isTrue);
    });
  });

  group('CrudEvent', () {
    test('equality is by value', () {
      expect(
        const CrudEntityCreated<Todo>(Todo(id: '1', title: 'One')),
        const CrudEntityCreated<Todo>(Todo(id: '1', title: 'One')),
      );
      expect(
        const CrudEntityCreated<Todo>(Todo(id: '1', title: 'One')),
        isNot(const CrudEntityUpdated<Todo>(Todo(id: '1', title: 'One'))),
      );
    });

    test('the union constructors and the variant classes agree', () {
      expect(
        const CrudEvent<Todo>.deleted('1'),
        const CrudEntityDeleted<Todo>('1'),
      );
    });
  });

  group('PagingCrudService', () {
    test('forwards findPage to the delegate', () async {
      final service = PagingCrudService<Todo, String>(
        InMemoryCrudRepository<Todo, String>(
          withId: assignTodoId,
          initial: const [
            Todo(id: '1', title: 'One'),
            Todo(id: '2', title: 'Two'),
          ],
        ),
      );
      addTearDown(service.dispose);

      final page = (await service.findPage(
        const OffsetPageRequest(size: 1),
      )).getOrThrow();

      expect(page.content, hasLength(1));
      expect((page as OffsetPage<Todo>).totalElements, 2);
    });
  });
}
