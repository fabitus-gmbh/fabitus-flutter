// Calls an API behind a Cognito authorizer.
//
//   dart run example/main.dart <user pool id> <app client id> <username> <password> <url>
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:fabitus_cognito_auth_dio/fabitus_cognito_auth_dio.dart';

Future<void> main(List<String> args) async {
  if (args.length != 5) {
    stderr.writeln('usage: dart run example/main.dart <user pool id> <app client id> <username> <password> <url>');
    exitCode = 64;
    return;
  }

  final auth = AuthCubit(CognitoAuthClient(userPoolId: args[0], clientId: args[1]));
  await auth.restore();
  await auth.signIn(args[2], args[3]);
  if (!auth.state.isAuthenticated) {
    print('Not signed in: ${auth.state.errorOrNull}');
    exitCode = 1;
    return;
  }

  final url = Uri.parse(args[4]);
  final dio = Dio(BaseOptions(baseUrl: '${url.scheme}://${url.authority}'));
  dio.interceptors.add(CognitoAuthInterceptor(auth, dio: dio));

  try {
    final response = await dio.getUri<dynamic>(url);
    print('${response.statusCode}: ${response.data}');
  } on DioException catch (e) {
    print('${e.response?.statusCode}: ${e.response?.data ?? e.message}');
    exitCode = 1;
  } finally {
    await auth.close();
  }
}
