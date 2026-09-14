import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'crud_form_scope.dart';

/// Asks the user whether to throw unsaved edits away. `true` discards them.
typedef DiscardConfirmation = Future<bool> Function(BuildContext context);

/// The [Form] around one entity, wired to an [EntityCubit].
///
/// It owns the four things every edit screen otherwise rebuilds by hand:
///
/// * the [FormState] key, so saving can run the validators first;
/// * the draft, so fields read and write one entity rather than a controller
///   each;
/// * the guard against leaving with unsaved edits;
/// * telling the screen when a write went through.
///
/// It draws nothing. There is no scaffold, no snackbar, no dialog and no
/// navigation in here - [onSaved], [onDeleted] and [onFailure] hand those back
/// to you, and [confirmDiscard] is your dialog.
///
/// ```dart
/// CrudForm<Todo, String>(
///   canEdit: registry.isAllowed(Feature.todos, CrudOperation.update, roles),
///   confirmDiscard: (context) => MyDiscardDialog.show(context),
///   onSaved: (todo) {
///     MySnackbar.success(context, 'Saved');
///     Navigator.of(context).pop();
///   },
///   onFailure: (error) => MySnackbar.warn(context, error.message),
///   child: ListView(children: [titleField, doneField, actions]),
/// );
/// ```
///
/// The cubit comes from the enclosing [BlocProvider] unless one is passed.
class CrudForm<T extends CrudEntity<ID>, ID extends Object> extends StatefulWidget {
  /// Wires [child] to [cubit], or to the one in the enclosing provider.
  const CrudForm({
    required this.child,
    this.cubit,
    this.canEdit = true,
    this.canDelete = true,
    this.confirmDiscard,
    this.onSaved,
    this.onDeleted,
    this.onFailure,
    this.autovalidateMode,
    super.key,
  });

  /// The form's contents: fields, actions, anything.
  final Widget child;

  /// The cubit to drive. Read from the enclosing provider when omitted.
  final EntityCubit<T, ID>? cubit;

  /// Whether the user may change anything.
  ///
  /// `false` makes every field below read only and leaves
  /// [CrudFormScope.save] `null`. Where the answer comes from is your business -
  /// `fabitus_feature_modules` answers it per feature and role, and this package
  /// does not depend on it.
  final bool canEdit;

  /// Whether the user may delete. `false` leaves [CrudFormScope.delete] `null`.
  final bool canDelete;

  /// Asked before leaving with unsaved edits; `true` discards them.
  ///
  /// `null` - the default - lets the route pop without asking. There is no
  /// built-in dialog on purpose: a confirmation is a design and a translation
  /// decision.
  ///
  /// **The guard only sees `maybePop`.** That is Flutter's rule, not this
  /// package's: the system back gesture, the [AppBar] back button and
  /// [Navigator.maybePop] consult [PopScope], while a plain [Navigator.pop]
  /// leaves regardless. So a back or cancel button of your own has to call
  /// `Navigator.maybePop(context)`, or it will silently throw the user's edits
  /// away. A test in this package pins both behaviours.
  final DiscardConfirmation? confirmDiscard;

  /// Called after a write went through, with the entity as the store has it.
  final void Function(T entity)? onSaved;

  /// Called after the entity was deleted.
  final VoidCallback? onDeleted;

  /// Called when a read or a write failed.
  ///
  /// Field level problems reach the fields themselves through
  /// [CrudFormScope.violationFor]; this is for the message that belongs to the
  /// screen.
  final void Function(CrudException error)? onFailure;

  /// Passed to the underlying [Form].
  final AutovalidateMode? autovalidateMode;

  @override
  State<CrudForm<T, ID>> createState() => _CrudFormState<T, ID>();
}

class _CrudFormState<T extends CrudEntity<ID>, ID extends Object> extends State<CrudForm<T, ID>> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  EntityCubit<T, ID> _cubit(BuildContext context) => widget.cubit ?? context.read<EntityCubit<T, ID>>();

  /// Runs the field validators, then writes.
  ///
  /// `save()` first, so a field that pushes its value on `onSaved` rather than
  /// on every keystroke has put it into the draft before anything is checked.
  void _save(BuildContext context) {
    final form = _formKey.currentState;
    form?.save();
    if (form != null && !form.validate()) return;
    _cubit(context).save();
  }

  Future<void> _onPop(BuildContext context, EntityState<T> state) async {
    final navigator = Navigator.of(context);
    final confirm = widget.confirmDiscard;
    if (confirm == null || !state.isDirty || state.isDeleted) {
      navigator.pop();
      return;
    }
    if (await confirm(context)) navigator.pop();
  }

  void _onStateChanged(BuildContext context, EntityState<T> state) {
    switch (state.status) {
      case EntityStatus.success when state.isDeleted:
        widget.onDeleted?.call();
      case EntityStatus.success when state.action == EntityAction.save && state.entity != null:
        widget.onSaved?.call(state.entity as T);
      case EntityStatus.failure when state.error != null:
        widget.onFailure?.call(state.error!);
      case _:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = widget.cubit;
    return BlocConsumer<EntityCubit<T, ID>, EntityState<T>>(
      bloc: cubit,
      // Only the transitions worth announcing: a status that stayed the same
      // means an edit, not an outcome.
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.action != current.action ||
          previous.isDeleted != current.isDeleted,
      listener: _onStateChanged,
      builder: (context, state) {
        final canSave = widget.canEdit && state.hasDraft && !state.status.isBusy;
        final canDelete = widget.canDelete && !state.isNew && !state.status.isBusy && !state.isDeleted;

        return CrudFormScope<T>(
          state: state,
          canEdit: widget.canEdit,
          canDelete: widget.canDelete,
          edit: (change) => _cubit(context).edit(change),
          save: canSave ? () => _save(context) : null,
          reset: state.isDirty ? _cubit(context).reset : null,
          delete: canDelete ? _cubit(context).delete : null,
          child: PopScope(
            canPop: widget.confirmDiscard == null,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _onPop(context, state);
            },
            child: Form(key: _formKey, autovalidateMode: widget.autovalidateMode, child: widget.child),
          ),
        );
      },
    );
  }
}
