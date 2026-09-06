import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'crud_table.dart';
import 'page_request_sort.dart';
import 'pagination_controls.dart';
import 'table_column.dart';

/// A table over a [PaginationCubit]: one page of rows, sorted by the backend,
/// with a footer you draw.
///
/// Sorting goes to the server. Tapping a sortable header calls
/// [PaginationCubit.updateRequest] with the new [Sort] and starts over at the
/// first page, which is the only correct thing to do - a page number under one
/// ordering means nothing under another.
///
/// ```dart
/// CrudPaginatedTable<Todo, void>(
///   columns: columns,
///   footerBuilder: (context, controls) => MyTableFooter(controls),
///   rowBuilder: (context, todo, index, cells) =>
///       MyRow(onTap: () => _open(todo), children: cells),
/// );
/// ```
///
/// The cubit comes from the enclosing [BlocProvider] unless one is passed.
class CrudPaginatedTable<T, F> extends StatelessWidget {
  /// Renders the current page of [cubit], or of the one in the enclosing
  /// provider.
  const CrudPaginatedTable({
    required this.columns,
    this.cubit,
    this.footerBuilder,
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
  final PaginationCubit<T, F>? cubit;

  /// Draws the footer under the table. Nothing by default.
  final Widget Function(BuildContext context, PaginationControls controls)? footerBuilder;

  /// Assembles the header row. Defaults to a plain [Row].
  final TableHeaderBuilder? headerBuilder;

  /// Assembles one body row. Defaults to a plain [Row].
  final TableRowBuilder<T>? rowBuilder;

  /// Goes between two body rows. Nothing by default.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Wraps every cell, header cells included. Nothing by default.
  final TableCellWrapper? cellWrapper;

  /// Replaces the body when the page is empty.
  final WidgetBuilder? emptyBuilder;

  /// Replaces the whole table while the *first* page is being read.
  ///
  /// Only then: once there are rows, a later page keeps them on screen rather
  /// than flashing a spinner. [PaginationControls.isLoading] lets the footer say
  /// so, and the row builder can dim the body if you want.
  final WidgetBuilder? loadingBuilder;

  /// Replaces the whole table when the read failed. [retry] rereads.
  final Widget Function(BuildContext context, CrudException error, VoidCallback retry)? errorBuilder;

  /// Whether the header row still shows when the page is empty.
  final bool showHeaderWhenEmpty;

  @override
  Widget build(BuildContext context) {
    final cubit = this.cubit;
    return cubit == null
        ? BlocBuilder<PaginationCubit<T, F>, PaginationState<T, F>>(builder: _build)
        : BlocBuilder<PaginationCubit<T, F>, PaginationState<T, F>>(bloc: cubit, builder: _build);
  }

  Widget _build(BuildContext context, PaginationState<T, F> state) {
    final cubit = this.cubit ?? context.read<PaginationCubit<T, F>>();
    final error = state.error;

    // The first page is a different thing from a later one: there is nothing on
    // screen to keep, so a spinner is right here and wrong afterwards.
    final isFirstLoad = state.pages.isEmpty && !state.status.isFailure;
    if (isFirstLoad && loadingBuilder != null) return loadingBuilder!(context);

    if (state.status.isFailure && error != null && errorBuilder != null) {
      return errorBuilder!(context, error, cubit.refresh);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CrudTable<T>(
          columns: columns,
          rows: state.items,
          sort: state.initialRequest.sort,
          onSortChanged: (sort) => cubit.updateRequest(state.initialRequest.withSort(sort)),
          headerBuilder: headerBuilder,
          rowBuilder: rowBuilder,
          separatorBuilder: separatorBuilder,
          cellWrapper: cellWrapper,
          emptyBuilder: emptyBuilder,
          showHeaderWhenEmpty: showHeaderWhenEmpty,
        ),
        if (footerBuilder case final builder?) builder(context, PaginationControls.of(cubit, state)),
      ],
    );
  }
}
