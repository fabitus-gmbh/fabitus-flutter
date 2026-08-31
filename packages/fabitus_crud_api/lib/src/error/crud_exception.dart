import 'package:collection/collection.dart';

import 'crud_violation.dart';

/// The base type of every failure a repository reports.
///
/// The hierarchy is `sealed`, so a `switch` over a [CrudException] is checked
/// for exhaustiveness by the compiler:
///
/// ```dart
/// final message = switch (error) {
///   CrudValidationException(:final violations) => violations.join('\n'),
///   CrudNotFoundException() => 'Not found',
///   CrudUnauthorizedException() => 'Please sign in again',
///   _ => error.message,
/// };
/// ```
sealed class CrudException implements Exception {
  /// Creates an exception with a human readable [message].
  const CrudException(this.message, {this.statusCode, this.violations = const [], this.cause});

  /// Builds the exception that matches an HTTP [statusCode].
  ///
  /// Use this from an error mapper for your HTTP client, so that a 404 becomes
  /// a [CrudNotFoundException] and a 422 a [CrudValidationException]. Pass the
  /// backend's message and field errors along; with
  /// `package:fabitus_problem_details` both come out of one problem body.
  factory CrudException.fromStatusCode(
    int statusCode, {
    String? message,
    List<CrudViolation> violations = const [],
    Object? cause,
  }) {
    final text = message ?? 'HTTP $statusCode';
    return switch (statusCode) {
      400 || 422 => CrudValidationException(text, statusCode: statusCode, violations: violations, cause: cause),
      401 => CrudUnauthorizedException(text, statusCode: statusCode, violations: violations, cause: cause),
      403 => CrudForbiddenException(text, statusCode: statusCode, violations: violations, cause: cause),
      404 => CrudNotFoundException(text, statusCode: statusCode, violations: violations, cause: cause),
      409 => CrudConflictException(text, statusCode: statusCode, violations: violations, cause: cause),
      >= 500 => CrudServerException(text, statusCode: statusCode, violations: violations, cause: cause),
      _ => CrudUnknownException(text, statusCode: statusCode, violations: violations, cause: cause),
    };
  }

  /// Human readable description of the failure.
  final String message;

  /// The HTTP status code that caused this exception, when it came from a
  /// remote call.
  final int? statusCode;

  /// Field level validation errors reported by the origin.
  ///
  /// Empty for every failure that is not a validation failure.
  final List<CrudViolation> violations;

  /// The original error this exception was mapped from.
  final Object? cause;

  /// The violation for [field], or `null` when the field has none.
  ///
  /// ```dart
  /// TextFormField(
  ///   decoration: InputDecoration(errorText: error.violationFor('title')?.message),
  /// );
  /// ```
  CrudViolation? violationFor(String field) => violations.firstWhereOrNull((violation) => violation.field == field);

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    return '$runtimeType$status: $message';
  }
}

/// The requested entity does not exist. Maps to HTTP 404.
final class CrudNotFoundException extends CrudException {
  /// Creates a not found exception.
  const CrudNotFoundException(super.message, {super.statusCode, super.violations, super.cause});
}

/// The request was rejected because the payload is invalid. Maps to HTTP 400
/// and 422; inspect [CrudException.violations] for the offending fields.
final class CrudValidationException extends CrudException {
  /// Creates a validation exception.
  const CrudValidationException(super.message, {super.statusCode, super.violations, super.cause});
}

/// The caller is not authenticated. Maps to HTTP 401.
final class CrudUnauthorizedException extends CrudException {
  /// Creates an unauthorized exception.
  const CrudUnauthorizedException(super.message, {super.statusCode, super.violations, super.cause});
}

/// The caller is authenticated but lacks the required permission. Maps to
/// HTTP 403.
final class CrudForbiddenException extends CrudException {
  /// Creates a forbidden exception.
  const CrudForbiddenException(super.message, {super.statusCode, super.violations, super.cause});
}

/// The request conflicts with the current state, for example an optimistic
/// locking failure or a duplicate key. Maps to HTTP 409.
final class CrudConflictException extends CrudException {
  /// Creates a conflict exception.
  const CrudConflictException(super.message, {super.statusCode, super.violations, super.cause});
}

/// The backend failed to process a syntactically valid request. Maps to
/// HTTP 5xx.
final class CrudServerException extends CrudException {
  /// Creates a server exception.
  const CrudServerException(super.message, {super.statusCode, super.violations, super.cause});
}

/// The request never reached the backend, or the connection broke.
final class CrudNetworkException extends CrudException {
  /// Creates a network exception.
  const CrudNetworkException(super.message, {super.statusCode, super.violations, super.cause});
}

/// The request did not complete within the configured timeout.
final class CrudTimeoutException extends CrudException {
  /// Creates a timeout exception.
  const CrudTimeoutException(super.message, {super.statusCode, super.violations, super.cause});
}

/// The request was cancelled by the caller, for example because the widget that
/// started it was disposed.
final class CrudCancelledException extends CrudException {
  /// Creates a cancellation exception.
  const CrudCancelledException(super.message, {super.statusCode, super.violations, super.cause});
}

/// A payload could not be encoded or decoded.
final class CrudSerializationException extends CrudException {
  /// Creates a serialization exception.
  const CrudSerializationException(super.message, {super.statusCode, super.violations, super.cause});
}

/// The repository does not support the requested operation.
///
/// Reported for example by a remote repository whose API exposes no endpoint to
/// list every entity.
final class CrudUnsupportedException extends CrudException {
  /// Creates an unsupported operation exception.
  const CrudUnsupportedException(super.message, {super.statusCode, super.violations, super.cause});
}

/// A failure that does not fit any of the other categories.
final class CrudUnknownException extends CrudException {
  /// Creates an unknown exception.
  const CrudUnknownException(super.message, {super.statusCode, super.violations, super.cause});
}
