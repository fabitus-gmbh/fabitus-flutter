import 'package:dio/dio.dart';
import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_problem_details/fabitus_problem_details.dart';
import 'package:meta/meta.dart';

import 'problem_detail_violations.dart';

/// The [CrudErrorMapper] for a repository whose API talks through Dio.
///
/// It turns what Dio throws into the sealed [CrudException] hierarchy:
///
/// * A response with a status code becomes the exception that matches it -
///   404 a [CrudNotFoundException], 422 a [CrudValidationException], 5xx a
///   [CrudServerException] - carrying the message and the field errors read
///   from the body's RFC 9457 problem detail, when it has one.
/// * A timeout becomes a [CrudTimeoutException], a cancellation a
///   [CrudCancelledException], anything else without a response a
///   [CrudNetworkException].
/// * Anything that is not a [DioException] is handed to [fallback].
///
/// ```dart
/// final repository = RemotePagingCrudRepository<Todo, String>(
///   TodoApi(dio),
///   errorMapper: const DioCrudErrorMapper(),
/// );
/// ```
///
/// For a backend that does not speak RFC 9457, subclass and override
/// [problemFrom].
class DioCrudErrorMapper implements CrudErrorMapper {
  /// Creates a mapper that hands non-Dio errors to [fallback].
  const DioCrudErrorMapper({this.fallback = const DefaultCrudErrorMapper()});

  /// Handles everything that is not a [DioException].
  ///
  /// A repository can be wrapped around more than the HTTP client - a codec, a
  /// cache - and those failures still need mapping.
  final CrudErrorMapper fallback;

  @override
  CrudException map(Object error, StackTrace stackTrace) {
    if (error is! DioException) {
      return fallback.map(error, stackTrace);
    }

    final response = error.response;
    if (response != null) {
      final problem = problemFrom(response);
      return CrudException.fromStatusCode(
        response.statusCode ?? 0,
        message: problem?.message,
        violations: problem.toCrudViolations(),
        cause: error,
      );
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => CrudTimeoutException(error.message ?? 'The request timed out', cause: error),
      DioExceptionType.cancel => CrudCancelledException(error.message ?? 'The request was cancelled', cause: error),
      DioExceptionType.badCertificate => CrudNetworkException(
        error.message ?? 'The server certificate was rejected',
        cause: error,
      ),
      DioExceptionType.connectionError || DioExceptionType.badResponse || DioExceptionType.unknown =>
        CrudNetworkException(error.message ?? 'The request did not reach the server', cause: error),
    };
  }

  /// Reads the problem detail from [response], or `null` when the body is not
  /// one.
  ///
  /// Override this for a backend with its own error format:
  ///
  /// ```dart
  /// class LegacyDioCrudErrorMapper extends DioCrudErrorMapper {
  ///   const LegacyDioCrudErrorMapper();
  ///
  ///   @override
  ///   ProblemDetail? problemFrom(Response<dynamic> response) {
  ///     final body = response.data;
  ///     if (body is! Map<String, dynamic>) return null;
  ///     return ProblemDetail(detail: body['errorMessage'] as String?);
  ///   }
  /// }
  /// ```
  @protected
  ProblemDetail? problemFrom(Response<dynamic> response) => ProblemDetail.tryParse(response.data);
}
