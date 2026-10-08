import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  final catalog = FinanceCatalog(
    accounts: [
      FinAccount(
        id: 'cash',
        name: 'Касса',
        kind: AccountKind.cash,
        openingBalance: 100000,
        openingDate: DateTime(2025, 1, 1),
      ),
      const FinAccount(
        id: 'credit',
        name: 'Кредитка',
        kind: AccountKind.creditCard,
        sortOrder: 1,
      ),
    ],
    counterparties: const [
      Counterparty(id: 'bank', name: 'Банк'),
      Counterparty(id: 'neighbor', name: 'Сосед'),
    ],
    debts: [
      FinDebt(
        id: 'loan',
        counterpartyId: 'bank',
        kind: DebtKind.received,
        openingBalance: 5000000,
        openingDate: DateTime(2025, 1, 1),
      ),
      const FinDebt(
        id: 'lent',
        counterpartyId: 'neighbor',
        kind: DebtKind.given,
      ),
    ],
    assets: [
      const Asset(
        id: 'tractor',
        name: 'МТЗ-82',
        kind: AssetKind.machinery,
        year: 2015,
        referenceValue: 90000000,
      ),
      const Asset(
        id: 'new',
        name: 'Новый пресс',
        kind: AssetKind.equipment,
        year: 2026,
        referenceValue: 50000000,
      ),
      Asset(
        id: 'sold',
        name: 'Старая Нива',
        kind: AssetKind.vehicle,
        referenceValue: 1000,
        disposedOn: DateTime(2025, 3, 1),
      ),
      const Asset(
        id: 'land',
        name: 'Поле 10 га',
        kind: AssetKind.land,
        cadastralValue: 30000000,
      ),
      const Asset(id: 'noValue', name: 'Сарай', kind: AssetKind.building),
    ],
  );
  final ops = [
    // Покупка кредиткой: кредитка в минусе на 30 000.
    FinOperation(
      id: '1',
      date: DateTime(2025, 6, 1),
      type: OperationType.expense,
      amount: 3000000,
      accountId: 'credit',
    ),
    // Выдали соседу 2 000 из кассы.
    FinOperation(
      id: '2',
      date: DateTime(2025, 6, 2),
      type: OperationType.debt,
      amount: 200000,
      accountId: 'cash',
      debtId: 'lent',
      debtMove: DebtMove.lend,
    ),
    // Вернули банку 10 000 (после даты баланса — не входит).
    FinOperation(
      id: '3',
      date: DateTime(2025, 12, 1),
      type: OperationType.debt,
      amount: 1000000,
      accountId: 'cash',
      debtId: 'loan',
      debtMove: DebtMove.repay,
    ),
  ];

  test('актив, пассив и капитал на дату', () {
    final b = buildManagementBalance(
      day: DateTime(2025, 6, 30),
      catalog: catalog,
      operations: ops,
      payrollBalances: const {'e1': 1500000, 'e2': -50000, 'e3': 0},
      employeeName: (id) => 'Сотрудник $id',
    );
    Map<String, int> lines(BalanceSection s) => {
      for (final l in s.lines) l.name: l.amount,
    };
    final a = {for (final s in b.assets) s.title: s};
    final l = {for (final s in b.liabilities) s.title: s};

    expect(a['Деньги']!.lines, isEmpty);
    // Касса ушла в минус (100 000 − 200 000 коп.) — она в пассиве.
    expect(lines(l['Кредитные карты и кошельки в минусе']!), {
      'Касса': 100000,
      'Кредитка': 3000000,
    });
    expect(lines(a['Займы выданные']!), {'Сосед': 200000});
    expect(lines(l['Займы полученные']!), {'Банк': 5000000});
    expect(
      lines(a['Имущество (справочная стоимость)']!),
      {'МТЗ-82': 90000000, 'Поле 10 га': 30000000},
      reason: 'новый пресс куплен позже, Нива продана, у сарая нет цены',
    );
    expect(lines(l['Долг по зарплате']!), {'Сотрудник e1': 1500000});
    expect(lines(a['Переплата сотрудникам']!), {'Сотрудник e2': 50000});

    expect(b.totalAssets, 200000 + 50000 + 90000000 + 30000000);
    expect(b.totalLiabilities, 5000000 + 3100000 + 1500000);
    expect(b.equity, b.totalAssets - b.totalLiabilities);
  });

  test('займа до дня его начального остатка ещё нет', () {
    final b = buildManagementBalance(
      day: DateTime(2024, 12, 31),
      catalog: catalog,
      operations: ops,
    );
    expect(b.totalLiabilities, 0);
  });

  test('возврат займа после даты учитывается на своей дате', () {
    final b = buildManagementBalance(
      day: DateTime(2025, 12, 31),
      catalog: catalog,
      operations: ops,
    );
    final loans = b.liabilities.firstWhere(
      (s) => s.title == 'Займы полученные',
    );
    expect(loans.total, 4000000);
  });
}
