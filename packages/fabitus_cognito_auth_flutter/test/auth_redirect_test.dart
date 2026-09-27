import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:fabitus_cognito_auth/testing.dart';
import 'package:fabitus_cognito_auth_flutter/fabitus_cognito_auth_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const guard = AuthRedirect(loginPath: '/login', homePath: '/files', publicPaths: {'/', '/imprint'});
  final signedIn = AuthAuthenticated(fakeSession('jane'));
  const signedOut = AuthUnauthenticated();

  String? redirect(AuthState state, String location) => guard(state, Uri.parse(location));

  group('signed out', () {
    test('goes to the login, remembering where it wanted to go', () {
      expect(redirect(signedOut, '/projects/42?tab=files'), '/login?from=%2Fprojects%2F42%3Ftab%3Dfiles');
    });

    test('stays on the login and on public pages', () {
      expect(redirect(signedOut, '/login'), isNull);
      expect(redirect(signedOut, '/'), isNull);
      expect(redirect(signedOut, '/imprint'), isNull);
    });

    test('stays on the login while signing in or setting a new password', () {
      expect(redirect(const AuthInProgress(AuthStep.signIn), '/login'), isNull);
      expect(redirect(const AuthNewPasswordRequired(), '/login'), isNull);
    });

    test('does not remember the home page', () {
      expect(redirect(signedOut, '/files'), '/login');
    });
  });

  group('signed in', () {
    test('leaves the login for the page it came from', () {
      expect(redirect(signedIn, '/login?from=%2Fprojects%2F42%3Ftab%3Dfiles'), '/projects/42?tab=files');
    });

    test('leaves the login for home without a from', () {
      expect(redirect(signedIn, '/login'), '/files');
    });

    test('ignores a from that leaves the app', () {
      expect(redirect(signedIn, '/login?from=https%3A%2F%2Fevil.example'), '/files');
      expect(redirect(signedIn, '/login?from=%2F%2Fevil.example%2Fx'), '/files');
      expect(redirect(signedIn, '/login?from=%2Flogin'), '/files');
    });

    test('stays anywhere else', () {
      expect(redirect(signedIn, '/projects/42'), isNull);
      expect(redirect(signedIn, '/'), isNull);
    });
  });

  group('while restoring', () {
    test('stays put without a splash screen', () {
      expect(redirect(const AuthInitial(), '/projects/42'), isNull);
      expect(redirect(const AuthInProgress(AuthStep.restore), '/projects/42'), isNull);
    });

    test('waits on the splash screen and continues from there', () {
      const withSplash = AuthRedirect(loginPath: '/login', homePath: '/files', restoringPath: '/splash');

      final toSplash = withSplash(const AuthInitial(), Uri.parse('/projects/42'));
      expect(toSplash, '/splash?from=%2Fprojects%2F42');
      expect(withSplash(const AuthInitial(), Uri.parse(toSplash!)), isNull);

      expect(withSplash(signedIn, Uri.parse(toSplash)), '/projects/42');
      expect(withSplash(signedOut, Uri.parse(toSplash)), '/login?from=%2Fprojects%2F42');
    });
  });

  group('AuthRefreshListenable', () {
    test('notifies when the answer can change, not on every refresh', () async {
      final cognito = FakeCognito();
      cognito.initiateAuth = (_) => FakeCognito.authenticated(fakeSession('jane'));
      final auth = AuthCubit(cognito.client());
      final listenable = AuthRefreshListenable(auth);
      var notifications = 0;
      listenable.addListener(() => notifications++);
      addTearDown(() async {
        listenable.dispose();
        await auth.close();
      });

      await auth.restore(); // restored: notifies
      await auth.signIn('jane', 'secret'); // signed in: notifies
      await auth.refresh(); // same answer: silent
      await auth.signOut(); // signed out: notifies
      await pumpEventQueue();

      expect(notifications, 3);
    });
  });

  test('AuthState.isRestored is false only before the restore settles', () {
    expect(const AuthInitial().isRestored, isFalse);
    expect(const AuthInProgress(AuthStep.restore).isRestored, isFalse);
    expect(const AuthInProgress(AuthStep.signIn).isRestored, isTrue);
    expect(signedOut.isRestored, isTrue);
    expect(signedIn.isRestored, isTrue);
  });
}
