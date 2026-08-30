import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

void main() {
  group('ProblemDetail.fromJson', () {
    test('reads the RFC 9457 members', () {
      final problem = ProblemDetail.fromJson(const {
        'type': 'https://fabit.us/problem/bad-request',
        'title': 'Bad Request',
        'status': 400,
        'detail': 'Title must not be blank',
        'instance': '/todos/1',
      });

      expect(problem.type, 'https://fabit.us/problem/bad-request');
      expect(problem.title, 'Bad Request');
      expect(problem.status, 400);
      expect(problem.detail, 'Title must not be blank');
      expect(problem.instance, '/todos/1');
    });

    test('reads violations from "violations"', () {
      final problem = ProblemDetail.fromJson(const {
        'violations': [
          {'field': 'title', 'message': 'must not be blank'},
        ],
      });

      expect(problem.violations.single.field, 'title');
      expect(problem.violations.single.message, 'must not be blank');
    });

    test('reads violations from "errors" as well', () {
      final problem = ProblemDetail.fromJson(const {
        'errors': [
          {'propertyPath': 'title', 'defaultMessage': 'blank'},
        ],
      });

      expect(problem.violations.single.field, 'title');
      expect(problem.violations.single.message, 'blank');
    });

    test('keeps unknown members in extensions', () {
      final problem = ProblemDetail.fromJson(const {
        'title': 'Bad Request',
        'traceId': 'abc-123',
      });

      expect(problem.extensions, {'traceId': 'abc-123'});
      expect(problem.toJson()['traceId'], 'abc-123');
    });

    test('tolerates a missing violations list', () {
      expect(
        ProblemDetail.fromJson(const {'violations': 'nope'}).violations,
        isEmpty,
      );
    });
  });

  group('ProblemDetail.tryParse', () {
    test('parses a JSON object', () {
      expect(ProblemDetail.tryParse(const {'title': 'Nope'})?.title, 'Nope');
    });

    test('parses a Map with non String keys', () {
      final body = <Object, Object?>{'title': 'Nope'};

      expect(ProblemDetail.tryParse(body)?.title, 'Nope');
    });

    test('returns null for a body that is not an object', () {
      expect(ProblemDetail.tryParse('plain text'), isNull);
      expect(ProblemDetail.tryParse(null), isNull);
    });
  });

  test('message falls through detail, title and type', () {
    expect(const ProblemDetail(detail: 'd', title: 't').message, 'd');
    expect(const ProblemDetail(title: 't', type: 'x').message, 't');
    expect(const ProblemDetail(type: 'x').message, 'x');
    expect(const ProblemDetail().message, 'Unknown problem');
  });

  test('violationFor finds the violation of a field', () {
    const problem = ProblemDetail(
      violations: [
        ConstraintViolation(field: 'title', message: 'blank'),
        ConstraintViolation(field: 'due', message: 'past'),
      ],
    );

    expect(problem.violationFor('due')?.message, 'past');
    expect(problem.violationFor('other'), isNull);
  });

  test('copyWith replaces a single member', () {
    const problem = ProblemDetail(title: 'Bad Request', status: 400);

    expect(problem.copyWith(status: 422).status, 422);
    expect(problem.copyWith(status: 422).title, 'Bad Request');
  });

  test('equality is by value, deep for violations', () {
    const a = ProblemDetail(
      title: 'x',
      violations: [ConstraintViolation(field: 'title', message: 'blank')],
    );
    const b = ProblemDetail(
      title: 'x',
      violations: [ConstraintViolation(field: 'title', message: 'blank')],
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('a violation reads as "field: message"', () {
    const violations = [
      ConstraintViolation(field: 'title', message: 'must not be blank'),
      ConstraintViolation(field: 'due', message: 'must be in the future'),
    ];

    expect(
      violations.join('\n'),
      'title: must not be blank\ndue: must be in the future',
    );
  });

  test('toJson omits absent members', () {
    expect(const ProblemDetail(title: 'Only').toJson(), {'title': 'Only'});
  });
}
