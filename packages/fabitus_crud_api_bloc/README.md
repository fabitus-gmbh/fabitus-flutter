# fabitus_crud_api_bloc

Cubits and widgets for driving [`fabitus_crud_api`](../fabitus_crud_api)
repositories from Flutter. Three shapes, three cubits:

| Cubit | For a screen that |
| --- | --- |
| `LoadCubit<T>` | shows one thing - an entity, or a whole list |
| `PaginationCubit<T, F>` | walks a paged collection, as a table or an endless scroll |
| `EntityCubit<T, ID>` | reads, edits, saves and deletes one entity |

```dart
BlocProvider(
  create: (_) => LoadCubit<List<Todo>>(repository.findAll, loadOnCreate: true),
  child: LoadBuilder<List<Todo>>(
    builder: (context, todos, {bool refreshing = false}) => TodoList(todos: todos),
  ),
);
```

That is a screen with a spinner, an error view with a retry button, and a refresh
that does not blink - in seven lines.

## Contents

- [Installation](#installation)
- [Why cubits and not blocs](#why-cubits-and-not-blocs)
- [Guide 1: showing one thing](#guide-1-showing-one-thing)
- [Guide 2: paging through a collection](#guide-2-paging-through-a-collection)
- [Guide 3: an edit form](#guide-3-an-edit-form)
- [Guide 4: errors and field validation](#guide-4-errors-and-field-validation)
- [Guide 5: keeping a list in sync with writes](#guide-5-keeping-a-list-in-sync-with-writes)
- [Guide 6: testing](#guide-6-testing)
- [Design notes](#design-notes)

## Installation

```yaml
dependencies:
  fabitus_crud_api_bloc:
    git:
      url: https://github.com/fabitus-gmbh/fabitus-flutter.git
      path: packages/fabitus_crud_api_bloc
```

```dart
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
```

It pulls in `fabitus_crud_api` and `flutter_bloc`. It does **not** pull in
`dio`: the cubits see a `CrudResult` and a typed `CrudException`, whoever
produced them. Use it alongside
[`fabitus_crud_api_dio`](../fabitus_crud_api_dio) - that package fills in the
error mapper, and nothing here needs to know.

## Why cubits and not blocs

Because in this layer the events were pure indirection. The original of
`EntityCubit` was a `Bloc` with seven event classes whose single handler did
nothing but `event.map(...)` onto seven methods. `cubit.save()` says what
`bloc.add(const UpdateEntity())` said, and costs an event class, a `freezed`
part file and a dispatch table less.

A `Bloc` earns its keep when **events need transforming** - and that is a real
thing, not a hypothetical:

| You need | Bloc gives you | Here |
| --- | --- | --- |
| a search field that waits for typing to stop | `debounce` transformer | `debounce` your `TextField`, then call `updateFilter` |
| requests that must not interleave | `sequential()` transformer | each cubit drops a response that a newer call has overtaken |
| an audit trail of what the user asked for | events are values you can log | `BlocObserver` still sees every state |
| one screen reacting to another's events | one bloc listening to another | `CrudService.events` from `fabitus_crud_api` |

So: **reach for a `Bloc` when a transformer is the point.** For a search field
with `debounce` over a stream of keystrokes, that is genuinely the better tool -
and it composes fine, because a `Bloc` can drive these cubits.

What the cubits do instead of `sequential()` is drop stale responses: every call
takes a ticket, and a response whose ticket has been superseded is discarded. For
loading that is what you want - the last request wins - and it needs no queue.

## Guide 1: showing one thing

One cubit covers a single value and a list alike, so there is no list variant to
choose:

```dart
LoadCubit<Todo>(() => repository.findById(id), loadOnCreate: true);
LoadCubit<List<Todo>>(repository.findAll, loadOnCreate: true);
LoadCubit<Page<Todo>>(() => repository.findPage(request));
```

`LoadState<T>` is sealed, so a `switch` over it is exhaustive - which is how the
"success, but the data was null" hole of a status-plus-nullable-data state is
closed:

```dart
switch (state) {
  case LoadInitial() || LoadInProgress(previous: null):
    return const CircularProgressIndicator();
  case LoadInProgress(:final previous?):
    return TodoList(todos: previous, refreshing: true);
  case LoadSuccess(:final data):
    return TodoList(todos: data);
  case LoadFailure(:final error):
    return Text(error.message);
}
```

`LoadBuilder` writes that for you, with a spinner and a `CrudErrorView` as
defaults:

```dart
LoadBuilder<List<Todo>>(
  builder: (context, todos, {bool refreshing = false}) => Column(
    children: [
      if (refreshing) const LinearProgressIndicator(),
      Expanded(child: TodoList(todos: todos)),
    ],
  ),
  onLoading: (context) => const MyBrandedSpinner(),
  onError: (context, error, retry) => MyErrorView(error, onRetry: retry),
);
```

### Reloading without blinking

```dart
cubit.load();     // clears the screen, shows the spinner
cubit.refresh();  // keeps what is on screen, marks it refreshing
```

`refresh` is what a pull-to-refresh, a poll, or a reload after an inline change
wants: the content stays, `refreshing` goes `true`, and a *failed* refresh keeps
the stale content beside the error instead of throwing it away. The first load
has nothing to keep, so it shows the spinner either way.

## Guide 2: paging through a collection

```dart
final cubit = PaginationCubit<Todo, TodoFilter>(
  loadPage: (request, filter) => repository.search(filter, request),
  initialRequest: OffsetPageRequest(size: 20, sort: Sort.by('title')),
  initialFilter: const TodoFilter(),
  loadOnCreate: true,
);
```

With nothing to filter by, use `void`:

```dart
PaginationCubit<Todo, void>(
  loadPage: (request, _) => repository.findPage(request),
  initialRequest: OffsetPageRequest(size: 20),
  initialFilter: null,
);
```

The same cubit serves both list shapes:

```dart
state.items;      // the page the user is on   -> a table
state.allItems;   // everything read so far    -> an endless scroll
```

| Call | Does |
| --- | --- |
| `nextPage()` | moves on, reading the page only if it is not held yet |
| `previousPage()` | moves back, from memory |
| `goToPage(i)` | moves to a page already held |
| `jumpToPage(n)` | reads offset page `n` directly, for a page-number footer |
| `refresh()` | rereads the first page, keeping filter, size and sort |
| `updateFilter(f)` | applies a filter and starts over at page one |
| `updateRequest(r)` | applies a new page size or sort and starts over |

**Cursor pagination works, and going back needs no cursor.** Pages already read
are kept, so `previousPage` serves them from memory - a cursor only ever moves
forward. `jumpToPage` is the one thing a cursor collection cannot do, and it says
so with a `CrudUnsupportedException` rather than pretending.

A table footer:

```dart
Row(
  children: [
    IconButton(
      icon: const Icon(Icons.chevron_left),
      onPressed: state.hasPrevious ? cubit.previousPage : null,
    ),
    Text('${state.index + 1}'),
    IconButton(
      icon: const Icon(Icons.chevron_right),
      onPressed: state.hasNext ? cubit.nextPage : null,
    ),
  ],
);
```

A search field, where a `debounce` belongs on the input rather than in the cubit:

```dart
TextField(
  onChanged: (query) => _debouncer.run(
    () => cubit.updateFilter(state.filter.copyWith(query: query)),
  ),
);
```

## Guide 3: an edit form

`EntityCubit` keeps two copies: the entity as the store has it, and the draft as
the form has it. That is what answers `isDirty`, what lets `reset()` undo without
a round trip, and what keeps the form filled after a failed save.

```dart
// An edit form.
final cubit = EntityCubit<Todo, String>(repository)..load(id);

// A create form: start on a blank draft.
final cubit = EntityCubit<Todo, String>(repository, draft: const Todo(title: ''));
```

```dart
TextFormField(
  initialValue: state.draft?.title,
  onChanged: (value) => cubit.edit((todo) => todo.copyWith(title: value)),
);

FilledButton(
  onPressed: state.status.isBusy || !state.isDirty ? null : cubit.save,
  child: const Text('Save'),
);
```

`save()` creates when the draft has no id and updates when it has one - it goes
through `CrudRepository.save`, so the form does not care which. `select(entity)`
takes an entity the list already has, without a read.

Closing the screen when the write went through:

```dart
BlocListener<EntityCubit<Todo, String>, EntityState<Todo>>(
  listener: (context, state) {
    if (state.status.isSuccess &&
        (state.isDeleted ||
            (state.action == EntityAction.save && !state.isDirty))) {
      Navigator.of(context).pop();
    }
  },
  child: ...,
);
```

## Guide 4: errors and field validation

Every state carries a typed `CrudException`, so a screen can say something useful
rather than "an error occurred":

```dart
String messageFor(CrudException error) => switch (error) {
  CrudNetworkException() || CrudTimeoutException() => 'No connection',
  CrudConflictException() => 'Someone else changed this',
  CrudForbiddenException() => 'You are not allowed to do that',
  _ => error.message,
};
```

Field errors reach the field that caused them:

```dart
TextFormField(
  decoration: InputDecoration(
    errorText: state.violationFor('title')?.message,
  ),
);
```

`edit` clears the error, so a violation disappears as soon as the user touches
the field it is about.

Where those violations come from is the mapper's business, not the cubit's: with
`fabitus_crud_api_dio` an RFC 9457 body fills them in, and nothing in this layer
changes if the backend speaks something else.

`CrudErrorView` is the default failure rendering - plain, using the ambient
theme, listing the field errors because "check the highlighted fields" is useless
on a screen with no highlighting. Use it, wrap it, or replace it.

## Guide 5: keeping a list in sync with writes

`fabitus_crud_api`'s `CrudService` announces every successful write. Wire it to a
list and a detail screen never has to tell the list anything:

```dart
class TodoListCubit extends LoadCubit<List<Todo>> {
  TodoListCubit(this._service) : super(_service.findAll, loadOnCreate: true) {
    _subscription = _service.events.listen((_) => refresh());
  }

  final CrudService<Todo, String> _service;
  late final StreamSubscription<CrudEvent<Todo>> _subscription;

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
```

`refresh` rather than `load`, so the list does not blink when something else
changes.

## Guide 6: testing

The cubits are plain Dart objects over a repository, so a fake repository is all
the setup they need - and `fabitus_crud_api` ships one:

```dart
final repository = InMemoryCrudRepository<Todo, String>(
  withId: (todo, id) => todo.copyWith(id: id),
  initial: const [Todo(id: '1', title: 'Write docs')],
);

test('save writes the draft and clears the dirty flag', () async {
  final cubit = EntityCubit<Todo, String>(repository)..select(todo);

  cubit.edit((todo) => todo.copyWith(title: 'Renamed'));
  await cubit.save();

  expect(cubit.state.entity?.title, 'Renamed');
  expect(cubit.state.isDirty, isFalse);
});
```

With `bloc_test`, the state sequence is writable down - because failure states
leave the `StackTrace` out of `==`:

```dart
blocTest<LoadCubit<Todo>, LoadState<Todo>>(
  'emits loading then success',
  build: () => LoadCubit<Todo>(load),
  act: (cubit) => cubit.load(),
  expect: () => [LoadInProgress<Todo>(), const LoadSuccess(todo)],
);
```

Two things to know when widget testing `LoadBuilder`:

- A cubit's `emit` reaches `BlocBuilder` through a stream, so **one `pump()` is
  not enough** - the first lets the listener run, the second renders. Use two.
- `pumpAndSettle()` **times out on the loading state**, because the default
  `CircularProgressIndicator` animates forever. Use it only where no spinner is
  on screen.

Both are in [`test/load_builder_test.dart`](test/load_builder_test.dart).

## Design notes

**Why is the `StackTrace` outside `==`?** Two failures with the same error are
the same state as far as a widget is concerned. Comparing stack traces by
identity would rebuild on every retry that fails the same way, and would make the
state impossible to write down in a `bloc_test` expectation. Same reason
`CrudFailure` does it in `fabitus_crud_api`.

**Why no `freezed` here?** Precisely because of the line above: `freezed`
generates an `==` over every field, and the one field that must stay out of it is
the one it cannot skip. The states are hand written, sealed where a `switch`
should be exhaustive.

**Why does `loadOnCreate` wait a microtask?** Emitting inside the constructor
makes the initial state unobservable - a subscriber attaches after it has already
gone. Deferring by one microtask means a `BlocBuilder` built in the same frame
still sees the spinner, and a test can assert the whole sequence.

**Why is `previousPage` served from memory?** Because a cursor cannot look
backwards. Keeping the pages read makes going back work for cursor and offset
collections alike, and makes `allItems` correct for an endless scroll.

**Why is there no `PaginationBuilder`?** A paged list is a table for one screen
and an endless scroll for the next; there is no default worth defaulting to.
`LoadBuilder` exists because loading really does have one sensible shape.

## License

[MIT](LICENSE) © Fabitus GmbH.
