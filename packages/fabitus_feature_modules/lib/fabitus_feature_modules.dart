/// Declare an app's features as modules, and ask one registry what the current
/// user may do with them.
///
/// A [FeatureModule] carries a feature's routes and its navigation entry; a
/// [FeatureAccess] says which roles are granted which [CrudOperation]; a
/// [FeatureRegistry] holds both and answers the questions the rest of the app
/// has. Nothing here knows about a router, a widget toolkit or an
/// authentication provider - those are type parameters you fill in.
///
/// See the README for wiring recipes, including `go_router`.
library;

export 'src/crud_operation.dart';
export 'src/feature_access.dart';
export 'src/feature_module.dart';
export 'src/feature_registry.dart';
