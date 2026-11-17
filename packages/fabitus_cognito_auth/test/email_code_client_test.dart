import 'dart:convert';

import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:fabitus_cognito_auth/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

Matcher _failsWith(AuthFailure failure) => throwsA(isA<AuthException>().having((e) => e.failure, 'failure', failure));

void main() {
  late FakeCognito cognito;

  setUp(() => cognito = FakeCognito());

  group('CognitoAuthClient.requestEmailCode', () {
    test('starts USER_AUTH preferring EMAIL_OTP and returns where the code went', () async {
      cognito.initiateAuth = (_) => FakeCognito.emailCodeChallenge(session: 's-1');

      final challenge = await cognito.client().requestEmailCode('jane@fabit.us');

      final body = cognito.calls.single.body;
      expect(body['AuthFlow'], 'USER_AUTH');
      expect(body['ClientId'], FakeCognito.clientId);
      expect(body['AuthParameters'], {'USERNAME': 'jane@fabit.us', 'PREFERRED_CHALLENGE': 'EMAIL_OTP'});
      expect(challenge.username, 'jane@fabit.us');
      expect(challenge.destination, 'j***@f***');
      expect(challenge.session, 's-1');
    });

    test('SELECT_CHALLENGE means the pool offers no e-mail code', () async {
      cognito.initiateAuth = (_) => FakeCognito.selectChallenge(['PASSWORD', 'WEB_AUTHN']);

      await expectLater(
        cognito.client().requestEmailCode('jane@fabit.us'),
        _failsWith(AuthFailure.unsupportedChallenge),
      );
    });

    test('any other challenge is unsupported, naming it', () async {
      cognito.initiateAuth = (_) => FakeCognito.newPasswordChallenge();

      await expectLater(
        cognito.client().requestEmailCode('jane@fabit.us'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'NEW_PASSWORD_REQUIRED')),
      );
    });

    test('an unknown user is invalid credentials', () async {
      cognito.initiateAuth = (_) => FakeCognito.error('UserNotFoundException', 'User does not exist.');

      await expectLater(
        cognito.client().requestEmailCode('nobody@fabit.us'),
        _failsWith(AuthFailure.invalidCredentials),
      );
    });

    test('throttling is too many requests', () async {
      cognito.initiateAuth = (_) => FakeCognito.error('LimitExceededException', 'Exceeded daily email limit.');

      await expectLater(cognito.client().requestEmailCode('jane@fabit.us'), _failsWith(AuthFailure.tooManyRequests));
    });
  });

  group('CognitoAuthClient.requestEmailCode answers', () {
    test('without a session are unknown failures', () async {
      cognito.initiateAuth = (_) =>
          http.Response(json.encode({'ChallengeName': 'EMAIL_OTP', 'ChallengeParameters': <String, dynamic>{}}), 200);

      await expectLater(cognito.client().requestEmailCode('jane@fabit.us'), _failsWith(AuthFailure.unknown));
    });
  });

  group('CognitoAuthClient.submitEmailCode', () {
    final session = fakeSession('jane');

    Future<EmailCodeChallenge> challenge({String? username}) {
      cognito.initiateAuth = (_) => FakeCognito.emailCodeChallenge(username: username, session: 's-1');
      return cognito.client().requestEmailCode('jane@fabit.us');
    }

    test('answers EMAIL_OTP with the session and returns the tokens', () async {
      final pending = await challenge();
      cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(session);

      final result = await cognito.client().submitEmailCode(pending, '123456');

      expect(result, session);
      final call = cognito.calls.last;
      expect(call.operation, 'RespondToAuthChallenge');
      expect(call.body, {
        'ClientId': FakeCognito.clientId,
        'ChallengeName': 'EMAIL_OTP',
        'Session': 's-1',
        'ChallengeResponses': {'USERNAME': 'jane@fabit.us', 'EMAIL_OTP_CODE': '123456'},
      });
    });

    test('uses the user name Cognito resolved', () async {
      final pending = await challenge(username: 'uuid-1');
      cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(session);

      await cognito.client().submitEmailCode(pending, '123456');

      expect(cognito.calls.last.body['ChallengeResponses'], containsPair('USERNAME', 'uuid-1'));
    });

    test('an answer without a refresh token is an unknown failure', () async {
      final pending = await challenge();
      cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(session, includeRefreshToken: false);

      await expectLater(cognito.client().submitEmailCode(pending, '123456'), _failsWith(AuthFailure.unknown));
    });

    test('a further challenge is unsupported', () async {
      final pending = await challenge();
      cognito.respondToAuthChallenge = (_) => FakeCognito.newPasswordChallenge();

      await expectLater(
        cognito.client().submitEmailCode(pending, '123456'),
        _failsWith(AuthFailure.unsupportedChallenge),
      );
    });

    final mapping = <String, (String, String, AuthFailure)>{
      'a wrong code': ('CodeMismatchException', 'Invalid code received for user', AuthFailure.invalidCode),
      'an expired code': ('ExpiredCodeException', 'Invalid code received for user', AuthFailure.codeExpired),
      'exceeded attempts': ('NotAuthorizedException', 'Password attempts exceeded', AuthFailure.tooManyRequests),
      'an expired auth session': (
        'NotAuthorizedException',
        'Invalid session for the user, session is expired.',
        AuthFailure.codeExpired,
      ),
      'another authorization failure': (
        'NotAuthorizedException',
        'Incorrect username or password.',
        AuthFailure.invalidCode,
      ),
      'an unknown user': ('UserNotFoundException', 'User does not exist.', AuthFailure.invalidCode),
      'too many failed attempts': ('TooManyFailedAttemptsException', 'Too many.', AuthFailure.tooManyRequests),
      'throttling': ('TooManyRequestsException', 'Slow down.', AuthFailure.tooManyRequests),
      'the limit': ('LimitExceededException', 'Limit.', AuthFailure.tooManyRequests),
      'an unexpected error': ('InternalErrorException', 'Oops.', AuthFailure.unknown),
    };
    mapping.forEach((name, entry) {
      test('$name is ${entry.$3.name}', () async {
        final pending = await challenge();
        cognito.respondToAuthChallenge = (_) => FakeCognito.error(entry.$1, entry.$2);

        await expectLater(cognito.client().submitEmailCode(pending, '123456'), _failsWith(entry.$3));
      });
    });

    test('an unreachable Cognito is a network failure', () async {
      final pending = await challenge();
      cognito.respondToAuthChallenge = (_) => FakeCognito.error('NetworkError', 'offline');

      await expectLater(cognito.client().submitEmailCode(pending, '123456'), _failsWith(AuthFailure.network));
    });
  });
}
