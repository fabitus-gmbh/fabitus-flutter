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
}
