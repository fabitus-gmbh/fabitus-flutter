import 'feature_access.dart';

/// One feature of an app, declared in one place.
///
/// A module says what it is called, what routes it contributes and what its
/// entry in the navigation looks like. What it deliberately does *not* say is
/// who may use it: access rights come from the backend at runtime and are held
/// by the [FeatureRegistry], so a module stays a `const` value that can be
/// constructed in a test without a logged in user.
///
/// The four type parameters are the four things only your app can decide:
///
/// * [F] - how features are identified, usually an `enum`, so a `switch` over
///   them is exhaustive.
/// * [R] - what a role is: a Cognito group, a realm role, a [String].
/// * [TRoute] - your router's route type. Nothing here knows about `go_router`;
///   `RouteBase` is simply what [TRoute] happens to be in a `go_router` app.
/// * [TNav] - whatever your navigation is built from, typically a `Widget`.
///
/// Name them once and every declaration downstream reads plainly:
///
/// ```dart
/// typedef AppModule = FeatureModule<Feature, Role, RouteBase, Widget>;
///
/// class TodoModule extends AppModule {
///   const TodoModule();
///
///   @override
///   Feature get id => Feature.todos;
///
///   @override
///   List<RouteBase> get routes => [
///     GoRoute(path: '/todos', builder: (_, _) => const TodoListPage()),
///     GoRoute(path: '/todos/:id', builder: (_, state) =>
///         TodoEditPage(id: state.pathParameters['id']!)),
///   ];
///
///   @override
///   Widget? get navigation => const NavigationItem(
///     icon: Icon(Icons.check_box_outlined),
///     label: 'Todos',
///     target: '/todos',
///   );
/// }
/// ```
abstract class FeatureModule<F extends Object, R extends Object, TRoute, TNav> {
  /// Creates a module.
  const FeatureModule();

  /// What this feature is called, and the key its access rights arrive under.
  ///
  /// Unique across the registry; [FeatureRegistry] rejects a duplicate.
  F get id;

  /// The routes this feature contributes, in the order they should be added.
  ///
  /// Return an empty list for a feature that has no pages of its own.
  List<TRoute> get routes;

  /// This feature's entry in the navigation, or `null` when it has none.
  ///
  /// Nothing here says where that navigation is: a bar across the top, a rail
  /// or drawer down the side, a command palette. [TNav] is whatever your app
  /// builds it from, and the registry only decides *which* entries a given user
  /// gets - see [FeatureRegistry.navigationFor].
  TNav? get navigation => null;

  /// The group this feature's entry appears under, or `null` for a feature that
  /// sits at the top level.
  ///
  /// Identified by equality, so an `enum` of the app's own is the natural
  /// choice, and every group used has to be declared on the
  /// [FeatureRegistry] - which is where a typo is caught.
  ///
  /// ```dart
  /// @override
  /// Object? get group => NavGroup.data;
  /// ```
  Object? get group => null;

  /// The access rights to use while the backend sends none for this feature.
  ///
  /// A module that ships before the server knows about it would otherwise be
  /// locked for everyone. Spell out the rights it should have in the meantime
  /// and they are dropped the day the backend starts sending its own - no
  /// special case anywhere else.
  ///
  /// `null`, the default, means a feature the backend does not know is denied.
  FeatureAccess<R>? get fallbackAccess => null;

  @override
  String toString() => '$runtimeType($id)';
}
