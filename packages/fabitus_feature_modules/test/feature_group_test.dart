import 'package:fabitus_feature_modules/fabitus_feature_modules.dart';
import 'package:test/test.dart';

import 'support/app.dart';

void main() {
  const modules = [TodoModule(), LabelModule(), VisibleMemberModule()];

  AppRegistry build({
    Iterable<AppModule> modules = modules,
    Iterable<FeatureGroup<NavEntry>> groups = appGroups,
    Map<Feature, FeatureAccess<Role>>? access,
  }) => AppRegistry(
    modules: modules,
    groups: groups,
    access:
        access ??
        {
          Feature.todos: const FeatureAccess<Role>(
            navigation: {Role.viewer, Role.editor, Role.admin},
            read: {Role.viewer, Role.editor, Role.admin},
          ),
        },
  );

  group('declaration', () {
    test('keeps the groups in the order they were given', () {
      expect(build().groups.map((group) => group.id), [NavGroup.data, NavGroup.administration]);
    });

    test('rejects two groups with the same id', () {
      expect(
        () => build(
          groups: const [
            FeatureGroup<NavEntry>(id: NavGroup.data, heading: NavEntry('Data')),
            FeatureGroup<NavEntry>(id: NavGroup.data, heading: NavEntry('Again')),
          ],
        ),
        throwsA(isA<ArgumentError>().having((error) => error.message, 'message', contains('NavGroup.data'))),
      );
    });

    test('rejects a module naming a group that was not declared', () {
      expect(
        () => build(groups: const []),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            allOf(contains('TodoModule'), contains('NavGroup.data')),
          ),
        ),
      );
    });

    test('a declared group nobody names is simply unused', () {
      final registry = AppRegistry(modules: const [MemberModule()], groups: appGroups);

      expect(registry.navigationSectionsFor(const [Role.admin]), isEmpty);
    });

    test('works with no groups at all, as before', () {
      final registry = AppRegistry(
        modules: const [MemberModule()],
        access: {
          Feature.members: FeatureAccess<Role>.uniform(const {Role.admin}),
        },
      );

      expect(registry.groups, isEmpty);
      expect(registry.navigationFor(const [Role.admin]), isEmpty);
    });

    test('the group list is unmodifiable', () {
      expect(() => build().groups.add(const FeatureGroup<NavEntry>(id: NavGroup.data)), throwsUnsupportedError);
    });
  });

  group('navigationSectionsFor', () {
    test('collects the features of a group under one heading', () {
      final sections = build().navigationSectionsFor(const [Role.admin]);

      expect(sections.map((section) => section.group?.id), [NavGroup.data, NavGroup.administration]);
      expect(sections.first.heading, const NavEntry('Data'));
      expect(sections.first.entries.map((entry) => entry.feature), [Feature.todos, Feature.labels]);
      expect(sections.last.entries.map((entry) => entry.feature), [Feature.members]);
    });

    test('a section appears where its first visible module appears', () {
      // Declaration order interleaves the groups; the sections still collect.
      final registry = build(modules: const [TodoModule(), VisibleMemberModule(), LabelModule()]);

      final sections = registry.navigationSectionsFor(const [Role.admin]);

      expect(sections.map((section) => section.group?.id), [NavGroup.data, NavGroup.administration]);
      expect(sections.first.entries.map((entry) => entry.feature), [Feature.todos, Feature.labels]);
    });

    test('leaves out a section the user sees nothing in', () {
      // A viewer sees todos and labels, but nothing under Administration.
      final sections = build().navigationSectionsFor(const [Role.viewer]);

      expect(sections.map((section) => section.group?.id), [NavGroup.data]);
    });

    test('is empty for a user who sees nothing', () {
      expect(build().navigationSectionsFor(const []), isEmpty);
    });

    test('ungrouped features land in a section without a heading', () {
      final registry = build(
        modules: const [MemberModule(), TodoModule()],
        access: {
          Feature.members: FeatureAccess<Role>.uniform(const {Role.admin}),
          Feature.todos: FeatureAccess<Role>.uniform(const {Role.admin}),
        },
      );

      // MemberModule has no navigation entry, so only the grouped one shows.
      expect(registry.navigationSectionsFor(const [Role.admin]).single.group?.id, NavGroup.data);
    });

    test('an ungrouped entry keeps its place among the sections', () {
      final registry = build(
        modules: const [_UngroupedModule(), TodoModule()],
        access: {
          Feature.members: FeatureAccess<Role>.uniform(const {Role.admin}),
          Feature.todos: FeatureAccess<Role>.uniform(const {Role.admin}),
        },
      );

      final sections = registry.navigationSectionsFor(const [Role.admin]);

      expect(sections.first.isGrouped, isFalse);
      expect(sections.first.heading, isNull);
      expect(sections.first.entries.single.feature, Feature.members);
      expect(sections.last.group?.id, NavGroup.data);
    });

    test('the sections and their entries are unmodifiable', () {
      final sections = build().navigationSectionsFor(const [Role.admin]);

      expect(
        () => sections.first.entries.add(const NavigationEntry(feature: Feature.todos, navigation: NavEntry('x'))),
        throwsUnsupportedError,
      );
    });
  });

  group('the flat view still works', () {
    test('navigationFor ignores the groups', () {
      expect(build().navigationFor(const [Role.admin]), const [
        NavEntry('Todos'),
        NavEntry('Labels'),
        NavEntry('Members'),
      ]);
    });

    test('visibleEntriesFor pairs each entry with its feature', () {
      expect(build().visibleEntriesFor(const [Role.viewer]), const [
        NavigationEntry(feature: Feature.todos, navigation: NavEntry('Todos')),
        NavigationEntry(feature: Feature.labels, navigation: NavEntry('Labels')),
      ]);
    });
  });

  group('isGroupVisible', () {
    test('is true when one of the group\'s features is visible', () {
      final registry = build();

      expect(registry.isGroupVisible(NavGroup.data, const [Role.viewer]), isTrue);
      expect(registry.isGroupVisible(NavGroup.administration, const [Role.viewer]), isFalse);
      expect(registry.isGroupVisible(NavGroup.administration, const [Role.admin]), isTrue);
    });

    test('is false for a group nobody declared', () {
      expect(build().isGroupVisible('nonsense', const [Role.admin]), isFalse);
    });
  });

  group('featuresInGroup', () {
    test('lists what was declared under a group, in module order', () {
      expect(build().featuresInGroup(NavGroup.data), [Feature.todos, Feature.labels]);
      expect(build().featuresInGroup(NavGroup.administration), [Feature.members]);
      expect(build().featuresInGroup('nonsense'), isEmpty);
    });
  });

  group('value types', () {
    test('a FeatureGroup is equal by id and heading', () {
      expect(
        const FeatureGroup<NavEntry>(id: NavGroup.data, heading: NavEntry('Data')),
        const FeatureGroup<NavEntry>(id: NavGroup.data, heading: NavEntry('Data')),
      );
      expect(
        const FeatureGroup<NavEntry>(id: NavGroup.data),
        isNot(const FeatureGroup<NavEntry>(id: NavGroup.administration)),
      );
    });

    test('a NavigationSection is equal by group and entries', () {
      const section = NavigationSection<Feature, NavEntry>(
        group: FeatureGroup<NavEntry>(id: NavGroup.data),
        entries: [NavigationEntry(feature: Feature.todos, navigation: NavEntry('Todos'))],
      );

      expect(
        section,
        const NavigationSection<Feature, NavEntry>(
          group: FeatureGroup<NavEntry>(id: NavGroup.data),
          entries: [NavigationEntry(feature: Feature.todos, navigation: NavEntry('Todos'))],
        ),
      );
      expect(section, isNot(const NavigationSection<Feature, NavEntry>(entries: [])));
    });

    test('toString names what it holds', () {
      expect(const FeatureGroup<NavEntry>(id: NavGroup.data).toString(), 'FeatureGroup(NavGroup.data)');
      expect(
        build().navigationSectionsFor(const [Role.admin]).first.toString(),
        'NavigationSection(NavGroup.data, 2 entries)',
      );
    });
  });
}

/// A module with a navigation entry but no group.
class _UngroupedModule extends MemberModule {
  const _UngroupedModule();

  @override
  NavEntry? get navigation => const NavEntry('Settings');
}
