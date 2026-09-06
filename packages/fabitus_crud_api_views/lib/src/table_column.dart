import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:flutter/widgets.dart';

/// How a column is currently sorted, handed to its header builder.
enum ColumnSortState {
  /// The column can be sorted, but is not the one being sorted by.
  sortable,

  /// The table is sorted by this column, smallest first.
  ascending,

  /// The table is sorted by this column, largest first.
  descending,

  /// The column declared no [TableColumn.sortKey] and cannot be sorted.
  unsortable;

  /// Whether the table is currently sorted by this column.
  bool get isActive => this == ColumnSortState.ascending || this == ColumnSortState.descending;
}

/// One column of a table: what its header says, what its cells show, and
/// whether it can be sorted by.
///
/// Nothing here is a colour, a font or a padding. [header] and [cell] are your
/// widgets; the table only decides how wide the column is and where the cell
/// goes:
///
/// ```dart
/// TableColumn<Todo>(
///   header: (context, sort) => TableHeaderLabel('Title', sort: sort),
///   cell: (context, todo) => Text(todo.title),
///   sortKey: 'title',
///   sortValue: (todo) => todo.title,
///   flex: 3,
/// );
/// ```
class TableColumn<T> {
  /// Declares a column.
  ///
  /// Give [width] for a fixed column, or leave it out and let [flex] share the
  /// remaining space, as in a [Row].
  const TableColumn({required this.header, required this.cell, this.sortKey, this.sortValue, this.width, this.flex = 1})
    : assert(flex > 0, 'flex must be greater than zero');

  /// Builds the header cell.
  ///
  /// [sort] says whether this column is the one being sorted by and in which
  /// direction, so you can draw your own arrow - the package draws none.
  final Widget Function(BuildContext context, ColumnSortState sort) header;

  /// Builds a body cell for one row.
  final Widget Function(BuildContext context, T row) cell;

  /// The property name the backend sorts by, for example `createdAt`.
  ///
  /// `null` makes the column unsortable: its header is not tappable and its
  /// [header] builder is given [ColumnSortState.unsortable].
  final String? sortKey;

  /// Reads the value this column sorts by, for a table that sorts in memory.
  ///
  /// Only needed by `CrudLoadedTable`, which has the whole list and no backend
  /// to ask. A paged table sends [sortKey] instead and never calls this.
  final Comparable<Object>? Function(T row)? sortValue;

  /// A fixed width, or `null` to share the remaining space by [flex].
  final double? width;

  /// How much of the remaining space this column takes, when [width] is `null`.
  final int flex;

  /// This column's state under [sort].
  ColumnSortState sortStateFor(Sort sort) {
    final key = sortKey;
    if (key == null) return ColumnSortState.unsortable;
    final order = sort.orders.where((order) => order.property == key).firstOrNull;
    return switch (order?.direction) {
      null => ColumnSortState.sortable,
      SortDirection.asc => ColumnSortState.ascending,
      SortDirection.desc => ColumnSortState.descending,
    };
  }
}

/// The sort a table should move to when the header of [key] is tapped.
///
/// First tap on a column sorts it ascending; tapping the column that is already
/// active flips the direction. Sorting is single column - tapping a different
/// one replaces the sort rather than adding to it, which is what a header row
/// with one arrow can express.
Sort nextSortFor(String key, Sort current) {
  final active = current.orders.where((order) => order.property == key).firstOrNull;
  if (active == null || active.direction == SortDirection.desc) {
    return Sort.by(key);
  }
  return Sort.by(key, SortDirection.desc);
}
