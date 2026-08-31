import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/todo.dart';

void main() {
  const todo = Todo(id: '1', title: 'Write docs');
  const error = CrudNotFoundException('gone');

  Future<CrudResult<Todo>> succeeds() async => const CrudSuccess(todo);
  Future<CrudResult<Todo>> fails() async => CrudFailure<Todo>(error, StackTrace.current);

  group('LoadCubit', () {
    test('starts in the initial state and does not load on its own', () async {
      var calls = 0;
      final cubit = LoadCubit<Todo>(() async {
        calls++;
        return const CrudSuccess(todo);
      });
      addTearDown(cubit.close);

      expect(cubit.state, LoadInitial<Todo>());
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
    });

    test('loadOnCreate loads immediately', () async {
      final cubit = LoadCubit<Todo>(succeeds, loadOnCreate: true);
      addTearDown(cubit.close);

      await expectLater(cubit.stream, emitsInOrder([LoadInProgress<Todo>(), const LoadSuccess(todo)]));
    });

    blocTest<LoadCubit<Todo>, LoadState<Todo>>(
      'emits loading then success',
      build: () => LoadCubit<Todo>(succeeds),
      act: (cubit) => cubit.load(),
      expect: () => [LoadInProgress<Todo>(), const LoadSuccess(todo)],
    );

    blocTest<LoadCubit<Todo>, LoadState<Todo>>(
      'emits loading then failure',
      build: () => LoadCubit<Todo>(fails),
      act: (cubit) => cubit.load(),
      expect: () => [LoadInProgress<Todo>(), isA<LoadFailure<Todo>>().having((s) => s.error, 'error', error)],
    );

    blocTest<LoadCubit<Todo>, LoadState<Todo>>(
      'a refresh keeps the previous value on screen',
      build: () => LoadCubit<Todo>(succeeds),
      act: (cubit) async {
        await cubit.load();
        await cubit.refresh();
      },
      expect: () => [
        LoadInProgress<Todo>(),
        const LoadSuccess(todo),
        const LoadInProgress<Todo>(previous: todo),
        const LoadSuccess(todo),
      ],
    );

    blocTest<LoadCubit<Todo>, LoadState<Todo>>(
      'a failed refresh keeps the previous value beside the error',
      build: () {
        var first = true;
        return LoadCubit<Todo>(() async {
          if (first) {
            first = false;
            return const CrudSuccess(todo);
          }
          return CrudFailure<Todo>(error, StackTrace.current);
        });
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.refresh();
      },
      expect: () => [
        LoadInProgress<Todo>(),
        const LoadSuccess(todo),
        const LoadInProgress<Todo>(previous: todo),
        isA<LoadFailure<Todo>>().having((s) => s.previous, 'previous', todo),
      ],
    );

    test('a load that is overtaken does not overwrite the newer one', () async {
      final completers = <String, Completer<CrudResult<Todo>>>{};
      var call = 0;
      final cubit = LoadCubit<Todo>(() {
        final key = 'call${call++}';
        return (completers[key] = Completer<CrudResult<Todo>>()).future;
      });
      addTearDown(cubit.close);

      final first = cubit.load();
      final second = cubit.load();

      // The newer load answers first, the older one afterwards.
      completers['call1']!.complete(const CrudSuccess(Todo(id: '2', title: 'newer')));
      await second;
      completers['call0']!.complete(const CrudSuccess(Todo(id: '1', title: 'older')));
      await first;

      expect(cubit.state, const LoadSuccess(Todo(id: '2', title: 'newer')));
    });

    test('a response arriving after close is dropped', () async {
      final completer = Completer<CrudResult<Todo>>();
      final cubit = LoadCubit<Todo>(() => completer.future);

      final pending = cubit.load();
      await cubit.close();
      completer.complete(const CrudSuccess(todo));

      // Must not throw "emit was called after close".
      await expectLater(pending, completes);
    });

    test('works for a list without a separate list cubit', () async {
      final repository = seededRepository(3);
      final cubit = LoadCubit<List<Todo>>(repository.findAll, loadOnCreate: true);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => state.isSuccess);

      expect(cubit.state.dataOrNull, hasLength(3));
    });
  });

  group('LoadState', () {
    test('exposes the value through every state that has one', () {
      expect(LoadInitial<Todo>().dataOrNull, isNull);
      expect(const LoadInProgress<Todo>(previous: todo).dataOrNull, todo);
      expect(const LoadSuccess(todo).dataOrNull, todo);
      expect(LoadFailure<Todo>(error, StackTrace.current, previous: todo).dataOrNull, todo);
    });

    test('the status getters agree with the type', () {
      expect(LoadInitial<Todo>().isInitial, isTrue);
      expect(LoadInProgress<Todo>().isLoading, isTrue);
      expect(const LoadSuccess(todo).isSuccess, isTrue);
      expect(LoadFailure<Todo>(error, StackTrace.current).isFailure, isTrue);
      expect(const LoadSuccess(todo).hasData, isTrue);
      expect(LoadInitial<Todo>().hasData, isFalse);
    });

    test('exposes violations of a validation failure', () {
      const invalid = CrudValidationException(
        'invalid',
        violations: [CrudViolation(field: 'title', message: 'must not be blank')],
      );

      expect(LoadFailure<Todo>(invalid, StackTrace.current).violations.single.field, 'title');
      expect(const LoadSuccess(todo).violations, isEmpty);
    });

    test('equality ignores the stack trace', () {
      expect(
        LoadFailure<Todo>(error, StackTrace.current),
        LoadFailure<Todo>(error, StackTrace.fromString('somewhere else')),
      );
    });

    test('equality is by value otherwise', () {
      expect(const LoadSuccess(todo), const LoadSuccess(todo));
      expect(const LoadSuccess(todo), isNot(const LoadSuccess(Todo(title: 'x'))));
      expect(LoadInitial<Todo>(), LoadInitial<Todo>());
      expect(LoadInitial<Todo>(), isNot(LoadInProgress<Todo>()));
    });
  });
}
