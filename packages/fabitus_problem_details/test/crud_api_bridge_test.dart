// The bridge between this package and fabitus_crud_api, as documented in both
// READMEs. It lives here as a test rather than as a snippet so it cannot rot:
// fabitus_crud_api is a dev dependency only, the package itself does not use it.
import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_problem_details/fabitus_problem_details.dart';
import 'package:test/test.dart';

/// Converts the violations of an RFC 9457 body into the CRUD model.
///
/// Declared on the nullable type so a body that was not a problem detail simply
/// yields an empty list.
extension ProblemDetailCrudViolations on ProblemDetail? {
  List<CrudViolation> toCrudViolations() => [
    for (final violation in this?.violations ?? const <ConstraintViolation>[])
      CrudViolation(field: violation.field, message: violation.message),
  ];
}

/// What the `CrudErrorMapper` of an app does with a response it got back.
CrudException mapResponse(int statusCode, Object? body) {
  final problem = ProblemDetail.tryParse(body);
  return CrudException.fromStatusCode(statusCode, message: problem?.message, violations: problem.toCrudViolations());
}

void main() {
  test('a 422 problem becomes a validation exception with its violations', () {
    final exception = mapResponse(422, const {
      'type': 'https://fabit.us/problem/constraint-violation',
      'status': 422,
      'detail': 'The todo could not be saved',
      'violations': [
        {'field': 'title', 'message': 'must not be blank'},
        {'field': 'dueAt', 'message': 'must be in the future'},
      ],
    });

    expect(exception, isA<CrudValidationException>());
    expect(exception.message, 'The todo could not be saved');
    expect(exception.violationFor('title')?.message, 'must not be blank');
    expect(exception.violationFor('dueAt')?.message, 'must be in the future');
  });

  test('the general message survives without any violations', () {
    final exception = mapResponse(404, const {'title': 'Not Found', 'status': 404});

    expect(exception, isA<CrudNotFoundException>());
    expect(exception.message, 'Not Found');
    expect(exception.violations, isEmpty);
  });

  test('a body that is not a problem detail still yields a typed failure', () {
    final exception = mapResponse(503, '<html>502 Bad Gateway</html>');

    expect(exception, isA<CrudServerException>());
    expect(exception.message, 'HTTP 503');
    expect(exception.violations, isEmpty);
  });

  test('Spring Boot spelling maps just as well', () {
    final exception = mapResponse(400, const {
      'detail': 'Validation failed',
      'errors': [
        {'propertyPath': 'title', 'defaultMessage': 'must not be blank'},
      ],
    });

    expect(exception, isA<CrudValidationException>());
    expect(exception.violationFor('title')?.message, 'must not be blank');
  });
}
