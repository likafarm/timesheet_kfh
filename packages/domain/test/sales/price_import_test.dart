import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  group('разбор листа', () {
    test('как бумажный прайс: группа в столбце «№», дата «вводится с»', () {
      final rows = <List<String?>>[
        [null, null, 'ПРАЙС-ЛИСТ'],
        ['вводится с 01.03.2026 г.'],
        ['№ п\\п', 'Наименование продукции', 'Цена, руб.', 'Единица измерения'],
        ['Говядина охлаждённая'],
        ['1.', 'Вырезка', '1840', 'кг'],
        ['2.', 'Говядина охлаждённая (набор)', '920', 'кг'],
        ['Субпродукты говяжьи'],
        ['11.', 'Вымя', '400', 'кг'],
        ['12.', 'Голова', '1000', 'шт'],
        [],
        ['Глава КФХ', null, null, 'Лопатин И. И.'],
      ];
      final p = parsePriceSheet(rows);
      expect(p.validFrom, DateTime(2026, 3, 1));
      expect(p.groups.map((g) => g.name), [
        'Говядина охлаждённая',
        'Субпродукты говяжьи',
      ]);
      expect(p.productCount, 4);
      final head = p.groups.last.products.last;
      expect(
        (head.name, head.price, head.unit),
        ('Голова', 100000, ProductUnit.pcs),
      );
      expect(p.skipped, isEmpty);
    });

    test('как выгрузка программы: группа в столбце названия, числа Excel', () {
      final rows = <List<String?>>[
        ['Прайс-лист, вводится с 01.12.2026'],
        ['КФХ'],
        [],
        ['№', 'Наименование продукции', 'Цена, руб.', 'Единица', 'Изменение'],
        [null, 'Говядина охлаждённая'],
        ['1', 'Вырезка', '1932.5', 'кг', '0.05'],
        [],
        ['Выгружено 24.11.2026 18:00'],
      ];
      final p = parsePriceSheet(rows);
      expect(p.validFrom, DateTime(2026, 12, 1));
      expect(p.groups.single.products.single.price, 193250);
    });

    test('без групп, цена текстом, неразобранные строки — в пропущенных', () {
      final rows = <List<String?>>[
        ['Наименование', 'Цена', 'Ед.'],
        ['Тушёнка', '450 ₽', 'банка'],
        ['Колбаса', '1 600,00', 'кг'],
        ['Котлеты', 'договорная', 'кг'],
        ['Хвост', '400', 'метр'],
      ];
      final p = parsePriceSheet(rows);
      expect(p.validFrom, isNull);
      expect(p.groups.single.name, 'Без группы');
      expect(p.groups.single.products.map((x) => (x.price, x.unit)), [
        (45000, ProductUnit.can),
        (160000, ProductUnit.kg),
      ]);
      expect(p.skipped.length, 2);
    });

    test('нет заголовка — понятная ошибка', () {
      expect(
        () => parsePriceSheet([
          ['Вырезка', '1840'],
        ]),
        throwsA(isA<PriceImportException>()),
      );
    });
  });

  group('план загрузки', () {
    const meat = ProductGroup(id: 'g1', name: 'Говядина охлаждённая');
    final existing = [
      const Product(id: 'p1', groupId: 'g1', name: 'Вырезка'),
      const Product(id: 'p2', groupId: 'g1', name: 'Пашина', sortOrder: 1),
      const Product(id: 'p3', groupId: 'g1', name: 'Мосол', hidden: true),
    ];
    final prices = [
      ProductPrice(
        id: 'x1',
        productId: 'p1',
        validFrom: DateTime(2025, 5, 1),
        price: 160000,
      ),
      ProductPrice(
        id: 'x2',
        productId: 'p2',
        validFrom: DateTime(2025, 5, 1),
        price: 46000,
      ),
    ];
    var n = 0;
    String newId() => 'new${++n}';

    test('новые группы и товары, только изменённые цены', () {
      final file = parsePriceSheet([
        ['Наименование', 'Цена', 'Единица'],
        ['ГОВЯДИНА охлаждённая'],
        ['вырезка', '1840', 'кг'],
        ['Пашина', '460', 'кг'],
        ['Субпродукты говяжьи'],
        ['Голова', '1000', 'шт'],
        ['Мосол', '160', 'кг'],
      ]);
      final plan = planPriceImport(
        file: file,
        validFrom: DateTime(2026, 3, 1),
        groups: [meat],
        products: existing,
        prices: prices,
        newId: newId,
      );
      // Группа «ГОВЯДИНА охлаждённая» — та же (регистр не важен).
      expect(plan.groups.map((g) => g.name), ['Субпродукты говяжьи']);
      expect(plan.count(PriceImportAction.newProduct), 1);
      expect(plan.count(PriceImportAction.newPrice), 2);
      expect(plan.count(PriceImportAction.same), 1);
      expect(
        plan.lines.firstWhere((l) => l.item.name == 'вырезка').before,
        160000,
      );
      // Мосол был скрыт — снова продаётся и переезжает в новую группу.
      final mosol = plan.products.firstWhere((p) => p.id == 'p3');
      expect(mosol.hidden, isFalse);
      expect(mosol.groupId, plan.groups.single.id);
      // Цены: вырезка, голова, мосол — с 01.03.2026; пашина — та же.
      expect(plan.prices.map((p) => p.price).toSet(), {184000, 100000, 16000});
      expect(
        plan.prices.every((p) => p.validFrom == DateTime(2026, 3, 1)),
        isTrue,
      );
      expect(plan.missing, isEmpty);
    });

    test('товары программы, которых нет в файле, остаются как были', () {
      final plan = planPriceImport(
        file: parsePriceSheet([
          ['Наименование', 'Цена'],
          ['Вырезка', '1600'],
        ]),
        validFrom: DateTime(2026, 3, 1),
        groups: [meat],
        products: existing,
        prices: prices,
        newId: newId,
      );
      expect(plan.isEmpty, isFalse, reason: 'группа «Без группы» — новая');
      expect(plan.prices, isEmpty);
      expect(plan.missing.map((p) => p.name), ['Пашина']);
    });
  });
}
