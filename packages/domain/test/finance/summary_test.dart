import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

import 'fixture.dart';

void main() {
  group('buildFinanceSummary', () {
    test('остатки на конец дня: позже — не считается', () {
      final ops = [
        income(meat, 100000),
        expense(fuel, 30000, date: DateTime(2025, 6, 11)),
        expense(fuel, 5000, account: credit),
      ];
      final s = buildFinanceSummary(
        catalog: catalog,
        operations: ops,
        day: day,
      );
      final byId = {for (final a in s.accounts) a.account.id: a.balance};
      expect(byId[cash], 100000);
      expect(byId[bank], 2900301);
      expect(byId[credit], -5000);
      // Итог — с минусом кредитки.
      expect(s.total, 100000 + 2900301 - 5000);
    });

    test('закрытый кошелёк — только с ненулевым остатком', () {
      final none = buildFinanceSummary(
        catalog: catalog,
        operations: const [],
        day: day,
      );
      expect(
        none.accounts.map((a) => a.account.id),
        isNot(contains(closedAccount)),
      );
      final some = buildFinanceSummary(
        catalog: catalog,
        operations: [income(meat, 100, account: closedAccount)],
        day: day,
      );
      expect(some.accounts.map((a) => a.account.id), contains(closedAccount));
    });

    test('займы: должны мы и должны нам, нулевые — не показываются', () {
      final ops = [
        debt(loanTaken, DebtMove.repay, 500000000),
        debt(loanGiven, DebtMove.lend, 2000000, account: bank),
      ];
      final s = buildFinanceSummary(
        catalog: catalog,
        operations: ops,
        day: day,
      );
      expect(s.weOwe, 3000000000);
      expect(s.owedToUs, 2000000);
      expect(s.debts.first.debt.id, loanTaken);

      final repaid = buildFinanceSummary(
        catalog: catalog,
        operations: [debt(loanTaken, DebtMove.repay, 3500000000)],
        day: day,
      );
      expect(repaid.debts, isEmpty);
      expect(repaid.weOwe, 0);
    });

    test('итоги месяца дня — без других месяцев', () {
      final ops = [
        income(meat, 100000),
        expense(fuel, 30000, date: DateTime(2025, 6, 30)),
        expense(tractorPurchase, 70000, date: DateTime(2025, 6, 1)),
        expense(fuel, 99999, date: DateTime(2025, 5, 31)),
        income(meat, 99999, date: DateTime(2025, 7, 1)),
      ];
      final s = buildFinanceSummary(
        catalog: catalog,
        operations: ops,
        day: day,
      );
      expect(s.month.income, 100000);
      expect(s.month.expense, 30000);
      expect(s.month.capex, 70000);
      expect(s.month.result, 0);
    });

    test('пустая база — сводка пустая', () {
      final s = buildFinanceSummary(
        catalog: FinanceCatalog(),
        operations: const [],
        day: day,
      );
      expect(s.isEmpty, isTrue);
      expect(s.total, 0);
    });
  });

  group('статьи и направление корректировки', () {
    test('по названию и виду', () {
      final c = FinanceCatalog(
        categories: const [
          FinCategory(
            id: 'in',
            type: CategoryType.income,
            group: '3',
            name: reconciliationSurplusCategory,
          ),
          FinCategory(
            id: 'out',
            type: CategoryType.expense,
            group: '08',
            name: reconciliationShortageCategory,
          ),
          // То же название, но не тот вид — не подходит.
          FinCategory(
            id: 'wrong',
            type: CategoryType.expense,
            group: '08',
            name: reconciliationSurplusCategory,
          ),
        ],
      );
      expect(reconciliationCategory(c, CategoryType.income)?.id, 'in');
      expect(reconciliationCategory(c, CategoryType.expense)?.id, 'out');
      expect(reconciliationCategory(catalog, CategoryType.income), isNull);
    });

    test('направление — общехозяйственное, иначе первое, иначе нет', () {
      expect(reconciliationDirection(catalog), general);
      expect(
        reconciliationDirection(
          FinanceCatalog(
            directions: const [
              FinDirection(id: 'b', name: 'Б', sortOrder: 2),
              FinDirection(id: 'a', name: 'А', sortOrder: 1),
            ],
          ),
        ),
        'a',
      );
      expect(reconciliationDirection(FinanceCatalog()), isNull);
    });
  });
}
