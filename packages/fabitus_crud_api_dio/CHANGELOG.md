# Changelog

## 0.1.0

Initial release.

- `DioCrudErrorMapper`, the `CrudErrorMapper` every Dio based app previously had
  to copy out of the `fabitus_crud_api` README. Maps a response to the
  `CrudException` matching its status code, filling message and violations from
  the RFC 9457 body when there is one, and maps timeouts, cancellations and
  connection failures to their own exception types.
- `problemFrom` is overridable, for a backend with its own error format.
- `fallback` handles anything that is not a `DioException`.
- `ProblemDetailCrudViolations.toCrudViolations()`, the bridge from
  `fabitus_problem_details` to `fabitus_crud_api`.
