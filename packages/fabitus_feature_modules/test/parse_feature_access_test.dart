import 'package:fabitus_feature_modules/fabitus_feature_modules.dart';
import 'package:test/test.dart';

import 'support/app.dart';

Map<Feature, FeatureAccess<Role>> parse(Object? json) =>
    parseFeatureAccess<Feature, Role>(json, featureFromJson: Feature.tryParse, roleFromJson: Role.tryParse);

void main() {
  test('reads a list of entries, each naming its feature', () {
    final access = parse(const [
      {
        'feature': 'RSS_MANAGEMENT',
        'navigation': ['editor'],
        'read': ['editor'],
        'delete': ['admin'],
      },
      {
        'feature': 'USER_MANAGEMENT',
        'read': ['admin'],
      },
    ]);

    expect(access.keys, {Feature.rss, Feature.users});
    expect(access[Feature.rss]!.read, {Role.editor});
    expect(access[Feature.rss]!.delete, {Role.admin});
    expect(access[Feature.users]!.navigation, isEmpty);
  });

  test('reads a map keyed by feature name', () {
    final access = parse(const {
      'RSS_MANAGEMENT': {
        'read': ['editor'],
      },
    });

    expect(access[Feature.rss]!.read, {Role.editor});
  });

  test('skips a feature this app does not know', () {
    final access = parse(const [
      {
        'feature': 'A_FEATURE_FROM_THE_FUTURE',
        'read': ['admin'],
      },
      {
        'feature': 'RSS_MANAGEMENT',
        'read': ['admin'],
      },
    ]);

    expect(access.keys, {Feature.rss});
  });

  test('skips an entry that does not name its feature', () {
    expect(
      parse(const [
        {
          'read': ['admin'],
        },
      ]),
      isEmpty,
    );
  });

  test('honours a custom feature key', () {
    final access = parseFeatureAccess<Feature, Role>(
      const [
        {
          'module': 'RSS_MANAGEMENT',
          'read': ['admin'],
        },
      ],
      featureFromJson: Feature.tryParse,
      roleFromJson: Role.tryParse,
      featureKey: 'module',
    );

    expect(access.keys, {Feature.rss});
  });

  test('a body that is neither list nor map yields nothing', () {
    expect(parse('nonsense'), isEmpty);
    expect(parse(null), isEmpty);
  });
}
