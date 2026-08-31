# fabitus_problem_details example

Parses an RFC 9457 body and reads a message, the field errors and a custom
extension member out of it.

```sh
dart run example/main.dart
```

The [package README](../README.md) shows how to wire this into a Dio
interceptor and into `fabitus_crud_api`'s error mapper.
