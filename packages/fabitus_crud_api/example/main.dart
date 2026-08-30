// A runnable tour of fabitus_crud_api: define an entity, put it behind a
// repository, page through it and react to changes.
//
//   dart run example/main.dart
import 'package:fabitus_crud_api/fabitus_crud_api.dart';

void main() async {
  // 1. A repository. Swap InMemoryCrudRepository for KeyValueCrudRepository or
  //    RemotePagingCrudRepository without touching anything below.
  final service = PagingCrudService<Todo, String>(
    InMemoryCrudRepository<Todo, String>(withId: (todo, id) => todo.copyWith(id: id)),
    // 2a. Listeners are handed in at construction. This is where an event bus
    //     goes: `CrudEventListener.fromCallback(eventBus.fire)`.
    listeners: [CrudEventListener.fromCallback((event) => print('listener: $event'))],
  );

  // 2b. And anyone can follow the stream. Both routes are always active.
  service.events.listen((event) => print('stream:   $event'));

  // 3. Create. The store assigns the id.
  final created = await service.create(const Todo(title: 'Write the docs'));
  switch (created) {
    case CrudSuccess(:final data):
      print('created ${data.id}');
    case CrudFailure(:final error):
      print('failed: ${error.message}');
  }

  for (final title in ['Review the PR', 'Ship it']) {
    await service.create(Todo(title: title));
  }

  // 4. Page through the collection, newest title first.
  final page = await service.findPage(OffsetPageRequest(size: 2, sort: Sort.by('title', SortDirection.desc)));
  final todos = page.getOrThrow();
  print('page 0: ${todos.content.map((todo) => todo.title).join(', ')}');
  print('has next: ${todos.hasNext}');

  // 5. Failures are values, never exceptions.
  final missing = await service.findById('does-not-exist');
  print('missing: ${missing.errorOrNull?.message}');

  await service.dispose();
}

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
}
