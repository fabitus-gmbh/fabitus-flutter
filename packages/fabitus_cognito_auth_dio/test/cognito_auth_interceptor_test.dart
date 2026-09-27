import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:fabitus_cognito_auth_dio/fabitus_cognito_auth_dio.dart';
import 'package:test/test.dart';

const _baseUrl = 'https://api.fabit.us/todos';

void main() {
  late _FakeTokens tokens;
  late _FakeBackend backend;
  late Dio dio;

  setUp(() {
    tokens = _FakeTokens(_session('id-1'));
    backend = _FakeBackend();
    dio = Dio(BaseOptions(baseUrl: _baseUrl))..httpClientAdapter = backend;
    dio.interceptors.add(CognitoAuthInterceptor(tokens, dio: dio));
  });

  group('onRequest', () {
    test('attaches the id token as a bearer token', () async {
      await dio.get<dynamic>('/1');

      expect(backend.authorizations, ['Bearer id-1']);
    });

    test('takes the session from validSession, so it is refreshed before it expires', () async {
      tokens.valid = _session('id-2');

      await dio.get<dynamic>('/1');

      expect(backend.authorizations, ['Bearer id-2']);
    });

    test('sends the current token when refreshing fails without ending the session', () async {
      tokens.validError = const AuthException(AuthFailure.network);

      await dio.get<dynamic>('/1');

      expect(backend.authorizations, ['Bearer id-1']);
    });

    test('sends no token when nobody is signed in', () async {
      tokens.current = null;

      await dio.get<dynamic>('/1');

      expect(backend.authorizations, [null]);
    });

    test('leaves requests outside the base URL alone', () async {
      await dio.put<dynamic>('https://bucket.s3.eu-central-1.amazonaws.com/part-1?X-Amz-Signature=abc');
      await dio.get<dynamic>('https://api.fabit.us.example.com/todos/1');
      await dio.get<dynamic>('https://api.fabit.us/todos-archive/1');

      expect(backend.authorizations, [null, null, null]);
    });

    test('leaves a request that brings its own header alone', () async {
      await dio.get<dynamic>('/1', options: Options(headers: {'authorization': 'Basic abc'}));

      expect(backend.authorizations, ['Basic abc']);
    });

    test('can send the access token in a custom header', () async {
      dio.interceptors
        ..clear()
        ..add(
          CognitoAuthInterceptor(
            tokens,
            dio: dio,
            tokenType: AuthTokenType.access,
            headerName: 'X-Auth',
            headerValue: (token) => token,
          ),
        );

      await dio.get<dynamic>('/1');

      expect(backend.requests.single.headers['X-Auth'], 'access-id-1');
    });
  });

  group('onError', () {
    test('refreshes once on a 401 and retries with the new token', () async {
      backend.respond = (options) => options.headers['Authorization'] == 'Bearer id-1' ? 401 : 200;
      tokens.refreshed = _session('id-2');

      final response = await dio.get<dynamic>('/1');

      expect(response.statusCode, 200);
      expect(backend.authorizations, ['Bearer id-1', 'Bearer id-2']);
      expect(tokens.refreshCalls, 1);
    });

    test('passes the 401 on when the session ended during the refresh', () async {
      backend.respond = (_) => 401;
      tokens.refreshed = null;

      await expectLater(dio.get<dynamic>('/1'), throwsA(_status(401)));
      expect(backend.requests, hasLength(1));
    });

    test('passes the 401 on when the refresh failed', () async {
      backend.respond = (_) => 401;
      tokens.refreshError = const AuthException(AuthFailure.network);

      await expectLater(dio.get<dynamic>('/1'), throwsA(_status(401)));
      expect(backend.requests, hasLength(1));
    });

    test('retries only once', () async {
      backend.respond = (_) => 401;
      tokens.refreshed = _session('id-2');

      await expectLater(dio.get<dynamic>('/1'), throwsA(_status(401)));
      expect(backend.authorizations, ['Bearer id-1', 'Bearer id-2']);
      expect(tokens.refreshCalls, 1);
    });

    test('reports the failure of the retry, not the 401', () async {
      backend.respond = (options) => options.headers['Authorization'] == 'Bearer id-1' ? 401 : 500;
      tokens.refreshed = _session('id-2');

      await expectLater(dio.get<dynamic>('/1'), throwsA(_status(500)));
    });

    test('reuses a token another request already refreshed', () async {
      backend.respond = (options) => options.headers['Authorization'] == 'Bearer id-1' ? 401 : 200;
      final gate = Completer<void>();
      backend.gate = gate.future;

      final request = dio.get<dynamic>('/1');
      while (backend.requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      tokens.current = _session('id-2'); // refreshed by someone else meanwhile
      gate.complete();
      await request;

      expect(backend.authorizations, ['Bearer id-1', 'Bearer id-2']);
      expect(tokens.refreshCalls, 0);
    });

    test('ignores other errors and requests without a token', () async {
      backend.respond = (_) => 403;
      await expectLater(dio.get<dynamic>('/1'), throwsA(_status(403)));

      backend.respond = (_) => 401;
      await expectLater(dio.get<dynamic>('https://other.fabit.us/x'), throwsA(_status(401)));

      expect(tokens.refreshCalls, 0);
    });

    test('clones FormData for the retry', () async {
      backend.respond = (options) => options.headers['Authorization'] == 'Bearer id-1' ? 401 : 200;
      tokens.refreshed = _session('id-2');

      final response = await dio.post<dynamic>('/upload', data: FormData.fromMap({'name': 'todo.txt'}));

      expect(response.statusCode, 200);
      expect(backend.requests, hasLength(2));
    });
  });
}

Matcher _status(int status) => isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', status);

/// An unsigned token whose only claim that matters is `exp`.
AuthSession _session(String id) => AuthSession(idToken: id, accessToken: 'access-$id', refreshToken: 'refresh');

class _FakeTokens implements AuthTokenSource {
  _FakeTokens(this.current);

  /// What [currentSession] returns.
  AuthSession? current;

  /// What [validSession] returns; [current] when unset.
  AuthSession? valid;

  /// What [validSession] throws, if anything.
  AuthException? validError;

  /// What [refresh] returns; it becomes [current] too.
  AuthSession? refreshed;

  /// What [refresh] throws, if anything.
  AuthException? refreshError;

  int refreshCalls = 0;

  @override
  AuthSession? get currentSession => current;

  @override
  Future<AuthSession?> validSession() async {
    if (validError case final error?) throw error;
    return valid ?? current;
  }

  @override
  Future<AuthSession?> refresh() async {
    refreshCalls++;
    if (refreshError case final error?) throw error;
    valid = null;
    return current = refreshed;
  }
}

/// Answers every request with the status [respond] picks, recording what it
/// received.
class _FakeBackend implements HttpClientAdapter {
  int Function(RequestOptions options) respond = (_) => 200;

  /// Holds the first request until it completes.
  Future<void>? gate;

  final List<RequestOptions> requests = [];

  /// The `Authorization` header of each request, as it was sent.
  final List<Object?> authorizations = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    authorizations.add(options.headers['Authorization']);
    if (requestStream != null) await requestStream.drain<void>();
    final pending = gate;
    gate = null;
    if (pending != null) await pending;
    return ResponseBody.fromString(
      json.encode({'ok': true}),
      respond(options),
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
