import '../core/crud_entity.dart';
import '../error/crud_exception.dart';
import '../paging/page.dart';
import '../paging/page_request.dart';
import '../paging/sort.dart';

/// Reads the value a [Sort] refers to from an entity.
///
/// The default implementation looks the property up in the entity's JSON, which
/// covers flat entities without any configuration.
typedef PropertyAccessor<T> = Object? Function(T entity, String property);

/// Sorts [entities] by [sort], without mutating the input list.
///
/// Values are compared with [Comparable]. `null` always sorts last, in both
/// directions, so an entity with a missing value stays at the bottom of a list
/// when the user flips the sort order. Throws [CrudUnsupportedException] when a
/// property holds values that cannot be compared.
List<T> sortEntities<T>(
  List<T> entities,
  Sort sort,
  PropertyAccessor<T> accessor,
) {
  if (sort.isUnsorted || entities.length < 2) {
    return List<T>.unmodifiable(entities);
  }
  final sorted = List<T>.of(entities);
  sorted.sort((a, b) {
    for (final order in sort.orders) {
      final left = accessor(a, order.property);
      final right = accessor(b, order.property);
      if (left == null || right == null) {
        // Decided before the direction is applied, so reversing the sort does
        // not promote missing values to the front.
        if (left == null && right == null) continue;
        return left == null ? 1 : -1;
      }
      final comparison = _compareValues(left, right, order.property);
      if (comparison != 0) {
        return order.direction == SortDirection.asc ? comparison : -comparison;
      }
    }
    return 0;
  });
  return List<T>.unmodifiable(sorted);
}

int _compareValues(Object left, Object right, String property) {
  if (left is Comparable<Object> && right is Comparable<Object>) {
    return left.compareTo(right);
  }
  throw CrudUnsupportedException(
    'Property "$property" holds values of type ${left.runtimeType} which are '
    'not Comparable and therefore cannot be sorted in memory',
  );
}

/// Slices [entities] according to [pageRequest] and wraps the result in a
/// [Page] of the matching flavour.
///
/// [entities] must already be sorted. For a [CursorPageRequest] the cursor is
/// the zero based index of the first element of the page, encoded as a string,
/// which keeps local stores compatible with cursor based callers.
Page<T> pageOf<T>(List<T> entities, PageRequest pageRequest) {
  final start = switch (pageRequest) {
    OffsetPageRequest(:final offset) => offset,
    CursorPageRequest(:final cursor) => _decodeCursor(cursor),
  };
  final clampedStart = start.clamp(0, entities.length);
  final end = (clampedStart + pageRequest.size).clamp(0, entities.length);
  final content = entities.sublist(clampedStart, end);
  return switch (pageRequest) {
    OffsetPageRequest(:final page, :final size) => OffsetPage<T>(
      content: content,
      page: page,
      size: size,
      totalElements: entities.length,
    ),
    CursorPageRequest() => CursorPage<T>(
      content: content,
      nextCursor: end < entities.length ? '$end' : null,
    ),
  };
}

int _decodeCursor(String? cursor) {
  if (cursor == null) return 0;
  final index = int.tryParse(cursor);
  if (index == null || index < 0) {
    throw CrudValidationException('Invalid cursor: "$cursor"');
  }
  return index;
}

/// The [PropertyAccessor] local repositories use when none is supplied.
///
/// Looks the property up in [CrudEntity.toJson], which covers flat entities
/// without any configuration. Pass an explicit accessor for nested properties
/// or for entities whose JSON keys differ from the ones the backend sorts by.
PropertyAccessor<T> jsonPropertyAccessor<T extends CrudEntity<Object>>() =>
    (entity, property) => entity.toJson()[property];
