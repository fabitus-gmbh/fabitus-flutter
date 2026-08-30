import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

void main() {
  group('CrudException.fromStatusCode', () {
    test('maps the documented status codes', () {
      expect(CrudException.fromStatusCode(400), isA<CrudValidationException>());
      expect(CrudException.fromStatusCode(422), isA<CrudValidationException>());
      expect(
        CrudException.fromStatusCode(401),
        isA<CrudUnauthorizedException>(),
      );
      expect(CrudException.fromStatusCode(403), isA<CrudForbiddenException>());
      expect(CrudException.fromStatusCode(404), isA<CrudNotFoundException>());
      expect(CrudException.fromStatusCode(409), isA<CrudConflictException>());
      expect(CrudException.fromStatusCode(500), isA<CrudServerException>());
      expect(CrudException.fromStatusCode(503), isA<CrudServerException>());
      expect(CrudException.fromStatusCode(418), isA<CrudUnknownException>());
    });

    test('prefers the explicit message over the problem detail', () {
      final exception = CrudException.fromStatusCode(
        404,
        message: 'explicit',
        problem: const ProblemDetail(detail: 'from problem'),
      );

      expect(exception.message, 'explicit');
    });

    test('falls back to the problem detail, then to the status', () {
      expect(
        CrudException.fromStatusCode(
          404,
          problem: const ProblemDetail(detail: 'from problem'),
        ).message,
        'from problem',
      );
      expect(CrudException.fromStatusCode(404).message, 'HTTP 404');
    });

    test('exposes the violations of a validation problem', () {
      final exception = CrudException.fromStatusCode(
        422,
        problem: const ProblemDetail(
          violations: [ConstraintViolation(field: 'title', message: 'blank')],
        ),
      );

      expect(exception.violations.single.field, 'title');
    });
  });

  test('violations default to empty', () {
    expect(const CrudNetworkException('offline').violations, isEmpty);
  });

  test('toString names the type and the status', () {
    expect(
      const CrudNotFoundException('gone', statusCode: 404).toString(),
      'CrudNotFoundException (404): gone',
    );
  });
}
