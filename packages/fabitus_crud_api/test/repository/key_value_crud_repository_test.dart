import 'dart:convert';

import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

import '../support/todo.dart';
import 'crud_repository_contract.dart';

void main() {
  KeyValueCrudRepository<Todo, String> build(KeyValueStore store) =>
      KeyValueCrudRepository<Todo, String>(store: store, storageKey: 'todos', codec: todoCodec, withId: assignTodoId);

  runCrudRepositoryContract('KeyValueCrudRepository', () => build(InMemoryKeyValueStore()));

  group('KeyValueCrudRepository', () {
    late InMemoryKeyValueStore store;
    late KeyValueCrudRepository<Todo, String> repository;

    setUp(() {
      store = InMemoryKeyValueStore();
      repository = build(store);
    });

    test('persists the collection as a JSON array under the storage key', () async {
      await repository.create(const Todo(id: '1', title: 'Persisted'));

      final raw = store.values['todos'];
      expect(raw, isNotNull);
      expect(jsonDecode(raw!), [
        {'id': '1', 'title': 'Persisted', 'priority': null, 'done': false},
      ]);
    });

    test('reads a collection written by a previous session', () async {
      final store = InMemoryKeyValueStore({
        'todos': jsonEncode([
          {'id': '7', 'title': 'From disk', 'done': true},
        ]),
      });

      final todo = (await build(store).findById('7')).getOrThrow();

      expect(todo.title, 'From disk');
      expect(todo.done, isTrue);
    });

    test('treats a missing key as an empty collection', () async {
      expect((await repository.findAll()).getOrThrow(), isEmpty);
    });

    test('reports invalid JSON as a serialization failure', () async {
      await store.write('todos', 'not json');

      expect((await repository.findAll()).errorOrNull, isA<CrudSerializationException>());
    });

    test('reports a JSON object instead of an array as a failure', () async {
      await store.write('todos', '{"todos": []}');

      expect((await repository.findAll()).errorOrNull, isA<CrudSerializationException>());
    });

    test('clear removes the document from the store', () async {
      await repository.create(const Todo(title: 'One'));

      expect((await repository.clear()).isSuccess, isTrue);
      expect(store.values.containsKey('todos'), isFalse);
    });

    test('an invalid cursor fails validation', () async {
      final result = await repository.findPage(const CursorPageRequest(size: 2, cursor: 'nonsense'));

      expect(result.errorOrNull, isA<CrudValidationException>());
    });
  });
}
