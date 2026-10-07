import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/native.dart';
import 'package:test/test.dart';

class FakeClock {
  DateTime now = DateTime.utc(2026, 10, 8, 10);
  DateTime call() => now;
  void advance() => now = now.add(const Duration(minutes: 1));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeClock clock;
  late LocalDatabase db;
  late FinanceRepository fin;

  setUp(() async {
    clock = FakeClock();
    db = LocalDatabase.memory(clock: clock.call);
    fin = DriftRepositories(db).finance;
    await fin.saveDirection(
      const FinDirection(id: 'd-herd', name: 'Животноводство'),
    );
    await fin.saveDirection(
      const FinDirection(
        id: 'd-crops',
        name: 'Растениеводство (корма)',
        sortOrder: 1,
      ),
    );
    await fin.saveAccount(
      const FinAccount(id: 'cash', name: 'Касса', kind: AccountKind.cash),
    );
    await fin.saveAccount(
      FinAccount(
        id: 'bank',
        name: 'Счёт',
        kind: AccountKind.bank,
        openingBalance: 2900301,
        openingDate: DateTime(2025, 1, 1),
        sortOrder: 1,
      ),
    );
    await fin.saveCategory(
      const FinCategory(
        id: 'fuel',
        type: CategoryType.expense,
        group: '04. Техника и транспорт',
        name: 'ГСМ',
        directionId: 'd-herd',
      ),
    );
  });
  tearDown(() => db.close());

  Future<Map<String, Object?>> raw(String table, String uuid) async =>
      (await db
              .customSelect(
                'SELECT * FROM $table WHERE uuid = ?',
                variables: [Variable<String>(uuid)],
              )
              .getSingle())
          .data;

  FinOperation op(
    String id, {
    DateTime? date,
    int amount = 100,
    String account = 'cash',
    int? season,
  }) => FinOperation(
    id: id,
    date: date ?? DateTime(2025, 6, 10),
    type: OperationType.expense,
    amount: amount,
    accountId: account,
    categoryId: 'fuel',
    season: season,
    createdBy: 'ivan',
  );

  group('справочники', () {
    test('кошелёк: коды, копейки, даты — туда и обратно', () async {
      final accounts = await fin.accounts();
      expect(accounts.map((a) => a.id), ['cash', 'bank']);
      final bank = accounts.last;
      expect(bank.kind, AccountKind.bank);
      expect(bank.openingBalance, 2900301);
      expect(bank.openingDate, DateTime(2025, 1, 1));
      expect((await raw('fin_accounts', 'bank'))['opening_date'], '2025-01-01');
    });

    test('все виды записей', () async {
      await fin.saveAllocationKey(
        AllocationKey(
          id: 'k',
          name: 'Трактора',
          periods: [
            AllocationPeriod(
              validFrom: DateTime(2025, 1, 1),
              shares: const {'d-herd': 60, 'd-crops': 40},
            ),
          ],
        ),
      );
      await fin.saveAsset(
        Asset(
          id: 'a',
          name: 'Пресс-подборщик',
          kind: AssetKind.equipment,
          year: 2022,
          referenceValue: 200000000,
          valuedOn: DateTime(2023, 1, 1),
          directionId: 'd-crops',
          areaHa: null,
          disposedOn: DateTime(2026, 5, 1),
          disposalReason: 'Продан',
        ),
      );
      await fin.saveAsset(
        const Asset(
          id: 'land',
          name: 'Участок',
          kind: AssetKind.land,
          cadastralNumber: '40:24:130214:98',
          areaHa: 9.4149,
          cadastralValue: 17277283,
          allocationKeyId: 'k',
        ),
      );
      await fin.saveCounterparty(
        const Counterparty(
          id: 'cp',
          name: 'Займодавец',
          kind: CounterpartyKind.person,
          inn: '123',
        ),
      );
      await fin.saveDebt(
        FinDebt(
          id: 'debt',
          counterpartyId: 'cp',
          kind: DebtKind.received,
          openingBalance: 3500000000,
          openingDate: DateTime(2025, 1, 1),
        ),
      );
      await fin.saveCategory(
        const FinCategory(
          id: 'refund',
          type: CategoryType.income,
          group: '3. Прочие поступления',
          name: 'Возвраты',
          kind: CategoryKind.refund,
          allocationKeyId: 'k',
          inTaxBook: false,
          hidden: true,
        ),
      );

      final key = (await fin.allocationKeys()).single;
      expect(key.periods.single.shares, {'d-herd': 60, 'd-crops': 40});
      final assets = {for (final a in await fin.assets()) a.id: a};
      expect(assets['a']!.kind, AssetKind.equipment);
      expect(assets['a']!.referenceValue, 200000000);
      expect(assets['a']!.disposedOn, DateTime(2026, 5, 1));
      expect(assets['land']!.areaHa, 9.4149);
      expect(assets['land']!.allocationKeyId, 'k');
      expect((await fin.counterparties()).single.kind, CounterpartyKind.person);
      final debt = (await fin.debts()).single;
      expect(debt.kind, DebtKind.received);
      expect(debt.openingBalance, 3500000000);
      final refund = (await fin.categories()).firstWhere(
        (c) => c.id == 'refund',
      );
      expect(refund.type, CategoryType.income);
      expect(refund.kind, CategoryKind.refund);
      expect(refund.inTaxBook, isFalse);
      expect(refund.hidden, isTrue);
    });

    test('правка ставит updated_at и edited_by, удаление — мягкое', () async {
      final before = await raw('fin_accounts', 'cash');
      clock.advance();
      await fin.saveAccount(
        const FinAccount(
          id: 'cash',
          name: 'Касса нал',
          kind: AccountKind.cash,
          closed: true,
        ),
      );
      final after = await raw('fin_accounts', 'cash');
      expect(after['name'], 'Касса нал');
      expect(after['updated_at'], isNot(before['updated_at']));
      expect(after['edited_by'], await db.deviceId());

      await fin.deleteAccount('cash');
      expect((await fin.accounts()).map((a) => a.id), ['bank']);
      expect((await raw('fin_accounts', 'cash'))['deleted'], 1);
      expect(
        () => fin.saveAccount(
          const FinAccount(id: 'cash', name: 'Касса', kind: AccountKind.cash),
        ),
        throwsStateError,
      );
    });

    test('повтор названия — DuplicateEntryException', () async {
      await expectLater(
        fin.saveAccount(
          const FinAccount(id: 'x', name: 'Касса', kind: AccountKind.cash),
        ),
        throwsA(isA<DuplicateEntryException>()),
      );
      // Та же статья у дохода — можно.
      await fin.saveCategory(
        const FinCategory(
          id: 'fuel-in',
          type: CategoryType.income,
          group: 'Прочее',
          name: 'ГСМ',
        ),
      );
      await expectLater(
        fin.saveCategory(
          const FinCategory(
            id: 'fuel2',
            type: CategoryType.expense,
            group: 'Прочее',
            name: 'ГСМ',
          ),
        ),
        throwsA(isA<DuplicateEntryException>()),
      );
      // Удалённое название можно занять снова.
      await fin.deleteAccount('cash');
      await fin.saveAccount(
        const FinAccount(id: 'cash2', name: 'Касса', kind: AccountKind.cash),
      );
    });
  });

