import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

import 'fixture.dart';

void main() {
  String? problem(FinOperation op, {FinOperation? before}) =>
      operationProblem(op, catalog, before: before);

  group('доход и расход', () {
    test('верные операции', () {
      expect(problem(expense(fuel, 100)), isNull);
      expect(problem(income(meat, 100)), isNull);
      expect(problem(expense(film, 100, season: 2026)), isNull);
      expect(problem(expense(fuel, 100, asset: gazelle)), isNull);
    });

    test('сумма больше нуля', () {
      expect(problem(expense(fuel, 0)), contains('больше нуля'));
      expect(problem(expense(fuel, -5)), contains('больше нуля'));
    });

    test('статья обязательна и подходит к виду', () {
      expect(
        problem(expense(fuel, 1).copyWith(categoryId: 'нет такой')),
        'Статья не найдена',
      );
      expect(problem(expense(meat, 100)), contains('доход'));
      expect(problem(income(fuel, 100)), contains('расход'));
      final noCategory = FinOperation(
        id: 'x',
        date: day,
        type: OperationType.expense,
        amount: 1,
        accountId: cash,
      );
      expect(problem(noCategory), 'Не указана статья');
    });

    test('направление: явное, ключ, имущество или статья', () {
      expect(problem(expense(noDirection, 100)), 'Не указано направление');
      expect(problem(expense(noDirection, 100, direction: general)), isNull);
      expect(problem(expense(noDirection, 100, key: tractors)), isNull);
      expect(problem(expense(noDirection, 100, asset: press)), isNull);
      expect(
        problem(expense(fuel, 100, direction: herd, key: tractors)),
        contains('не оба'),
      );
      expect(
        problem(expense(fuel, 100, direction: 'нет')),
        'Направление не найдено',
      );
      expect(
        problem(expense(fuel, 100, key: 'нет')),
        'Ключ распределения не найден',
      );
    });

    test('выбывшее имущество — только для старых записей', () {
      final op = expense(fuel, 100, asset: oldPress);
      expect(problem(op), contains('выбыло'));
      expect(problem(op, before: op), isNull);
      final early = expense(
        fuel,
        100,
        asset: oldPress,
        date: DateTime(2025, 2, 1),
      );
      expect(problem(early), isNull);
    });

    test('у дохода и расхода нет второго кошелька и займа', () {
      expect(
        problem(expense(fuel, 1).copyWith(toAccountId: bank)),
        contains('второго кошелька'),
      );
      expect(
        problem(expense(fuel, 1).copyWith(debtId: loanTaken)),
        contains('Займ'),
      );
    });

    test('сезон урожая — год', () {
      expect(problem(expense(film, 1, season: 26)), contains('Сезон'));
    });
  });

  group('кошельки', () {
    test('кошелёк должен существовать', () {
      expect(problem(expense(fuel, 1, account: 'нет')), 'Кошелёк не найден');
    });

    test('закрытый кошелёк — только для старых записей', () {
      final op = expense(fuel, 1, account: closedAccount);
      expect(problem(op), contains('закрыт'));
      expect(problem(op, before: op), isNull);
    });
  });

  group('перевод', () {
    test('два разных кошелька, без статьи', () {
      expect(problem(transfer(cash, bank, 100)), isNull);
      expect(problem(transfer(cash, cash, 100)), 'Перевод в тот же кошелёк');
      expect(problem(transfer(cash, 'нет', 100)), 'Кошелёк, куда не найден');
      expect(problem(transfer(cash, closedAccount, 100)), contains('закрыт'));
      expect(
        problem(transfer(cash, bank, 100).copyWith(categoryId: fuel)),
        'У перевода нет статьи',
      );
      final noTarget = FinOperation(
        id: 'x',
        date: day,
        type: OperationType.transfer,
        amount: 1,
        accountId: cash,
      );
      expect(problem(noTarget), contains('куда'));
    });
  });

  group('займ', () {
    test('движение подходит к виду займа', () {
      expect(problem(debt(loanTaken, DebtMove.take, 100)), isNull);
      expect(problem(debt(loanTaken, DebtMove.repay, 100)), isNull);
      expect(problem(debt(loanGiven, DebtMove.lend, 100)), isNull);
      expect(problem(debt(loanGiven, DebtMove.collect, 100)), isNull);
      expect(
        problem(debt(loanTaken, DebtMove.lend, 100)),
        contains('не подходит'),
      );
      expect(
        problem(debt(loanGiven, DebtMove.take, 100)),
        contains('не подходит'),
      );
    });

    test('займ без статьи и с указанным долгом', () {
      expect(
        problem(debt(loanTaken, DebtMove.take, 1).copyWith(categoryId: fuel)),
        'У займа нет статьи',
      );
      expect(problem(debt('нет', DebtMove.take, 1)), 'Займ не найден');
      final noMove = FinOperation(
        id: 'x',
        date: day,
        type: OperationType.debt,
        amount: 1,
        accountId: cash,
        debtId: loanTaken,
      );
      expect(problem(noMove), contains('что сделали'));
    });
  });

  group('ключ распределения', () {
    test('верный ключ', () {
      expect(allocationKeyProblem(catalog.keys[tractors]!, catalog), isNull);
    });

    test('доли в сумме 100, неотрицательные, направления существуют', () {
      AllocationKey key(Map<String, int> shares) => AllocationKey(
        id: 'k',
        name: 'К',
        periods: [AllocationPeriod(validFrom: day, shares: shares)],
      );
      expect(
        allocationKeyProblem(key({herd: 60, crops: 30})),
        contains('90 %'),
      );
      expect(
        allocationKeyProblem(key({herd: 110, crops: -10})),
        contains('отрицательной'),
      );
      expect(allocationKeyProblem(key({})), contains('нет долей'));
      expect(
        allocationKeyProblem(key({'нет': 100}), catalog),
        contains('не найдено'),
      );
    });

    test('без названия, без версий, две версии с одной даты', () {
      expect(
        allocationKeyProblem(
          const AllocationKey(id: 'k', name: ' ', periods: []),
        ),
        contains('названия'),
      );
      expect(
        allocationKeyProblem(
          const AllocationKey(id: 'k', name: 'К', periods: []),
        ),
        contains('нет долей'),
      );
      final p = AllocationPeriod(validFrom: day, shares: const {herd: 100});
      expect(
        allocationKeyProblem(
          AllocationKey(id: 'k', name: 'К', periods: [p, p]),
        ),
        contains('одной даты'),
      );
    });
  });
}
