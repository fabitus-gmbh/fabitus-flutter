/// Forms over `fabitus_crud_api` entities, with the design left to you.
///
/// Four pieces:
///
/// * [EntityField] binds one form field to one property of an entity - its
///   name, how to read it, how to write it back.
/// * [CrudForm] is the [Form] around an `EntityCubit`: it owns the form key, the
///   draft, the guard against leaving with unsaved edits, and it tells the
///   screen when a write went through.
/// * [CrudFormScope] is what everything below the form reads - the draft, the
///   dirty flag, the backend's violations, and the save, reset and delete
///   actions, each `null` when it is not available.
/// * [EntityFieldBuilder] binds one field and hands your widget its value, its
///   error and its writer.
///
/// **Nothing here paints.** No scaffold, no snackbar, no dialog, no navigation
/// and no field widget: `CrudForm` hands outcomes back through callbacks, and
/// the confirmation before discarding edits is your dialog. It builds on
/// `package:flutter/widgets.dart`, not `material.dart`.
library;

export 'src/crud_form.dart';
export 'src/crud_form_scope.dart';
export 'src/entity_field.dart';
export 'src/entity_field_builder.dart';
