import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

void main() {
  group('OffsetPageRequest', () {
    test('computes the offset from page and size', () {
      expect(const OffsetPageRequest(page: 3, size: 20).offset, 60);
    });

    test('copyWith clears a cursor when null is passed', () {
      const request = CursorPageRequest(size: 10, cursor: 'abc');

      expect(request.copyWith(cursor: null).cursor, isNull);
    });

    test('next and previous move by one page', () {
      const request = OffsetPageRequest(page: 1, size: 10);

      expect(request.next().page, 2);
      expect(request.previous().page, 0);
    });

    test('previous stays on the first page', () {
      const request = OffsetPageRequest(size: 10);

      expect(request.previous(), same(request));
    });

    test('toQueryParameters omits an unsorted sort', () {
      expect(const OffsetPageRequest(page: 2, size: 10).toQueryParameters(), {'page': 2, 'size': 10});
    });

    test('toQueryParameters includes the sort when present', () {
      expect(OffsetPageRequest(size: 10, sort: Sort.by('title')).toQueryParameters(), {
        'page': 0,
        'size': 10,
        'sort': ['title,ASC'],
      });
    });

    test('toJson matches toQueryParameters', () {
      const request = OffsetPageRequest(size: 5);

      expect(request.toJson(), request.toQueryParameters());
    });

    test('rejects a non positive size and a negative page', () {
      expect(() => OffsetPageRequest(size: 0), throwsA(isA<AssertionError>()));
      expect(() => OffsetPageRequest(page: -1, size: 5), throwsA(isA<AssertionError>()));
    });

    test('equality is by value', () {
      expect(const OffsetPageRequest(page: 1, size: 10), const OffsetPageRequest(page: 1, size: 10));
      expect(const OffsetPageRequest(page: 1, size: 10), isNot(const OffsetPageRequest(page: 2, size: 10)));
    });
  });

  group('CursorPageRequest', () {
    test('a null cursor requests the first page', () {
      const request = CursorPageRequest(size: 10);

      expect(request.isFirst, isTrue);
      expect(request.toQueryParameters(), {'size': 10});
    });

    test('copyWith carries size and sort over', () {
      final request = CursorPageRequest(size: 10, sort: Sort.by('title'));

      final next = request.copyWith(cursor: 'abc');

      expect(next.cursor, 'abc');
      expect(next.size, 10);
      expect(next.sort, Sort.by('title'));
      expect(next.toQueryParameters(), {
        'size': 10,
        'cursor': 'abc',
        'sort': ['title,ASC'],
      });
    });
  });
}
