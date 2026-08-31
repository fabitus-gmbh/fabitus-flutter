import 'package:fabitus_feature_modules/fabitus_feature_modules.dart';
import 'package:test/test.dart';

import 'support/app.dart';

void main() {
  const modules = [TodoModule(), LabelModule(), MemberModule()];

  /// What the backend sends: todos and members, but nothing for labels yet.
  final backendAccess = parseFeatureAccess<Feature, Role>(
    const [
      {
        'feature': 'TODO_MANAGEMENT',
        'navigation': ['editor', 'admin'],
        'read': ['editor', 'admin'],
        'create': ['admin'],
        'update': ['admin'],
        'delete': ['admin'],
      },
      {
        'feature': 'MEMBER_MANAGEMENT',
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
      expect(build().features, [Feature.todos, Feature.labels, Feature.members]);
    });

    test('rejects two modules claiming the same feature', () {
      expect(
        () => AppRegistry(modules: const [TodoModule(), TodoModule()]),
        throwsA(isA<ArgumentError>().having((error) => error.message, 'message', contains('Feature.todos'))),
      );
    });

    test('works with no access configuration at all', () {
      final registry = AppRegistry(modules: modules);

      // The label module brings its own rights, the others have none.
      expect(registry.accessFor(Feature.todos).isDenied, isTrue);
      expect(registry.accessFor(Feature.labels).isDenied, isFalse);
    });

    test('the module list is unmodifiable', () {
      expect(() => build().modules.add(const TodoModule()), throwsUnsupportedError);
    });
  });

  group('accessFor', () {
    test('uses what the backend sent', () {
      expect(build().accessFor(Feature.todos).delete, {Role.admin});
    });

    test('falls back to the module while the backend sends none', () {
      expect(build().accessFor(Feature.labels).read, {Role.editor, Role.admin, Role.viewer});
    });

    test('prefers the backend over the fallback once it arrives', () {
      final registry = build(
        access: {
          ...backendAccess,
          Feature.labels: const FeatureAccess<Role>(read: {Role.admin}),
        },
      );

      expect(registry.accessFor(Feature.labels).read, {Role.admin});
    });

    test('denies a feature no module claims', () {
      final registry = AppRegistry(modules: const [TodoModule()]);

      expect(registry.accessFor(Feature.members).isDenied, isTrue);
      expect(registry.moduleFor(Feature.members), isNull);
    });

    test('denies a module the backend and the fallback both ignore', () {
      expect(build().accessFor(Feature.members).create, isEmpty);
    });
  });

  group('routes', () {
    test('collects every module\'s routes in module order', () {
      expect(build().routes, const [
        AppRoute('/todos'),
        AppRoute('/todos/:id'),
        AppRoute('/labels'),
        AppRoute('/members'),
      ]);
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
      expect(build().navigationFor(const [Role.editor]), const [NavEntry('Todos'), NavEntry('Labels')]);
    });

    test('hides a module the roles are not granted', () {
      // A viewer sees labels through the fallback, but not todos.
      expect(build().navigationFor(const [Role.viewer]), const [NavEntry('Labels')]);
    });

    test('leaves out a module that has no navigation entry', () {
      expect(build().navigationFor(const [Role.admin]), isNot(contains(const NavEntry('Members'))));
    });

    test('is empty for a user with no roles', () {
      expect(build().navigationFor(const []), isEmpty);
    });

    test('isNavigationVisible answers the same question for one feature', () {
      final registry = build();

      expect(registry.isNavigationVisible(Feature.todos, const [Role.editor]), isTrue);
      expect(registry.isNavigationVisible(Feature.todos, const [Role.viewer]), isFalse);
      expect(registry.isNavigationVisible(Feature.members, const [Role.admin]), isFalse);
    });
  });

  group('permissions', () {
    test('isAllowed answers one operation', () {
      final registry = build();

      expect(registry.isAllowed(Feature.todos, CrudOperation.read, const [Role.editor]), isTrue);
      expect(registry.isAllowed(Feature.todos, CrudOperation.delete, const [Role.editor]), isFalse);
      expect(registry.isAllowed(Feature.todos, CrudOperation.delete, const [Role.admin]), isTrue);
    });

    test('allowedOperations answers all of them at once', () {
      final registry = build();

      expect(registry.allowedOperations(Feature.todos, const [Role.editor]), {CrudOperation.read});
      expect(registry.allowedOperations(Feature.todos, const [Role.admin]), CrudOperation.values.toSet());
      expect(registry.allowedOperations(Feature.members, const [Role.admin]), {
        CrudOperation.read,
        CrudOperation.update,
      });
    });

    test('an unknown feature is refused, not waved through', () {
      final registry = AppRegistry(modules: const [TodoModule()]);

      for (final operation in CrudOperation.values) {
        expect(registry.isAllowed(Feature.members, operation, const [Role.admin]), isFalse, reason: '$operation');
      }
    });

    test('readableFeatures lists what the roles may open', () {
      final registry = build();

      expect(registry.readableFeatures(const [Role.editor]), [Feature.todos, Feature.labels]);
      expect(registry.readableFeatures(const [Role.viewer]), [Feature.labels]);
      expect(registry.readableFeatures(const []), isEmpty);
    });
  });

  group('toString', () {
    test('names the features it holds', () {
      expect(build().toString(), contains('Feature.todos'));
    });

    test('a module names its feature', () {
      expect(const TodoModule().toString(), 'TodoModule(Feature.todos)');
    });
  });
}
