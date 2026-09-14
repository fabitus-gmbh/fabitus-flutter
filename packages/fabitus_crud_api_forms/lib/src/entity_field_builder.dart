import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:flutter/widgets.dart';

import 'crud_form_scope.dart';
import 'entity_field.dart';

/// What one field needs to render itself, and how it writes back.
///
/// Handed to your field builder, so your own text field, dropdown or date picker
/// can be bound to an entity without knowing anything about cubits.
class EntityFieldState<V> {
  /// Creates the state. Built for you by [EntityFieldBuilder].
  const EntityFieldState({
    required this.value,
    required this.readOnly,
    required this.isLoading,
    required this.onChanged,
    required this.onSaved,
    this.violation,
  });

  /// The current value on the draft.
  final V? value;

  /// Whether the field must not be edited - the user may not, or a write is
  /// running.
  final bool readOnly;

  /// Whether the entity has not arrived yet, so there is nothing to show.
  ///
  /// The moment for a skeleton, if your design system has one.
  final bool isLoading;

  /// The backend's complaint about this field, or `null`.
  final CrudViolation? violation;

  /// Writes a new value into the draft. For a field that reports as it is typed.
  final ValueChanged<V?> onChanged;

  /// Writes a new value into the draft when the form is saved.
  ///
  /// Pass it to a [FormField.onSaved] for a field that only reports on submit;
  /// `CrudForm` runs `save()` before validating, so the draft is current by the
  /// time anything is checked.
  final ValueChanged<V?> onSaved;

  /// The backend's message for this field, ready for an `errorText`.
  String? get errorText => violation?.message;

  /// Whether the backend complained about this field.
  bool get hasError => violation != null;
}

/// Binds one [EntityField] to the enclosing `CrudForm`.
///
/// The builder gets the current value, whether it may be edited, the backend's
/// complaint about this field, and two ways to write back. What it returns is
/// entirely yours:
///
/// ```dart
/// EntityFieldBuilder<Todo, String>(
///   field: titleField,
///   builder: (context, field) => TextFormField(
///     initialValue: field.value,
///     readOnly: field.readOnly,
///     decoration: InputDecoration(labelText: 'Title', errorText: field.errorText),
///     onChanged: field.onChanged,
///     validator: (value) => value!.isEmpty ? 'Required' : null,
///   ),
/// );
/// ```
///
/// Wrap it once per field type and the rest of the app writes
/// `TodoTextField(field: titleField, label: 'Title')` - see the README.
class EntityFieldBuilder<T extends CrudEntity<Object>, V> extends StatelessWidget {
  /// Binds [field] and hands the result to [builder].
  const EntityFieldBuilder({required this.field, required this.builder, this.readOnly = false, super.key});

  /// Which property of the entity this is.
  final EntityField<T, V> field;

  /// Builds the widget the user sees.
  final Widget Function(BuildContext context, EntityFieldState<V> state) builder;

  /// Forces this one field read only, whatever the form says.
  ///
  /// For a property the backend computes, or one that may only be set while
  /// creating.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final form = CrudFormScope.of<T>(context);
    return builder(
      context,
      EntityFieldState<V>(
        value: form.valueOf(field),
        readOnly: readOnly || !form.canEdit || form.isBusy,
        isLoading: form.isLoading,
        violation: form.violationFor(field.name),
        onChanged: (value) => form.setValue(field, value),
        onSaved: (value) => form.setValue(field, value),
      ),
    );
  }
}
