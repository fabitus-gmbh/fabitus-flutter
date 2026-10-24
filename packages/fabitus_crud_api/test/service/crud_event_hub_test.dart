import 'package:fabitus_crud_api/fabitus_crud_api.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import '../support/todo.dart';

/// Records what it was handed, under a shared log for order assertions.
class _RecordingListener implements CrudEventListener<Todo> {
  _RecordingListener(this.name, this.log);

  final String name;
  final List<String> log;

  @override
  void onCrudEvent(CrudEvent<Todo> event) => log.add(name);
}

class _ThrowingListener implements CrudEventListener<Todo> {
  @override
  void onCrudEvent(CrudEvent<Todo> event) => throw StateError('broken listener');
}

void main() {
  group('CrudEventHub', () {
    test('announces to the stream', () async {
      final hub = CrudEventHub<Todo>();
      addTearDown(hub.dispose);
      final events = <CrudEvent<Todo>>[];
      hub.events.listen(events.add);

      hub.announce(const CrudEvent<Todo>.deleted('1'));
      await pumpEventQueue();

      expect(events.single, isA<CrudEntityDeleted<Todo>>());
      expect((events.single as CrudEntityDeleted<Todo>).id, '1');
    });

    test('pushes to the listeners in order', () {
      final log = <String>[];
      final hub = CrudEventHub<Todo>(listeners: [_RecordingListener('first', log), _RecordingListener('second', log)]);
      addTearDown(hub.dispose);

      hub.announce(const CrudEvent<Todo>.created(Todo(id: '1', title: 'One')));

      expect(log, ['first', 'second']);
    });

    test('a throwing listener is logged and the ones behind it still hear', () {
      final log = <String>[];
      final records = <LogRecord>[];
      final subscription = crudLogger.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final hub = CrudEventHub<Todo>(
        listeners: [_RecordingListener('first', log), _ThrowingListener(), _RecordingListener('last', log)],
      );
      addTearDown(hub.dispose);

      hub.announce(const CrudEvent<Todo>.deleted('1'));

      expect(log, ['first', 'last']);
      expect(records.single.level, Level.SEVERE);
      expect(records.single.error, isA<StateError>());
    });

    test('the listener list is an unmodifiable copy', () {
      final given = <CrudEventListener<Todo>>[_RecordingListener('only', [])];
      final hub = CrudEventHub<Todo>(listeners: given);
      addTearDown(hub.dispose);
      given.clear();

      expect(hub.listeners, hasLength(1));
      expect(hub.listeners.clear, throwsUnsupportedError);
    });

    test('an announcement after dispose is dropped', () async {
      final log = <String>[];
      final hub = CrudEventHub<Todo>(listeners: [_RecordingListener('only', log)]);
      await hub.dispose();

      expect(hub.isDisposed, isTrue);
      hub.announce(const CrudEvent<Todo>.deleted('1'));

      expect(log, isEmpty);
    });
  });
}
