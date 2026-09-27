/// Why an authentication step failed.
///
/// An enum rather than a message on purpose: the package does not know your
/// app's language or tone, so it tells you *what* went wrong and you say it:
///
/// ```dart
/// String describe(AuthFailure failure) => switch (failure) {
///   AuthFailure.invalidCredentials => 'E-Mail oder Passwort ist ungültig.',
///   AuthFailure.sessionExpired => 'Deine Sitzung ist abgelaufen.',
///   _ => 'Anmeldung fehlgeschlagen. Bitte versuche es erneut.',
/// };
/// ```
enum AuthFailure {
  /// Username or password was left empty.
  missingCredentials,

  /// Username and password do not match, or the user does not exist. Cognito
  /// reports both the same way unless user existence errors are enabled, and
  /// the two are folded here either way so a login form cannot be used to probe
  /// for accounts.
  invalidCredentials,

  /// The user signed up but has not confirmed the account yet.
  userNotConfirmed,

  /// An administrator reset the password; the user has to set a new one
  /// through the forgot password flow before signing in.
  passwordResetRequired,

  /// The new password does not satisfy the password policy - either the local
  /// `PasswordPolicy` or, when that is missing or out of date, the user pool.
  invalidPassword,

  /// Too many attempts in a short time; Cognito throttles the user or the
  /// client.
  tooManyRequests,

  /// Cognito could not be reached.
  network,

  /// The refresh token was rejected - it expired, was revoked, or the user was
  /// disabled. The user has to sign in again.
  sessionExpired,

  /// Cognito asked for a challenge this package does not answer, such as an
  /// MFA code or a custom challenge.
  unsupportedChallenge,

  /// A new password arrived without a challenge to answer: the app restarted in
  /// the middle of the flow, or the challenge expired - Cognito keeps one for
  /// three minutes. Sign in again.
  noPendingChallenge,

  /// Anything else. The cause is kept on the exception.
  unknown,
}

/// An authentication step failed.
///
/// [failure] is what to branch on; [message] is Cognito's own wording, meant
/// for logs rather than for users; [cause] is the original error.
class AuthException implements Exception {
  /// Creates an exception for [failure].
  const AuthException(this.failure, {this.message, this.cause});

  /// Why the step failed.
  final AuthFailure failure;

  /// The message Cognito sent along, if any. English, and not meant for users.
  final String? message;

  /// The original error, when there was one.
  final Object? cause;

  /// Whether this failure ends the session rather than just failing one step.
  bool get endsSession => failure == AuthFailure.sessionExpired;

  @override
  bool operator ==(Object other) => other is AuthException && other.failure == failure && other.message == message;

  @override
  int get hashCode => Object.hash(failure, message);

  @override
  String toString() => message == null ? 'AuthException(${failure.name})' : 'AuthException(${failure.name}: $message)';
}
