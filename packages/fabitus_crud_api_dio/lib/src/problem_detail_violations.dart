import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_problem_details/fabitus_problem_details.dart';

/// Converts the violations of an RFC 9457 body into the CRUD model.
///
/// Declared on the nullable type, so a body that was not a problem detail at
/// all simply yields an empty list:
///
/// ```dart
/// ProblemDetail.tryParse(response.data).toCrudViolations();
/// ```
///
/// This is the whole bridge between `fabitus_problem_details` and
/// `fabitus_crud_api`. It has nothing to do with Dio and is exported here only
/// because this is the package that already depends on both; with another HTTP
/// client, copy these four lines.
extension ProblemDetailCrudViolations on ProblemDetail? {
  /// The violations of this problem, as [CrudViolation]s.
  List<CrudViolation> toCrudViolations() => [
    for (final violation in this?.violations ?? const <ConstraintViolation>[])
      CrudViolation(field: violation.field, message: violation.message),
  ];
}
