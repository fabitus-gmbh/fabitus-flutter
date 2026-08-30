# fabitus_crud_api

Spring Data style CRUD abstractions for Dart and Flutter: repository interfaces,
pagination, a typed error model, and three interchangeable implementations
(in memory, key-value backed, remote).

Write a screen once against `CrudRepository<Todo, String>` and decide later
whether it is served from a fake, from local storage or from your backend.

- **No `build_runner` for consumers.** The value types are `freezed` classes, so
  you get `copyWith`, value equality and exhaustive `switch` for free - and the
  generated code is committed, so depending on this package pulls in no build
  step of your own.
- **No transport dependency.** No `dio`, no `http`, no Flutter. It runs on the
  VM, in the browser and inside Flutter alike.
- **Errors are values.** Repositories return `CrudResult`, they never throw.

## Contents

- [Installation](#installation)
- [Concepts](#concepts)
- [Quick start](#quick-start)
- [Guide 1: an in-memory repository](#guide-1-an-in-memory-repository)
- [Guide 2: local storage](#guide-2-local-storage)
- [Guide 3: a remote repository with retrofit and dio](#guide-3-a-remote-repository-with-retrofit-and-dio)
- [Guide 4: pagination](#guide-4-pagination)
- [Guide 5: error handling and form validation](#guide-5-error-handling-and-form-validation)
- [Guide 6: services, events and dependency injection](#guide-6-services-events-and-dependency-injection)
- [Guide 7: adding your own queries](#guide-7-adding-your-own-queries)
- [Guide 8: testing](#guide-8-testing)
- [API overview](#api-overview)
- [Design notes](#design-notes)

## Installation

```yaml
dependencies:
  fabitus_crud_api:
    git:
      url: https://github.com/fabitus-gmbh/fabitus-flutter.git
      path: packages/fabitus_crud_api
```

```dart
import 'package:fabitus_crud_api/fabitus_crud_api.dart';
```

Runtime dependencies are `collection`, `freezed_annotation`, `logging`, `meta`
and `uuid`. You do **not** need `build_runner` or `freezed` yourself - the
generated code ships with the package.

## Concepts

If you know Spring Data, you know the vocabulary:

| Spring Data | This package | Notes |
| --- | --- | --- |
| domain object | `CrudEntity<ID>` | `ID? get id` plus `toJson()` |
| `CrudRepository<T, ID>` | `CrudRepository<T, ID>` | `findById`, `findAll`, `save`, `deleteById`, `count`, `existsById` |
| `PagingAndSortingRepository` | `PagingCrudRepository<T, ID>` | adds `findPage` |
| `Pageable` | `PageRequest` | `OffsetPageRequest` or `CursorPageRequest` |
| `Page<T>` | `Page<T>` | `OffsetPage<T>` or `CursorPage<T>` |
| `Sort` | `Sort` | `Sort.by('createdAt', SortDirection.desc)` |
| `ProblemDetail` | `ProblemDetail` | RFC 9457, incl. constraint violations |
| exceptions | `CrudResult<T>` | `CrudSuccess` or `CrudFailure`, never thrown |

One layer sits below the repository: `CrudApi<T, ID>` is the raw HTTP client
contract that a retrofit client implements. `RemoteCrudRepository` wraps it and
turns thrown exceptions into results.

```
CrudApi (throws)  ->  RemoteCrudRepository  ->  CrudService (adds events)
                       CrudRepository (returns CrudResult)
                      InMemoryCrudRepository
                      KeyValueCrudRepository
```

## Quick start

An entity implements `CrudEntity<ID>`: an `id` and a `toJson()`. A hand written
class works, and so does a `freezed` class that adds
`implements CrudEntity<String>` - this package does not care which.

```dart
class Todo implements CrudEntity<String> {
  const Todo({this.id, required this.title, this.done = false});

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as String?,
    title: json['title'] as String,
    done: json['done'] as bool? ?? false,
  );

  @override
  final String? id;
  final String title;
  final bool done;

  Todo copyWith({String? id, String? title, bool? done}) =>
      Todo(id: id ?? this.id, title: title ?? this.title, done: done ?? this.done);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
}
```

Every repository call returns a `CrudResult`, which is `sealed`, so the compiler
makes sure you handle both branches:

```dart
switch (await repository.findById('42')) {
  case CrudSuccess(:final data):
    emit(TodoLoaded(data));
  case CrudFailure(:final error):
    emit(TodoError(error.message));
}
```

Or, when you only care about one branch:

```dart
final todo = (await repository.findById('42')).dataOrNull;
final todos = (await repository.findAll()).getOrElse((_) => const []);
final page = (await repository.findPage(request)).getOrThrow(); // rethrows
```

A runnable tour is in [`example/main.dart`](example/main.dart):

```sh
dart run example/main.dart
```

## Guide 1: an in-memory repository

The fastest way to build a screen before the backend exists, and the fake you
want in tests. `withId` is the only required argument: it tells the repository
how to put a generated id onto an entity.

```dart
final repository = InMemoryCrudRepository<Todo, String>(
  withId: (todo, id) => todo.copyWith(id: id),
  initial: const [Todo(id: '1', title: 'Write the docs')],
);

final created = await repository.create(const Todo(title: 'Ship it'));
// created.dataOrNull!.id is a generated 16 character id
```

Ids default to `newUuid()`, a random version 4 UUID. Version 4 is the right
default on a client: it needs no coordination, so two devices creating entities
offline will not collide. For a non-`String` id, or for ids the backend hands
out, pass your own generator:

```dart
InMemoryCrudRepository<Invoice, int>(
  withId: (invoice, id) => invoice.copyWith(id: id),
  generateId: () => ++_lastInvoiceNumber,
);
```

Sorting reads properties from `toJson()`, so `Sort.by('title')` works without
configuration. For nested or computed properties, pass a `propertyAccessor`:

```dart
InMemoryCrudRepository<Todo, String>(
  withId: (todo, id) => todo.copyWith(id: id),
  propertyAccessor: (todo, property) => switch (property) {
    'authorName' => todo.author.name,
    _ => todo.toJson()[property],
  },
);
```

## Guide 2: local storage

`KeyValueCrudRepository` persists the whole collection as one JSON array under a
single key. Point it at whatever storage the platform offers by implementing
`KeyValueStore` - three methods.

```dart
final repository = KeyValueCrudRepository<Todo, String>(
  store: SharedPreferencesKeyValueStore(await SharedPreferences.getInstance()),
  storageKey: 'todos',
  codec: EntityCodec.forEntity(Todo.fromJson),
  withId: (todo, id) => todo.copyWith(id: id),
);
```

### shared_preferences

```dart
class SharedPreferencesKeyValueStore implements KeyValueStore {
  const SharedPreferencesKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
```

### Browser localStorage

```dart
import 'package:web/web.dart' show window;

class LocalStorageKeyValueStore implements KeyValueStore {
  const LocalStorageKeyValueStore();

  @override
  Future<String?> read(String key) async => window.localStorage.getItem(key);

  @override
  Future<void> write(String key, String value) async =>
      window.localStorage.setItem(key, value);

  @override
  Future<void> remove(String key) async => window.localStorage.removeItem(key);
}
```

### flutter_secure_storage

```dart
class SecureKeyValueStore implements KeyValueStore {
  const SecureKeyValueStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> remove(String key) => _storage.delete(key: key);
}
```

`InMemoryKeyValueStore` ships with the package for tests.

> **When not to use it.** Every write serialises the full collection. That is
> the right trade for the hundreds of entities a device holds, and the wrong one
> for tens of thousands - reach for a real database there.

## Guide 3: a remote repository with retrofit and dio

Let your retrofit client extend `CrudApi` or `PagingCrudApi`. The method
signatures are inherited, so all you add are the annotations:

```dart
@RestApi()
abstract class TodoApi extends PagingCrudApi<Todo, String> {
  factory TodoApi(Dio dio, {String baseUrl}) = _TodoApi;

  @GET('/todos')
  @override
  // Nullable, so retrofit strips null query parameters.
  Future<Page<Todo>> findPage(@Queries() PageRequest? pageRequest);

  @GET('/todos/{id}')
  @override
  Future<Todo> findById(@Path('id') String id);

  @POST('/todos')
  @override
  Future<Todo> create(@Body() Todo entity);

  @PUT('/todos/{id}')
  @override
  Future<Todo> update(@Path('id') String id, @Body() Todo entity);

  @DELETE('/todos/{id}')
  @override
  Future<void> deleteById(@Path('id') String id);
}
```

`PageRequest.toJson()` emits `page`, `size` and `sort`, and `Page.fromJson`
reads the Spring Data response shape, so both directions work out of the box.

Wrap the client in a repository:

```dart
final repository = RemotePagingCrudRepository<Todo, String>(
  TodoApi(dio),
  errorMapper: const DioCrudErrorMapper(),
);
```

### The Dio error mapper

The package has no `dio` dependency, so this ~25 line class lives in your app.
Write it once and reuse it for every repository:

```dart
class DioCrudErrorMapper implements CrudErrorMapper {
  const DioCrudErrorMapper();

  @override
  CrudException map(Object error, StackTrace stackTrace) {
    if (error is! DioException) {
      return const DefaultCrudErrorMapper().map(error, stackTrace);
    }
    final response = error.response;
    if (response != null) {
      return CrudException.fromStatusCode(
        response.statusCode ?? 0,
        problem: ProblemDetail.tryParse(response.data),
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
```

`CrudException.fromStatusCode` turns 404 into `CrudNotFoundException`, 422 into
`CrudValidationException`, 5xx into `CrudServerException`, and so on.

> `RemoteCrudRepository.findAll()` and `count()` fail with
> `CrudUnsupportedException`, because a plain `CrudApi` has no collection
> endpoint. `RemotePagingCrudRepository` implements both by walking the pages,
> and `count()` short-circuits when the backend reports `totalElements`.

## Guide 4: pagination

Two flavours, because backends use both. Offset paging matches Spring's
`Pageable`:

```dart
var request = const OffsetPageRequest(page: 0, size: 20);
final page = (await repository.findPage(request)).getOrThrow() as OffsetPage<Todo>;

page.content;        // the entities
page.totalElements;  // null when the backend does not report it
page.totalPages;
page.hasNext;
page.isLast;
```

Keyset (cursor) paging, for feeds:

```dart
const request = CursorPageRequest(size: 20);
final page = (await repository.findPage(request)).getOrThrow();
```

Every request and page is a `freezed` class, so `copyWith` is available:
`request.copyWith(page: 2)`, `request.copyWith(sort: Sort.by('title'))`,
`request.copyWith(cursor: null)` to go back to the first page.

`nextPageRequest` carries size and sort over and returns `null` on the last
page, which is all an infinite scroll needs:

```dart
Future<void> loadMore() async {
  final next = _page?.nextPageRequest(_request);
  if (next == null) return; // no further page
  _request = next;
  final result = await repository.findPage(next);
  if (result case CrudSuccess(:final data)) {
    setState(() {
      _page = data;
      _todos.addAll(data.content);
    });
  }
}
```

Sorting travels with the request and is emitted in Spring's format
(`sort=createdAt,DESC`):

```dart
OffsetPageRequest(
  size: 20,
  sort: Sort.by('createdAt', SortDirection.desc).and(Sort.by('title')),
);
```

The local repositories apply the same sort in memory, so a fake behaves like the
backend. `null` values always sort last, in both directions.

## Guide 5: error handling and form validation

`CrudException` is sealed, so a `switch` covering it is checked for
exhaustiveness:

```dart
String messageFor(CrudException error) => switch (error) {
  CrudValidationException() => 'Please check the highlighted fields',
  CrudNotFoundException() => 'This entry no longer exists',
  CrudUnauthorizedException() => 'Please sign in again',
  CrudForbiddenException() => 'You are not allowed to do that',
  CrudConflictException() => 'Someone else changed this entry',
  CrudNetworkException() || CrudTimeoutException() => 'No connection',
  CrudServerException() => 'The server had a problem, try again later',
  _ => error.message,
};
```

Field level errors from an RFC 9457 body are on every exception:

```dart
final result = await repository.save(todo);
if (result case CrudFailure(:final error)) {
  setState(() => _violations = error.violations);
}

// In the form field:
TextFormField(
  decoration: InputDecoration(
    errorText: _violations
        .where((violation) => violation.field == 'title')
        .map((violation) => violation.message)
        .firstOrNull,
  ),
);
```

Backends disagree on the wire format, so `ProblemDetail` accepts `violations`
and `errors`, and reads a field name from `field`, `propertyPath` or `name`.
Anything it does not know is kept in `extensions`, so a `traceId` survives.

## Guide 6: services, events and dependency injection

`CrudService` wraps any repository and announces every successful write on a
broadcast stream. That is how a list refreshes itself when a detail screen
saves, without the two knowing about each other.

```dart
final service = PagingCrudService<Todo, String>(repository);

service.events.listen((event) {
  switch (event) {
    case CrudEntityCreated(:final entity):
    case CrudEntityUpdated(:final entity):
      _upsert(entity);
    case CrudEntityDeleted(:final id):
      _removeWhere((todo) => todo.id == id);
  }
});
```

### Forwarding the events somewhere else

The stream works when the listener lives near the service. When the events
should reach something that already exists - an application wide event bus,
analytics, a cache - hand it in as a `CrudEventListener` at construction:

```dart
final todos = CrudService<Todo, String>(
  repository,
  listeners: [
    CrudEventListener.fromCallback(eventBus.fire),
    AnalyticsCrudEventListener(analytics),
  ],
);
```

Both routes are always active: the listeners fire *and* the stream emits.

#### With the `event_bus` package

`EventBus.fire` takes an `Object`, and a `void Function(Object)` is a valid
`void Function(CrudEvent<Todo>)`, so the tear-off fits as is - one bus serves
the services of every entity type:

```dart
final eventBus = EventBus();

final todos = CrudService<Todo, String>(
  todoRepository,
  listeners: [CrudEventListener.fromCallback(eventBus.fire)],
);
final invoices = CrudService<Invoice, String>(
  invoiceRepository,
  listeners: [CrudEventListener.fromCallback(eventBus.fire)],
);
```

Subscribers then filter by event type, which is what an event bus is good at:

```dart
eventBus.on<CrudEntityDeleted<Todo>>().listen((event) => _remove(event.id));
eventBus.on<CrudEvent<Todo>>().listen(_refresh);   // any change to a Todo
```

#### A listener with dependencies

Implement the interface when the listener needs state or collaborators:

```dart
class AnalyticsCrudEventListener<T> implements CrudEventListener<T> {
  const AnalyticsCrudEventListener(this._analytics);

  final Analytics _analytics;

  @override
  void onCrudEvent(CrudEvent<T> event) => _analytics.track(switch (event) {
    CrudEntityCreated() => '${T}_created',
    CrudEntityUpdated() => '${T}_updated',
    CrudEntityDeleted() => '${T}_deleted',
  });
}
```

Listeners are called synchronously, in the order given, after the write has
already succeeded. **A listener that throws is logged and skipped**: it can
never turn a successful save into a failure, and never stops the listeners
behind it. The list is fixed for the lifetime of the service - to attach and
detach at runtime, listen to `events` and cancel the subscription.

> **One inference wrinkle.** When you pass listeners, give the call a type
> context: write `CrudService<Todo, String>(...)`, or assign to a variable or
> return type that names the arguments. Bare
> `final s = CrudService(repository, listeners: [...]);` does not compile,
> because `CrudService`'s type parameters are dependent
> (`T extends CrudEntity<ID>`) and inference then cannot reach the listeners.
> The `get_it` registration below has that context and needs nothing extra.

### With `get_it`

```dart
getIt
  ..registerLazySingleton<Dio>(buildDio)
  ..registerLazySingleton<TodoApi>(() => TodoApi(getIt()))
  ..registerLazySingleton<PagingCrudRepository<Todo, String>>(
    () => RemotePagingCrudRepository(getIt<TodoApi>(),
        errorMapper: const DioCrudErrorMapper()),
  )
  ..registerLazySingleton<EventBus>(EventBus.new)
  ..registerLazySingleton<PagingCrudService<Todo, String>>(
    () => PagingCrudService(
      getIt(),
      listeners: [CrudEventListener.fromCallback(getIt<EventBus>().fire)],
    ),
    dispose: (service) => service.dispose(),
  );
```

Screens depend on `PagingCrudService<Todo, String>`; swapping the registration
for an `InMemoryCrudRepository` gives you an offline demo build with no other
change.

Failed operations emit nothing - the caller still gets the `CrudFailure`.

## Guide 7: adding your own queries

Filters and search are application specific, so extend the repository and use
`guardCrud` to get the same error handling for your own calls:

```dart
class TodoRepository extends RemotePagingCrudRepository<Todo, String> {
  TodoRepository(this._api, {super.errorMapper}) : super(_api);

  final TodoApi _api;

  Future<CrudResult<Page<Todo>>> search(
    TodoFilter filter,
    PageRequest pageRequest,
  ) => guardCrud(
    () => _api.search(pageRequest, filter),
    errorMapper: errorMapper,
  );
}
```

Inside a `BaseCrudRepository` subclass, the protected `guard` helper already
carries the mapper:

```dart
Future<CrudResult<List<Todo>>> findOverdue(DateTime now) =>
    guard(() => _api.findOverdue(now));
```

## Guide 8: testing

**Use `InMemoryCrudRepository` as the fake.** It implements the full contract,
including paging and sorting, so a bloc test needs no mocking framework:

```dart
test('loads the first page', () async {
  final repository = InMemoryCrudRepository<Todo, String>(
    withId: (todo, id) => todo.copyWith(id: id),
    initial: const [Todo(id: '1', title: 'One')],
  );

  final bloc = TodoListBloc(repository)..add(const TodoListStarted());

  await expectLater(bloc.stream, emits(isA<TodoListLoaded>()));
});
```

**Test your own repository against the contract.** This package ships its
implementations through one shared suite
([`test/repository/crud_repository_contract.dart`](test/repository/crud_repository_contract.dart));
copy the pattern for repositories you write yourself, so local and remote stay
interchangeable:

```dart
void main() {
  runCrudRepositoryContract(
    'MyRepository',
    () => MyRepository(FakeApi()),
  );
}
```

**Assert on results, not on exceptions.**

```dart
expect((await repository.findById('nope')).errorOrNull, isA<CrudNotFoundException>());
expect((await repository.create(todo)).isSuccess, isTrue);
```

Run the suite:

```sh
dart test
```

## API overview

| Type | Purpose |
| --- | --- |
| `CrudEntity<ID>` | what an entity must provide: `id` and `toJson()` |
| `IdGenerator`, `newUuid` | ids for locally created entities |
| `EntityCodec<T>` | `fromJson`/`toJson` pair for local stores |
| `CrudResult<T>` | `CrudSuccess<T>` or `CrudFailure<T>` |
| `CrudException` | sealed error hierarchy, `CrudException.fromStatusCode` |
| `ProblemDetail`, `ConstraintViolation` | RFC 9457 error bodies |
| `CrudErrorMapper`, `DefaultCrudErrorMapper`, `guardCrud` | turning throws into results |
| `Sort`, `SortOrder`, `SortDirection` | ordering |
| `PageRequest` → `OffsetPageRequest`, `CursorPageRequest` | what to read |
| `Page<T>` → `OffsetPage<T>`, `CursorPage<T>` | what came back |
| `ReadCrudRepository`, `CrudRepository`, `PagingCrudRepository` | the contracts |
| `BaseCrudRepository` | base class for your own implementations |
| `InMemoryCrudRepository` | map backed, for tests and prototypes |
| `KeyValueStore`, `InMemoryKeyValueStore` | the local storage seam |
| `sortEntities`, `pageOf`, `jsonPropertyAccessor` | in-memory sorting and slicing, for your own local repositories |
| `KeyValueCrudRepository` | JSON document in a `KeyValueStore` |
| `CrudApi`, `PagingCrudApi` | the retrofit client contract |
| `RemoteCrudRepository`, `RemotePagingCrudRepository` | backend backed |
| `CrudService`, `PagingCrudService` | repository plus event stream and listeners |
| `CrudEventListener` | the seam for pushing events into an event bus, analytics or a cache |
| `CrudEvent` → `CrudEntityCreated`, `CrudEntityUpdated`, `CrudEntityDeleted` | what happened |

## Design notes

**Why results instead of exceptions?** A repository call fails for expected
reasons - offline, 404, a rejected form. Making that part of the return type
means a caller cannot forget it, and `sealed` turns "did you handle the error?"
into a compile time question.

**Why is `fromJson` hand written?** The parsing is deliberately tolerant:
`ProblemDetail` reads violations from `violations` or `errors`, `Page` accepts
`content`, `items` or `data` and picks its variant from the keys that are
present. `json_serializable` cannot express that, so these types use freezed for
equality and `copyWith` only, with `@Freezed(fromJson: false, toJson: false)`.

**Why no `dio` dependency?** The transport is the one thing every project picks
differently. Keeping it out means this package works with `dio`, `http`, a
generated OpenAPI client or a websocket, and it keeps the dependency
footprint at `collection`, `logging` and `meta`.

**Why freezed, and why is the generated code committed?** The value types -
`Sort`, `PageRequest`, `Page`, `ProblemDetail`, `CrudEvent` - are `freezed`
classes, which is where `copyWith` and value equality come from. Committing the
`.freezed.dart` files means a consumer needs no build step: the package is used
through a git dependency, and pub serves whatever is in the repository. CI
regenerates on every push and fails if the committed output has drifted.

`CrudResult` and `CrudException` are deliberately hand written. `copyWith` on an
exception is meaningless, and freezed's `==` would compare the `StackTrace` of a
`CrudFailure`, so two logically equal failures would not be equal.

**Why two type parameters?** `CrudRepository<Todo, String>` is more to type than
`CrudRepository<Todo>`, but it makes `findById` and `deleteById` type safe and
matches Spring's `CrudRepository<T, ID>`.

**Logging.** Every failure, and every exception a `CrudEventListener` throws, is
logged through `package:logging` before it is handled. The logger is exported as
`crudLogger`, so there is no name to get wrong:

```dart
crudLogger.onRecord.listen(reportToCrashlytics);
```

## License

[MIT](LICENSE) © Fabitus GmbH.
