import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

import '../support/todo.dart';

void main() {
  group('EntityCodec.forEntity', () {
    test('round trips an entity', () {
      const todo = Todo(id: '1', title: 'Round trip', done: true);

      expect(todoCodec.fromJson(todoCodec.toJson(todo)), todo);
    });
  });

  group('randomStringId', () {
    test('produces ids of the requested length', () {
      expect(randomStringId().length, 16);
      expect(randomStringId(length: 4).length, 4);
    });

    test('produces distinct ids', () {
      final ids = {for (var i = 0; i < 500; i++) randomStringId()};

      expect(ids, hasLength(500));
    });

    test('uses only URL safe characters', () {
      expect(randomStringId(length: 64), matches(RegExp(r'^[0-9a-z]+$')));
    });
  });
}
