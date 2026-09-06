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

  LoadCubit<List<Todo>> cubitFor(List<Todo> todos) {
    final cubit = LoadCubit<List<Todo>>(() async => CrudSuccess(todos));
    addTearDown(cubit.close);
    return cubit;
  }

  const todos = [
    Todo(id: 'a', title: 'Charlie', priority: 30),
    Todo(id: 'b', title: 'Alpha', priority: 10),
    Todo(id: 'c', title: 'Bravo', priority: 20),
  ];

  /// The titles in the order they are rendered.
  List<String> renderedTitles(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .where((label) => const {'Alpha', 'Bravo', 'Charlie'}.contains(label))
      .toList();

  testWidgets('shows everything the cubit holds, in its own order', (tester) async {
    final cubit = cubitFor(todos);
    await cubit.load();

    await tester.pumpWidget(wrap(CrudLoadedTable<Todo>(cubit: cubit, columns: todoColumns())));

    expect(renderedTitles(tester), ['Charlie', 'Alpha', 'Bravo']);
  });

  testWidgets('sorts in memory when a header is tapped', (tester) async {
    final cubit = cubitFor(todos);
    await cubit.load();

    await tester.pumpWidget(wrap(CrudLoadedTable<Todo>(cubit: cubit, columns: todoColumns())));

    await tester.tap(find.text('Title sortable'));
    await tester.pumpAndSettle();
    expect(renderedTitles(tester), ['Alpha', 'Bravo', 'Charlie']);

    await tester.tap(find.text('Title asc'));
    await tester.pumpAndSettle();
    expect(renderedTitles(tester), ['Charlie', 'Bravo', 'Alpha']);
  });

  testWidgets('sorts by a numeric column through its sortValue', (tester) async {
    final cubit = cubitFor(todos);
    await cubit.load();

    await tester.pumpWidget(wrap(CrudLoadedTable<Todo>(cubit: cubit, columns: todoColumns())));

    await tester.tap(find.text('Priority sortable'));
    await tester.pumpAndSettle();

    expect(renderedTitles(tester), ['Alpha', 'Bravo', 'Charlie']);
  });

  testWidgets('honours an initial sort', (tester) async {
    final cubit = cubitFor(todos);
    await cubit.load();

    await tester.pumpWidget(
      wrap(
        CrudLoadedTable<Todo>(cubit: cubit, columns: todoColumns(), initialSort: Sort.by('title', SortDirection.desc)),
      ),
    );

    expect(renderedTitles(tester), ['Charlie', 'Bravo', 'Alpha']);
    expect(find.text('Title desc'), findsOne);
  });

  testWidgets('filters before sorting', (tester) async {
    final cubit = cubitFor(todos);
    await cubit.load();

    await tester.pumpWidget(
      wrap(
        CrudLoadedTable<Todo>(
          cubit: cubit,
          columns: todoColumns(),
          initialSort: Sort.by('title'),
          where: (todo) => todo.priority >= 20,
        ),
      ),
    );

    expect(renderedTitles(tester), ['Bravo', 'Charlie']);
  });

  testWidgets('shows the empty builder when the filter keeps nothing', (tester) async {
    final cubit = cubitFor(todos);
    await cubit.load();

    await tester.pumpWidget(
      wrap(
        CrudLoadedTable<Todo>(
          cubit: cubit,
          columns: todoColumns(),
          where: (todo) => false,
          emptyBuilder: (context) => const Text('Nothing matches'),
        ),
      ),
    );

    expect(find.text('Nothing matches'), findsOne);
  });

  testWidgets('the loading builder owns the body until the list arrives', (tester) async {
    final cubit = cubitFor(todos);

    await tester.pumpWidget(
      wrap(
        CrudLoadedTable<Todo>(cubit: cubit, columns: todoColumns(), loadingBuilder: (context) => const Text('Loading')),
      ),
    );
    expect(find.text('Loading'), findsOne);

    await cubit.load();
    await tester.pumpAndSettle();
    expect(find.text('Charlie'), findsOne);
  });

  testWidgets('the error builder replaces the table and can retry', (tester) async {
    var fail = true;
    final cubit = LoadCubit<List<Todo>>(
      () async => fail
          ? CrudFailure<List<Todo>>(const CrudNetworkException('offline'), StackTrace.current)
          : const CrudSuccess(todos),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      wrap(
        CrudLoadedTable<Todo>(
          cubit: cubit,
          columns: todoColumns(),
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

    expect(find.text('Charlie'), findsOne);
  });

  testWidgets('a failed refresh keeps the rows on screen', (tester) async {
    var fail = false;
    final cubit = LoadCubit<List<Todo>>(
      () async => fail
          ? CrudFailure<List<Todo>>(const CrudNetworkException('offline'), StackTrace.current)
          : const CrudSuccess(todos),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      wrap(
        CrudLoadedTable<Todo>(
          cubit: cubit,
          columns: todoColumns(),
          errorBuilder: (context, error, retry) => const Text('failed'),
        ),
      ),
    );

    fail = true;
    await cubit.refresh();
    await tester.pumpAndSettle();

    // LoadFailure keeps `previous`, so the table renders it rather than
    // dropping to the error view.
    expect(find.text('Charlie'), findsOne);
    expect(find.text('failed'), findsNothing);
  });

  testWidgets('a sortable column without a sortValue is a programming error', (tester) async {
    final cubit = cubitFor(todos);
    await cubit.load();

    await tester.pumpWidget(
      wrap(
        CrudLoadedTable<Todo>(
          cubit: cubit,
          columns: [
            TableColumn<Todo>(
              header: (context, sort) => const Text('Title'),
              cell: (context, todo) => Text(todo.title),
              sortKey: 'title',
            ),
          ],
        ),
      ),
    );

    expect(
      tester.takeException(),
      isA<AssertionError>().having((error) => error.message, 'message', contains('sortValue')),
    );
  });

  testWidgets('reads the cubit from the enclosing provider', (tester) async {
    final cubit = cubitFor(todos);
    await cubit.load();

    await tester.pumpWidget(
      wrap(
        BlocProvider<LoadCubit<List<Todo>>>.value(
          value: cubit,
          child: CrudLoadedTable<Todo>(columns: todoColumns()),
        ),
      ),
    );

    expect(find.text('Charlie'), findsOne);
  });
}
