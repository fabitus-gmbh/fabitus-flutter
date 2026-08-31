// What DioCrudErrorMapper does with the errors Dio throws, without a network.
//
//   dart run example/main.dart
import 'package:dio/dio.dart';
import 'package:fabitus_crud_api_dio/fabitus_crud_api_dio.dart';

void main() {
  const mapper = DioCrudErrorMapper();
  final options = RequestOptions(path: '/todos');

  // A Spring Boot style 422, the case the mapper exists for.
  final rejected = DioException.badResponse(
    statusCode: 422,
    requestOptions: options,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: 422,
      data: const {
        'type': 'https://fabit.us/problem/constraint-violation',
        'status': 422,
        'detail': 'The todo could not be saved',
        'violations': [
          {'field': 'title', 'message': 'must not be blank'},
          {'field': 'dueAt', 'message': 'must be in the future'},
        ],
      },
    ),
  );

  final exception = mapper.map(rejected, StackTrace.current);
  print('${exception.runtimeType} (${exception.statusCode})');
  print('  message: ${exception.message}');
  print('  title:   ${exception.violationFor('title')?.message}');
  print('  dueAt:   ${exception.violationFor('dueAt')?.message}');

  // A body that is not a problem detail still yields a typed failure.
  final gateway = DioException.badResponse(
    statusCode: 502,
    requestOptions: options,
    response: Response<dynamic>(requestOptions: options, statusCode: 502, data: '<html>Bad Gateway</html>'),
  );
  print(mapper.map(gateway, StackTrace.current));

  // And so does a request that never arrived.
  print(
    mapper.map(
      DioException(requestOptions: options, type: DioExceptionType.connectionError, message: 'Failed host lookup'),
      StackTrace.current,
    ),
  );
}
