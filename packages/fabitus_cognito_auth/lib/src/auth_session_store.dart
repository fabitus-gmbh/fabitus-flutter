import 'dart:async';
import 'dart:convert';

import 'auth_session.dart';

/// Where an `AuthCubit` keeps the session between app starts.
///
/// Kept this small so the package stays pure Dart: [KeyValueAuthSessionStore]
/// adapts `shared_preferences`, `flutter_secure_storage` or browser storage in
/// three lines, see the README.
abstract interface class AuthSessionStore {
  /// The stored session, or `null` when there is none.
  Future<AuthSession?> read();

  /// Stores [session], replacing anything stored before.
  Future<void> write(AuthSession session);

  /// Removes the stored session.
  Future<void> clear();
}

/// An [AuthSessionStore] that forgets everything on restart.
///
/// The default, and the store for tests.
class InMemoryAuthSessionStore implements AuthSessionStore {
  /// Creates a store, optionally holding [session] already.
  InMemoryAuthSessionStore([this.session]);

  /// The stored session, for assertions in tests.
  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}

/// An [AuthSessionStore] on top of any string key-value storage.
///
/// The session is stored as JSON under [key]. With `shared_preferences`:
///
/// ```dart
/// final prefs = SharedPreferencesAsync();
/// final store = KeyValueAuthSessionStore(
///   read: prefs.getString,
///   write: prefs.setString,
///   remove: prefs.remove,
/// );
/// ```
///
/// A stored value that cannot be read back - written by an older version, or
/// corrupted - counts as no session rather than an error, so the worst case is a
/// fresh login.
class KeyValueAuthSessionStore implements AuthSessionStore {
  /// Creates a store that goes through the three given functions.
  const KeyValueAuthSessionStore({
    required FutureOr<String?> Function(String key) read,
    required FutureOr<void> Function(String key, String value) write,
    required FutureOr<void> Function(String key) remove,
    this.key = 'fabitus_cognito_auth.session',
  }) : _read = read,
       _write = write,
       _remove = remove;

  final FutureOr<String?> Function(String key) _read;
  final FutureOr<void> Function(String key, String value) _write;
  final FutureOr<void> Function(String key) _remove;

  /// The key the session is stored under.
  final String key;

  @override
  Future<AuthSession?> read() async {
    final raw = await _read(key);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(json.decode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) async => _write(key, json.encode(session.toJson()));

  @override
  Future<void> clear() async => _remove(key);
}
