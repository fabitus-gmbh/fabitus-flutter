import 'dart:async';

import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:fabitus_crud_api_views/fabitus_crud_api_views.dart';
import 'package:flutter/widgets.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/todo.dart';

void main() {
  Widget wrap(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: child,
    ),
  );

  group('CrudPaginationProvider', () {
    late InMemoryCrudRepository<Todo, String> repository;
    late List<String> reads;

    setUp(() {
      repository = seededRepository(6);
      reads = [];
    });

    Widget providerFor({
      required String filter,
      PageRequest pageRequest = const OffsetPageRequest(size: 2),
      Stream<Object?>? refreshOn,
    }) => wrap(
      CrudPaginationProvider<Todo, String>(
        loadPage: (request, filter) {
          reads.add(filter);
          return repository.findPage(request);
        },
        filter: filter,
        pageRequest: pageRequest,
        refreshOn: refreshOn,
        child: CrudPaginatedTable<Todo, String>(columns: todoColumns()),
      ),
    );

    testWidgets('creates the cubit and reads the first page', (tester) async {
      await tester.pumpWidget(providerFor(filter: 'all'));
      await tester.pumpAndSettle();

      expect(reads, ['all']);
      expect(find.text('Todo 6'), findsOne);
    });

    testWidgets('a changed filter reads again, from the first page', (tester) async {
      await tester.pumpWidget(providerFor(filter: 'all'));
      await tester.pumpAndSettle();
      final cubit = tester.element(find.byType(CrudPaginatedTable<Todo, String>)).read<PaginationCubit<Todo, String>>();
      await cubit.nextPage();
      expect(cubit.state.index, 1);

      await tester.pumpWidget(providerFor(filter: 'done'));
      await tester.pumpAndSettle();

      expect(reads, ['all', 'all', 'done']);
      expect(cubit.state.filter, 'done');
      expect(cubit.state.index, 0);
    });

    testWidgets('an unchanged filter does not read again', (tester) async {
      await tester.pumpWidget(providerFor(filter: 'all'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(providerFor(filter: 'all'));
      await tester.pumpAndSettle();

      expect(reads, ['all']);
    });

    testWidgets('a changed page request reads again', (tester) async {
      await tester.pumpWidget(providerFor(filter: 'all'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(providerFor(filter: 'all', pageRequest: const OffsetPageRequest(size: 4)));
      await tester.pumpAndSettle();

      expect(reads, hasLength(2));
      expect(find.text('Todo 3'), findsOne);
    });

    testWidgets('a request and a filter changing together read once', (tester) async {
      await tester.pumpWidget(providerFor(filter: 'all'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(providerFor(filter: 'done', pageRequest: const OffsetPageRequest(size: 4)));
      await tester.pumpAndSettle();

      // updateRequest already carries the current filter, so doing both would
      // have read the same page twice.
      expect(reads, ['all', 'done']);
    });

    testWidgets('an event on refreshOn rereads', (tester) async {
      final events = StreamController<Object?>.broadcast();
      addTearDown(events.close);

      await tester.pumpWidget(providerFor(filter: 'all', refreshOn: events.stream));
      await tester.pumpAndSettle();
      expect(reads, hasLength(1));

      events.add(const CrudEntityDeleted<Todo>('1'));
      await tester.pumpAndSettle();

      expect(reads, hasLength(2));
    });

    testWidgets('a burst of events costs one read', (tester) async {
      final events = StreamController<Object?>.broadcast();
      addTearDown(events.close);

      await tester.pumpWidget(providerFor(filter: 'all', refreshOn: events.stream));
      await tester.pumpAndSettle();

      // A bulk delete announcing ten deletions in one turn.
      for (var i = 0; i < 10; i++) {
        events.add(CrudEntityDeleted<Todo>('$i'));
      }
      await tester.pumpAndSettle();

      expect(reads, hasLength(2));
    });

    testWidgets('a real CrudService keeps the view current', (tester) async {
      final service = PagingCrudService<Todo, String>(repository);
      addTearDown(service.dispose);

      await tester.pumpWidget(providerFor(filter: 'all', refreshOn: service.events));
      await tester.pumpAndSettle();
      expect(find.text('Todo 6'), findsOne);

      // Deleting the first row elsewhere in the app.
      await service.deleteById('0');
      await tester.pumpAndSettle();

      expect(reads, hasLength(2));
      expect(find.text('Todo 6'), findsNothing);
      expect(find.text('Todo 5'), findsOne);
    });

    testWidgets('closes the cubit when it goes away', (tester) async {
      await tester.pumpWidget(providerFor(filter: 'all'));
      await tester.pumpAndSettle();
      final cubit = tester.element(find.byType(CrudPaginatedTable<Todo, String>)).read<PaginationCubit<Todo, String>>();

      await tester.pumpWidget(wrap(const SizedBox.shrink()));

      expect(cubit.isClosed, isTrue);
    });

    testWidgets('an event after disposal is harmless', (tester) async {
      final events = StreamController<Object?>.broadcast();
      addTearDown(events.close);

      await tester.pumpWidget(providerFor(filter: 'all', refreshOn: events.stream));
      await tester.pumpAndSettle();

      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      events.add('after disposal');
      await tester.pumpAndSettle();

      expect(reads, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('loadOnCreate can be turned off', (tester) async {
      await tester.pumpWidget(
        wrap(
          CrudPaginationProvider<Todo, String>(
            loadPage: (request, filter) {
              reads.add(filter);
              return repository.findPage(request);
            },
            filter: 'all',
            loadOnCreate: false,
            child: CrudPaginatedTable<Todo, String>(columns: todoColumns()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(reads, isEmpty);
    });
  });

  group('CrudLoadProvider', () {
    late InMemoryCrudRepository<Todo, String> repository;
    late int reads;

    setUp(() {
      repository = seededRepository(3);
      reads = 0;
    });

    Widget providerFor({Stream<Object?>? refreshOn}) => wrap(
      CrudLoadProvider<List<Todo>>(
        load: () {
          reads++;
          return repository.findAll();
        },
        refreshOn: refreshOn,
        child: CrudLoadedTable<Todo>(columns: todoColumns()),
      ),
    );

    testWidgets('creates the cubit and reads the list', (tester) async {
      await tester.pumpWidget(providerFor());
      await tester.pumpAndSettle();

      expect(reads, 1);
      expect(find.text('Todo 3'), findsOne);
    });

    testWidgets('an event rereads without clearing the table', (tester) async {
      final events = StreamController<Object?>.broadcast();
      addTearDown(events.close);

      await tester.pumpWidget(providerFor(refreshOn: events.stream));
      await tester.pumpAndSettle();

      events.add('changed');
      await tester.pump();

      // refresh, not load: the rows stay while it rereads.
      expect(find.text('Todo 3'), findsOne);

      await tester.pumpAndSettle();
      expect(reads, 2);
    });

    testWidgets('a burst of events costs one read', (tester) async {
      final events = StreamController<Object?>.broadcast();
      addTearDown(events.close);

      await tester.pumpWidget(providerFor(refreshOn: events.stream));
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        events.add('changed $i');
      }
      await tester.pumpAndSettle();

      expect(reads, 2);
    });

    testWidgets('closes the cubit when it goes away', (tester) async {
      await tester.pumpWidget(providerFor());
      await tester.pumpAndSettle();
      final cubit = tester.element(find.byType(CrudLoadedTable<Todo>)).read<LoadCubit<List<Todo>>>();

      await tester.pumpWidget(wrap(const SizedBox.shrink()));

      expect(cubit.isClosed, isTrue);
    });
  });
}
