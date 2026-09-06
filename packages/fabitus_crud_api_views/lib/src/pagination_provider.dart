import 'dart:async';

import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Creates, owns and closes a [PaginationCubit], and keeps it in step with the
/// widget tree.
///
/// The `BlocProvider(create: ...)` this replaces was not only boilerplate; it
/// also left three things to do by hand, each of which is easy to get wrong:
///
/// * **Filtering.** [filter] is a widget property, so a search field only has to
///   rebuild. The cubit is told when the value actually changes - not on every
///   rebuild - and reading starts over at page one, which is the only sensible
///   thing after a filter change.
/// * **Page size and sort.** Same for [pageRequest].
/// * **Staying current.** Point [refreshOn] at
///   `CrudService.events` and the list rereads itself whenever something is
///   created, updated or deleted, wherever in the app that happened.
///
/// ```dart
/// CrudPaginationProvider<Todo, TodoFilter>(
///   loadPage: (request, filter) => repository.search(filter, request),
///   filter: TodoFilter(query: _query),
///   pageRequest: OffsetPageRequest(size: 25, sort: Sort.by('title')),
///   refreshOn: todoService.events,
///   child: CrudPaginatedTable<Todo, TodoFilter>(columns: columns),
/// );
/// ```
///
/// It provides the cubit; the view underneath finds it. Compose it with whichever
/// view fits - a table, an endless scroll, your own widget - rather than reaching
/// for a variant of this class per view.
///
/// [F] needs a meaningful `==` for the filter change to be noticed, which a
/// `freezed` filter, a record or a [String] all have. Use `void` and pass `null`
/// when there is nothing to filter by.
class CrudPaginationProvider<T, F> extends StatefulWidget {
  /// Provides a cubit reading pages through [loadPage] to [child].
  const CrudPaginationProvider({
    required this.loadPage,
    required this.filter,
    required this.child,
    this.pageRequest = const OffsetPageRequest(size: 20),
    this.refreshOn,
    this.loadOnCreate = true,
    super.key,
  });

  /// Reads one page. Captured once - put what varies in [filter].
  final LoadPageFunction<T, F> loadPage;

  /// What to filter by. A change starts over at the first page.
  final F filter;

  /// How the first page is read, and the template for size and sort.
  ///
  /// An [OffsetPageRequest] or a [CursorPageRequest]; a change starts over.
  final PageRequest pageRequest;

  /// Every event on this stream rereads the first page.
  ///
  /// Typed loosely on purpose: `CrudService.events` fits, and so does any other
  /// stream that means "something changed". Events arriving in one turn of the
  /// event loop are coalesced into a single read, so a bulk delete that
  /// announces ten deletions costs one request.
  final Stream<Object?>? refreshOn;

  /// Whether the first page is read as soon as the cubit exists.
  final bool loadOnCreate;

  /// What is rendered under the provided cubit.
  final Widget child;

  @override
  State<CrudPaginationProvider<T, F>> createState() => _CrudPaginationProviderState<T, F>();
}

class _CrudPaginationProviderState<T, F> extends State<CrudPaginationProvider<T, F>> {
  late final PaginationCubit<T, F> _cubit = PaginationCubit<T, F>(
    loadPage: widget.loadPage,
    initialRequest: widget.pageRequest,
    initialFilter: widget.filter,
    loadOnCreate: widget.loadOnCreate,
  );

  StreamSubscription<Object?>? _refreshes;

  /// Collapses a burst of events into one read. Timers run after microtasks, so
  /// everything announced in the same turn arrives before this fires.
  Timer? _pendingRefresh;

  @override
  void initState() {
    super.initState();
    _listenForRefreshes();
  }

  @override
  void didUpdateWidget(CrudPaginationProvider<T, F> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // One call whichever of the two changed: updateRequest alone would keep the
    // cubit's old filter, and calling both in turn would read the first page
    // twice.
    if (oldWidget.pageRequest != widget.pageRequest || oldWidget.filter != widget.filter) {
      _cubit.updateQuery(widget.pageRequest, widget.filter);
    }

    if (oldWidget.refreshOn != widget.refreshOn) _listenForRefreshes();
  }

  void _listenForRefreshes() {
    _refreshes?.cancel();
    _refreshes = widget.refreshOn?.listen((_) {
      _pendingRefresh?.cancel();
      _pendingRefresh = Timer(Duration.zero, () {
        if (!_cubit.isClosed) _cubit.refresh();
      });
    });
  }

  @override
  void dispose() {
    _pendingRefresh?.cancel();
    _refreshes?.cancel();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<PaginationCubit<T, F>>.value(value: _cubit, child: widget.child);
}
