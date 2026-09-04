import 'package:test/test.dart';

import 'support/app.dart';

/// Stands in for `get_it`, to show the hook needs no particular container.
class FakeLocator {
  final Map<Type, Object> _instances = {};
  final List<Type> registrations = [];

  void register<T extends Object>(T instance) {
    if (_instances.containsKey(T)) {
      throw StateError('$T is already registered');
    }
    _instances[T] = instance;
    registrations.add(T);
  }

  T get<T extends Object>() {
    final instance = _instances[T];
    if (instance == null) throw StateError('$T is not registered');
    return instance as T;
  }

  bool isRegistered<T extends Object>() => _instances.containsKey(T);
}

class TodoApi {
  const TodoApi();
}

class TodoRepository {
  const TodoRepository(this.api);

  final TodoApi api;
}

void main() {
  late FakeLocator locator;

  setUp(() => locator = FakeLocator());

  AppRegistry build(List<AppModule> modules) => AppRegistry(modules: modules, groups: appGroups);

  test('every module gets to register, in module order', () async {
    final calls = <String>[];
    final registry = build([
      _RecordingModule(Feature.todos, calls),
      _RecordingModule(Feature.labels, calls),
      _RecordingModule(Feature.members, calls),
    ]);

    await registry.registerDependencies();

    expect(calls, ['Feature.todos', 'Feature.labels', 'Feature.members']);
  });

  test('a module may rely on what an earlier one registered', () async {
    final registry = build([_ApiModule(Feature.todos, locator), _RepositoryModule(Feature.labels, locator)]);

    await registry.registerDependencies();

    expect(locator.isRegistered<TodoRepository>(), isTrue);
    expect(locator.get<TodoRepository>().api, isA<TodoApi>());
    expect(locator.registrations, [TodoApi, TodoRepository]);
  });

  test('a module registering out of order fails loudly', () async {
    // The repository comes first, so the api it needs is not there yet.
    final registry = build([_RepositoryModule(Feature.todos, locator), _ApiModule(Feature.labels, locator)]);

    await expectLater(registry.registerDependencies(), throwsA(isA<StateError>()));
  });

  test('an async registration is awaited before the next module runs', () async {
    final calls = <String>[];
    final registry = build([_SlowModule(Feature.todos, calls), _RecordingModule(Feature.labels, calls)]);

    await registry.registerDependencies();

    expect(calls, ['Feature.todos started', 'Feature.todos done', 'Feature.labels']);
  });

  test('what a module throws propagates, so startup fails', () async {
    final registry = build([_FailingModule(Feature.todos)]);

    await expectLater(
      registry.registerDependencies(),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('boom'))),
    );
  });

  test('a module that throws stops the ones behind it', () async {
    final calls = <String>[];
    final registry = build([_FailingModule(Feature.todos), _RecordingModule(Feature.labels, calls)]);

    await registry.registerDependencies().onError<StateError>((_, _) {});

    expect(calls, isEmpty);
  });

  test('modules that register nothing are the default', () async {
    final registry = build(const [TodoModule(), LabelModule()]);

    await expectLater(registry.registerDependencies(), completes);
  });

  test('a registry only asked about permissions needs no wiring', () {
    final registry = build([_FailingModule(Feature.todos)]);

    // registerDependencies was never called, so the failing module never ran.
    expect(registry.allowedOperations(Feature.todos, const [Role.admin]), isEmpty);
    expect(registry.routes, isEmpty);
  });
}

class _RecordingModule extends AppModule {
  const _RecordingModule(this._id, this._calls);

  final Feature _id;
  final List<String> _calls;

  @override
  Feature get id => _id;

  @override
  List<AppRoute> get routes => const [];

  @override
  Future<void> registerDependencies() async => _calls.add('$_id');
}

class _SlowModule extends AppModule {
  const _SlowModule(this._id, this._calls);

  final Feature _id;
  final List<String> _calls;

  @override
  Feature get id => _id;

  @override
  List<AppRoute> get routes => const [];

  @override
  Future<void> registerDependencies() async {
    _calls.add('$_id started');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _calls.add('$_id done');
  }
}

class _ApiModule extends AppModule {
  const _ApiModule(this._id, this._locator);

  final Feature _id;
  final FakeLocator _locator;

  @override
  Feature get id => _id;

  @override
  List<AppRoute> get routes => const [];

  @override
  Future<void> registerDependencies() async => _locator.register<TodoApi>(const TodoApi());
}

class _RepositoryModule extends AppModule {
  const _RepositoryModule(this._id, this._locator);

  final Feature _id;
  final FakeLocator _locator;

  @override
  Feature get id => _id;

  @override
  List<AppRoute> get routes => const [];

  @override
  Future<void> registerDependencies() async =>
      _locator.register<TodoRepository>(TodoRepository(_locator.get<TodoApi>()));
}

class _FailingModule extends AppModule {
  const _FailingModule(this._id);

  final Feature _id;

  @override
  Feature get id => _id;

  @override
  List<AppRoute> get routes => const [];

  @override
  Future<void> registerDependencies() async => throw StateError('boom');
}
