import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../load/load_cubit.dart';
import '../load/load_state.dart';
import 'crud_error_view.dart';

/// Renders the three states of a [LoadCubit] without an `if` chain per screen.
///
/// ```dart
/// BlocProvider(
///   create: (_) => LoadCubit<List<Todo>>(repository.findAll, loadOnCreate: true),
///   child: LoadBuilder<List<Todo>>(
///     builder: (context, todos) => TodoList(todos: todos),
///   ),
/// );
/// ```
///
/// The cubit is read from the enclosing [BlocProvider] unless one is passed
/// explicitly. Defaults are a centred progress indicator while loading and a
/// [CrudErrorView] with a retry button on failure; [onLoading] and [onError]
/// replace either.
///
/// During a refresh started with [LoadCubit.refresh] the previous value is still
/// rendered - [builder] is called with it and [refreshing] is `true` - so the
/// screen does not collapse to a spinner and back.
class LoadBuilder<T> extends StatelessWidget {
  /// Renders the states of [cubit], or of the one in the enclosing provider.
  const LoadBuilder({required this.builder, this.cubit, this.onLoading, this.onError, super.key});

  /// Renders the value.
  ///
  /// [refreshing] is `true` while a background refresh is running, for a subtle
  /// indicator over content that is still valid.
  final Widget Function(BuildContext context, T data, {bool refreshing}) builder;

  /// The cubit to watch. Read from the enclosing provider when omitted.
  final LoadCubit<T>? cubit;

  /// Renders the state where there is nothing yet to show.
  final WidgetBuilder? onLoading;

  /// Renders a failure. [retry] reloads.
  final Widget Function(BuildContext context, CrudException error, VoidCallback retry)? onError;

  @override
  Widget build(BuildContext context) {
    final cubit = this.cubit;
    return cubit == null
        ? BlocBuilder<LoadCubit<T>, LoadState<T>>(builder: _build)
        : BlocBuilder<LoadCubit<T>, LoadState<T>>(bloc: cubit, builder: _build);
  }

  Widget _build(BuildContext context, LoadState<T> state) {
    void retry() => (cubit ?? context.read<LoadCubit<T>>()).load();

    return switch (state) {
      LoadSuccess<T>(:final data) => builder(context, data, refreshing: false),
      // A refresh that kept its data keeps rendering it.
      LoadInProgress<T>(previous: final data?) => builder(context, data, refreshing: true),
      LoadFailure<T>(previous: final data?) => builder(context, data, refreshing: false),
      LoadFailure<T>(:final error) =>
        onError?.call(context, error, retry) ?? CrudErrorView(error: error, onRetry: retry),
      LoadInitial<T>() ||
      LoadInProgress<T>() => onLoading?.call(context) ?? const Center(child: CircularProgressIndicator()),
    };
  }
}
