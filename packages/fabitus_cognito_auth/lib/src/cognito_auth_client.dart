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

/// A one-time code Cognito sent by e-mail, waiting to be answered.
///
/// Answer it with [CognitoAuthClient.submitEmailCode]. The challenge is bound
/// to the Cognito auth session that sent the code and lives only in memory;
/// after a restart, request a new code.
final class EmailCodeChallenge {
  /// Creates the challenge. Only [CognitoAuthClient] has a session to pass.
  @internal
  const EmailCodeChallenge({required this.username, required this.session, this.destination, String? answerUsername})
    : answerUsername = answerUsername ?? username;

  /// The address the code was requested for, as it was entered.
  final String username;

  /// Where Cognito sent the code, masked - such as `j***@f***` - or `null`
  /// when Cognito did not say.
  final String? destination;

  /// The Cognito auth session the answer has to carry.
  @internal
  final String session;

  /// The user name the answer has to carry: the one Cognito resolved, when it
  /// named one, else [username].
  @internal
  final String answerUsername;
}

/// Signs in to a Cognito user pool and keeps the tokens fresh.
///
/// Stateless: it hands out [AuthSession]s and forgets them. Holding on to the
/// session, persisting it and reacting to its end is the `AuthCubit`'s job.
///
/// Every failure is thrown as an [AuthException]; nothing from the underlying
/// Cognito library escapes.
///
/// Besides the password, [requestEmailCode] and [submitEmailCode] sign in with a
/// one-time code sent by e-mail (choice-based authentication). That needs an
/// app client with `ALLOW_USER_AUTH` and `ALLOW_REFRESH_TOKEN_AUTH`, a user pool
/// on the Essentials or Plus tier with `EMAIL_OTP` among the allowed first
/// factors of its sign-in policy, and Cognito sending e-mail through SES
/// (`email_sending_account = DEVELOPER`). Users must not be required to use MFA.
/// Set `PreventUserExistenceErrors` to `ENABLED` on the app client
/// (`prevent_user_existence_errors = "ENABLED"`): without it Cognito reports an
/// unknown address as such, and the form can be used to probe for accounts.
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

  /// Asks Cognito to e-mail a one-time code to [username].
  ///
  /// Returns the challenge to answer with [submitEmailCode]. Calling it again
  /// sends a new code and starts a new challenge; the old one is of no use.
  /// Throws an [AuthException] with [AuthFailure.unsupportedChallenge] when the
  /// pool offers no e-mail code to that user, [AuthFailure.invalidCredentials]
  /// for an unknown user or one that may not sign in, and
  /// [AuthFailure.tooManyRequests] when Cognito throttles the requests.
  Future<EmailCodeChallenge> requestEmailCode(String username) async {
    try {
      final response =
          (await _pool.client!.request('InitiateAuth', {
                'AuthFlow': 'USER_AUTH',
                'ClientId': _pool.getClientId(),
                'AuthParameters': {'USERNAME': username, 'PREFERRED_CHALLENGE': 'EMAIL_OTP'},
              }))
              as Map<String, dynamic>;
      final challengeName = response['ChallengeName'] as String?;
      if (challengeName != 'EMAIL_OTP') {
        throw AuthException(AuthFailure.unsupportedChallenge, message: challengeName ?? 'No challenge');
      }
      final parameters = (response['ChallengeParameters'] as Map<String, dynamic>?) ?? const {};
      return EmailCodeChallenge(
        username: username,
        destination: parameters['CODE_DELIVERY_DESTINATION'] as String?,
        session: response['Session'] as String,
        answerUsername: parameters['USERNAME'] as String?,
      );
    } on Object catch (e) {
      throw _map(e);
    }
  }

  /// Answers [challenge] with the [code] from the e-mail.
  ///
  /// Throws an [AuthException] with [AuthFailure.invalidCode] for a wrong code,
  /// [AuthFailure.codeExpired] when the code or its auth session ran out, and
  /// [AuthFailure.tooManyRequests] when Cognito throttles the user. A wrong code
  /// does not end the challenge - Cognito allows a few attempts. After too many,
  /// request a new code; whether Cognito then answers `tooManyRequests` or
  /// `codeExpired` has not been verified against a real pool.
  Future<AuthSession> submitEmailCode(EmailCodeChallenge challenge, String code) async {
    try {
      final response =
          (await _pool.client!.request('RespondToAuthChallenge', {
                'ClientId': _pool.getClientId(),
                'ChallengeName': 'EMAIL_OTP',
                'Session': challenge.session,
                'ChallengeResponses': {'USERNAME': challenge.answerUsername, 'EMAIL_OTP_CODE': code},
              }))
              as Map<String, dynamic>;
      final result = response['AuthenticationResult'] as Map<String, dynamic>?;
      if (result == null) {
        throw AuthException(
          AuthFailure.unsupportedChallenge,
          message: response['ChallengeName'] as String? ?? 'No authentication result',
        );
      }
      return _sessionFrom(
        CognitoUserSession(
          CognitoIdToken(result['IdToken'] as String?),
          CognitoAccessToken(result['AccessToken'] as String?),
          refreshToken: result['RefreshToken'] == null ? null : CognitoRefreshToken(result['RefreshToken'] as String),
        ),
      );
    } on Object catch (e) {
      throw _map(e, answeringEmailCode: true);
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

  static bool _mentionsSession(CognitoClientException error) =>
      error.message?.toLowerCase().contains('session') ?? false;

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
  /// challenge expired, while [refreshing] the session is over, and while
  /// [answeringEmailCode] the code is wrong or the auth session ran out.
  AuthException _map(
    Object error, {
    bool refreshing = false,
    bool answeringChallenge = false,
    bool answeringEmailCode = false,
  }) {
    if (error is AuthException) return error;
    if (error is CognitoClientException) {
      final failure = switch (error.code) {
        'NotAuthorizedException' ||
        'UserNotFoundException' ||
        'RefreshTokenReuseException' when refreshing => AuthFailure.sessionExpired,
        'CodeMismatchException' when answeringEmailCode => AuthFailure.invalidCode,
        'ExpiredCodeException' when answeringEmailCode => AuthFailure.codeExpired,
        'NotAuthorizedException' when answeringEmailCode && (error.message?.contains('attempts exceeded') ?? false) =>
          AuthFailure.tooManyRequests,
        'NotAuthorizedException' when answeringEmailCode && _mentionsSession(error) => AuthFailure.codeExpired,
        // With user existence errors prevented, Cognito simulates the flow for
        // unknown addresses, so a wrong code and an unknown user must look the same.
        'NotAuthorizedException' || 'UserNotFoundException' when answeringEmailCode => AuthFailure.invalidCode,
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
