import 'package:collection/collection.dart';

import 'crud_operation.dart';
import 'feature_access.dart';
import 'feature_group.dart';
import 'feature_module.dart';

/// The modules an app is built from, together with the access rights that
/// arrived for them.
///
/// One instance answers the three questions the rest of the app has: what
/// routes exist, what navigation this user sees, and what this user may do.
///
/// ```dart
/// final registry = FeatureRegistry<Feature, Role, RouteBase, Widget>(
///   modules: const [TodoModule(), LabelModule()],
///   access: parseFeatureAccess(
///     await api.getAccessRightConfig(),
///     featureFromJson: Feature.tryParse,
///     roleFromJson: Role.tryParse,
///   ),
/// );
///
/// GoRouter(routes: registry.routes);
/// registry.navigationFor(user.roles);          // flat, for a bar or a rail
/// registry.navigationSectionsFor(user.roles);  // grouped, for a side menu
/// if (registry.isAllowed(Feature.todos, CrudOperation.delete, user.roles)) ...
/// ```
///
/// Access is resolved once, at construction: what the backend sent, else the
/// module's [FeatureModule.fallbackAccess], else nothing at all. Build a new
/// registry when the configuration is reloaded.
class FeatureRegistry<F extends Object, R extends Object, TRoute, TNav> {
  /// Collects [modules] and resolves their access rights against [access].
  ///
  /// [groups] declares the navigation groups the modules may name, with the
  /// heading each is rendered under. A group nobody names is simply unused; a
  /// module naming one that is not declared is an error.
  ///
  /// Throws [ArgumentError] when two modules claim the same
  /// [FeatureModule.id], when two groups share an id, or when a module names an
  /// undeclared group - each would otherwise show up as a silently missing menu
  /// entry.
  FeatureRegistry({
    required Iterable<FeatureModule<F, R, TRoute, TNav>> modules,
    Map<F, FeatureAccess<R>> access = const {},
    Iterable<FeatureGroup<TNav>> groups = const [],
  }) : modules = List.unmodifiable(modules),
       groups = List.unmodifiable(groups) {
    final duplicate = this.modules
        .map((module) => module.id)
        .groupFoldBy<F, int>((id) => id, (count, _) => (count ?? 0) + 1)
        .entries
        .firstWhereOrNull((entry) => entry.value > 1);
    if (duplicate != null) {
      throw ArgumentError.value(modules, 'modules', 'More than one module claims the feature ${duplicate.key}');
    }
    final duplicateGroup = this.groups
        .map((group) => group.id)
        .groupFoldBy<Object, int>((id) => id, (count, _) => (count ?? 0) + 1)
        .entries
        .firstWhereOrNull((entry) => entry.value > 1);
    if (duplicateGroup != null) {
      throw ArgumentError.value(groups, 'groups', 'More than one group claims the id ${duplicateGroup.key}');
    }

    _groups = {for (final group in this.groups) group.id: group};

    final orphan = this.modules.firstWhereOrNull(
      (module) => module.group != null && !_groups.containsKey(module.group),
    );
    if (orphan != null) {
      throw ArgumentError.value(
        modules,
        'modules',
        '${orphan.runtimeType} names the group ${orphan.group}, which is not declared in groups',
      );
    }

    _access = {
      for (final module in this.modules) module.id: access[module.id] ?? module.fallbackAccess ?? FeatureAccess<R>(),
    };
  }

  /// The modules, in the order they were given.
  final List<FeatureModule<F, R, TRoute, TNav>> modules;

  /// The navigation groups, in the order they were declared.
  final List<FeatureGroup<TNav>> groups;

  late final Map<Object, FeatureGroup<TNav>> _groups;
  late final Map<F, FeatureAccess<R>> _access;

  /// The features this registry knows, in module order.
  List<F> get features => List.unmodifiable(modules.map((module) => module.id));

  /// The module for [feature], or `null` when no module claims it.
  FeatureModule<F, R, TRoute, TNav>? moduleFor(F feature) => modules.firstWhereOrNull((module) => module.id == feature);

  /// The resolved access rights for [feature].
  ///
  /// An empty, all-denying [FeatureAccess] for a feature no module claims, so an
  /// unknown feature is refused rather than waved through.
  FeatureAccess<R> accessFor(F feature) => _access[feature] ?? FeatureAccess<R>();

  /// Every route of every module, in module order.
  ///
  /// Unfiltered on purpose: a router is usually built once, while the user can
  /// change. Refuse the page inside a route guard - `isAllowed(..., read, ...)`
  /// - rather than by leaving the route out and turning "not allowed" into
  /// "not found".
  List<TRoute> get routes => List.unmodifiable(modules.expand((module) => module.routes));

