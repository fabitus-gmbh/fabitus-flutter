import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:test/test.dart';

void main() {
  group('Sort', () {
    test('unsorted has no orders', () {
      const sort = Sort.unsorted;

      expect(sort.isUnsorted, isTrue);
      expect(sort.isSorted, isFalse);
      expect(sort.toQueryValue(), isEmpty);
    });

    test('by builds a single ascending order', () {
      expect(Sort.by('title').toQueryValue(), ['title,ASC']);
    });

    test('and concatenates orders in order', () {
      final sort = Sort.by(
        'createdAt',
        SortDirection.desc,
      ).and(Sort.by('title'));

      expect(sort.toQueryValue(), ['createdAt,DESC', 'title,ASC']);
    });

    test('ascending and descending force the direction', () {
      final sort = Sort.by('a', SortDirection.desc).and(Sort.by('b'));

      expect(sort.ascending().toQueryValue(), ['a,ASC', 'b,ASC']);
      expect(sort.descending().toQueryValue(), ['a,DESC', 'b,DESC']);
    });

    test('parse reads the query representation, direction optional', () {
      final sort = Sort.parse(['createdAt,DESC', 'title', '']);

      expect(sort.orders, [
        const SortOrder('createdAt', SortDirection.desc),
        const SortOrder('title'),
      ]);
    });

    test('equality is by value', () {
      expect(Sort.by('a'), Sort.by('a'));
      expect(Sort.by('a'), isNot(Sort.by('b')));
      expect(Sort.by('a').hashCode, Sort.by('a').hashCode);
    });
  });

  group('SortOrder', () {
    test('reversed flips the direction', () {
      expect(const SortOrder('a').reversed.direction, SortDirection.desc);
      expect(
        const SortOrder('a', SortDirection.desc).reversed.direction,
        SortDirection.asc,
      );
    });
  });

  group('SortDirection', () {
    test('wireValue is upper case', () {
      expect(SortDirection.asc.wireValue, 'ASC');
      expect(SortDirection.desc.wireValue, 'DESC');
    });

    test('fromJson accepts both cases and defaults to asc', () {
      expect(SortDirection.fromJson('DESC'), SortDirection.desc);
      expect(SortDirection.fromJson('desc'), SortDirection.desc);
      expect(SortDirection.fromJson('anything'), SortDirection.asc);
    });
  });
}
