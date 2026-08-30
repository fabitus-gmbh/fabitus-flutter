import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:logging/logging.dart';
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

      final created = (await service.create(const Todo(title: 'One'))).getOrThrow();
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single, isA<CrudEntityCreated<Todo>>());
      expect((events.single as CrudEntityCreated<Todo>).entity, created);
    });

    test('emits an updated event', () async {
      final created = (await service.create(const Todo(title: 'One'))).getOrThrow();
      final events = <CrudEvent<Todo>>[];
      service.events.listen(events.add);

      await service.update(created.copyWith(title: 'Two'));
      await pumpEventQueue();

      expect(events.single, isA<CrudEntityUpdated<Todo>>());
    });

    test('emits a deleted event with the id', () async {
      final created = (await service.create(const Todo(title: 'One'))).getOrThrow();
      final events = <CrudEvent<Todo>>[];
      service.events.listen(events.add);

      await service.deleteById(created.id!);
      await pumpEventQueue();

      expect((events.single as CrudEntityDeleted<Todo>).id, created.id);
    });

    test('delete(entity) emits the same event as deleteById', () async {
      final created = (await service.create(const Todo(title: 'One'))).getOrThrow();
      final events = <CrudEvent<Todo>>[];
      service.events.listen(events.add);

      await service.delete(created);
      await pumpEventQueue();

      expect(events.single, isA<CrudEntityDeleted<Todo>>());
    });

    test('save routes to create and to update', () async {
      final events = <CrudEvent<Todo>>[];
      service.events.listen(events.add);

      final created = (await service.save(const Todo(title: 'One'))).getOrThrow();
      await service.save(created.copyWith(title: 'Two'));
      await pumpEventQueue();

      expect(events, [isA<CrudEntityCreated<Todo>>(), isA<CrudEntityUpdated<Todo>>()]);
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
      final created = (await delegate.create(const Todo(title: 'One'))).getOrThrow();

      expect((await service.findById(created.id!)).getOrThrow(), created);
      expect((await service.findAll()).getOrThrow(), [created]);
      expect((await service.count()).getOrThrow(), 1);
      expect((await service.existsById(created.id!)).getOrThrow(), isTrue);
    });

    test('dispose closes the stream and silences later writes', () async {
      await service.dispose();

      expect(service.isDisposed, isTrue);
      // Must not throw even though the controller is closed.
      expect((await service.create(const Todo(title: 'One'))).isSuccess, isTrue);
    });

    test('the stream is a broadcast stream', () {
      expect(service.events.isBroadcast, isTrue);
    });
  });

  group('CrudService listeners', () {
    late InMemoryCrudRepository<Todo, String> delegate;
    late _RecordingListener<Todo> recording;

    setUp(() {
      delegate = InMemoryCrudRepository<Todo, String>(withId: assignTodoId);
      recording = _RecordingListener<Todo>();
    });

    test('receive every event, in order', () async {
      final service = CrudService<Todo, String>(delegate, listeners: [recording]);
      addTearDown(service.dispose);

      final created = (await service.create(const Todo(title: 'One'))).getOrThrow();
      await service.update(created.copyWith(title: 'Two'));
      await service.deleteById(created.id!);

      expect(recording.events, [
        isA<CrudEntityCreated<Todo>>(),
        isA<CrudEntityUpdated<Todo>>(),
        isA<CrudEntityDeleted<Todo>>(),
      ]);
    });

    test('are called in the order they were given', () async {
      final calls = <String>[];
      final service = CrudService<Todo, String>(
        delegate,
        listeners: [
          CrudEventListener.fromCallback((_) => calls.add('first')),
          CrudEventListener.fromCallback((_) => calls.add('second')),
        ],
      );
      addTearDown(service.dispose);

      await service.create(const Todo(title: 'One'));

      expect(calls, ['first', 'second']);
    });

    test('see the same events as the stream', () async {
      final service = CrudService<Todo, String>(delegate, listeners: [recording]);
      addTearDown(service.dispose);
      final fromStream = <CrudEvent<Todo>>[];
      service.events.listen(fromStream.add);

      await service.create(const Todo(title: 'One'));
      await pumpEventQueue();

      expect(recording.events, fromStream);
    });

    test('a listener that throws does not fail the operation', () async {
      final service = CrudService<Todo, String>(
        delegate,
        listeners: [CrudEventListener.fromCallback((_) => throw StateError('boom'))],
      );
      addTearDown(service.dispose);

      final result = await service.create(const Todo(title: 'One'));

      expect(result.isSuccess, isTrue);
      expect((await delegate.count()).getOrThrow(), 1);
    });

    test('a listener that throws does not stop the ones behind it', () async {
      final service = CrudService<Todo, String>(
        delegate,
        listeners: [CrudEventListener.fromCallback((_) => throw StateError('boom')), recording],
      );
      addTearDown(service.dispose);

      await service.create(const Todo(title: 'One'));

      expect(recording.events, hasLength(1));
    });

    test('a listener that throws is logged', () async {
      final records = <LogRecord>[];
      final subscription = crudLogger.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final service = CrudService<Todo, String>(
        delegate,
        listeners: [CrudEventListener.fromCallback((_) => throw StateError('boom'))],
      );
      addTearDown(service.dispose);

      await service.create(const Todo(title: 'One'));

      expect(records.single.level, Level.SEVERE);
      expect(records.single.error, isA<StateError>());
    });

    test('are not notified when the operation fails', () async {
      final service = CrudService<Todo, String>(delegate, listeners: [recording]);
      addTearDown(service.dispose);

      await service.update(const Todo(id: 'ghost', title: 'x'));

      expect(recording.events, isEmpty);
    });

    test('are not notified after dispose', () async {
      final service = CrudService<Todo, String>(delegate, listeners: [recording]);

      await service.dispose();
      await service.create(const Todo(title: 'One'));

      expect(recording.events, isEmpty);
    });

    test('the listener list is unmodifiable', () {
      final service = CrudService<Todo, String>(delegate, listeners: [recording]);
      addTearDown(service.dispose);

      expect(() => service.listeners.add(recording), throwsUnsupportedError);
    });

    test('a callback listener adapts a plain function, contravariantly', () async {
      // `EventBus.fire` has this shape: it takes an Object, which makes it a
      // valid listener for the events of any entity type.
      final fired = <Object>[];
      void fire(Object event) => fired.add(event);
      final service = CrudService<Todo, String>(delegate, listeners: [CrudEventListener<Todo>.fromCallback(fire)]);
      addTearDown(service.dispose);

      await service.create(const Todo(title: 'One'));

      expect(fired.single, isA<CrudEntityCreated<Todo>>());
    });

    test('PagingCrudService forwards listeners too', () async {
      final service = PagingCrudService<Todo, String>(delegate, listeners: [recording]);
      addTearDown(service.dispose);

      await service.create(const Todo(title: 'One'));

      expect(recording.events, hasLength(1));
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
      expect(const CrudEvent<Todo>.deleted('1'), const CrudEntityDeleted<Todo>('1'));
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

      final page = (await service.findPage(const OffsetPageRequest(size: 1))).getOrThrow();

      expect(page.content, hasLength(1));
      expect((page as OffsetPage<Todo>).totalElements, 2);
    });
  });
}

class _RecordingListener<T> implements CrudEventListener<T> {
  final List<CrudEvent<T>> events = [];

  @override
  void onCrudEvent(CrudEvent<T> event) => events.add(event);
}
