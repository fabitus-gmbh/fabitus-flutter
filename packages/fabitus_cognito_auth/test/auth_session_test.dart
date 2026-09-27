import 'dart:convert';

import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:test/test.dart';

import 'support/fake_cognito.dart';

void main() {
  group('AuthSession', () {
    test('reads the user from the id token', () {
      final user = sessionFor('jane', groups: ['admin', 'editor']).user;

      expect(user.username, 'jane');
      expect(user.subject, 'sub-jane');
      expect(user.email, 'jane@fabit.us');
      expect(user.displayName, 'jane@fabit.us');
      expect(user.isInGroup('admin'), isTrue);
      expect(user.isInGroup('viewer'), isFalse);
      expect(user.claims['cognito:username'], 'jane');
    });

    test('a user without email or groups falls back sensibly', () {
      final user = AuthUser.fromClaims(const {'sub': 'abc'});

      expect(user.username, 'abc');
      expect(user.displayName, 'abc');
      expect(user.groups, isEmpty);
    });

    test('expires at the earlier of the two tokens', () {
      final now = DateTime.utc(2026, 1, 1, 12);
      final session = AuthSession(
        idToken: jwt({'sub': 'a'}, expiresAt: now.add(const Duration(minutes: 30))),
        accessToken: jwt({'sub': 'a'}, expiresAt: now.add(const Duration(minutes: 10))),
        refreshToken: 'r',
      );

      expect(session.expiresAt, now.add(const Duration(minutes: 10)));
      expect(session.expiresWithin(const Duration(minutes: 5), now: now), isFalse);
      expect(session.expiresWithin(const Duration(minutes: 10), now: now), isTrue);
      expect(session.expiresWithin(Duration.zero, now: now.add(const Duration(hours: 1))), isTrue);
    });

    test('hands out the token of either type', () {
      final session = sessionFor('jane');

      expect(session.token(AuthTokenType.id), session.idToken);
      expect(session.token(AuthTokenType.access), session.accessToken);
    });

    test('round trips through json', () {
      final session = sessionFor('jane');

      expect(AuthSession.fromJson(json.decode(json.encode(session.toJson())) as Map<String, dynamic>), session);
    });

    test('reads the json the Auth model of earlier apps wrote', () {
      final session = sessionFor('jane');
      final legacy = {
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'idToken': session.idToken,
        'user': {'userName': 'jane@fabit.us', 'userId': 'jane', 'groups': <String>[]},
      };

      expect(AuthSession.fromJson(legacy), session);
    });

    test('json without a token is a format error', () {
      expect(() => AuthSession.fromJson(const {'idToken': 'x', 'accessToken': 'y'}), throwsFormatException);
    });

    test('toString does not leak tokens', () {
      final session = sessionFor('jane');

      expect(session.toString(), isNot(contains(session.idToken)));
      expect(session.toString(), isNot(contains(session.refreshToken)));
      expect(session.toString(), contains('jane'));
    });
  });

  group('KeyValueAuthSessionStore', () {
    late Map<String, String> values;
    late KeyValueAuthSessionStore store;

    setUp(() {
      values = {};
      store = KeyValueAuthSessionStore(
        read: (key) => values[key],
        write: (key, value) => values[key] = value,
        remove: values.remove,
      );
    });

    test('writes, reads and clears the session', () async {
      final session = sessionFor('jane');

      await store.write(session);
      expect(values.keys, ['fabitus_cognito_auth.session']);
      expect(await store.read(), session);

      await store.clear();
      expect(values, isEmpty);
      expect(await store.read(), isNull);
    });

    test('an unreadable value counts as no session', () async {
      values['fabitus_cognito_auth.session'] = 'not json';

      expect(await store.read(), isNull);
    });
  });
}
