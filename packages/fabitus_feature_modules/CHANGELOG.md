# Changelog

## 0.1.0

Initial release.

- `FeatureModule`, a constant declaration of one feature: its id, its routes and
  its navigation entry. Generic over the feature id, the role, the route type
  and the navigation type, so no router or widget toolkit is a dependency.
- `FeatureAccess`, which roles are granted which `CrudOperation` and the
  navigation entry, as a `freezed` value type. Denies by default.
- `parseFeatureAccess`, reading a backend's configuration from a list or a map,
  skipping features and roles this build does not know.
- `FeatureRegistry`, resolving each module's rights - backend, else the module's
  `fallbackAccess`, else denied - and answering what routes exist, what
  navigation a user sees and what a user may do.
