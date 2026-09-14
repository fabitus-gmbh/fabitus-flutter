import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_bloc/fabitus_crud_api_bloc.dart';
import 'package:fabitus_crud_api_forms/fabitus_crud_api_forms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/todo.dart';

void main() {
  late FlakyTodoRepository repository;

  EntityCubit<Todo, String> cubitFor({Todo? draft}) {
    repository = seededRepository();
    final cubit = EntityCubit<Todo, String>(repository, draft: draft);
    addTearDown(cubit.close);
    return cubit;
  }

  /// The form under test: a title field, and the three actions as plain text so
  /// a finder can see whether they are enabled.
  Widget formFor(
    EntityCubit<Todo, String> cubit, {
    bool canEdit = true,
    bool canDelete = true,
    DiscardConfirmation? confirmDiscard,
    void Function(Todo)? onSaved,
    VoidCallback? onDeleted,
    void Function(CrudException)? onFailure,
    FormFieldValidator<String>? validator,
  }) => MaterialApp(
    home: Scaffold(
      body: CrudForm<Todo, String>(
        cubit: cubit,
        canEdit: canEdit,
        canDelete: canDelete,
        confirmDiscard: confirmDiscard,
        onSaved: onSaved,
        onDeleted: onDeleted,
        onFailure: onFailure,
        child: Column(
          children: [
            EntityFieldBuilder<Todo, String>(
              field: titleField,
              builder: (context, field) => TextFormField(
                key: const Key('title'),
                initialValue: field.value,
                readOnly: field.readOnly,
                decoration: InputDecoration(errorText: field.errorText),
                onChanged: field.onChanged,
                validator: validator,
              ),
            ),
            Builder(
              builder: (context) {
                final form = CrudFormScope.of<Todo>(context);
                return Column(
                  children: [
                    Text('dirty: ${form.isDirty}'),
                    Text('new: ${form.isNew}'),
                    TextButton(onPressed: form.save, child: Text('save ${form.save == null ? 'off' : 'on'}')),
                    TextButton(onPressed: form.reset, child: Text('reset ${form.reset == null ? 'off' : 'on'}')),
                    TextButton(onPressed: form.delete, child: Text('delete ${form.delete == null ? 'off' : 'on'}')),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );

  group('the field', () {
    testWidgets('shows the draft and writes back to it', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      await tester.pumpWidget(formFor(cubit));

      expect(find.text('Write docs'), findsOne);
      expect(find.text('dirty: false'), findsOne);

      await tester.enterText(find.byKey(const Key('title')), 'Renamed');
      await tester.pumpAndSettle();

      expect(cubit.state.draft?.title, 'Renamed');
      expect(cubit.state.entity?.title, 'Write docs');
      expect(find.text('dirty: true'), findsOne);
    });

    testWidgets('shows the backend violation for its own property', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      await tester.pumpWidget(formFor(cubit));

      repository.nextError = const CrudValidationException(
        'invalid',
        violations: [
          CrudViolation(field: 'title', message: 'must not be blank'),
          CrudViolation(field: 'done', message: 'not yours to set'),
        ],
      );
      await cubit.save();
      await tester.pumpAndSettle();

      expect(find.text('must not be blank'), findsOne);
      // The other field's violation does not leak into this one.
      expect(find.text('not yours to set'), findsNothing);
    });

    testWidgets('is read only when the form says so', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');

      await tester.pumpWidget(formFor(cubit, canEdit: false));

      final field = tester.widget<TextField>(
        find.descendant(of: find.byKey(const Key('title')), matching: find.byType(TextField)),
      );
      expect(field.readOnly, isTrue);
      expect(find.text('save off'), findsOne);
    });

    testWidgets('throws a helpful error outside a form', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EntityFieldBuilder<Todo, String>(
            field: titleField,
            builder: (context, field) => const SizedBox.shrink(),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          allOf(contains('CrudFormScope<Todo>'), contains('CrudForm<Todo')),
        ),
      );
    });
  });

  group('the actions', () {
    testWidgets('save is off while there is no draft', (tester) async {
      final cubit = cubitFor();

      await tester.pumpWidget(formFor(cubit));

      expect(find.text('save off'), findsOne);
    });

    testWidgets('save writes the draft and reports it', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      Todo? saved;
      await tester.pumpWidget(formFor(cubit, onSaved: (todo) => saved = todo));

      await tester.enterText(find.byKey(const Key('title')), 'Renamed');
      await tester.pumpAndSettle();
      await tester.tap(find.text('save on'));
      await tester.pumpAndSettle();

      expect(saved?.title, 'Renamed');
      expect(find.text('dirty: false'), findsOne);
    });

    testWidgets('save runs the validators first and stops on a failure', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      await tester.pumpWidget(formFor(cubit, validator: (value) => (value ?? '').isEmpty ? 'Required' : null));

      await tester.enterText(find.byKey(const Key('title')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('save on'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOne);
      // Nothing was written: the stored copy is untouched and the draft is dirty.
      expect(cubit.state.entity?.title, 'Write docs');
      expect(find.text('dirty: true'), findsOne);
    });

    testWidgets('reset is off until something changed, then undoes it', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      await tester.pumpWidget(formFor(cubit));

      expect(find.text('reset off'), findsOne);

      await tester.enterText(find.byKey(const Key('title')), 'Renamed');
      await tester.pumpAndSettle();
      expect(find.text('reset on'), findsOne);

      await tester.tap(find.text('reset on'));
      await tester.pumpAndSettle();

      expect(cubit.state.draft?.title, 'Write docs');
      expect(find.text('dirty: false'), findsOne);
    });

    testWidgets('delete is off on a create form', (tester) async {
      final cubit = cubitFor(draft: const Todo(title: 'New'));

      await tester.pumpWidget(formFor(cubit));

      expect(find.text('new: true'), findsOne);
      expect(find.text('delete off'), findsOne);
      expect(find.text('save on'), findsOne);
    });

    testWidgets('delete is off when the user may not', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');

      await tester.pumpWidget(formFor(cubit, canDelete: false));

      expect(find.text('delete off'), findsOne);
    });

    testWidgets('delete reports when it went through', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      var deleted = false;
      await tester.pumpWidget(formFor(cubit, onDeleted: () => deleted = true));

      await tester.tap(find.text('delete on'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      expect(cubit.state.isDeleted, isTrue);
    });

    testWidgets('a failure is reported to the screen', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      CrudException? failure;
      await tester.pumpWidget(formFor(cubit, onFailure: (error) => failure = error));

      await tester.enterText(find.byKey(const Key('title')), 'Renamed');
      await tester.pumpAndSettle();
      repository.nextError = const CrudServerException('down', statusCode: 503);
      await tester.tap(find.text('save on'));
      await tester.pumpAndSettle();

      expect(failure, isA<CrudServerException>());
      // The draft survives, so nothing typed is lost.
      expect(cubit.state.draft?.title, 'Renamed');
    });

    testWidgets('an edit alone announces nothing', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      var saves = 0;
      await tester.pumpWidget(formFor(cubit, onSaved: (_) => saves++));

      await tester.enterText(find.byKey(const Key('title')), 'Renamed');
      await tester.pumpAndSettle();

      expect(saves, 0);
    });

    testWidgets('reads the cubit from the enclosing provider', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<EntityCubit<Todo, String>>.value(
            value: cubit,
            child: CrudForm<Todo, String>(
              child: EntityFieldBuilder<Todo, String>(
                field: titleField,
                builder: (context, field) => Text(field.value ?? '-'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Write docs'), findsOne);
    });
  });

  group('leaving with unsaved edits', () {
    Widget routedForm(EntityCubit<Todo, String> cubit, {DiscardConfirmation? confirmDiscard}) => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: CrudForm<Todo, String>(
                    cubit: cubit,
                    confirmDiscard: confirmDiscard,
                    child: Builder(
                      builder: (context) => Column(
                        children: [
                          TextButton(
                            // maybePop is what consults PopScope; see the
                            // "bypasses the guard" test below.
                            onPressed: () => Navigator.maybePop(context),
                            child: const Text('back'),
                          ),
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('force back')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    testWidgets('pops freely when no confirmation was given', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      await tester.pumpWidget(routedForm(cubit));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      cubit.edit((todo) => todo.copyWith(title: 'Renamed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOne);
    });

    testWidgets('pops without asking when nothing changed', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      var asked = 0;
      await tester.pumpWidget(
        routedForm(
          cubit,
          confirmDiscard: (context) async {
            asked++;
            return false;
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();

      expect(asked, 0);
      expect(find.text('open'), findsOne);
    });

    testWidgets('asks when something changed, and stays on a refusal', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      var asked = 0;
      await tester.pumpWidget(
        routedForm(
          cubit,
          confirmDiscard: (context) async {
            asked++;
            return false;
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      cubit.edit((todo) => todo.copyWith(title: 'Renamed'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();

      expect(asked, 1);
      expect(find.text('back'), findsOne);
    });

    testWidgets('a plain Navigator.pop bypasses the guard', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      var asked = 0;
      await tester.pumpWidget(
        routedForm(
          cubit,
          confirmDiscard: (context) async {
            asked++;
            return false;
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      cubit.edit((todo) => todo.copyWith(title: 'Renamed'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('force back'));
      await tester.pumpAndSettle();

      // Documented, not desired: PopScope only sees maybePop. An in-app back
      // button has to use maybePop for the guard to run at all.
      expect(asked, 0);
      expect(find.text('open'), findsOne);
    });

    testWidgets('leaves when the confirmation agrees', (tester) async {
      final cubit = cubitFor();
      await cubit.load('1');
      await tester.pumpWidget(routedForm(cubit, confirmDiscard: (context) async => true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      cubit.edit((todo) => todo.copyWith(title: 'Renamed'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOne);
    });
  });
}
