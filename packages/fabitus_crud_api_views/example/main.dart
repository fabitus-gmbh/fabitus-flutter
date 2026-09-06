// The four shapes on four screens, each with a deliberately plain look - the
// point is that every pixel below comes from this file, not from the package.
//
// Like the other Flutter packages here it has no `dart run`: widgets need a host
// app. It is analyzed as part of the package, so it cannot rot, and the widget
// tests in `test/` exercise the same paths headlessly.
import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:fabitus_crud_api_views/fabitus_crud_api_views.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  final repository = InMemoryCrudRepository<Todo, String>(
    withId: (todo, id) => todo.copyWith(id: id),
    initial: [for (var i = 1; i <= 40; i++) Todo(id: '$i', title: 'Todo $i', priority: i % 5)],
  );
  runApp(ExampleApp(repository: repository));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({required this.repository, super.key});

  final PagingCrudRepository<Todo, String> repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: RepositoryProvider<PagingCrudRepository<Todo, String>>.value(value: repository, child: const HomeScreen()),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<PagingCrudRepository<Todo, String>>();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Todos'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Paged table'),
              Tab(text: 'Endless'),
              Tab(text: 'Load more'),
              Tab(text: 'Everything'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            PagedTableTab(repository: repository),
            EndlessTab(repository: repository),
            LoadMoreTab(repository: repository),
            EverythingTab(repository: repository),
          ],
        ),
      ),
    );
  }
}

/// The columns. Headers draw their own sort arrow - the package draws none.
List<TableColumn<Todo>> todoColumns() => [
  TableColumn<Todo>(
    header: (context, sort) => SortableHeader('Title', sort: sort),
    cell: (context, todo) => Text(todo.title),
    sortKey: 'title',
    sortValue: (todo) => todo.title,
    flex: 3,
  ),
  TableColumn<Todo>(
    header: (context, sort) => SortableHeader('Priority', sort: sort),
    cell: (context, todo) => Text('${todo.priority}'),
    sortKey: 'priority',
    sortValue: (todo) => todo.priority,
  ),
  TableColumn<Todo>(
    header: (context, sort) => const Text('ID'),
    cell: (context, todo) => Text(todo.id ?? '-'),
    width: 56,
  ),
];

class SortableHeader extends StatelessWidget {
  const SortableHeader(this.label, {required this.sort, super.key});

  final String label;
  final ColumnSortState sort;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      if (sort.isActive) Icon(sort == ColumnSortState.ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
    ],
  );
}

PaginationCubit<Todo, void> pagedCubit(PagingCrudRepository<Todo, String> repository, {int size = 10}) =>
    PaginationCubit<Todo, void>(
      loadPage: (request, _) => repository.findPage(request),
      initialRequest: OffsetPageRequest(size: size, sort: Sort.by('title')),
      initialFilter: null,
      loadOnCreate: true,
    );

/// One page at a time, sorted by the backend, with a footer of our own.
class PagedTableTab extends StatelessWidget {
  const PagedTableTab({required this.repository, super.key});

  final PagingCrudRepository<Todo, String> repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => pagedCubit(repository),
    child: SingleChildScrollView(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: CrudPaginatedTable<Todo, void>(
          columns: todoColumns(),
          cellWrapper: (context, cell, column) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Align(alignment: Alignment.centerLeft, child: cell),
          ),
          headerBuilder: (context, cells) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(children: cells),
          ),
          rowBuilder: (context, todo, index, cells) => InkWell(
            onTap: () {},
            child: Row(children: cells),
          ),
          separatorBuilder: (context, index) => const Divider(height: 1),
          loadingBuilder: (context) => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          emptyBuilder: (context) => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No todos yet')),
          ),
          errorBuilder: (context, error, retry) => Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text(error.message),
                TextButton(onPressed: retry, child: const Text('Try again')),
              ],
            ),
          ),
          footerBuilder: (context, controls) => TableFooter(controls),
        ),
      ),
    ),
  );
}

/// Everything a footer needs is on [PaginationControls]; the look is ours.
class TableFooter extends StatelessWidget {
  const TableFooter(this.controls, {super.key});

