import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

void main() {
  const error = CrudNotFoundException('missing');
  final stackTrace = StackTrace.current;

  group('CrudSuccess', () {
    const result = CrudSuccess<int>(42);

    test('exposes the value', () {
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, 42);
      expect(result.errorOrNull, isNull);
      expect(result.getOrThrow(), 42);
      expect(result.getOrElse((_) => 0), 42);
    });

    test('map transforms the value', () {
      expect(result.map((value) => '$value'), const CrudSuccess<String>('42'));
    });

    test('fold takes the success branch', () {
      expect(result.fold(onSuccess: (value) => value * 2, onFailure: (_, _) => -1), 84);
    });

    test('equality is by value', () {
      expect(result, const CrudSuccess<int>(42));
      expect(result, isNot(const CrudSuccess<int>(43)));
    });
  });

  group('CrudFailure', () {
    late CrudFailure<int> result;

    setUp(() => result = CrudFailure<int>(error, stackTrace));

    test('exposes the error', () {
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull, error);
      expect(result.getOrElse((_) => 0), 0);
    });

    test('getOrThrow rethrows with the original stack trace', () {
      expect(result.getOrThrow, throwsA(same(error)));
    });

    test('map passes the failure through', () {
      final mapped = result.map((value) => '$value');

      expect(mapped, isA<CrudFailure<String>>());
      expect(mapped.errorOrNull, error);
    });

    test('cast retypes the failure', () {
      expect(result.cast<List<String>>(), isA<CrudFailure<List<String>>>());
    });

    test('fold takes the failure branch', () {
      expect(result.fold(onSuccess: (value) => value, onFailure: (e, _) => -1), -1);
    });
  });

  test('crudVoidSuccess is a successful void result', () {
    expect(crudVoidSuccess.isSuccess, isTrue);
  });
}
