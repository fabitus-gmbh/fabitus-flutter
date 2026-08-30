import 'package:collection/collection.dart';

/// The direction a property is sorted in.
enum SortDirection {
  /// Smallest value first.
  asc,

  /// Largest value first.
  desc;

  /// The wire representation, `ASC` or `DESC`, as used by Spring Data.
  String get wireValue => name.toUpperCase();

  /// Parses `asc`/`ASC` and `desc`/`DESC`, defaulting to [SortDirection.asc].
  static SortDirection fromJson(String json) =>
      json.toLowerCase() == 'desc' ? SortDirection.desc : SortDirection.asc;
}

/// A single `property, direction` pair.
class SortOrder {
  /// Sorts by [property] in the given [direction].
  const SortOrder(this.property, [this.direction = SortDirection.asc]);

  /// The name of the property to sort by, as the backend knows it.
  final String property;

  /// Whether to sort ascending or descending.
  final SortDirection direction;

  /// This order with the direction flipped.
  SortOrder get reversed => SortOrder(
    property,
    direction == SortDirection.asc ? SortDirection.desc : SortDirection.asc,
  );

  /// The Spring Data query representation, for example `createdAt,DESC`.
  String toQueryValue() => '$property,${direction.wireValue}';

  @override
  String toString() => toQueryValue();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortOrder &&
          other.property == property &&
          other.direction == direction;

  @override
  int get hashCode => Object.hash(property, direction);
}

/// An ordered list of [SortOrder]s, the equivalent of Spring's `Sort`.
///
/// ```dart
/// const Sort.unsorted();
/// Sort.by('title');
/// Sort.by('createdAt', SortDirection.desc).and(Sort.by('title'));
/// ```
class Sort {
  /// Creates a sort from an explicit list of [orders].
  const Sort(this.orders);

  /// A sort that imposes no order at all.
  const Sort.unsorted() : orders = const [];

  /// Sorts by a single [property].
  Sort.by(String property, [SortDirection direction = SortDirection.asc])
    : orders = [SortOrder(property, direction)];

  /// Parses the Spring Data query representation, for example
  /// `['createdAt,DESC', 'title']`.
  factory Sort.parse(List<String> values) => Sort([
    for (final value in values)
      if (value.isNotEmpty)
        SortOrder(
          value.split(',').first,
          value.contains(',')
              ? SortDirection.fromJson(value.split(',').last)
              : SortDirection.asc,
        ),
  ]);

  /// The orders, applied from first to last.
  final List<SortOrder> orders;

  /// Whether any order is defined.
  bool get isSorted => orders.isNotEmpty;

  /// Whether no order is defined.
  bool get isUnsorted => orders.isEmpty;

  /// This sort followed by the orders of [other].
  Sort and(Sort other) => Sort([...orders, ...other.orders]);

  /// This sort with every order forced to [SortDirection.asc].
  Sort ascending() =>
      Sort([for (final o in orders) SortOrder(o.property, SortDirection.asc)]);

  /// This sort with every order forced to [SortDirection.desc].
  Sort descending() =>
      Sort([for (final o in orders) SortOrder(o.property, SortDirection.desc)]);

  /// The Spring Data query representation, one entry per order.
  List<String> toQueryValue() =>
      orders.map((order) => order.toQueryValue()).toList(growable: false);

  @override
  String toString() => isUnsorted ? 'unsorted' : toQueryValue().join('; ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sort &&
          const ListEquality<SortOrder>().equals(other.orders, orders);

  @override
  int get hashCode => const ListEquality<SortOrder>().hash(orders);
}
