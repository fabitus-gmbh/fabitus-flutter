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

  group('newUuid', () {
    test('produces a version 4 UUID', () {
      expect(
        newUuid(),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('produces distinct ids', () {
      final ids = {for (var i = 0; i < 500; i++) newUuid()};

      expect(ids, hasLength(500));
    });
  });
}
