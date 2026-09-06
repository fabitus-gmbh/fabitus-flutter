import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:fabitus_crud_api_views/fabitus_crud_api_views.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/todo.dart';

void main() {
  group('sortStateFor', () {
    final sortable = TableColumn<Todo>(
      header: (_, _) => const SizedBox.shrink(),
      cell: (_, _) => const SizedBox.shrink(),
      sortKey: 'title',
    );
    final unsortable = TableColumn<Todo>(
      header: (_, _) => const SizedBox.shrink(),
      cell: (_, _) => const SizedBox.shrink(),
    );

    test('a column without a sortKey is unsortable', () {
      expect(unsortable.sortStateFor(Sort.by('title')), ColumnSortState.unsortable);
    });

    test('a column that is not the active one is merely sortable', () {
      expect(sortable.sortStateFor(Sort.unsorted), ColumnSortState.sortable);
      expect(sortable.sortStateFor(Sort.by('other')), ColumnSortState.sortable);
    });

    test('the active column reports its direction', () {
      expect(sortable.sortStateFor(Sort.by('title')), ColumnSortState.ascending);
      expect(sortable.sortStateFor(Sort.by('title', SortDirection.desc)), ColumnSortState.descending);
    });

    test('isActive is true only for the column being sorted by', () {
      expect(ColumnSortState.ascending.isActive, isTrue);
      expect(ColumnSortState.descending.isActive, isTrue);
      expect(ColumnSortState.sortable.isActive, isFalse);
      expect(ColumnSortState.unsortable.isActive, isFalse);
    });

    test('a multi order sort still finds this column', () {
      final sort = Sort.by('other').and(Sort.by('title', SortDirection.desc));

      expect(sortable.sortStateFor(sort), ColumnSortState.descending);
    });
  });

  group('nextSortFor', () {
    test('a fresh column sorts ascending', () {
      expect(nextSortFor('title', Sort.unsorted), Sort.by('title'));
      expect(nextSortFor('title', Sort.by('other')), Sort.by('title'));
    });

    test('the active ascending column flips to descending', () {
      expect(nextSortFor('title', Sort.by('title')), Sort.by('title', SortDirection.desc));
    });

    test('the active descending column flips back to ascending', () {
      expect(nextSortFor('title', Sort.by('title', SortDirection.desc)), Sort.by('title'));
    });

    test('sorting is single column, so tapping another replaces it', () {
      expect(nextSortFor('priority', Sort.by('title')).orders, hasLength(1));
    });
  });

  test('a column rejects a flex of zero', () {
    expect(
      () => TableColumn<Todo>(
        header: (_, _) => const SizedBox.shrink(),
        cell: (_, _) => const SizedBox.shrink(),
        flex: 0,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
