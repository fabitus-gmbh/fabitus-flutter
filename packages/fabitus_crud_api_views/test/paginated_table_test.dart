import 'dart:async';

import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:fabitus_crud_api_views/fabitus_crud_api_views.dart';
// Flutter's Navigator has its own Page; this one is the crud_api Page.
import 'package:flutter/widgets.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/todo.dart';

void main() {
  late InMemoryCrudRepository<Todo, String> repository;
  late List<PageRequest> requests;

  PaginationCubit<Todo, void> buildCubit({int size = 2, bool cursor = false}) {
    repository = seededRepository(5);
    requests = [];
    final cubit = PaginationCubit<Todo, void>(
      loadPage: (request, _) {
        requests.add(request);
        return repository.findPage(request);
      },
      initialRequest: cursor ? CursorPageRequest(size: size) : OffsetPageRequest(size: size),
      initialFilter: null,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Widget wrap(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: child,
    ),
  );

  Widget tableFor(
    PaginationCubit<Todo, void> cubit, {
    Widget Function(BuildContext, PaginationControls)? footerBuilder,
    WidgetBuilder? loadingBuilder,
    Widget Function(BuildContext, CrudException, VoidCallback)? errorBuilder,
  }) => wrap(
    CrudPaginatedTable<Todo, void>(
      cubit: cubit,
      columns: todoColumns(),
      footerBuilder: footerBuilder,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      emptyBuilder: (context) => const Text('Nothing here'),
    ),
  );

  testWidgets('shows the current page', (tester) async {
    final cubit = buildCubit();
    await cubit.loadFirstPage();

    await tester.pumpWidget(tableFor(cubit));

    expect(find.text('Todo 5'), findsOne);
    expect(find.text('Todo 4'), findsOne);
    expect(find.text('Todo 3'), findsNothing);
  });

  testWidgets('a header tap sorts on the server and starts over', (tester) async {
    final cubit = buildCubit();
    await cubit.loadFirstPage();
    await cubit.nextPage();
    await tester.pumpWidget(tableFor(cubit));

    await tester.tap(find.text('Title sortable'));
    await tester.pumpAndSettle();

    final last = requests.last as OffsetPageRequest;
    expect(last.sort, Sort.by('title'));
    // Back to the first page: a page number under one ordering means nothing
    // under another.
    expect(last.page, 0);
    expect(cubit.state.index, 0);
    expect(find.text('Title asc'), findsOne);
  });

  testWidgets('tapping the active column flips the direction', (tester) async {
    final cubit = buildCubit();
    await cubit.loadFirstPage();
    await tester.pumpWidget(tableFor(cubit));

    await tester.tap(find.text('Title sortable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title asc'));
    await tester.pumpAndSettle();

    expect(requests.last.sort, Sort.by('title', SortDirection.desc));
  });

  testWidgets('the footer gets the controls and can drive the cubit', (tester) async {
    final cubit = buildCubit();
    await cubit.loadFirstPage();
    late PaginationControls seen;

    await tester.pumpWidget(
      tableFor(
        cubit,
        footerBuilder: (context, controls) {
          seen = controls;
          return GestureDetector(
            onTap: controls.onNext,
            child: Text('page ${controls.page} of ${controls.totalPages}'),
          );
        },
      ),
    );

    expect(seen.page, 0);
    expect(seen.pageSize, 2);
    expect(seen.itemsOnPage, 2);
    expect(seen.totalElements, 5);
    expect(seen.totalPages, 3);
    expect(seen.canJumpToPage, isTrue);
    expect(seen.rangeLabel, '1-2');
    expect(seen.onPrevious, isNull);
    expect(find.text('page 0 of 3'), findsOne);

    await tester.tap(find.text('page 0 of 3'));
    await tester.pumpAndSettle();

    expect(find.text('page 1 of 3'), findsOne);
    expect(seen.rangeLabel, '3-4');
    expect(seen.onPrevious, isNotNull);
  });

  testWidgets('a cursor collection cannot jump to a page', (tester) async {
    final cubit = buildCubit(cursor: true);
    await cubit.loadFirstPage();
    late PaginationControls seen;

    await tester.pumpWidget(
      tableFor(
        cubit,
        footerBuilder: (context, controls) {
          seen = controls;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(seen.canJumpToPage, isFalse);
    expect(seen.onJumpToPage, isNull);
    expect(seen.totalElements, isNull);
    expect(seen.totalPages, isNull);
    // The range still closes, from what the page actually holds.
    expect(seen.rangeLabel, '1-2');
  });

  testWidgets('the loading builder owns the body only for the first page', (tester) async {
    final cubit = buildCubit();

    await tester.pumpWidget(tableFor(cubit, loadingBuilder: (context) => const Text('Loading')));
    expect(find.text('Loading'), findsOne);

    await cubit.loadFirstPage();
    await tester.pumpAndSettle();
    expect(find.text('Todo 5'), findsOne);

    // A later page keeps the rows on screen instead of flashing a spinner.
    unawaited(cubit.nextPage());
    await tester.pump();
    expect(find.text('Loading'), findsNothing);
  });

  testWidgets('the error builder replaces the table and can retry', (tester) async {
    final cubit = PaginationCubit<Todo, void>(
      loadPage: (request, _) async => CrudFailure<Page<Todo>>(const CrudServerException('down'), StackTrace.current),
      initialRequest: OffsetPageRequest(size: 2),
      initialFilter: null,
    );
    addTearDown(cubit.close);
    await cubit.loadFirstPage();

    await tester.pumpWidget(
      tableFor(
        cubit,
        errorBuilder: (context, error, retry) => GestureDetector(onTap: retry, child: Text('failed: ${error.message}')),
      ),
    );

    expect(find.text('failed: down'), findsOne);
    expect(find.text('Title sortable'), findsNothing);
  });

  testWidgets('an empty page shows the empty builder', (tester) async {
    repository = InMemoryCrudRepository<Todo, String>(withId: (todo, id) => todo.copyWith(id: id));
    final cubit = PaginationCubit<Todo, void>(
      loadPage: (request, _) => repository.findPage(request),
      initialRequest: OffsetPageRequest(size: 2),
      initialFilter: null,
    );
    addTearDown(cubit.close);
    await cubit.loadFirstPage();

    await tester.pumpWidget(tableFor(cubit));

    expect(find.text('Nothing here'), findsOne);
  });

  testWidgets('reads the cubit from the enclosing provider', (tester) async {
    final cubit = buildCubit();
    await cubit.loadFirstPage();

    await tester.pumpWidget(
      wrap(
        BlocProvider<PaginationCubit<Todo, void>>.value(
          value: cubit,
          child: CrudPaginatedTable<Todo, void>(columns: todoColumns()),
        ),
      ),
    );

    expect(find.text('Todo 5'), findsOne);
  });
}
