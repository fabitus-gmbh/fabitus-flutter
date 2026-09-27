import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'auth_exception.dart';
import 'auth_session.dart';

/// How [CognitoAuthClient.signIn] proves the password to Cognito.
///
/// The app client in the user pool has to allow the flow you pick.
enum CognitoAuthFlow {
  /// `USER_PASSWORD_AUTH`: the password goes to Cognito over TLS.
  ///
  /// The default, because [srp] freezes Flutter web: its big integer
  /// arithmetic runs synchronously on the main isolate and blocks the UI for
  /// seconds.
  userPassword('USER_PASSWORD_AUTH'),

  /// `USER_SRP_AUTH`: the password never leaves the device. Fine on mobile and
  /// desktop; on web see [userPassword].
  srp('USER_SRP_AUTH');

  const CognitoAuthFlow(this.cognitoName);

  /// The name Cognito knows the flow by.
  final String cognitoName;
}

/// What a [CognitoAuthClient.signIn] ended with.
sealed class SignInResult {
  const SignInResult();
}

/// The user is signed in.
final class SignedIn extends SignInResult {
  /// Creates a result carrying [session].
  const SignedIn(this.session);

  /// The fresh session.
  final AuthSession session;
}

/// Cognito wants a new password before it completes the sign in - the state of
/// a user an administrator created with a temporary password.
///
/// Answer it with [CognitoAuthClient.completeNewPassword]. The challenge is
/// bound to the sign in that raised it and lives only in memory; after a restart
/// the user signs in again.
final class NewPasswordRequired extends SignInResult {
  /// Creates the challenge. Only [CognitoAuthClient] has a user to pass.
  @internal
  const NewPasswordRequired(this.cognitoUser, {this.requiredAttributes = const []});

  /// The Cognito handle the answer has to go through.
  @internal
  final CognitoUser cognitoUser;

  /// User attributes the pool requires along with the password, such as
  /// `name`. Usually empty.
  final List<String> requiredAttributes;
}

/// Signs in to a Cognito user pool and keeps the tokens fresh.
///
/// Stateless: it hands out [AuthSession]s and forgets them. Holding on to the
/// session, persisting it and reacting to its end is the `AuthCubit`'s job.
///
/// Every failure is thrown as an [AuthException]; nothing from the underlying
/// Cognito library escapes.
///
/// ```dart
/// final client = CognitoAuthClient(
///   userPoolId: 'eu-central-1_AbCdEfGhI',
///   clientId: '1a2b3c4d5e6f7g8h9i0j',
/// );
///
/// switch (await client.signIn('jane@fabit.us', password)) {
///   case SignedIn(:final session):
///     print(session.user.displayName);
///   case NewPasswordRequired() && final challenge:
///     await client.completeNewPassword(challenge, newPassword);
/// }
/// ```
class CognitoAuthClient {
  /// Creates a client for the app client [clientId] of the user pool
  /// [userPoolId].
  ///
  /// The region is read from the pool id. [refreshTokenRotation] has to match
  /// the app client's setting: with rotation on, refreshing goes through
  /// `GetTokensFromRefreshToken`, which hands out a new refresh token each
  /// time. [httpClient] is for tests.
  ///
  /// App clients with a client secret are not supported: a secret shipped in an
  /// app is no secret. Use a public app client.
  CognitoAuthClient({
    required String userPoolId,
    required String clientId,
    this.authFlow = CognitoAuthFlow.userPassword,
    this.refreshTokenRotation = false,
    http.Client? httpClient,
  }) : _pool = CognitoUserPool(
         userPoolId,
         clientId,
         customClient: httpClient == null ? null : Client(region: userPoolId.split('_').first, client: httpClient),
       );

  final CognitoUserPool _pool;

  /// The flow [signIn] uses.
  final CognitoAuthFlow authFlow;

  /// Whether the app client rotates refresh tokens.
  final bool refreshTokenRotation;

  /// Signs in with [username] and [password].
  ///
  /// Returns [SignedIn], or [NewPasswordRequired] when the user still has a
  /// temporary password. Throws an [AuthException] otherwise, with
  /// [AuthFailure.invalidCredentials] for a wrong password or unknown user.
  Future<SignInResult> signIn(String username, String password) async {
    final user = CognitoUser(username, _pool)..authenticationFlowType = authFlow.cognitoName;
    try {
      final session = await user.authenticateUser(AuthenticationDetails(username: username, password: password));
      return SignedIn(_sessionFrom(session));
    } on CognitoUserNewPasswordRequiredException catch (e) {
      return NewPasswordRequired(
        user,
        requiredAttributes: [...?e.requiredAttributes?.map((attribute) => attribute.toString())],
      );
    } on Object catch (e) {
      throw _map(e);
    }
  }

