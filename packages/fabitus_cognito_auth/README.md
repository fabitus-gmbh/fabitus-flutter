# fabitus_cognito_auth

Username and password login against an AWS Cognito user pool, for apps whose
backend sits behind an API Gateway Cognito authorizer: sign in, the
`NEW_PASSWORD_REQUIRED` challenge, session restore on start, token refresh and
sign out.

```dart
final auth = AuthCubit(
  CognitoAuthClient(userPoolId: 'eu-central-1_AbCdEfGhI', clientId: '1a2b3c4d5e6f7g8h9i0j'),
  store: sessionStore,
);
await auth.restore();
await auth.signIn('jane@fabit.us', password);

auth.state; // AuthAuthenticated(AuthSession(user: jane, expiresAt: ...))
```

Pure Dart, and it paints nothing. Attaching the token to requests is the job
of a transport adapter - [`fabitus_cognito_auth_dio`](../fabitus_cognito_auth_dio)
for Dio - and the route guard and headless login forms live in
[`fabitus_cognito_auth_flutter`](../fabitus_cognito_auth_flutter).

## Installation

```yaml
dependencies:
  fabitus_cognito_auth:
    git:
      url: https://github.com/fabitus-gmbh/fabitus-flutter.git
      path: packages/fabitus_cognito_auth
      ref: <commit or tag> # the same for every fabitus package, see the repo README
  fabitus_cognito_auth_dio: # if you use Dio, see its README
```

```dart
import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
```

## What the user pool needs

- A **public app client**, without a client secret - a secret shipped in an
  app is no secret, and the package does not send one.
