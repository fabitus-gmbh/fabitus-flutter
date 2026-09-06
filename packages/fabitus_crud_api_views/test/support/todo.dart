import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_views/fabitus_crud_api_views.dart';
import 'package:flutter/widgets.dart';

/// The entity every test here works with.
class Todo implements CrudEntity<String> {
  const Todo({this.id, required this.title, this.priority = 0});

  @override
  final String? id;
  final String title;
  final int priority;

  Todo copyWith({String? id, String? title, int? priority}) =>
      Todo(id: id ?? this.id, title: title ?? this.title, priority: priority ?? this.priority);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'priority': priority};

  @override
  String toString() => 'Todo($id, $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Todo && other.id == id && other.title == title && other.priority == priority;

  @override
  int get hashCode => Object.hash(id, title, priority);
}

/// A repository holding [count] todos, titled so that alphabetical order is not
/// insertion order.
InMemoryCrudRepository<Todo, String> seededRepository(int count) => InMemoryCrudRepository<Todo, String>(
  withId: (todo, id) => todo.copyWith(id: id),
  initial: [for (var i = 0; i < count; i++) Todo(id: '$i', title: 'Todo ${count - i}', priority: i)],
);

/// The columns the table tests use. Text only, so a finder can see them.
List<TableColumn<Todo>> todoColumns() => [
  TableColumn<Todo>(
    header: (context, sort) => Text('Title ${_arrow(sort)}'),
    cell: (context, todo) => Text(todo.title),
    sortKey: 'title',
    sortValue: (todo) => todo.title,
    flex: 2,
  ),
  TableColumn<Todo>(
    header: (context, sort) => Text('Priority ${_arrow(sort)}'),
    cell: (context, todo) => Text('${todo.priority}'),
    sortKey: 'priority',
    sortValue: (todo) => todo.priority,
  ),
  TableColumn<Todo>(
    header: (context, sort) => Text('Id ${_arrow(sort)}'),
    cell: (context, todo) => Text(todo.id ?? '-'),
    width: 40,
  ),
];

/// Renders the sort state as text, so a test can read it off the widget tree.
String _arrow(ColumnSortState sort) => switch (sort) {
  ColumnSortState.ascending => 'asc',
  ColumnSortState.descending => 'desc',
  ColumnSortState.sortable => 'sortable',
  ColumnSortState.unsortable => 'unsortable',
};
