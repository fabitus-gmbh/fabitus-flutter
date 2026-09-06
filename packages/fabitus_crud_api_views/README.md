# fabitus_crud_api_views

Lists and tables over [`fabitus_crud_api`](../fabitus_crud_api) repositories.
Four shapes, one for each way a collection reaches a screen:

| Widget | For |
| --- | --- |
| `CrudInfiniteList` | an endless scroll - the next page arrives as the user reaches the end |
| `CrudLoadMoreList` | the same list, with a control at the end instead of a scroll trigger |
| `CrudPaginatedTable` | one page at a time, sorted by the backend, with a footer you draw |
| `CrudLoadedTable` | the whole collection at once, sorted and filtered in memory |

**Nothing here paints.** These widgets own the wiring, the column sizing and the
sort interaction. Every colour, border, divider, padding and font comes from a
builder you pass. They import `package:flutter/widgets.dart`, not
`material.dart`, so they cannot accidentally acquire a look - and there is no
`Card`, no `Divider`, no `Theme` lookup anywhere in them.

```dart
CrudPaginatedTable<Todo, void>(
  columns: [
    TableColumn(
      header: (context, sort) => MyHeaderLabel('Title', sort: sort),
      cell: (context, todo) => Text(todo.title),
      sortKey: 'title',
      flex: 3,
    ),
  ],
  rowBuilder: (context, todo, index, cells) =>
      MyTableRow(onTap: () => _open(todo), children: cells),
  footerBuilder: (context, controls) => MyTableFooter(controls),
);
```

## Contents

