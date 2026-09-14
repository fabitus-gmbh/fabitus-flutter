// An edit form and a create form, with a deliberately plain look - every pixel
// below comes from this file, not from the package.
//
// Like the other Flutter packages here it has no `dart run`: widgets need a host
// app. It is analyzed as part of the package, so it cannot rot, and the widget
// tests in `test/` exercise the same paths headlessly.
import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:fabitus_crud_api_forms/fabitus_crud_api_forms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  final repository = InMemoryCrudRepository<Todo, String>(
    withId: (todo, id) => todo.copyWith(id: id),
    initial: const [
      Todo(id: '1', title: 'Write the docs', priority: Priority.high),
      Todo(id: '2', title: 'Review the PR'),
    ],
  );
  runApp(ExampleApp(repository: repository));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({required this.repository, super.key});

  final CrudRepository<Todo, String> repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: RepositoryProvider<CrudRepository<Todo, String>>.value(value: repository, child: const TodoListScreen()),
  );
}

/// The fields, declared once and reused by both forms.
const titleField = EntityField<Todo, String>(name: 'title', read: _readTitle, write: _writeTitle);
const doneField = EntityField<Todo, bool>(name: 'done', read: _readDone, write: _writeDone);
const priorityField = EntityField<Todo, Priority>(name: 'priority', read: _readPriority, write: _writePriority);

String? _readTitle(Todo todo) => todo.title;
Todo _writeTitle(Todo todo, String? value) => todo.copyWith(title: value ?? '');
bool? _readDone(Todo todo) => todo.done;
Todo _writeDone(Todo todo, bool? value) => todo.copyWith(done: value ?? false);
Priority? _readPriority(Todo todo) => todo.priority;
Todo _writePriority(Todo todo, Priority? value) => todo.copyWith(priority: value ?? Priority.normal);

class TodoListScreen extends StatelessWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CrudRepository<Todo, String>>();
    return BlocProvider<LoadCubit<List<Todo>>>(
      create: (_) => LoadCubit<List<Todo>>(repository.findAll, loadOnCreate: true),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Todos')),
          body: LoadBuilder<List<Todo>>(
            builder: (context, todos, {bool refreshing = false}) => ListView(
              children: [
                for (final todo in todos)
                  ListTile(
                    title: Text(todo.title),
                    subtitle: Text(todo.priority.name),
                    trailing: todo.done ? const Icon(Icons.check) : null,
                    onTap: () => _open(context, todo.id),
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _open(context, null),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, String? id) {
    final repository = context.read<CrudRepository<Todo, String>>();
    final list = context.read<LoadCubit<List<Todo>>>();

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TodoFormScreen(repository: repository, id: id),
          ),
        )
        .then((_) => list.refresh());
  }
}

class TodoFormScreen extends StatelessWidget {
  const TodoFormScreen({required this.repository, this.id, super.key});

  final CrudRepository<Todo, String> repository;

  /// `null` opens a create form.
  final String? id;

  @override
  Widget build(BuildContext context) => BlocProvider<EntityCubit<Todo, String>>(
    create: (_) {
      final cubit = EntityCubit<Todo, String>(
        repository,
        // A create form starts on a blank draft instead of loading.
        draft: id == null ? const Todo(title: '') : null,
      );
      if (id != null) cubit.load(id!);
      return cubit;
    },
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(id == null ? 'New todo' : 'Edit todo'),
          // maybePop, so the unsaved-edits guard actually runs. A plain pop
          // would leave without asking.
          leading: BackButton(onPressed: () => Navigator.maybePop(context)),
        ),
        body: CrudForm<Todo, String>(
          confirmDiscard: _confirmDiscard,
          onSaved: (todo) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved "${todo.title}"')));
            Navigator.of(context).pop();
          },
          onDeleted: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
            Navigator.of(context).pop();
          },
          onFailure: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TodoTextField(field: titleField, label: 'Title'),
                SizedBox(height: 16),
                TodoSwitchField(field: doneField, label: 'Done'),
                SizedBox(height: 16),
                TodoPriorityField(field: priorityField),
                Spacer(),
                TodoFormActions(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// The dialog is ours; the package only asks.
  Future<bool> _confirmDiscard(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep editing')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Discard')),
          ],
        ),
      ) ??
      false;
}

/// One wrapper per field type, and every form after this is a list of
/// one-liners.
class TodoTextField extends StatelessWidget {
  const TodoTextField({required this.field, required this.label, super.key});

  final EntityField<Todo, String> field;
  final String label;

  @override
  Widget build(BuildContext context) => EntityFieldBuilder<Todo, String>(
    field: field,
    builder: (context, state) => TextFormField(
      key: Key(field.name),
      initialValue: state.value,
      readOnly: state.readOnly,
      decoration: InputDecoration(
        labelText: label,
        // The backend's own message for this property.
        errorText: state.errorText,
      ),
      validator: (value) => (value ?? '').isEmpty ? 'Required' : null,
      onChanged: state.onChanged,
    ),
  );
}

class TodoSwitchField extends StatelessWidget {
  const TodoSwitchField({required this.field, required this.label, super.key});

  final EntityField<Todo, bool> field;
  final String label;

  @override
  Widget build(BuildContext context) => EntityFieldBuilder<Todo, bool>(
    field: field,
    builder: (context, state) => SwitchListTile(
      title: Text(label),
      subtitle: state.errorText == null ? null : Text(state.errorText!),
      value: state.value ?? false,
      onChanged: state.readOnly ? null : state.onChanged,
    ),
  );
}

class TodoPriorityField extends StatelessWidget {
  const TodoPriorityField({required this.field, super.key});

  final EntityField<Todo, Priority> field;

  @override
  Widget build(BuildContext context) => EntityFieldBuilder<Todo, Priority>(
    field: field,
    builder: (context, state) => DropdownButtonFormField<Priority>(
      initialValue: state.value,
      decoration: InputDecoration(labelText: 'Priority', errorText: state.errorText),
      items: Priority.values.map((priority) => DropdownMenuItem(value: priority, child: Text(priority.name))).toList(),
      onChanged: state.readOnly ? null : state.onChanged,
    ),
  );
}

/// Each action is null when it is not available, which is what a disabled
/// button wants.
class TodoFormActions extends StatelessWidget {
  const TodoFormActions({super.key});

  @override
  Widget build(BuildContext context) {
    final form = CrudFormScope.of<Todo>(context);
    return Row(
      children: [
        if (form.delete != null) TextButton(onPressed: form.delete, child: const Text('Delete')),
        const Spacer(),
        TextButton(onPressed: form.reset, child: const Text('Discard')),
        const SizedBox(width: 8),
        FilledButton(onPressed: form.save, child: Text(form.isBusy ? 'Saving...' : 'Save')),
      ],
    );
  }
}

enum Priority { low, normal, high }

class Todo implements CrudEntity<String> {
  const Todo({this.id, required this.title, this.done = false, this.priority = Priority.normal});

  @override
  final String? id;
  final String title;
  final bool done;
  final Priority priority;

  Todo copyWith({String? id, String? title, bool? done, Priority? priority}) =>
      Todo(id: id ?? this.id, title: title ?? this.title, done: done ?? this.done, priority: priority ?? this.priority);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done, 'priority': priority.name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo && other.id == id && other.title == title && other.done == done && other.priority == priority;

  @override
  int get hashCode => Object.hash(id, title, done, priority);
}
