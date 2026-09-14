import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_forms/fabitus_crud_api_forms.dart';

/// The entity every test here works with.
class Todo implements CrudEntity<String> {
  const Todo({this.id, this.title = '', this.done = false});

  @override
  final String? id;
  final String title;
  final bool done;

  Todo copyWith({String? id, String? title, bool? done}) =>
      Todo(id: id ?? this.id, title: title ?? this.title, done: done ?? this.done);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  @override
  String toString() => 'Todo($id, $title, done: $done)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Todo && other.id == id && other.title == title && other.done == done;

  @override
  int get hashCode => Object.hash(id, title, done);
}

const EntityField<Todo, String> titleField = EntityField<Todo, String>(
  name: 'title',
  read: _readTitle,
  write: _writeTitle,
);

const EntityField<Todo, bool> doneField = EntityField<Todo, bool>(name: 'done', read: _readDone, write: _writeDone);

String? _readTitle(Todo todo) => todo.title;
Todo _writeTitle(Todo todo, String? value) => todo.copyWith(title: value ?? '');
bool? _readDone(Todo todo) => todo.done;
Todo _writeDone(Todo todo, bool? value) => todo.copyWith(done: value ?? false);

/// A repository that can be told to fail, so the failure paths are reachable.
class FlakyTodoRepository extends BaseCrudRepository<Todo, String> {
  FlakyTodoRepository(this.delegate);

  final InMemoryCrudRepository<Todo, String> delegate;

  /// When set, the next call fails with this instead of doing its work.
  CrudException? nextError;

  CrudFailure<R>? _fail<R>() {
    final error = nextError;
    if (error == null) return null;
    nextError = null;
    return CrudFailure<R>(error, StackTrace.current);
  }

  @override
  Future<CrudResult<Todo>> findById(String id) async => _fail<Todo>() ?? await delegate.findById(id);

  @override
  Future<CrudResult<List<Todo>>> findAll() async => _fail<List<Todo>>() ?? await delegate.findAll();

  @override
  Future<CrudResult<int>> count() async => _fail<int>() ?? await delegate.count();

  @override
  Future<CrudResult<Todo>> create(Todo entity) async => _fail<Todo>() ?? await delegate.create(entity);

  @override
  Future<CrudResult<Todo>> update(Todo entity) async => _fail<Todo>() ?? await delegate.update(entity);

  @override
  Future<CrudResult<void>> deleteById(String id) async => _fail<void>() ?? await delegate.deleteById(id);
}

/// A repository holding one todo, `'1'`.
FlakyTodoRepository seededRepository() => FlakyTodoRepository(
  InMemoryCrudRepository<Todo, String>(
    withId: (todo, id) => todo.copyWith(id: id),
    initial: const [Todo(id: '1', title: 'Write docs')],
  ),
);
