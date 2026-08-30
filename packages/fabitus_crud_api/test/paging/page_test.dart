import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

void main() {
  group('OffsetPage', () {
    test('derives totalPages and offset', () {
      const page = OffsetPage<int>(content: [1, 2], page: 1, size: 2, totalElements: 5);

      expect(page.offset, 2);
      expect(page.totalPages, 3);
      expect(page.length, 2);
      expect(page.isNotEmpty, isTrue);
    });

    test('hasNext uses the total when it is known', () {
      const middle = OffsetPage<int>(content: [1, 2], size: 2, totalElements: 5);
      const last = OffsetPage<int>(content: [5], page: 2, size: 2, totalElements: 5);

      expect(middle.hasNext, isTrue);
      expect(last.hasNext, isFalse);
      expect(last.isLast, isTrue);
    });

    test('hasNext falls back to a full page when no total is reported', () {
      const full = OffsetPage<int>(content: [1, 2], size: 2);
      const partial = OffsetPage<int>(content: [1], size: 2);

      expect(full.hasNext, isTrue);
      expect(partial.hasNext, isFalse);
    });

    test('totalPages is null without a total', () {
      expect(const OffsetPage<int>(content: [], size: 2).totalPages, isNull);
    });

    test('an empty page has no content and no next page', () {
      const page = OffsetPage<int>(size: 0);

      expect(page.isEmpty, isTrue);
      expect(page.hasNext, isFalse);
    });

    test('copyWith replaces a single member', () {
      const page = OffsetPage<int>(content: [1], size: 2, totalElements: 5);

      expect(page.copyWith(totalElements: 1).hasNext, isFalse);
      expect(page.copyWith(totalElements: 1).content, [1]);
    });

    test('nextPageRequest advances, and is null on the last page', () {
      const page = OffsetPage<int>(content: [1, 2], size: 2, totalElements: 5);
      const request = OffsetPageRequest(size: 2);

      expect((page.nextPageRequest(request)! as OffsetPageRequest).page, 1);
      expect(const OffsetPage<int>(content: [1], size: 2).nextPageRequest(request), isNull);
    });

    test('nextPageRequest converts a cursor request to an offset one', () {
      const page = OffsetPage<int>(content: [1, 2], size: 2, totalElements: 5);

      final next = page.nextPageRequest(const CursorPageRequest(size: 2));

      expect(next, isA<OffsetPageRequest>());
      expect((next! as OffsetPageRequest).page, 1);
    });

    test('map converts the content and keeps the metadata', () {
      const page = OffsetPage<int>(content: [1, 2], page: 1, size: 2, totalElements: 5);

      final mapped = page.map((value) => '$value') as OffsetPage<String>;

      expect(mapped.content, ['1', '2']);
      expect(mapped.page, 1);
      expect(mapped.totalElements, 5);
    });

    test('equality is by value', () {
      expect(const OffsetPage<int>(content: [1], size: 1), const OffsetPage<int>(content: [1], size: 1));
      expect(const OffsetPage<int>(content: [1], size: 1), isNot(const OffsetPage<int>(content: [2], size: 1)));
    });
  });

  group('CursorPage', () {
    test('hasNext requires a non empty cursor', () {
      expect(const CursorPage<int>(content: [1], nextCursor: 'abc').hasNext, isTrue);
      expect(const CursorPage<int>(content: [1]).hasNext, isFalse);
      expect(const CursorPage<int>(content: [1], nextCursor: '').hasNext, isFalse);
    });

    test('nextPageRequest carries the cursor over', () {
      const page = CursorPage<int>(content: [1], nextCursor: 'abc');

      final next = page.nextPageRequest(const CursorPageRequest(size: 2));

      expect((next! as CursorPageRequest).cursor, 'abc');
    });

    test('nextPageRequest converts an offset request to a cursor one', () {
      const page = CursorPage<int>(content: [1], nextCursor: 'abc');

      final next = page.nextPageRequest(const OffsetPageRequest(size: 2));

      expect(next, isA<CursorPageRequest>());
    });
  });

  group('Page.fromJson', () {
    int toInt(Object? json) => (json! as num).toInt();

    test('reads the Spring Data shape', () {
      final page = Page<int>.fromJson(const {
        'content': [1, 2],
        'number': 1,
        'size': 2,
        'totalElements': 5,
      }, toInt);

      expect(page, isA<OffsetPage<int>>());
      expect((page as OffsetPage<int>).page, 1);
      expect(page.totalElements, 5);
      expect(page.content, [1, 2]);
    });

    test('accepts items and data as the content key', () {
      expect(
        Page<int>.fromJson(const {
          'items': [1],
        }, toInt).content,
        [1],
      );
      expect(
        Page<int>.fromJson(const {
          'data': [2],
        }, toInt).content,
        [2],
      );
    });

    test('detects a cursor page from nextPageToken', () {
      final page = Page<int>.fromJson(const {
        'content': [1],
        'nextPageToken': 'abc',
      }, toInt);

      expect(page, isA<CursorPage<int>>());
      expect((page as CursorPage<int>).nextCursor, 'abc');
    });

    test('a cursor key with a null value marks the last page', () {
      final page = Page<int>.fromJson(const {
        'content': [1],
        'nextCursor': null,
      }, toInt);

      expect(page, isA<CursorPage<int>>());
      expect(page.hasNext, isFalse);
    });

    test('tolerates a missing content list', () {
      expect(Page<int>.fromJson(const {}, toInt).content, isEmpty);
    });

    test('round trips through toJson', () {
      const page = OffsetPage<int>(content: [1, 2], page: 1, size: 2, totalElements: 5);

      final json = page.toJson((value) => value);

      expect(Page<int>.fromJson(json, toInt), page);
    });
  });
}
