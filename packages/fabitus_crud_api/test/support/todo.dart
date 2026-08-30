import 'package:fabitus_crud_api/fabitus_crud_api.dart';

/// The entity every test in this package works with.
class Todo implements CrudEntity<String> {
  const Todo({this.id, required this.title, this.priority, this.done = false});

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as String?,
    title: json['title'] as String,
    priority: (json['priority'] as num?)?.toInt(),
    done: json['done'] as bool? ?? false,
  );

  @override
  final String? id;
  final String title;
  final int? priority;
  final bool done;

  Todo copyWith({String? id, String? title, int? priority, bool? done}) => Todo(
    id: id ?? this.id,
    title: title ?? this.title,
    priority: priority ?? this.priority,
    done: done ?? this.done,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'priority': priority,
    'done': done,
  };

  @override
  String toString() => 'Todo($id, $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo &&
          other.id == id &&
          other.title == title &&
          other.priority == priority &&
          other.done == done;

  @override
  int get hashCode => Object.hash(id, title, priority, done);
}

/// Assigns an id to a [Todo], as local repositories require.
Todo assignTodoId(Todo todo, String id) => todo.copyWith(id: id);

/// The codec local repositories use for [Todo].
final EntityCodec<Todo> todoCodec = EntityCodec.forEntity(Todo.fromJson);
