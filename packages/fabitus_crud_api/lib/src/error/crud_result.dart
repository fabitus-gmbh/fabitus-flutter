import 'crud_exception.dart';

/// The outcome of a repository call: either [CrudSuccess] or [CrudFailure].
///
/// Repositories never throw; they return a result, so callers cannot forget to
/// handle the failure case. The type is `sealed`, so `switch` is exhaustive:
///
/// ```dart
/// switch (await repository.findById('42')) {
///   case CrudSuccess(:final data):
///     emit(TodoLoaded(data));
///   case CrudFailure(:final error):
///     emit(TodoError(error.message));
/// }
/// ```
sealed class CrudResult<T> {
  /// Creates a result.
  const CrudResult();

  /// Whether the call succeeded.
  bool get isSuccess => this is CrudSuccess<T>;

  /// Whether the call failed.
  bool get isFailure => this is CrudFailure<T>;

  /// The value on success, `null` on failure.
  T? get dataOrNull => switch (this) {
    CrudSuccess<T>(:final data) => data,
    CrudFailure<T>() => null,
  };

  /// The error on failure, `null` on success.
  CrudException? get errorOrNull => switch (this) {
    CrudSuccess<T>() => null,
    CrudFailure<T>(:final error) => error,
  };

  /// The value on success, or throws the [CrudException] on failure.
  ///
  /// Use this at the edge of code that already runs inside a `try`/`catch`.
  T getOrThrow() => switch (this) {
    CrudSuccess<T>(:final data) => data,
    CrudFailure<T>(:final error, :final stackTrace) => Error.throwWithStackTrace(error, stackTrace),
  };

  /// The value on success, or the result of [orElse] on failure.
  T getOrElse(T Function(CrudException error) orElse) => switch (this) {
    CrudSuccess<T>(:final data) => data,
    CrudFailure<T>(:final error) => orElse(error),
  };

  /// Reduces both branches to a single value of type [R].
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(CrudException error, StackTrace stackTrace) onFailure,
  }) => switch (this) {
    CrudSuccess<T>(:final data) => onSuccess(data),
    CrudFailure<T>(:final error, :final stackTrace) => onFailure(error, stackTrace),
  };

  /// Transforms the value of a successful result, passing failures through.
  CrudResult<R> map<R>(R Function(T data) transform) => switch (this) {
    CrudSuccess<T>(:final data) => CrudSuccess<R>(transform(data)),
    CrudFailure<T>(:final error, :final stackTrace) => CrudFailure<R>(error, stackTrace),
  };
}

/// A successful result carrying [data].
final class CrudSuccess<T> extends CrudResult<T> {
  /// Creates a successful result.
  const CrudSuccess(this.data);

  /// The value the call produced.
  final T data;

  @override
  String toString() => 'CrudSuccess<$T>($data)';

  @override
  bool operator ==(Object other) => identical(this, other) || other is CrudSuccess<T> && other.data == data;

  @override
  int get hashCode => Object.hash(CrudSuccess<T>, data);
}

/// A failed result carrying the [error] and the [stackTrace] of its origin.
final class CrudFailure<T> extends CrudResult<T> {
  /// Creates a failed result.
  const CrudFailure(this.error, this.stackTrace);

  /// What went wrong.
  final CrudException error;

  /// Where it went wrong.
  final StackTrace stackTrace;

  /// Returns this failure typed as a `CrudResult<R>`.
  ///
  /// Useful when a repository method has to forward a failure it received from
  /// a call with a different value type.
  CrudFailure<R> cast<R>() => CrudFailure<R>(error, stackTrace);

  @override
  String toString() => 'CrudFailure<$T>($error)';

  @override
  bool operator ==(Object other) => identical(this, other) || other is CrudFailure<T> && other.error == error;

  @override
  int get hashCode => Object.hash(CrudFailure<T>, error);
}

/// A successful result for an operation that produces no value.
///
/// Shorthand for `CrudSuccess<void>(null)`, used by `delete` style methods.
const CrudResult<void> crudVoidSuccess = CrudSuccess<void>(null);
