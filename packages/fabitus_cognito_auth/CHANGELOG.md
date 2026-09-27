# Changelog

## 0.1.0

Initial release, generalised from the auth module of the DMB Slicer frontend.

- `CognitoAuthClient`: username and password sign in (`USER_PASSWORD_AUTH` by
  default, SRP on request), the `NEW_PASSWORD_REQUIRED` challenge, refresh with
  and without refresh token rotation, and refresh token revocation. Every
  failure is an `AuthException` with an `AuthFailure` to branch on, instead of
  a hard coded message.
- `AuthCubit`: restore on start, sign in, new password, refresh with concurrent
  calls deduplicated, sign out. A refresh that returns after a sign out no
  longer revives the session, and a network failure during a refresh no longer
  signs the user out.
- `AuthSession` and `AuthUser`, read from the tokens; `toString` redacts them.
  `AuthSession.fromJson` reads the JSON of the earlier `Auth` model.
- `AuthSessionStore`, with `InMemoryAuthSessionStore` and
  `KeyValueAuthSessionStore`, instead of a dependency on `hydrated_bloc`.
- `PasswordPolicy`, configurable to match the user pool, with the rules as
  `PasswordRequirement` values rather than German labels.
- `AuthTokenSource`, the seam for transport adapters.
