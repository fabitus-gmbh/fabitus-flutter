import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth_session.dart';
import '../cognito_auth_client.dart';

/// Builds an unsigned JWT carrying [claims], expiring at [expiresAt].
///
/// Good enough for everything on the client side, which reads tokens without
/// verifying them.
String fakeJwt(Map<String, dynamic> claims, {required DateTime expiresAt}) {
  String part(Object value) => base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');
  return [
    part({'alg': 'none'}),
    part({...claims, 'exp': expiresAt.millisecondsSinceEpoch ~/ 1000}),
    'signature',
  ].join('.');
}

/// A session for [username], expiring [validFor] from now, with the refresh
/// token [refreshToken] and the Cognito [groups].
///
/// The id token carries `sub`, `cognito:username`, `email` (`<username>@fabit.us`)
/// and `cognito:groups`.
AuthSession fakeSession(
  String username, {
  Duration validFor = const Duration(hours: 1),
  String refreshToken = 'refresh-1',
  List<String> groups = const [],
}) {
  final expiresAt = DateTime.now().add(validFor);
  return AuthSession(
    idToken: fakeJwt({
      'sub': 'sub-$username',
      'cognito:username': username,
      'email': '$username@fabit.us',
      'cognito:groups': groups,
    }, expiresAt: expiresAt),
    accessToken: fakeJwt({'sub': 'sub-$username', 'username': username}, expiresAt: expiresAt),
    refreshToken: refreshToken,
  );
}

/// One call the fake received.
typedef CognitoCall = ({String operation, Map<String, dynamic> body});

/// Answers Cognito's JSON protocol in memory, for testing code on top of
/// [CognitoAuthClient] - an `AuthCubit`, a login page - without a user pool.
///
/// Each operation is answered by the matching handler; an operation without a
/// handler is answered with an error, which surfaces as `AuthFailure.unknown`.
/// Every call is recorded in [calls].
///
/// ```dart
/// final cognito = FakeCognito()
///   ..initiateAuth = (_) => FakeCognito.authenticated(fakeSession('jane'));
/// final auth = AuthCubit(cognito.client());
///
/// await auth.signIn('jane', 'secret');
/// expect(auth.state.isAuthenticated, isTrue);
/// ```
class FakeCognito {
  /// A user pool id in the format Cognito uses; the region is read from it.
  static const userPoolId = 'eu-central-1_TestPool1';

  /// The app client id of [client].
  static const clientId = 'test-client-id';

  /// Handles `InitiateAuth`, for both sign in and refresh.
  http.Response Function(Map<String, dynamic> body)? initiateAuth;

  /// Handles `RespondToAuthChallenge`.
  http.Response Function(Map<String, dynamic> body)? respondToAuthChallenge;

  /// Handles `GetTokensFromRefreshToken`.
  http.Response Function(Map<String, dynamic> body)? getTokensFromRefreshToken;

  /// Handles `RevokeToken`.
  http.Response Function(Map<String, dynamic> body)? revokeToken;

  /// Every call received, in order.
  final List<CognitoCall> calls = [];

  /// The operations received, in order.
  List<String> get operations => [for (final call in calls) call.operation];

  /// The HTTP client behind [client], for a [CognitoAuthClient] of your own.
  late final http.Client httpClient = MockClient((request) async {
    final operation = request.headers['X-Amz-Target']!.split('.').last;
    final body = json.decode(request.body) as Map<String, dynamic>;
    calls.add((operation: operation, body: body));
    final handler = switch (operation) {
      'InitiateAuth' => initiateAuth,
      'RespondToAuthChallenge' => respondToAuthChallenge,
      'GetTokensFromRefreshToken' => getTokensFromRefreshToken,
      'RevokeToken' => revokeToken,
      _ => null,
    };
    return handler?.call(body) ?? error('UnexpectedOperation', 'No handler for $operation');
  });

  /// A client wired to this fake.
  CognitoAuthClient client({bool refreshTokenRotation = false}) => CognitoAuthClient(
    userPoolId: userPoolId,
    clientId: clientId,
    refreshTokenRotation: refreshTokenRotation,
    httpClient: httpClient,
  );

  /// A successful authentication result carrying [session]'s tokens. Leave
  /// [includeRefreshToken] off for a refresh, which Cognito answers without
  /// one.
  static http.Response authenticated(AuthSession session, {bool includeRefreshToken = true}) => http.Response(
    json.encode({
      'AuthenticationResult': {
        'IdToken': session.idToken,
        'AccessToken': session.accessToken,
        if (includeRefreshToken) 'RefreshToken': session.refreshToken,
        'ExpiresIn': 3600,
        'TokenType': 'Bearer',
      },
      'ChallengeParameters': <String, dynamic>{},
    }),
    200,
  );

  /// The NEW_PASSWORD_REQUIRED challenge.
  static http.Response newPasswordChallenge({List<String> requiredAttributes = const []}) => http.Response(
    json.encode({
      'ChallengeName': 'NEW_PASSWORD_REQUIRED',
      'Session': 'challenge-session',
      'ChallengeParameters': {
        'userAttributes': json.encode({'email': 'jane@fabit.us'}),
        'requiredAttributes': json.encode(requiredAttributes),
      },
    }),
    200,
  );

  /// An error response of type [code].
  static http.Response error(String code, String message, {int status = 400}) =>
      http.Response(json.encode({'__type': code, 'message': message}), status);

  /// An empty success, as `RevokeToken` returns.
  static http.Response ok() => http.Response('{}', 200);
}