- [Installation](#installation)
- [What the package owns, and what you do](#what-the-package-owns-and-what-you-do)
- [Guide 1: columns](#guide-1-columns)
- [Guide 2: a paged table](#guide-2-a-paged-table)
- [Guide 3: the footer](#guide-3-the-footer)
- [Guide 4: an endless scroll](#guide-4-an-endless-scroll)
- [Guide 5: a load more list](#guide-5-a-load-more-list)
- [Guide 6: a table for everything](#guide-6-a-table-for-everything)
- [Guide 7: bringing your design system](#guide-7-bringing-your-design-system)
- [Guide 8: testing](#guide-8-testing)
- [Design notes](#design-notes)

## Installation

```yaml
dependencies:
  fabitus_crud_api_views:
    git:
      url: https://github.com/fabitus-gmbh/fabitus-flutter.git
      path: packages/fabitus_crud_api_views
```

```dart
import 'package:fabitus_crud_api_views/fabitus_crud_api_views.dart';
```

It pulls in `fabitus_crud_api`, `fabitus_crud_api_bloc` and `flutter_bloc`. The
paged widgets run on a `PaginationCubit` and `CrudLoadedTable` on a `LoadCubit`,
both from the bloc package.

> **One name clash to know about.** `fabitus_crud_api` has a `Page<T>` - the
> result of reading one page - and Flutter's `Navigator` has a `Page<T>` too. In
> a file that names the crud one, hide the other:
> `import 'package:flutter/material.dart' hide Page;`. Most widget files never
> name it, because these widgets hand you rows rather than pages.

## What the package owns, and what you do

| The package | You |
| --- | --- |
| when to read the next page | what the loader and the "load more" control look like |
| how wide a column is (`width` / `flex`) | what is inside the cell |
| what a header tap means for the sort | what a sorted header looks like |
| turning cubit state into rows | the row, its background, its tap target, its divider |
| what a footer needs to know and can do | what the footer looks like |

Every builder is optional. Leave them all out and you get an unstyled, working
table - useful in a test, not on a screen.

## Guide 1: columns

```dart
final columns = <TableColumn<Todo>>[
  TableColumn(
    header: (context, sort) => Row(
      children: [
        const Text('TITLE'),
        if (sort.isActive)
          Icon(sort == ColumnSortState.ascending
              ? Icons.arrow_upward
              : Icons.arrow_downward),
      ],
    ),
    cell: (context, todo) => Text(todo.title),
    sortKey: 'title',        // what the backend sorts by
    sortValue: (todo) => todo.title,   // how CrudLoadedTable sorts in memory
    flex: 3,
  ),
  TableColumn(
    header: (context, sort) => const Text('DONE'),
    cell: (context, todo) => Icon(todo.done ? Icons.check : Icons.close),
    width: 64,               // fixed instead of flexible
  ),
];
```

- **`sortKey`** makes the header tappable. Leave it out and the column is inert;
  its header builder is told so with `ColumnSortState.unsortable`.
- **`sortValue`** is only for `CrudLoadedTable`, which has the whole list and no
  backend to ask. A paged table sends `sortKey` and never calls it.
- **`width`** or **`flex`**, like a `Row`: a fixed width, or a share of what is
  left.

The sort arrow is yours. `ColumnSortState` tells the header whether it is the
active column and in which direction; the package draws nothing.

## Guide 2: a paged table

```dart
BlocProvider(
  create: (_) => PaginationCubit<Todo, TodoFilter>(
    loadPage: (request, filter) => repository.search(filter, request),
    initialRequest: OffsetPageRequest(size: 25, sort: Sort.by('title')),
    initialFilter: const TodoFilter(),
    loadOnCreate: true,
  ),
  child: CrudPaginatedTable<Todo, TodoFilter>(
    columns: columns,
    rowBuilder: (context, todo, index, cells) => MyRow(
      onTap: () => _open(todo),
      striped: index.isEven,
      children: cells,
    ),
    separatorBuilder: (context, index) => const MyHairline(),
    footerBuilder: (context, controls) => MyTableFooter(controls),
    loadingBuilder: (context) => const MySpinner(),
    errorBuilder: (context, error, retry) =>
        MyErrorPanel(error.message, onRetry: retry),
    emptyBuilder: (context) => const Text('No todos yet'),
  ),
);
```

**Sorting goes to the server.** Tapping a sortable header calls
`updateRequest` with the new `Sort` and starts over at the first page - the only
correct thing to do, because a page number under one ordering means nothing under
another.

**`loadingBuilder` is only for the first page.** Once there are rows, a later
page keeps them on screen rather than flashing a spinner;
`controls.isLoading` lets the footer say so, and `rowBuilder` can dim the body if
you want that.

## Guide 3: the footer

`footerBuilder` gets a `PaginationControls`: everything a footer needs to know
and everything it can do. Callbacks are `null` when the action is unavailable,
which is exactly what a disabled button wants.

```dart
Widget myFooter(BuildContext context, PaginationControls controls) => Row(
  children: [
    DropdownButton<int>(
      value: controls.pageSize,
      items: const [10, 25, 50]
          .map((size) => DropdownMenuItem(value: size, child: Text('$size')))
          .toList(),
      onChanged: (size) => size == null ? null : controls.onPageSizeChanged?.call(size),
    ),
    const Spacer(),
    Text(
      controls.totalElements == null
          ? controls.rangeLabel ?? 'No results'          // cursor pagination
          : '${controls.rangeLabel} of ${controls.totalElements}',
    ),
    IconButton(onPressed: controls.onPrevious, icon: const Icon(Icons.chevron_left)),
    IconButton(onPressed: controls.onNext, icon: const Icon(Icons.chevron_right)),
    if (controls.canJumpToPage)
      IconButton(
        onPressed: controls.totalPages == null
            ? null
            : () => controls.onJumpToPage!(controls.totalPages! - 1),
        icon: const Icon(Icons.last_page),
      ),
  ],
);
```

`canJumpToPage` is `false` for cursor pagination - a cursor cannot address a page
by number - and `totalElements` is `null` there too, so a cursor footer shows a
range and arrows rather than page buttons. The wording around the numbers is
yours, and so is its translation.

## Guide 4: an endless scroll

```dart
CrudInfiniteList<Todo, void>(
  itemBuilder: (context, todo, index) => MyTile(todo),
  separatorBuilder: (context, index) => const MyHairline(),
  loadingBuilder: (context) => const MySpinner(),
  emptyBuilder: (context) => const Text('Nothing here'),
  errorBuilder: (context, error, retry) =>
      MyErrorPanel(error.message, onRetry: retry),
);
```

The pages accumulate, so the list only ever grows. Reading the next one is
triggered by the trailing item being built, which is also the prefetch knob:

```dart
cacheExtent: const ScrollCacheExtent.pixels(0),      // read only at the very end
cacheExtent: const ScrollCacheExtent.viewport(1),    // read a screenful ahead
```

Flutter's default of 250 pixels is usually right: a first page too short to fill
the screen tops itself up without the user doing anything.

Nothing is read twice - the cubit ignores a `nextPage` while one is in flight,
and the list does not ask while it is loading. A **later** page failing does not
take the pages already read off the screen: the error goes at the end, with a
retry.

## Guide 5: a load more list

The same list, with a decision instead of a scroll trigger:

```dart
CrudLoadMoreList<Todo, void>(
  itemBuilder: (context, todo, index) => MyTile(todo),
  loadMoreBuilder: (context, onPressed) => MyButton(
    onPressed: onPressed,            // null while a page is on its way
    label: onPressed == null ? 'Loading...' : 'Load more',
  ),
);
```

The control disappears on the last page, because `hasNext` is false.

## Guide 6: a table for everything

For the collections that are not paged - a lookup table, a settings list, the
dozen rows behind a `findAll`:

```dart
BlocProvider(
  create: (_) => LoadCubit<List<Todo>>(repository.findAll, loadOnCreate: true),
  child: CrudLoadedTable<Todo>(
    columns: columns,
    initialSort: Sort.by('title'),
    where: (todo) => todo.title.toLowerCase().contains(_query),
    rowBuilder: (context, todo, index, cells) => MyRow(children: cells),
  ),
);
```

Sorting never leaves the device, so a sortable column needs a `sortValue` - an
assert names the offending column if it does not have one. Filtering runs before
sorting and is rebuilt whenever the widget is, so a search field only has to
trigger a rebuild.

A failed **refresh** keeps the rows on screen: `LoadState` carries the previous
value, so the table renders it rather than dropping to the error view. The error
view is for a first load that failed.

## Guide 7: bringing your design system

Wrap the widget once, with your builders baked in, and the rest of the app never
passes them again:

```dart
class AcmeTable<T, F> extends StatelessWidget {
  const AcmeTable({required this.columns, this.onRowTap, super.key});

  final List<TableColumn<T>> columns;
  final void Function(T row)? onRowTap;

  @override
  Widget build(BuildContext context) => AcmeCard(
    child: CrudPaginatedTable<T, F>(
      columns: columns,
      cellWrapper: (context, cell, column) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Align(alignment: Alignment.centerLeft, child: cell),
      ),
      headerBuilder: (context, cells) => ColoredBox(
        color: AcmeColors.surfaceMuted,
        child: Row(children: cells),
      ),
      rowBuilder: (context, row, index, cells) => InkWell(
        onTap: onRowTap == null ? null : () => onRowTap!(row),
        child: Row(children: cells),
      ),
      separatorBuilder: (context, index) => const Divider(height: 1),
      loadingBuilder: (context) => const AcmeSpinner(),
      errorBuilder: (context, error, retry) => AcmeError(error, onRetry: retry),
      footerBuilder: (context, controls) => AcmeTableFooter(controls),
    ),
  );
}
```

`cellWrapper` is the hook that spares you repeating a padding in every cell
builder - it wraps body and header cells alike.

## Guide 8: testing

The widgets need nothing but a cubit, and `fabitus_crud_api` ships an in-memory
repository to feed it:

```dart
final repository = InMemoryCrudRepository<Todo, String>(
  withId: (todo, id) => todo.copyWith(id: id),
  initial: const [Todo(id: '1', title: 'Write docs')],
);

final cubit = PaginationCubit<Todo, void>(
  loadPage: (request, _) => repository.findPage(request),
  initialRequest: OffsetPageRequest(size: 2),
  initialFilter: null,
);
await cubit.loadFirstPage();

await tester.pumpWidget(
  MaterialApp(home: CrudPaginatedTable<Todo, void>(cubit: cubit, columns: columns)),
);
```

Two things that will bite otherwise:

- **`pumpAndSettle` times out on an animating spinner.** Use two `pump()`s
  where a `CircularProgressIndicator` is on screen.
- **Set `cacheExtent: ScrollCacheExtent.pixels(0)`** when testing the scroll
  trigger. Otherwise the list builds ahead into its cache and reads pages before
  you scroll - correct behaviour, confusing assertion.

Both are in [`test/paged_list_test.dart`](test/paged_list_test.dart).

## Design notes

**Why builders rather than a theme?** A theme is a bet on which properties
matter. Builders make no bet: whatever your design system does to a row - a card,
a stripe, a hover state, a leading avatar - is a widget you already have.

**Why does `CrudTable` size the cells rather than handing them raw?** Because
column widths are the one layout decision that has to be consistent between the
header and every row, and it is tedious and easy to get wrong by hand. Your
builders get cells that are already the right width and put them wherever they
like.

**Why a `GestureDetector` on a sortable header, not an `InkWell`?** A ripple is
Material's opinion. The package adds a tap target and a pointer cursor; the
feedback is yours to add in the header builder.

**Why is the trailing item the scroll trigger?** Because it is exactly the
question being asked - is the end near? A scroll listener with a pixel threshold
has to be re-tuned for every item height; a trailing item does not.

**Why does `CrudLoadedTable` hold the sort itself?** There is no request to put
it in. The paged table keeps the sort in the `PageRequest`, where the backend
reads it; the loaded one has nowhere else to keep it, so it is widget state.

## License

[MIT](LICENSE) © Fabitus GmbH.
