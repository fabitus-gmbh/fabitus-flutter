import 'dart:async';
import 'dart:convert';

import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

void main() {
  const mapper = DefaultCrudErrorMapper();
  final stackTrace = StackTrace.current;

  group('DefaultCrudErrorMapper', () {
    test('passes a CrudException through unchanged', () {
      const exception = CrudConflictException('duplicate');

      expect(mapper.map(exception, stackTrace), same(exception));
    });

    test('maps a TimeoutException', () {
      final mapped = mapper.map(TimeoutException('slow'), stackTrace);

      expect(mapped, isA<CrudTimeoutException>());
      expect(mapped.message, 'slow');
    });

    test('maps a FormatException', () {
      final mapped = mapper.map(const FormatException('bad json'), stackTrace);

      expect(mapped, isA<CrudSerializationException>());
    });

    test('maps a JsonUnsupportedObjectError', () {
      final mapped = mapper.map(
        JsonUnsupportedObjectError(Object()),
        stackTrace,
      );

      expect(mapped, isA<CrudSerializationException>());
    });

    test('falls back to unknown and keeps the cause', () {
      final cause = StateError('boom');

      final mapped = mapper.map(cause, stackTrace);

      expect(mapped, isA<CrudUnknownException>());
      expect(mapped.cause, same(cause));
    });
  });

  group('guardCrud', () {
    test('wraps a value in a success', () async {
      expect(await guardCrud(() async => 1), const CrudSuccess<int>(1));
    });

    test('wraps a thrown object in a failure', () async {
      final result = await guardCrud<int>(() async => throw StateError('boom'));

      expect(result.errorOrNull, isA<CrudUnknownException>());
    });

    test('uses the supplied mapper', () async {
      final result = await guardCrud<int>(
        () async => throw StateError('boom'),
        errorMapper: const _AlwaysConflict(),
      );

      expect(result.errorOrNull, isA<CrudConflictException>());
    });

    test('keeps the stack trace of the origin', () async {
      final result = await guardCrud<int>(() async => throw StateError('boom'));

      expect(
        (result as CrudFailure<int>).stackTrace.toString(),
        contains('crud_error_mapper_test.dart'),
      );
    });
  });
}

class _AlwaysConflict implements CrudErrorMapper {
  const _AlwaysConflict();

  @override
  CrudException map(Object error, StackTrace stackTrace) =>
      CrudConflictException('$error', cause: error);
}
