/// The minimal persistence primitive local repositories build on.
///
/// Keeping it this small is what lets this package stay pure Dart: adapters for
/// `shared_preferences`, browser `localStorage`, `flutter_secure_storage` or a
/// plain file are a handful of lines each and live in the app, not here. See
/// the package README for ready made adapters.
abstract interface class KeyValueStore {
  /// The value stored under [key], or `null` when there is none.
  Future<String?> read(String key);

  /// Stores [value] under [key], replacing anything stored before.
  Future<void> write(String key, String value);

  /// Removes [key] and its value.
  Future<void> remove(String key);
}

/// A [KeyValueStore] backed by a plain map.
///
/// The default store for tests and for prototypes that do not need to survive a
/// restart.
class InMemoryKeyValueStore implements KeyValueStore {
  /// Creates a store, optionally pre-filled with [initial].
  InMemoryKeyValueStore([Map<String, String> initial = const {}])
    : _values = Map<String, String>.of(initial);

  final Map<String, String> _values;

  /// The current contents, for assertions in tests.
  Map<String, String> get values => Map<String, String>.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
