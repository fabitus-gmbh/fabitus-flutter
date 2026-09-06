import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_views/fabitus_crud_api_views.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/todo.dart';

void main() {
  // Ids and priorities are deliberately unlike each other, so a text finder
  // cannot match the wrong cell.
  const rows = [Todo(id: 'a', title: 'Beta', priority: 20), Todo(id: 'b', title: 'Alpha', priority: 10)];

  Widget wrap(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: child,
    ),
  );

  testWidgets('renders a header cell and a body cell per column', (tester) async {
    await tester.pumpWidget(wrap(CrudTable<Todo>(columns: todoColumns(), rows: rows)));

    expect(find.text('Title sortable'), findsOne);
    expect(find.text('Id unsortable'), findsOne);
    expect(find.text('Beta'), findsOne);
    expect(find.text('Alpha'), findsOne);
    expect(find.text('20'), findsOne);
    expect(find.text('a'), findsOne);
  });

  testWidgets('reflects the current sort in the header', (tester) async {
    await tester.pumpWidget(
      wrap(CrudTable<Todo>(columns: todoColumns(), rows: rows, sort: Sort.by('title', SortDirection.desc))),
    );

    expect(find.text('Title desc'), findsOne);
    expect(find.text('Priority sortable'), findsOne);
  });

  testWidgets('a header tap asks for the next sort', (tester) async {
    final asked = <Sort>[];

    await tester.pumpWidget(
      wrap(CrudTable<Todo>(columns: todoColumns(), rows: rows, sort: Sort.by('title'), onSortChanged: asked.add)),
    );

    await tester.tap(find.text('Title asc'));
    await tester.tap(find.text('Priority sortable'));

    expect(asked, [Sort.by('title', SortDirection.desc), Sort.by('priority')]);
  });

  testWidgets('an unsortable header does not react', (tester) async {
    final asked = <Sort>[];

    await tester.pumpWidget(wrap(CrudTable<Todo>(columns: todoColumns(), rows: rows, onSortChanged: asked.add)));

    await tester.tap(find.text('Id unsortable'));

    expect(asked, isEmpty);
  });

  testWidgets('headers are inert without onSortChanged', (tester) async {
    await tester.pumpWidget(wrap(CrudTable<Todo>(columns: todoColumns(), rows: rows)));

    // No gesture detector wrapping the sortable header.
    expect(find.byType(MouseRegion), findsNothing);
  });

  testWidgets('the builders own the layout', (tester) async {
    await tester.pumpWidget(
      wrap(
        CrudTable<Todo>(
          columns: todoColumns(),
          rows: rows,
          headerBuilder: (context, cells) => Row(key: const Key('header'), children: cells),
          rowBuilder: (context, row, index, cells) => Row(key: Key('row-$index'), children: cells),
          separatorBuilder: (context, index) => SizedBox(key: Key('separator-$index'), height: 1),
          cellWrapper: (context, cell, column) => Padding(padding: const EdgeInsets.all(4), child: cell),
        ),
      ),
    );

    expect(find.byKey(const Key('header')), findsOne);
    expect(find.byKey(const Key('row-0')), findsOne);
    expect(find.byKey(const Key('row-1')), findsOne);
    // One separator for two rows, and none after the last.
    expect(find.byKey(const Key('separator-0')), findsOne);
    expect(find.byKey(const Key('separator-1')), findsNothing);
    // Every cell wrapped: three headers plus three cells per row.
    expect(find.byType(Padding), findsNWidgets(9));
  });

  testWidgets('shows the empty builder, header included by default', (tester) async {
    await tester.pumpWidget(
      wrap(
        CrudTable<Todo>(columns: todoColumns(), rows: const [], emptyBuilder: (context) => const Text('Nothing here')),
      ),
    );

    expect(find.text('Nothing here'), findsOne);
    expect(find.text('Title sortable'), findsOne);
  });

  testWidgets('can hide the header when empty', (tester) async {
    await tester.pumpWidget(
      wrap(
        CrudTable<Todo>(
          columns: todoColumns(),
          rows: const [],
          showHeaderWhenEmpty: false,
          emptyBuilder: (context) => const Text('Nothing here'),
        ),
      ),
    );

    expect(find.text('Nothing here'), findsOne);
    expect(find.text('Title sortable'), findsNothing);
  });

  testWidgets('a fixed width column gets exactly that width', (tester) async {
    await tester.pumpWidget(wrap(CrudTable<Todo>(columns: todoColumns(), rows: rows)));

    // The Id column declares width: 40, and is the only SizedBox around a cell.
    final box = tester.getSize(find.ancestor(of: find.text('a'), matching: find.byType(SizedBox)).first);

    expect(box.width, 40);
  });

  testWidgets('flex shares what is left, in the declared ratio', (tester) async {
    await tester.pumpWidget(wrap(CrudTable<Todo>(columns: todoColumns(), rows: rows)));

    // 800 wide, 40 fixed for the id: 760 shared between title and priority as
    // 2:1. A cell's left edge is where its column starts - measuring the Text
    // itself would measure the glyphs, not the slot.
    expect(tester.getTopLeft(find.text('Beta')).dx, 0);
    expect(tester.getTopLeft(find.text('20')).dx, closeTo(760 * 2 / 3, 0.01));
    expect(tester.getTopLeft(find.text('a')).dx, closeTo(760, 0.01));
  });
}
