/// Username and password login against an AWS Cognito user pool, for apps
/// whose backend sits behind an API Gateway Cognito authorizer.
///
/// [CognitoAuthClient] talks to Cognito; [AuthCubit] holds the session,
/// restores it on start, refreshes it and signs out; [AuthSessionStore] decides
/// where it survives a restart. Attaching the token to requests is left to a
/// transport adapter such as `fabitus_cognito_auth_dio`, through
/// [AuthTokenSource].
///
/// ```dart
/// final auth = AuthCubit(
///   CognitoAuthClient(userPoolId: 'eu-central-1_AbCdEfGhI', clientId: '1a2b3c4d5e6f7g8h9i0j'),
///   store: myStore,
/// );
/// await auth.restore();
/// await auth.signIn('jane@fabit.us', password);
/// ```
library;

export 'src/auth_cubit.dart';
export 'src/auth_exception.dart';
export 'src/auth_session.dart';
export 'src/auth_session_store.dart';
export 'src/auth_state.dart';
export 'src/auth_token_source.dart';
export 'src/auth_user.dart';
export 'src/cognito_auth_client.dart';
export 'src/password_policy.dart';
