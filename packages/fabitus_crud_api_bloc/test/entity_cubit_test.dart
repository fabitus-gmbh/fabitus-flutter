import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/todo.dart';

void main() {
  late FlakyTodoRepository repository;

  EntityCubit<Todo, String> build({Todo? draft}) {
    repository = FlakyTodoRepository(seededRepository(2));
    final cubit = EntityCubit<Todo, String>(repository, draft: draft);
    addTearDown(cubit.close);
    return cubit;
  }

  group('load', () {
    test('makes the stored entity the draft', () async {
      final cubit = build();

      await cubit.load('1');

      expect(cubit.state.entity, const Todo(id: '1', title: 'Todo 1'));
      expect(cubit.state.draft, cubit.state.entity);
      expect(cubit.state.isDirty, isFalse);
      expect(cubit.state.status.isSuccess, isTrue);
      expect(cubit.state.action, EntityAction.load);
    });

    test('reports a failure', () async {
      final cubit = build();

      await cubit.load('nope');

      expect(cubit.state.status.isFailure, isTrue);
      expect(cubit.state.error, isA<CrudNotFoundException>());
      expect(cubit.state.action, EntityAction.load);
    });

    test('an overtaken load does not overwrite the newer one', () async {
      final cubit = build();

      final first = cubit.load('0');
      final second = cubit.load('1');
      await Future.wait([first, second]);

      expect(cubit.state.entity?.id, '1');
    });
  });

  group('select', () {
    test('takes an entity without a round trip', () {
      final cubit = build();

      cubit.select(const Todo(id: '9', title: 'From the list'));

      expect(cubit.state.entity?.id, '9');
      expect(cubit.state.isDirty, isFalse);
      expect(repository.calls, isEmpty);
    });
  });

  group('edit', () {
    test('changes the draft and marks the state dirty', () async {
      final cubit = build();
      await cubit.load('1');

      cubit.edit((todo) => todo.copyWith(title: 'Renamed'));

      expect(cubit.state.draft?.title, 'Renamed');
      expect(cubit.state.entity?.title, 'Todo 1');
      expect(cubit.state.isDirty, isTrue);
    });

    test('clears the previous error, so a violation goes away when typing', () async {
      final cubit = build(draft: const Todo(title: 'x'));
      repository.nextError = const CrudValidationException(
        'invalid',
        violations: [CrudViolation(field: 'title', message: 'must not be blank')],
      );
      await cubit.save();
      expect(cubit.state.violationFor('title'), isNotNull);

      cubit.edit((todo) => todo.copyWith(title: 'Now filled in'));

      expect(cubit.state.violationFor('title'), isNull);
      expect(cubit.state.error, isNull);
    });

    test('is ignored when there is no draft yet', () {
      final cubit = build();

      cubit.edit((todo) => todo.copyWith(title: 'Nope'));

      expect(cubit.state.draft, isNull);
    });

    test('replaceDraft swaps the whole draft', () async {
      final cubit = build();
      await cubit.load('1');

      cubit.replaceDraft(const Todo(id: '1', title: 'Replaced'));

      expect(cubit.state.draft?.title, 'Replaced');
    });

    test('reset throws the edits away', () async {
      final cubit = build();
      await cubit.load('1');
      cubit.edit((todo) => todo.copyWith(title: 'Renamed'));

      cubit.reset();

      expect(cubit.state.draft, cubit.state.entity);
      expect(cubit.state.isDirty, isFalse);
    });
  });

  group('save', () {
    test('creates a draft that has no id', () async {
      final cubit = build(draft: const Todo(title: 'Brand new'));
      expect(cubit.state.isNew, isTrue);

      await cubit.save();

      expect(cubit.state.entity?.id, isNotNull);
      expect(cubit.state.isDirty, isFalse);
      expect(cubit.state.action, EntityAction.save);
      expect(repository.calls, ['create']);
    });

    test('updates a draft that has one', () async {
      final cubit = build();
      await cubit.load('1');
      cubit.edit((todo) => todo.copyWith(title: 'Renamed'));

      await cubit.save();

      expect(cubit.state.entity?.title, 'Renamed');
      expect(cubit.state.isDirty, isFalse);
      expect(repository.calls.last, 'update');
    });

    test('a failure keeps the draft and exposes the field errors', () async {
      final cubit = build();
      await cubit.load('1');
      cubit.edit((todo) => todo.copyWith(title: ''));
      repository.nextError = const CrudValidationException(
        'invalid',
        violations: [
          CrudViolation(field: 'title', message: 'must not be blank'),
          CrudViolation(field: 'done', message: 'must be false'),
        ],
      );

      await cubit.save();

      expect(cubit.state.status.isFailure, isTrue);
      expect(cubit.state.draft?.title, '');
      expect(cubit.state.entity?.title, 'Todo 1');
      expect(cubit.state.isDirty, isTrue);
      expect(cubit.state.violations, hasLength(2));
      expect(cubit.state.violationFor('title')?.message, 'must not be blank');
      expect(cubit.state.violationFor('missing'), isNull);
    });

    test('is ignored when there is no draft', () async {
      final cubit = build();

      await cubit.save();

      expect(repository.calls, isEmpty);
      expect(cubit.state.status.isInitial, isTrue);
    });
  });

  group('delete', () {
    test('marks the state deleted and drops both copies', () async {
      final cubit = build();
      await cubit.load('1');

      await cubit.delete();

      expect(cubit.state.isDeleted, isTrue);
      expect(cubit.state.entity, isNull);
      expect(cubit.state.draft, isNull);
      expect(cubit.state.action, EntityAction.delete);
      expect(cubit.state.status.isSuccess, isTrue);
    });

    test('a failure keeps the entity', () async {
      final cubit = build();
      await cubit.load('1');
      repository.nextError = const CrudForbiddenException('not yours');

      await cubit.delete();

      expect(cubit.state.isDeleted, isFalse);
      expect(cubit.state.entity, isNotNull);
      expect(cubit.state.error, isA<CrudForbiddenException>());
    });

    test('is ignored when nothing is loaded', () async {
      final cubit = build(draft: const Todo(title: 'Never stored'));

      await cubit.delete();

      expect(repository.calls, isEmpty);
      expect(cubit.state.isDeleted, isFalse);
    });
  });

  group('EntityState', () {
    test('equality ignores the stack trace', () {
      const error = CrudServerException('down');
      const base = EntityState<Todo>.initial();

      expect(
        base.copyWith(error: error, stackTrace: StackTrace.empty),
        base.copyWith(error: error, stackTrace: StackTrace.fromString('elsewhere')),
      );
    });

    test('copyWith clears the error unless told to keep it', () {
      const error = CrudServerException('down');
      final failed = const EntityState<Todo>.initial().copyWith(error: error);

      expect(failed.copyWith(status: EntityStatus.busy).error, isNull);
      expect(failed.copyWith(status: EntityStatus.busy, keepError: true).error, error);
    });

    test('an initial state with a draft is a create form', () {
      const state = EntityState<Todo>.initial(draft: Todo(title: 'New'));

      expect(state.hasDraft, isTrue);
      expect(state.isNew, isTrue);
      expect(state.isDirty, isTrue);
    });
  });
}
