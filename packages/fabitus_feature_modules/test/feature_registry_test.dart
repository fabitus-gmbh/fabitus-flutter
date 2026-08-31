import 'package:fabitus_feature_modules/fabitus_feature_modules.dart';
import 'package:test/test.dart';

import 'support/app.dart';

void main() {
  const modules = [RssModule(), TaxonomyModule(), UsersModule()];

  /// What the backend sends: RSS and users, but nothing for taxonomy yet.
  final backendAccess = parseFeatureAccess<Feature, Role>(
    const [
      {
        'feature': 'RSS_MANAGEMENT',
        'navigation': ['editor', 'admin'],
        'read': ['editor', 'admin'],
        'create': ['admin'],
        'update': ['admin'],
        'delete': ['admin'],
      },
      {
        'feature': 'USER_MANAGEMENT',
        'read': ['admin'],
        'update': ['admin'],
      },
    ],
    featureFromJson: Feature.tryParse,
    roleFromJson: Role.tryParse,
  );

  AppRegistry build({Map<Feature, FeatureAccess<Role>>? access}) =>
      AppRegistry(modules: modules, access: access ?? backendAccess);

  group('construction', () {
    test('keeps the modules in order', () {
      expect(build().features, [Feature.rss, Feature.taxonomy, Feature.users]);
    });

    test('rejects two modules claiming the same feature', () {
      expect(
        () => AppRegistry(modules: const [RssModule(), RssModule()]),
        throwsA(isA<ArgumentError>().having((error) => error.message, 'message', contains('Feature.rss'))),
      );
    });

    test('works with no access configuration at all', () {
      final registry = AppRegistry(modules: modules);

      // The taxonomy module brings its own rights, the others have none.
      expect(registry.accessFor(Feature.rss).isDenied, isTrue);
      expect(registry.accessFor(Feature.taxonomy).isDenied, isFalse);
    });

    test('the module list is unmodifiable', () {
      expect(() => build().modules.add(const RssModule()), throwsUnsupportedError);
    });
  });

  group('accessFor', () {
    test('uses what the backend sent', () {
      expect(build().accessFor(Feature.rss).delete, {Role.admin});
    });

    test('falls back to the module while the backend sends none', () {
      expect(build().accessFor(Feature.taxonomy).read, {Role.editor, Role.admin, Role.support});
    });

    test('prefers the backend over the fallback once it arrives', () {
      final registry = build(
        access: {
          ...backendAccess,
          Feature.taxonomy: const FeatureAccess<Role>(read: {Role.admin}),
        },
      );

      expect(registry.accessFor(Feature.taxonomy).read, {Role.admin});
    });

    test('denies a feature no module claims', () {
      final registry = AppRegistry(modules: const [RssModule()]);

      expect(registry.accessFor(Feature.users).isDenied, isTrue);
      expect(registry.moduleFor(Feature.users), isNull);
    });

    test('denies a module the backend and the fallback both ignore', () {
      expect(build().accessFor(Feature.users).create, isEmpty);
    });
  });

  group('routes', () {
    test('collects every module\'s routes in module order', () {
      expect(build().routes, const [AppRoute('/rss'), AppRoute('/rss/:id'), AppRoute('/taxonomy'), AppRoute('/users')]);
    });

    test('is not filtered by the user, so a refusal is not a 404', () {
      // Nobody is logged in here, yet the router still knows every path.
      expect(build().routes, hasLength(4));
    });

    test('is unmodifiable', () {
      expect(() => build().routes.add(const AppRoute('/sneaky')), throwsUnsupportedError);
    });
  });

  group('navigationFor', () {
    test('shows what the roles are granted, in module order', () {
      expect(build().navigationFor(const [Role.editor]), const [NavEntry('RSS'), NavEntry('Taxonomies')]);
    });

    test('hides a module the roles are not granted', () {
      // Support sees taxonomy through the fallback, but not RSS.
      expect(build().navigationFor(const [Role.support]), const [NavEntry('Taxonomies')]);
    });

    test('leaves out a module that has no navigation entry', () {
      expect(build().navigationFor(const [Role.admin]), isNot(contains(const NavEntry('Users'))));
    });

    test('is empty for a user with no roles', () {
      expect(build().navigationFor(const []), isEmpty);
    });

    test('isNavigationVisible answers the same question for one feature', () {
      final registry = build();

      expect(registry.isNavigationVisible(Feature.rss, const [Role.editor]), isTrue);
      expect(registry.isNavigationVisible(Feature.rss, const [Role.support]), isFalse);
      expect(registry.isNavigationVisible(Feature.users, const [Role.admin]), isFalse);
    });
  });

  group('permissions', () {
    test('isAllowed answers one operation', () {
      final registry = build();

      expect(registry.isAllowed(Feature.rss, CrudOperation.read, const [Role.editor]), isTrue);
      expect(registry.isAllowed(Feature.rss, CrudOperation.delete, const [Role.editor]), isFalse);
      expect(registry.isAllowed(Feature.rss, CrudOperation.delete, const [Role.admin]), isTrue);
    });

    test('allowedOperations answers all of them at once', () {
      final registry = build();

      expect(registry.allowedOperations(Feature.rss, const [Role.editor]), {CrudOperation.read});
      expect(registry.allowedOperations(Feature.rss, const [Role.admin]), CrudOperation.values.toSet());
      expect(registry.allowedOperations(Feature.users, const [Role.admin]), {CrudOperation.read, CrudOperation.update});
    });

    test('an unknown feature is refused, not waved through', () {
      final registry = AppRegistry(modules: const [RssModule()]);

      for (final operation in CrudOperation.values) {
        expect(registry.isAllowed(Feature.users, operation, const [Role.admin]), isFalse, reason: '$operation');
      }
    });

    test('readableFeatures lists what the roles may open', () {
      final registry = build();

      expect(registry.readableFeatures(const [Role.editor]), [Feature.rss, Feature.taxonomy]);
      expect(registry.readableFeatures(const [Role.support]), [Feature.taxonomy]);
      expect(registry.readableFeatures(const []), isEmpty);
    });
  });

  group('toString', () {
    test('names the features it holds', () {
      expect(build().toString(), contains('Feature.rss'));
    });

    test('a module names its feature', () {
      expect(const RssModule().toString(), 'RssModule(Feature.rss)');
    });
  });
}
