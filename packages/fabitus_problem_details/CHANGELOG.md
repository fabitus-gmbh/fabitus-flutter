# Changelog

## 0.1.0

Initial release. Extracted from `fabitus_crud_api`, where the model was part of
the CRUD error hierarchy - it belongs to the HTTP transport, which that package
deliberately knows nothing about.

- `ProblemDetail` and `ConstraintViolation` as `freezed` value types, so they
  carry `copyWith` and value equality.
- Tolerant parsing: violations are read from `violations` or `errors`, a field
  name from `field`, `propertyPath` or `name`, a message from `message`,
  `defaultMessage` or `reason`.
- Members the standard does not define are kept in `extensions` and survive a
  round trip through `toJson`.
- `ProblemDetail.tryParse` for a response body that may not be a problem detail
  at all.
