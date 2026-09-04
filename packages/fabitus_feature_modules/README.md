# fabitus_feature_modules

Declare each feature of an app in one place - its routes, its navigation entry,
its access rights - and ask one registry what the current user may do.

```dart
final registry = AppRegistry(
  modules: const [TodoModule(), LabelModule(), MemberModule()],
  access: parseFeatureAccess(await api.accessRights(), ...),
);

await registry.registerDependencies();                 // each feature wires itself
GoRouter(routes: registry.routes);                     // the router
registry.navigationFor(user.roles);                    // a bar, a rail, tabs
registry.navigationSectionsFor(user.roles);            // a grouped side menu
registry.isAllowed(Feature.todos, CrudOperation.delete, user.roles);
```

- **No router.** `go_router` is not a dependency; it is simply what the route
  type parameter happens to be in a `go_router` app. `auto_route`, `Navigator`
  or plain path strings work the same way.
- **No opinion on where the navigation sits.** A bar across the top, a rail or
  drawer down the side, a command palette - the package decides *which* entries
  a user gets and how they group, never how they are laid out.
- **No Flutter.** Pure Dart, so the permission model is unit testable without a
  widget tree.
- **Deny by default.** A feature the backend sent no configuration for grants
  nothing, unless the module itself says what it should grant in the meantime.

## Contents

