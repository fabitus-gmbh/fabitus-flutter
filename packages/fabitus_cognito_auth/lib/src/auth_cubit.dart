import 'dart:async';

import 'package:bloc/bloc.dart';

import 'auth_exception.dart';
import 'auth_session.dart';
import 'auth_session_store.dart';
import 'auth_state.dart';
import 'auth_token_source.dart';
import 'cognito_auth_client.dart';
import 'password_policy.dart';

/// The app's session: sign in, the new password challenge, restore on start,
/// refresh and sign out.
///
/// One per app, created at startup and provided above the router, so the login
/// page, the route guard and the HTTP interceptor all see the same session:
///
/// ```dart
/// final auth = AuthCubit(client, store: store, passwordPolicy: policy);
/// await auth.restore();   // before the router reads auth.state
/// runApp(BlocProvider.value(value: auth, child: const App()));
/// ```
///
/// A `Cubit` rather than a `Bloc`, as elsewhere in these packages: each step is
/// a method that says what it does, and the interceptor can `await` a refresh
/// instead of firing an event and hoping.
///
/// Every session change goes to the [AuthSessionStore] - written on sign in and
/// refresh, cleared on sign out and expiry - in the order it happened. A store
/// that fails does not fail the step: the session lives on in memory, and the
/// error goes to [onError] and from there to the `BlocObserver`.
class AuthCubit extends Cubit<AuthState> implements AuthTokenSource {
  /// Creates a cubit on top of [client].
  ///
  /// Without a [store] the session is kept in memory only. With a
  /// [passwordPolicy], a new password that breaks it is rejected before it goes
  /// to Cognito. [expiryLeeway] is how close to expiry a token may get before
  /// [validSession] refreshes it.
  AuthCubit(
    this._client, {
    AuthSessionStore? store,
    this.passwordPolicy,
    this.expiryLeeway = const Duration(minutes: 1),
  }) : _store = store ?? InMemoryAuthSessionStore(),
       super(const AuthInitial());

  final CognitoAuthClient _client;
  final AuthSessionStore _store;

  /// The policy a new password is checked against before it is sent, if any.
  final PasswordPolicy? passwordPolicy;

  /// How close to expiry a token may get before [validSession] refreshes it.
  final Duration expiryLeeway;

  /// The NEW_PASSWORD_REQUIRED challenge waiting for an answer.
  NewPasswordRequired? _challenge;

  /// The refresh in flight, shared by everyone who asks meanwhile.
  Future<AuthSession?>? _refreshing;

  /// Counts sign ins and sign outs, so a Cognito response that arrives after the
  /// session it belongs to was replaced can be recognised and dropped.
  int _generation = 0;

  /// Store operations, chained so they land in the order they were issued.
  Future<void> _storeQueue = Future<void>.value();

  @override
  AuthSession? get currentSession => state.sessionOrNull;

  /// Picks up the stored session, refreshing it when it has expired.
  ///
  /// Call once at startup, before anything routes on [state]. Ends in
  /// [AuthAuthenticated] or [AuthUnauthenticated] - the latter with
  /// [AuthFailure.sessionExpired] when the stored session could not be revived.
  ///
  /// Offline, an expired session is restored as it is rather than thrown away:
  /// the first request refreshes it once the network is back.
  Future<void> restore() async {
    if (state is! AuthInitial) return;

    AuthSession? stored;
    try {
      stored = await _store.read();
    } on Object catch (e, stackTrace) {
      addError(e, stackTrace);
    }
    if (isClosed || state is! AuthInitial) return;
    if (stored == null) {
      emit(const AuthUnauthenticated());
      return;
    }

    final bool expired;
    try {
      expired = stored.expiresWithin(expiryLeeway);
    } on FormatException {
      await _end(null);
      return;
    }
    if (!expired) {
      emit(AuthAuthenticated(stored));
      return;
    }

    final generation = _generation;
    emit(const AuthInProgress(AuthStep.restore));
    try {
      final refreshed = await _client.refresh(stored);
      if (_isStale(generation)) return;
      await _authenticate(refreshed);
    } on AuthException catch (e) {
      if (_isStale(generation)) return;
      if (e.endsSession) {
        await _end(e);
      } else {
        emit(AuthAuthenticated(stored));
      }
    }
  }

