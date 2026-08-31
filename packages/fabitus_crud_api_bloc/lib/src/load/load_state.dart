import 'package:fabitus_crud_api/fabitus_crud_api.dart';

/// What a [LoadCubit] is currently showing.
///
/// Sealed, so a `switch` over it is checked for exhaustiveness - the reason the
/// "success but the data was null" hole of a status-plus-nullable-data state
/// cannot occur here:
///
/// ```dart
/// switch (state) {
///   case LoadInitial() || LoadInProgress(previous: null):
///     return const CircularProgressIndicator();
///   case LoadInProgress(:final previous?):
///     return TodoList(todos: previous, refreshing: true);
///   case LoadSuccess(:final data):
///     return TodoList(todos: data);
///   case LoadFailure(:final error):
///     return Text(error.message);
/// }
/// ```
sealed class LoadState<T> {
  /// Creates a state.
  const LoadState();

  /// The value on hand, whether freshly loaded or kept from before a refresh.
  ///
  /// `null` while the first load is running and after a failure that had
  /// nothing to keep.
  T? get dataOrNull => switch (this) {
    LoadInitial<T>() => null,
    LoadInProgress<T>(:final previous) => previous,
    LoadSuccess<T>(:final data) => data,
    LoadFailure<T>(:final previous) => previous,
  };

  /// What went wrong, or `null` when nothing did.
  CrudException? get errorOrNull => this is LoadFailure<T> ? (this as LoadFailure<T>).error : null;

  /// Where it went wrong, or `null` when nothing did.
  StackTrace? get stackTraceOrNull => this is LoadFailure<T> ? (this as LoadFailure<T>).stackTrace : null;

  /// Field level errors reported by the backend, empty when there are none.
  List<CrudViolation> get violations => errorOrNull?.violations ?? const [];

  /// Nothing has been requested yet.
  bool get isInitial => this is LoadInitial<T>;

  /// A load is running.
  bool get isLoading => this is LoadInProgress<T>;

  /// The last load succeeded.
  bool get isSuccess => this is LoadSuccess<T>;

  /// The last load failed.
  bool get isFailure => this is LoadFailure<T>;

  /// Whether there is something to render, refreshing or not.
  bool get hasData => dataOrNull != null;
}

/// Nothing has been requested yet.
final class LoadInitial<T> extends LoadState<T> {
  /// Creates the initial state.
  const LoadInitial();

  @override
  String toString() => 'LoadInitial<$T>()';

  @override
  bool operator ==(Object other) => other is LoadInitial<T>;

  @override
  int get hashCode => (LoadInitial<T>).hashCode;
}

/// A load is running.
final class LoadInProgress<T> extends LoadState<T> {
  /// Creates a loading state, optionally keeping [previous] on screen.
  const LoadInProgress({this.previous});

  /// What was on screen when the load started, for a refresh that should not
  /// collapse the view to a spinner. `null` for a load that starts from nothing.
  final T? previous;

  @override
  String toString() => 'LoadInProgress<$T>(previous: $previous)';

  @override
  bool operator ==(Object other) => other is LoadInProgress<T> && other.previous == previous;

  @override
  int get hashCode => Object.hash(LoadInProgress<T>, previous);
}

/// The load succeeded.
final class LoadSuccess<T> extends LoadState<T> {
  /// Creates a success state.
  const LoadSuccess(this.data);

  /// The loaded value.
  final T data;

  @override
  String toString() => 'LoadSuccess<$T>($data)';

  @override
  bool operator ==(Object other) => other is LoadSuccess<T> && other.data == data;

  @override
  int get hashCode => Object.hash(LoadSuccess<T>, data);
}

/// The load failed.
///
/// [stackTrace] is deliberately left out of `==`: two failures with the same
/// error are the same state as far as a widget is concerned, and comparing
/// stack traces by identity would rebuild on every retry that fails the same
/// way - and make the state impossible to write down in a test.
final class LoadFailure<T> extends LoadState<T> {
  /// Creates a failure state, optionally keeping [previous] on screen.
  const LoadFailure(this.error, this.stackTrace, {this.previous});

  /// What went wrong.
  final CrudException error;

  /// Where it went wrong.
  final StackTrace stackTrace;

  /// What was on screen when the load started, so a failed refresh can keep
  /// showing stale data with an error beside it rather than losing it.
  final T? previous;

  @override
  String toString() => 'LoadFailure<$T>($error, previous: $previous)';

  @override
  bool operator ==(Object other) => other is LoadFailure<T> && other.error == error && other.previous == previous;

  @override
  int get hashCode => Object.hash(LoadFailure<T>, error, previous);
}
