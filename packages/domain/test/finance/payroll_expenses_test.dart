import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

import 'fixture.dart';

void main() {
  final employees = {
    'e1': Employee(
      id: 'e1',
      fullName: 'Иванов И.',
      position: ' Механизатор ',
      hireDate: DateTime(2024, 1, 1),
      baseRate: 2000,
      fieldRate: 3000,
    ),
    'e2': Employee(
      id: 'e2',
      fullName: 'Петров П.',
      position: 'Скотник',
      hireDate: DateTime(2024, 1, 1),
      baseRate: 2000,
      fieldRate: 3000,
    ),
  };
  final mapping = PayrollFinanceMapping(
    methodAccounts: const {'cash': cash, 'card': card},
    defaultAccountId: cash,
    positionCategories: const {'механизатор': mechanics},
    defaultCategoryId: workers,
  );

  test('выплата — расход: кошелёк по способу, статья по должности', () {
    final ops = payrollExpenses(
      [
        Payment(
          id: 'p1',
          employeeId: 'e1',
          paymentDate: DateTime(2026, 7, 31),
          amount: 17000.5,
          paymentMethod: 'card',
        ),
        Payment(
          id: 'p2',
          employeeId: 'e2',
          paymentDate: DateTime(2026, 7, 31),
          amount: 9000,
          paymentType: 'advance',
          paymentMethod: 'transfer',
        ),
      ],
      employees,
      mapping,
    );
    expect(ops, hasLength(2));
    final first = ops.first;
    expect(first.id, 'payroll:p1');
    expect(first.type, OperationType.expense);
    expect(first.amount, 1700050);
    expect(first.accountId, card);
    expect(first.categoryId, mechanics);
    expect(first.employeeId, 'e1');
    expect(first.source, OperationSource.payroll);
    expect(first.sourceRef, 'p1');
    expect(first.description, 'Зарплата: Иванов И.');
    expect(operationProblem(first, catalog), isNull);

    final second = ops.last;
    expect(second.accountId, cash, reason: 'способ не сопоставлен');
    expect(second.categoryId, workers, reason: 'должность не сопоставлена');
    expect(second.description, 'Аванс: Петров П.');
  });

  test('механизаторы раскладываются по ключу, рабочие — животноводство', () {
    final ops = payrollExpenses(
      [
        Payment(id: 'p1', employeeId: 'e1', paymentDate: day, amount: 1000),
        Payment(id: 'p2', employeeId: 'e2', paymentDate: day, amount: 500),
      ],
      employees,
      mapping,
    );
    expect(expensesByDirection(ops, catalog), {
      herd: 60000 + 50000,
      crops: 40000,
    });
  });

  test('выплаты уменьшают остаток кошелька', () {
    final ops = payrollExpenses(
      [
        Payment(
          id: 'p1',
          employeeId: 'e2',
          paymentDate: day,
          amount: 300,
          paymentMethod: 'cash',
        ),
      ],
      employees,
      mapping,
    );
    expect(accountBalances(catalog.accounts.values, ops)[cash], -30000);
  });

  test('без id и с нулевой суммой — пропускаются; сотрудник неизвестен', () {
    final ops = payrollExpenses(
      [
        Payment(employeeId: 'e1', paymentDate: day, amount: 100),
        Payment(id: 'p0', employeeId: 'e1', paymentDate: day, amount: 0),
        Payment(id: 'p9', employeeId: 'нет', paymentDate: day, amount: 1),
      ],
      employees,
      mapping,
    );
    expect(ops, hasLength(1));
    expect(ops.single.categoryId, workers);
    expect(ops.single.description, 'Зарплата');
  });
}