- [Installation](#installation)
- [The four pieces](#the-four-pieces)
- [Guide 1: declaring a module](#guide-1-declaring-a-module)
- [Guide 2: loading access rights from a backend](#guide-2-loading-access-rights-from-a-backend)
- [Guide 3: building the registry](#guide-3-building-the-registry)
- [Guide 4: with go_router](#guide-4-with-go_router)
- [Guide 5: each feature registers its own dependencies](#guide-5-each-feature-registers-its-own-dependencies)
- [Guide 6: grouping the navigation](#guide-6-grouping-the-navigation)
- [Guide 7: gating the UI](#guide-7-gating-the-ui)
- [Guide 8: a feature the backend does not know yet](#guide-8-a-feature-the-backend-does-not-know-yet)
- [Guide 9: testing](#guide-9-testing)
- [Design notes](#design-notes)

## Installation

```yaml
dependencies:
  fabitus_feature_modules:
    git:
      url: https://github.com/fabitus-gmbh/fabitus-flutter.git
      path: packages/fabitus_feature_modules
```

```dart
import 'package:fabitus_feature_modules/fabitus_feature_modules.dart';
```

Runtime dependencies are `collection` and `freezed_annotation`. You do **not**
need `build_runner` - the generated code ships with the package.

## The four pieces

| Type | Holds |
| --- | --- |
| `FeatureModule` | one feature: its id, its routes, its navigation entry, its group, its wiring |
| `FeatureAccess` | which roles are granted which `CrudOperation`, and the navigation |
| `FeatureGroup` | a heading several features appear under |
| `FeatureRegistry` | every module and group plus the access rights that arrived |

A module is a **constant**: it knows nothing about who is logged in, so it can be
built in a test without a user. Access rights arrive at runtime and live in the
registry. That split is what keeps the two testable apart.

Four type parameters name the four things only your app can decide - the feature
id, the role, the route type and whatever navigation is made of. Name them once:

```dart
typedef AppModule = FeatureModule<Feature, Role, RouteBase, Widget>;
typedef AppRegistry = FeatureRegistry<Feature, Role, RouteBase, Widget>;
```

Everything downstream then reads as `class TodoModule extends AppModule`.

## Guide 1: declaring a module

The app below is a todo list: todos, the labels you can put on one, and the
members of the team.

```dart
enum Feature { todos, labels, members }

enum Role { viewer, editor, admin }

class TodoModule extends AppModule {
  const TodoModule();

  @override
  Feature get id => Feature.todos;

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/todos', builder: (_, _) => const TodoListPage()),
    GoRoute(path: '/todos/:id', builder: (_, state) =>
        TodoEditPage(id: state.pathParameters['id']!)),
  ];

  @override
  Widget? get navigation => const NavigationItem(
    icon: Icon(Icons.check_box_outlined),
    label: 'Todos',
    target: '/todos',
  );
}
```

`navigation` is optional - return `null` for a feature reachable only by a deep
link. Whether the entry is *shown* is not decided here; the registry filters by
the roles of the user actually looking at it. And nothing says *where* it is
shown: `TNav` is whatever your navigation is made of, top bar or side rail
alike - see [Guide 6](#guide-6-grouping-the-navigation).

Because `Feature` is an enum, a `switch` over it stays exhaustive, so adding a
feature makes the compiler point at every place that has to handle it.

## Guide 2: loading access rights from a backend

A typical configuration endpoint returns one entry per feature:

```json
[
  {
    "feature": "TODO_MANAGEMENT",
    "navigation": ["editor", "admin"],
    "read": ["editor", "admin"],
    "create": ["editor", "admin"],
    "update": ["editor", "admin"],
    "delete": ["admin"]
  }
]
```

```dart
final access = parseFeatureAccess<Feature, Role>(
  await api.accessRights(),
  featureFromJson: Feature.tryParse,
  roleFromJson: Role.tryParse,
);
```

The two decoders return `null` for a name this app does not know, and unknown
names are dropped: a feature the *server* gained but this build has not is
skipped rather than fatal, and a retired role name cannot grant anything.

A map keyed by feature name is read too, and `featureKey` renames the field when
your backend calls it something other than `feature`. An operation that is
missing, `null` or not a list becomes an empty set, so one malformed key does not
cost you the rest of the configuration.

`navigation` is a separate list from `read` on purpose: a feature can be
reachable by a link for a role that should not be advertised the module.

## Guide 3: building the registry

```dart
final registry = AppRegistry(
  modules: const [TodoModule(), LabelModule(), MemberModule()],
  access: access,
);
```

Access is resolved once, at construction, in this order:

1. what the backend sent for that feature,
2. else the module's own `fallbackAccess`,
3. else nothing at all - the feature is denied.

Build a new registry when the configuration is reloaded; two modules claiming the
same feature id throw an `ArgumentError` rather than one silently winning.

Then let every module wire itself up, and register the registry wherever your app
keeps its singletons - see
[Guide 5](#guide-5-each-feature-registers-its-own-dependencies) for the whole
startup sequence:

```dart
await registry.registerDependencies();
getIt.registerSingleton<AppRegistry>(registry);
```

## Guide 4: with `go_router`

There is no adapter to install. `go_router`'s `RouteBase` is what you put in the
route type parameter, and `registry.routes` is a `List<RouteBase>`:

```dart
typedef AppModule = FeatureModule<Feature, Role, RouteBase, Widget>;

GoRouter buildRouter(AppRegistry registry) => GoRouter(
  initialLocation: '/todos',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppScaffold(child: child),
      routes: registry.routes,
    ),
  ],
);
```

`routes` is **not** filtered by the current user, deliberately. A router is
usually built once while the user can change, and leaving a route out turns "you
may not open this" into "this does not exist". Refuse in a redirect instead:

```dart
GoRoute(
  path: '/todos',
  redirect: (context, state) => registry.isAllowed(
    Feature.todos,
    CrudOperation.read,
    context.read<AuthCubit>().state.roles,
  )
      ? null
      : '/forbidden',
  builder: (_, _) => const TodoListPage(),
);
```

For another router, change one type parameter. With `auto_route` it is
`AutoRoute`; with a hand rolled `Navigator` map it can be `String` and the app
looks the widget up itself.

## Guide 5: each feature registers its own dependencies

A feature's wiring is the third thing it owns, beside its routes and its
navigation. Declaring it in the module means adding a feature is adding one entry
to the module list, and deleting one is deleting one file - instead of both, plus
an edit to a central `injection_container.dart` that nobody notices is now wrong.

```dart
class TodoModule extends AppModule {
  const TodoModule();

  @override
  Future<void> registerDependencies() async {
    getIt
      ..registerLazySingleton<TodoApi>(() => TodoApi(getIt()))
      ..registerLazySingleton<PagingCrudRepository<Todo, String>>(
        () => RemotePagingCrudRepository(
          getIt<TodoApi>(),
          errorMapper: const DioCrudErrorMapper(),
        ),
      )
      ..registerLazySingleton<PagingCrudService<Todo, String>>(
        () => PagingCrudService(
          getIt(),
          listeners: [CrudEventListener.fromCallback(getIt<EventBus>().fire)],
        ),
        dispose: (service) => service.dispose(),
      );
  }

  // ... id, routes, navigation, group
}
```

The registry runs them all, once, at startup:

```dart
Future<void> bootstrap() async {
  // 1. The core services the features build on.
  getIt
    ..registerLazySingleton<Dio>(buildDio)
    ..registerLazySingleton<EventBus>(EventBus.new);

  // 2. The registry, with the access rights the backend sent.
  final registry = AppRegistry(
    modules: const [TodoModule(), InvoiceModule(), MemberModule()],
    groups: appNavGroups,
    access: parseFeatureAccess(
      await getIt<UserApi>().accessRights(),
      featureFromJson: Feature.tryParse,
      roleFromJson: Role.tryParse,
    ),
  );

  // 3. Every feature wires itself.
  await registry.registerDependencies();

  getIt.registerSingleton<AppRegistry>(registry);
  runApp(App(registry: registry));
}
```

Three things worth knowing:

- **Sequential, in module order.** A module may rely on what the ones before it
  registered. Order the `modules` list accordingly - it is the same list that
  orders the navigation.
- **Async.** Some registrations are (`registerSingletonAsync`, a database that
  has to open), so the hook is `Future<void>`.
- **Failures propagate.** Whatever a module throws comes out of
  `registerDependencies`, so a misconfigured app fails at startup instead of on
  the screen that needed the missing service.

### Why it takes no container argument

Because the locator is the app's, and `GetIt.instance` is already how a module
reaches it. A facade over `get_it` in this package was the alternative, and it
would have been the wrong one: too small to express async singletons, scopes,
named instances or disposal, so every real app would end up reaching past it.
Nothing here depends on `get_it` - a module that uses `riverpod`, `injectable` or
a plain global works exactly the same way.

## Guide 6: grouping the navigation

A side navigation is usually sections, not a flat list:

```
Data
  Todos
  Invoices
Administration
  Members
```

Each module names the group it belongs to, and the registry is told what the
groups are called:

```dart
enum NavGroup { data, administration }

class TodoModule extends AppModule {
  const TodoModule();

  @override
  Object? get group => NavGroup.data;

  // ... id, routes, navigation
}

final registry = AppRegistry(
  modules: const [TodoModule(), InvoiceModule(), MemberModule()],
  groups: const [
    FeatureGroup<Widget>(id: NavGroup.data, heading: NavSectionHeading('Data')),
    FeatureGroup<Widget>(
      id: NavGroup.administration,
      heading: NavSectionHeading('Administration'),
    ),
  ],
  access: access,
);
```

`navigationSectionsFor` then hands you the menu, already filtered:

```dart
ListView(
  children: [
    for (final section in registry.navigationSectionsFor(user.roles)) ...[
      ?section.heading,
      for (final entry in section.entries) entry.navigation,
    ],
  ],
);
```

Three things it decides for you:

- **A section whose entries are all hidden is left out**, so a heading never
  appears over nothing. An editor who may not administer anything simply has no
  "Administration".
- **Section order follows module order.** A section appears where its first
  visible module appears, and the rest of that group collects into it. One rule
  governs the whole menu, and reordering `modules` reorders the sections - the
  `groups` list only supplies headings.
- **A feature that names no group** lands in a section whose `group` is `null`,
  keeping its place among the others. Render those without a heading.

A module naming a group that is not declared throws at construction, so a typo
surfaces at startup rather than as a menu entry that quietly went missing.

For a flat navigation there is nothing to do differently - `navigationFor`
ignores groups entirely, and `visibleEntriesFor` is the same list with each
entry's feature attached, for marking the current one:

```dart
NavigationBar(
  selectedIndex: entries.indexWhere((entry) => entry.feature == current),
  destinations: [for (final entry in entries) entry.navigation],
);
```

`isGroupVisible(NavGroup.data, roles)` and `featuresInGroup(NavGroup.data)`
answer the two questions a menu sometimes asks directly.

## Guide 7: gating the UI

The navigation, filtered for the user looking at it - here as a rail, but the
package does not care:

```dart
BlocBuilder<AuthCubit, AuthState>(
  builder: (context, state) => NavigationRail(
    destinations: registry.navigationFor(state.roles),
  ),
);
```

A page or form usually wants every permission at once, so it can decide which
buttons exist rather than asking one question per button:

```dart
final allowed = registry.allowedOperations(Feature.todos, user.roles);

return Column(
  children: [
    if (allowed.contains(CrudOperation.create))
      FilledButton(onPressed: _create, child: const Text('New todo')),
    TodoForm(readOnly: !allowed.contains(CrudOperation.update)),
    if (allowed.contains(CrudOperation.delete))
      TextButton(onPressed: _delete, child: const Text('Delete')),
  ],
);
```

Hiding a button is not authorisation - the backend still has to refuse the call.
This decides what to *offer*, so a user is not shown an action that will fail.

Pairs naturally with [`fabitus_crud_api`](../fabitus_crud_api), which this
package does not depend on: gate the call, and let the repository report what the
server said.

```dart
if (registry.isAllowed(Feature.todos, CrudOperation.delete, user.roles)) {
  final result = await repository.deleteById(id);
}
```

## Guide 8: a feature the backend does not know yet

A module that ships before the server has a configuration for it would otherwise
be locked for everyone. Say what it should grant in the meantime:

```dart
class LabelModule extends AppModule {
  const LabelModule();

  @override
  Feature get id => Feature.labels;

  /// The rights to use while the backend returns no `LABEL_MANAGEMENT` entry.
  /// Readable by every role, writable by admins only: labels are shared across
  /// the whole board, and a deleted one vanishes from every todo that carried
  /// it, so the stricter half of the rule is the one to keep while we guess.
  @override
  FeatureAccess<Role> get fallbackAccess => const FeatureAccess<Role>(
    navigation: {Role.viewer, Role.editor, Role.admin},
    read: {Role.viewer, Role.editor, Role.admin},
    create: {Role.admin},
    update: {Role.admin},
    delete: {Role.admin},
  );

  // ... routes, navigation
}
```

The fallback is dropped the day the backend starts sending an entry for the
feature. Nothing else changes, and no lookup anywhere needs a special case.

Leave `fallbackAccess` out and an unconfigured feature is denied, which is the
right default for one you have not thought about.

## Guide 9: testing

The permission model is pure Dart, so the interesting cases need no widget tree:

```dart
test('an editor may read but not delete', () {
  final registry = AppRegistry(
    modules: const [TodoModule()],
    access: {
      Feature.todos: const FeatureAccess<Role>(
        read: {Role.editor, Role.admin},
        delete: {Role.admin},
      ),
    },
  );

  expect(registry.allowedOperations(Feature.todos, [Role.editor]), {CrudOperation.read});
  expect(registry.isAllowed(Feature.todos, CrudOperation.delete, [Role.editor]), isFalse);
});
```

A registry that is only asked about permissions never runs
`registerDependencies`, so a test about access rights needs no service locator at
all. When you do want to test the wiring, `get_it` gives you a clean slate:

```dart
setUp(() => getIt.reset());

test('the todo module registers a repository', () async {
  await AppRegistry(modules: const [TodoModule()]).registerDependencies();

  expect(getIt.isRegistered<PagingCrudRepository<Todo, String>>(), isTrue);
});
```

`FeatureAccess.uniform({Role.admin})` grants everything to the roles you name,
for the tests that are not about permissions at all. And the fixture in
[`test/support/app.dart`](test/support/app.dart) shows the whole shape - feature
enum, role enum, modules, typedefs - with plain classes standing in for routes
and widgets.

## Design notes

**Why is the module constant and the access separate?** Rights come from a server
and change with the user; routes and navigation do not. Keeping them apart means
a module is a value you can construct in a test, and the registry is the only
thing that needs a logged in user.

**Why four type parameters?** They are the four decisions this package must not
make for you: what identifies a feature, what a role is, what your router calls a
route, and what your navigation is built from. Baking in `String` ids would cost
the exhaustive `switch`; baking in `RouteBase` would make `go_router` a
dependency. One typedef per app pays for all of it once.

**Why is `navigation` separate from `read`?** Because "may open this page" and
"should be told this module exists" are different questions, and a deep link
answers only the first.

**Why is a group id `Object` rather than a fifth type parameter?** Because a
group is something you render a label for, not something you `switch` over
exhaustively - the exhaustiveness that earns `F` its type parameter buys nothing
here, and a fifth parameter would be paid by every app, grouped or not. The
safety that matters is caught anyway: a module naming an undeclared group is
rejected when the registry is built.

**Why does `registerDependencies` take no container?** Because the locator is
the app's. A facade over `get_it` in this package would be too small to express
async singletons, scopes, named instances or disposal, so every real app would
reach past it - and then the abstraction is only in the way. `GetIt.instance` is
already how a module reaches its locator, and a module on `riverpod` or a plain
global works the same way.

**Why is `registerDependencies` not called by the constructor?** Registration can
be async and a constructor cannot await. Keeping it separate also means a test
that only asks about permissions needs no service locator at all.

**Why does group order come from the modules?** Because two ordered lists that
have to agree is a bug waiting to happen. `groups` says what a group is called;
`modules` says what order everything is in. Adding a module in the right place
puts it in the right place.

**Why no `cancel` operation?** `CrudOperation` covers the four things a role can
be granted. Closing a form is not one of them - nobody needs a permission for it,
and listing it would mean shipping a permission that always holds.

**Why is `routes` unfiltered?** See [Guide 4](#guide-4-with-go_router): a
missing route reports the wrong thing. Refuse in a redirect, where you can say
why.

## License

[MIT](LICENSE) © Fabitus GmbH.
