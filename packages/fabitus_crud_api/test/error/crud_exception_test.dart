import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

void main() {
  group('CrudException.fromStatusCode', () {
    test('maps the documented status codes', () {
      expect(CrudException.fromStatusCode(400), isA<CrudValidationException>());
      expect(CrudException.fromStatusCode(422), isA<CrudValidationException>());
      expect(CrudException.fromStatusCode(401), isA<CrudUnauthorizedException>());
      expect(CrudException.fromStatusCode(403), isA<CrudForbiddenException>());
      expect(CrudException.fromStatusCode(404), isA<CrudNotFoundException>());
      expect(CrudException.fromStatusCode(409), isA<CrudConflictException>());
      expect(CrudException.fromStatusCode(500), isA<CrudServerException>());
      expect(CrudException.fromStatusCode(503), isA<CrudServerException>());
      expect(CrudException.fromStatusCode(418), isA<CrudUnknownException>());
    });

    test('uses the message it is given, or falls back to the status', () {
      expect(CrudException.fromStatusCode(404, message: 'explicit').message, 'explicit');
      expect(CrudException.fromStatusCode(404).message, 'HTTP 404');
    });

    test('carries the violations it is given', () {
      final exception = CrudException.fromStatusCode(
        422,
        violations: const [CrudViolation(field: 'title', message: 'blank')],
      );

      expect(exception, isA<CrudValidationException>());
      expect(exception.violations.single.field, 'title');
    });
  });

  test('violations default to empty', () {
    expect(const CrudNetworkException('offline').violations, isEmpty);
    expect(const CrudNetworkException('offline').violationFor('title'), isNull);
  });

  test('violationFor finds the violation of a field', () {
    const exception = CrudValidationException(
      'invalid',
      violations: [
        CrudViolation(field: 'title', message: 'must not be blank'),
        CrudViolation(field: 'due', message: 'must be in the future'),
      ],
    );

    expect(exception.violationFor('due')?.message, 'must be in the future');
    expect(exception.violationFor('other'), isNull);
  });

  test('a violation reads as "field: message"', () {
    const violations = [
      CrudViolation(field: 'title', message: 'must not be blank'),
      CrudViolation(field: 'due', message: 'must be in the future'),
    ];

    expect(violations.join('\n'), 'title: must not be blank\ndue: must be in the future');
  });

  test('toString names the type and the status', () {
    expect(const CrudNotFoundException('gone', statusCode: 404).toString(), 'CrudNotFoundException (404): gone');
  });
}
