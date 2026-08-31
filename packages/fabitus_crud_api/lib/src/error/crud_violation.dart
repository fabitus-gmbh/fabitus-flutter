import 'package:freezed_annotation/freezed_annotation.dart';

part 'crud_violation.freezed.dart';

/// A single field level validation error attached to a [CrudException].
///
/// Deliberately transport agnostic: a backend rejecting a `POST` produces these,
/// and so does a local repository that validates before it stores. Mapping a
/// wire format onto them - RFC 9457 `violations`, a GraphQL error extension, a
/// gRPC `BadRequest.FieldViolation` - is the job of the [CrudErrorMapper], and
/// `package:fabitus_problem_details` covers the RFC 9457 case.
///
/// [toString] is the compact `field: message` form, so a list of violations can
/// be joined straight into a message.
@Freezed(toStringOverride: false)
abstract class CrudViolation with _$CrudViolation {
  /// Creates a violation for [field] with the given [message].
  const factory CrudViolation({
    /// Name of the offending property, for example `title` or `address.zip`.
    required String field,

    /// Human readable description of what is wrong with [field].
    required String message,
  }) = _CrudViolation;

  const CrudViolation._();

  @override
  String toString() => '$field: $message';
}
