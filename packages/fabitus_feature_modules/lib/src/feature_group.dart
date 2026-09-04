/// A heading several features appear under in the navigation.
///
/// Groups are what turns a flat list of modules into the sections a side
/// navigation is usually built from:
///
/// ```
/// Data
///   Todos
///   Invoices
/// Administration
///   Members
/// ```
///
/// [id] is identified by equality, so an `enum` of the app's own is the natural
/// choice. It is typed [Object] rather than a fifth type parameter: a group is
/// something you render a label for, not something you `switch` over
/// exhaustively. A module naming a group that was never declared is rejected
/// when the [FeatureRegistry] is built, so a typo still surfaces at startup
/// rather than as a silently missing menu entry.
///
/// ```dart
/// enum NavGroup { data, administration }
///
/// FeatureGroup<Widget>(
///   id: NavGroup.data,
///   heading: const NavSectionHeading('Data'),
/// );
/// ```
class FeatureGroup<TNav> {
  /// Declares a group, optionally with what the app renders as its heading.
  const FeatureGroup({required this.id, this.heading});

  /// Identifies the group, by equality. Typically an `enum` value.
  final Object id;

  /// What the app renders above the group's entries, or `null` for a group that
  /// only orders its features without a visible heading.
  final TNav? heading;

  @override
  String toString() => 'FeatureGroup($id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FeatureGroup<TNav> && other.id == id && other.heading == heading;

  @override
  int get hashCode => Object.hash(id, heading);
}

/// One feature's entry in the navigation, and which feature it belongs to.
///
/// The feature travels with the entry so the caller can mark the current one as
/// selected without matching on the widget.
class NavigationEntry<F extends Object, TNav> {
  /// Pairs [navigation] with the [feature] that declared it.
  const NavigationEntry({required this.feature, required this.navigation});

  /// The feature this entry opens.
  final F feature;

  /// What the app renders for it.
  final TNav navigation;

  @override
  String toString() => 'NavigationEntry($feature)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationEntry<F, TNav> && other.feature == feature && other.navigation == navigation;

  @override
  int get hashCode => Object.hash(feature, navigation);
}

/// One section of the navigation: a group and the entries visible under it.
///
/// A section with a `null` [group] holds the features that declared none; render
/// those at the top level, without a heading.
class NavigationSection<F extends Object, TNav> {
  /// Creates a section.
  const NavigationSection({required this.entries, this.group});

  /// The group these entries belong to, or `null` for the ungrouped ones.
  final FeatureGroup<TNav>? group;

  /// The entries the current user may see, in module order.
  ///
  /// Never empty: a section whose entries are all hidden is left out entirely,
  /// so a heading is never rendered over nothing.
  final List<NavigationEntry<F, TNav>> entries;

  /// What the app renders above [entries], or `null` when there is no heading.
  TNav? get heading => group?.heading;

  /// Whether these entries belong to a group.
  bool get isGrouped => group != null;

  @override
  String toString() => 'NavigationSection(${group?.id}, ${entries.length} entries)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationSection<F, TNav> && other.group == group && _entriesEqual(other.entries, entries);

  @override
  int get hashCode => Object.hash(group, Object.hashAll(entries));

  static bool _entriesEqual(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
