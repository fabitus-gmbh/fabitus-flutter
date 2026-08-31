import 'package:fabitus_feature_modules/fabitus_feature_modules.dart';
import 'package:test/test.dart';

import 'support/app.dart';

void main() {
  const access = FeatureAccess<Role>(
    navigation: {Role.editor, Role.admin},
    read: {Role.editor, Role.admin},
    create: {Role.admin},
    update: {Role.admin},
    delete: {Role.admin},
  );

  group('allows', () {
    test('grants an operation to a role listed for it', () {
      expect(access.allows(CrudOperation.read, const [Role.editor]), isTrue);
      expect(access.allows(CrudOperation.delete, const [Role.admin]), isTrue);
    });

    test('refuses an operation the role is not listed for', () {
      expect(access.allows(CrudOperation.delete, const [Role.editor]), isFalse);
    });

    test('refuses a user with no roles at all', () {
      for (final operation in CrudOperation.values) {
        expect(access.allows(operation, const []), isFalse, reason: '$operation');
      }
    });

    test('one matching role among several is enough', () {
      expect(access.allows(CrudOperation.delete, const [Role.support, Role.admin]), isTrue);
    });
  });

  group('operationsFor', () {
    test('collects everything a role may do', () {
      expect(access.operationsFor(const [Role.editor]), {CrudOperation.read});
      expect(access.operationsFor(const [Role.admin]), CrudOperation.values.toSet());
    });

    test('is empty for a role that is granted nothing', () {
      expect(access.operationsFor(const [Role.support]), isEmpty);
    });
  });

  group('allowsNavigation', () {
    test('is separate from read access', () {
      const hidden = FeatureAccess<Role>(read: {Role.support});

      expect(hidden.allows(CrudOperation.read, const [Role.support]), isTrue);
      expect(hidden.allowsNavigation(const [Role.support]), isFalse);
    });
  });

  group('the default constructor', () {
    const denied = FeatureAccess<Role>();

    test('grants nothing', () {
      expect(denied.isDenied, isTrue);
      expect(denied.allowsNavigation(const [Role.admin]), isFalse);
      expect(denied.operationsFor(const [Role.admin]), isEmpty);
      expect(denied.allRoles, isEmpty);
    });

    test('is not denied once anything is granted', () {
      expect(const FeatureAccess<Role>(read: {Role.admin}).isDenied, isFalse);
    });
  });

  group('uniform', () {
    test('grants everything to the given roles and nothing to others', () {
      final access = FeatureAccess<Role>.uniform(const {Role.admin});

      expect(access.operationsFor(const [Role.admin]), CrudOperation.values.toSet());
      expect(access.allowsNavigation(const [Role.admin]), isTrue);
      expect(access.operationsFor(const [Role.editor]), isEmpty);
    });
  });

  group('rolesFor and allRoles', () {
    test('rolesFor returns the set of one operation', () {
      expect(access.rolesFor(CrudOperation.create), {Role.admin});
    });

    test('allRoles collects every role named anywhere', () {
      expect(access.allRoles, {Role.editor, Role.admin});
    });
  });

  group('fromJson', () {
    test('reads the role lists', () {
      final parsed = FeatureAccess<Role>.fromJson(const {
        'navigation': ['editor', 'admin'],
        'read': ['editor', 'admin'],
        'create': ['admin'],
        'update': ['admin'],
        'delete': ['admin'],
      }, Role.tryParse);

      expect(parsed, access);
    });

    test('drops role names this app does not know', () {
      final parsed = FeatureAccess<Role>.fromJson(const {
        'read': ['admin', 'a-group-we-retired'],
      }, Role.tryParse);

      expect(parsed.read, {Role.admin});
    });

    test('treats a missing or malformed operation as empty', () {
      final parsed = FeatureAccess<Role>.fromJson(const {
        'read': ['admin'],
        'delete': 'nonsense',
      }, Role.tryParse);

      expect(parsed.read, {Role.admin});
      expect(parsed.delete, isEmpty);
      expect(parsed.create, isEmpty);
    });

    test('an empty body denies everything', () {
      expect(FeatureAccess<Role>.fromJson(const {}, Role.tryParse).isDenied, isTrue);
    });
  });

  group('equality', () {
    test('is by value, deep for the sets', () {
      expect(const FeatureAccess<Role>(read: {Role.admin}), const FeatureAccess<Role>(read: {Role.admin}));
      expect(const FeatureAccess<Role>(read: {Role.admin}), isNot(const FeatureAccess<Role>(read: {Role.editor})));
    });

    test('copyWith replaces a single operation', () {
      expect(access.copyWith(delete: const {Role.editor}).delete, {Role.editor});
      expect(access.copyWith(delete: const {Role.editor}).read, access.read);
    });
  });
}
