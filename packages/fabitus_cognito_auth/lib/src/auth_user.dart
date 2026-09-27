import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

/// The signed in user, as the Cognito id token describes them.
///
/// Never stored on its own: an [AuthSession] derives it from its id token, so it
/// is always exactly as current as the token the backend sees.
@Freezed(fromJson: false, toJson: false)
abstract class AuthUser with _$AuthUser {
  /// Creates a user.
  const factory AuthUser({
    /// The `cognito:username` claim - the name the user pool knows the user by.
    /// For a pool that signs in with email as an alias this is a UUID, not the
    /// email.
    required String username,

    /// The `sub` claim, the user's immutable id in the pool.
    required String subject,

    /// The `email` claim, when the pool has one.
    String? email,

    /// The `cognito:groups` claim, empty when the user is in no group.
    @Default(<String>[]) List<String> groups,

    /// Every claim of the id token, for custom attributes such as
    /// `custom:tenant`.
    @Default(<String, dynamic>{}) Map<String, dynamic> claims,
  }) = _AuthUser;

  const AuthUser._();

  /// Reads a user from the claims of a Cognito id token.
  factory AuthUser.fromClaims(Map<String, dynamic> claims) {
    final subject = (claims['sub'] ?? '') as String;
    final groups = claims['cognito:groups'];
    return AuthUser(
      username: (claims['cognito:username'] ?? subject) as String,
      subject: subject,
      email: claims['email'] as String?,
      groups: groups is List ? List<String>.unmodifiable(groups.cast<String>()) : const [],
      claims: Map<String, dynamic>.unmodifiable(claims),
    );
  }

  /// What to show as the user's name: the email when there is one, the
  /// username otherwise.
  String get displayName => email ?? username;

  /// Whether the user is in [group].
  bool isInGroup(String group) => groups.contains(group);
}
