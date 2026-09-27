import 'auth_session.dart';

/// Hands out a session for outgoing requests and refreshes it on demand.
///
/// The seam between the session and the transport: an HTTP interceptor, such
/// as the one in `fabitus_cognito_auth_dio`, needs these three operations and
/// nothing else. `AuthCubit` implements it; a test double is a few lines.
abstract interface class AuthTokenSource {
  /// The session as it stands, without touching the network. `null` when
  /// nobody is signed in.
  AuthSession? get currentSession;

  /// A session that does not expire in the next moments, refreshing first if
  /// the current one is about to. `null` when nobody is signed in, or when the
  /// session ended during the refresh.
  ///
  /// Throws an `AuthException` when refreshing failed for a reason that does
  /// not end the session, a network failure above all.
  Future<AuthSession?> validSession();

  /// Refreshes the session now, whatever its expiry says - the move after the
  /// backend rejected a token. `null` when nobody is signed in, or when the
  /// session ended during the refresh.
  ///
  /// Concurrent calls share one refresh. Throws like [validSession].
  Future<AuthSession?> refresh();
}
