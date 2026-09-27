# fabitus_cognito_auth_flutter example

A complete login in one file: an `AuthGate`, a login page from `SignInFlow`,
`SignInForm` and `NewPasswordForm`, and a home page with a sign out button -
drawn with plain Material widgets from the example, not from the package.

Without configuration it runs against the in-memory `FakeCognito`: sign in as
`jane` / `secret`, or as `new` / `temporary` to get the new password challenge.
Against a real user pool:

```sh
flutter run -t example/main.dart \
  --dart-define=USER_POOL_ID=eu-central-1_AbCdEfGhI \
  --dart-define=CLIENT_ID=1a2b3c4d5e6f7g8h9i0j
```

With go_router, swap the `AuthGate` for `AuthRedirect` and
`AuthRefreshListenable` - see the package README.
