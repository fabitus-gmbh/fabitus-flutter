# fabitus_feature_modules

Declare each feature of an app in one place - its routes, its navigation entry,
its access rights - and ask one registry what the current user may do.

```dart
final registry = AppRegistry(
  modules: const [RssModule(), TaxonomyModule(), UserModule()],
  access: parseFeatureAccess(await api.accessRights(), ...),
);

GoRouter(routes: registry.routes);                          // the router
Row(children: registry.navigationFor(user.roles));           // the app bar
registry.isAllowed(Feature.rss, CrudOperation.delete, user.roles);
```

- **No router.** `go_router` is not a dependency; it is simply what the route
  type parameter happens to be in a `go_router` app. `auto_route`, `Navigator`
  or plain path strings work the same way.
- **No Flutter.** Pure Dart, so the permission model is unit testable without a
  widget tree.
- **Deny by default.** A feature the backend sent no configuration for grants
  nothing, unless the module itself says what it should grant in the meantime.

## Contents

- [Installation](#installation)
- [The three pieces](#the-three-pieces)
- [Guide 1: declaring a module](#guide-1-declaring-a-module)
- [Guide 2: loading access rights from a backend](#guide-2-loading-access-rights-from-a-backend)
- [Guide 3: building the registry](#guide-3-building-the-registry)
- [Guide 4: with go_router](#guide-4-with-go_router)
- [Guide 5: gating the UI](#guide-5-gating-the-ui)
- [Guide 6: a feature the backend does not know yet](#guide-6-a-feature-the-backend-does-not-know-yet)
- [Guide 7: testing](#guide-7-testing)
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

## The three pieces

| Type | Holds |
| --- | --- |
| `FeatureModule` | one feature: its id, its routes, its navigation entry |
| `FeatureAccess` | which roles are granted which `CrudOperation`, and the navigation |
| `FeatureRegistry` | every module plus the access rights that arrived for them |

A module is a **constant**: it knows nothing about who is logged in, so it can be
built in a test without a user. Access rights arrive at runtime and live in the
registry. That split is what keeps the two testable apart.

Four type parameters name the four things only your app can decide - the feature
id, the role, the route type and whatever navigation is made of. Name them once:

```dart
typedef AppModule = FeatureModule<Feature, Role, RouteBase, Widget>;
typedef AppRegistry = FeatureRegistry<Feature, Role, RouteBase, Widget>;
```

Everything downstream then reads as `class RssModule extends AppModule`.

## Guide 1: declaring a module

```dart
enum Feature { rss, taxonomy, users }

enum Role { editor, admin, support }

class RssModule extends AppModule {
  const RssModule();

  @override
  Feature get id => Feature.rss;

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/rss', builder: (_, _) => const RssOverviewPage()),
    GoRoute(path: '/rss/:id', builder: (_, state) =>
        RssEditPage(id: state.pathParameters['id']!)),
  ];

  @override
  Widget? get navigation =>
      const NavigationItem(icon: Icon(Icons.rss_feed), label: 'RSS', target: '/rss');
}
```

`navigation` is optional - return `null` for a feature reachable only by a deep
link. Whether the entry is *shown* is not decided here; the registry filters by
the roles of the user actually looking at it.

Because `Feature` is an enum, a `switch` over it stays exhaustive, so adding a
feature makes the compiler point at every place that has to handle it.

## Guide 2: loading access rights from a backend

A typical configuration endpoint returns one entry per feature:

```json
[
  {
    "feature": "RSS_MANAGEMENT",
    "navigation": ["editor", "admin"],
    "read": ["editor", "admin"],
    "create": ["admin"],
    "update": ["admin"],
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
  modules: const [RssModule(), TaxonomyModule(), UserModule()],
  access: access,
);
```

Access is resolved once, at construction, in this order:

1. what the backend sent for that feature,
2. else the module's own `fallbackAccess`,
3. else nothing at all - the feature is denied.

Build a new registry when the configuration is reloaded; two modules claiming the
same feature id throw an `ArgumentError` rather than one silently winning.

Register it wherever your app keeps singletons:

```dart
getIt.registerSingletonAsync<AppRegistry>(() async => AppRegistry(
  modules: const [RssModule(), TaxonomyModule(), UserModule()],
  access: parseFeatureAccess(
    await getIt<UserApi>().accessRights(),
    featureFromJson: Feature.tryParse,
    roleFromJson: Role.tryParse,
  ),
));
```

## Guide 4: with `go_router`

There is no adapter to install. `go_router`'s `RouteBase` is what you put in the
route type parameter, and `registry.routes` is a `List<RouteBase>`:

```dart
typedef AppModule = FeatureModule<Feature, Role, RouteBase, Widget>;

GoRouter buildRouter(AppRegistry registry) => GoRouter(
  initialLocation: '/rss',
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
  path: '/rss',
  redirect: (context, state) => registry.isAllowed(
    Feature.rss,
    CrudOperation.read,
    context.read<AuthCubit>().state.roles,
  )
      ? null
      : '/forbidden',
  builder: (_, _) => const RssOverviewPage(),
);
```

For another router, change one type parameter. With `auto_route` it is
`AutoRoute`; with a hand rolled `Navigator` map it can be `String` and the app
looks the widget up itself.

## Guide 5: gating the UI

The navigation, filtered for the user looking at it:

```dart
BlocBuilder<AuthCubit, AuthState>(
  builder: (context, state) => Row(
    children: registry.navigationFor(state.roles),
  ),
);
```

A page or form usually wants every permission at once, so it can decide which
buttons exist rather than asking one question per button:

```dart
final allowed = registry.allowedOperations(Feature.rss, user.roles);

return Column(
  children: [
    if (allowed.contains(CrudOperation.create))
      FilledButton(onPressed: _create, child: const Text('New feed')),
    RssForm(readOnly: !allowed.contains(CrudOperation.update)),
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
if (registry.isAllowed(Feature.rss, CrudOperation.delete, user.roles)) {
  final result = await repository.deleteById(id);
}
```

## Guide 6: a feature the backend does not know yet

A module that ships before the server has a configuration for it would otherwise
be locked for everyone. Say what it should grant in the meantime:

```dart
class TaxonomyModule extends AppModule {
  const TaxonomyModule();

  @override
  Feature get id => Feature.taxonomy;

  /// The rights to use while the user-management API returns no
  /// `TAXONOMY_MANAGEMENT` entry. Readable by every group, writable by admins:
  /// taxonomy terms are shared, and a deleted term takes its assignments along,
  /// so the stricter half of the old rule is the one to keep.
  @override
  FeatureAccess<Role> get fallbackAccess => const FeatureAccess<Role>(
    navigation: {Role.editor, Role.admin, Role.support},
    read: {Role.editor, Role.admin, Role.support},
    create: {Role.admin},
    update: {Role.admin},
    delete: {Role.admin},
  );

  // ... id, routes, navigation
}
```

The fallback is dropped the day the backend starts sending an entry for the
feature. Nothing else changes, and no lookup anywhere needs a special case.

Leave `fallbackAccess` out and an unconfigured feature is denied, which is the
right default for one you have not thought about.

## Guide 7: testing

The permission model is pure Dart, so the interesting cases need no widget tree:

```dart
test('an editor may read but not delete', () {
  final registry = AppRegistry(
    modules: const [RssModule()],
    access: {
      Feature.rss: const FeatureAccess<Role>(
        read: {Role.editor, Role.admin},
        delete: {Role.admin},
      ),
    },
  );

  expect(registry.allowedOperations(Feature.rss, [Role.editor]), {CrudOperation.read});
  expect(registry.isAllowed(Feature.rss, CrudOperation.delete, [Role.editor]), isFalse);
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

**Why no `cancel` operation?** `CrudOperation` covers the four things a role can
be granted. Closing a form is not one of them - nobody needs a permission for it,
and listing it would mean shipping a permission that always holds.

**Why is `routes` unfiltered?** See [Guide 4](#guide-4-with-go_router): a
missing route reports the wrong thing. Refuse in a redirect, where you can say
why.

## License

[MIT](LICENSE) © Fabitus GmbH.
