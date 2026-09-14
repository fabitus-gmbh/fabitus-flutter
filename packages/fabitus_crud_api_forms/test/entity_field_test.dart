import 'package:fabitus_crud_api_forms/fabitus_crud_api_forms.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/todo.dart';

/// A sealed entity with a property that only one variant has.
sealed class Page {
  const Page({this.id});
  final String? id;
}

class DossierPage extends Page {
  const DossierPage({super.id, this.dossierId});
  final String? dossierId;

  DossierPage copyWith({String? dossierId}) => DossierPage(id: id, dossierId: dossierId ?? this.dossierId);
}

class ArticlePage extends Page {
  const ArticlePage({super.id});
}

void main() {
  group('EntityField', () {
    test('reads the property off an entity', () {
      expect(titleField.read(const Todo(title: 'Hello')), 'Hello');
      expect(doneField.read(const Todo(done: true)), isTrue);
    });

    test('write returns a new entity, leaving the old one alone', () {
      const original = Todo(id: '1', title: 'Before');

      final updated = titleField.write(original, 'After');

      expect(updated.title, 'After');
      expect(updated.id, '1');
      expect(original.title, 'Before');
    });

    test('names itself in toString', () {
      expect(titleField.toString(), 'EntityField<Todo, String>(title)');
    });
  });

  group('EntityField.ofSubtype', () {
    final dossierId = EntityField.ofSubtype<DossierPage, Page, String>(
      name: 'dossierId',
      read: (page) => page.dossierId,
      write: (page, value) => page.copyWith(dossierId: value),
    );

    test('reads and writes on the variant it belongs to', () {
      const page = DossierPage(id: '1', dossierId: 'd1');

      expect(dossierId.read(page), 'd1');
      expect((dossierId.write(page, 'd2') as DossierPage).dossierId, 'd2');
    });

    test('reads null on another variant instead of throwing', () {
      expect(dossierId.read(const ArticlePage(id: '1')), isNull);
    });

    test('leaves another variant alone instead of throwing', () {
      const page = ArticlePage(id: '1');

      expect(dossierId.write(page, 'd2'), same(page));
    });
  });
}
