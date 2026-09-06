import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter/widgets.dart';

import 'page_request_sort.dart';

/// Everything a pagination footer needs to know, and everything it can do.
///
/// Handed to your `footerBuilder` so you can draw the footer your design system
/// wants - this package draws none. It is the same information a page range,
/// a rows-per-page dropdown and four arrows are built from:
///
/// ```dart
/// footerBuilder: (context, controls) => Row(
///   children: [
///     Text(controls.rangeLabel ?? 'no results'),
///     IconButton(
///       onPressed: controls.onPrevious,   // null disables the button
///       icon: const Icon(Icons.chevron_left),
///     ),
///     IconButton(
///       onPressed: controls.onNext,
///       icon: const Icon(Icons.chevron_right),
///     ),
///   ],
/// );
/// ```
///
/// Every callback is `null` when the action is not available, which is exactly
/// what a disabled button wants.
class PaginationControls {
  /// Creates the controls. Built for you by the paged widgets.
  const PaginationControls({
    required this.page,
    required this.pageSize,
    required this.itemsOnPage,
    required this.isLoading,
    required this.canJumpToPage,
    this.totalElements,
    this.error,
    this.onNext,
    this.onPrevious,
    this.onJumpToPage,
    this.onPageSizeChanged,
    this.onRefresh,
  });

  /// Reads the controls out of a cubit and its current state.
  static PaginationControls of<T, F>(PaginationCubit<T, F> cubit, PaginationState<T, F> state) {
    final request = state.requests.elementAtOrNull(state.index);
    final canJump = state.initialRequest is OffsetPageRequest;
    return PaginationControls(
      page: request?.pageNumber ?? state.index,
      pageSize: state.initialRequest.size,
      itemsOnPage: state.items.length,
      totalElements: state.totalElements,
      isLoading: state.status.isLoading,
      canJumpToPage: canJump,
      error: state.error,
      onNext: state.hasNext ? cubit.nextPage : null,
      onPrevious: state.hasPrevious || (request?.pageNumber ?? 0) > 0 ? cubit.previousPage : null,
      onJumpToPage: canJump ? cubit.jumpToPage : null,
      onPageSizeChanged: (size) => cubit.updateRequest(state.initialRequest.withSize(size)),
      onRefresh: cubit.refresh,
    );
  }

  /// The page the user is on, zero based.
  final int page;

  /// How many entities a page holds at most.
  final int pageSize;

  /// How many the current page actually holds.
  final int itemsOnPage;

  /// The total across all pages, or `null` when the backend does not report it -
  /// which is always the case for cursor pagination.
  final int? totalElements;

  /// Whether a page is being read right now.
  final bool isLoading;

  /// Whether [onJumpToPage] can be used at all.
  ///
  /// `false` for cursor pagination: a cursor cannot address a page by number, so
  /// a footer should offer arrows rather than page buttons.
  final bool canJumpToPage;

  /// What went wrong on the last read, or `null`.
  final CrudException? error;

  /// Goes to the following page, or `null` when there is none.
  final VoidCallback? onNext;

  /// Goes to the preceding page, or `null` when there is none.
  final VoidCallback? onPrevious;

  /// Goes straight to a page by number, or `null` for cursor pagination.
  final ValueChanged<int>? onJumpToPage;

  /// Changes how many entities a page holds, starting over at the first page.
  final ValueChanged<int>? onPageSizeChanged;

  /// Reads the first page again.
  final VoidCallback? onRefresh;

  /// The index of the first entity on this page, zero based.
  int get firstIndex => page * pageSize;

  /// The total number of pages, or `null` when [totalElements] is unknown.
  int? get totalPages {
    final total = totalElements;
    if (total == null || pageSize <= 0) return null;
    return total == 0 ? 1 : (total / pageSize).ceil();
  }

  /// Whether this is the last page it is possible to reach.
  bool get isLastPage => onNext == null;

  /// The one-based range this page covers, for example `1-10`, or `null` when
  /// the page is empty.
  ///
  /// The wording around it - "of 240", "no results" - is yours to add, and to
  /// translate.
  String? get rangeLabel => itemsOnPage == 0 ? null : '${firstIndex + 1}-${firstIndex + itemsOnPage}';

  @override
  String toString() =>
      'PaginationControls(page: $page of ${totalPages ?? '?'}, '
      'items: $itemsOnPage, loading: $isLoading)';
}
