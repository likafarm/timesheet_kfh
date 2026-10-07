import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

import 'fixture.dart';

void main() {
  group('allocate — копейки без потерь', () {
    test('ровные доли', () {
      expect(allocate(10000, [60, 40]), [6000, 4000]);
    });

    test('лишняя копейка — большему остатку', () {
      expect(allocate(1, [60, 40]), [1, 0]);
      expect(allocate(1, [40, 60]), [0, 1]);
      expect(allocate(1, [1, 1, 1]), [1, 0, 0]);
      expect(allocate(2, [1, 1, 1]), [1, 1, 0]);
      expect(allocate(100, [1, 1, 1]), [34, 33, 33]);
    });

    test('отрицательная сумма — со знаком', () {
      expect(allocate(-100, [1, 1, 1]), [-34, -33, -33]);
    });

    test('сумма частей всегда равна целому', () {
      for (final amount in [0, 1, 7, 99, 101, 12345, 80497100, 999999999]) {
        for (final weights in [
          [60, 40],
          [33, 33, 34],
          [1, 2, 3, 4],
          [100],
          [0, 100],
        ]) {
          final parts = allocate(amount, weights);
          expect(
            parts.fold(0, (a, b) => a + b),
            amount,
            reason: '$amount $weights',
          );
        }
      }
    });

    test('неверные доли', () {
      expect(() => allocate(1, []), throwsArgumentError);
      expect(() => allocate(1, [0, 0]), throwsArgumentError);
      expect(() => allocate(1, [-1, 2]), throwsArgumentError);
    });
  });

  group('splitByDirection', () {
    test('по статье', () {
      expect(splitByDirection(expense(film, 500), catalog), {crops: 500});
      expect(splitByDirection(income(meat, 500), catalog), {herd: 500});
    });

    test('ключ статьи: 60/40 в 2025, 70/30 с 2026', () {
      expect(splitByDirection(expense(fuel, 10001), catalog), {
        herd: 6001,
        crops: 4000,
      });
      final in2026 = expense(fuel, 10000, date: DateTime(2026, 3, 1));
      expect(splitByDirection(in2026, catalog), {herd: 7000, crops: 3000});
      final before = expense(fuel, 10000, date: DateTime(2024, 12, 31));
      expect(splitByDirection(before, catalog), {herd: 6000, crops: 4000});
    });

    test('порядок: явное → ключ → имущество → статья', () {
      expect(
        splitByDirection(
          expense(fuel, 100, direction: sales, asset: gazelle),
          catalog,
        ),
        {sales: 100},
      );
      expect(splitByDirection(expense(film, 100, key: tractors), catalog), {
        herd: 60,
        crops: 40,
      });
      expect(splitByDirection(expense(fuel, 100, asset: gazelle), catalog), {
        general: 100,
      });
      expect(splitByDirection(expense(fuel, 100, asset: press), catalog), {
        crops: 100,
      });
    });

    test('не определилось — отдельной строкой', () {
      expect(splitByDirection(expense(noDirection, 100), catalog), {
        unassignedDirection: 100,
      });
    });

    test('переводы и займы — не доход и не расход', () {
      expect(splitByDirection(transfer(cash, bank, 100), catalog), isEmpty);
      expect(
        splitByDirection(debt(loanTaken, DebtMove.take, 100), catalog),
        isEmpty,
      );
    });
  });

  group('accountBalances', () {
    final accounts = catalog.accounts.values;

    test('доход, расход, перевод, займ', () {
      final ops = [
        income(meat, 100000),
        expense(fuel, 30000),
        transfer(cash, bank, 50000),
        debt(loanTaken, DebtMove.take, 20000, account: card),
        debt(loanGiven, DebtMove.lend, 2000000, account: bank),
      ];
      final b = accountBalances(accounts, ops);
      expect(b[cash], 100000 - 30000 - 50000);
      expect(b[bank], 2900301 + 50000 - 2000000);
      expect(b[card], 20000);
    });

    test('кредитка уходит в минус — это долг банку', () {
      final ops = [
        expense(fuel, 5000, account: credit),
        transfer(card, credit, 2000),
      ];
      final b = accountBalances(accounts, ops);
      expect(b[credit], -3000);
      expect(b[card], -2000);
    });

    test('на дату: позже — не считается', () {
      final ops = [
        income(meat, 100, date: DateTime(2025, 6, 1)),
        income(meat, 1000, date: DateTime(2025, 7, 1)),
      ];
      expect(
        accountBalances(accounts, ops, at: DateTime(2025, 6, 30))[cash],
        100,
      );
      expect(
        accountBalances(accounts, ops, at: DateTime(2025, 7, 1))[cash],
        1100,
      );
    });

    test('начальный остаток — на начало дня, раньше операции не считаются', () {
      final ops = [
        income(meat, 999, account: bank, date: DateTime(2024, 12, 31)),
        income(meat, 1, account: bank, date: DateTime(2025, 1, 1)),
      ];
      expect(accountBalances(accounts, ops)[bank], 2900302);
      expect(
        accountBalances(accounts, ops, at: DateTime(2024, 12, 31))[bank],
        0,
      );
    });

    test('подотчёт: выдали и человек потратил', () {
      final ops = [
        transfer(cash, accountable, 10000),
        expense(fuel, 7000, account: accountable),
      ];
      final b = accountBalances(accounts, ops);
      expect(b[accountable], 3000);
      expect(b[cash], -10000);
    });
  });

  group('debtBalances', () {
    test('займ получен: взяли и вернули', () {
      final ops = [
        debt(loanTaken, DebtMove.take, 20000000),
        debt(loanTaken, DebtMove.repay, 5000000),
      ];
      final b = debtBalances(catalog.debts.values, ops);
      expect(b[loanTaken], 3500000000 + 20000000 - 5000000);
      expect(b[loanGiven], 0);
    });

    test('займ выдан: дали и нам вернули', () {
      final ops = [
        debt(loanGiven, DebtMove.lend, 2000000),
        debt(loanGiven, DebtMove.collect, 500000),
      ];
      expect(debtBalances(catalog.debts.values, ops)[loanGiven], 1500000);
    });

    test('займ меняет кошелёк, но не доходы и расходы', () {
      final ops = [debt(loanTaken, DebtMove.take, 20000)];
      final t = financeTotals(ops, catalog);
      expect(t.income, 0);
      expect(t.expense, 0);
      expect(t.debtIn, 20000);
      expect(t.result, 0);
      expect(accountBalances(catalog.accounts.values, ops)[cash], 20000);
    });
  });

  group('financeTotals', () {
    test('возвраты и капвложения — отдельно', () {
      final t = financeTotals([
        income(meat, 100000),
        income(refund, 5000),
        expense(fuel, 30000),
        expense(tractorPurchase, 15000000),
        transfer(cash, bank, 7000),
        debt(loanTaken, DebtMove.repay, 1000),
      ], catalog);
      expect(t.income, 100000);
      expect(t.refunds, 5000);
      expect(t.expense, 30000);
      expect(t.capex, 15000000);
      expect(t.transfers, 7000);
      expect(t.debtOut, 1000);
      expect(t.result, 100000 + 5000 - 30000 - 15000000);
    });
  });

  test('expensesByDirection — сумма по направлениям равна сумме расходов', () {
    final ops = [
      expense(fuel, 80497100),
      expense(mechanics, 139000000),
      expense(film, 30912000),
      expense(workers, 24666799),
      expense(fuel, 888200, asset: gazelle),
      expense(noDirection, 101),
      income(meat, 5000),
    ];
    final byDirection = expensesByDirection(ops, catalog);
    final total = ops
        .where((o) => o.type == OperationType.expense)
        .fold(0, (a, o) => a + o.amount);
    expect(byDirection.values.fold(0, (a, b) => a + b), total);
    expect(byDirection[general], 888200);
    expect(byDirection[unassignedDirection], 101);
  });

  group('сверка остатка', () {
    final ops = [income(meat, 100000), expense(fuel, 30000)];

    test('недостача — корректировка расходом', () {
      final r = reconcile(
        account: catalog.accounts[cash]!,
        operations: ops,
        date: day,
        actual: 65000,
      );
      expect(r.expected, 70000);
      expect(r.difference, -5000);
      final fix = reconciliationAdjustment(
        r,
        id: 'fix',
        incomeCategoryId: adjustIn,
        expenseCategoryId: adjustOut,
        directionId: general,
      )!;
      expect(fix.type, OperationType.expense);
      expect(fix.amount, 5000);
      expect(fix.categoryId, adjustOut);
      expect(operationProblem(fix, catalog), isNull);
      expect(
        accountBalances(catalog.accounts.values, [...ops, fix])[cash],
        65000,
      );
    });

    test('излишек — доходом, совпадение — без корректировки', () {
      final more = reconcile(
        account: catalog.accounts[cash]!,
        operations: ops,
        date: day,
        actual: 71000,
      );
      final fix = reconciliationAdjustment(
        more,
        id: 'fix',
        incomeCategoryId: adjustIn,
        expenseCategoryId: adjustOut,
        directionId: general,
      )!;
      expect(fix.type, OperationType.income);
      expect(fix.amount, 1000);
      final same = reconcile(
        account: catalog.accounts[cash]!,
        operations: ops,
        date: day,
        actual: 70000,
      );
      expect(
        reconciliationAdjustment(
          same,
          id: 'fix',
          incomeCategoryId: adjustIn,
          expenseCategoryId: adjustOut,
          directionId: general,
        ),
        isNull,
      );
    });
  });

  group('сезон урожая', () {
    test('по умолчанию — год операции, можно указать следующий', () {
      expect(
        expense(film, 1, date: DateTime(2025, 12, 5)).effectiveSeason,
        2025,
      );
      expect(
        expense(
          film,
          1,
          date: DateTime(2025, 12, 5),
          season: 2026,
        ).effectiveSeason,
        2026,
      );
    });
  });
}
