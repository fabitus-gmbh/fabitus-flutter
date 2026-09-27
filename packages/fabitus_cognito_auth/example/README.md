# fabitus_cognito_auth example

Signs in to a real user pool, prints who you are and when the tokens expire,
refreshes them and signs out again. Needs a public app client that allows
`USER_PASSWORD_AUTH` and `REFRESH_TOKEN_AUTH`.

```sh
dart run example/main.dart <user pool id> <app client id> <username> <password>
```

A user with a temporary password is asked for a new one on stdin.