  /// Signs in with [username] and [password].
  ///
  /// Ends in [AuthAuthenticated], in [AuthNewPasswordRequired] for a user with a
  /// temporary password, or in [AuthUnauthenticated] with the reason. The
  /// username is trimmed; the password is sent as it is.
  ///
  /// Ignored while another step is in progress.
  Future<void> signIn(String username, String password) async {
    if (state is AuthInProgress) return;
    final name = username.trim();
    if (name.isEmpty || password.isEmpty) {
      emit(const AuthUnauthenticated(error: AuthException(AuthFailure.missingCredentials)));
      return;
    }

    final generation = ++_generation;
    _challenge = null;
    emit(const AuthInProgress(AuthStep.signIn));
    try {
      final result = await _client.signIn(name, password);
      if (_isStale(generation)) return;
      switch (result) {
        case SignedIn(:final session):
          await _authenticate(session);
        case NewPasswordRequired() && final challenge:
          _challenge = challenge;
          emit(AuthNewPasswordRequired(requiredAttributes: challenge.requiredAttributes));
      }
    } on AuthException catch (e) {
      if (_isStale(generation)) return;
      emit(AuthUnauthenticated(error: e));
    }
  }

  /// Answers the NEW_PASSWORD_REQUIRED challenge with [newPassword], and any
  /// [attributes] the pool requires (see
  /// [AuthNewPasswordRequired.requiredAttributes]).
  ///
  /// A rejected password - by the [passwordPolicy] or by Cognito - keeps the
  /// challenge open: the state stays [AuthNewPasswordRequired], with the error.
  /// A challenge that is gone ends in [AuthUnauthenticated] with
  /// [AuthFailure.noPendingChallenge].
  ///
  /// Ignored while another step is in progress.
  Future<void> submitNewPassword(String newPassword, {Map<String, String> attributes = const {}}) async {
    if (state is AuthInProgress) return;
    final challenge = _challenge;
    if (challenge == null) {
      emit(const AuthUnauthenticated(error: AuthException(AuthFailure.noPendingChallenge)));
      return;
    }
    final unmet = passwordPolicy?.unmet(newPassword) ?? const [];
    if (unmet.isNotEmpty) {
      emit(
        AuthNewPasswordRequired(
          requiredAttributes: challenge.requiredAttributes,
          error: AuthException(AuthFailure.invalidPassword, message: 'Unmet: ${unmet.map((r) => r.name).join(', ')}'),
        ),
      );
      return;
    }

    final generation = _generation;
    emit(const AuthInProgress(AuthStep.newPassword));
    try {
      final session = await _client.completeNewPassword(challenge, newPassword, attributes: attributes);
      if (_isStale(generation)) return;
      _challenge = null;
      await _authenticate(session);
    } on AuthException catch (e) {
      if (_isStale(generation)) return;
      if (e.failure == AuthFailure.noPendingChallenge) {
        _challenge = null;
        emit(AuthUnauthenticated(error: e));
      } else {
        emit(AuthNewPasswordRequired(requiredAttributes: challenge.requiredAttributes, error: e));
      }
    }
  }

  /// Signs out: drops the session here and in the store.
  ///
  /// With [revoke], the refresh token is also revoked at Cognito, so a copy of
  /// it is worthless. That happens after the state changed - the user is signed
  /// out at once either way - and a failed revocation goes to [onError].
  Future<void> signOut({bool revoke = false}) async {
    final session = state.sessionOrNull;
    _generation++;
    _challenge = null;
    _refreshing = null;
    await _end(null);
    if (revoke && session != null) {
      try {
        await _client.revoke(session);
      } on AuthException catch (e, stackTrace) {
        addError(e, stackTrace);
      }
    }
  }

  @override
  Future<AuthSession?> validSession() async {
    final session = state.sessionOrNull;
    if (session == null) return null;
    try {
      if (!session.expiresWithin(expiryLeeway)) return session;
    } on FormatException {
      // Unreadable tokens: let the refresh decide.
    }
    return refresh();
  }

  @override
  Future<AuthSession?> refresh() {
    if (state.sessionOrNull == null) return Future.value();
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<AuthSession?> _refresh() async {
    final session = state.sessionOrNull!;
    final generation = _generation;
    try {
      final refreshed = await _client.refresh(session);
      if (_isStale(generation)) return state.sessionOrNull;
      await _authenticate(refreshed);
      return refreshed;
    } on AuthException catch (e) {
      if (_isStale(generation)) return state.sessionOrNull;
      if (!e.endsSession) rethrow;
      _generation++;
      await _end(e);
      return null;
    }
  }

  bool _isStale(int generation) => isClosed || generation != _generation;

  Future<void> _authenticate(AuthSession session) {
    emit(AuthAuthenticated(session));
    return _enqueue(() => _store.write(session));
  }

  Future<void> _end(AuthException? error) {
    if (!isClosed) emit(AuthUnauthenticated(error: error));
    return _enqueue(_store.clear);
  }

  Future<void> _enqueue(Future<void> Function() operation) => _storeQueue = _storeQueue.then((_) async {
    try {
      await operation();
    } on Object catch (e, stackTrace) {
      if (!isClosed) addError(e, stackTrace);
    }
  });
}
