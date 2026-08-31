# fabitus_problem_details

[RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) (formerly RFC 7807) problem
details for HTTP APIs: the machine readable error body a REST backend returns
when something goes wrong, and the field level violations that come with a
rejected payload.

```json
{
  "type": "https://fabit.us/problem/constraint-violation",
  "title": "Constraint Violation",
  "status": 422,
  "detail": "The todo could not be saved",
  "traceId": "8f1c2d3e",
  "violations": [{ "field": "title", "message": "must not be blank" }]
}
```

```dart
final problem = ProblemDetail.fromJson(body);

problem.message;                          // 'The todo could not be saved'
problem.violationFor('title')?.message;   // 'must not be blank'
problem.extensions['traceId'];            // '8f1c2d3e'
```

- **No HTTP client.** Hand it a decoded body, get a value. Works with `dio`,
  `http`, a generated client or a test fixture.
- **Tolerant.** Spring Boot, Zalando's `problem` library and hand rolled
  backends all disagree on spelling; the parser accepts the common variants.
- **Lossless.** Members the standard does not define are kept in `extensions`,
  so a `traceId` survives a round trip.

## Contents

- [Installation](#installation)
- [The model](#the-model)
- [What the parser tolerates](#what-the-parser-tolerates)
- [Guide 1: reading a problem from a Dio response](#guide-1-reading-a-problem-from-a-dio-response)
- [Guide 2: with fabitus_crud_api](#guide-2-with-fabitus_crud_api)
- [Guide 3: emitting a problem detail](#guide-3-emitting-a-problem-detail)
- [Design notes](#design-notes)

## Installation

```yaml
dependencies:
  fabitus_problem_details:
    git:
      url: https://github.com/fabitus-gmbh/fabitus-flutter.git
      path: packages/fabitus_problem_details
```

```dart
import 'package:fabitus_problem_details/fabitus_problem_details.dart';
```

Runtime dependencies are `collection` and `freezed_annotation`. You do **not**
need `build_runner` - the generated code ships with the package.

## The model

| Member | Meaning |
| --- | --- |
| `type` | URI identifying the problem *kind*, e.g. `https://fabit.us/problem/constraint-violation` |
| `title` | short summary of the type, the same for every occurrence |
| `status` | the HTTP status code the origin generated |
| `detail` | explanation specific to *this* occurrence |
| `instance` | URI identifying this occurrence |
| `violations` | field level errors, empty unless this is a validation failure |
| `extensions` | everything else the body carried |

`problem.message` is the one line to put in front of a user: `detail`, falling
back to `title`, then `type`, then `'Unknown problem'`.

`problem.violationFor('title')` finds a single field's error;
`problem.violations` is the whole list, and a `ConstraintViolation` prints as
`title: must not be blank`, so the list joins straight into a message.

Both types are `freezed` classes, so they have `copyWith` and value equality.

## What the parser tolerates

```dart
ProblemDetail.fromJson(body);   // body is a decoded JSON object
ProblemDetail.tryParse(body);   // returns null when body is not a JSON object
```

Use `tryParse` on a response body you did not produce - a gateway timeout page
is HTML, not a problem detail, and you want `null` rather than an exception.

| Field | Keys accepted |
| --- | --- |
| the violation list | `violations`, `errors` |
| a violation's field | `field`, `propertyPath`, `name` |
| a violation's message | `message`, `defaultMessage`, `reason` |

A `violations` member that is not a list is ignored rather than fatal: a partly
wrong error body should still yield the message.

## Guide 1: reading a problem from a Dio response

The package deliberately has no `dio` dependency. Reading the body is a
one-liner wherever you handle the error:

```dart
try {
  await dio.post('/todos', data: todo);
} on DioException catch (error) {
  final problem = ProblemDetail.tryParse(error.response?.data);
  showSnackBar(problem?.message ?? 'Something went wrong');
}
```

As an interceptor, so no call site has to think about it:

```dart
class ProblemDetailInterceptor extends Interceptor {
  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    final problem = ProblemDetail.tryParse(error.response?.data);
    if (problem == null) return handler.next(error);
    // Carry the parsed problem along, so later layers need not parse again.
    return handler.next(error.copyWith(error: problem));
  }
}
```

## Guide 2: with `fabitus_crud_api`

[`fabitus_crud_api`](../fabitus_crud_api) reports failures as a sealed
`CrudException` carrying a `message` and a list of `CrudViolation`s. It has no
opinion about the wire format - translating one into the other is exactly what a
`CrudErrorMapper` is for, and that is the seam where this package plugs in.

A problem detail gives you both halves at once: **the general message** and
**the field errors**.

```dart
import 'package:dio/dio.dart';
import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_problem_details/fabitus_problem_details.dart';

class DioCrudErrorMapper implements CrudErrorMapper {
  const DioCrudErrorMapper();

  @override
  CrudException map(Object error, StackTrace stackTrace) {
    if (error is! DioException) {
      return const DefaultCrudErrorMapper().map(error, stackTrace);
    }

    final response = error.response;
    if (response != null) {
      final problem = ProblemDetail.tryParse(response.data);
      return CrudException.fromStatusCode(
        response.statusCode ?? 0,
        // The general error message, straight from the backend.
        message: problem?.message,
        // The field errors, converted into the CRUD model.
        violations: problem.toCrudViolations(),
        cause: error,
      );
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        CrudTimeoutException(error.message ?? 'Timeout', cause: error),
      DioExceptionType.cancel =>
        CrudCancelledException('Request cancelled', cause: error),
      _ => CrudNetworkException(error.message ?? 'Network error', cause: error),
    };
  }
}

/// The whole bridge between the two packages.
extension ProblemDetailCrudViolations on ProblemDetail? {
  List<CrudViolation> toCrudViolations() => [
    for (final violation in this?.violations ?? const <ConstraintViolation>[])
      CrudViolation(field: violation.field, message: violation.message),
  ];
}
```

`CrudException.fromStatusCode` picks the right subtype from the status, so a 422
carrying violations arrives as a `CrudValidationException`. On the screen:

```dart
final result = await repository.save(todo);
if (result case CrudFailure(:final error)) {
  setState(() => _error = error);
}

// The general message.
Text(_error?.message ?? '');

// And the field errors, without anyone below this line knowing about RFC 9457.
TextFormField(
  decoration: InputDecoration(errorText: _error?.violationFor('title')?.message),
);
```

Keep the extension in one file in your app and every repository is covered.

## Guide 3: emitting a problem detail

`toJson` is symmetric with `fromJson` and spreads `extensions` back into the
root object, which is what the standard prescribes. Useful for a mock server, a
test fixture or a Dart backend:

```dart
const problem = ProblemDetail(
  type: 'https://fabit.us/problem/constraint-violation',
  title: 'Constraint Violation',
  status: 422,
  detail: 'The todo could not be saved',
  violations: [ConstraintViolation(field: 'title', message: 'must not be blank')],
  extensions: {'traceId': '8f1c2d3e'},
);

jsonEncode(problem.toJson());
```

Absent members are omitted rather than written as `null`.

## Design notes

**Why a separate package?** A problem detail only ever arrives over HTTP.
`fabitus_crud_api` deliberately knows nothing about the transport - not `dio`,
not `http` - and a wire error format is the same kind of knowledge. Keeping it
out means a gRPC or GraphQL backend can use that package with its own mapper,
and it means this model is usable on its own, by any client, CRUD or not.

**Why is `fromJson` hand written?** The parsing is tolerant of key spellings and
captures unknown members into `extensions`; `json_serializable` can express
neither. The types use `freezed` for equality and `copyWith` only, with
`@Freezed(fromJson: false, toJson: false)`.

**Why is `status` not authoritative?** It is what the *origin* claims, which can
differ from the status the client actually saw when a proxy rewrote it. Drive
your control flow from the real response status and use `status` for
diagnostics.

## License

[MIT](LICENSE) © Fabitus GmbH.
