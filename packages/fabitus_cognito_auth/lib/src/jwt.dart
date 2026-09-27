import 'dart:convert';

import 'package:meta/meta.dart';

/// Reads the claims of a JSON Web Token without verifying its signature.
///
/// Verification is the backend's job - the API Gateway authorizer checks every
/// request. The client only needs the claims to know who is signed in and when
/// to refresh, and a forged token gains it nothing: the backend rejects it.
///
/// Throws a [FormatException] when [token] is not a JWT.
@internal
Map<String, dynamic> decodeJwtClaims(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw const FormatException('A JWT has three dot separated parts.');
  }
  final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
  final claims = json.decode(payload);
  if (claims is! Map<String, dynamic>) {
    throw const FormatException('The JWT payload is not a JSON object.');
  }
  return claims;
}

/// The `exp` claim of [claims] as a UTC [DateTime].
///
/// Throws a [FormatException] when the claim is missing, which a Cognito token
/// never is.
@internal
DateTime expiryOf(Map<String, dynamic> claims) {
  final exp = claims['exp'];
  if (exp is! num) {
    throw const FormatException('The JWT has no exp claim.');
  }
  return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
}
