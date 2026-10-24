import 'dart:async';

import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/todo.dart';

void main() {
  late FlakyTodoRepository repository;

  PaginationCubit<Todo, void> build({int total = 5, int size = 2, bool cursor = false}) {
    repository = FlakyTodoRepository(seededRepository(total));
    final cubit = PaginationCubit<Todo, void>(
      loadPage: (request, _) => repository.findPage(request),
      initialRequest: cursor ? CursorPageRequest(size: size) : OffsetPageRequest(size: size),
      initialFilter: null,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('loading', () {
    test('starts empty and loads nothing on its own', () {
      final cubit = build();

      expect(cubit.state.status, PaginationStatus.initial);
      expect(cubit.state.pages, isEmpty);
      expect(repository.calls, isEmpty);
    });

    test('loadOnCreate is observable from the initial state', () async {
      final repo = seededRepository(3);
      final cubit = PaginationCubit<Todo, void>(
        loadPage: (request, _) => repo.findPage(request),
        initialRequest: OffsetPageRequest(size: 2),
        initialFilter: null,
        loadOnCreate: true,
      );
      addTearDown(cubit.close);

      expect(cubit.state.status, PaginationStatus.initial);
      await expectLater(
        cubit.stream.map((state) => state.status),
        emitsInOrder([PaginationStatus.loading, PaginationStatus.success]),
      );
    });

    test('the first page holds the first slice and the total', () async {
      final cubit = build();

      await cubit.loadFirstPage();

      expect(cubit.state.items.map((todo) => todo.id), ['0', '1']);
      expect(cubit.state.totalElements, 5);
      expect(cubit.state.hasNext, isTrue);
      expect(cubit.state.hasPrevious, isFalse);
      expect(cubit.state.status.isSuccess, isTrue);
    });

    test('a failure is reported and keeps the cubit usable', () async {
      final cubit = build();
      repository.nextError = const CrudServerException('down', statusCode: 503);

      await cubit.loadFirstPage();

      expect(cubit.state.status.isFailure, isTrue);
      expect(cubit.state.error, isA<CrudServerException>());

      await cubit.loadFirstPage();

      expect(cubit.state.status.isSuccess, isTrue);
      expect(cubit.state.error, isNull);
    });
  });

  group('navigation', () {
    test('nextPage appends and moves on', () async {
      final cubit = build();
      await cubit.loadFirstPage();

      await cubit.nextPage();

      expect(cubit.state.index, 1);
      expect(cubit.state.pages, hasLength(2));
      expect(cubit.state.items.map((todo) => todo.id), ['2', '3']);
      expect(cubit.state.allItems, hasLength(4));
    });

    test('previousPage is served from memory, without a call', () async {
      final cubit = build();
      await cubit.loadFirstPage();
      await cubit.nextPage();
      final callsBefore = repository.calls.length;

      await cubit.previousPage();

      expect(cubit.state.index, 0);
      expect(cubit.state.items.map((todo) => todo.id), ['0', '1']);
      expect(repository.calls, hasLength(callsBefore));
    });

    test('nextPage over a page already held does not reload it', () async {
      final cubit = build();
      await cubit.loadFirstPage();
      await cubit.nextPage();
      await cubit.previousPage();
      final callsBefore = repository.calls.length;

      await cubit.nextPage();

      expect(cubit.state.index, 1);
      expect(repository.calls, hasLength(callsBefore));
    });

    test('nextPage on the last page does nothing', () async {
      final cubit = build(total: 3, size: 2);
      await cubit.loadFirstPage();
      await cubit.nextPage();

      expect(cubit.state.hasNext, isFalse);
      final callsBefore = repository.calls.length;

      await cubit.nextPage();

      expect(repository.calls, hasLength(callsBefore));
      expect(cubit.state.index, 1);
    });

    test('nextPage without a first page loads it', () async {
      final cubit = build();

      await cubit.nextPage();

      expect(cubit.state.pages, hasLength(1));
      expect(cubit.state.index, 0);
    });

    test('previousPage on the first page does nothing', () async {
      final cubit = build();
      await cubit.loadFirstPage();

      await cubit.previousPage();

      expect(cubit.state.index, 0);
    });

    test('goToPage moves within the pages held', () async {
      final cubit = build();
      await cubit.loadFirstPage();
      await cubit.nextPage();

      cubit.goToPage(0);

      expect(cubit.state.index, 0);
    });

    test('goToPage out of range is ignored', () async {
      final cubit = build();
      await cubit.loadFirstPage();

      cubit.goToPage(7);
      cubit.goToPage(-1);

      expect(cubit.state.index, 0);
    });
  });

  group('jumpToPage', () {
    test('reads that offset page directly', () async {
      final cubit = build();

      await cubit.jumpToPage(2);

      expect(cubit.state.items.map((todo) => todo.id), ['4']);
      expect(cubit.state.pages, hasLength(1));
    });

    test('previousPage after a jump reads the page before it', () async {
      final cubit = build();
      await cubit.jumpToPage(2);

      await cubit.previousPage();

      expect(cubit.state.items.map((todo) => todo.id), ['2', '3']);
      expect(cubit.state.index, 0);
      expect(cubit.state.pages, hasLength(2));
      // Prepended, so the pages stay contiguous and allItems stays ordered.
      expect(cubit.state.allItems.map((todo) => todo.id), ['2', '3', '4']);
    });

    test('is refused for a cursor paginated collection', () async {
      final cubit = build(cursor: true);

      await cubit.jumpToPage(2);

      expect(cubit.state.status.isFailure, isTrue);
      expect(cubit.state.error, isA<CrudUnsupportedException>());
    });
  });

  group('cursor pagination', () {
    test('walks forward and comes back from memory', () async {
      final cubit = build(cursor: true);

      await cubit.loadFirstPage();
      await cubit.nextPage();

      expect(cubit.state.allItems.map((todo) => todo.id), ['0', '1', '2', '3']);

      final callsBefore = repository.calls.length;
      await cubit.previousPage();

      expect(cubit.state.items.map((todo) => todo.id), ['0', '1']);
      expect(repository.calls, hasLength(callsBefore));
    });
  });

  group('filter and request', () {
    test('updateFilter resets to the first page and keeps the filter', () async {
      final repo = seededRepository(5);
      var seenFilter = '';
      final cubit = PaginationCubit<Todo, String>(
        loadPage: (request, filter) {
          seenFilter = filter;
          return repo.findPage(request);
        },
        initialRequest: OffsetPageRequest(size: 2),
        initialFilter: 'all',
      );
      addTearDown(cubit.close);
      await cubit.loadFirstPage();
      await cubit.nextPage();

      await cubit.updateFilter('done');

      expect(seenFilter, 'done');
      expect(cubit.state.filter, 'done');
      expect(cubit.state.index, 0);
      expect(cubit.state.pages, hasLength(1));
    });

    test('updateRequest applies a new size and resets', () async {
      final cubit = build();
      await cubit.loadFirstPage();

      await cubit.updateRequest(OffsetPageRequest(size: 4));

      expect(cubit.state.items, hasLength(4));
      expect(cubit.state.initialRequest, OffsetPageRequest(size: 4));
    });

    test('updateQuery applies both at once, reading only once', () async {
      final repo = seededRepository(6);
      var reads = 0;
      final cubit = PaginationCubit<Todo, String>(
        loadPage: (request, filter) {
          reads++;
          return repo.findPage(request);
        },
        initialRequest: OffsetPageRequest(size: 2),
        initialFilter: 'all',
      );
      addTearDown(cubit.close);
      await cubit.loadFirstPage();
      await cubit.nextPage();

      await cubit.updateQuery(OffsetPageRequest(size: 4), 'done');

      expect(reads, 3);
      expect(cubit.state.filter, 'done');
      expect(cubit.state.initialRequest, OffsetPageRequest(size: 4));
      expect(cubit.state.items, hasLength(4));
      expect(cubit.state.index, 0);
    });

    test('updateRequest on its own keeps the current filter', () async {
      final repo = seededRepository(4);
      final seen = <String>[];
      final cubit = PaginationCubit<Todo, String>(
        loadPage: (request, filter) {
          seen.add(filter);
          return repo.findPage(request);
        },
        initialRequest: OffsetPageRequest(size: 2),
        initialFilter: 'all',
      );
      addTearDown(cubit.close);
      await cubit.loadFirstPage();

      await cubit.updateRequest(OffsetPageRequest(size: 4));

      expect(seen, ['all', 'all']);
    });

    test('refresh rereads the first page', () async {
      final cubit = build();
      await cubit.loadFirstPage();
      await cubit.nextPage();

      await cubit.refresh();

      expect(cubit.state.index, 0);
      expect(cubit.state.pages, hasLength(1));
    });
  });

  group('PaginationState', () {
    test('isEmpty only once something was loaded', () {
      final cubit = build();

      expect(cubit.state.isEmpty, isFalse);
    });

    test('reports an empty result', () async {
      final cubit = build(total: 0);

      await cubit.loadFirstPage();

      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.hasNext, isFalse);
    });

    test('equality ignores the stack trace', () {
      const error = CrudServerException('down');
      final base = PaginationState<Todo, void>.initial(filter: null, initialRequest: OffsetPageRequest(size: 2));

      expect(
        base.copyWith(error: error, stackTrace: StackTrace.current),
        base.copyWith(error: error, stackTrace: StackTrace.fromString('elsewhere')),
      );
    });

    test('copyWith clears the error unless told to keep it', () {
      const error = CrudServerException('down');
      final failed = PaginationState<Todo, void>.initial(
        filter: null,
        initialRequest: OffsetPageRequest(size: 2),
      ).copyWith(error: error, status: PaginationStatus.failure);

      expect(failed.copyWith(status: PaginationStatus.loading).error, isNull);
      expect(failed.copyWith(status: PaginationStatus.loading, keepError: true).error, error);
    });
  });

  group('events', () {
    test('a delete on a cursor page removes in place and keeps the cursor', () async {
      final cubit = build(cursor: true);
      await cubit.loadFirstPage();
      final reads = repository.calls.length;

      cubit.apply(const CrudEvent<Todo>.deleted('0'));
      await pumpEventQueue();

      expect(cubit.state.items.map((todo) => todo.id), ['1']);
      expect((cubit.state.page! as CursorPage<Todo>).nextCursor, '2');
      expect(repository.calls, hasLength(reads));
    });

    test('a delete on a completely held offset collection removes in place', () async {
      final cubit = build(total: 4);
      await cubit.loadFirstPage();
      await cubit.nextPage();
      final reads = repository.calls.length;

      cubit.apply(const CrudEvent<Todo>.deleted('0'));
      await pumpEventQueue();

      expect(cubit.state.allItems.map((todo) => todo.id), ['1', '2', '3']);
      expect(repository.calls, hasLength(reads));
    });

    test('a delete lowers the total on every held page', () async {
      final cubit = build(total: 4);
      await cubit.loadFirstPage();
      await cubit.nextPage();

      cubit.apply(const CrudEvent<Todo>.deleted('0'));
      await pumpEventQueue();

      for (final page in cubit.state.pages) {
        expect((page as OffsetPage<Todo>).totalElements, 3);
      }
    });

    test('a delete on an offset collection with more pages on the server rereads', () async {
      final cubit = build();
      await cubit.loadFirstPage();
      await repository.deleteById('1');
      final reads = repository.calls.length;

      cubit.apply(const CrudEvent<Todo>.deleted('1'));
      await pumpEventQueue();

      // Removed at once, then reread, so the next page skips nothing.
      expect(repository.calls.length, reads + 1);
      await cubit.nextPage();
      expect(cubit.state.allItems.map((todo) => todo.id), ['0', '2', '3', '4']);
    });

    test('a delete for an id no held page shows changes nothing', () async {
      final cubit = build();
      await cubit.loadFirstPage();
      final before = cubit.state;

      cubit.apply(const CrudEvent<Todo>.deleted('99'));

      expect(cubit.state, same(before));
    });

    test('an update replaces the entity in place without a read', () async {
      final cubit = build();
      await cubit.loadFirstPage();
      final reads = repository.calls.length;

      cubit.apply(const CrudEvent<Todo>.updated(Todo(id: '0', title: 'Renamed')));

      expect(cubit.state.items.singleWhere((todo) => todo.id == '0').title, 'Renamed');
      expect(repository.calls, hasLength(reads));
    });

    test('an update reaches an entity on another held page', () async {
      final cubit = build();
      await cubit.loadFirstPage();
      await cubit.nextPage();

      cubit.apply(const CrudEvent<Todo>.updated(Todo(id: '0', title: 'Renamed')));
      cubit.goToPage(0);

      expect(cubit.state.items.singleWhere((todo) => todo.id == '0').title, 'Renamed');
    });

    test('an update for an id no held page shows changes nothing', () async {
      final cubit = build();
      await cubit.loadFirstPage();
      final before = cubit.state;

      cubit.apply(const CrudEvent<Todo>.updated(Todo(id: '99', title: 'Elsewhere')));

      expect(cubit.state, same(before));
    });

    test('an update keeps the error of a failed state', () async {
      final cubit = build();
      await cubit.loadFirstPage();
      repository.nextError = const CrudServerException('down');
      await cubit.nextPage();
      final error = cubit.state.error;
      expect(error, isNotNull);

      cubit.apply(const CrudEvent<Todo>.updated(Todo(id: '0', title: 'Renamed')));

      expect(cubit.state.error, error);
    });

    test('a create event rereads the first page', () async {
      final cubit = build();
      await cubit.loadFirstPage();
      final reads = repository.calls.length;

      cubit.apply(const CrudEvent<Todo>.created(Todo(id: '9', title: 'New')));
      await pumpEventQueue();

      expect(repository.calls.length, reads + 1);
    });

    test('a create event before the first load does nothing', () async {
      final cubit = build();

      cubit.apply(const CrudEvent<Todo>.created(Todo(id: '9', title: 'New')));
      await pumpEventQueue();

      expect(cubit.state.status, PaginationStatus.initial);
      expect(repository.calls, isEmpty);
    });

    test('an event during an in-flight read ends in a reread', () async {
      final gate = Completer<void>();
      var reads = 0;
      repository = FlakyTodoRepository(seededRepository(5));
      final cubit = PaginationCubit<Todo, void>(
        loadPage: (request, _) async {
          reads++;
          if (reads == 1) await gate.future;
          return repository.findPage(request);
        },
        initialRequest: OffsetPageRequest(size: 2),
        initialFilter: null,
      );
      addTearDown(cubit.close);

      final first = cubit.loadFirstPage();
      cubit.apply(const CrudEvent<Todo>.deleted('0'));
      gate.complete();
      await first;
      await pumpEventQueue();

      expect(reads, 2);
    });

    test('a delete for a T that is no CrudEntity uses idOf', () async {
      final cubit = PaginationCubit<String, void>(
        loadPage: (request, _) async => const CrudSuccess(CursorPage<String>(content: ['a', 'b'])),
        initialRequest: const CursorPageRequest(size: 2),
        initialFilter: null,
        idOf: (item) => item,
      );
      addTearDown(cubit.close);
      await cubit.loadFirstPage();

      cubit.apply(const CrudEvent<String>.deleted('a'));

      expect(cubit.state.items, ['b']);
    });

    test('removing the last item of a page keeps the page held', () async {
      final cubit = build(total: 3);
      await cubit.loadFirstPage();
      await cubit.nextPage();
      final reads = repository.calls.length;

      cubit.apply(const CrudEvent<Todo>.deleted('2'));
      await pumpEventQueue();

      expect(cubit.state.pages, hasLength(2));
      expect(cubit.state.items, isEmpty);
      expect(repository.calls, hasLength(reads));
    });

    test('a watched hub drives apply until the cubit closes', () async {
      final hub = CrudEventHub<Todo>();
      addTearDown(hub.dispose);
      repository = FlakyTodoRepository(seededRepository(4));
      final cubit = PaginationCubit<Todo, void>(
        loadPage: (request, _) => repository.findPage(request),
        initialRequest: OffsetPageRequest(size: 2),
        initialFilter: null,
        watch: hub.events,
      );
      await cubit.loadFirstPage();
      await cubit.nextPage();

      hub.announce(const CrudEvent<Todo>.deleted('0'));
      await pumpEventQueue();
      expect(cubit.state.allItems.map((todo) => todo.id), ['1', '2', '3']);

      // Still-held id: without the cancel in close this would emit on a
      // closed cubit and fail with a StateError.
      final before = cubit.state;
      await cubit.close();
      hub.announce(const CrudEvent<Todo>.deleted('1'));
      await pumpEventQueue();
      expect(cubit.state, same(before));
    });
  });
}
