import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'support/fake_cognito.dart';

Matcher _failsWith(AuthFailure failure) => throwsA(isA<AuthException>().having((e) => e.failure, 'failure', failure));

void main() {
  late FakeCognito cognito;
  late CognitoAuthClient client;

  setUp(() {
    cognito = FakeCognito();
    client = cognito.client();
  });

  group('signIn', () {
    test('returns the session Cognito issued', () async {
      final session = sessionFor('jane', groups: ['editor']);
      cognito.initiateAuth = (_) => FakeCognito.authenticated(session);

      final result = await client.signIn('jane', 'secret');

      expect(result, isA<SignedIn>().having((r) => r.session, 'session', session));
      final user = (result as SignedIn).session.user;
      expect(user.username, 'jane');
      expect(user.email, 'jane@fabit.us');
      expect(user.groups, ['editor']);
    });

    test('uses USER_PASSWORD_AUTH by default', () async {
      cognito.initiateAuth = (_) => FakeCognito.authenticated(sessionFor('jane'));

      await client.signIn('jane', 'secret');

      final body = cognito.calls.single.body;
      expect(body['AuthFlow'], 'USER_PASSWORD_AUTH');
      expect(body['ClientId'], clientId);
      expect(body['AuthParameters'], containsPair('USERNAME', 'jane'));
      expect(body['AuthParameters'], containsPair('PASSWORD', 'secret'));
    });

    test('returns the challenge for a user with a temporary password', () async {
      cognito.initiateAuth = (_) => FakeCognito.newPasswordChallenge(requiredAttributes: ['name']);

      final result = await client.signIn('jane', 'temporary');

      expect(result, isA<NewPasswordRequired>().having((r) => r.requiredAttributes, 'requiredAttributes', ['name']));
    });

    test('a wrong password is invalid credentials', () async {
      cognito.initiateAuth = (_) => FakeCognito.error('NotAuthorizedException', 'Incorrect username or password.');

      await expectLater(client.signIn('jane', 'wrong'), _failsWith(AuthFailure.invalidCredentials));
    });

    test('an unknown user is invalid credentials too', () async {
      cognito.initiateAuth = (_) => FakeCognito.error('UserNotFoundException', 'User does not exist.');

      await expectLater(client.signIn('nobody', 'secret'), _failsWith(AuthFailure.invalidCredentials));
    });

    test('a locked out user is too many requests', () async {
      cognito.initiateAuth = (_) => FakeCognito.error('NotAuthorizedException', 'Password attempts exceeded');

      await expectLater(client.signIn('jane', 'wrong'), _failsWith(AuthFailure.tooManyRequests));
    });

    test('maps the other Cognito errors', () async {
      final cases = {
        'UserNotConfirmedException': AuthFailure.userNotConfirmed,
        'PasswordResetRequiredException': AuthFailure.passwordResetRequired,
        'TooManyRequestsException': AuthFailure.tooManyRequests,
        'LimitExceededException': AuthFailure.tooManyRequests,
        'InternalErrorException': AuthFailure.unknown,
      };
      for (final MapEntry(key: code, value: failure) in cases.entries) {
        cognito.initiateAuth = (_) => FakeCognito.error(code, 'message');
        await expectLater(client.signIn('jane', 'secret'), _failsWith(failure), reason: code);
      }
    });

    test('a request that never arrives is a network failure', () async {
      final offline = CognitoAuthClient(userPoolId: userPoolId, clientId: clientId, httpClient: _ThrowingClient());

      await expectLater(offline.signIn('jane', 'secret'), _failsWith(AuthFailure.network));
    });

    test('an MFA challenge is unsupported', () async {
      cognito.initiateAuth = (_) =>
          http.Response('{"ChallengeName": "SOFTWARE_TOKEN_MFA", "Session": "s", "ChallengeParameters": {}}', 200);

      await expectLater(client.signIn('jane', 'secret'), _failsWith(AuthFailure.unsupportedChallenge));
    });
  });

  group('completeNewPassword', () {
    test('answers the challenge on the session that raised it', () async {
      final session = sessionFor('jane');
      cognito.initiateAuth = (_) => FakeCognito.newPasswordChallenge();
      cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(session);

      final challenge = await client.signIn('jane', 'temporary') as NewPasswordRequired;
      final result = await client.completeNewPassword(challenge, 'NewSecret123!', attributes: {'name': 'Jane'});

      expect(result, session);
      final body = cognito.calls.last.body;
      expect(body['ChallengeName'], 'NEW_PASSWORD_REQUIRED');
      expect(body['Session'], 'challenge-session');
      expect(body['ChallengeResponses'], containsPair('NEW_PASSWORD', 'NewSecret123!'));
      expect(body['ChallengeResponses'], containsPair('userAttributes.name', 'Jane'));
    });

    test('a password the pool rejects is invalid password', () async {
      cognito.initiateAuth = (_) => FakeCognito.newPasswordChallenge();
      cognito.respondToAuthChallenge = (_) => FakeCognito.error('InvalidPasswordException', 'Password not long enough');

      final challenge = await client.signIn('jane', 'temporary') as NewPasswordRequired;

      await expectLater(client.completeNewPassword(challenge, 'short'), _failsWith(AuthFailure.invalidPassword));
    });

    test('an expired challenge is no pending challenge', () async {
      cognito.initiateAuth = (_) => FakeCognito.newPasswordChallenge();
      cognito.respondToAuthChallenge = (_) =>
          FakeCognito.error('NotAuthorizedException', 'Invalid session for the user, session is expired.');

      final challenge = await client.signIn('jane', 'temporary') as NewPasswordRequired;

      await expectLater(
        client.completeNewPassword(challenge, 'NewSecret123!'),
        _failsWith(AuthFailure.noPendingChallenge),
      );
    });
  });

  group('refresh', () {
    test('keeps the refresh token when Cognito sends none', () async {
      final stale = sessionFor('jane', validFor: Duration.zero, refreshToken: 'refresh-1');
      final fresh = sessionFor('jane', refreshToken: 'ignored');
      cognito.initiateAuth = (_) => FakeCognito.authenticated(fresh, includeRefreshToken: false);

      final refreshed = await client.refresh(stale);

      expect(refreshed.idToken, fresh.idToken);
      expect(refreshed.refreshToken, 'refresh-1');
      final body = cognito.calls.single.body;
      expect(body['AuthFlow'], 'REFRESH_TOKEN_AUTH');
      expect(body['AuthParameters'], containsPair('REFRESH_TOKEN', 'refresh-1'));
    });

    test('uses GetTokensFromRefreshToken with rotation, and takes the new refresh token', () async {
      final rotating = cognito.client(refreshTokenRotation: true);
      cognito.getTokensFromRefreshToken = (_) =>
          FakeCognito.authenticated(sessionFor('jane', refreshToken: 'refresh-2'));

      final refreshed = await rotating.refresh(sessionFor('jane', refreshToken: 'refresh-1'));

      expect(cognito.operations, ['GetTokensFromRefreshToken']);
      expect(refreshed.refreshToken, 'refresh-2');
    });

    test('a rejected refresh token ends the session', () async {
      cognito.initiateAuth = (_) => FakeCognito.error('NotAuthorizedException', 'Refresh Token has expired');

      await expectLater(client.refresh(sessionFor('jane')), _failsWith(AuthFailure.sessionExpired));
    });

    test('a reused rotated refresh token ends the session', () async {
      final rotating = cognito.client(refreshTokenRotation: true);
      cognito.getTokensFromRefreshToken = (_) => FakeCognito.error('RefreshTokenReuseException', 'reused');

      await expectLater(rotating.refresh(sessionFor('jane')), _failsWith(AuthFailure.sessionExpired));
    });

    test('a network failure does not end the session', () async {
      final offline = CognitoAuthClient(userPoolId: userPoolId, clientId: clientId, httpClient: _ThrowingClient());

      await expectLater(offline.refresh(sessionFor('jane')), _failsWith(AuthFailure.network));
    });
  });

  test('revoke sends the refresh token to RevokeToken', () async {
    cognito.revokeToken = (_) => FakeCognito.ok();

    await client.revoke(sessionFor('jane', refreshToken: 'refresh-1'));

    expect(cognito.calls.single.operation, 'RevokeToken');
    expect(cognito.calls.single.body, {'ClientId': clientId, 'Token': 'refresh-1'});
  });
}

/// An HTTP client whose every request fails before a response, as when the
/// host cannot be resolved.
class _ThrowingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw http.ClientException('Failed host lookup: cognito-idp.eu-central-1.amazonaws.com');
}
