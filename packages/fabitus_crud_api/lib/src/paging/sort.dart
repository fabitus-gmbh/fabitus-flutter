import 'package:freezed_annotation/freezed_annotation.dart';

part 'sort.freezed.dart';

/// The direction a property is sorted in.
enum SortDirection {
  /// Smallest value first.
  asc,

  /// Largest value first.
  desc;

  /// The wire representation, `ASC` or `DESC`, as used by Spring Data.
  String get wireValue => name.toUpperCase();

  /// Parses `asc`/`ASC` and `desc`/`DESC`, defaulting to [SortDirection.asc].
  static SortDirection fromJson(String json) => json.toLowerCase() == 'desc' ? SortDirection.desc : SortDirection.asc;
}

/// A single `property, direction` pair.
///
/// [toString] is the query representation, so an order reads as
/// `createdAt,DESC` in logs.
@Freezed(toStringOverride: false)
abstract class SortOrder with _$SortOrder {
  /// Sorts by [property] in the given [direction].
  const factory SortOrder(
    /// The name of the property to sort by, as the backend knows it.
    String property, [

    /// Whether to sort ascending or descending.
    @Default(SortDirection.asc) SortDirection direction,
  ]) = _SortOrder;

  const SortOrder._();

  /// This order with the direction flipped.
  SortOrder get reversed =>
      SortOrder(property, direction == SortDirection.asc ? SortDirection.desc : SortDirection.asc);

  /// The Spring Data query representation, for example `createdAt,DESC`.
  String toQueryValue() => '$property,${direction.wireValue}';

  @override
  String toString() => toQueryValue();
}

/// An ordered list of [SortOrder]s, the equivalent of Spring's `Sort`.
///
/// ```dart
/// Sort.unsorted;
/// Sort.by('title');
/// Sort.by('createdAt', SortDirection.desc).and(Sort.by('title'));
/// ```
@Freezed(toStringOverride: false)
abstract class Sort with _$Sort {
  /// Creates a sort from an explicit list of [orders].
  const factory Sort(
    /// The orders, applied from first to last.
    List<SortOrder> orders,
  ) = _Sort;

  const Sort._();

  /// Sorts by a single [property].
  factory Sort.by(String property, [SortDirection direction = SortDirection.asc]) =>
      Sort([SortOrder(property, direction)]);

  /// Parses the Spring Data query representation, for example
  /// `['createdAt,DESC', 'title']`.
  factory Sort.parse(List<String> values) => Sort([
    for (final value in values)
      if (value.isNotEmpty)
        SortOrder(
          value.split(',').first,
          value.contains(',') ? SortDirection.fromJson(value.split(',').last) : SortDirection.asc,
        ),
  ]);

  /// A sort that imposes no order at all.
  static const Sort unsorted = Sort([]);

  /// Whether any order is defined.
  bool get isSorted => orders.isNotEmpty;

  /// Whether no order is defined.
  bool get isUnsorted => orders.isEmpty;

  /// This sort followed by the orders of [other].
  Sort and(Sort other) => Sort([...orders, ...other.orders]);

  /// This sort with every order forced to [SortDirection.asc].
  Sort ascending() => Sort([for (final o in orders) SortOrder(o.property, SortDirection.asc)]);

  /// This sort with every order forced to [SortDirection.desc].
  Sort descending() => Sort([for (final o in orders) SortOrder(o.property, SortDirection.desc)]);

  /// The Spring Data query representation, one entry per order.
  List<String> toQueryValue() => orders.map((order) => order.toQueryValue()).toList(growable: false);

  @override
  String toString() => isUnsorted ? 'unsorted' : toQueryValue().join('; ');
}
