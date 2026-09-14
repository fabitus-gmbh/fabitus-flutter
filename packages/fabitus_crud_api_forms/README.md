# fabitus_crud_api_forms

Forms over [`fabitus_crud_api`](../fabitus_crud_api) entities, driven by the
`EntityCubit` from [`fabitus_crud_api_bloc`](../fabitus_crud_api_bloc).

| Piece | Does |
| --- | --- |
| `EntityField` | binds one form field to one property: its name, how to read it, how to write it back |
| `CrudForm` | the `Form` around the entity: form key, draft, unsaved-edits guard, outcome callbacks |
| `CrudFormScope` | what everything below reads: the draft, the dirty flag, the violations, and save/reset/delete |
| `EntityFieldBuilder` | binds one field and hands your widget its value, its error and its writer |

**Nothing here paints.** No scaffold, no snackbar, no dialog, no navigation and
no field widget. `CrudForm` hands outcomes back through callbacks, the
confirmation before discarding edits is your dialog, and it builds on
`package:flutter/widgets.dart` rather than `material.dart`.

```dart
CrudForm<Todo, String>(
  onSaved: (todo) { MySnackbar.success(context, 'Saved'); Navigator.pop(context); },
  onFailure: (error) => MySnackbar.warn(context, error.message),
  child: Column(
    children: [
      EntityFieldBuilder<Todo, String>(
        field: titleField,
        builder: (context, field) => MyTextField(
          label: 'Title',
          value: field.value,
          readOnly: field.readOnly,
          errorText: field.errorText,     // the backend's own message
          onChanged: field.onChanged,
        ),
      ),
      const TodoFormActions(),
    ],
  ),
);
```

## Contents

