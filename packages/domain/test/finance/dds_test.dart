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
        openingDate: DateTime(2026, 1, 1),
      ),
      FinAccount(
        id: 'bank',
        name: 'Счёт',
        kind: AccountKind.bank,
        // Заведён в феврале с остатком — «прочее».
        openingBalance: 500000,
        openingDate: DateTime(2026, 2, 10),
      ),
    ],
    categories: const [
      FinCategory(
        id: 'meat',
        type: CategoryType.income,
        group: 'Продажи',
        name: 'Мясо',
      ),
      FinCategory(
        id: 'fuel',
        type: CategoryType.expense,
        group: 'Техника',
        name: 'ГСМ',
      ),
      FinCategory(
        id: 'tractor',
        type: CategoryType.expense,
        group: 'Капвложения',
        name: 'Техника',
        kind: CategoryKind.capex,
      ),
    ],
    counterparties: const [Counterparty(id: 'b', name: 'Банк')],
    debts: [FinDebt(id: 'loan', counterpartyId: 'b', kind: DebtKind.received)],
  );
  FinOperation op(
    String id,
    DateTime date,
    OperationType type,
    int amount, {
    String account = 'cash',
    String? category,
    String? to,
    DebtMove? move,
  }) => FinOperation(
    id: id,
    date: date,
    type: type,
    amount: amount,
    accountId: account,
    categoryId: category,
    toAccountId: to,
    debtId: move == null ? null : 'loan',
    debtMove: move,
  );
  final ops = [
    op(
      '1',
      DateTime(2026, 1, 5),
      OperationType.income,
      30000,
      category: 'meat',
    ),
    op(
      '2',
      DateTime(2026, 1, 6),
      OperationType.expense,
      5000,
      category: 'fuel',
    ),
    op(
      '3',
      DateTime(2026, 1, 7),
      OperationType.debt,
      200000,
      move: DebtMove.take,
    ),
    op(
      '4',
      DateTime(2026, 2, 1),
      OperationType.expense,
      250000,
      category: 'tractor',
    ),
    op(
      '5',
      DateTime(2026, 2, 3),
      OperationType.debt,
      50000,
      move: DebtMove.repay,
    ),
    // Перевод денег не меняет.
    op(
      '6',
      DateTime(2026, 2, 20),
      OperationType.transfer,
      70000,
      account: 'bank',
      to: 'cash',
    ),
  ];

  test('потоки по видам деятельности и остатки', () {
    final r = ddsReport(
      operations: ops,
      catalog: catalog,
      from: DateTime(2026),
      count: 2,
    );
    expect(r.opening, [100000, 325000]);
    expect(r.operatingIn.values, [30000, 0]);
    expect(r.operatingOut.values, [5000, 0]);
    expect(r.operatingNet, [25000, 0]);
    expect(r.investingOut.values, [0, 250000]);
    expect(r.investingNet, [0, -250000]);
    expect(
      {for (final l in r.financing) l.name: l.values},
      {
        'Получили займ': [200000, 0],
        'Вернули займ': [0, -50000],
      },
    );
    expect(r.netFlow, [225000, -300000]);
    // Февраль: заведён счёт с остатком 5 000 — «прочее».
    expect(r.other, [0, 500000]);
    expect(r.closing, [325000, 525000]);
    for (var i = 0; i < 2; i++) {
      expect(r.opening[i] + r.netFlow[i] + r.other[i], r.closing[i]);
    }
  });
}
