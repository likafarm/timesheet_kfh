import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  final catalog = FinanceCatalog(
    groups: const [
      FinCategoryGroup(id: 'gi', type: CategoryType.income, name: 'Продажи'),
      FinCategoryGroup(
        id: 'ge',
        type: CategoryType.expense,
        name: 'Корма',
        sortOrder: 1,
      ),
    ],
    categories: const [
      FinCategory(
        id: 'meat',
        type: CategoryType.income,
        groupId: 'gi',
        group: 'Продажи',
        name: 'Мясо',
      ),
      FinCategory(
        id: 'feed',
        type: CategoryType.expense,
        groupId: 'ge',
        group: 'Корма',
        name: 'Комбикорм',
      ),
      FinCategory(
        id: 'rent',
        type: CategoryType.expense,
        group: 'Аренда',
        name: 'Аренда земли',
      ),
    ],
  );
  FinOperation op(String id, DateTime d, OperationType t, int k, String c) =>
      FinOperation(
        id: id,
        date: d,
        type: t,
        amount: k,
        accountId: 'a',
        categoryId: c,
      );
  final ops = [
    op('1', DateTime(2025, 3, 5), OperationType.income, 100049, 'meat'),
    op('2', DateTime(2026, 3, 5), OperationType.income, 120000, 'meat'),
    op('3', DateTime(2026, 3, 9), OperationType.expense, 30000, 'feed'),
  ];

  test('план и факт по статьям; статья только с планом — тоже', () {
    final r = budgetReport(
      year: 2026,
      entries: const [
        BudgetEntry(
          id: 'b1',
          year: 2026,
          month: 3,
          categoryId: 'meat',
          amount: 100000,
        ),
        BudgetEntry(
          id: 'b2',
          year: 2026,
          month: 4,
          categoryId: 'rent',
          amount: 50000,
        ),
        // Другой год — не входит.
        BudgetEntry(
          id: 'b3',
          year: 2025,
          month: 3,
          categoryId: 'feed',
          amount: 1,
        ),
      ],
      operations: ops,
      catalog: catalog,
    );
    final meat = r.income.groups.single.lines.single;
    expect(meat.planOf([3]), 100000);
    expect(meat.factOf([3]), 120000);
    expect(meat.factOf(), 120000);
    expect([for (final g in r.expense.groups) g.name], ['Корма', 'Аренда']);
    final rent = r.expense.groups.last.lines.single;
    expect(rent.planOf(), 50000);
    expect(rent.factOf(), 0);
    expect(r.expense.planOf([3, 4]), 50000);
    expect(r.expense.factOf([3, 4]), 30000);
  });

  test('план из факта прошлого года — до рубля', () {
    final plan = budgetFromFact(year: 2026, operations: ops, catalog: catalog);
    expect(plan.keys, ['meat']);
    expect(plan['meat']![2], 100000);
  });
}
