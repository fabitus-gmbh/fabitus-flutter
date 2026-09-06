import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:fabitus_crud_api_views/fabitus_crud_api_views.dart';
import 'package:flutter/widgets.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/todo.dart';

void main() {
  late InMemoryCrudRepository<Todo, String> repository;
  late int loads;

  PaginationCubit<Todo, void> buildCubit({int total = 5, int size = 2}) {
    repository = seededRepository(total);
    loads = 0;
    final cubit = PaginationCubit<Todo, void>(
      loadPage: (request, _) {
        loads++;
        return repository.findPage(request);
      },
      initialRequest: OffsetPageRequest(size: size),
      initialFilter: null,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  // Tall enough for two 100px rows, so the trailing item is off screen until
  // the list is scrolled - which is what the endless scroll waits for.
  Widget wrap(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(400, 200)),
      child: Center(child: SizedBox(width: 400, height: 200, child: child)),
    ),
  );

  Widget tile(BuildContext context, Todo todo, int index) => SizedBox(height: 100, child: Text(todo.title));

  group('CrudInfiniteList', () {
    testWidgets('shows the pages read so far, accumulated', (tester) async {
      final cubit = buildCubit();
      await cubit.loadFirstPage();
      await cubit.nextPage();

      await tester.pumpWidget(wrap(CrudInfiniteList<Todo, void>(cubit: cubit, itemBuilder: tile)));

      expect(find.text('Todo 5'), findsOne);
      expect(find.text('Todo 4'), findsOne);
    });

    testWidgets('reads the next page when the trailer comes into view', (tester) async {
      final cubit = buildCubit();
      await cubit.loadFirstPage();
      expect(loads, 1);

      await tester.pumpWidget(
        wrap(
          CrudInfiniteList<Todo, void>(
            cubit: cubit,
            itemBuilder: tile,
            // No prefetch, so the read happens exactly when the end is on
            // screen - which is what this test is about.
            cacheExtent: const ScrollCacheExtent.pixels(0),
            loadingBuilder: (context) => const SizedBox(height: 50, child: Text('more')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Two 100px rows fill the 200px viewport, so the trailer is not built yet.
      expect(loads, 1);

      await tester.drag(find.byType(ListView), const Offset(0, -150));
      await tester.pumpAndSettle();

      expect(loads, 2);
      expect(find.text('Todo 3'), findsOne);
    });

    testWidgets('the default cache extent tops up a page too short to fill the screen', (tester) async {
      final cubit = buildCubit();
      await cubit.loadFirstPage();

      await tester.pumpWidget(
        wrap(
          CrudInfiniteList<Todo, void>(
            cubit: cubit,
            itemBuilder: tile,
            loadingBuilder: (context) => const SizedBox(height: 50, child: Text('more')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A ListView builds within its cache extent, so the trailer is reached
      // without the user scrolling and the list fills itself up.
      expect(loads, greaterThan(1));
      expect(find.text('more'), findsNothing);
    });

    testWidgets('stops asking once the last page is in', (tester) async {
      final cubit = buildCubit(total: 2, size: 2);
      await cubit.loadFirstPage();

      await tester.pumpWidget(
        wrap(
          CrudInfiniteList<Todo, void>(
            cubit: cubit,
            itemBuilder: tile,
            loadingBuilder: (context) => const Text('more'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('more'), findsNothing);
      expect(loads, 1);
    });

    testWidgets('the first page owns the body while it is coming', (tester) async {
      final cubit = buildCubit();

      await tester.pumpWidget(
        wrap(
          CrudInfiniteList<Todo, void>(
            cubit: cubit,
            itemBuilder: tile,
            loadingBuilder: (context) => const Text('first load'),
          ),
        ),
      );

      expect(find.text('first load'), findsOne);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('an empty collection shows the empty builder', (tester) async {
      final cubit = PaginationCubit<Todo, void>(
        loadPage: (request, _) =>
            InMemoryCrudRepository<Todo, String>(withId: (todo, id) => todo.copyWith(id: id)).findPage(request),
        initialRequest: OffsetPageRequest(size: 2),
        initialFilter: null,
      );
      addTearDown(cubit.close);
      await cubit.loadFirstPage();

      await tester.pumpWidget(
        wrap(
          CrudInfiniteList<Todo, void>(
            cubit: cubit,
            itemBuilder: tile,
            emptyBuilder: (context) => const Text('Nothing here'),
          ),
        ),
      );

      expect(find.text('Nothing here'), findsOne);
    });

    testWidgets('a failed first page replaces the body and can retry', (tester) async {
      var fail = true;
      final repo = seededRepository(3);
      final cubit = PaginationCubit<Todo, void>(
        loadPage: (request, _) async => fail
            ? CrudFailure<Page<Todo>>(const CrudNetworkException('offline'), StackTrace.current)
            : await repo.findPage(request),
        initialRequest: OffsetPageRequest(size: 2),
        initialFilter: null,
      );
      addTearDown(cubit.close);
      await cubit.loadFirstPage();

      await tester.pumpWidget(
        wrap(
          CrudInfiniteList<Todo, void>(
            cubit: cubit,
            itemBuilder: tile,
            errorBuilder: (context, error, retry) => GestureDetector(
              onTap: () {
                fail = false;
                retry();
              },
              child: Text('failed: ${error.message}'),
            ),
          ),
        ),
      );

      expect(find.text('failed: offline'), findsOne);

      await tester.tap(find.text('failed: offline'));
      await tester.pumpAndSettle();

      expect(find.text('Todo 3'), findsOne);
    });

    testWidgets('separators go between items', (tester) async {
      final cubit = buildCubit();
      await cubit.loadFirstPage();

      await tester.pumpWidget(
        wrap(
          CrudInfiniteList<Todo, void>(
            cubit: cubit,
            itemBuilder: tile,
            separatorBuilder: (context, index) => const SizedBox(key: Key('sep'), height: 1),
          ),
        ),
      );

      expect(find.byKey(const Key('sep')), findsAtLeast(1));
    });
  });

  group('CrudLoadMoreList', () {
    testWidgets('does not read anything until asked', (tester) async {
      final cubit = buildCubit();
      await cubit.loadFirstPage();

      await tester.pumpWidget(
        wrap(
          CrudLoadMoreList<Todo, void>(
            cubit: cubit,
            itemBuilder: tile,
            cacheExtent: const ScrollCacheExtent.pixels(0),
            loadMoreBuilder: (context, onPressed) => GestureDetector(
              onTap: onPressed,
              child: const SizedBox(height: 50, child: Text('Load more')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Scrolled the button into view, and still only the first page was read.
      expect(loads, 1);
      expect(find.text('Load more'), findsOne);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(loads, 2);
      expect(find.text('Todo 3'), findsOne);
    });

    testWidgets('the button disappears on the last page', (tester) async {
      final cubit = buildCubit(total: 2, size: 2);
      await cubit.loadFirstPage();

      await tester.pumpWidget(
        wrap(
          CrudLoadMoreList<Todo, void>(
            cubit: cubit,
            itemBuilder: tile,
            loadMoreBuilder: (context, onPressed) => const Text('Load more'),
          ),
        ),
      );

      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('reads the cubit from the enclosing provider', (tester) async {
      final cubit = buildCubit();
      await cubit.loadFirstPage();

      await tester.pumpWidget(
        wrap(
          BlocProvider<PaginationCubit<Todo, void>>.value(
            value: cubit,
            child: CrudLoadMoreList<Todo, void>(
              itemBuilder: tile,
              loadMoreBuilder: (context, onPressed) => const Text('Load more'),
            ),
          ),
        ),
      );

      expect(find.text('Todo 5'), findsOne);
    });
  });
}
