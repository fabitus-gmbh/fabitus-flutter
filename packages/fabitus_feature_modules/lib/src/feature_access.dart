import 'package:freezed_annotation/freezed_annotation.dart';

import 'crud_operation.dart';

part 'feature_access.freezed.dart';

/// Which roles may do what with one feature.
///
/// [R] is whatever your app calls a role - a Cognito group, a Keycloak realm
/// role, a plain [String]. A user holds a set of them; a role grants an
/// operation when it appears in that operation's set.
///
/// Deny by default: an empty set grants nothing, so `const FeatureAccess<Role>()`
/// - every set left at its default - locks the feature completely, which
/// [isDenied] reports. That is deliberate: the fallback path when a backend
/// sends no config for a feature should not be "everyone may do everything".
///
/// ```dart
/// const FeatureAccess<Role>(
///   navigation: {Role.editor, Role.admin},
///   read: {Role.editor, Role.admin},
///   create: {Role.admin},
///   update: {Role.admin},
///   delete: {Role.admin},
/// );
/// ```
@Freezed(fromJson: false, toJson: false)
abstract class FeatureAccess<R extends Object> with _$FeatureAccess<R> {
  /// Grants each operation to the roles listed for it.
  const factory FeatureAccess({
    /// Roles that see the feature's entry in the navigation.
    ///
    /// Kept apart from [read] on purpose: a feature can be reachable by a
    /// deep link for a role that should not be advertised the module.
    @Default(<Never>{}) Set<R> navigation,

    /// Roles that may create.
    @Default(<Never>{}) Set<R> create,

    /// Roles that may read.
    @Default(<Never>{}) Set<R> read,

    /// Roles that may update.
    @Default(<Never>{}) Set<R> update,

    /// Roles that may delete.
    @Default(<Never>{}) Set<R> delete,
  }) = _FeatureAccess<R>;

  const FeatureAccess._();

  /// Grants every operation, and the navigation entry, to [roles].
  ///
  /// Useful for tests and for an app whose features are not gated per operation.
  factory FeatureAccess.uniform(Set<R> roles) =>
      FeatureAccess<R>(navigation: roles, create: roles, read: roles, update: roles, delete: roles);

  /// Reads one entry of a backend's access configuration.
  ///
  /// Each key holds a list of role names; a missing or non-list value yields an
  /// empty set rather than an error, so one malformed operation does not cost
  /// the whole config. [roleFromJson] returns `null` for a name this app does
  /// not know, and unknown names are dropped - a role nobody holds must not end
  /// up granting anything.
  factory FeatureAccess.fromJson(Map<String, dynamic> json, R? Function(String name) roleFromJson) {
    Set<R> roles(String key) {
      final value = json[key];
      if (value is! List) return const {};
      return {
        for (final name in value.whereType<String>())
          if (roleFromJson(name) case final R role) role,
      };
    }

    return FeatureAccess<R>(
      navigation: roles('navigation'),
      create: roles('create'),
      read: roles('read'),
      update: roles('update'),
      delete: roles('delete'),
    );
  }

  /// The roles granted [operation].
  Set<R> rolesFor(CrudOperation operation) => switch (operation) {
    CrudOperation.create => create,
    CrudOperation.read => read,
    CrudOperation.update => update,
    CrudOperation.delete => delete,
  };

  /// Whether any of [userRoles] is granted [operation].
  bool allows(CrudOperation operation, Iterable<R> userRoles) {
    final assigned = userRoles.toSet();
    return rolesFor(operation).any(assigned.contains);
  }

  /// Whether any of [userRoles] sees the navigation entry.
  bool allowsNavigation(Iterable<R> userRoles) {
    final assigned = userRoles.toSet();
    return navigation.any(assigned.contains);
  }

  /// Everything [userRoles] may do, as a set to test against.
  Set<CrudOperation> operationsFor(Iterable<R> userRoles) {
    final assigned = userRoles.toSet();
    return {
      for (final operation in CrudOperation.values)
        if (rolesFor(operation).any(assigned.contains)) operation,
    };
  }

  /// Whether this grants nothing at all.
  bool get isDenied => navigation.isEmpty && create.isEmpty && read.isEmpty && update.isEmpty && delete.isEmpty;

  /// Every role named anywhere in this configuration.
  Set<R> get allRoles => {...navigation, ...create, ...read, ...update, ...delete};
}

/// Reads a backend's whole access configuration into a map.
///
/// [json] is the decoded response: a list of objects, each naming its feature
/// under [featureKey] and carrying the role lists that [FeatureAccess.fromJson]
/// reads. A `Map` keyed by feature name is accepted too, since backends spell
/// this both ways.
///
/// Entries naming a feature this app does not know are skipped - a new module on
/// the server must not break an older client.
///
/// ```dart
/// final access = parseFeatureAccess<Feature, Role>(
///   await api.getAccessRightConfig(),
///   featureFromJson: Feature.tryParse,
///   roleFromJson: Role.tryParse,
/// );
/// ```
Map<F, FeatureAccess<R>> parseFeatureAccess<F extends Object, R extends Object>(
  Object? json, {
  required F? Function(String name) featureFromJson,
  required R? Function(String name) roleFromJson,
  String featureKey = 'feature',
}) {
  final entries = switch (json) {
    final List<dynamic> list => [
      for (final item in list.whereType<Map<String, dynamic>>())
        if (item[featureKey] case final String name) (name, item),
    ],
    final Map<String, dynamic> map => [
      for (final entry in map.entries)
        if (entry.value case final Map<String, dynamic> item) (entry.key, item),
    ],
    _ => const <(String, Map<String, dynamic>)>[],
  };

  return {
    for (final (name, item) in entries)
      if (featureFromJson(name) case final F feature) feature: FeatureAccess<R>.fromJson(item, roleFromJson),
  };
}
