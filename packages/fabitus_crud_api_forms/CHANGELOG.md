# Changelog

## 0.1.0

Initial release. Generalised from the Toolbox's CRUD form widgets, with the
design system taken out.

- `EntityField`, binding one form field to one property: its name - matched
  against a `CrudViolation` so the backend's complaint lands on the right field -
  plus how to read it and how to write it back immutably.
- `EntityField.ofSubtype` for a property that only one variant of a sealed entity
  has. The cast lives in one place and is total: reading the wrong variant gives
  `null`, writing leaves it alone, nothing throws.
- `CrudForm`, the `Form` around an `EntityCubit`: owns the form key, runs the
  validators before saving, guards against leaving with unsaved edits, and hands
  outcomes back through `onSaved`, `onDeleted` and `onFailure`.
- `CrudFormScope`, what everything below the form reads - draft, dirty flag,
  violations - and the save, reset and delete actions, each `null` when it is not
  available.
- `EntityFieldBuilder`, handing a field widget its value, its read-only state,
  its skeleton flag, the backend's message for that property, and two writers.
- Nothing imports `material.dart`, so none of it can acquire a look by accident.
