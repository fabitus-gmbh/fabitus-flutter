// The three cubits on three screens: a list, a paged table and an edit form.
//
// Unlike the other packages here, this one cannot offer `dart run` - Flutter
// widgets need a host app. The file is analyzed as part of the package, so it
// cannot rot; copy it into an app to see it move. The widget tests in `test/`
// run the same paths headlessly.
import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  // In a real app this is a RemotePagingCrudRepository over your retrofit client,
  // with the error mapper from fabitus_crud_api_dio. Swapping it for the in
  // memory one is all it takes to run the whole app on a fake.
  final repository = InMemoryCrudRepository<Todo, String>(
    withId: (todo, id) => todo.copyWith(id: id),
    initial: const [
      Todo(id: '1', title: 'Write the docs'),
      Todo(id: '2', title: 'Review the PR'),
    ],
  );

  runApp(ExampleApp(repository: repository));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({required this.repository, super.key});

  final PagingCrudRepository<Todo, String> repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: RepositoryProvider<PagingCrudRepository<Todo, String>>.value(
      value: repository,
      child: const TodoListScreen(),
    ),
  );
}

/// Show one thing: LoadCubit plus LoadBuilder, and the screen is done.
class TodoListScreen extends StatelessWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<PagingCrudRepository<Todo, String>>();

    return BlocProvider<LoadCubit<List<Todo>>>(
      create: (_) => LoadCubit<List<Todo>>(repository.findAll, loadOnCreate: true),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Todos'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                // Keeps the list on screen while it reloads.
                onPressed: context.read<LoadCubit<List<Todo>>>().refresh,
              ),
            ],
          ),
          body: LoadBuilder<List<Todo>>(
            builder: (context, todos, {bool refreshing = false}) => Column(
              children: [
                if (refreshing) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    children: [
                      for (final todo in todos)
                        ListTile(title: Text(todo.title), onTap: () => _openForm(context, todo)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openForm(context, null),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, Todo? todo) {
    final repository = context.read<PagingCrudRepository<Todo, String>>();
    final list = context.read<LoadCubit<List<Todo>>>();

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TodoFormScreen(repository: repository, todo: todo),
          ),
        )
        // Whatever happened in the form, the list may be stale now.
        .then((_) => list.refresh());
  }
}

/// Edit one thing: EntityCubit holds the draft, the errors and the dirty flag.
class TodoFormScreen extends StatelessWidget {
  const TodoFormScreen({required this.repository, this.todo, super.key});

  final CrudRepository<Todo, String> repository;
  final Todo? todo;

  @override
  Widget build(BuildContext context) => BlocProvider<EntityCubit<Todo, String>>(
    // No id means a create form: start on a blank draft.
    create: (_) => EntityCubit<Todo, String>(repository, draft: todo ?? const Todo(title: '')),
    child: BlocConsumer<EntityCubit<Todo, String>, EntityState<Todo>>(
      // Close the screen once the write went through.
      listener: (context, state) {
        if (state.status.isSuccess && (state.isDeleted || (state.action == EntityAction.save && !state.isDirty))) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final cubit = context.read<EntityCubit<Todo, String>>();
        return Scaffold(
          appBar: AppBar(
            title: Text(state.isNew ? 'New todo' : 'Edit todo'),
            actions: [
              if (!state.isNew)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: state.status.isBusy ? null : cubit.delete,
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: state.draft?.title,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    // The backend's own message for this field.
                    errorText: state.violationFor('title')?.message,
                  ),
                  onChanged: (value) => cubit.edit((todo) => todo.copyWith(title: value)),
                ),
                const SizedBox(height: 16),
                if (state.status.isFailure && state.violations.isEmpty) CrudErrorView(error: state.error!),
                const Spacer(),
                FilledButton(
                  onPressed: state.status.isBusy || !state.isDirty ? null : cubit.save,
                  child: Text(state.status.isBusy ? 'Saving...' : 'Save'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Page through a collection: one cubit serves a table and an endless scroll.
class TodoTableScreen extends StatelessWidget {
  const TodoTableScreen({required this.repository, super.key});

  final PagingCrudRepository<Todo, String> repository;

  @override
  Widget build(BuildContext context) => BlocProvider<PaginationCubit<Todo, void>>(
    create: (_) => PaginationCubit<Todo, void>(
      loadPage: (request, _) => repository.findPage(request),
      initialRequest: OffsetPageRequest(size: 20, sort: Sort.by('title')),
      initialFilter: null,
      loadOnCreate: true,
    ),
    child: BlocBuilder<PaginationCubit<Todo, void>, PaginationState<Todo, void>>(
      builder: (context, state) {
        final cubit = context.read<PaginationCubit<Todo, void>>();
        return Scaffold(
          appBar: AppBar(title: const Text('Todos')),
          body: Column(
            children: [
              if (state.status.isLoading) const LinearProgressIndicator(),
              if (state.status.isFailure) CrudErrorView(error: state.error!, onRetry: cubit.refresh),
              Expanded(
                child: ListView(
                  children: [
                    // state.items is the current page; state.allItems is
                    // everything read so far, for an endless scroll.
                    for (final todo in state.items) ListTile(title: Text(todo.title)),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: state.hasPrevious ? cubit.previousPage : null,
                  ),
                  Text('${state.index + 1}'),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: state.hasNext ? cubit.nextPage : null),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

class Todo implements CrudEntity<String> {
  const Todo({this.id, required this.title, this.done = false});

  @override
  final String? id;
  final String title;
  final bool done;

  Todo copyWith({String? id, String? title, bool? done}) =>
      Todo(id: id ?? this.id, title: title ?? this.title, done: done ?? this.done);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Todo && other.id == id && other.title == title && other.done == done;

  @override
  int get hashCode => Object.hash(id, title, done);
}
