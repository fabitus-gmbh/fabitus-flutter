/// Test support for code on top of `fabitus_cognito_auth`: a fake Cognito
/// backend and fake tokens, so an `AuthCubit` - and the login page, route guard
/// or interceptor around it - can be tested without a user pool.
///
/// ```dart
/// import 'package:fabitus_cognito_auth/testing.dart';
/// ```
library;

export 'src/testing/fake_cognito.dart';
