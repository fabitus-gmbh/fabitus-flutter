// A runnable tour of fabitus_feature_modules: declare two features, load the
// access rights a backend sent, and ask what three different users may do.
//
//   dart run example/main.dart
import 'package:fabitus_feature_modules/fabitus_feature_modules.dart';

void main() {
  // 1. What the backend returned. It knows nothing about taxonomy yet.
  final access = parseFeatureAccess<Feature, Role>(
    const [
      {
        'feature': 'RSS_MANAGEMENT',
        'navigation': ['editor', 'admin'],
        'read': ['editor', 'admin'],
        'create': ['admin'],
        'update': ['admin'],
        'delete': ['admin'],
      },
    ],
    featureFromJson: Feature.tryParse,
    roleFromJson: Role.tryParse,
  );

  // 2. One registry, built from the modules plus that configuration.
  final registry = AppRegistry(modules: const [RssModule(), TaxonomyModule()], access: access);

  // 3. The router asks for every route, once.
  print('routes: ${registry.routes.join(', ')}');

  // 4. Every user gets their own navigation and their own permissions.
  for (final (name, roles) in const [
    ('nobody', <Role>[]),
    ('editor', [Role.editor]),
    ('admin', [Role.admin]),
  ]) {
    print('\n$name');
    print('  navigation: ${registry.navigationFor(roles).join(', ')}');
    for (final feature in registry.features) {
      final allowed = registry.allowedOperations(feature, roles);
      print('  ${feature.name}: ${allowed.isEmpty ? '-' : allowed.map((o) => o.name).join(', ')}');
    }
  }

  // 5. Taxonomy has no config from the backend, so its own fallback applies -
  //    and it disappears the day the backend starts sending one.
  print(
    '\ntaxonomy rights come from the module: '
    '${registry.accessFor(Feature.taxonomy) == const TaxonomyModule().fallbackAccess}',
  );
}

enum Feature {
  rss,
  taxonomy;

  static Feature? tryParse(String name) => Feature.values.where((feature) => feature.wireName == name).firstOrNull;

  String get wireName => switch (this) {
    Feature.rss => 'RSS_MANAGEMENT',
    Feature.taxonomy => 'TAXONOMY_MANAGEMENT',
  };
}

enum Role {
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

class RssModule extends AppModule {
  const RssModule();

  @override
  Feature get id => Feature.rss;

  @override
  List<Route> get routes => const ['/rss', '/rss/:id'];

  @override
  NavEntry? get navigation => 'RSS';
}

class TaxonomyModule extends AppModule {
  const TaxonomyModule();

  @override
  Feature get id => Feature.taxonomy;

  @override
  List<Route> get routes => const ['/taxonomy'];

  @override
  NavEntry? get navigation => 'Taxonomies';

  /// Shipped before the backend knew this feature: readable by everyone,
  /// writable by admins only.
  @override
  FeatureAccess<Role> get fallbackAccess => const FeatureAccess<Role>(
    navigation: {Role.editor, Role.admin},
    read: {Role.editor, Role.admin},
    create: {Role.admin},
    update: {Role.admin},
    delete: {Role.admin},
  );
}
