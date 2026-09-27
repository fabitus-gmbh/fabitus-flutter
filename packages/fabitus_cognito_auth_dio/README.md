# fabitus_cognito_auth_dio

The Dio interceptor for [`fabitus_cognito_auth`](../fabitus_cognito_auth): it
attaches the Cognito token to API requests and keeps it fresh.

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.fabit.us/todos'));
dio.interceptors.add(CognitoAuthInterceptor(authCubit, dio: dio));
```

That is the whole integration.

## Installation

```yaml
dependencies:
  fabitus_cognito_auth: # ... (see its README)
  fabitus_cognito_auth_dio:
    git:
      url: https://github.com/fabitus-gmbh/fabitus-flutter.git
      path: packages/fabitus_cognito_auth_dio
      ref: <commit or tag> # the same for every fabitus package, see the repo README
```

```dart
import 'package:fabitus_cognito_auth_dio/fabitus_cognito_auth_dio.dart';
```

## What it does

| When | It |
| --- | --- |
| before a request to the API | asks for a session that does not expire in the next minute - refreshing first if needed - and sets `Authorization: Bearer <id token>` |
| the refresh fails, but the session lives on (offline) | sends the current token and lets the backend decide |
| nobody is signed in | sends the request without a token |
| the backend answers 401 | refreshes once and retries the request with the new token |
| another request refreshed meanwhile | retries with that token, without refreshing again |
| the refresh token is rejected | passes the 401 on; the `AuthCubit` is already unauthenticated, so the route guard sends the user to the login page |
| the retry fails too | passes the retry's error on |

Concurrent 401s share one refresh - the `AuthCubit` deduplicates it. The
interceptor is a plain `Interceptor`, not a `QueuedInterceptor`: queuing every
error behind a refresh that retries through the same Dio deadlocks as soon as
the retry fails.

## Which requests get the token

By default, those whose URL lies under their `baseUrl` - same scheme, host and
port, and a path at or below the base path. So a Dio that also uploads to
presigned S3 URLs keeps those free of an `Authorization` header, which S3 would
reject, and `https://api.fabit.us.example.com` is not mistaken for
`https://api.fabit.us`. A Retrofit client with its own `baseUrl` works the same
way, since Retrofit puts that into the request's `baseUrl`.

A Dio without a `baseUrl` authorizes nothing. Decide yourself with `authorize`:

```dart
CognitoAuthInterceptor(
  authCubit,
  dio: dio,
  authorize: (options) => options.uri.host == 'api.fabit.us',
);
```

A request that already carries the header is left alone.

## Id or access token

A Cognito authorizer without OAuth scopes validates the **id token**, the
default. Configure scopes on the authorizer and it wants the access token:

```dart
CognitoAuthInterceptor(authCubit, dio: dio, tokenType: AuthTokenType.access);
```

`headerName` and `headerValue` change the header, for an authorizer whose token
source is not `Authorization`, or one that wants the bare token:

```dart
CognitoAuthInterceptor(authCubit, dio: dio, headerValue: (token) => token);
```

## Retrying bodies

A retry sends the request again, so its body has to be sendable twice. JSON,
strings and bytes are; `FormData` is cloned. A body that is a `Stream` is not
and fails on retry - refresh before such an upload with
`await authCubit.validSession()`, and the first attempt goes out with a fresh
token.

## Wiring it up

```dart
getIt
  ..registerSingleton<AuthCubit>(auth)
  ..registerLazySingleton<Dio>(() {
    final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));
    dio.interceptors.add(CognitoAuthInterceptor(getIt<AuthCubit>(), dio: dio));
    return dio;
  });
```

The interceptor depends on `AuthTokenSource`, not on the cubit, so a test can
hand it a stub with three methods.

## Related

| Package | Role |
| --- | --- |
| [`fabitus_cognito_auth`](../fabitus_cognito_auth) | the Cognito client, the session and the `AuthCubit` |
| [`fabitus_crud_api_dio`](../fabitus_crud_api_dio) | maps the errors of the same Dio to `CrudException`s |

## License

[MIT](LICENSE) © Fabitus GmbH.
