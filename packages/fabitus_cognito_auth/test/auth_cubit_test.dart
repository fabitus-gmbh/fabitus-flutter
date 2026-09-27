import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:fabitus_cognito_auth/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

Matcher _unauthenticatedWith(AuthFailure? failure) =>
    isA<AuthUnauthenticated>().having((s) => s.error?.failure, 'failure', failure);

void main() {
  late FakeCognito cognito;
  late InMemoryAuthSessionStore store;

  AuthCubit build({PasswordPolicy? passwordPolicy}) =>
      AuthCubit(cognito.client(), store: store, passwordPolicy: passwordPolicy);

  setUp(() {
    cognito = FakeCognito();
    store = InMemoryAuthSessionStore();
  });

  group('restore', () {
    blocTest<AuthCubit, AuthState>(
      'without a stored session ends unauthenticated',
      build: build,
      act: (cubit) => cubit.restore(),
      expect: () => [const AuthUnauthenticated()],
    );

    final valid = fakeSession('jane');
    blocTest<AuthCubit, AuthState>(
      'picks up a valid session without calling Cognito',
      setUp: () => store.session = valid,
      build: build,
      act: (cubit) => cubit.restore(),
      expect: () => [AuthAuthenticated(valid)],
      verify: (_) => expect(cognito.calls, isEmpty),
    );

    final expired = fakeSession('jane', validFor: const Duration(minutes: -5));
    final fresh = fakeSession('jane', refreshToken: 'refresh-1');
    blocTest<AuthCubit, AuthState>(
      'refreshes an expired session and stores the result',
      setUp: () {
        store.session = expired;
        cognito.initiateAuth = (_) => FakeCognito.authenticated(fresh);
      },
      build: build,
      act: (cubit) => cubit.restore(),
      expect: () => [const AuthInProgress(AuthStep.restore), AuthAuthenticated(fresh)],
      verify: (_) => expect(store.session, fresh),
    );

    blocTest<AuthCubit, AuthState>(
      'an expired session Cognito rejects ends the session and clears the store',
      setUp: () {
        store.session = expired;
        cognito.initiateAuth = (_) => FakeCognito.error('NotAuthorizedException', 'Refresh Token has expired');
      },
      build: build,
      act: (cubit) => cubit.restore(),
      expect: () => [const AuthInProgress(AuthStep.restore), _unauthenticatedWith(AuthFailure.sessionExpired)],
      verify: (_) => expect(store.session, isNull),
    );

    blocTest<AuthCubit, AuthState>(
      'offline, an expired session is kept for a later refresh',
      setUp: () => store.session = expired,
      build: () => AuthCubit(
        CognitoAuthClient(
          userPoolId: FakeCognito.userPoolId,
          clientId: FakeCognito.clientId,
          httpClient: _OfflineClient(),
        ),
        store: store,
      ),
      act: (cubit) => cubit.restore(),
      expect: () => [const AuthInProgress(AuthStep.restore), AuthAuthenticated(expired)],
      verify: (_) => expect(store.session, expired),
    );

    test('runs only once', () async {
      store.session = valid;
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.restore();
      await cubit.signOut();
      await cubit.restore();

      expect(cubit.state, const AuthUnauthenticated());
    });
  });

  group('signIn', () {
    final session = fakeSession('jane');

    blocTest<AuthCubit, AuthState>(
      'signs in and stores the session',
      setUp: () => cognito.initiateAuth = (_) => FakeCognito.authenticated(session),
      build: build,
      act: (cubit) => cubit.signIn('  jane ', 'secret'),
      expect: () => [const AuthInProgress(AuthStep.signIn), AuthAuthenticated(session)],
      verify: (_) {
        expect(store.session, session);
        expect(cognito.calls.single.body['AuthParameters'], containsPair('USERNAME', 'jane'));
      },
    );

    blocTest<AuthCubit, AuthState>(
      'empty credentials fail without calling Cognito',
      build: build,
      act: (cubit) => cubit.signIn(' ', 'secret'),
      expect: () => [_unauthenticatedWith(AuthFailure.missingCredentials)],
      verify: (_) => expect(cognito.calls, isEmpty),
    );

    blocTest<AuthCubit, AuthState>(
      'wrong credentials end unauthenticated with the reason',
      setUp: () => cognito.initiateAuth = (_) => FakeCognito.error('NotAuthorizedException', 'Incorrect'),
      build: build,
      act: (cubit) => cubit.signIn('jane', 'wrong'),
      expect: () => [const AuthInProgress(AuthStep.signIn), _unauthenticatedWith(AuthFailure.invalidCredentials)],
      verify: (_) => expect(store.session, isNull),
    );

    test('a second sign in while one is running is ignored', () async {
      final response = Completer<http.Response>();
      cognito.initiateAuth = (_) => FakeCognito.authenticated(session);
      final cubit = AuthCubit(
        CognitoAuthClient(
          userPoolId: FakeCognito.userPoolId,
          clientId: FakeCognito.clientId,
          httpClient: _DelayedClient(cognito.httpClient, response.future),
        ),
      );
      addTearDown(cubit.close);

      final first = cubit.signIn('jane', 'secret');
      await cubit.signIn('jane', 'secret');
      response.complete(http.Response('', 200));
      await first;

      expect(cognito.calls, hasLength(1));
      expect(cubit.state, AuthAuthenticated(session));
    });
  });

  group('the new password challenge', () {
    final session = fakeSession('jane');

    setUp(() {
      cognito.initiateAuth = (_) => FakeCognito.newPasswordChallenge(requiredAttributes: ['name']);
      cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(session);
    });

    blocTest<AuthCubit, AuthState>(
      'is raised and answered',
      build: build,
      act: (cubit) async {
        await cubit.signIn('jane', 'temporary');
        await cubit.submitNewPassword('NewSecret123!', attributes: {'name': 'Jane'});
      },
      expect: () => [
        const AuthInProgress(AuthStep.signIn),
        const AuthNewPasswordRequired(requiredAttributes: ['name']),
        const AuthInProgress(AuthStep.newPassword),
        AuthAuthenticated(session),
      ],
      verify: (_) => expect(store.session, session),
    );

    blocTest<AuthCubit, AuthState>(
      'a password breaking the policy is rejected locally and keeps the challenge',
      build: () => build(passwordPolicy: const PasswordPolicy(minimumLength: 12)),
      act: (cubit) async {
        await cubit.signIn('jane', 'temporary');
        await cubit.submitNewPassword('Short1!');
        await cubit.submitNewPassword('LongEnough123!');
      },
      expect: () => [
        const AuthInProgress(AuthStep.signIn),
        const AuthNewPasswordRequired(requiredAttributes: ['name']),
        isA<AuthNewPasswordRequired>().having((s) => s.error?.failure, 'failure', AuthFailure.invalidPassword),
        const AuthInProgress(AuthStep.newPassword),
        AuthAuthenticated(session),
      ],
      verify: (_) => expect(cognito.operations, ['InitiateAuth', 'RespondToAuthChallenge']),
    );

    blocTest<AuthCubit, AuthState>(
      'a password Cognito rejects keeps the challenge',
      setUp: () => cognito.respondToAuthChallenge = (_) => FakeCognito.error('InvalidPasswordException', 'Too short'),
      build: build,
      act: (cubit) async {
        await cubit.signIn('jane', 'temporary');
        await cubit.submitNewPassword('whatever');
      },
      skip: 2,
      expect: () => [
        const AuthInProgress(AuthStep.newPassword),
        isA<AuthNewPasswordRequired>().having((s) => s.error?.failure, 'failure', AuthFailure.invalidPassword),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'an expired challenge sends the user back to sign in',
      setUp: () =>
          cognito.respondToAuthChallenge = (_) =>
              FakeCognito.error('NotAuthorizedException', 'Invalid session for the user, session is expired.'),
      build: build,
      act: (cubit) async {
        await cubit.signIn('jane', 'temporary');
        await cubit.submitNewPassword('NewSecret123!');
        await cubit.submitNewPassword('NewSecret123!');
      },
      skip: 3,
      expect: () => [
        _unauthenticatedWith(AuthFailure.noPendingChallenge),
        _unauthenticatedWith(AuthFailure.noPendingChallenge),
      ],
      verify: (_) => expect(cognito.operations, ['InitiateAuth', 'RespondToAuthChallenge']),
    );

    blocTest<AuthCubit, AuthState>(
      'a new password without a challenge is no pending challenge',
      build: build,
      act: (cubit) => cubit.submitNewPassword('NewSecret123!'),
      expect: () => [_unauthenticatedWith(AuthFailure.noPendingChallenge)],
      verify: (_) => expect(cognito.calls, isEmpty),
    );
  });

  group('refresh', () {
    final initial = fakeSession('jane', refreshToken: 'refresh-1');
    final fresh = fakeSession('jane', validFor: const Duration(hours: 2), refreshToken: 'refresh-1');

    Future<AuthCubit> signedIn() async {
      store.session = initial;
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.restore();
      return cubit;
    }

    test('replaces and stores the session', () async {
      final cubit = await signedIn();
      cognito.initiateAuth = (_) => FakeCognito.authenticated(fresh, includeRefreshToken: false);

      expect(await cubit.refresh(), fresh);
      expect(cubit.state, AuthAuthenticated(fresh));
      expect(store.session, fresh);
    });

    test('concurrent calls share one refresh', () async {
      final cubit = await signedIn();
      cognito.initiateAuth = (_) => FakeCognito.authenticated(fresh);

      final results = await Future.wait([cubit.refresh(), cubit.refresh(), cubit.refresh()]);

      expect(results, [fresh, fresh, fresh]);
      expect(cognito.calls, hasLength(1));
    });

    test('a rejected refresh token ends the session and returns null', () async {
      final cubit = await signedIn();
      cognito.initiateAuth = (_) => FakeCognito.error('NotAuthorizedException', 'Refresh Token has been revoked');

      expect(await cubit.refresh(), isNull);
      expect(cubit.state, _unauthenticatedWith(AuthFailure.sessionExpired));
      expect(store.session, isNull);
    });

    test('a failure that does not end the session is thrown and keeps it', () async {
      final cubit = await signedIn();
      cognito.initiateAuth = (_) => FakeCognito.error('InternalErrorException', 'boom', status: 500);

      await expectLater(cubit.refresh(), throwsA(isA<AuthException>()));
      expect(cubit.state, AuthAuthenticated(initial));
    });

    test('without a session there is nothing to refresh', () async {
      final cubit = build();
      addTearDown(cubit.close);

      expect(await cubit.refresh(), isNull);
      expect(await cubit.validSession(), isNull);
      expect(cognito.calls, isEmpty);
    });

    test('validSession refreshes only close to expiry', () async {
      final cubit = await signedIn();
      cognito.initiateAuth = (_) => FakeCognito.authenticated(fresh);

      expect(await cubit.validSession(), initial);
      expect(cognito.calls, isEmpty);

      // Cognito hands out a session within the leeway of its expiry.
      final nearlyExpired = fakeSession('jane', validFor: const Duration(seconds: 30));
      cognito.initiateAuth = (_) => FakeCognito.authenticated(nearlyExpired);
      await cubit.signIn('jane', 'secret');
      expect(cubit.state, AuthAuthenticated(nearlyExpired));
      cognito.calls.clear();
      cognito.initiateAuth = (_) => FakeCognito.authenticated(fresh);

      expect(await cubit.validSession(), fresh);
      expect(cognito.operations, ['InitiateAuth']);
      expect(cognito.calls.single.body['AuthFlow'], 'REFRESH_TOKEN_AUTH');
    });

    test('a refresh that returns after a sign out does not revive the session', () async {
      store.session = initial;
      final response = Completer<http.Response>();
      cognito.initiateAuth = (_) => FakeCognito.authenticated(fresh);
      final slow = AuthCubit(
        CognitoAuthClient(
          userPoolId: FakeCognito.userPoolId,
          clientId: FakeCognito.clientId,
          httpClient: _DelayedClient(cognito.httpClient, response.future),
        ),
        store: store,
      );
      addTearDown(slow.close);
      await slow.restore();
      expect(slow.state.isAuthenticated, isTrue);

      final refreshing = slow.refresh();
      await slow.signOut();
      response.complete(http.Response('', 200));

      expect(await refreshing, isNull);
      expect(slow.state, const AuthUnauthenticated());
      expect(store.session, isNull);
    });
  });

  group('signOut', () {
    final session = fakeSession('jane', refreshToken: 'refresh-1');

    blocTest<AuthCubit, AuthState>(
      'drops the session and clears the store',
      setUp: () => store.session = session,
      build: build,
      act: (cubit) async {
        await cubit.restore();
        await cubit.signOut();
      },
      expect: () => [AuthAuthenticated(session), const AuthUnauthenticated()],
      verify: (_) {
        expect(store.session, isNull);
        expect(cognito.calls, isEmpty);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'with revoke also revokes the refresh token',
      setUp: () {
        store.session = session;
        cognito.revokeToken = (_) => FakeCognito.ok();
      },
      build: build,
      act: (cubit) async {
        await cubit.restore();
        await cubit.signOut(revoke: true);
      },
      skip: 1,
      expect: () => [const AuthUnauthenticated()],
      verify: (_) => expect(cognito.calls.single.body['Token'], 'refresh-1'),
    );

    blocTest<AuthCubit, AuthState>(
      'a failed revocation still signs out and reports the error',
      setUp: () {
        store.session = session;
        cognito.revokeToken = (_) => FakeCognito.error('InternalErrorException', 'boom', status: 500);
      },
      build: build,
      act: (cubit) async {
        await cubit.restore();
        await cubit.signOut(revoke: true);
      },
      skip: 1,
      expect: () => [const AuthUnauthenticated()],
      errors: () => [isA<AuthException>()],
    );
  });

  blocTest<AuthCubit, AuthState>(
    'a failing store does not fail the step and reports the error',
    build: () => AuthCubit(cognito.client(), store: _FailingStore()),
    setUp: () => cognito.initiateAuth = (_) => FakeCognito.authenticated(fakeSession('jane')),
    act: (cubit) => cubit.signIn('jane', 'secret'),
    expect: () => [const AuthInProgress(AuthStep.signIn), isA<AuthAuthenticated>()],
    errors: () => [isA<StateError>()],
  );
}

/// Fails every request before a response arrives.
class _OfflineClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => throw http.ClientException('XMLHttpRequest error.');
}

/// Holds every request until [gate] completes, then passes it to [inner].
class _DelayedClient extends http.BaseClient {
  _DelayedClient(this._inner, this._gate);

  final http.Client _inner;
  final Future<void> _gate;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _gate;
    return _inner.send(request);
  }
}

class _FailingStore implements AuthSessionStore {
  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> write(AuthSession session) => Future.error(StateError('disk full'));

  @override
  Future<void> clear() async {}
}
