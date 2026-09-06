import 'dart:async';

import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'pagination_state.dart';

/// Reads one page, the way a repository returns it.
///
/// [F] is whatever your app filters by - a `freezed` filter object, or `void`
/// when there is nothing to filter.
typedef LoadPageFunction<T, F> = Future<CrudResult<Page<T>>> Function(PageRequest request, F filter);

/// Walks a paged collection, keeping the pages it has already read.
///
/// Serves both shapes a paged list comes in: a table with next and previous
/// buttons reads [PaginationState.items], an infinite scroll reads
/// [PaginationState.allItems], and both use the same cubit.
///
/// ```dart
/// final cubit = PaginationCubit<Todo, TodoFilter>(
///   loadPage: (request, filter) => repository.search(filter, request),
///   initialRequest: OffsetPageRequest(size: 20, sort: Sort.by('title')),
///   initialFilter: const TodoFilter(),
///   loadOnCreate: true,
/// );
/// ```
///
/// Cursor pagination works too, and going back needs no cursor: pages already
/// read are kept, so [previousPage] serves them from memory.
class PaginationCubit<T, F> extends Cubit<PaginationState<T, F>> {
  /// Creates a cubit that calls [loadPage] for every page.
  PaginationCubit({
    required this.loadPage,
    required PageRequest initialRequest,
    required F initialFilter,
    bool loadOnCreate = false,
  }) : super(PaginationState<T, F>.initial(filter: initialFilter, initialRequest: initialRequest)) {
    // On the next microtask, so the initial state stays observable - see
    // [LoadCubit].
    if (loadOnCreate) {
      scheduleMicrotask(() {
        if (!isClosed) loadFirstPage();
      });
    }
  }

  /// Reads one page.
  final LoadPageFunction<T, F> loadPage;

  int _generation = 0;
  bool _inFlight = false;

  /// Reads the first page, dropping whatever was loaded before.
  Future<void> loadFirstPage() => _reload(state.initialRequest, filter: state.filter);

  /// Reads the first page again, keeping the current filter, size and sort.
  ///
  /// This is what to call after a create or a delete: the page the user is on
  /// may no longer hold what it did.
  Future<void> refresh() => loadFirstPage();

  /// Applies [filter] and reads the first page again.
  Future<void> updateFilter(F filter) => _reload(state.initialRequest, filter: filter);

  /// Applies a new page size or sort order and reads the first page again.
  ///
  /// Keeps the current filter. To change both at once use [updateQuery] - doing
  /// this and [updateFilter] in turn would read the first page twice, and doing
  /// only this one would quietly keep the old filter.
  Future<void> updateRequest(PageRequest request) => _reload(request, filter: state.filter);

  /// Applies a new request and a new filter together, reading the first page
  /// once.
  ///
  /// Both are required: with `F` nullable or `void` there is no value that could
  /// mean "leave this one alone".
  Future<void> updateQuery(PageRequest request, F filter) => _reload(request, filter: filter);

  /// Moves to the following page, reading it when it is not held yet.
  Future<void> nextPage() async {
    if (state.pages.isEmpty) return loadFirstPage();
    if (state.index + 1 < state.pages.length) {
      emit(state.copyWith(index: state.index + 1, status: PaginationStatus.success));
      return;
    }
    final request = state.pages.last.nextPageRequest(state.requests.last);
    if (request == null || _inFlight) return;

    final page = await _read(request);
    if (page == null) return;
    emit(
      state.copyWith(
        status: PaginationStatus.success,
        pages: [...state.pages, page],
        requests: [...state.requests, request],
        index: state.pages.length,
      ),
    );
  }

  /// Moves to the preceding page.
  ///
  /// Served from memory when that page is still held. Otherwise - after a
  /// [jumpToPage] - the preceding offset page is read and put in front, so the
  /// pages stay contiguous. A cursor based collection cannot look backwards, so
  /// there this does nothing.
  Future<void> previousPage() async {
    if (state.index > 0) {
      emit(state.copyWith(index: state.index - 1, status: PaginationStatus.success));
      return;
    }
    final first = state.requests.firstOrNull;
    if (first is! OffsetPageRequest || first.page == 0 || _inFlight) return;

    final request = first.previous();
    final page = await _read(request);
    if (page == null) return;
    emit(
      state.copyWith(
        status: PaginationStatus.success,
        pages: [page, ...state.pages],
        requests: [request, ...state.requests],
        index: 0,
      ),
    );
  }

  /// Moves to a page that is already held.
  ///
  /// Out of range indices are ignored - use [nextPage] to reach a page that has
  /// not been read, or [jumpToPage] to go straight to one.
  void goToPage(int index) {
    if (index < 0 || index >= state.pages.length) {
      crudLogger.warning('goToPage($index) ignored: only ${state.pages.length} page(s) loaded');
      return;
    }
    emit(state.copyWith(index: index, status: PaginationStatus.success));
  }

  /// Reads offset page [page] directly, dropping the pages held before it.
  ///
  /// For a table whose footer offers page numbers. Only offset requests can
  /// address a page by number; with a cursor request this reports a failure
  /// rather than pretending.
  Future<void> jumpToPage(int page) async {
    final request = state.initialRequest;
    if (request is! OffsetPageRequest) {
      emit(
        state.copyWith(
          status: PaginationStatus.failure,
          error: const CrudUnsupportedException(
            'A cursor paginated collection cannot address a page by number. '
            'Use nextPage instead.',
          ),
          stackTrace: StackTrace.current,
        ),
      );
      return;
    }
    await _reload(request.copyWith(page: page), filter: state.filter);
  }

  /// Reads [request] as the new first page, dropping everything held.
  Future<void> _reload(PageRequest request, {required F filter}) async {
    emit(
      state.copyWith(
        status: PaginationStatus.loading,
        filter: filter,
        initialRequest: request,
        pages: const [],
        requests: const [],
        index: 0,
      ),
    );

    final page = await _read(request, filter: filter);
    if (page == null) return;
    emit(state.copyWith(status: PaginationStatus.success, pages: [page], requests: [request], index: 0));
  }

  /// Calls [loadPage] and returns the page, or `null` when the caller should
  /// stop - because the load failed, or because a newer one has taken over.
  Future<Page<T>?> _read(PageRequest request, {F? filter}) async {
    final generation = ++_generation;
    _inFlight = true;
    if (state.status != PaginationStatus.loading) {
      emit(state.copyWith(status: PaginationStatus.loading, keepError: true));
    }

    final result = await loadPage(request, filter ?? state.filter);

    // A newer load started while this one was in flight, or the cubit is gone.
    if (generation != _generation || isClosed) return null;
    _inFlight = false;

    switch (result) {
      case CrudSuccess<Page<T>>(:final data):
        return data;
      case CrudFailure<Page<T>>(:final error, :final stackTrace):
        emit(state.copyWith(status: PaginationStatus.failure, error: error, stackTrace: stackTrace));
        return null;
    }
  }
}
