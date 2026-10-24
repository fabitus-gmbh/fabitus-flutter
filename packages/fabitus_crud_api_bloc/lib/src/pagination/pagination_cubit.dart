import 'dart:async';

import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'pagination_state.dart';

/// Reads one page, the way a repository returns it.
///
/// [F] is whatever your app filters by - a `freezed` filter object, or `void`
/// when there is nothing to filter.
typedef LoadPageFunction<T, F> = Future<CrudResult<Page<T>>> Function(PageRequest request, F filter);

/// Reads the id of [item], for matching it against a [CrudEvent].
typedef EntityIdOf<T> = Object? Function(T item);

Object? _crudEntityId<T>(T item) => item is CrudEntity<Object> ? item.id : null;

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
  ///
  /// [watch] feeds [apply] with every event until the cubit closes - point it
  /// at a `CrudEventHub.events` or `CrudService.events`, and the held pages
  /// follow writes performed elsewhere. [idOf] is how events find their entity
  /// in the pages; it defaults to [CrudEntity.id] and only needs passing for a
  /// [T] that is no [CrudEntity].
  PaginationCubit({
    required this.loadPage,
    required PageRequest initialRequest,
    required F initialFilter,
    bool loadOnCreate = false,
    Stream<CrudEvent<T>>? watch,
    EntityIdOf<T>? idOf,
  }) : assert(
         watch == null || idOf != null || <T>[] is List<CrudEntity<Object>?>,
         'watch needs idOf when $T is no CrudEntity, or updates and deletes cannot find their entity',
       ),
       _idOf = idOf ?? _crudEntityId<T>,
       super(PaginationState<T, F>.initial(filter: initialFilter, initialRequest: initialRequest)) {
    _watch = watch?.listen(
      apply,
      onError: (Object error, StackTrace stackTrace) =>
          crudLogger.severe('The stream watched by $runtimeType reported an error', error, stackTrace),
    );
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

  final EntityIdOf<T> _idOf;
  StreamSubscription<CrudEvent<T>>? _watch;

  int _generation = 0;
  bool _inFlight = false;

  @override
  Future<void> close() async {
    await _watch?.cancel();
    return super.close();
  }

  /// Applies [event] to the pages already held.
  ///
  /// * [CrudEntityUpdated]: the stored entity replaces the held one with the
  ///   same id, wherever a page holds it, without a read. It keeps its place
  ///   even when the change would move it under the current sort or filter.
  /// * [CrudEntityDeleted]: the entity leaves the page holding it, and every
  ///   held total drops accordingly; a page emptied this way stays held.
  ///   Cursor pages, and offset collections that are held completely, need no
  ///   read for this. Any other offset collection is reread after the removal,
  ///   because the server shifts the later entities and the held page numbers
  ///   would skip one.
  /// * [CrudEntityCreated]: the held pages are dropped and the first page is
  ///   read again - where the entity belongs depends on sort and filter, which
  ///   only the backend knows. Before the first load this does nothing.
  ///
  /// An event whose id no held page shows changes nothing, and an event
  /// arriving while a page is being read ends in a reread, so the landing page
  /// cannot be stale. Ids are matched with `idOf`, so a deleted event whose id
  /// has another runtime type than the entity's id matches nothing, silently.
  ///
  /// This is also the seam for server-sent events: decode them into
  /// [CrudEvent]s and hand them here, or into the hub this cubit watches.
  void apply(CrudEvent<T> event) {
    switch (event) {
      case CrudEntityCreated<T>():
        if (state.status.isInitial) return;
        unawaited(refresh());
      case CrudEntityUpdated<T>(:final entity):
        if (_inFlight) {
          unawaited(refresh());
          return;
        }
        _replaceHeld(entity);
      case CrudEntityDeleted<T>(:final id):
        if (_inFlight) {
          unawaited(refresh());
          return;
        }
        _removeHeld(id);
    }
  }

  void _replaceHeld(T entity) {
    final id = _idOf(entity);
    if (id == null) return;
    var changed = false;
    final pages = state.pages
        .map((page) {
          if (!page.content.any((item) => _idOf(item) == id)) return page;
          changed = true;
          return _withContent(page, [for (final item in page.content) _idOf(item) == id ? entity : item]);
        })
        .toList(growable: false);
    if (changed) emit(state.copyWith(pages: pages, keepError: true));
  }

  void _removeHeld(Object id) {
    // Decided before the removal: cursor pages continue behind their cursor
    // either way, and an offset collection that is held completely cannot
    // shift. Any other offset collection must be reread, or the server-side
    // shift makes the held page numbers skip an entity - and without a total,
    // a page turned non-full would end the listing early.
    final needsReread = state.initialRequest is OffsetPageRequest && (state.pages.lastOrNull?.hasNext ?? false);

    var removed = 0;
    var pages = state.pages
        .map((page) {
          final remaining = page.content.where((item) => _idOf(item) != id).toList(growable: false);
          if (remaining.length == page.content.length) return page;
          removed += page.content.length - remaining.length;
          return _withContent(page, remaining);
        })
        .toList(growable: false);
    if (removed == 0) return;

    // The total describes the whole collection, so every held page drops it.
    pages = pages.map((page) => _lowerTotal(page, removed)).toList(growable: false);
    emit(state.copyWith(pages: pages, keepError: true));
    if (needsReread) unawaited(refresh());
  }

  /// The same page with [content].
  Page<T> _withContent(Page<T> page, List<T> content) => switch (page) {
    final OffsetPage<T> offset => offset.copyWith(content: content),
    final CursorPage<T> cursor => cursor.copyWith(content: content),
  };

  /// The same page with its total, if it reports one, lowered by [removed].
  Page<T> _lowerTotal(Page<T> page, int removed) => switch (page) {
    final OffsetPage<T> offset when offset.totalElements != null => offset.copyWith(
      totalElements: offset.totalElements! - removed,
    ),
    _ => page,
  };

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
