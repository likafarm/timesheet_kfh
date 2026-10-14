import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/finance_provider.dart';
import 'package:kfx_time_tracking/services/app_database.dart';

/// Модель раздела «Финансы» (8.5) на базе в памяти.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;
  late FinanceProvider fin;
  late String employeeId;

  const herd = 'd-herd', crops = 'd-crops', key = 'k-tractors';
  const cash = 'a-cash', card = 'a-card';
  const fuel = 'c-fuel', meat = 'c-meat', salary = 'c-salary';

  setUp(() async {
    db = LocalDatabase.memory();
    app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: false);
    final repos = DriftRepositories(db);
    final f = repos.finance;
    await f.saveDirection(const FinDirection(id: herd, name: 'Животноводство'));
    await f.saveDirection(const FinDirection(id: crops, name: 'Корма'));
    await f.saveAllocationKey(
      AllocationKey(
        id: key,
        name: 'Трактора',
        periods: [
          AllocationPeriod(
            validFrom: DateTime(2025),
            shares: {herd: 60, crops: 40},
          ),
        ],
      ),
    );
    await f.saveAccount(
      FinAccount(
        id: cash,
        name: 'Касса',
        kind: AccountKind.cash,
        openingBalance: 100000,
        openingDate: DateTime(2026, 1, 1),
      ),
    );
    await f.saveAccount(
      const FinAccount(id: card, name: 'Карта', kind: AccountKind.card),
    );
    await f.saveCategory(
      const FinCategory(
        id: fuel,
        type: CategoryType.expense,
        group: '04',
        name: 'ГСМ',
        allocationKeyId: key,
      ),
    );
    await f.saveCategory(
      const FinCategory(
        id: meat,
        type: CategoryType.income,
        group: '1',
        name: 'Мясо',
        directionId: herd,
      ),
    );
    await f.saveCategory(
      const FinCategory(
        id: salary,
        type: CategoryType.expense,
        group: '03',
        name: 'Рабочие',
        directionId: herd,
      ),
    );
    await f.savePayrollMapping(
      PayrollFinanceMapping(
        methodAccounts: {'cash': cash},
        defaultAccountId: cash,
        positionCategories: const {},
        defaultCategoryId: salary,
      ),
    );
    employeeId = await repos.employees.add(
      Employee(
        fullName: 'Иванов Иван',
        position: 'Рабочий',
        hireDate: DateTime(2026, 1, 1),
        baseRate: 1000,
        fieldRate: 1000,
      ),
    );
    await repos.payments.add(
      Payment(
        employeeId: employeeId,
        paymentDate: DateTime(2026, 9, 30),
        amount: 150,
        paymentMethod: 'cash',
      ),
    );
    fin = FinanceProvider(app);
    await fin.load();
  });

  tearDown(() async {
    fin.dispose();
    await db.close();
  });

  FinOperation expense({
    String id = 'op-1',
    int amount = 50000,
    DateTime? date,
    String? category = fuel,
  }) => FinOperation(
    id: id,
    date: date ?? DateTime(2026, 9, 10),
    type: OperationType.expense,
    amount: amount,
    accountId: cash,
    categoryId: category,
  );

  test('выплата ЗП — расход из табеля, только чтение', () async {
    final payroll = fin.allOperations.single;
    expect(FinanceProvider.isPayroll(payroll), isTrue);
    expect(payroll.amount, 15000);
    expect(payroll.categoryId, salary);
    expect(await fin.saveOperation(payroll), isFalse);
    expect(app.takeNotice(), contains('«Выплатах»'));
    expect(fin.accountBalancesAt()[cash], 100000 - 15000);
  });

  test('запись по правилам; отбор, итоги и остатки', () async {
    expect(await fin.saveOperation(expense(category: null)), isFalse);
    expect(app.takeNotice(), contains('Не указана статья'));

    expect(await fin.saveOperation(expense()), isTrue);
    expect(
      await fin.saveOperation(
        FinOperation(
          id: 'op-2',
          date: DateTime(2026, 10, 2),
          type: OperationType.income,
          amount: 30000,
          accountId: card,
          categoryId: meat,
        ),
      ),
      isTrue,
    );
    expect(fin.allOperations, hasLength(3));

    final sept = fin.operations(FinanceFilter(month: DateTime(2026, 9)));
    expect(sept.map((o) => o.id), contains('op-1'));
    expect(sept, hasLength(2), reason: 'ГСМ и выплата ЗП');
    final crops_ = fin.operations(const FinanceFilter(directionId: crops));
    expect(crops_.single.id, 'op-1', reason: 'ГСМ — ключ 60/40');
    expect(
      fin.operations(const FinanceFilter(accountId: card)).single.id,
      'op-2',
    );
    final totals = fin.totals(sept);
    expect(totals.expense, 50000 + 15000);
    expect(fin.accountBalancesAt()[cash], 100000 - 50000 - 15000);
    expect(
      fin.directionLabel(fin.operations(const FinanceFilter()).last),
      isNotEmpty,
    );
  });

  test('повтор операции — новый id, сегодняшний день', () async {
    await fin.saveOperation(expense());
    final copy = fin.repeat(
      fin.allOperations.firstWhere((o) => o.id == 'op-1'),
      date: DateTime(2026, 10, 5),
    );
    expect(copy.id, isNot('op-1'));
    expect(copy.date, DateTime(2026, 10, 5));
    expect(copy.categoryId, fuel);
    expect(await fin.saveOperation(copy), isTrue);
    expect(fin.allOperations, hasLength(3));
  });

  test('закрытый месяц — не записывается', () async {
    await LocalSyncStore(db).saveLockedMonths([(2026, 9)]);
    await app.loadLockedMonths();
    expect(await fin.saveOperation(expense()), isFalse);
    expect(app.takeNotice(), contains('09.2026'));
  });

  test('автор новой операции — вошедший, у старой не меняется', () async {
    app.userUuid = 'u-buh';
    expect(await fin.saveOperation(expense()), isTrue);
    final saved = fin.allOperations.firstWhere((o) => o.id == 'op-1');
    expect(saved.createdBy, 'u-buh');
    app.userUuid = 'u-admin';
    expect(
      await fin.saveOperation(expense(amount: 777), before: saved),
      isTrue,
    );
    expect(
      fin.allOperations.firstWhere((o) => o.id == 'op-1').createdBy,
      'u-buh',
    );
  });

  test('оператор: свои расходы и доходы, новые контрагенты (8.8.4)', () async {
    // Чужая операция (бухгалтера) уже есть.
    app.userUuid = 'u-buh';
    expect(await fin.saveOperation(expense(id: 'op-buh')), isTrue);

    app.operatorMode = true;
    app.userUuid = 'u-oper';
    await fin.load();
    expect(fin.allOperations, isEmpty, reason: 'ни чужих, ни выплат ЗП');

    expect(await fin.saveOperation(expense(id: 'op-mine')), isTrue);
    expect(fin.allOperations.map((o) => o.id), ['op-mine']);
    expect(fin.allOperations.single.createdBy, 'u-oper');

    // Перевод — нельзя.
    final transfer = FinOperation(
      id: 'op-t',
      date: DateTime(2026, 9, 10),
      type: OperationType.transfer,
      amount: 100,
      accountId: cash,
      toAccountId: card,
    );
    expect(await fin.saveOperation(transfer), isFalse);
    expect(app.takeNotice(), contains('только расходы и доходы'));

    // Чужую — не исправить и не удалить.
    final buh = (await DriftRepositories(
      db,
    ).finance.operations()).firstWhere((o) => o.id == 'op-buh');
    expect(
      await fin.saveOperation(expense(id: 'op-buh', amount: 1), before: buh),
      isFalse,
    );
    expect(await fin.deleteOperation(buh), isFalse);
    expect(app.takeNotice(), contains('только свои'));

    // Справочники — нельзя, нового контрагента — можно.
    expect(
      await fin.saveAccount(
        const FinAccount(id: 'a-new', name: 'Сейф', kind: AccountKind.cash),
      ),
      isFalse,
    );
    expect(
      await fin.saveCounterparty(const Counterparty(id: 'cp-1', name: 'АЗС')),
      isTrue,
    );
    expect(
      await fin.saveCounterparty(const Counterparty(id: 'cp-1', name: 'АЗС-2')),
      isFalse,
    );

    // Своя — удаляется.
    expect(await fin.deleteOperation(fin.allOperations.single), isTrue);
    expect(fin.allOperations, isEmpty);
  });

  test('используемую статью не удалить, неиспользуемую — можно', () async {
    await fin.saveOperation(expense());
    expect(fin.usages(categoryId: fuel), 1);
    expect(await fin.deleteCatalogItem('fin_categories', fuel), isFalse);
    expect(app.takeNotice(), contains('используется'));
    expect(await fin.deleteCatalogItem('fin_categories', meat), isTrue);
    expect(fin.categories.map((c) => c.id), isNot(contains(meat)));
  });

  test('приём с сервера — модель перечитывает данные', () async {
    await DriftRepositories(db).finance.addOperation(expense(id: 'op-9'));
    expect(fin.allOperations.map((o) => o.id), isNot(contains('op-9')));
    await app.reloadAfterSync();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fin.allOperations.map((o) => o.id), contains('op-9'));
  });

  test('быстрый ввод: последние статьи, контрагенты и кошелёк', () async {
    await DriftRepositories(
      db,
    ).finance.saveCounterparty(const Counterparty(id: 'cp-azs', name: 'АЗС'));
    await DriftRepositories(db).finance.saveCounterparty(
      const Counterparty(id: 'cp-shop', name: 'Магазин'),
    );
    await fin.load();
    await fin.saveOperation(
      FinOperation(
        id: 'op-a',
        date: DateTime(2026, 9, 1),
        type: OperationType.expense,
        amount: 100,
        accountId: card,
        categoryId: fuel,
        counterpartyId: 'cp-azs',
      ),
    );
    await fin.saveOperation(
      FinOperation(
        id: 'op-b',
        date: DateTime(2026, 9, 5),
        type: OperationType.expense,
        amount: 100,
        accountId: card,
        categoryId: salary,
        counterpartyId: 'cp-shop',
      ),
    );
    expect(
      fin.recentCategories(OperationType.expense).map((c) => c.id),
      [salary, fuel],
      reason: 'свежие сверху, выплаты ЗП не в счёт',
    );
    expect(fin.recentCategories(OperationType.income), isEmpty);
    expect(
      fin
          .recentCounterparties(OperationType.expense, categoryId: fuel)
          .map((c) => c.id),
      ['cp-azs', 'cp-shop'],
      reason: 'со статьёй — сначала её контрагенты',
    );
    expect(fin.lastAccount(OperationType.expense), card);
    expect(
      fin.lastAccount(OperationType.income),
      fin.accounts.first.id,
      reason: 'доходов не было — первый открытый кошелёк',
    );
  });

  test('сверка остатка: корректировка, статьи заводятся один раз', () async {
    // Касса: 1 000 на 01.01.2026, выплата ЗП 150 — по записям 850.
    final day = DateTime(2026, 9, 30);
    final short = fin.reconciliation(cash, day, 80000);
    expect(short.expected, 85000);
    expect(short.difference, -5000);
    expect(await fin.applyReconciliation(short), isTrue);
    final fix = fin.allOperations.firstWhere(
      (o) => o.type == OperationType.expense && !FinanceProvider.isPayroll(o),
    );
    expect(fix.amount, 5000);
    expect(fix.date, day);
    expect(fin.categoryName(fix.categoryId), reconciliationShortageCategory);
    // Направлений «накладных» нет — первое по порядку.
    expect(fix.directionId, isNotNull);
    expect(fin.accountBalancesAt(day)[cash], 80000);

    // Совпало — записывать нечего.
    expect(
      await fin.applyReconciliation(fin.reconciliation(cash, day, 80000)),
      isFalse,
    );
    expect(app.takeNotice(), contains('Расхождения нет'));

    // Излишек — доходом; статья недостачи не дублируется.
    expect(
      await fin.applyReconciliation(fin.reconciliation(cash, day, 81000)),
      isTrue,
    );
    expect(fin.accountBalancesAt(day)[cash], 81000);
    expect(
      fin.categories.where((c) => c.name.startsWith('Корректировка остатка')),
      hasLength(2),
    );
    expect(
      await fin.applyReconciliation(fin.reconciliation(cash, day, 80000)),
      isTrue,
    );
    expect(
      fin.categories.where((c) => c.name.startsWith('Корректировка остатка')),
      hasLength(2),
    );
  });

  test('сверка в закрытом месяце — не записывается', () async {
    await LocalSyncStore(db).saveLockedMonths([(2026, 9)]);
    await app.loadLockedMonths();
    final r = fin.reconciliation(cash, DateTime(2026, 9, 30), 0);
    expect(await fin.applyReconciliation(r), isFalse);
    expect(app.takeNotice(), contains('09.2026'));
    expect(fin.accountBalancesAt()[cash], 85000);
    expect(
      fin.categories.where((c) => c.name.startsWith('Корректировка')),
      isEmpty,
    );
  });

  test('сводка: остатки, итоги месяца, подписи строк', () async {
    await fin.saveOperation(expense());
    final s = fin.summaryAt(DateTime(2026, 9, 30));
    expect(s.total, 100000 - 15000 - 50000);
    expect(s.month.expense, 15000 + 50000);
    expect(s.debts, isEmpty);
    final payroll = fin.allOperations.firstWhere(FinanceProvider.isPayroll);
    expect(fin.counterpartyLabel(payroll), 'Иванов Иван');
    expect(fin.whatLabel(payroll), 'Рабочие');
  });

  test(
    'группы статей: статья только с группой своего вида, переименование, удаление',
    () async {
      const staff = FinCategoryGroup(
        id: 'g-staff',
        type: CategoryType.expense,
        name: '03. Персонал',
      );
      expect(await fin.saveCategoryGroup(staff), isTrue);

      FinCategory cat(
        String? groupId, {
        CategoryType type = CategoryType.expense,
      }) => FinCategory(
        id: 'c-new',
        type: type,
        groupId: groupId,
        group: '03. Персонал',
        name: 'Механизаторы',
        directionId: herd,
      );
      expect(await fin.saveCategory(cat(null)), isFalse);
      expect(app.takeNotice(), contains('Выберите группу'));
      expect(
        await fin.saveCategory(cat('g-staff', type: CategoryType.income)),
        isFalse,
      );
      expect(app.takeNotice(), contains('для расходов'));
      expect(await fin.saveCategory(cat('g-staff')), isTrue);
      expect(fin.groupUsages('g-staff'), 1);

      // Переименование — новое название у статьи; вид не сменить, пока есть статьи.
      expect(
        await fin.saveCategoryGroup(
          const FinCategoryGroup(
            id: 'g-staff',
            type: CategoryType.expense,
            name: '03. Люди',
          ),
          before: staff,
        ),
        isTrue,
      );
      final renamed = fin.categories.firstWhere((c) => c.id == 'c-new');
      expect(renamed.group, '03. Люди');
      expect(fin.groupName(renamed), '03. Люди');
      expect(
        await fin.saveCategoryGroup(
          const FinCategoryGroup(
            id: 'g-staff',
            type: CategoryType.income,
            name: '03. Люди',
          ),
          before: staff,
        ),
        isFalse,
      );
      expect(app.takeNotice(), contains('сменить доход/расход нельзя'));

      expect(
        await fin.deleteCatalogItem('fin_category_groups', 'g-staff'),
        isFalse,
      );
      expect(app.takeNotice(), contains('используется'));
      expect(await fin.deleteCatalogItem('fin_categories', 'c-new'), isTrue);
      expect(
        await fin.deleteCatalogItem('fin_category_groups', 'g-staff'),
        isTrue,
      );
      expect(fin.categoryGroups, isEmpty);
    },
  );

  test('статья старой программы — группа по названию', () async {
    await DriftRepositories(db).finance.saveCategoryGroup(
      const FinCategoryGroup(
        id: 'g-04',
        type: CategoryType.expense,
        name: '04',
      ),
    );
    await fin.load();
    // Статья «ГСМ» заведена с текстом группы «04» без ссылки.
    final fuelCat = fin.categories.firstWhere((c) => c.id == fuel);
    expect(fuelCat.groupId, isNull);
    expect(fin.catalog.groupOf(fuelCat)?.id, 'g-04');
    expect(fin.groupUsages('g-04'), 1);
  });

  test('остатки по зарплате на дату — для баланса (8Б.2)', () async {
    // Табеля нет, выплачено 150 ₽ 30.09 — переплата.
    expect(await app.payrollBalancesOn(DateTime(2026, 9, 29)), isEmpty);
    expect(await app.payrollBalancesOn(DateTime(2026, 9, 30)), {
      employeeId: -15000,
    });
  });

  test('платёжный календарь: план, пропуск, оплата, прогноз (8Б.4)', () async {
    final today = calendarDay(DateTime.now());
    final plan = FinPlan(
      id: 'plan-rent',
      type: OperationType.expense,
      amount: 30000,
      startDate: today,
      repeat: PlanRepeat.monthly,
      accountId: cash,
      categoryId: fuel,
      description: 'Аренда',
    );
    expect(await fin.savePlan(plan), isTrue);
    expect(fin.plans.single.description, 'Аренда');

    final first = fin.occurrences(today, today).single;
    expect(first.open, isTrue);
    // Прогноз: сегодня — минус план.
    final money = fin.accountBalancesAt(today).values.fold(0, (s, v) => s + v);
    expect(fin.forecast().first.balance, money - 30000);

    // Оплата: операция из плана со ссылкой — раз закрыт.
    final pay = fin.paymentFor(first);
    expect(pay.sourceRef, planSourceRef('plan-rent', today));
    expect(pay.accountId, cash);
    expect(await fin.saveOperation(pay), isTrue);
    expect(fin.occurrences(today, today).single.payment?.id, pay.id);

    // Пропуск следующего раза.
    final nextDay = DateTime(today.year, today.month + 1, today.day);
    final next = fin.occurrences(nextDay, addCalendarDays(nextDay, 3)).first;
    expect(await fin.skipOccurrence(next), isTrue);
    expect(fin.plans.single.skipped, contains(next.day));
    expect(fin.occurrences(next.day, next.day).single.skipped, isTrue);

    // Повтор до дня раньше начала — не записывается.
    expect(
      await fin.savePlan(
        plan.copyWith(untilDate: () => addCalendarDays(today, -1)),
      ),
      isFalse,
    );
    expect(await fin.deletePlan(fin.plans.single), isTrue);
    expect(fin.plans, isEmpty);
  });

  test('оператору планы не загружаются и не пишутся', () async {
    app.operatorMode = true;
    app.userUuid = 'u-oper';
    await fin.load();
    expect(fin.plans, isEmpty);
    expect(
      await fin.savePlan(
        FinPlan(
          id: 'p',
          type: OperationType.expense,
          amount: 1,
          startDate: DateTime(2026, 10, 1),
        ),
      ),
      isFalse,
    );
  });

  test('БДДС: план статьи, факт, заполнение из прошлого года (8Б.5)', () async {
    await fin.saveOperation(
      expense(id: 'op-2025', date: DateTime(2025, 9, 10)),
    );
    await fin.saveOperation(expense(id: 'op-2026', amount: 70000));
    // План ГСМ на 2026: сентябрь 60 000 коп.
    final months = List.filled(12, 0)..[8] = 60000;
    expect(await fin.saveBudgetFor(2026, fuel, months), isTrue);
    final r = fin.budgetReportFor(2026, await fin.budget(2026));
    final line = r.expense.groups
        .expand((g) => g.lines)
        .firstWhere((l) => l.categoryId == fuel);
    expect(line.planOf([9]), 60000);
    expect(line.factOf([9]), 70000);

    // Из факта 2025 — только статьи без плана (у ГСМ план есть).
    expect(await fin.fillBudgetFromLastYear(2026), isTrue);
    final again = await fin.budget(2026);
    expect(again.where((e) => e.categoryId == fuel).single.amount, 60000);
    // На 2027 — заполняется из факта 2026 (сентябрь, до рубля).
    expect(await fin.fillBudgetFromLastYear(2027), isTrue);
    final next = await fin.budget(2027);
    expect(
      next.where((e) => e.categoryId == fuel && e.month == 9).single.amount,
      70000,
    );
  });

  test('выписка: новые, связь с введённой, контрагент с ИНН, без дублей '
      '(8Б.6)', () async {
    // Введённая вручную оплата, которая есть и в выписке.
    await fin.saveOperation(expense(id: 'op-manual', amount: 50000));
    final statement = BankStatement(
      account: '40802',
      lines: [
        BankLine(
          date: DateTime(2026, 9, 11),
          amount: 50000,
          incoming: false,
          docNumber: '1',
          purpose: 'ГСМ',
        ),
        BankLine(
          date: DateTime(2026, 9, 12),
          amount: 320875,
          incoming: false,
          docNumber: '2',
          purpose: 'Оплата за электроэнергию',
          counterpartyName: 'ПАО "Калужская сбытовая компания"',
          counterpartyInn: '4029030252',
        ),
      ],
    );
    var matches = fin.matchStatement(statement, cash);
    expect(matches.map((m) => m.status), [
      BankLineStatus.matched,
      BankLineStatus.fresh,
    ]);
    final written = await fin.importStatement(
      accountId: cash,
      fresh: [(statement.lines[1], fuel, null, null)],
      matched: [matches.first],
    );
    expect(written, 1);
    final ops = await DriftRepositories(db).finance.operations();
    final bank = ops.firstWhere((o) => o.amount == 320875);
    expect(bank.source, OperationSource.bank);
    expect(bank.sourceRef, statement.lines[1].key);
    final cp = fin.catalog.counterparties[bank.counterpartyId]!;
    expect(cp.inn, '4029030252');
    expect(
      ops.firstWhere((o) => o.id == 'op-manual').sourceRef,
      statement.lines[0].key,
    );

    // Повторная загрузка — всё уже есть; подсказка статьи — по контрагенту.
    matches = fin.matchStatement(statement, cash);
    expect(matches.map((m) => m.status), everyElement(BankLineStatus.imported));
    final next = BankLine(
      date: DateTime(2026, 9, 20),
      amount: 100000,
      incoming: false,
      docNumber: '3',
      purpose: 'Свет',
      counterpartyInn: '4029030252',
    );
    final hint = fin.matchStatement(BankStatement(lines: [next]), cash).single;
    expect(hint.categoryId, fuel);
    expect(hint.counterpartyId, cp.id);

    // Без статьи — отказ.
    expect(
      await fin.importStatement(
        accountId: cash,
        fresh: [(next, null, null, null)],
        matched: const [],
      ),
      isNull,
    );
    expect(fin.lastProblem, contains('статья'));
  });
}
