import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:fabitus_cognito_auth/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

Matcher _codeRequiredWith(AuthFailure? failure, {String? destination = 'j***@f***'}) => isA<AuthEmailCodeRequired>()
    .having((s) => s.username, 'username', 'jane@fabit.us')
    .having((s) => s.destination, 'destination', destination)
    .having((s) => s.error?.failure, 'failure', failure);

Matcher _unauthenticatedWith(AuthFailure? failure) =>
    isA<AuthUnauthenticated>().having((s) => s.error?.failure, 'failure', failure);

void main() {
  late FakeCognito cognito;
  late InMemoryAuthSessionStore store;

  setUp(() {
    cognito = FakeCognito();
    store = InMemoryAuthSessionStore();
  });

  group('AuthCubit e-mail code', () {
    final session = fakeSession('jane', refreshToken: 'refresh-1');

    AuthCubit build() => AuthCubit(cognito.client(), store: store);

    void codeSent({String destination = 'j***@f***', String session = 'otp-1'}) =>
        cognito.initiateAuth = (_) => FakeCognito.emailCodeChallenge(destination: destination, session: session);

    blocTest<AuthCubit, AuthState>(
      'requesting a code waits for the answer',
      setUp: codeSent,
      build: build,
      act: (cubit) => cubit.requestEmailCode('  jane@fabit.us '),
      expect: () => [
        const AuthInProgress(AuthStep.requestEmailCode),
        const AuthEmailCodeRequired(username: 'jane@fabit.us', destination: 'j***@f***'),
      ],
      verify: (_) => expect(cognito.calls.single.body['AuthParameters'], containsPair('USERNAME', 'jane@fabit.us')),
    );

    blocTest<AuthCubit, AuthState>(
      'an empty address does not call Cognito',
      build: build,
      act: (cubit) => cubit.requestEmailCode('  '),
      expect: () => [_unauthenticatedWith(AuthFailure.missingCredentials)],
      verify: (_) => expect(cognito.calls, isEmpty),
    );

    blocTest<AuthCubit, AuthState>(
      'a failed request ends unauthenticated with the reason',
      setUp: () => cognito.initiateAuth = (_) => FakeCognito.error('UserNotFoundException', 'nope'),
      build: build,
      act: (cubit) => cubit.requestEmailCode('jane@fabit.us'),
      expect: () => [
        const AuthInProgress(AuthStep.requestEmailCode),
        _unauthenticatedWith(AuthFailure.invalidCredentials),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'a pool without e-mail codes ends unsupported',
      setUp: () => cognito.initiateAuth = (_) => FakeCognito.selectChallenge(['PASSWORD']),
      build: build,
      act: (cubit) => cubit.requestEmailCode('jane@fabit.us'),
      expect: () => [
        const AuthInProgress(AuthStep.requestEmailCode),
        _unauthenticatedWith(AuthFailure.unsupportedChallenge),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'the right code signs in, stores the session and refresh works afterwards',
      setUp: () {
        codeSent();
        cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(session);
      },
      build: build,
      act: (cubit) async {
        await cubit.requestEmailCode('jane@fabit.us');
        await cubit.submitEmailCode(' 123 456 ');
        cognito.initiateAuth = (body) {
          expect(body['AuthFlow'], 'REFRESH_TOKEN_AUTH');
          return FakeCognito.authenticated(
            fakeSession('jane', validFor: const Duration(hours: 2)),
            includeRefreshToken: false,
          );
        };
        await cubit.refresh();
      },
      skip: 2,
      expect: () => [
        const AuthInProgress(AuthStep.submitEmailCode),
        AuthAuthenticated(session),
        isA<AuthAuthenticated>().having((s) => s.session.refreshToken, 'refreshToken', 'refresh-1'),
      ],
      verify: (cubit) {
        expect(store.session?.refreshToken, 'refresh-1');
        final answer = cognito.calls.firstWhere((c) => c.operation == 'RespondToAuthChallenge').body;
        expect(answer['ChallengeResponses'], containsPair('EMAIL_OTP_CODE', '123456'));
      },
    );

    blocTest<AuthCubit, AuthState>(
      'a wrong code keeps the challenge, a second right one succeeds',
      setUp: codeSent,
      build: build,
      act: (cubit) async {
        await cubit.requestEmailCode('jane@fabit.us');
        cognito.respondToAuthChallenge = (_) => FakeCognito.error('CodeMismatchException', 'Wrong');
        await cubit.submitEmailCode('111111');
        cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(session);
        await cubit.submitEmailCode('222222');
      },
      skip: 2,
      expect: () => [
        const AuthInProgress(AuthStep.submitEmailCode),
        _codeRequiredWith(AuthFailure.invalidCode),
        const AuthInProgress(AuthStep.submitEmailCode),
        AuthAuthenticated(session),
      ],
    );

    for (final (name, code, failure) in [
      ('an expired code', 'ExpiredCodeException', AuthFailure.codeExpired),
      ('too many attempts', 'TooManyFailedAttemptsException', AuthFailure.tooManyRequests),
      ('a network failure', 'NetworkError', AuthFailure.network),
    ]) {
      blocTest<AuthCubit, AuthState>(
        '$name returns to the code form with the reason',
        setUp: codeSent,
        build: build,
        act: (cubit) async {
          await cubit.requestEmailCode('jane@fabit.us');
          cognito.respondToAuthChallenge = (_) => FakeCognito.error(code, 'x');
          await cubit.submitEmailCode('123456');
        },
        skip: 2,
        expect: () => [const AuthInProgress(AuthStep.submitEmailCode), _codeRequiredWith(failure)],
      );
    }

    blocTest<AuthCubit, AuthState>(
      'an empty code does not call Cognito',
      setUp: codeSent,
      build: build,
      act: (cubit) async {
        await cubit.requestEmailCode('jane@fabit.us');
        await cubit.submitEmailCode(' \t');
      },
      skip: 2,
      expect: () => [_codeRequiredWith(AuthFailure.missingCredentials)],
      verify: (_) => expect(cognito.operations, ['InitiateAuth']),
    );

    blocTest<AuthCubit, AuthState>(
      'resend replaces the session, clears the error and the next answer uses the new one',
      setUp: codeSent,
      build: build,
      act: (cubit) async {
        await cubit.requestEmailCode('jane@fabit.us');
        cognito.respondToAuthChallenge = (_) => FakeCognito.error('ExpiredCodeException', 'x');
        await cubit.submitEmailCode('111111');
        codeSent(destination: 'j***@g***', session: 'otp-2');
        await cubit.resendEmailCode();
        cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(session);
        await cubit.submitEmailCode('222222');
      },
      skip: 4,
      expect: () => [
        const AuthInProgress(AuthStep.resendEmailCode),
        const AuthEmailCodeRequired(username: 'jane@fabit.us', destination: 'j***@g***'),
        const AuthInProgress(AuthStep.submitEmailCode),
        AuthAuthenticated(session),
      ],
      verify: (_) => expect(cognito.calls.last.body, containsPair('Session', 'otp-2')),
    );

    blocTest<AuthCubit, AuthState>(
      'a failed resend keeps the old challenge',
      setUp: codeSent,
      build: build,
      act: (cubit) async {
        await cubit.requestEmailCode('jane@fabit.us');
        cognito.initiateAuth = (_) => FakeCognito.error('LimitExceededException', 'x');
        await cubit.resendEmailCode();
        cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(session);
        await cubit.submitEmailCode('123456');
      },
      skip: 2,
      expect: () => [
        const AuthInProgress(AuthStep.resendEmailCode),
        _codeRequiredWith(AuthFailure.tooManyRequests),
        const AuthInProgress(AuthStep.submitEmailCode),
        AuthAuthenticated(session),
      ],
      verify: (_) => expect(cognito.calls.last.body, containsPair('Session', 'otp-1')),
    );

    blocTest<AuthCubit, AuthState>(
      'submit and resend without a challenge end unauthenticated',
      build: build,
      act: (cubit) async {
        await cubit.submitEmailCode('123456');
        await cubit.resendEmailCode();
      },
      expect: () => [_unauthenticatedWith(AuthFailure.noPendingChallenge)],
      verify: (_) => expect(cognito.calls, isEmpty),
    );

    blocTest<AuthCubit, AuthState>(
      'cancel drops the challenge',
      setUp: codeSent,
      build: build,
      act: (cubit) async {
        await cubit.requestEmailCode('jane@fabit.us');
        cubit.cancelEmailCode();
        await cubit.submitEmailCode('123456');
      },
      skip: 2,
      expect: () => [const AuthUnauthenticated(), _unauthenticatedWith(AuthFailure.noPendingChallenge)],
    );

    blocTest<AuthCubit, AuthState>(
      'signOut drops the challenge',
      setUp: codeSent,
      build: build,
      act: (cubit) async {
        await cubit.requestEmailCode('jane@fabit.us');
        await cubit.signOut();
        await cubit.submitEmailCode('123456');
      },
      skip: 2,
      expect: () => [const AuthUnauthenticated(), _unauthenticatedWith(AuthFailure.noPendingChallenge)],
    );

    blocTest<AuthCubit, AuthState>(
      'a password sign in after a cancelled code flow still works',
      setUp: () =>
          cognito.initiateAuth = (body) =>
              body['AuthFlow'] == 'USER_AUTH' ? FakeCognito.emailCodeChallenge() : FakeCognito.authenticated(session),
      build: build,
      act: (cubit) async {
        await cubit.requestEmailCode('jane@fabit.us');
        cubit.cancelEmailCode();
        await cubit.signIn('jane', 'secret');
      },
      skip: 3,
      expect: () => [const AuthInProgress(AuthStep.signIn), AuthAuthenticated(session)],
      verify: (_) => expect(store.session, session),
    );

    blocTest<AuthCubit, AuthState>(
      'cancel leaves a signed in session alone',
      setUp: () => store.session = session,
      build: build,
      act: (cubit) async {
        await cubit.restore();
        cubit.cancelEmailCode();
      },
      expect: () => [AuthAuthenticated(session)],
      verify: (_) => expect(store.session, session),
    );

    blocTest<AuthCubit, AuthState>(
      'a failed password sign in drops a pending code challenge',
      setUp: codeSent,
      build: build,
      act: (cubit) async {
        await cubit.requestEmailCode('jane@fabit.us');
        cognito.initiateAuth = (_) => FakeCognito.error('NotAuthorizedException', 'Incorrect');
        await cubit.signIn('jane', 'wrong');
        await cubit.submitEmailCode('123456');
      },
      skip: 4,
      expect: () => [_unauthenticatedWith(AuthFailure.noPendingChallenge)],
      verify: (_) => expect(cognito.operations, ['InitiateAuth', 'InitiateAuth']),
    );

    blocTest<AuthCubit, AuthState>(
      'a failed second request drops the first challenge',
      setUp: codeSent,
      build: build,
      act: (cubit) async {
        await cubit.requestEmailCode('jane@fabit.us');
        cognito.initiateAuth = (_) => FakeCognito.error('UserNotFoundException', 'nope');
        await cubit.requestEmailCode('other@fabit.us');
        await cubit.resendEmailCode();
      },
      skip: 4,
      expect: () => [_unauthenticatedWith(AuthFailure.noPendingChallenge)],
      verify: (_) => expect(cognito.operations, ['InitiateAuth', 'InitiateAuth']),
    );

    blocTest<AuthCubit, AuthState>(
      'requesting a code drops a pending new password challenge',
      setUp: () =>
          cognito.initiateAuth = (body) =>
              body['AuthFlow'] == 'USER_AUTH' ? FakeCognito.emailCodeChallenge() : FakeCognito.newPasswordChallenge(),
      build: build,
      act: (cubit) async {
        await cubit.signIn('jane', 'temporary');
        await cubit.requestEmailCode('jane@fabit.us');
        await cubit.submitNewPassword('Sicher123456');
      },
      skip: 4,
      expect: () => [_unauthenticatedWith(AuthFailure.noPendingChallenge)],
      verify: (_) => expect(cognito.operations, ['InitiateAuth', 'InitiateAuth']),
    );

    blocTest<AuthCubit, AuthState>(
      'toString shows the destination, not the typed address',
      setUp: codeSent,
      build: build,
      act: (cubit) => cubit.requestEmailCode('jane@fabit.us'),
      verify: (cubit) => expect(cubit.state.toString(), allOf(contains('j***@f***'), isNot(contains('jane@')))),
    );

    group('a stale answer', () {
      late Completer<void> gate;

      setUp(() {
        gate = Completer<void>();
        cognito.initiateAuth = (_) => FakeCognito.emailCodeChallenge();
        cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(session);
      });

      AuthCubit delayedAnswers() {
        final delayed = AuthCubit(
          CognitoAuthClient(
            userPoolId: FakeCognito.userPoolId,
            clientId: FakeCognito.clientId,
            httpClient: _GatedClient(cognito.httpClient, () => gate.future),
          ),
          store: store,
        );
        addTearDown(delayed.close);
        return delayed;
      }

      test('is dropped after cancel', () async {
        final delayed = delayedAnswers();
        gate.complete();
        await delayed.requestEmailCode('jane@fabit.us');
        gate = Completer<void>();

        final answer = delayed.submitEmailCode('123456');
        delayed.cancelEmailCode();
        gate.complete();
        await answer;

        expect(delayed.state, const AuthUnauthenticated());
        expect(store.session, isNull);
      });

      test('is dropped after signOut', () async {
        final delayed = delayedAnswers();
        gate.complete();
        await delayed.requestEmailCode('jane@fabit.us');
        gate = Completer<void>();

        final answer = delayed.submitEmailCode('123456');
        await delayed.signOut();
        gate.complete();
        await answer;

        expect(delayed.state, const AuthUnauthenticated());
        expect(store.session, isNull);
      });

      test('a second step while one is running is ignored', () async {
        final delayed = delayedAnswers();
        gate.complete();
        await delayed.requestEmailCode('jane@fabit.us');
        gate = Completer<void>();

        final answer = delayed.submitEmailCode('123456');
        await delayed.resendEmailCode();
        await delayed.submitEmailCode('654321');
        gate.complete();
        await answer;

        expect(cognito.operations, ['InitiateAuth', 'RespondToAuthChallenge']);
        expect(delayed.state, AuthAuthenticated(session));
      });
    });
  });
}

/// Holds every request until `_gate` completes, then passes it on.
class _GatedClient extends http.BaseClient {
  _GatedClient(this._inner, this._gate);

  final http.Client _inner;
  final Future<void> Function() _gate;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _gate();
    return _inner.send(request);
  }
}
