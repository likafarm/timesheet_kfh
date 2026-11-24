import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

/// Порядок групп и товаров перетаскиванием (11.1, просьба владельца
/// 2026-11-24).
void main() {
  const meat = ProductGroup(id: 'g1', name: 'Говядина');
  const offal = ProductGroup(id: 'g2', name: 'Субпродукты', sortOrder: 1);
  const a = Product(id: 'a', groupId: 'g1', name: 'Вырезка');
  const b = Product(id: 'b', groupId: 'g1', name: 'Мякоть', sortOrder: 1);
  const c = Product(id: 'c', groupId: 'g2', name: 'Печень');
  const d = Product(id: 'd', groupId: 'g2', name: 'Язык', sortOrder: 1);
  final groups = [offal, meat];
  final products = [d, c, b, a];

  // Список: 0 Говядина, 1 Вырезка, 2 Мякоть, 3 Субпродукты, 4 Печень, 5 Язык.
  test('список по порядку прайса', () {
    expect(catalogEntries(groups, products).map((e) => e.id), [
      'g:g1',
      'p:a',
      'p:b',
      'g:g2',
      'p:c',
      'p:d',
    ]);
  });

  test('товар внутри группы', () {
    // «Мякоть» выше «Вырезки».
    final r = reorderCatalog(
      groups: groups,
      products: products,
      oldIndex: 2,
      newIndex: 1,
    );
    expect(r.groups, isEmpty);
    expect({for (final p in r.products) p.id: p.sortOrder}, {'b': 0, 'a': 1});
  });

  test('товар в другую группу', () {
    // «Вырезка» — между «Печенью» и «Языком» (место — после удаления).
    final r = reorderCatalog(
      groups: groups,
      products: products,
      oldIndex: 1,
      newIndex: 4,
    );
    final byId = {for (final p in r.products) p.id: p};
    expect(byId['a']!.groupId, 'g2');
    expect(byId['a']!.sortOrder, 1);
    expect(byId['d']!.sortOrder, 2);
    expect(byId['b']!.sortOrder, 0, reason: 'мякоть стала первой');
    expect(byId.containsKey('c'), isFalse, reason: 'печень не сдвинулась');
  });

  test('группа переезжает вместе с товарами', () {
    // «Субпродукты» — наверх.
    final r = reorderCatalog(
      groups: groups,
      products: products,
      oldIndex: 3,
      newIndex: 0,
    );
    expect(r.products, isEmpty);
    expect({for (final g in r.groups) g.id: g.sortOrder}, {'g2': 0, 'g1': 1});
  });

  test('товар выше всех заголовков — в начало первой группы', () {
    final r = reorderCatalog(
      groups: groups,
      products: products,
      oldIndex: 4,
      newIndex: 0,
    );
    final byId = {for (final p in r.products) p.id: p};
    expect(byId['c']!.groupId, 'g1');
    expect(byId['c']!.sortOrder, 0);
    expect(byId['a']!.sortOrder, 1);
  });

  test('на то же место — ничего не меняется', () {
    final r = reorderCatalog(
      groups: groups,
      products: products,
      oldIndex: 2,
      newIndex: 2,
    );
    expect(r.groups, isEmpty);
    expect(r.products, isEmpty);
  });
}
