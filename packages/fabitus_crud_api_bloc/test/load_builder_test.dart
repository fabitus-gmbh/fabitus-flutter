import 'dart:async';

import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/todo.dart';

void main() {
  const todo = Todo(id: '1', title: 'Write docs');

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  Widget builderFor(LoadCubit<Todo> cubit) => wrap(
    LoadBuilder<Todo>(
      cubit: cubit,
      builder: (context, data, {bool refreshing = false}) => Text('${data.title}${refreshing ? ' (refreshing)' : ''}'),
    ),
  );

  testWidgets('shows a spinner while there is nothing yet', (tester) async {
    final completer = Completer<CrudResult<Todo>>();
    final cubit = LoadCubit<Todo>(() => completer.future);
    addTearDown(cubit.close);

    await tester.pumpWidget(builderFor(cubit));
    unawaited(cubit.load());
    // Two pumps: the first lets the stream deliver the state, the second
    // renders it. pumpAndSettle would time out - the default spinner animates
    // forever, so the tree never settles.
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOne);

    completer.complete(const CrudSuccess(todo));
    await tester.pumpAndSettle();

    expect(find.text('Write docs'), findsOne);
  });

  testWidgets('keeps the content on screen during a refresh', (tester) async {
    var completer = Completer<CrudResult<Todo>>()..complete(const CrudSuccess(todo));
    final cubit = LoadCubit<Todo>(() => completer.future);
    addTearDown(cubit.close);

    await tester.pumpWidget(builderFor(cubit));
    await cubit.load();
    await tester.pumpAndSettle();
    expect(find.text('Write docs'), findsOne);

    completer = Completer<CrudResult<Todo>>();
    unawaited(cubit.refresh());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Write docs (refreshing)'), findsOne);

    completer.complete(const CrudSuccess(todo));
    await tester.pumpAndSettle();
    expect(find.text('Write docs'), findsOne);
  });

  testWidgets('shows the default error view with a retry button', (tester) async {
    var attempts = 0;
    final cubit = LoadCubit<Todo>(() async {
      attempts++;
      return attempts == 1
          ? CrudFailure<Todo>(const CrudServerException('The server had a problem'), StackTrace.current)
          : const CrudSuccess(todo);
    });
    addTearDown(cubit.close);

    await tester.pumpWidget(builderFor(cubit));
    await cubit.load();
    await tester.pumpAndSettle();

    expect(find.text('The server had a problem'), findsOne);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Write docs'), findsOne);
    expect(attempts, 2);
  });

  testWidgets('lists the field errors of a validation failure', (tester) async {
    final cubit = LoadCubit<Todo>(
      () async => CrudFailure<Todo>(
        const CrudValidationException(
          'Please check the fields',
          violations: [CrudViolation(field: 'title', message: 'must not be blank')],
        ),
        StackTrace.current,
      ),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(builderFor(cubit));
    await cubit.load();
    await tester.pumpAndSettle();

    expect(find.text('Please check the fields'), findsOne);
    expect(find.text('title: must not be blank'), findsOne);
  });

  testWidgets('onError and onLoading replace the defaults', (tester) async {
    final completer = Completer<CrudResult<Todo>>();
    final cubit = LoadCubit<Todo>(() => completer.future);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      wrap(
        LoadBuilder<Todo>(
          cubit: cubit,
          onLoading: (_) => const Text('my spinner'),
          onError: (_, error, retry) => Text('my error: ${error.message}'),
          builder: (context, data, {bool refreshing = false}) => Text(data.title),
        ),
      ),
    );
    unawaited(cubit.load());
    await tester.pumpAndSettle();

    expect(find.text('my spinner'), findsOne);

    completer.complete(CrudFailure<Todo>(const CrudNotFoundException('gone'), StackTrace.current));
    await tester.pumpAndSettle();

    expect(find.text('my error: gone'), findsOne);
  });

  testWidgets('reads the cubit from the enclosing provider', (tester) async {
    final repository = seededRepository(2);

    await tester.pumpWidget(
      wrap(
        BlocProvider<LoadCubit<List<Todo>>>(
          create: (_) => LoadCubit<List<Todo>>(repository.findAll, loadOnCreate: true),
          child: LoadBuilder<List<Todo>>(
            builder: (context, todos, {bool refreshing = false}) => Text('${todos.length} todos'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 todos'), findsOne);
  });
}