  group('ключ распределения', () {
    test('версия с той же датой сохраняет uuid, лишние удаляются', () async {
      AllocationKey key(List<AllocationPeriod> periods) =>
          AllocationKey(id: 'k', name: 'Трактора', periods: periods);
      final y2025 = AllocationPeriod(
        validFrom: DateTime(2025, 1, 1),
        shares: const {'d-herd': 60, 'd-crops': 40},
      );
      await fin.saveAllocationKey(
        key([
          y2025,
          AllocationPeriod(
            validFrom: DateTime(2026, 1, 1),
            shares: const {'d-herd': 70, 'd-crops': 30},
          ),
        ]),
      );
      final rows = await db.select(db.finAllocationPeriods).get();
      final uuid2025 = rows.firstWhere((r) => r.validFrom == '2025-01-01').uuid;
      // JSON — ключи по алфавиту.
      expect(rows.first.shares, '{"d-crops":40,"d-herd":60}');

      await fin.saveAllocationKey(
        key([
          AllocationPeriod(
            validFrom: DateTime(2025, 1, 1),
            shares: const {'d-herd': 50, 'd-crops': 50},
          ),
        ]),
      );
      final live = await db.financeDao.allPeriods();
      expect(live.single.uuid, uuid2025);
      expect(DriftFinanceRepository.decodeShares(live.single.shares), {
        'd-herd': 50,
        'd-crops': 50,
      });

      await fin.deleteAllocationKey('k');
      expect(await fin.allocationKeys(), isEmpty);
      expect(await db.financeDao.allPeriods(), isEmpty);
    });
  });

