import 'package:freezed_annotation/freezed_annotation.dart';

import 'auth_user.dart';
import 'jwt.dart';

part 'auth_session.freezed.dart';

/// Which Cognito token a request carries.
///
/// An API Gateway Cognito authorizer without OAuth scopes validates the id
/// token, which is why [id] is the default everywhere. Configure the authorizer
/// with scopes and it wants the [access] token instead.
enum AuthTokenType {
  /// The id token: who the user is, including groups and custom attributes.
  id,

  /// The access token: what the user may do, carrying the OAuth scopes.
  access,
}

/// The tokens of a signed in user.
///
/// Only the three tokens are stored; everything else - the [user], the expiry -
/// is read from them, so nothing can drift out of step with what the backend
/// sees.
///
/// [toString] redacts the tokens, so a session can be logged without leaking
/// credentials.
@Freezed(fromJson: false, toJson: false, toStringOverride: false)
abstract class AuthSession with _$AuthSession {
  /// Creates a session from the three Cognito tokens.
  const factory AuthSession({
    /// The id token.
    required String idToken,

    /// The access token.
    required String accessToken,

    /// The refresh token, which outlives the other two and fetches new ones.
    required String refreshToken,
  }) = _AuthSession;

  const AuthSession._();

  /// Reads a session from [toJson]'s output.
  ///
  /// The keys match the ones the `Auth` model of earlier apps used, so a
  /// session persisted by one of them is picked up as it is.
  ///
  /// Throws a [FormatException] when a token is missing.
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    String read(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('The session has no $key.');
      }
      return value;
    }

    return AuthSession(idToken: read('idToken'), accessToken: read('accessToken'), refreshToken: read('refreshToken'));
  }

  /// The JSON representation of this session.
  Map<String, dynamic> toJson() => {'idToken': idToken, 'accessToken': accessToken, 'refreshToken': refreshToken};

  /// The claims of the id token.
  Map<String, dynamic> get idTokenClaims => decodeJwtClaims(idToken);

  /// The claims of the access token.
  Map<String, dynamic> get accessTokenClaims => decodeJwtClaims(accessToken);

  /// The user the id token describes.
  AuthUser get user => AuthUser.fromClaims(idTokenClaims);

  /// The token of the given [type].
  String token(AuthTokenType type) => switch (type) {
    AuthTokenType.id => idToken,
    AuthTokenType.access => accessToken,
  };

  /// When the first of the id and access token expires.
  ///
  /// Cognito issues both with the same lifetime, but they are configured
  /// separately, so the earlier one is what counts.
  DateTime get expiresAt {
    final id = expiryOf(idTokenClaims);
    final access = expiryOf(accessTokenClaims);
    return id.isBefore(access) ? id : access;
  }

  /// Whether the tokens expire within [leeway] of [now] (default: the current
  /// time), or already have.
  ///
  /// A leeway of a minute or so absorbs clock skew and the time a request spends
  /// on the wire, so a token is not refreshed a second too late.
  bool expiresWithin(Duration leeway, {DateTime? now}) =>
      !expiresAt.isAfter((now ?? DateTime.now()).toUtc().add(leeway));

  @override
  String toString() {
    try {
      return 'AuthSession(user: ${user.username}, expiresAt: $expiresAt)';
    } on FormatException {
      return 'AuthSession(<malformed tokens>)';
    }
  }
}
