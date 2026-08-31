import 'package:collection/collection.dart';

import 'crud_operation.dart';
import 'feature_access.dart';
import 'feature_module.dart';

/// The modules an app is built from, together with the access rights that
/// arrived for them.
///
/// One instance answers the three questions the rest of the app has: what
/// routes exist, what navigation this user sees, and what this user may do.
///
/// ```dart
/// final registry = FeatureRegistry<Feature, Role, RouteBase, Widget>(
///   modules: const [RssModule(), TaxonomyModule()],
///   access: parseFeatureAccess(
///     await api.getAccessRightConfig(),
///     featureFromJson: Feature.tryParse,
///     roleFromJson: Role.tryParse,
///   ),
/// );
///
/// GoRouter(routes: registry.routes);
/// Row(children: registry.navigationFor(user.roles));
/// if (registry.isAllowed(Feature.rss, CrudOperation.delete, user.roles)) ...
/// ```
///
/// Access is resolved once, at construction: what the backend sent, else the
/// module's [FeatureModule.fallbackAccess], else nothing at all. Build a new
/// registry when the configuration is reloaded.
class FeatureRegistry<F extends Object, R extends Object, TRoute, TNav> {
  /// Collects [modules] and resolves their access rights against [access].
  ///
  /// Throws [ArgumentError] when two modules claim the same
  /// [FeatureModule.id] - the lookups here would silently favour one of them.
  FeatureRegistry({
    required Iterable<FeatureModule<F, R, TRoute, TNav>> modules,
    Map<F, FeatureAccess<R>> access = const {},
  }) : modules = List.unmodifiable(modules) {
    final duplicate = this.modules
        .map((module) => module.id)
        .groupFoldBy<F, int>((id) => id, (count, _) => (count ?? 0) + 1)
        .entries
        .firstWhereOrNull((entry) => entry.value > 1);
    if (duplicate != null) {
      throw ArgumentError.value(modules, 'modules', 'More than one module claims the feature ${duplicate.key}');
    }
    _access = {
      for (final module in this.modules) module.id: access[module.id] ?? module.fallbackAccess ?? FeatureAccess<R>(),
    };
  }

  /// The modules, in the order they were given.
  final List<FeatureModule<F, R, TRoute, TNav>> modules;

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
  /// order.
  ///
  /// Modules without a [FeatureModule.navigation] and modules whose navigation
  /// this user is not granted are left out.
  List<TNav> navigationFor(Iterable<R> userRoles) {
    final assigned = userRoles.toSet();
    return List.unmodifiable(<TNav>[
      for (final module in modules)
        if (module.navigation case final TNav entry)
          if (accessFor(module.id).allowsNavigation(assigned)) entry,
    ]);
  }

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
