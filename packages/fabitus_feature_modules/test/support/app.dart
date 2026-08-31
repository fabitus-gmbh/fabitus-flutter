import 'package:fabitus_feature_modules/fabitus_feature_modules.dart';

/// The features of the app under test.
enum Feature {
  rss,
  taxonomy,
  users;

  static Feature? tryParse(String name) => Feature.values.where((feature) => feature.wireName == name).firstOrNull;

  String get wireName => switch (this) {
    Feature.rss => 'RSS_MANAGEMENT',
    Feature.taxonomy => 'TAXONOMY_MANAGEMENT',
    Feature.users => 'USER_MANAGEMENT',
  };
}

/// The roles a user of that app can hold.
enum Role {
  editor,
  admin,
  support;

  static Role? tryParse(String name) => Role.values.where((role) => role.name == name).firstOrNull;
}

/// A route, standing in for whatever a real router uses.
class AppRoute {
  const AppRoute(this.path);

  final String path;

  @override
  String toString() => path;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AppRoute && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// A navigation entry, standing in for a widget.
class NavEntry {
  const NavEntry(this.label);

  final String label;

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) => identical(this, other) || other is NavEntry && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

/// The one typedef an app writes, so nothing downstream repeats the parameters.
typedef AppModule = FeatureModule<Feature, Role, AppRoute, NavEntry>;

/// And the matching registry.
typedef AppRegistry = FeatureRegistry<Feature, Role, AppRoute, NavEntry>;

class RssModule extends AppModule {
  const RssModule();

  @override
  Feature get id => Feature.rss;

  @override
  List<AppRoute> get routes => const [AppRoute('/rss'), AppRoute('/rss/:id')];

  @override
  NavEntry? get navigation => const NavEntry('RSS');
}

/// A module the backend does not know about yet, so it brings its own rights.
class TaxonomyModule extends AppModule {
  const TaxonomyModule();

  @override
  Feature get id => Feature.taxonomy;

  @override
  List<AppRoute> get routes => const [AppRoute('/taxonomy')];

  @override
  NavEntry? get navigation => const NavEntry('Taxonomies');

  @override
  FeatureAccess<Role> get fallbackAccess => const FeatureAccess<Role>(
    navigation: {Role.editor, Role.admin, Role.support},
    read: {Role.editor, Role.admin, Role.support},
    create: {Role.admin},
    update: {Role.admin},
    delete: {Role.admin},
  );
}

/// A module without a navigation entry, reachable by deep link only.
class UsersModule extends AppModule {
  const UsersModule();

  @override
  Feature get id => Feature.users;

  @override
  List<AppRoute> get routes => const [AppRoute('/users')];
}