  /// Answers [challenge] with [newPassword], and any [attributes] the pool
  /// requires (see [NewPasswordRequired.requiredAttributes]).
  ///
  /// Throws an [AuthException] with [AuthFailure.invalidPassword] when the user
  /// pool rejects the password; the challenge stays valid then, so the user can
  /// try another. [AuthFailure.noPendingChallenge] means the challenge expired
  /// and the user has to sign in again.
  Future<AuthSession> completeNewPassword(
    NewPasswordRequired challenge,
    String newPassword, {
    Map<String, String> attributes = const {},
  }) async {
    try {
      final session = await challenge.cognitoUser.sendNewPasswordRequiredAnswer(newPassword, attributes);
      return _sessionFrom(session);
    } on Object catch (e) {
      throw _map(e, answeringChallenge: true);
    }
  }

  /// Exchanges the refresh token of [session] for fresh id and access tokens.
  ///
  /// Throws an [AuthException] with [AuthFailure.sessionExpired] when Cognito
  /// rejects the refresh token - it expired, was revoked, or the user is gone.
  /// Any other failure, [AuthFailure.network] above all, leaves the session
  /// intact: try again later.
  Future<AuthSession> refresh(AuthSession session) async {
    final String username;
    try {
      username = session.user.username;
    } on FormatException catch (e) {
      throw AuthException(AuthFailure.sessionExpired, message: 'The stored id token is malformed.', cause: e);
    }
    final user = CognitoUser(username, _pool);
    final refreshToken = CognitoRefreshToken(session.refreshToken);
    try {
      final refreshed = refreshTokenRotation
          ? await user.getTokensFromRefreshToken(refreshToken)
          : await user.refreshSession(refreshToken);
      // A refresh without rotation returns no new refresh token; the old one
      // stays valid.
      return _sessionFrom(refreshed, fallbackRefreshToken: session.refreshToken);
    } on Object catch (e) {
      throw _map(e, refreshing: true);
    }
  }

  /// Revokes the refresh token of [session], so it cannot be used again even if
  /// it was copied off the device.
  ///
  /// Signing out does not require this - dropping the tokens is enough for the
  /// device - but it is what "sign out" should mean when the tokens may have
  /// leaked. The id and access tokens stay valid until they expire; Cognito has
  /// no way to recall them.
  Future<void> revoke(AuthSession session) async {
    try {
      await _pool.client!.request('RevokeToken', {'ClientId': _pool.getClientId(), 'Token': session.refreshToken});
    } on Object catch (e) {
      throw _map(e);
    }
  }

  AuthSession _sessionFrom(CognitoUserSession? session, {String? fallbackRefreshToken}) {
    final idToken = session?.getIdToken().getJwtToken();
    final accessToken = session?.getAccessToken().getJwtToken();
    final refreshToken = session?.getRefreshToken()?.getToken() ?? fallbackRefreshToken;
    if (idToken == null || accessToken == null || refreshToken == null) {
      throw const AuthException(AuthFailure.unknown, message: 'Cognito returned an incomplete session.');
    }
    return AuthSession(idToken: idToken, accessToken: accessToken, refreshToken: refreshToken);
  }

  /// Turns whatever the Cognito library threw into an [AuthException].
  ///
  /// An authorization failure means something different at each step: during a
  /// sign in the credentials are wrong, while [answeringChallenge] the
  /// challenge expired, and while [refreshing] the session is over.
  AuthException _map(Object error, {bool refreshing = false, bool answeringChallenge = false}) {
    if (error is AuthException) return error;
    if (error is CognitoClientException) {
      final failure = switch (error.code) {
        'NotAuthorizedException' ||
        'UserNotFoundException' ||
        'RefreshTokenReuseException' when refreshing => AuthFailure.sessionExpired,
        'NotAuthorizedException' when answeringChallenge => AuthFailure.noPendingChallenge,
        // Cognito reports a locked out user as NotAuthorized, told apart only by
        // the message.
        'NotAuthorizedException' when error.message?.contains('attempts exceeded') ?? false =>
          AuthFailure.tooManyRequests,
        'NotAuthorizedException' || 'UserNotFoundException' => AuthFailure.invalidCredentials,
        'UserNotConfirmedException' => AuthFailure.userNotConfirmed,
        'PasswordResetRequiredException' => AuthFailure.passwordResetRequired,
        'InvalidPasswordException' => AuthFailure.invalidPassword,
        'TooManyRequestsException' ||
        'LimitExceededException' ||
        'TooManyFailedAttemptsException' => AuthFailure.tooManyRequests,
        // The library's own codes for a request that never got a response.
        'NetworkError' || 'Unknown error' => AuthFailure.network,
        _ => AuthFailure.unknown,
      };
      return AuthException(failure, message: error.message, cause: error);
    }
    if (error is CognitoUserConfirmationNecessaryException) {
      return AuthException(AuthFailure.userNotConfirmed, message: error.message, cause: error);
    }
    if (error is CognitoUserException) {
      return AuthException(
        AuthFailure.unsupportedChallenge,
        message: error.challengeName ?? error.message,
        cause: error,
      );
    }
    return AuthException(AuthFailure.unknown, message: error.toString(), cause: error);
  }
}
