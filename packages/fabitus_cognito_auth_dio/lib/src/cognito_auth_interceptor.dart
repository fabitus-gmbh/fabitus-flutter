import 'package:dio/dio.dart';
import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';

/// Decides whether a request gets the token.
typedef AuthorizeRequest = bool Function(RequestOptions options);

/// Attaches the Cognito token to API requests and keeps it fresh.
///
/// - **Before a request** the session is refreshed when it is about to expire,
///   so the backend rarely sees a stale token at all.
/// - **On a 401** the session is refreshed once and the request retried with
///   the new token. When the refresh token itself is rejected the session ends
///   - the `AuthCubit` goes unauthenticated, which is what a router listens
///   to - and the 401 is passed on.
///
/// ```dart
/// final dio = Dio(BaseOptions(baseUrl: 'https://api.fabit.us/todos'));
/// dio.interceptors.add(CognitoAuthInterceptor(authCubit, dio: dio));
/// ```
///
/// Only requests to the API get the token: by default those whose URL lies
/// under their `baseUrl` (see [isUnderBaseUrl]). A Dio that also uploads to
/// presigned S3 URLs therefore keeps those free of an `Authorization` header,
/// which S3 would reject. A request that already carries the header is left
/// alone.
///
/// Concurrent 401s share one refresh, and a request that failed with a token
/// someone else has already replaced is retried with the new one without
/// refreshing again. A plain [Interceptor] rather than a [QueuedInterceptor] on
/// purpose: queuing every error behind a refresh that retries through the same
/// Dio deadlocks as soon as the retry fails.
///
/// A request whose body is a stream cannot be sent twice and is not retried
/// successfully; `FormData` is cloned for the retry.
class CognitoAuthInterceptor extends Interceptor {
  /// Creates an interceptor taking its tokens from [tokens] - usually the
  /// `AuthCubit` - and retrying through [dio].
  ///
  /// [tokenType] is the token the API Gateway authorizer validates: the id
  /// token for a Cognito authorizer without scopes, the access token for one
  /// with. [authorize] replaces the default choice of requests. [headerName]
  /// and [headerValue] shape the header; the default is
  /// `Authorization: Bearer <token>`.
  CognitoAuthInterceptor(
    this._tokens, {
    required Dio dio,
    this.tokenType = AuthTokenType.id,
    AuthorizeRequest authorize = isUnderBaseUrl,
    this.headerName = 'Authorization',
    String Function(String token) headerValue = bearer,
  }) : _dio = dio,
       _authorize = authorize,
       _headerValue = headerValue;

  final AuthTokenSource _tokens;
  final Dio _dio;
  final AuthorizeRequest _authorize;
  final String Function(String token) _headerValue;

  /// The token requests carry.
  final AuthTokenType tokenType;

  /// The header the token goes into.
  final String headerName;

  static const _sentTokenKey = 'fabitus_cognito_auth.sent_token';
  static const _retriedKey = 'fabitus_cognito_auth.retried';

  /// The default header value: `Bearer <token>`.
  static String bearer(String token) => 'Bearer $token';

  /// The default choice of requests: those whose URL has the scheme, host and
  /// port of their `baseUrl` and a path at or below its path.
  ///
  /// Compared part by part rather than as a string prefix, so
  /// `https://api.fabit.us.example.com` is not mistaken for
  /// `https://api.fabit.us`. A Dio without a `baseUrl` authorizes nothing -
  /// pass [authorize] to decide yourself.
  static bool isUnderBaseUrl(RequestOptions options) {
    if (options.baseUrl.isEmpty) return false;
    final base = Uri.parse(options.baseUrl);
    final target = options.uri;
    if (target.scheme != base.scheme || target.host != base.host || target.port != base.port) return false;
    final prefix = base.path.endsWith('/') ? base.path : '${base.path}/';
    return target.path == base.path || target.path.startsWith(prefix);
  }

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_authorize(options) || _hasHeader(options)) {
      handler.next(options);
      return;
    }

    AuthSession? session;
    try {
      session = await _tokens.validSession();
    } on AuthException {
      // Refreshing failed without ending the session - offline, most likely.
      // Send what there is and let the backend decide.
      session = _tokens.currentSession;
    }
    if (session != null) _attach(options, session);
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final sentToken = options.extra[_sentTokenKey];
    if (err.response?.statusCode != 401 || sentToken == null || options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }

    AuthSession? session;
    try {
      final current = _tokens.currentSession;
      session = current != null && current.token(tokenType) != sentToken ? current : await _tokens.refresh();
    } on AuthException {
      handler.next(err);
      return;
    }
    if (session == null) {
      handler.next(err);
      return;
    }

    final retry = options.copyWith(
      data: switch (options.data) {
        final FormData form => form.clone(),
        final data => data,
      },
      extra: {...options.extra, _retriedKey: true},
    );
    _attach(retry, session);
    try {
      handler.resolve(await _dio.fetch<dynamic>(retry));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _hasHeader(RequestOptions options) {
    final name = headerName.toLowerCase();
    return options.headers.keys.any((key) => key.toLowerCase() == name);
  }

  void _attach(RequestOptions options, AuthSession session) {
    final token = session.token(tokenType);
    options.headers[headerName] = _headerValue(token);
    options.extra[_sentTokenKey] = token;
  }
}