  /// The navigation entries a user holding [userRoles] should see, in module
  /// order, ignoring groups.
  ///
  /// Modules without a [FeatureModule.navigation] and modules whose navigation
  /// this user is not granted are left out. Use this for a flat navigation - a
  /// bar, a rail, a set of tabs - and [navigationSectionsFor] when the groups
  /// should show.
  List<TNav> navigationFor(Iterable<R> userRoles) =>
      List.unmodifiable(visibleEntriesFor(userRoles).map((entry) => entry.navigation));

  /// The visible navigation entries with the feature each belongs to, in module
  /// order.
  ///
  /// Same filtering as [navigationFor]; use this when the caller has to know
  /// which entry is the current one.
  List<NavigationEntry<F, TNav>> visibleEntriesFor(Iterable<R> userRoles) {
    final assigned = userRoles.toSet();
    return List.unmodifiable(<NavigationEntry<F, TNav>>[
      for (final module in modules)
        if (module.navigation case final TNav entry)
          if (accessFor(module.id).allowsNavigation(assigned))
            NavigationEntry<F, TNav>(feature: module.id, navigation: entry),
    ]);
  }

  /// The navigation a user holding [userRoles] should see, split into the groups
  /// the modules declared.
  ///
  /// A section appears where its first visible module appears, and every module
  /// of that group collects into it - so one rule, module order, governs the
  /// whole menu, and reordering [modules] reorders the sections with it.
  /// Features that declared no group land in a section whose
  /// [NavigationSection.group] is `null`, to be rendered without a heading.
  ///
  /// A section whose entries are all hidden is left out, so a heading is never
  /// rendered over nothing.
  ///
  /// ```dart
  /// ListView(
  ///   children: [
  ///     for (final section in registry.navigationSectionsFor(user.roles)) ...[
  ///       ?section.heading,
  ///       for (final entry in section.entries) entry.navigation,
  ///     ],
  ///   ],
  /// );
  /// ```
  List<NavigationSection<F, TNav>> navigationSectionsFor(Iterable<R> userRoles) {
    final order = <Object?>[];
    final entriesByGroup = <Object?, List<NavigationEntry<F, TNav>>>{};

    for (final entry in visibleEntriesFor(userRoles)) {
      final group = moduleFor(entry.feature)?.group;
      if (!entriesByGroup.containsKey(group)) {
        order.add(group);
        entriesByGroup[group] = [];
      }
      entriesByGroup[group]!.add(entry);
    }

    return List.unmodifiable(<NavigationSection<F, TNav>>[
      for (final group in order)
        NavigationSection<F, TNav>(
          group: group == null ? null : _groups[group],
          entries: List.unmodifiable(entriesByGroup[group]!),
        ),
    ]);
  }

  /// Whether a user holding [userRoles] sees any entry of the group [groupId].
  ///
  /// A group is visible exactly when one of its features is - there is nothing
  /// to configure per group.
  bool isGroupVisible(Object groupId, Iterable<R> userRoles) {
    final assigned = userRoles.toSet();
    return modules.any(
      (module) =>
          module.group == groupId && module.navigation != null && accessFor(module.id).allowsNavigation(assigned),
    );
  }

  /// The features declared under the group [groupId], in module order.
  List<F> featuresInGroup(Object groupId) =>
      List.unmodifiable(modules.where((module) => module.group == groupId).map((module) => module.id));

  /// Whether a user holding [userRoles] sees [feature] in the navigation.
  bool isNavigationVisible(F feature, Iterable<R> userRoles) => accessFor(feature).allowsNavigation(userRoles);

  /// Whether a user holding [userRoles] may perform [operation] on [feature].
  bool isAllowed(F feature, CrudOperation operation, Iterable<R> userRoles) =>
      accessFor(feature).allows(operation, userRoles);

  /// Everything a user holding [userRoles] may do with [feature].
  ///
  /// Hand this to a form or a list so it can hide the buttons it must not
  /// offer, instead of asking one question per button.
  Set<CrudOperation> allowedOperations(F feature, Iterable<R> userRoles) => accessFor(feature).operationsFor(userRoles);

  /// The features a user holding [userRoles] may read.
  List<F> readableFeatures(Iterable<R> userRoles) {
    final assigned = userRoles.toSet();
    return List.unmodifiable(<F>[
      for (final module in modules)
        if (accessFor(module.id).allows(CrudOperation.read, assigned)) module.id,
    ]);
  }

  @override
  String toString() => 'FeatureRegistry(${features.join(', ')})';
}
