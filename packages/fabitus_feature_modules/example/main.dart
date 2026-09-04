// A runnable tour of fabitus_feature_modules: declare the features of a small
// todo app, let each one register its own dependencies, group them the way a
// side navigation would, load the access rights a backend sent, and ask what
// four different users may do.
//
//   dart run example/main.dart
import 'package:fabitus_feature_modules/fabitus_feature_modules.dart';

Future<void> main() async {
  // 1. What the backend returned. It knows nothing about labels yet.
  final access = parseFeatureAccess<Feature, Role>(
    const [
      {
        'feature': 'TODO_MANAGEMENT',
        'navigation': ['editor', 'admin'],
        'read': ['editor', 'admin'],
        'create': ['editor', 'admin'],
        'update': ['editor', 'admin'],
        'delete': ['admin'],
      },
      {
        'feature': 'INVOICE_MANAGEMENT',
        'navigation': ['admin'],
        'read': ['admin'],
      },
    ],
    featureFromJson: Feature.tryParse,
    roleFromJson: Role.tryParse,
  );

  // 2. One registry, built from the modules, the groups they name, and that
  //    configuration.
  final registry = AppRegistry(
    modules: const [TodoModule(), InvoiceModule(), LabelModule(), MemberModule()],
    groups: const [
      FeatureGroup<NavEntry>(id: NavGroup.data, heading: 'Data'),
      FeatureGroup<NavEntry>(id: NavGroup.administration, heading: 'Administration'),
    ],
    access: access,
  );

  // 3. Every feature wires itself up, in module order. In a real app the
  //    locator is get_it and this is `getIt.registerLazySingleton(...)`.
  await registry.registerDependencies();
  print('registered: ${locator.registrations.join(', ')}');

  // 4. The router asks for every route, once.
  print('routes: ${registry.routes.join(', ')}');

  // 5. Every user gets their own navigation and their own permissions. The
  //    grouped view is what a side navigation renders; a section nobody may see
  //    anything in is left out, heading and all.
  for (final (name, roles) in const [
    ('nobody', <Role>[]),
    ('viewer', [Role.viewer]),
    ('editor', [Role.editor]),
    ('admin', [Role.admin]),
  ]) {
    print('\n$name');
    final sections = registry.navigationSectionsFor(roles);
    if (sections.isEmpty) print('  (no navigation)');
    for (final section in sections) {
      print('  ${section.heading ?? '(no heading)'}');
      for (final entry in section.entries) {
        print('    ${entry.navigation}');
      }
    }
    for (final feature in registry.features) {
      final allowed = registry.allowedOperations(feature, roles);
      print(
        '  ${feature.name}: '
        '${allowed.isEmpty ? '-' : allowed.map((operation) => operation.name).join(', ')}',
      );
    }
  }

  // 6. Labels have no config from the backend, so the module's own fallback
  //    applies - and it disappears the day the backend starts sending one.
  print(
    '\nlabel rights come from the module: '
    '${registry.accessFor(Feature.labels) == const LabelModule().fallbackAccess}',
  );
}

/// Stands in for get_it, to show the hook needs no particular container.
class Locator {
  final Map<String, Object Function()> _factories = {};

  /// What was registered, in order.
  final List<String> registrations = [];

  void register(String name, Object Function() create) {
    _factories[name] = create;
    registrations.add(name);
  }

  T get<T extends Object>(String name) => _factories[name]!() as T;
}

final Locator locator = Locator();

enum Feature {
  todos,
  invoices,
  labels,
  members;

  static Feature? tryParse(String name) => Feature.values.where((feature) => feature.wireName == name).firstOrNull;

  String get wireName => switch (this) {
    Feature.todos => 'TODO_MANAGEMENT',
    Feature.invoices => 'INVOICE_MANAGEMENT',
    Feature.labels => 'LABEL_MANAGEMENT',
    Feature.members => 'MEMBER_MANAGEMENT',
  };
}

/// The sections the navigation is split into.
enum NavGroup { data, administration }

enum Role {
  viewer,
  editor,
  admin;

  static Role? tryParse(String name) => Role.values.where((role) => role.name == name).firstOrNull;
}

/// Stands in for a `go_router` `RouteBase` and a navigation `Widget`, so the
/// example stays a plain Dart program.
typedef Route = String;
typedef NavEntry = String;

/// The one typedef an app writes.
typedef AppModule = FeatureModule<Feature, Role, Route, NavEntry>;
typedef AppRegistry = FeatureRegistry<Feature, Role, Route, NavEntry>;

class TodoModule extends AppModule {
  const TodoModule();

  @override
  Feature get id => Feature.todos;

  @override
  List<Route> get routes => const ['/todos', '/todos/:id'];

  @override
  NavEntry? get navigation => 'Todos';

  @override
  Object? get group => NavGroup.data;

  @override
  Future<void> registerDependencies() async {
    locator.register('TodoApi', () => 'a TodoApi');
    locator.register('TodoRepository', () => 'a TodoRepository over ${locator.get<String>('TodoApi')}');
  }
}

class InvoiceModule extends AppModule {
  const InvoiceModule();

  @override
  Feature get id => Feature.invoices;

  @override
  List<Route> get routes => const ['/invoices', '/invoices/:id'];

  @override
  NavEntry? get navigation => 'Invoices';

  @override
  Object? get group => NavGroup.data;

  /// Runs after TodoModule, so it may rely on what that one registered.
  @override
  Future<void> registerDependencies() async => locator.register('InvoiceRepository', () => 'an InvoiceRepository');
}

/// Under a different heading, and only for admins - so the whole section
/// disappears for everyone else.
class MemberModule extends AppModule {
  const MemberModule();

  @override
  Feature get id => Feature.members;

  @override
  List<Route> get routes => const ['/members'];

  @override
  NavEntry? get navigation => 'Members';

  @override
  Object? get group => NavGroup.administration;

  @override
  FeatureAccess<Role> get fallbackAccess => const FeatureAccess<Role>(navigation: {Role.admin}, read: {Role.admin});
}

class LabelModule extends AppModule {
  const LabelModule();

  @override
  Feature get id => Feature.labels;

  @override
  List<Route> get routes => const ['/labels'];

  @override
  NavEntry? get navigation => 'Labels';

  @override
  Object? get group => NavGroup.data;

  /// Shipped before the backend knew this feature: every role may read labels,
  /// only an admin may change them - a deleted label vanishes from every todo
  /// that carried it.
  @override
  FeatureAccess<Role> get fallbackAccess => const FeatureAccess<Role>(
    navigation: {Role.viewer, Role.editor, Role.admin},
    read: {Role.viewer, Role.editor, Role.admin},
    create: {Role.admin},
    update: {Role.admin},
    delete: {Role.admin},
  );
}
