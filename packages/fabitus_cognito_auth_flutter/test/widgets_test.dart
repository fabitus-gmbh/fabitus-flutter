import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:fabitus_cognito_auth/testing.dart';
import 'package:fabitus_cognito_auth_flutter/fabitus_cognito_auth_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] under a provider for [auth].
Future<void> _pump(WidgetTester tester, AuthCubit auth, Widget child) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: BlocProvider.value(value: auth, child: child),
  ),
);

/// Lets the fake Cognito answer and the widgets rebuild.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(pumpEventQueue);
  await tester.pump();
}

void main() {
  late FakeCognito cognito;
  late AuthCubit auth;

  setUp(() {
    cognito = FakeCognito();
    auth = AuthCubit(cognito.client(), passwordPolicy: const PasswordPolicy(minimumLength: 12, requireSymbol: false));
  });

  tearDown(() => auth.close());

  group('AuthGate', () {
    Widget gate() => AuthGate(
      restoring: (_) => const Text('restoring'),
      signedOut: (_) => const Text('signed out'),
      signedIn: (_, user) => Text('hello ${user.username}'),
    );

    testWidgets('follows the session from restore to sign in to sign out', (tester) async {
      cognito.initiateAuth = (_) => FakeCognito.authenticated(fakeSession('jane'));
      await _pump(tester, auth, gate());
      expect(find.text('restoring'), findsOneWidget);

      await tester.runAsync(auth.restore);
      await tester.pump();
      expect(find.text('signed out'), findsOneWidget);

      await tester.runAsync(() => auth.signIn('jane', 'secret'));
      await tester.pump();
      expect(find.text('hello jane'), findsOneWidget);

      await tester.runAsync(auth.signOut);
      await tester.pump();
      expect(find.text('signed out'), findsOneWidget);
    });

    testWidgets('keeps the signed out subtree through a sign in attempt', (tester) async {
      cognito.initiateAuth = (_) => FakeCognito.error('NotAuthorizedException', 'Incorrect');
      await tester.runAsync(auth.restore);
      final key = GlobalKey();
      await _pump(
        tester,
        auth,
        AuthGate(
          signedOut: (_) => SizedBox(key: key),
          signedIn: (_, _) => const SizedBox(),
        ),
      );
      final element = tester.element(find.byKey(key));

      await tester.runAsync(() => auth.signIn('jane', 'wrong'));
      await tester.pump();

      expect(tester.element(find.byKey(key)), same(element));
    });
  });

  group('SignInForm', () {
    late SignInFormData form;

    Widget signInForm() => SignInForm(
      initialUsername: 'jane',
      builder: (_, data) {
        form = data;
        return Text('busy: ${data.isSubmitting}, error: ${data.error?.failure.name}');
      },
    );

    testWidgets('signs in with what the fields hold', (tester) async {
      cognito.initiateAuth = (_) => FakeCognito.authenticated(fakeSession('jane'));
      await _pump(tester, auth, signInForm());

      expect(form.username.text, 'jane');
      expect(form.hasInput, isFalse);
      form.password.text = 'secret';
      await tester.pump();
      expect(form.hasInput, isTrue);

      form.submit!();
      // The fake answers within the next pump, so look before it.
      expect(auth.state, const AuthInProgress(AuthStep.signIn));

      await _settle(tester);
      expect(auth.state.isAuthenticated, isTrue);
      expect(cognito.calls.single.body['AuthParameters'], containsPair('PASSWORD', 'secret'));
    });

    testWidgets('shows why the sign in failed', (tester) async {
      cognito.initiateAuth = (_) => FakeCognito.error('NotAuthorizedException', 'Incorrect');
      await _pump(tester, auth, signInForm());

      form.password.text = 'wrong';
      form.submit!();
      await _settle(tester);

      expect(find.text('busy: false, error: invalidCredentials'), findsOneWidget);
      expect(form.submit, isNotNull);
    });
  });

  group('the new password step', () {
    late NewPasswordFormData form;

    Widget flow() => SignInFlow(
      signIn: (_) => SignInForm(builder: (_, _) => const Text('sign in')),
      newPassword: (_) => NewPasswordForm(
        builder: (_, data) {
          form = data;
          return const Text('new password');
        },
      ),
    );

    setUp(() {
      cognito.initiateAuth = (_) => FakeCognito.newPasswordChallenge();
      cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(fakeSession('jane'));
    });

    testWidgets('switches to the new password form and stays there while it is sent', (tester) async {
      await _pump(tester, auth, flow());
      expect(find.text('sign in'), findsOneWidget);

      await tester.runAsync(() => auth.signIn('jane', 'temporary'));
      await tester.pump();
      expect(find.text('new password'), findsOneWidget);

      form.newPassword.text = 'Sicher123456';
      form.confirmation.text = 'Sicher123456';
      await tester.pump();
      form.submit!();
      expect(auth.state, const AuthInProgress(AuthStep.newPassword));
      expect(SignInFlow.isNewPasswordStep(auth.state), isTrue);

      await _settle(tester);
      expect(auth.state.isAuthenticated, isTrue);
    });

    testWidgets('checks the policy and the confirmation as the user types', (tester) async {
      await _pump(tester, auth, flow());
      await tester.runAsync(() => auth.signIn('jane', 'temporary'));
      await tester.pump();

      expect(form.checklist.map((c) => c.requirement), [
        PasswordRequirement.minimumLength,
        PasswordRequirement.uppercase,
        PasswordRequirement.lowercase,
        PasswordRequirement.digit,
      ]);
      expect(form.submit, isNull);

      form.newPassword.text = 'sicher123456';
      await tester.pump();
      expect(
        {for (final c in form.checklist) c.requirement: c.isMet},
        {
          PasswordRequirement.minimumLength: true,
          PasswordRequirement.uppercase: false,
          PasswordRequirement.lowercase: true,
          PasswordRequirement.digit: true,
        },
      );
      expect(form.meetsPolicy, isFalse);

      form.newPassword.text = 'Sicher123456';
      form.confirmation.text = 'Sicher12345';
      await tester.pump();
      expect(form.meetsPolicy, isTrue);
      expect(form.confirmationMatches, isFalse);
      expect(form.submit, isNull);

      form.confirmation.text = 'Sicher123456';
      await tester.pump();
      expect(form.submit, isNotNull);
    });

    testWidgets('shows a password Cognito rejects and keeps the form', (tester) async {
      cognito.respondToAuthChallenge = (_) => FakeCognito.error('InvalidPasswordException', 'Too common');
      await _pump(tester, auth, flow());
      await tester.runAsync(() => auth.signIn('jane', 'temporary'));
      await tester.pump();

      form.newPassword.text = 'Sicher123456';
      form.confirmation.text = 'Sicher123456';
      await tester.pump();
      form.submit!();
      await _settle(tester);

      expect(find.text('new password'), findsOneWidget);
      expect(form.error?.failure, AuthFailure.invalidPassword);
    });

    testWidgets('cancel returns to the sign in form', (tester) async {
      await _pump(tester, auth, flow());
      await tester.runAsync(() => auth.signIn('jane', 'temporary'));
      await tester.pump();

      form.cancel!();
      await _settle(tester);

      expect(find.text('sign in'), findsOneWidget);
      expect(auth.state, const AuthUnauthenticated());
    });
  });
}
