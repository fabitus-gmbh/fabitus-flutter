import 'dart:async';

import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Creates, owns and closes a [LoadCubit], and keeps it current.
///
/// The counterpart of `CrudPaginationProvider` for a collection that is read
/// whole. Point [refreshOn] at `CrudService.events` and the list rereads itself
/// whenever something is written, wherever in the app that happened - with
/// [LoadCubit.refresh], so the rows stay on screen while it does.
///
/// ```dart
/// CrudLoadProvider<List<Todo>>(
///   load: repository.findAll,
///   refreshOn: todoService.events,
///   child: CrudLoadedTable<Todo>(columns: columns),
/// );
/// ```
///
/// Filtering a loaded table needs no request, so it belongs on the view: pass a
/// `where` to `CrudLoadedTable` instead.
class CrudLoadProvider<T> extends StatefulWidget {
  /// Provides a cubit reading through [load] to [child].
  const CrudLoadProvider({
    required this.load,
    required this.child,
    this.refreshOn,
    this.loadOnCreate = true,
    super.key,
  });

  /// Reads the value. Captured once.
  final LoadFunction<T> load;

  /// Every event on this stream rereads, keeping what is on screen.
  ///
  /// Events arriving in one turn of the event loop are coalesced into a single
  /// read.
  final Stream<Object?>? refreshOn;

  /// Whether the value is read as soon as the cubit exists.
  final bool loadOnCreate;

  /// What is rendered under the provided cubit.
  final Widget child;

  @override
  State<CrudLoadProvider<T>> createState() => _CrudLoadProviderState<T>();
}

class _CrudLoadProviderState<T> extends State<CrudLoadProvider<T>> {
  late final LoadCubit<T> _cubit = LoadCubit<T>(widget.load, loadOnCreate: widget.loadOnCreate);

  StreamSubscription<Object?>? _refreshes;
  Timer? _pendingRefresh;

  @override
  void initState() {
    super.initState();
    _listenForRefreshes();
  }

  @override
  void didUpdateWidget(CrudLoadProvider<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
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
  Widget build(BuildContext context) => BlocProvider<LoadCubit<T>>.value(value: _cubit, child: widget.child);
}