  final PaginationControls controls;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        const Text('Rows per page'),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: controls.pageSize,
          items: const [10, 25, 50].map((size) => DropdownMenuItem(value: size, child: Text('$size'))).toList(),
          onChanged: (size) => size == null ? null : controls.onPageSizeChanged?.call(size),
        ),
        const Spacer(),
        if (controls.isLoading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Text(
          controls.totalElements == null
              // Cursor pagination cannot know a total.
              ? controls.rangeLabel ?? 'No results'
              : '${controls.rangeLabel ?? '0'} of ${controls.totalElements}',
        ),
        IconButton(onPressed: controls.onPrevious, icon: const Icon(Icons.chevron_left)),
        IconButton(onPressed: controls.onNext, icon: const Icon(Icons.chevron_right)),
      ],
    ),
  );
}

/// The next page arrives as the reader reaches the end.
class EndlessTab extends StatelessWidget {
  const EndlessTab({required this.repository, super.key});

  final PagingCrudRepository<Todo, String> repository;

  @override
  // The provider owns the cubit, so this tab needs no BlocProvider and no
  // close(). Point refreshOn at a CrudService and it rereads itself too.
  Widget build(BuildContext context) => CrudPaginationProvider<Todo, void>(
    loadPage: (request, _) => repository.findPage(request),
    filter: null,
    pageRequest: OffsetPageRequest(size: 8, sort: Sort.by('title')),
    child: CrudInfiniteList<Todo, void>(
      itemBuilder: (context, todo, index) => ListTile(title: Text(todo.title)),
      separatorBuilder: (context, index) => const Divider(height: 1),
      loadingBuilder: (context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      emptyBuilder: (context) => const Center(child: Text('Nothing here')),
      errorBuilder: (context, error, retry) => ListTile(
        title: Text(error.message),
        trailing: TextButton(onPressed: retry, child: const Text('Retry')),
      ),
    ),
  );
}

/// The same list, but reading more is a decision.
class LoadMoreTab extends StatelessWidget {
  const LoadMoreTab({required this.repository, super.key});

  final PagingCrudRepository<Todo, String> repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => pagedCubit(repository, size: 8),
    child: CrudLoadMoreList<Todo, void>(
      itemBuilder: (context, todo, index) => ListTile(title: Text(todo.title)),
      separatorBuilder: (context, index) => const Divider(height: 1),
      loadMoreBuilder: (context, onPressed) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: FilledButton.tonal(onPressed: onPressed, child: Text(onPressed == null ? 'Loading...' : 'Load more')),
        ),
      ),
      loadingBuilder: (context) => const Center(child: CircularProgressIndicator()),
    ),
  );
}

/// The whole collection at once, sorted and filtered without a round trip.
class EverythingTab extends StatefulWidget {
  const EverythingTab({required this.repository, super.key});

  final PagingCrudRepository<Todo, String> repository;

  @override
  State<EverythingTab> createState() => _EverythingTabState();
}

class _EverythingTabState extends State<EverythingTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) => CrudLoadProvider<List<Todo>>(
    load: widget.repository.findAll,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(labelText: 'Search'),
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: CrudLoadedTable<Todo>(
              columns: todoColumns(),
              initialSort: Sort.by('title'),
              // Rebuilt on every keystroke; no request is made.
              where: (todo) => todo.title.toLowerCase().contains(_query),
              cellWrapper: (context, cell, column) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Align(alignment: Alignment.centerLeft, child: cell),
              ),
              headerBuilder: (context, cells) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(children: cells),
              ),
              rowBuilder: (context, todo, index, cells) => Row(children: cells),
              separatorBuilder: (context, index) => const Divider(height: 1),
              loadingBuilder: (context) => const Center(child: CircularProgressIndicator()),
              emptyBuilder: (context) => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Nothing matches')),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class Todo implements CrudEntity<String> {
  const Todo({this.id, required this.title, this.priority = 0});

  @override
  final String? id;
  final String title;
  final int priority;

  Todo copyWith({String? id, String? title, int? priority}) =>
      Todo(id: id ?? this.id, title: title ?? this.title, priority: priority ?? this.priority);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'priority': priority};
}
