import 'package:dio/dio.dart';
import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_dio/fabitus_crud_api_dio.dart';
import 'package:fabitus_problem_details/fabitus_problem_details.dart';
import 'package:test/test.dart';

final RequestOptions _options = RequestOptions(path: '/todos');

DioException _badResponse(int? statusCode, Object? body) => DioException.badResponse(
  statusCode: statusCode ?? 0,
  requestOptions: _options,
  response: Response<dynamic>(requestOptions: _options, statusCode: statusCode, data: body),
);

DioException _ofType(DioExceptionType type, {String? message}) =>
    DioException(requestOptions: _options, type: type, message: message);

void main() {
  const mapper = DioCrudErrorMapper();
  final stackTrace = StackTrace.current;

  group('a response with a problem detail', () {
    test('422 becomes a validation exception with its violations', () {
      final exception = mapper.map(
        _badResponse(422, const {
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
      expect(exception.statusCode, 422);
      expect(exception.violationFor('title')?.message, 'must not be blank');
      expect(exception.violationFor('dueAt')?.message, 'must be in the future');
    });

    test('404 becomes a not found exception with the general message', () {
      final exception = mapper.map(_badResponse(404, const {'title': 'Not Found', 'status': 404}), stackTrace);

      expect(exception, isA<CrudNotFoundException>());
      expect(exception.message, 'Not Found');
      expect(exception.violations, isEmpty);
    });

    test('the Spring Boot spelling maps just as well', () {
      final exception = mapper.map(
        _badResponse(400, const {
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

    test('keeps the DioException as the cause', () {
      final dioException = _badResponse(500, const {'title': 'Boom'});

      expect(mapper.map(dioException, stackTrace).cause, same(dioException));
    });
  });

  group('a response without a problem detail', () {
    test('still maps by status code', () {
      final exception = mapper.map(_badResponse(503, '<html>Bad Gateway</html>'), stackTrace);

      expect(exception, isA<CrudServerException>());
      expect(exception.message, 'HTTP 503');
      expect(exception.violations, isEmpty);
    });

    test('an unknown status becomes an unknown exception', () {
      expect(mapper.map(_badResponse(null, null), stackTrace), isA<CrudUnknownException>());
    });

    test('the documented status mapping holds end to end', () {
      CrudException map(int status) => mapper.map(_badResponse(status, null), stackTrace);

      expect(map(400), isA<CrudValidationException>());
      expect(map(401), isA<CrudUnauthorizedException>());
      expect(map(403), isA<CrudForbiddenException>());
      expect(map(404), isA<CrudNotFoundException>());
      expect(map(409), isA<CrudConflictException>());
      expect(map(422), isA<CrudValidationException>());
      expect(map(500), isA<CrudServerException>());
      expect(map(418), isA<CrudUnknownException>());
    });
  });

  group('an error without a response', () {
    test('every timeout becomes a timeout exception', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(mapper.map(_ofType(type), stackTrace), isA<CrudTimeoutException>(), reason: '$type');
      }
    });

    test('a cancellation becomes a cancelled exception', () {
      expect(mapper.map(_ofType(DioExceptionType.cancel), stackTrace), isA<CrudCancelledException>());
    });

    test('everything else becomes a network exception', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.badCertificate,
        DioExceptionType.badResponse,
        DioExceptionType.unknown,
      ]) {
        expect(mapper.map(_ofType(type), stackTrace), isA<CrudNetworkException>(), reason: '$type');
      }
    });

    test('uses the message Dio provides', () {
      final exception = mapper.map(
        _ofType(DioExceptionType.connectionError, message: 'Failed host lookup'),
        stackTrace,
      );

      expect(exception.message, 'Failed host lookup');
    });
  });

  group('anything that is not a DioException', () {
    test('goes to the default fallback', () {
      final exception = mapper.map(StateError('boom'), stackTrace);

      expect(exception, isA<CrudUnknownException>());
      expect(exception.cause, isA<StateError>());
    });

    test('goes to a custom fallback when one is given', () {
      const mapper = DioCrudErrorMapper(fallback: _AlwaysConflict());

      expect(mapper.map(StateError('boom'), stackTrace), isA<CrudConflictException>());
    });

    test('a CrudException still passes through the default fallback', () {
      const cause = CrudNotFoundException('gone');

      expect(mapper.map(cause, stackTrace), same(cause));
    });
  });

  group('problemFrom', () {
    test('can be overridden for a backend with its own format', () {
      const mapper = _LegacyDioCrudErrorMapper();

      final exception = mapper.map(_badResponse(500, const {'errorMessage': 'Legacy boom'}), stackTrace);

      expect(exception.message, 'Legacy boom');
    });
  });

  group('toCrudViolations', () {
    test('converts every violation', () {
      const problem = ProblemDetail(
        violations: [ConstraintViolation(field: 'title', message: 'blank')],
      );

      expect(problem.toCrudViolations(), const [CrudViolation(field: 'title', message: 'blank')]);
    });

    test('yields an empty list for a problem that is null or has none', () {
      expect(ProblemDetail.tryParse('not a problem').toCrudViolations(), isEmpty);
      expect(const ProblemDetail(title: 'x').toCrudViolations(), isEmpty);
    });
  });
}

class _AlwaysConflict implements CrudErrorMapper {
  const _AlwaysConflict();

  @override
  CrudException map(Object error, StackTrace stackTrace) => CrudConflictException('$error', cause: error);
}

class _LegacyDioCrudErrorMapper extends DioCrudErrorMapper {
  const _LegacyDioCrudErrorMapper();

  @override
  ProblemDetail? problemFrom(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map<String, dynamic>) return null;
    return ProblemDetail(detail: body['errorMessage'] as String?);
  }
}
