# fabitus_crud_api_dio

The [`CrudErrorMapper`](../fabitus_crud_api#the-dio-error-mapper) for a Dio based
app, so you do not have to write it.

```dart
final repository = RemotePagingCrudRepository<Todo, String>(
  TodoApi(dio),
  errorMapper: const DioCrudErrorMapper(),
);
```

That is the whole integration. `fabitus_crud_api` carries no transport and no
opinion about a backend's error format, which leaves exactly one thing for every
Dio project to write - and this package is that thing.

## Installation

```yaml
dependencies:
  fabitus_crud_api: # ... (see its README)
  fabitus_crud_api_dio:
    git:
      url: https://github.com/fabitus-gmbh/fabitus-flutter.git
      path: packages/fabitus_crud_api_dio
```

```dart
import 'package:fabitus_crud_api_dio/fabitus_crud_api_dio.dart';
```

It pulls in `dio`, `fabitus_crud_api` and `fabitus_problem_details`. Depend on
it only where you use Dio; a project on `http` or a generated client keeps
`fabitus_crud_api` alone and writes its own mapper.

## What it maps

| Dio throws | You get |
| --- | --- |
| a response, 400 or 422 | `CrudValidationException`, with `violations` |
| a response, 401 | `CrudUnauthorizedException` |
| a response, 403 | `CrudForbiddenException` |
| a response, 404 | `CrudNotFoundException` |
| a response, 409 | `CrudConflictException` |
| a response, 5xx | `CrudServerException` |
| a response, anything else | `CrudUnknownException` |
| `connectionTimeout`, `sendTimeout`, `receiveTimeout`, `transformTimeout` | `CrudTimeoutException` |
| `cancel` | `CrudCancelledException` |
| `connectionError`, `badCertificate`, anything else without a response | `CrudNetworkException` |
| not a `DioException` at all | whatever [`fallback`](#non-dio-errors) returns |

The original `DioException` is always kept as `cause`, so nothing is lost.

When the response body is an
[RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem detail - which Spring
Boot returns by default - its message and field errors come along:

```dart
// 422 with {"detail": "The todo could not be saved",
//           "violations": [{"field": "title", "message": "must not be blank"}]}

final result = await repository.save(todo);
if (result case CrudFailure(:final error)) {
  error.message;                            // 'The todo could not be saved'
  error.violationFor('title')?.message;     // 'must not be blank'
}
```

A body that is *not* a problem detail - an HTML error page, an empty body - is
not a problem: you still get the exception matching the status code, with
`'HTTP 502'` as the message.

## Wiring it up

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.fabit.us'));

getIt
  ..registerLazySingleton<Dio>(() => dio)
  ..registerLazySingleton<TodoApi>(() => TodoApi(getIt()))
  ..registerLazySingleton<PagingCrudRepository<Todo, String>>(
    () => RemotePagingCrudRepository(
      getIt<TodoApi>(),
      errorMapper: const DioCrudErrorMapper(),
    ),
  );
```

The mapper is `const` and stateless, so one instance serves every repository.

## Non-Dio errors

A repository can be wrapped around more than the HTTP client - a codec, a cache -
and those failures need mapping too. Anything that is not a `DioException` goes
to `fallback`, which defaults to `DefaultCrudErrorMapper`:

```dart
const DioCrudErrorMapper(fallback: MyOwnMapper());
```

## A backend with its own error format

Override `problemFrom` and the status mapping keeps working:

```dart
class LegacyDioCrudErrorMapper extends DioCrudErrorMapper {
  const LegacyDioCrudErrorMapper();

  @override
  ProblemDetail? problemFrom(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map<String, dynamic>) return null;
    return ProblemDetail(
      detail: body['errorMessage'] as String?,
      violations: [
        for (final field in (body['invalidFields'] as List? ?? const []))
          ConstraintViolation(field: field as String, message: 'is invalid'),
      ],
    );
  }
}
```

Returning `null` means "no message and no violations, map by status code alone".

## The bridge, on its own

`toCrudViolations()` converts the violations of a problem detail into
`CrudViolation`s. It has nothing to do with Dio and is exported here only because
this is the package that already depends on both sides - useful if you write a
mapper for another client:

```dart
final problem = ProblemDetail.tryParse(responseBody);

CrudException.fromStatusCode(
  statusCode,
  message: problem?.message,
  violations: problem.toCrudViolations(),
);
```

## Related

| Package | Role |
| --- | --- |
| [`fabitus_crud_api`](../fabitus_crud_api) | the repository contracts and the `CrudException` hierarchy |
| [`fabitus_problem_details`](../fabitus_problem_details) | the RFC 9457 model, on its own |

## License

[MIT](LICENSE) © Fabitus GmbH.
