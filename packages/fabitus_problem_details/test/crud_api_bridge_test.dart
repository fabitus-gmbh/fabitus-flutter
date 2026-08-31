// The mapper this package's README shows for an HTTP client other than Dio.
// It lives here as a test rather than as a snippet so it cannot rot;
// fabitus_crud_api is a dev dependency only, the package itself does not use it.
//
// The Dio case needs no such snippet - fabitus_crud_api_dio ships it, and tests
// it there.
import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_problem_details/fabitus_problem_details.dart';
import 'package:test/test.dart';

/// Stands in for whatever an `http` or generated client throws.
class MyHttpException implements Exception {
  MyHttpException(this.statusCode, this.body);

  final int statusCode;
  final Object? body;
}

class MyCrudErrorMapper implements CrudErrorMapper {
  const MyCrudErrorMapper();

  @override
  CrudException map(Object error, StackTrace stackTrace) {
    if (error is! MyHttpException) {
      return const DefaultCrudErrorMapper().map(error, stackTrace);
    }
    final problem = ProblemDetail.tryParse(error.body);
    return CrudException.fromStatusCode(
      error.statusCode,
      // The general error message, straight from the backend.
      message: problem?.message,
      // The field errors, converted into the CRUD model.
      violations: [
        for (final violation in problem?.violations ?? const <ConstraintViolation>[])
          CrudViolation(field: violation.field, message: violation.message),
      ],
      cause: error,
    );
  }
}

void main() {
  const mapper = MyCrudErrorMapper();
  final stackTrace = StackTrace.current;

  test('a 422 problem becomes a validation exception with its violations', () {
    final exception = mapper.map(
      MyHttpException(422, const {
        'type': 'https://fabit.us/problem/constraint-violation',
        'status': 422,
        'detail': 'The todo could not be saved',
        'violations': [
          {'field': 'title', 'message': 'must not be blank'},
          {'field': 'dueAt', 'message': 'must be in the future'},
        ],
      }),
      stackTrace,
    );

    expect(exception, isA<CrudValidationException>());
    expect(exception.message, 'The todo could not be saved');
    expect(exception.violationFor('title')?.message, 'must not be blank');
    expect(exception.violationFor('dueAt')?.message, 'must be in the future');
  });

  test('the general message survives without any violations', () {
    final exception = mapper.map(MyHttpException(404, const {'title': 'Not Found', 'status': 404}), stackTrace);

    expect(exception, isA<CrudNotFoundException>());
    expect(exception.message, 'Not Found');
    expect(exception.violations, isEmpty);
  });

  test('a body that is not a problem detail still yields a typed failure', () {
    final exception = mapper.map(MyHttpException(503, '<html>Bad Gateway</html>'), stackTrace);

    expect(exception, isA<CrudServerException>());
    expect(exception.message, 'HTTP 503');
    expect(exception.violations, isEmpty);
  });

  test('Spring Boot spelling maps just as well', () {
    final exception = mapper.map(
      MyHttpException(400, const {
        'detail': 'Validation failed',
        'errors': [
          {'propertyPath': 'title', 'defaultMessage': 'must not be blank'},
        ],
      }),
      stackTrace,
    );

    expect(exception, isA<CrudValidationException>());
    expect(exception.violationFor('title')?.message, 'must not be blank');
  });

  test('anything that is not an HTTP failure goes to the fallback', () {
    expect(mapper.map(StateError('boom'), stackTrace), isA<CrudUnknownException>());
  });
}
