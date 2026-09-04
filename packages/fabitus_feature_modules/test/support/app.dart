import 'package:fabitus_feature_modules/fabitus_feature_modules.dart';

/// The features of the app under test: a todo list, the labels you can put on a
/// todo, and the members of the team.
enum Feature {
  todos,
  labels,
  members;

  static Feature? tryParse(String name) => Feature.values.where((feature) => feature.wireName == name).firstOrNull;

  String get wireName => switch (this) {
    Feature.todos => 'TODO_MANAGEMENT',
    Feature.labels => 'LABEL_MANAGEMENT',
    Feature.members => 'MEMBER_MANAGEMENT',
  };
}

/// The roles a user of that app can hold.
enum Role {
  viewer,
  editor,
  admin;

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

/// The groups the navigation is split into.
enum NavGroup { data, administration }

/// The one typedef an app writes, so nothing downstream repeats the parameters.
typedef AppModule = FeatureModule<Feature, Role, AppRoute, NavEntry>;

/// And the matching registry.
typedef AppRegistry = FeatureRegistry<Feature, Role, AppRoute, NavEntry>;

class TodoModule extends AppModule {
  const TodoModule();

  @override
  Feature get id => Feature.todos;

  @override
  List<AppRoute> get routes => const [AppRoute('/todos'), AppRoute('/todos/:id')];

  @override
  NavEntry? get navigation => const NavEntry('Todos');

  @override
  Object? get group => NavGroup.data;
}

/// A module the backend does not know about yet, so it brings its own rights.
class LabelModule extends AppModule {
  const LabelModule();

  @override
  Feature get id => Feature.labels;

  @override
  List<AppRoute> get routes => const [AppRoute('/labels')];

  @override
  NavEntry? get navigation => const NavEntry('Labels');

  @override
  Object? get group => NavGroup.data;

  @override
  FeatureAccess<Role> get fallbackAccess => const FeatureAccess<Role>(
    navigation: {Role.viewer, Role.editor, Role.admin},
    read: {Role.viewer, Role.editor, Role.admin},
    create: {Role.admin},
    update: {Role.admin},
    delete: {Role.admin},
  );
}

/// A module without a navigation entry, reachable from the settings menu only.
class MemberModule extends AppModule {
  const MemberModule();

  @override
  Feature get id => Feature.members;

  @override
  List<AppRoute> get routes => const [AppRoute('/members')];
}

/// The same feature, but with an entry under Administration - for the grouping
/// tests, which need a second group.
class VisibleMemberModule extends MemberModule {
  const VisibleMemberModule();

  @override
  NavEntry? get navigation => const NavEntry('Members');

  @override
  Object? get group => NavGroup.administration;

  @override
  FeatureAccess<Role> get fallbackAccess => const FeatureAccess<Role>(navigation: {Role.admin}, read: {Role.admin});
}

/// The groups those modules name.
const List<FeatureGroup<NavEntry>> appGroups = [
  FeatureGroup<NavEntry>(id: NavGroup.data, heading: NavEntry('Data')),
  FeatureGroup<NavEntry>(id: NavGroup.administration, heading: NavEntry('Administration')),
];
