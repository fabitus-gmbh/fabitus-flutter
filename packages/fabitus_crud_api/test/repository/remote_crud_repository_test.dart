import 'dart:async';

import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

import '../support/fake_todo_api.dart';
import '../support/todo.dart';

void main() {
  group('RemoteCrudRepository', () {
    late FakeTodoApi api;
    late RemoteCrudRepository<Todo, String> repository;

    setUp(() {
      api = FakeTodoApi();
      repository = RemoteCrudRepository<Todo, String>(api);
    });

    test('delegates create to the api', () async {
      final created = (await repository.create(const Todo(title: 'Remote'))).getOrThrow();

      expect(created.id, '1');
      expect(api.calls, ['create']);
    });

    test('update passes the id from the entity', () async {
      await repository.create(const Todo(id: 'a', title: 'One'));

      await repository.update(const Todo(id: 'a', title: 'Two'));

      expect(api.calls.last, 'update(a)');
    });

    test('update without an id never reaches the api', () async {
      final result = await repository.update(const Todo(title: 'No id'));

      expect(result.errorOrNull, isA<CrudValidationException>());
      expect(api.calls, isEmpty);
    });

    test('maps a thrown CrudException to a failure', () async {
      api.nextError = const CrudNotFoundException('gone');

      final result = await repository.findById('1');

      expect(result.errorOrNull, isA<CrudNotFoundException>());
    });

    test('maps an unrecognised error with the default mapper', () async {
      api.nextError = StateError('boom');

      final result = await repository.findById('1');

      expect(result.errorOrNull, isA<CrudUnknownException>());
      expect(result.errorOrNull!.cause, isA<StateError>());
    });

    test('uses a custom error mapper', () async {
      final repository = RemoteCrudRepository<Todo, String>(api, errorMapper: const _StatusCodeMapper());
      api.nextError = const _HttpError(403);

      final result = await repository.findById('1');

      expect(result.errorOrNull, isA<CrudForbiddenException>());
    });

    test('existsById maps a not found error to false', () async {
      expect((await repository.existsById('missing')).getOrThrow(), isFalse);
    });

    test('existsById forwards other failures', () async {
      api.nextError = TimeoutException('slow');

      final result = await repository.existsById('1');

      expect(result.errorOrNull, isA<CrudTimeoutException>());
    });

    test('findAll and count are unsupported without paging', () async {
      expect((await repository.findAll()).errorOrNull, isA<CrudUnsupportedException>());
      expect((await repository.count()).errorOrNull, isA<CrudUnsupportedException>());
    });
  });

  group('RemotePagingCrudRepository', () {
    late FakeTodoApi api;

    RemotePagingCrudRepository<Todo, String> build({bool reportTotal = true}) {
      api = FakeTodoApi(
        reportTotal: reportTotal,
        initial: [for (var i = 0; i < 5; i++) Todo(id: '$i', title: 'Todo $i')],
      );
      return RemotePagingCrudRepository<Todo, String>(api, pageSizeForFindAll: 2);
    }

    test('findPage delegates to the api', () async {
      final page = (await build().findPage(const OffsetPageRequest(page: 1, size: 2))).getOrThrow();

      expect(page.content.map((todo) => todo.id), ['2', '3']);
      expect(api.calls.single, contains('page: 1'));
    });

    test('count uses the reported total instead of walking pages', () async {
      final repository = build();

      expect((await repository.count()).getOrThrow(), 5);
      expect(api.calls, hasLength(1));
    });

    test('count walks every page when no total is reported', () async {
      final repository = build(reportTotal: false);

      expect((await repository.count()).getOrThrow(), 5);
      expect(api.calls.length, greaterThan(1));
    });

    test('findAll walks every page', () async {
      final repository = build();

      final all = (await repository.findAll()).getOrThrow();

      expect(all.map((todo) => todo.id), ['0', '1', '2', '3', '4']);
    });

    test('findAll stops on an empty page', () async {
      final repository = RemotePagingCrudRepository<Todo, String>(FakeTodoApi(reportTotal: false));

      expect((await repository.findAll()).getOrThrow(), isEmpty);
    });

    test('findAll gives up instead of looping on an endless backend', () async {
      final repository = RemotePagingCrudRepository<Todo, String>(
        _EndlessTodoApi(),
        pageSizeForFindAll: 2,
        maxPagesForFindAll: 3,
      );

      final result = await repository.findAll();

      expect(result.errorOrNull, isA<CrudUnsupportedException>());
      expect(result.errorOrNull!.message, contains('stopped after 3 pages'));
    });

    test('findAll forwards a failure from the api', () async {
      final repository = build();
      api.nextError = const CrudServerException('down', statusCode: 503);

      expect((await repository.findAll()).errorOrNull, isA<CrudServerException>());
    });
  });
}

/// An api that always claims another page, as a broken backend would.
class _EndlessTodoApi extends PagingCrudApi<Todo, String> {
  @override
  Future<Page<Todo>> findPage(PageRequest pageRequest) async => OffsetPage<Todo>(
    content: [for (var i = 0; i < pageRequest.size; i++) Todo(id: '$i', title: 'Todo')],
    size: pageRequest.size,
  );

  @override
  Future<Todo> findById(String id) async => throw UnimplementedError();
  @override
  Future<Todo> create(Todo entity) async => throw UnimplementedError();
  @override
  Future<Todo> update(String id, Todo entity) async => throw UnimplementedError();
  @override
  Future<void> deleteById(String id) async => throw UnimplementedError();
}

class _HttpError implements Exception {
  const _HttpError(this.statusCode);

  final int statusCode;
}

class _StatusCodeMapper implements CrudErrorMapper {
  const _StatusCodeMapper();

  @override
  CrudException map(Object error, StackTrace stackTrace) => error is _HttpError
      ? CrudException.fromStatusCode(error.statusCode, cause: error)
      : const DefaultCrudErrorMapper().map(error, stackTrace);
}