- [Installation](#installation)
- [Guide 1: describing the fields](#guide-1-describing-the-fields)
- [Guide 2: the form](#guide-2-the-form)
- [Guide 3: binding a field widget](#guide-3-binding-a-field-widget)
- [Guide 4: save, reset and delete](#guide-4-save-reset-and-delete)
- [Guide 5: validation, local and from the backend](#guide-5-validation-local-and-from-the-backend)
- [Guide 6: leaving with unsaved edits](#guide-6-leaving-with-unsaved-edits)
- [Guide 7: permissions](#guide-7-permissions)
- [Guide 8: a field that only one variant has](#guide-8-a-field-that-only-one-variant-has)
- [Guide 9: bringing your design system](#guide-9-bringing-your-design-system)
- [Guide 10: testing](#guide-10-testing)
- [Design notes](#design-notes)

## Installation

```yaml
dependencies:
  fabitus_crud_api_forms:
    git:
      url: https://github.com/fabitus-gmbh/fabitus-flutter.git
      path: packages/fabitus_crud_api_forms
```

```dart
import 'package:fabitus_crud_api_forms/fabitus_crud_api_forms.dart';
```

It pulls in `fabitus_crud_api`, `fabitus_crud_api_bloc` and `flutter_bloc`. The
form drives an `EntityCubit<T, ID>`; create it with a `BlocProvider` or pass it
in.

## Guide 1: describing the fields

One `EntityField` per property, declared once and reused by every widget that
touches it:

```dart
const titleField = EntityField<Todo, String>(
  name: 'title',
  read: (todo) => todo.title,
  write: (todo, value) => todo.copyWith(title: value ?? ''),
);

const doneField = EntityField<Todo, bool>(
  name: 'done',
  read: (todo) => todo.done,
  write: (todo, value) => todo.copyWith(done: value ?? false),
);
```

The entity stays immutable - `write` returns a new one, which is what a
`freezed` `copyWith` does.

**`name` is what ties the field to the backend's answer.** A `CrudViolation`
naming `title` lands on that field and nowhere else, so spell it the way the
backend does. With `fabitus_crud_api_dio` those violations come out of an RFC
9457 body without anything to write.

## Guide 2: the form

```dart
BlocProvider(
  create: (_) => EntityCubit<Todo, String>(repository)..load(id),
  child: CrudForm<Todo, String>(
    onSaved: (todo) => Navigator.of(context).pop(todo),
    onDeleted: () => Navigator.of(context).pop(),
    onFailure: (error) => MySnackbar.warn(context, error.message),
    child: MyTodoFormBody(),
  ),
);
```

A create form starts on a blank draft instead of loading:

```dart
EntityCubit<Todo, String>(repository, draft: const Todo(title: ''));
```

Everything else is the same - `save()` creates when the draft has no id and
updates when it has one, so the form does not care which it is.

## Guide 3: binding a field widget

`EntityFieldBuilder` hands your widget the four things it needs:

```dart
EntityFieldBuilder<Todo, String>(
  field: titleField,
  builder: (context, field) => TextFormField(
    initialValue: field.value,
    readOnly: field.readOnly,
    decoration: InputDecoration(labelText: 'Title', errorText: field.errorText),
    onChanged: field.onChanged,
  ),
);
```

| On `field` | Is |
| --- | --- |
| `value` | the current value on the draft |
| `readOnly` | the user may not edit, or a write is running |
| `isLoading` | the entity has not arrived yet - the moment for a skeleton |
| `errorText` / `violation` | the backend's complaint about *this* property |
| `onChanged` | write back as the user types |
| `onSaved` | write back when the form is saved |

`onSaved` is for a field that only reports on submit: `CrudForm` runs the form's
`save()` before validating, so the draft is current by the time anything is
checked. A field that reports as it is typed uses `onChanged` and ignores the
other.

## Guide 4: save, reset and delete

Everything below the form can read its state and drive it:

```dart
class TodoFormActions extends StatelessWidget {
  const TodoFormActions({super.key});

  @override
  Widget build(BuildContext context) {
    final form = CrudFormScope.of<Todo>(context);
    return Row(
      children: [
        if (form.delete != null)
          MyDangerButton(onPressed: form.delete, label: 'Delete'),
        MySecondaryButton(onPressed: form.reset, label: 'Discard'),
        MyPrimaryButton(
          onPressed: form.save,
          label: form.isBusy ? 'Saving...' : 'Save',
        ),
      ],
    );
  }
}
```

**Each action is `null` when it is not available**, which is exactly what a
disabled button wants:

| Action | `null` when |
| --- | --- |
| `save` | there is no draft, the user may not edit, or a write is running |
| `reset` | nothing was changed |
| `delete` | the entity was never stored, the user may not, or a write is running |

`save` runs the validators first and does nothing if they fail. Reading
`CrudFormScope.of` registers the widget for a rebuild, so the buttons enable and
disable themselves.

## Guide 5: validation, local and from the backend

They are different things and both work:

```dart
EntityFieldBuilder<Todo, String>(
  field: titleField,
  builder: (context, field) => TextFormField(
    initialValue: field.value,
    // Checked before anything leaves the device.
    validator: (value) => (value ?? '').isEmpty ? 'Required' : null,
    // What the backend said about this property.
    decoration: InputDecoration(errorText: field.errorText),
    onChanged: field.onChanged,
  ),
);
```

A failed save **keeps the draft**, so nothing the user typed is lost, and the
violations land on their fields. Editing a field clears the error, so the
complaint disappears as soon as the user addresses it.

The message that belongs to the screen rather than to a field - "the server had a
problem" - arrives through `onFailure`.

## Guide 6: leaving with unsaved edits

```dart
CrudForm<Todo, String>(
  confirmDiscard: (context) => MyConfirmDialog.show(
    context,
    title: 'Discard changes?',
  ),
  child: ...,
);
```

Asked only when the form is actually dirty. The dialog is yours - a confirmation
is a design and a translation decision.

> **The guard only sees `maybePop`.** That is Flutter's rule: the system back
> gesture, the `AppBar` back button and `Navigator.maybePop` consult `PopScope`,
> while a plain `Navigator.pop` leaves regardless. A back or cancel button of
> your own has to call `Navigator.maybePop(context)`, or it will silently throw
> the edits away. Both behaviours are pinned by a test here.

## Guide 7: permissions

`canEdit` and `canDelete` are plain booleans, so where the answer comes from is
your business. With
[`fabitus_feature_modules`](../fabitus_feature_modules) - which this package does
not depend on:

```dart
final allowed = registry.allowedOperations(Feature.todos, user.roles);

CrudForm<Todo, String>(
  canEdit: allowed.contains(
    todo.id == null ? CrudOperation.create : CrudOperation.update,
  ),
  canDelete: allowed.contains(CrudOperation.delete),
  child: ...,
);
```

`canEdit: false` makes every field below read only and leaves `save` `null`;
nothing else has to know.

## Guide 8: a field that only one variant has

A sealed entity - a page that is either a dossier or an article - has properties
that belong to one variant. Declaring those against the union means casting in
every accessor, and a wrong cast throws while the user is typing:

```dart
final dossierId = EntityField.ofSubtype<DossierPage, Page, String>(
  name: 'dossierId',
  read: (page) => page.dossierId,
  write: (page, value) => page.copyWith(dossierId: value),
);
```

The cast lives in one place and is total: on the wrong variant, reading gives
`null` and writing leaves the entity alone. Nothing throws.

## Guide 9: bringing your design system

Wrap each field type once, and every form after that is a list of one-liners:

```dart
class AcmeTextField<T extends CrudEntity<Object>> extends StatelessWidget {
  const AcmeTextField({
    required this.field,
    required this.label,
    this.validator,
    this.maxLines = 1,
    super.key,
  });

  final EntityField<T, String> field;
  final String label;
  final FormFieldValidator<String>? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) => EntityFieldBuilder<T, String>(
    field: field,
    builder: (context, state) => AcmeInput(
      label: label,
      value: state.value,
      readOnly: state.readOnly,
      skeleton: state.isLoading,
      errorText: state.errorText,
      maxLines: maxLines,
      validator: validator,
      onChanged: state.onChanged,
    ),
  );
}
```

```dart
AcmeTextField<Todo>(field: titleField, label: 'Title'),
AcmeSwitchField<Todo>(field: doneField, label: 'Done'),
AcmeSelectField<Todo, Priority>(field: priorityField, label: 'Priority', options: ...),
```

Pairs with [`fabitus_crud_api_views`](../fabitus_crud_api_views), which does the
same for lists and tables: one wrapper per design decision, written once.

## Guide 10: testing

The form needs nothing but a cubit, and `fabitus_crud_api` ships an in-memory
repository to feed it:

```dart
final repository = InMemoryCrudRepository<Todo, String>(
  withId: (todo, id) => todo.copyWith(id: id),
  initial: const [Todo(id: '1', title: 'Write docs')],
);
final cubit = EntityCubit<Todo, String>(repository)..load('1');

await tester.pumpWidget(
  MaterialApp(home: CrudForm<Todo, String>(cubit: cubit, child: MyFormBody())),
);
await tester.enterText(find.byKey(const Key('title')), 'Renamed');
await tester.tap(find.text('Save'));
await tester.pumpAndSettle();

expect(cubit.state.entity?.title, 'Renamed');
```

To exercise the violation path, make the repository fail with a
`CrudValidationException` carrying the violations - see
[`test/support/todo.dart`](test/support/todo.dart).

## Design notes

**Why does the scope name only the entity type?** A form is declared once with
`<T, ID>`, and the dozens of fields under it should not have to repeat the second
parameter. `CrudForm<Todo, String>` publishes a `CrudFormScope<Todo>`, and
`EntityFieldBuilder<Todo, String>` is `<entity, value>` rather than
`<entity, id, value>`.

**Why an `InheritedWidget` and not a `BlocBuilder` per field?** Because a field
should rebuild when the draft changes and not when anything else does, and
`dependOnInheritedWidgetOfExactType` gives exactly that without every field
knowing which cubit it is reading.

**Why no snackbar, dialog or navigation?** They are the three things every app
does differently, and two of them need translating. `onSaved`, `onDeleted`,
`onFailure` and `confirmDiscard` hand all four decisions back.

**Why no built-in validators?** A `required` validator needs a message, and a
message needs a locale. Flutter's `validator` is already the right hook, and your
app already has the strings.

**Why does a field outside a form throw?** Because it is a wiring mistake, not a
state a widget can render. The message names the type that is missing, which is
usually a mismatched entity type rather than a missing form.

## License

[MIT](LICENSE) © Fabitus GmbH.
