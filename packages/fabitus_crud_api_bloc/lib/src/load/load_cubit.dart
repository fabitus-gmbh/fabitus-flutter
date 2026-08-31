import 'dart:async';

import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'load_state.dart';

/// Loads one value, the way a repository returns it.
typedef LoadFunction<T> = Future<CrudResult<T>> Function();

/// Holds one loaded value and the status of loading it.
///
/// A `Cubit` rather than a `Bloc` on purpose: there is one thing to do, and
/// `cubit.load()` says it better than `bloc.add(const ReloadData())` while
/// costing an event class, a state class and a handler less. See the README for
/// the cases where a `Bloc` still earns its keep.
///
/// One cubit covers a single value and a list alike - `LoadCubit<Todo>` and
/// `LoadCubit<List<Todo>>` - so no separate list variant is needed:
///
/// ```dart
/// LoadCubit<List<Todo>>(repository.findAll, loadOnCreate: true);
/// LoadCubit<Todo>(() => repository.findById(id), loadOnCreate: true);
/// LoadCubit<Page<Todo>>(() => repository.findPage(request));
/// ```
///
/// Overlapping loads are safe: a response that arrives after a newer load
/// started is dropped, so the last call always wins.
class LoadCubit<T> extends Cubit<LoadState<T>> {
  /// Creates a cubit that calls [load] to get its value.
  ///
  /// Set [loadOnCreate] to start loading immediately, which is what a page that
  /// exists to show one thing wants. Leave it off when the load depends on
  /// something the caller has yet to supply.
  ///
  /// That first load starts on the next microtask rather than inside the
  /// constructor, so [LoadInitial] and the loading state that follows are both
  /// observable - a widget subscribing in the same frame still sees the spinner,
  /// and a test can write the whole sequence down.
  LoadCubit(this._load, {bool loadOnCreate = false}) : super(LoadInitial<T>()) {
    if (loadOnCreate) {
      scheduleMicrotask(() {
        if (!isClosed) load();
      });
    }
  }

  final LoadFunction<T> _load;

  /// Counts calls, so a response from an overtaken load can be recognised.
  int _generation = 0;

  /// Loads the value.
  ///
  /// [showLoading] decides what happens to what is already on screen. `true`
  /// clears it and shows a spinner; `false` keeps it and marks the state as
  /// loading, which is what a background refresh wants - a poll, or a reload
  /// after an inline change that already confirmed itself. The first load has
  /// nothing to keep either way.
  Future<void> load({bool showLoading = true}) async {
    final generation = ++_generation;
    final previous = state.dataOrNull;

    emit(LoadInProgress<T>(previous: showLoading ? null : previous));

    final result = await _load();

    // A newer load started while this one was in flight, or the cubit is gone.
    if (generation != _generation || isClosed) return;

    switch (result) {
      case CrudSuccess<T>(:final data):
        emit(LoadSuccess<T>(data));
      case CrudFailure<T>(:final error, :final stackTrace):
        emit(LoadFailure<T>(error, stackTrace, previous: previous));
    }
  }

  /// Reloads without clearing what is on screen.
  ///
  /// Shorthand for `load(showLoading: false)`.
  Future<void> refresh() => load(showLoading: false);
}
