/// Dio adapter for `fabitus_cognito_auth`.
///
/// One interceptor: it attaches the Cognito token to API requests, refreshes
/// the session before it expires, and once more when the backend answers 401.
///
/// ```dart
/// final dio = Dio(BaseOptions(baseUrl: 'https://api.fabit.us/todos'));
/// dio.interceptors.add(CognitoAuthInterceptor(authCubit, dio: dio));
/// ```
library;

export 'src/cognito_auth_interceptor.dart';
