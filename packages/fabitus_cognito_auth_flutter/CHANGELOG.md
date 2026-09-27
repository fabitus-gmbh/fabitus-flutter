# Changelog

## 0.1.0

Initial release.

- `AuthRedirect`, the route guard as a plain function of the state and the
  location: signed out to the login with the original location in `from`,
  signed in back to it, and a restore that is not sent anywhere yet. A `from`
  outside the app is ignored.
- `AuthRefreshListenable`, go_router's `refreshListenable`, firing only when
  the guard's answer can change.
- `AuthGate`, one subtree each for restoring, signed out and signed in.
- `SignInFlow`, switching a login page between its two forms.
- `SignInForm` and `NewPasswordForm`: headless forms owning the controllers,
  the live password checklist and the wiring to the `AuthCubit`.
