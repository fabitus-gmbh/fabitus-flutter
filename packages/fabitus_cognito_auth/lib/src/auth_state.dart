import 'auth_exception.dart';
import 'auth_session.dart';

/// Where an `AuthCubit` stands.
///
/// Sealed, so a `switch` over it is checked for exhaustiveness:
///
/// ```dart
/// switch (state) {
///   case AuthInitial() || AuthInProgress():
///     return const CircularProgressIndicator();
///   case AuthUnauthenticated(:final error):
///     return LoginForm(error: error?.failure);
///   case AuthNewPasswordRequired(:final error):
///     return NewPasswordForm(error: error?.failure);
///   case AuthAuthenticated(:final session):
///     return Text('Hello ${session.user.displayName}');
/// }
/// ```
sealed class AuthState {
  /// Creates a state.
  const AuthState();

  /// The current session, or `null` when nobody is signed in.
  AuthSession? get sessionOrNull => switch (this) {
    AuthAuthenticated(:final session) => session,
    _ => null,
  };

  /// Why the last step failed, or `null` when it did not.
  AuthException? get errorOrNull => switch (this) {
    AuthUnauthenticated(:final error) || AuthNewPasswordRequired(:final error) => error,
    _ => null,
  };

  /// Whether somebody is signed in.
  bool get isAuthenticated => this is AuthAuthenticated;

  /// Whether the stored session has been looked at yet. A router should hold
  /// off redirecting until it has.
  bool get isRestored => this is! AuthInitial;
}

/// The stored session has not been looked at yet - the state until
/// `AuthCubit.restore` has run.
final class AuthInitial extends AuthState {
  /// Creates the initial state.
  const AuthInitial();

  @override
  bool operator ==(Object other) => other is AuthInitial;

  @override
  int get hashCode => (AuthInitial).hashCode;

  @override
  String toString() => 'AuthInitial()';
}

/// A sign in, a new password or a session restore is on its way to Cognito.
final class AuthInProgress extends AuthState {
  /// Creates the in progress state.
  const AuthInProgress();

  @override
  bool operator ==(Object other) => other is AuthInProgress;

  @override
  int get hashCode => (AuthInProgress).hashCode;

  @override
  String toString() => 'AuthInProgress()';
}

/// Nobody is signed in.
final class AuthUnauthenticated extends AuthState {
  /// Creates the state, with the [error] that led here if there was one.
  const AuthUnauthenticated({this.error});

  /// Why the user is signed out: a failed sign in, or
  /// [AuthFailure.sessionExpired] after the session ended on its own. `null`
  /// after a deliberate sign out or when there was never a session.
  final AuthException? error;

  @override
  bool operator ==(Object other) => other is AuthUnauthenticated && other.error == error;

  @override
  int get hashCode => Object.hash(AuthUnauthenticated, error);

  @override
  String toString() => 'AuthUnauthenticated(error: $error)';
}

/// Cognito wants a new password before it completes the sign in.
///
/// Answer with `AuthCubit.submitNewPassword`.
final class AuthNewPasswordRequired extends AuthState {
  /// Creates the state, with the [error] of a rejected password if there was
  /// one.
  const AuthNewPasswordRequired({this.requiredAttributes = const [], this.error});

  /// User attributes the pool requires along with the password. Usually empty.
  final List<String> requiredAttributes;

  /// Why the last new password was rejected, `null` on the first attempt.
  final AuthException? error;

  @override
  bool operator ==(Object other) =>
      other is AuthNewPasswordRequired &&
      other.error == error &&
      _listEquals(other.requiredAttributes, requiredAttributes);

  @override
  int get hashCode => Object.hash(AuthNewPasswordRequired, error, Object.hashAll(requiredAttributes));

  @override
  String toString() => 'AuthNewPasswordRequired(requiredAttributes: $requiredAttributes, error: $error)';
}

/// Somebody is signed in.
final class AuthAuthenticated extends AuthState {
  /// Creates the state for [session].
  const AuthAuthenticated(this.session);

  /// The current session. Replaced, with a new state, on every refresh.
  final AuthSession session;

  @override
  bool operator ==(Object other) => other is AuthAuthenticated && other.session == session;

  @override
  int get hashCode => Object.hash(AuthAuthenticated, session);

  @override
  String toString() => 'AuthAuthenticated($session)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
