# Changelog

## 0.1.0

Initial release, generalised from the `TokenRefreshInterceptor` of the DMB
Slicer frontend.

- `CognitoAuthInterceptor` attaches the id or access token to requests under the
  `baseUrl`, refreshes it before it expires, and refreshes once more and
  retries on a 401.
- The request choice compares scheme, host, port and path instead of a string
  prefix, and needs no separate API URL.
- A plain `Interceptor` instead of a `QueuedInterceptor`, which could deadlock
  when a retry failed; concurrent refreshes are deduplicated by the token
  source instead.
- `FormData` is cloned for the retry.
