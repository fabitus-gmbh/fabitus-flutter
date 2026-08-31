import 'package:fabitus_crud_api/fabitus_crud_api.dart';

/// The entity every test here works with.
class Todo implements CrudEntity<String> {
  const Todo({this.id, required this.title, this.done = false});

  factory Todo.fromJson(Map<String, dynamic> json) =>
      Todo(id: json['id'] as String?, title: json['title'] as String, done: json['done'] as bool? ?? false);

  @override
  final String? id;
  final String title;
  final bool done;

  Todo copyWith({String? id, String? title, bool? done}) =>
      Todo(id: id ?? this.id, title: title ?? this.title, done: done ?? this.done);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  @override
  String toString() => 'Todo($id, $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Todo && other.id == id && other.title == title && other.done == done;

  @override
  int get hashCode => Object.hash(id, title, done);
}

/// Assigns an id to a [Todo], as local repositories require.
Todo assignTodoId(Todo todo, String id) => todo.copyWith(id: id);

/// A repository that can be told to fail, so the failure paths are reachable.
class FlakyTodoRepository extends BaseCrudRepository<Todo, String> implements PagingCrudRepository<Todo, String> {
  FlakyTodoRepository([this.delegate]) : super();

  final InMemoryCrudRepository<Todo, String>? delegate;

  /// When set, the next call fails with this instead of doing its work.
  CrudException? nextError;

  /// Every call, in order.
  final List<String> calls = [];

  InMemoryCrudRepository<Todo, String> get _delegate => delegate ?? (throw StateError('no delegate'));

  CrudFailure<R>? _fail<R>(String call) {
    calls.add(call);
    final error = nextError;
    if (error == null) return null;
    nextError = null;
    return CrudFailure<R>(error, StackTrace.current);
  }

  @override
  Future<CrudResult<Todo>> findById(String id) async => _fail<Todo>('findById($id)') ?? await _delegate.findById(id);

  @override
  Future<CrudResult<List<Todo>>> findAll() async => _fail<List<Todo>>('findAll') ?? await _delegate.findAll();

  @override
  Future<CrudResult<int>> count() async => _fail<int>('count') ?? await _delegate.count();

  @override
  Future<CrudResult<Todo>> create(Todo entity) async => _fail<Todo>('create') ?? await _delegate.create(entity);

  @override
  Future<CrudResult<Todo>> update(Todo entity) async => _fail<Todo>('update') ?? await _delegate.update(entity);

  @override
  Future<CrudResult<void>> deleteById(String id) async =>
      _fail<void>('deleteById($id)') ?? await _delegate.deleteById(id);

  @override
  Future<CrudResult<Page<Todo>>> findPage(PageRequest pageRequest) async =>
      _fail<Page<Todo>>('findPage') ?? await _delegate.findPage(pageRequest);
}

/// A repository seeded with [count] todos.
InMemoryCrudRepository<Todo, String> seededRepository(int count) => InMemoryCrudRepository<Todo, String>(
  withId: assignTodoId,
  initial: [for (var i = 0; i < count; i++) Todo(id: '$i', title: 'Todo $i')],
);