- The auth flows `ALLOW_USER_PASSWORD_AUTH` (or `ALLOW_USER_SRP_AUTH`, see
  [below](#srp-or-plain-password)) and `ALLOW_REFRESH_TOKEN_AUTH`.
- An API Gateway **Cognito authorizer** on the same pool. Without OAuth scopes
  it validates the id token, which is what the Dio interceptor sends by
  default.

## The pieces

| Type | Job |
| --- | --- |
| `CognitoAuthClient` | Talks to Cognito. Stateless: signs in, answers the new password challenge, refreshes, revokes. |
| `AuthCubit` | The app's session. Restores it on start, refreshes it, persists it, signs out. |
| `AuthState` | Sealed: `AuthInitial`, `AuthInProgress`, `AuthUnauthenticated`, `AuthNewPasswordRequired`, `AuthAuthenticated`. |
| `AuthSession` | The three tokens. The `user` and the expiry are read from them. |
| `AuthUser` | Username, subject, email, groups and every other claim of the id token. |
| `AuthSessionStore` | Where the session survives a restart. In memory by default. |
| `PasswordPolicy` | The client side mirror of the pool's password policy, for the checklist under the new password field. |
| `AuthException` | Every failure, with an `AuthFailure` to branch on. |
| `AuthTokenSource` | The seam to the transport: the three calls an HTTP interceptor needs. `AuthCubit` implements it. |

## Wiring it up

One `AuthCubit` per app, created before the router and restored before it
reads the state:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final auth = AuthCubit(
    CognitoAuthClient(userPoolId: config.cognitoUserPoolId, clientId: config.cognitoClientId),
    store: KeyValueAuthSessionStore(
      read: prefs.getString,
      write: prefs.setString,
      remove: prefs.remove,
    ),
    passwordPolicy: const PasswordPolicy(minimumLength: 12, requireSymbol: false),
  );
  await auth.restore();

  getIt.registerSingleton<AuthCubit>(auth);
  runApp(BlocProvider.value(value: auth, child: const App()));
}
```

`restore` looks at the stored session and ends in `AuthAuthenticated` or
`AuthUnauthenticated`. An expired session is refreshed first; one whose refresh
token Cognito rejects ends in `AuthUnauthenticated` with
`AuthFailure.sessionExpired`. Offline, an expired session is restored as it is
and refreshed by the first request once the network is back.

## The login page and the route guard

[`fabitus_cognito_auth_flutter`](../fabitus_cognito_auth_flutter) has both,
without a pixel of design: headless `SignInForm` and `NewPasswordForm`, a
`SignInFlow` switching between them, an `AuthGate`, and `AuthRedirect` with
`AuthRefreshListenable` for go_router. Without it, render the state yourself:

```dart
BlocBuilder<AuthCubit, AuthState>(
  builder: (context, state) => switch (state) {
    AuthInitial() || AuthInProgress(step: AuthStep.restore) => const Splash(),
    AuthNewPasswordRequired() || AuthInProgress(step: AuthStep.newPassword) => const NewPasswordForm(),
    AuthUnauthenticated() || AuthInProgress() => const LoginForm(),
    AuthAuthenticated() => const SizedBox.shrink(), // the router takes over
  },
);
```

The package has no messages of its own. `AuthFailure` says what went wrong and
you say it:

```dart
String describe(AuthFailure failure) => switch (failure) {
  AuthFailure.missingCredentials => 'Bitte gib E-Mail und Passwort an.',
  AuthFailure.invalidCredentials => 'E-Mail oder Passwort ist ungültig.',
  AuthFailure.invalidPassword => 'Das Passwort erfüllt nicht alle Anforderungen.',
  AuthFailure.sessionExpired => 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.',
  AuthFailure.tooManyRequests => 'Zu viele Versuche. Bitte warte einen Moment.',
  AuthFailure.network => 'Keine Verbindung. Bitte prüfe dein Netzwerk.',
  _ => 'Anmeldung fehlgeschlagen. Bitte versuche es erneut.',
};
```

A wrong password and an unknown user are both `invalidCredentials`, so the form
cannot be used to find out who has an account.

## The new password challenge

A user an administrator created has a temporary password. Signing in with it
ends in `AuthNewPasswordRequired`; `submitNewPassword` answers it and ends in
`AuthAuthenticated`.

With a `passwordPolicy` the cubit rejects a password that breaks it before it
goes to Cognito. Either way a rejected password keeps the challenge open - the
state stays `AuthNewPasswordRequired`, now with `AuthFailure.invalidPassword`.
Cognito keeps a challenge for three minutes; after that, or after a restart,
the answer ends in `AuthUnauthenticated` with `AuthFailure.noPendingChallenge`.

Some pools require attributes along with the password;
`AuthNewPasswordRequired.requiredAttributes` names them and
`submitNewPassword(password, attributes: {'name': 'Jane'})` sends them.

## The password checklist

`PasswordPolicy` mirrors the pool's policy. Its defaults are Cognito's defaults
- eight characters, every rule - so configure it to match your pool:

```dart
const policy = PasswordPolicy(minimumLength: 12, requireSymbol: false);

String label(PasswordRequirement requirement) => switch (requirement) {
  PasswordRequirement.minimumLength => 'Mindestens ${policy.minimumLength} Zeichen',
  PasswordRequirement.uppercase => 'Mindestens 1 Großbuchstabe',
  PasswordRequirement.lowercase => 'Mindestens 1 Kleinbuchstabe',
  PasswordRequirement.digit => 'Mindestens 1 Zahl',
  PasswordRequirement.symbol => 'Mindestens 1 Sonderzeichen',
};

Column(
  children: [
    for (final requirement in policy.requirements)
      CheckRow(label: label(requirement), checked: policy.isMet(requirement, password)),
  ],
);
```

Letters are matched Unicode aware, so 'Ä' is an uppercase letter; digits are
ASCII. `PasswordPolicy.confirmationMatches` checks the repeat field.

## Refresh and sign out

The HTTP interceptor refreshes the session - before a token expires and once
more on a 401 - so the app rarely has to. When it does:

- `auth.validSession()` returns a session that does not expire in the next
  minute, refreshing first if needed.
- `auth.refresh()` refreshes now. Concurrent calls share one request to Cognito.

A refresh token that Cognito rejects - expired, revoked, the user disabled -
ends the session: the state becomes `AuthUnauthenticated` with
`AuthFailure.sessionExpired`, the store is cleared, and the route guard sends the
user to the login page. Any other failure, a network failure above all, is
thrown and leaves the session alone.

`auth.signOut()` drops the session here and in the store. `signOut(revoke: true)`
also revokes the refresh token at Cognito, so a copy of it is worthless. Id and
access tokens stay valid until they expire - an hour by default - because
Cognito cannot recall them.

With **refresh token rotation** enabled on the app client, pass
`refreshTokenRotation: true` to the client; it then refreshes through
`GetTokensFromRefreshToken` and stores the new refresh token each time.

## Keeping the session

`AuthSessionStore` has three methods; `KeyValueAuthSessionStore` adapts any
string key-value storage to it.

**shared_preferences** - `localStorage` on web:

```dart
final prefs = SharedPreferencesAsync();
final store = KeyValueAuthSessionStore(read: prefs.getString, write: prefs.setString, remove: prefs.remove);
```

**flutter_secure_storage** - Keychain and Keystore on mobile:

```dart
const storage = FlutterSecureStorage();
final store = KeyValueAuthSessionStore(
  read: (key) => storage.read(key: key),
  write: (key, value) => storage.write(key: key, value: value),
  remove: (key) => storage.delete(key: key),
);
```

On web every option is readable by script on the page, so a cross site
scripting hole exposes the refresh token. That is the trade-off of staying
signed in across reloads in a browser; keep the refresh token lifetime short,
and revoke on sign out.

A store that fails does not fail sign in: the session lives on in memory, and
the error goes to the cubit's `onError` - and your `BlocObserver`. A stored
value that cannot be read back counts as no session.

## SRP or plain password

`CognitoAuthFlow.userPassword` (`USER_PASSWORD_AUTH`) is the default: the
password goes to Cognito over TLS. `CognitoAuthFlow.srp` keeps the password on
the device, but its big integer arithmetic runs synchronously on the main
isolate and freezes Flutter web for seconds. Use it on mobile and desktop if
your security requirements ask for it:

```dart
CognitoAuthClient(userPoolId: ..., clientId: ..., authFlow: CognitoAuthFlow.srp);
```

## Testing

`package:fabitus_cognito_auth/testing.dart` answers Cognito's protocol in
memory, so an `AuthCubit` - and the login page or route guard around it - runs in
a test without a user pool:

```dart
final cognito = FakeCognito()
  ..initiateAuth = (_) => FakeCognito.authenticated(fakeSession('jane', groups: ['admin']));
final auth = AuthCubit(cognito.client());

await auth.signIn('jane', 'secret');
expect(auth.state.sessionOrNull?.user.groups, ['admin']);
```

`FakeCognito.newPasswordChallenge()` and `FakeCognito.error('NotAuthorizedException', ...)`
cover the other paths; `cognito.calls` records what was sent.

## Not covered

MFA and custom challenges end in `AuthFailure.unsupportedChallenge`. Sign up,
forgot password and hosted UI (OAuth) logins are not part of this package yet.

## Migrating from an app's own AuthBloc

This package grew out of the auth module of the DMB Slicer frontend. If your app
has that module:

| Before | Now |
| --- | --- |
| `AuthService` | `CognitoAuthClient` |
| `AuthBloc` (hydrated) | `AuthCubit` with an `AuthSessionStore` |
| `AuthEvent.appStarted()` | `await auth.restore()` |
| `AuthEvent.loginSubmitted(...)` | `auth.signIn(username, password)` |
| `AuthEvent.newPasswordSubmitted(pw)` | `auth.submitNewPassword(pw)` |
| `AuthEvent.logoutRequested()` | `auth.signOut()` |
| `AuthEvent.tokenRefreshed` / `sessionExpired` | gone - `refresh()` does both |
| `AuthState.unauthenticated(error: 'German text')` | `AuthUnauthenticated(error: AuthException(AuthFailure...))` |
| `state.auth` / `state.isLoggedIn` | `state.sessionOrNull` / `state.isAuthenticated` |
| `auth.user.userName` / `userId` | `session.user.displayName` / `username` |
| static `PasswordPolicy` | `const PasswordPolicy(minimumLength: 12, requireSymbol: false)` |
| `TokenRefreshInterceptor` | `CognitoAuthInterceptor` from `fabitus_cognito_auth_dio` |

`AuthSession.fromJson` reads the JSON the old `Auth` model wrote, so a session
persisted before the switch survives it.

## Related

| Package | Role |
| --- | --- |
| [`fabitus_cognito_auth_dio`](../fabitus_cognito_auth_dio) | attaches the token to Dio requests and refreshes it |
| [`fabitus_cognito_auth_flutter`](../fabitus_cognito_auth_flutter) | route guard, auth gate and headless login forms |
| [`fabitus_feature_modules`](../fabitus_feature_modules) | role based access; feed it `session.user.groups` |

## License

[MIT](LICENSE) © Fabitus GmbH.