  group('операции', () {
    test(
      'все поля туда и обратно, автор и время создания не меняются',
      () async {
        await fin.saveCounterparty(const Counterparty(id: 'cp', name: 'АЗС'));
        final full = op('o1').copyWith(
          directionId: 'd-crops',
          season: 2026,
          counterpartyId: 'cp',
          description: 'ДТ',
          quantity: 120.5,
          unit: 'л',
          tag: '12',
          notes: 'заметка',
          source: OperationSource.imported,
          sourceRef: 'Расход!428',
        );
        await fin.addOperation(full);
        final read = (await fin.operation('o1'))!;
        expect(read.date, DateTime(2025, 6, 10));
        expect(read.type, OperationType.expense);
        expect(read.amount, 100);
        expect(read.directionId, 'd-crops');
        expect(read.season, 2026);
        expect(read.counterpartyId, 'cp');
        expect(read.quantity, 120.5);
        expect(read.unit, 'л');
        expect(read.tag, '12');
        expect(read.source, OperationSource.imported);
        expect(read.sourceRef, 'Расход!428');
        expect(read.createdBy, 'ivan');
        final created = (await raw('fin_operations', 'o1'))['created_at'];

        clock.advance();
        await fin.updateOperation(
          read.copyWith(amount: 250, createdBy: 'кто-то'),
        );
        final updated = (await fin.operation('o1'))!;
        expect(updated.amount, 250);
        expect(updated.createdBy, 'ivan');
        expect((await raw('fin_operations', 'o1'))['created_at'], created);
      },
    );

    test('займ и перевод', () async {
      await fin.saveCounterparty(
        const Counterparty(id: 'cp', name: 'Займодавец'),
      );
      await fin.saveDebt(
        const FinDebt(
          id: 'debt',
          counterpartyId: 'cp',
          kind: DebtKind.received,
        ),
      );
      await fin.addOperation(
        FinOperation(
          id: 'loan',
          date: DateTime(2025, 1, 18),
          type: OperationType.debt,
          amount: 5000000,
          accountId: 'cash',
          debtId: 'debt',
          debtMove: DebtMove.take,
        ),
      );
      await fin.addOperation(
        FinOperation(
          id: 'tr',
          date: DateTime(2025, 1, 19),
          type: OperationType.transfer,
          amount: 2000000,
          accountId: 'cash',
          toAccountId: 'bank',
        ),
      );
      final ops = await fin.operations();
      expect(ops.firstWhere((o) => o.id == 'loan').debtMove, DebtMove.take);
      final balances = accountBalances(await fin.accounts(), ops);
      expect(balances['cash'], 3000000);
      expect(balances['bank'], 2900301 + 2000000);
      expect(debtBalances(await fin.debts(), ops)['debt'], 5000000);
    });

    test(
      'добавить существующую — ошибка, изменить несуществующую — ошибка',
      () async {
        await fin.addOperation(op('o1'));
        await expectLater(fin.addOperation(op('o1')), throwsStateError);
        await fin.deleteOperation('o1');
        expect(await fin.operation('o1'), isNull);
        await expectLater(fin.addOperation(op('o1')), throwsStateError);
        await expectLater(fin.updateOperation(op('нет')), throwsStateError);
      },
    );

    test('отбор: период, кошелёк (и получатель перевода), сезон', () async {
      await fin.addOperation(op('jan', date: DateTime(2025, 1, 31)));
      await fin.addOperation(
        op('feb', date: DateTime(2025, 2, 1), account: 'bank'),
      );
      await fin.addOperation(
        op('dec', date: DateTime(2025, 12, 5), season: 2026),
      );
      await fin.addOperation(op('y26', date: DateTime(2026, 3, 1)));
      await fin.addOperation(
        FinOperation(
          id: 'tr',
          date: DateTime(2025, 3, 1),
          type: OperationType.transfer,
          amount: 1,
          accountId: 'cash',
          toAccountId: 'bank',
        ),
      );
      Future<List<String>> ids({
        DateTime? from,
        DateTime? to,
        String? account,
        int? season,
      }) async => [
        for (final o in await fin.operations(
          from: from,
          to: to,
          accountId: account,
          season: season,
        ))
          o.id,
      ];
      expect(await ids(), ['y26', 'dec', 'tr', 'feb', 'jan']);
      expect(await ids(from: DateTime(2025, 1, 31), to: DateTime(2025, 2, 1)), [
        'feb',
        'jan',
      ]);
      expect(await ids(account: 'bank'), ['tr', 'feb']);
      expect(await ids(season: 2025), ['tr', 'feb', 'jan']);
      expect(await ids(season: 2026), ['y26', 'dec']);
    });

    test('нет кошелька — запись не проходит (внешний ключ)', () async {
      await expectLater(
        fin.addOperation(op('o1', account: 'нет')),
        throwsA(anything),
      );
      expect(await fin.operations(), isEmpty);
    });
  });

  group('соответствия выплат ЗП', () {
    test('нет умолчаний — null; сохранить, изменить, убрать лишнее', () async {
      expect(await fin.payrollMapping(), isNull);
      await fin.saveCategory(
        const FinCategory(
          id: 'workers',
          type: CategoryType.expense,
          group: '03',
          name: 'Рабочие фермы',
          directionId: 'd-herd',
        ),
      );
      await fin.savePayrollMapping(
        PayrollFinanceMapping(
          methodAccounts: const {'cash': 'cash', 'card': 'bank'},
          defaultAccountId: 'cash',
          positionCategories: const {' Механизатор ': 'fuel'},
          defaultCategoryId: 'workers',
        ),
      );
      var m = (await fin.payrollMapping())!;
      expect(m.methodAccounts, {'cash': 'cash', 'card': 'bank'});
      expect(m.categoryFor('механизатор'), 'fuel');
      expect(m.defaultCategoryId, 'workers');

      await fin.savePayrollMapping(
        PayrollFinanceMapping(
          methodAccounts: const {'cash': 'bank'},
          defaultAccountId: 'cash',
          positionCategories: const {},
          defaultCategoryId: 'workers',
        ),
      );
      m = (await fin.payrollMapping())!;
      expect(m.methodAccounts, {'cash': 'bank'});
      expect(m.positionCategories, isEmpty);
      expect(await db.financeDao.allPayrollMapping(), hasLength(3));
    });
  });
}
