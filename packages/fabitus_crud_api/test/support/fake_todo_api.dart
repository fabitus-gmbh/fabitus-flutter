import 'package:fabitus_crud_api/fabitus_crud_api.dart';

import 'todo.dart';

/// A hand written stand in for a retrofit client.
///
/// Throws the way an HTTP client does, so the repository under test has to do
/// the error mapping.
class FakeTodoApi extends PagingCrudApi<Todo, String> {
  FakeTodoApi({List<Todo> initial = const [], this.reportTotal = true}) {
    for (final todo in initial) {
      todos[todo.id!] = todo;
    }
  }

  /// Whether paged responses carry `totalElements`.
  final bool reportTotal;

  /// The backing store, exposed so tests can assert on it.
  final Map<String, Todo> todos = {};

  /// Every call recorded in order, for assertions on the call sequence.
  final List<String> calls = [];

  /// When set, the next call throws this instead of doing its work.
  Object? nextError;

  int _nextId = 1;

  void _record(String call) {
    calls.add(call);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  @override
  Future<Todo> findById(String id) async {
    _record('findById($id)');
    final todo = todos[id];
    if (todo == null) throw CrudNotFoundException('No Todo with id $id');
    return todo;
  }

  @override
  Future<Todo> create(Todo entity) async {
    _record('create');
    final created = entity.copyWith(id: entity.id ?? '${_nextId++}');
    todos[created.id!] = created;
    return created;
  }

  @override
  Future<Todo> update(String id, Todo entity) async {
    _record('update($id)');
    if (!todos.containsKey(id)) throw CrudNotFoundException('No Todo $id');
    todos[id] = entity;
    return entity;
  }

  @override
  Future<void> deleteById(String id) async {
    _record('deleteById($id)');
    if (todos.remove(id) == null) throw CrudNotFoundException('No Todo $id');
  }

  @override
  Future<Page<Todo>> findPage(PageRequest pageRequest) async {
    _record('findPage(${pageRequest.toQueryParameters()})');
    final all = todos.values.toList(growable: false);
    final request = pageRequest as OffsetPageRequest;
    final start = request.offset.clamp(0, all.length);
    final end = (start + request.size).clamp(0, all.length);
    return OffsetPage<Todo>(
      content: all.sublist(start, end),
      page: request.page,
      size: request.size,
      totalElements: reportTotal ? all.length : null,
    );
  }
}
