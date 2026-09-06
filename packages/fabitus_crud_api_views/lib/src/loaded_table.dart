import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'crud_table.dart';
import 'table_column.dart';

/// A table over a [LoadCubit] holding the whole list, sorted and filtered in
/// memory.
///
/// For the collections that are not paged - a lookup table, a settings list, the
/// dozen rows behind a `findAll`. Sorting never leaves the device, so a column
/// needs a [TableColumn.sortValue] to be sortable here; [TableColumn.sortKey]
/// only names it.
///
/// ```dart
/// CrudLoadedTable<Todo>(
///   columns: columns,
///   where: (todo) => todo.title.contains(query),
///   rowBuilder: (context, todo, index, cells) => MyRow(children: cells),
/// );
/// ```
///
/// The cubit comes from the enclosing [BlocProvider] unless one is passed.
class CrudLoadedTable<T> extends StatefulWidget {
  /// Renders everything [cubit] holds, or the one in the enclosing provider.
  const CrudLoadedTable({
    required this.columns,
    this.cubit,
    this.initialSort = Sort.unsorted,
    this.where,
    this.headerBuilder,
    this.rowBuilder,
    this.separatorBuilder,
    this.cellWrapper,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.showHeaderWhenEmpty = true,
    super.key,
  });

  /// What the columns are.
  final List<TableColumn<T>> columns;

  /// The cubit to render. Read from the enclosing provider when omitted.
  final LoadCubit<List<T>>? cubit;

  /// How the rows are ordered before the user touches a header.
  final Sort initialSort;

  /// Keeps only the rows it accepts. Everything is kept by default.
  ///
  /// Applied before sorting, and rebuilt whenever the widget is - so a search
  /// field can pass a closure over its query and nothing else has to happen.
  final bool Function(T row)? where;

  /// Assembles the header row. Defaults to a plain [Row].
  final TableHeaderBuilder? headerBuilder;

  /// Assembles one body row. Defaults to a plain [Row].
  final TableRowBuilder<T>? rowBuilder;

  /// Goes between two body rows. Nothing by default.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Wraps every cell, header cells included. Nothing by default.
  final TableCellWrapper? cellWrapper;

  /// Replaces the body when nothing is left to show.
  final WidgetBuilder? emptyBuilder;

  /// Replaces the whole table while the list is being read the first time.
  final WidgetBuilder? loadingBuilder;

  /// Replaces the whole table when the read failed. [retry] reloads.
  final Widget Function(BuildContext context, CrudException error, VoidCallback retry)? errorBuilder;

  /// Whether the header row still shows when nothing is left to show.
  final bool showHeaderWhenEmpty;

  @override
  State<CrudLoadedTable<T>> createState() => _CrudLoadedTableState<T>();
}

class _CrudLoadedTableState<T> extends State<CrudLoadedTable<T>> {
  late Sort _sort = widget.initialSort;

  @override
  void initState() {
    super.initState();
    assert(_missingSortValue() == null, _missingSortValueMessage());
  }

  /// A column that says it can be sorted but cannot say by what.
  TableColumn<T>? _missingSortValue() =>
      widget.columns.where((column) => column.sortKey != null && column.sortValue == null).firstOrNull;

  String _missingSortValueMessage() =>
      'The column with sortKey "${_missingSortValue()?.sortKey}" has no '
      'sortValue. CrudLoadedTable sorts in memory, so it needs to read the '
      'value itself - sortKey only names the property for a backend.';

  /// Reads the value a column sorts by, for `sortEntities`.
  Object? _valueOf(T row, String property) =>
      widget.columns.where((column) => column.sortKey == property).firstOrNull?.sortValue?.call(row);

  @override
  Widget build(BuildContext context) {
    final cubit = widget.cubit;
    return cubit == null
        ? BlocBuilder<LoadCubit<List<T>>, LoadState<List<T>>>(builder: _build)
        : BlocBuilder<LoadCubit<List<T>>, LoadState<List<T>>>(bloc: cubit, builder: _build);
  }

  Widget _build(BuildContext context, LoadState<List<T>> state) {
    final cubit = widget.cubit ?? context.read<LoadCubit<List<T>>>();
    final rows = state.dataOrNull;

    if (rows == null) {
      return switch (state) {
        LoadFailure<List<T>>(:final error) =>
          widget.errorBuilder?.call(context, error, cubit.load) ?? const SizedBox.shrink(),
        _ => widget.loadingBuilder?.call(context) ?? const SizedBox.shrink(),
      };
    }

    final where = widget.where;
    final filtered = where == null ? rows : rows.where(where).toList(growable: false);

    return CrudTable<T>(
      columns: widget.columns,
      rows: sortEntities(filtered, _sort, _valueOf),
      sort: _sort,
      onSortChanged: (sort) => setState(() => _sort = sort),
      headerBuilder: widget.headerBuilder,
      rowBuilder: widget.rowBuilder,
      separatorBuilder: widget.separatorBuilder,
      cellWrapper: widget.cellWrapper,
      emptyBuilder: widget.emptyBuilder,
      showHeaderWhenEmpty: widget.showHeaderWhenEmpty,
    );
  }
}
