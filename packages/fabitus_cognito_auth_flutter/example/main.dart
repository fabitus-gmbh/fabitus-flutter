// A complete login, with a deliberately plain look - every pixel below comes
// from this file, not from the package.
//
// Like the other Flutter packages here it has no `dart run`: widgets need a host
// app. It is analyzed as part of the package, so it cannot rot, and the widget
// tests in `test/` exercise the same paths headlessly.
import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:fabitus_cognito_auth/testing.dart';
import 'package:fabitus_cognito_auth_flutter/fabitus_cognito_auth_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _userPoolId = String.fromEnvironment('USER_POOL_ID');
const _clientId = String.fromEnvironment('CLIENT_ID');
const _policy = PasswordPolicy(minimumLength: 12, requireSymbol: false);

Future<void> main() async {
  final client = _userPoolId.isEmpty
      ? _demoCognito().client()
      : CognitoAuthClient(userPoolId: _userPoolId, clientId: _clientId);
  final auth = AuthCubit(client, passwordPolicy: _policy);
  await auth.restore();
  runApp(BlocProvider.value(value: auth, child: const ExampleApp()));
}

/// jane / secret signs in; new / temporary has to set a new password first.
FakeCognito _demoCognito() {
  final cognito = FakeCognito();
  cognito.initiateAuth = (body) {
    final parameters = body['AuthParameters'] as Map<String, dynamic>;
    return switch ((parameters['USERNAME'], parameters['PASSWORD'])) {
      (_, null) => FakeCognito.authenticated(fakeSession('jane')), // a refresh
      ('jane', 'secret') => FakeCognito.authenticated(fakeSession('jane', groups: ['editor'])),
      ('new', 'temporary') => FakeCognito.newPasswordChallenge(),
      _ => FakeCognito.error('NotAuthorizedException', 'Incorrect username or password.'),
    };
  };
  cognito.respondToAuthChallenge = (_) => FakeCognito.authenticated(fakeSession('new'));
  return cognito;
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Login example',
    home: AuthGate(
      restoring: (_) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      signedOut: (_) => const LoginPage(),
      signedIn: (_, user) => HomePage(user: user),
    ),
  );
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SignInFlow(
              signIn: (_) => SignInForm(builder: _signIn),
              newPassword: (_) => NewPasswordForm(builder: _newPassword),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _signIn(BuildContext context, SignInFormData form) => AutofillGroup(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: form.username,
        decoration: const InputDecoration(labelText: 'E-Mail'),
        autofillHints: const [AutofillHints.username],
      ),
      TextField(
        controller: form.password,
        decoration: const InputDecoration(labelText: 'Passwort'),
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) => form.submit?.call(),
      ),
      if (form.error case final error?) _Error(_describe(error.failure)),
      const SizedBox(height: 24),
      FilledButton(onPressed: form.submit, child: form.isSubmitting ? const _Spinner() : const Text('Anmelden')),
    ],
  ),
);

Widget _newPassword(BuildContext context, NewPasswordFormData form) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const Text('Bitte lege ein neues Passwort fest, um die Anmeldung abzuschließen.'),
    TextField(
      controller: form.newPassword,
      decoration: const InputDecoration(labelText: 'Neues Passwort'),
      obscureText: true,
      autofillHints: const [AutofillHints.newPassword],
    ),
    const SizedBox(height: 8),
    for (final check in form.checklist) _Check(_label(check.requirement), met: check.isMet),
    TextField(
      controller: form.confirmation,
      decoration: const InputDecoration(labelText: 'Passwort bestätigen'),
      obscureText: true,
      onSubmitted: (_) => form.submit?.call(),
    ),
    const SizedBox(height: 8),
    _Check('Passwörter stimmen überein', met: form.confirmationMatches),
    if (form.error case final error?) _Error(_describe(error.failure)),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: form.submit,
      child: form.isSubmitting ? const _Spinner() : const Text('Passwort speichern'),
    ),
    TextButton(onPressed: form.cancel, child: const Text('Zurück zur Anmeldung')),
  ],
);

class HomePage extends StatelessWidget {
  const HomePage({required this.user, super.key});

  final AuthUser user;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Hallo ${user.displayName}'),
      actions: [
        IconButton(
          tooltip: 'Abmelden',
          icon: const Icon(Icons.logout),
          onPressed: () => context.read<AuthCubit>().signOut(),
        ),
      ],
    ),
    body: Center(child: Text('Gruppen: ${user.groups.isEmpty ? 'keine' : user.groups.join(', ')}')),
  );
}

String _describe(AuthFailure failure) => switch (failure) {
  AuthFailure.missingCredentials => 'Bitte gib E-Mail und Passwort an.',
  AuthFailure.invalidCredentials => 'E-Mail oder Passwort ist ungültig.',
  AuthFailure.invalidPassword => 'Das Passwort erfüllt nicht alle Anforderungen.',
  AuthFailure.sessionExpired => 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.',
  AuthFailure.noPendingChallenge => 'Die Anfrage ist abgelaufen. Bitte melde dich erneut an.',
  AuthFailure.tooManyRequests => 'Zu viele Versuche. Bitte warte einen Moment.',
  AuthFailure.network => 'Keine Verbindung. Bitte prüfe dein Netzwerk.',
  _ => 'Anmeldung fehlgeschlagen. Bitte versuche es erneut.',
};

String _label(PasswordRequirement requirement) => switch (requirement) {
  PasswordRequirement.minimumLength => 'Mindestens ${_policy.minimumLength} Zeichen',
  PasswordRequirement.uppercase => 'Mindestens 1 Großbuchstabe',
  PasswordRequirement.lowercase => 'Mindestens 1 Kleinbuchstabe',
  PasswordRequirement.digit => 'Mindestens 1 Zahl',
  PasswordRequirement.symbol => 'Mindestens 1 Sonderzeichen',
};

class _Check extends StatelessWidget {
  const _Check(this.label, {required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: met ? Colors.green : Colors.grey),
      const SizedBox(width: 8),
      Text(label),
    ],
  );
}

class _Error extends StatelessWidget {
  const _Error(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2));
}
