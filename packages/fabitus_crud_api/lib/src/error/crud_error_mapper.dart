import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'crud_exception.dart';
import 'crud_result.dart';

final Logger _logger = Logger('fabitus_crud_api');

/// Translates an arbitrary thrown object into a [CrudException].
///
/// Every repository takes a mapper, which is where knowledge about the
/// transport lives. The package itself has no HTTP dependency; supply a mapper
/// for your client. A Dio mapper is roughly:
///
/// ```dart
/// class DioCrudErrorMapper implements CrudErrorMapper {
///   const DioCrudErrorMapper();
///
///   @override
///   CrudException map(Object error, StackTrace stackTrace) {
///     if (error is! DioException) {
///       return const DefaultCrudErrorMapper().map(error, stackTrace);
///     }
///     final response = error.response;
///     if (response != null) {
///       return CrudException.fromStatusCode(
///         response.statusCode ?? 0,
///         problem: ProblemDetail.tryParse(response.data),
///         cause: error,
///       );
///     }
///     return switch (error.type) {
///       DioExceptionType.connectionTimeout ||
///       DioExceptionType.sendTimeout ||
///       DioExceptionType.receiveTimeout =>
///         CrudTimeoutException(error.message ?? 'Timeout', cause: error),
///       DioExceptionType.cancel =>
///         CrudCancelledException('Request cancelled', cause: error),
///       _ => CrudNetworkException(error.message ?? 'Network error', cause: error),
///     };
///   }
/// }
/// ```
abstract interface class CrudErrorMapper {
  /// Maps [error] and its [stackTrace] to a [CrudException].
  CrudException map(Object error, StackTrace stackTrace);
}

/// The transport agnostic mapper used when no other one is supplied.
///
/// It recognises errors that any Dart program can produce and falls back to
/// [CrudUnknownException]. Wrap it in your own mapper to add transport specific
/// handling, as shown on [CrudErrorMapper].
class DefaultCrudErrorMapper implements CrudErrorMapper {
  /// Creates the default mapper.
  const DefaultCrudErrorMapper();

  @override
  CrudException map(Object error, StackTrace stackTrace) => switch (error) {
    final CrudException exception => exception,
    TimeoutException(:final message) => CrudTimeoutException(message ?? 'The operation timed out', cause: error),
    FormatException(:final message) => CrudSerializationException(message, cause: error),
    JsonUnsupportedObjectError() => CrudSerializationException('Value cannot be encoded as JSON', cause: error),
    _ => CrudUnknownException('$error', cause: error),
  };
}

/// Runs [action] and converts anything it throws into a [CrudFailure].
///
/// This is the single place where repositories turn exceptions into results.
/// Use it when you extend a repository with your own queries:
///
/// ```dart
/// class TodoRepository extends RemotePagingCrudRepository<Todo, String> {
///   TodoRepository(this._api) : super(_api);
///
///   final TodoApi _api;
///
///   Future<CrudResult<Page<Todo>>> search(String query, PageRequest page) =>
///       guardCrud(() => _api.search(query, page), errorMapper: errorMapper);
/// }
/// ```
Future<CrudResult<T>> guardCrud<T>(
  Future<T> Function() action, {
  CrudErrorMapper errorMapper = const DefaultCrudErrorMapper(),
}) async {
  try {
    return CrudSuccess<T>(await action());
  } catch (error, stackTrace) {
    final exception = errorMapper.map(error, stackTrace);
    _logger.severe('CRUD operation for $T failed', exception, stackTrace);
    return CrudFailure<T>(exception, stackTrace);
  }
}
