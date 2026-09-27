# fabitus_cognito_auth_flutter

The Flutter side of [`fabitus_cognito_auth`](../fabitus_cognito_auth): the route
guard, an auth gate, and the sign in and new password forms - without a pixel of
design.

```dart
LoginPage: SignInFlow(
  signIn: (context) => SignInForm(builder: (context, form) => MySignInFields(form)),
  newPassword: (context) => NewPasswordForm(builder: (context, form) => MyNewPasswordFields(form)),
)
```

Every login page wires the same things: two text controllers, the call to the
cubit, the switch to the new password form, a live password checklist, a
disabled button while a request is on its way, the redirect to the login and
back to where the user wanted to go. This package does that wiring and hands
your builder what it needs. What the fields, buttons and messages look like - and
say - stays yours: nothing imports `material.dart`, and there is no text in
here.

## Installation

```yaml
dependencies:
  fabitus_cognito_auth: # ... (see its README)
  fabitus_cognito_auth_flutter:
    git:
      url: https://github.com/fabitus-gmbh/fabitus-flutter.git
      path: packages/fabitus_cognito_auth_flutter
      ref: <commit or tag> # the same for every fabitus package, see the repo README
```

```dart
import 'package:fabitus_cognito_auth_flutter/fabitus_cognito_auth_flutter.dart';
```

It needs the `AuthCubit` in a `BlocProvider` above the widgets, or passed to
each as `cubit:`.

## The pieces

| Type | Job |
| --- | --- |
| `AuthRedirect` | The route guard: a plain function of the state and the location, for any router. |
| `AuthRefreshListenable` | Tells the router to ask the guard again, when somebody signs in or out. |
| `AuthGate` | One subtree while restoring, one signed out, one signed in. |
| `SignInFlow` | Switches a login page between the sign in and the new password form. |
| `SignInForm` | Owns username and password controllers; your builder gets `SignInFormData`. |
| `NewPasswordForm` | Owns password and confirmation controllers and the checklist; your builder gets `NewPasswordFormData`. |

## The route guard

```dart
const guard = AuthRedirect(loginPath: '/login', homePath: '/files', publicPaths: {'/'});

final router = GoRouter(
  refreshListenable: AuthRefreshListenable(auth),
  redirect: (context, state) => guard(auth.state, state.uri),
  routes: [...],
);
```

| Signed | At | Goes to |
| --- | --- | --- |
| out | a page that is neither the login nor public | `/login?from=<where it wanted to go>` |
| out | the login, or a public page | stays |
| in | the login | `from`, or `homePath` |
| in | anywhere else | stays |
| not known yet (restoring) | anywhere | stays, or `restoringPath` if you have a splash screen |

The session ending on its own - the refresh token expired mid use - is a sign
out like any other: the listenable fires, the guard sends the user to the login,
and `from` brings them back afterwards.

`from` is honoured only when it is a path inside the app, so a crafted link like
`/login?from=https://evil.example` cannot send a freshly signed in user off
site.

`AuthRefreshListenable` fires only when the guard's answer can change - not on
the hourly token refresh. Nothing here depends on go_router; any router with a
redirect hook works the same way.

## The login page

`SignInFlow` shows the new password form while Cognito waits for a new password
- including while the answer is on its way - and the sign in form otherwise:

```dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => MyCard(
    child: SignInFlow(
      signIn: (context) => SignInForm(builder: _signIn),
      newPassword: (context) => NewPasswordForm(builder: _newPassword),
    ),
  );
}

Widget _signIn(BuildContext context, SignInFormData form) => AutofillGroup(
  child: Column(
    children: [
      MyTextField(label: 'E-Mail', controller: form.username, autofillHints: const [AutofillHints.username]),
      MyTextField(
        label: 'Passwort',
        controller: form.password,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) => form.submit?.call(),
      ),
      if (form.error case final error?) MyError(describe(error.failure)),
      MyButton(label: 'Anmelden', busy: form.isSubmitting, onPressed: form.submit),
    ],
  ),
);

Widget _newPassword(BuildContext context, NewPasswordFormData form) => Column(
  children: [
    MyTextField(label: 'Neues Passwort', controller: form.newPassword, obscureText: true),
    for (final check in form.checklist) MyCheckRow(label: label(check.requirement), checked: check.isMet),
    MyTextField(label: 'Passwort bestätigen', controller: form.confirmation, obscureText: true),
    MyCheckRow(label: 'Passwörter stimmen überein', checked: form.confirmationMatches),
    if (form.error case final error?) MyError(describe(error.failure)),
    MyButton(label: 'Passwort speichern', busy: form.isSubmitting, onPressed: form.submit),
    MyQuietButton(label: 'Zurück zur Anmeldung', onPressed: form.cancel),
  ],
);
```

`describe` and `label` are yours - see the
[`fabitus_cognito_auth` README](../fabitus_cognito_auth#the-login-page-and-the-route-guard)
for both. After a successful sign in there is nothing to do: the guard sends the
user on.

### What the builders get

`SignInFormData`:

| Member | Is |
| --- | --- |
| `username`, `password` | the controllers, owned by the form |
| `submit` | signs in; `null` while a sign in is running |
| `isSubmitting` | a sign in is running |
| `error` | why the last attempt failed, or `sessionExpired` when that is why the user is here |
| `hasInput` | both fields are filled, for a button that stays disabled until they are |

`NewPasswordFormData`:

| Member | Is |
| --- | --- |
| `newPassword`, `confirmation` | the controllers, owned by the form |
| `checklist` | one `(requirement, isMet)` per rule of the policy, updated as the user types |
| `meetsPolicy`, `confirmationMatches` | the two conditions for sending |
| `submit` | sends the password; `null` until both conditions hold, and while sending |
| `cancel` | gives up and returns to the sign in form |
| `error` | why the last password was rejected |
| `requiredAttributes` | attributes the pool wants along with the password, usually none |

The checklist follows the cubit's `passwordPolicy`, or the `policy:` passed to
the form. A pool that requires attributes gets them through
`NewPasswordForm(attributes: () => {'name': nameController.text})`.

## Without a router guard

`AuthGate` picks a subtree:

```dart
AuthGate(
  restoring: (context) => const Splash(),
  signedOut: (context) => const LoginPage(),
  signedIn: (context, user) => HomePage(user: user),
);
```

It rebuilds only when the answer changes, so the login page keeps its text
fields through a failed attempt, and the app is not rebuilt on every token
refresh. `signedIn` gets the `AuthUser`, which stays the same across refreshes;
read the cubit for the current tokens.

## Testing

`package:fabitus_cognito_auth/testing.dart` fakes Cognito, so these widgets - and
your pages built with them - run in a widget test against a real `AuthCubit`:

```dart
final cognito = FakeCognito()..initiateAuth = (_) => FakeCognito.authenticated(fakeSession('jane'));
final auth = AuthCubit(cognito.client());

await tester.pumpWidget(BlocProvider.value(value: auth, child: const MaterialApp(home: LoginPage())));
await tester.enterText(find.byType(TextField).first, 'jane');
...
```

Run the cubit's calls inside `tester.runAsync` when you drive it directly.

## Related

| Package | Role |
| --- | --- |
| [`fabitus_cognito_auth`](../fabitus_cognito_auth) | the Cognito client, the session and the `AuthCubit` |
| [`fabitus_cognito_auth_dio`](../fabitus_cognito_auth_dio) | attaches the token to Dio requests and refreshes it |
| [`fabitus_crud_api_forms`](../fabitus_crud_api_forms) | the same headless approach, for entity forms |

## License

[MIT](LICENSE) © Fabitus GmbH.
