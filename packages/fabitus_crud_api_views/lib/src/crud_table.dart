import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:flutter/widgets.dart';

import 'table_column.dart';

/// Wraps every cell, header cells included - for padding, alignment, a tooltip.
typedef TableCellWrapper = Widget Function(BuildContext context, Widget cell, int column);

/// Builds the header row from its already sized cells.
typedef TableHeaderBuilder = Widget Function(BuildContext context, List<Widget> cells);

/// Builds one body row from its already sized cells.
typedef TableRowBuilder<T> = Widget Function(BuildContext context, T row, int index, List<Widget> cells);

/// A table that lays out columns and sorts on a header tap, and paints nothing.
///
/// The split is deliberate: this widget owns **column sizing and the sort
/// interaction**, your builders own everything anyone can see. There is no
/// colour, border, divider, padding or font in here, and no `Material`
/// dependency - it builds on `package:flutter/widgets.dart` alone.
///
/// ```dart
/// CrudTable<Todo>(
///   columns: columns,
///   rows: todos,
///   sort: sort,
///   onSortChanged: (next) => setState(() => sort = next),
///   headerBuilder: (context, cells) => MyHeaderRow(children: cells),
///   rowBuilder: (context, todo, index, cells) => MyRow(
///     onTap: () => _open(todo),
///     children: cells,
///   ),
///   separatorBuilder: (context, index) => const MyDivider(),
/// );
/// ```
///
/// Feed it from a `LoadCubit` with `CrudLoadedTable`, or from a
/// `PaginationCubit` with `CrudPaginatedTable`; use it directly when the rows
/// come from somewhere else entirely.
class CrudTable<T> extends StatelessWidget {
  /// Renders [rows] under [columns].
  const CrudTable({
    required this.columns,
    required this.rows,
    this.sort = Sort.unsorted,
    this.onSortChanged,
    this.headerBuilder,
    this.rowBuilder,
    this.separatorBuilder,
    this.cellWrapper,
    this.emptyBuilder,
    this.showHeaderWhenEmpty = true,
    super.key,
  });

  /// What the columns are.
  final List<TableColumn<T>> columns;

  /// What to show, in the order given.
  final List<T> rows;

  /// The sort the header should reflect.
  final Sort sort;

  /// Called with the sort a header tap leads to, or `null` to make headers
  /// inert.
  ///
  /// The next sort comes from [nextSortFor]: first tap ascending, tapping the
  /// active column flips it.
  final ValueChanged<Sort>? onSortChanged;

  /// Assembles the header row. Defaults to a plain [Row].
  final TableHeaderBuilder? headerBuilder;

  /// Assembles one body row. Defaults to a plain [Row].
  ///
  /// This is where a row's tap handler, hover state and background belong.
  final TableRowBuilder<T>? rowBuilder;

  /// Goes between two body rows. Nothing by default.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Wraps every cell, header cells included. Nothing by default.
  ///
  /// The one hook that spares you repeating a padding in every cell builder.
  final TableCellWrapper? cellWrapper;

  /// Replaces the body when [rows] is empty. Nothing by default.
  final WidgetBuilder? emptyBuilder;

  /// Whether the header row still shows when there are no rows.
  final bool showHeaderWhenEmpty;

  @override
  Widget build(BuildContext context) {
    final isEmpty = rows.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isEmpty || showHeaderWhenEmpty) _buildHeader(context),
        if (isEmpty)
          emptyBuilder?.call(context) ?? const SizedBox.shrink()
        else
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0 && separatorBuilder != null) separatorBuilder!(context, index - 1),
            _buildRow(context, rows[index], index),
          ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cells = <Widget>[
      for (var index = 0; index < columns.length; index++)
        _sized(columns[index], _headerCell(context, columns[index], index)),
    ];
    return headerBuilder?.call(context, cells) ?? Row(children: cells);
  }

  Widget _headerCell(BuildContext context, TableColumn<T> column, int index) {
    final state = column.sortStateFor(sort);
    final cell = _wrap(context, column.header(context, state), index);
    final key = column.sortKey;
    if (key == null || onSortChanged == null) return cell;

    // A gesture and a cursor, no ink: a ripple would be a design decision.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSortChanged!(nextSortFor(key, sort)),
        child: cell,
      ),
    );
  }

  Widget _buildRow(BuildContext context, T row, int index) {
    final cells = <Widget>[
      for (var column = 0; column < columns.length; column++)
        _sized(columns[column], _wrap(context, columns[column].cell(context, row), column)),
    ];
    return rowBuilder?.call(context, row, index, cells) ?? Row(children: cells);
  }

  Widget _wrap(BuildContext context, Widget cell, int column) => cellWrapper?.call(context, cell, column) ?? cell;

  Widget _sized(TableColumn<T> column, Widget cell) =>
      column.width == null ? Expanded(flex: column.flex, child: cell) : SizedBox(width: column.width, child: cell);
}
