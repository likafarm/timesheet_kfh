import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

import 'fixture.dart';

FinOperation op(
  String id,
  DateTime date,
  OperationType type,
  int amount, {
  String? category,
  String? direction,
  String account = cash,
}) => FinOperation(
  id: id,
  date: date,
  type: type,
  amount: amount,
  accountId: account,
  categoryId: category,
  directionId: direction,
);

void main() {
  const e = OperationType.expense, i = OperationType.income;

  group('по статьям', () {
    final groups = FinanceCatalog(
      groups: const [
        FinCategoryGroup(
          id: 'g-tech',
          type: CategoryType.expense,
          name: '04. Техника',
          sortOrder: 2,
        ),
        FinCategoryGroup(
          id: 'g-feed',
          type: CategoryType.expense,
          name: '01. Корма',
          sortOrder: 1,
        ),
        FinCategoryGroup(
          id: 'g-sales',
          type: CategoryType.income,
          name: 'Реализация',
        ),
      ],
      categories: const [
        FinCategory(
          id: 'fuel',
          type: CategoryType.expense,
          groupId: 'g-tech',
          group: '04. Техника',
          name: 'ГСМ',
          sortOrder: 2,
        ),
        FinCategory(
          id: 'parts',
          type: CategoryType.expense,
          groupId: 'g-tech',
          group: '04. Техника',
          name: 'Запчасти',
          sortOrder: 1,
        ),
        FinCategory(
          id: 'tractor',
          type: CategoryType.expense,
          groupId: 'g-tech',
          group: '04. Техника',
          name: 'Трактор',
          kind: CategoryKind.capex,
          sortOrder: 3,
        ),
        FinCategory(
          id: 'feed',
          type: CategoryType.expense,
          groupId: 'g-feed',
          group: '01. Корма',
          name: 'Комбикорм',
        ),
        // Статья программы 1.18: группа — только текстом.
        FinCategory(
          id: 'old',
          type: CategoryType.expense,
          group: '99. Прочее',
          name: 'Разное',
        ),
        FinCategory(
          id: 'meat',
          type: CategoryType.income,
          groupId: 'g-sales',
          group: 'Реализация',
          name: 'Мясо',
        ),
        FinCategory(
          id: 'refund',
          type: CategoryType.income,
          groupId: 'g-sales',
          group: 'Реализация',
          name: 'Возвраты',
          kind: CategoryKind.refund,
        ),
        FinCategory(
          id: 'unused',
          type: CategoryType.expense,
          groupId: 'g-feed',
          group: '01. Корма',
          name: 'Сено',
        ),
      ],
    );
    final ops = [
      op('1', DateTime(2025, 1, 5), e, 10000, category: 'fuel'),
      op('2', DateTime(2025, 1, 20), e, 2500, category: 'fuel'),
      op('3', DateTime(2025, 3, 1), e, 700, category: 'parts'),
      op('4', DateTime(2025, 2, 1), e, 100000, category: 'tractor'),
      op('5', DateTime(2025, 2, 1), e, 3000, category: 'feed'),
      op('6', DateTime(2025, 3, 31), e, 50, category: 'old'),
      op('7', DateTime(2025, 1, 31), i, 400000, category: 'meat'),
      op('8', DateTime(2025, 3, 2), i, 900, category: 'refund'),
      op('9', DateTime(2025, 2, 2), e, 11),
      // Вне периода и не доходы/расходы — не входят.
      op('10', DateTime(2024, 12, 31), e, 1, category: 'fuel'),
      op('11', DateTime(2025, 4, 1), e, 1, category: 'fuel'),
      FinOperation(
        id: '12',
        date: DateTime(2025, 1, 2),
        type: OperationType.transfer,
        amount: 5000,
        accountId: cash,
        toAccountId: bank,
      ),
    ];
    final r = cashFlowReport(
      operations: ops,
      catalog: groups,
      from: DateTime(2025, 1, 15),
      count: 3,
    );

    test('месяцы с первого числа', () {
      expect(r.columns, [
        DateTime(2025, 1),
        DateTime(2025, 2),
        DateTime(2025, 3),
      ]);
    });

    test('группы по порядку справочника, статьи по порядку', () {
      final ex = r.expense.groups;
      expect(
        [for (final g in ex) g.name],
        ['01. Корма', '04. Техника', '99. Прочее', 'Без статьи'],
      );
      expect(
        [for (final l in ex[1].lines) l.name],
        ['Запчасти', 'ГСМ', 'Трактор'],
      );
      expect(ex[1].lines[1].values, [12500, 0, 0]);
      expect(ex[1].values, [12500, 100000, 700]);
      expect(ex[2].id, isNull);
      expect(ex[3].lines.single.id, noCategory);
      expect(ex[3].lines.single.values, [0, 11, 0]);
      expect(
        [for (final g in ex) ...g.lines].any((l) => l.id == 'unused'),
        isFalse,
        reason: 'статья без сумм не показывается',
      );
    });

    test('итоги разделов, «в т. ч.» и результат', () {
      expect(r.expense.values, [12500, 103011, 750]);
      expect(r.expense.special, [0, 100000, 0]);
      expect(r.expense.total, 116261);
      expect(r.income.values, [400000, 0, 900]);
      expect(r.income.special, [0, 0, 900]);
      expect(r.result, [387500, -103011, 150]);
      expect(r.resultTotal, r.income.total - r.expense.total);
    });

    test('пустой период', () {
      final empty = cashFlowReport(
        operations: ops,
        catalog: groups,
        from: DateTime(2030),
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.columns, hasLength(12));
      expect(empty.result, List.filled(12, 0));
    });
  });

  test('по направлениям: ключ делится по долям своего года', () {
    final r = cashFlowReport(
      operations: [
        op('1', DateTime(2025, 12, 1), e, 1001, category: fuel),
        op('2', DateTime(2026, 1, 1), e, 1000, category: fuel),
        op('3', DateTime(2026, 1, 2), i, 500, category: meat),
        op('4', DateTime(2026, 1, 3), e, 300, category: noDirection),
        op('5', DateTime(2026, 1, 4), e, 70, direction: general),
      ],
      catalog: catalog,
      from: DateTime(2025, 12),
      count: 2,
      by: CashFlowBy.direction,
    );
    final lines = r.expense.groups.single.lines;
    expect(
      [for (final l in lines) l.name],
      [
        // Порядок у всех 0 — по названию.
        'Животноводство',
        'Общехозяйственные',
        'Растениеводство (корма)',
        'Направление не определено',
      ],
    );
    expect(lines[0].values, [601, 700]);
    expect(lines[1].values, [0, 70]);
    expect(lines[2].values, [400, 300]);
    expect(lines[3].id, unassignedDirection);
    expect(r.expense.values, [1001, 1370]);
    expect(r.income.groups.single.lines.single.values, [0, 500]);
  });

  group('себестоимость кормов по сезонам', () {
    FinOperation seasonal(
      String id,
      DateTime date,
      OperationType type,
      int amount,
      String category, {
      int? season,
    }) => FinOperation(
      id: id,
      date: date,
      type: type,
      amount: amount,
      accountId: cash,
      categoryId: category,
      season: season,
    );

    final ops = [
      // ГСМ по ключу «Трактора»: растениеводству 40 % в 2025, 30 % в 2026.
      seasonal('1', DateTime(2025, 6, 1), e, 1000, fuel),
      // Плёнка, купленная зимой под урожай 2026 года.
      seasonal('2', DateTime(2025, 12, 20), e, 5000, film, season: 2026),
      seasonal('3', DateTime(2026, 7, 1), e, 1000, fuel),
      // Животноводство — не входит.
      seasonal('4', DateTime(2025, 7, 1), e, 777, workers),
      // Продажа излишков сена — выручка направления.
      FinOperation(
        id: '5',
        date: DateTime(2026, 9, 1),
        type: i,
        amount: 2000,
        accountId: cash,
        directionId: crops,
      ),
    ];

    test('доля направления по сезону урожая', () {
      final r = seasonCostReport(
        operations: ops,
        catalog: catalog,
        directionId: crops,
        lastSeason: 2026,
        count: 2,
      );
      expect(r.period, CashFlowPeriod.season);
      expect(r.columns, [DateTime(2025), DateTime(2026)]);
      expect(r.expense.values, [400, 5300]);
      final lines = [for (final g in r.expense.groups) ...g.lines];
      expect(
        {for (final l in lines) l.id: l.values},
        {
          fuel: [400, 300],
          film: [0, 5000],
        },
      );
      expect(r.income.values, [0, 2000]);
      expect(r.result, [-400, -3300]);
    });

    test('направление кормов по названию', () {
      expect(feedDirection(catalog), crops);
      expect(feedDirection(FinanceCatalog()), isNull);
    });
  });
}
