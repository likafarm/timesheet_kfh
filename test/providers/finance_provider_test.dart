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

  test('закрытый месяц и оператор — не записывается', () async {
    await LocalSyncStore(db).saveLockedMonths([(2026, 9)]);
    await app.loadLockedMonths();
    expect(await fin.saveOperation(expense()), isFalse);
    expect(app.takeNotice(), contains('09.2026'));

    app.operatorMode = true;
    expect(
      await fin.saveOperation(expense(date: DateTime(2026, 10, 1))),
      isFalse,
    );
    expect(app.takeNotice(), contains('Оператор'));
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
}
