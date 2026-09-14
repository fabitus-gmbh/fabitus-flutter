import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter/widgets.dart';

import 'entity_field.dart';

/// Everything below a `CrudForm` can ask about the entity being edited, and
/// everything it can do to it.
///
/// Published by `CrudForm` and read with [of], which registers the caller for a
/// rebuild - so a widget that reads [isDirty] rebuilds when the draft changes,
/// and one that reads nothing does not.
///
/// ```dart
/// final form = CrudFormScope.of<Todo>(context);
///
/// FilledButton(
///   onPressed: form.save,                    // null when there is nothing to save
///   child: Text(form.isBusy ? 'Saving...' : 'Save'),
/// );
/// ```
///
/// Only the entity type appears here, not its id type: a form is declared once
/// with both, and the dozens of fields under it should not have to repeat the
/// second.
class CrudFormScope<T extends CrudEntity<Object>> extends InheritedWidget {
  /// Publishes [state] to the subtree. Built for you by `CrudForm`.
  const CrudFormScope({
    required this.state,
    required this.canEdit,
    required this.canDelete,
    required this.edit,
    required this.save,
    required this.reset,
    required this.delete,
    required super.child,
    super.key,
  });

  /// Finds the enclosing form.
  ///
  /// Throws a [FlutterError] naming the missing widget rather than returning
  /// `null`, because a field outside its form is a wiring mistake, not a state.
  static CrudFormScope<T> of<T extends CrudEntity<Object>>(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CrudFormScope<T>>();
    if (scope == null) {
      throw FlutterError(
        'No CrudFormScope<$T> found above this widget.\n'
        'Wrap the form in a CrudForm<$T, ...>, and check that the entity type '
        'matches: a CrudForm<Todo, String> publishes a CrudFormScope<Todo> and '
        'nothing else.',
      );
    }
    return scope;
  }

  /// The entity as the cubit has it: stored copy, draft, status, error.
  final EntityState<T> state;

  /// Whether the user may change anything. `false` makes every field read only.
  final bool canEdit;

  /// Whether the user may delete. `false` leaves [delete] `null`.
  final bool canDelete;

  /// Applies a change to the draft.
  final void Function(T Function(T draft) change) edit;

  /// Validates the form and writes the draft, or `null` when there is nothing to
  /// save, the user may not, or a write is already running.
  final VoidCallback? save;

  /// Throws the edits away, or `null` when there are none.
  final VoidCallback? reset;

  /// Deletes the entity, or `null` when it was never stored, the user may not,
  /// or a write is already running.
  final VoidCallback? delete;

  /// The entity as the store has it.
  T? get entity => state.entity;

  /// The entity as the form has it.
  T? get draft => state.draft;

  /// Whether the draft differs from what the store has.
  bool get isDirty => state.isDirty;

  /// Whether the draft has never been stored, so saving will create it.
  bool get isNew => state.isNew;

  /// Whether a read or a write is running.
  bool get isBusy => state.status.isBusy;

  /// Whether nothing has been read yet, so there is nothing to render.
  bool get isLoading => state.status.isInitial || (state.status.isBusy && !state.hasDraft);

  /// Whether the entity was deleted, so the screen can close itself.
  bool get isDeleted => state.isDeleted;

  /// What went wrong on the last operation, or `null`.
  CrudException? get error => state.error;

  /// Field level errors the backend reported, empty when there are none.
  List<CrudViolation> get violations => state.violations;

  /// The backend's error for one field, or `null`.
  CrudViolation? violationFor(String name) => state.violationFor(name);

  /// The current value of [field] on the draft.
  V? valueOf<V>(EntityField<T, V> field) {
    final draft = state.draft;
    return draft == null ? null : field.read(draft);
  }

  /// Writes [value] into the draft through [field].
  void setValue<V>(EntityField<T, V> field, V? value) => edit((draft) => field.write(draft, value));

  @override
  bool updateShouldNotify(CrudFormScope<T> oldWidget) =>
      oldWidget.state != state ||
      oldWidget.canEdit != canEdit ||
      oldWidget.canDelete != canDelete ||
      // The callbacks flip between null and non-null as the state moves, which
      // is what a disabled button watches.
      (oldWidget.save == null) != (save == null) ||
      (oldWidget.reset == null) != (reset == null) ||
      (oldWidget.delete == null) != (delete == null);
}
