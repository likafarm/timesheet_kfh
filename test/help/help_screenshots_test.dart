// Снимки экранов для инструкций (шаг 4 «Дальнейших работ»): вымышленное
// хозяйство на текущий месяц, настоящие шрифты, PNG в assets/help.
//
// Запуск (Git Bash):
//   KFH_HELP_SHOTS=assets/help flutter test test/help/help_screenshots_test.dart
// Без KFH_HELP_SHOTS тест пропускается.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/help/help_content.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/sync_provider.dart';
import 'package:kfx_time_tracking/screens/main_screen.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/services/backup_service.dart';
import 'package:kfx_time_tracking/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/sync_test_server.dart';

final _out = Platform.environment['KFH_HELP_SHOTS'];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final skip = _out == null ? 'снимки — только с KFH_HELP_SHOTS' : null;

  setUpAll(() async {
    if (_out == null) return;
    await initializeDateFormatting('ru');
    await _loadFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'kfh',
      packageName: 'kfh',
      version: '1.15.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('компьютер: бухгалтер и администратор', (tester) async {
    final shots = _Shots(tester);
    await shots.start(size: const Size(1280, 800), operator: false);

    await shots.save('home');
    await shots.openSection('Табель');
    await shots.save('timesheet');
    await shots.tapTooltip('Ввод за день');
    for (final (i, mark) in ['Поле', 'Поле', 'База'].indexed) {
      await tester.tap(find.widgetWithText(OutlinedButton, mark).at(i));
      await tester.pump();
    }
    await shots.settle();
    await shots.save('daily_dialog');
    await tester.tap(find.text('Отменить'));
    await shots.settle();
    await shots.back();

    await shots.openSection('Сотрудники');
    await shots.save('employees');
    await shots.tapTooltip('Действия');
    await shots.tapText('Ставки');
    await shots.save('rates');
    await shots.back();

    await shots.openSection('Выплаты');
    await shots.save('payments');

    await shots.openSection('Отчёты');
    await shots.save('reports');
    await shots.tapText(_names.first, last: true);
    await shots.save('payroll_detail');
    await shots.tapText('Закрыть', last: true);
    // Подсказка «Изменения отменены» от окна расчёта не нужна на снимках.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .clearSnackBars();

    await shots.openSection('Финансы');
    await shots.save('finance');
    await tester.longPress(find.text('Говядина в тушах'));
    await shots.settle();
    await shots.save('finance_operation');
    await shots.tapText('Отмена', last: true);
    await shots.tapTooltip('Остатки');
    await shots.save('finance_balances');
    await shots.back();

    await shots.openSection('Настройки');
    await shots.tapText('Закрытие месяцев');
    await shots.save('periods');
    await shots.back();
    await shots.tapText('Сервер синхронизации');
    await shots.save('sync_desktop');
    await shots.back();
    await shots.tapText('Резервные копии');
    await shots.save('backups');
    await shots.back();
    await shots.stop();
  }, skip: skip != null);

  testWidgets('телефон: оператор', (tester) async {
    final shots = _Shots(tester);
    await shots.start(size: const Size(390, 844), operator: true);
    await shots.save('phone_timesheet');
    await shots.tapTooltip('Ввод за день');
    for (final (i, mark) in ['Поле', 'Поле', 'База'].indexed) {
      await tester.tap(find.widgetWithText(OutlinedButton, mark).at(i));
      await tester.pump();
    }
    await shots.settle();
    await shots.save('phone_input');
    await tester.tap(find.text('Сохранить').last);
    await shots.settle();
    await shots.sync();
    await shots.back();
    await shots.openSection('Сервер');
    await shots.save('sync');
    await shots.stop();
  }, skip: skip != null);

  testWidgets('телефон: финансы бухгалтера', (tester) async {
    final shots = _Shots(tester);
    await shots.start(size: const Size(390, 844), operator: false, phone: true);
    await shots.tapText('Расход / доход');
    await tester.enterText(find.byType(TextField).first, '2450');
    await shots.settle();
    await shots.tapText('Питание рабочих');
    await tester.drag(find.byType(ListView).first, const Offset(0, 600));
    await shots.settle();
    await shots.save('finance_quick');
    await shots.back();
    await shots.stop();
  }, skip: skip != null);

  test('все картинки инструкции сняты', () {
    final missing = [
      for (final name in helpImageNames)
        if (!File(p.join(_out!, '$name.png')).existsSync()) name,
    ];
    expect(missing, isEmpty);
  }, skip: skip);
}

// ------------------------------------------------------------------ данные

const _names = [
  'Алексеев Андрей Петрович',
  'Борисова Галина Ивановна',
  'Васильев Дмитрий Сергеевич',
  'Григорьев Евгений Олегович',
  'Данилова Жанна Викторовна',
];

/// Вымышленное хозяйство: прошлый месяц целиком и текущий по вчера.
Future<void> _seed(LocalDatabase db) async {
  final repos = DriftRepositories(db);
  final today = DateTime.now();
  final start = DateTime(today.year, today.month - 1, 1);
  await repos.settings.save(
    CompanySettings(
      companyName: 'КФХ «Рассвет»',
      directorName: 'Алексеев А. П.',
    ),
  );
  final ids = <String>[];
  for (final (i, name) in _names.indexed) {
    final id = await repos.employees.add(
      Employee(
        fullName: name,
        position: i == 1 ? 'Бухгалтер-учётчик' : 'Механизатор',
        hireDate: DateTime(2025, 3, 1),
        baseRate: 1800 + 100.0 * i,
        fieldRate: 2400 + 100.0 * i,
      ),
    );
    ids.add(id);
    await repos.rates.add(
      EmployeeRate(
        employeeId: id,
        baseRate: 1800 + 100.0 * i,
        fieldRate: 2400 + 100.0 * i,
        startDate: DateTime(2025, 3, 1),
      ),
    );
  }
  for (
    var d = start;
    d.isBefore(DateTime(today.year, today.month, today.day));
    d = addCalendarDays(d, 1)
  ) {
    if (!ProductionCalendar.isWorkingDay(d)) continue;
    for (final (i, id) in ids.indexed) {
      final r = (d.day + i) % 11;
      await repos.timesheet.add(
        TimesheetRecord(
          employeeId: id,
          date: d,
          dayType: r == 7 && i == 2 ? 'sick' : 'work',
          days: r == 5 ? 0.5 : 1,
          workPlace: r == 7 && i == 2
              ? null
              : (i + d.day) % 3 == 0
              ? 'base'
              : 'field',
        ),
      );
    }
  }
  for (final (i, id) in ids.indexed) {
    await repos.payments.add(
      Payment(
        employeeId: id,
        paymentDate: DateTime(start.year, start.month, 25),
        amount: 15000 + 1000.0 * i,
        paymentType: 'advance',
        paymentMethod: i.isEven ? 'cash' : 'card',
      ),
    );
    await repos.payments.add(
      Payment(
        employeeId: id,
        paymentDate: DateTime(today.year, today.month, 1),
        amount: 25000 + 500.0 * i,
        paymentType: 'salary',
        paymentMethod: 'card',
      ),
    );
  }
  await _seedFinance(repos.finance, today);
}

/// Деньги хозяйства: справочники и операции текущего месяца по сегодня.
Future<void> _seedFinance(FinanceRepository f, DateTime today) async {
  // Сервер принимает только канонические uuid.
  final ids = <String, String>{};
  String u(String key) => ids.putIfAbsent(
    key,
    () =>
        '00000000-0000-4000-8000-${(ids.length + 1).toString().padLeft(12, '0')}',
  );
  final live = u('d-live'), crop = u('d-crop'), general = u('d-general');
  for (final (i, (id, name)) in [
    (live, 'Животноводство'),
    (crop, 'Растениеводство (корма)'),
    (general, 'Общехозяйственные'),
  ].indexed) {
    await f.saveDirection(
      FinDirection(id: id, name: name, overhead: id == general, sortOrder: i),
    );
  }
  await f.saveAllocationKey(
    AllocationKey(
      id: u('k-tractors'),
      name: 'Трактора',
      periods: [
        AllocationPeriod(
          validFrom: DateTime(2025, 1, 1),
          shares: {live: 60, crop: 40},
        ),
      ],
    ),
  );
  final start = DateTime(today.year, today.month - 1, 1);
  for (final (i, (id, name, kind, opening)) in [
    (u('a-cash'), 'Касса', AccountKind.cash, 4520000),
    (u('a-bank'), 'Расчётный счёт', AccountKind.bank, 61834000),
    (u('a-card'), 'Карта', AccountKind.card, 25000000),
  ].indexed) {
    await f.saveAccount(
      FinAccount(
        id: id,
        name: name,
        kind: kind,
        openingBalance: opening,
        openingDate: start,
        sortOrder: i,
      ),
    );
  }
  final groups = [
    (u('g-feed'), CategoryType.expense, '01. Корма'),
    (u('g-tech'), CategoryType.expense, '02. Техника'),
    (u('g-staff'), CategoryType.expense, '03. Персонал'),
    (u('g-farm'), CategoryType.expense, '04. Хозяйство'),
    (u('g-sales'), CategoryType.income, '01. Реализация'),
  ];
  for (final (i, (id, type, name)) in groups.indexed) {
    await f.saveCategoryGroup(
      FinCategoryGroup(id: id, type: type, name: name, sortOrder: i),
    );
  }
  final groupName = {for (final (id, _, name) in groups) id: name};
  for (final (id, type, group, name, direction, key) in [
    (
      u('c-feed'),
      CategoryType.expense,
      u('g-feed'),
      'Корма покупные',
      live,
      null,
    ),
    (
      u('c-fuel'),
      CategoryType.expense,
      u('g-tech'),
      'ГСМ',
      null,
      u('k-tractors'),
    ),
    (
      u('c-parts'),
      CategoryType.expense,
      u('g-tech'),
      'Запчасти',
      null,
      u('k-tractors'),
    ),
    (
      u('c-salary'),
      CategoryType.expense,
      u('g-staff'),
      'Заработная плата',
      live,
      null,
    ),
    (
      u('c-food'),
      CategoryType.expense,
      u('g-staff'),
      'Питание рабочих',
      general,
      null,
    ),
    (u('c-vet'), CategoryType.expense, u('g-farm'), 'Ветпрепараты', live, null),
    (
      u('c-meat'),
      CategoryType.income,
      u('g-sales'),
      'Продажа мяса',
      live,
      null,
    ),
    (u('c-hay'), CategoryType.income, u('g-sales'), 'Продажа сена', crop, null),
  ]) {
    await f.saveCategory(
      FinCategory(
        id: id,
        type: type,
        groupId: group,
        group: groupName[group]!,
        name: name,
        directionId: direction,
        allocationKeyId: key,
      ),
    );
  }
  for (final (id, name, kind) in [
    (u('p-oil'), 'ООО «Нефтебаза»', CounterpartyKind.supplier),
    (u('p-feed'), 'ИП Комбикорм', CounterpartyKind.supplier),
    (u('p-shop'), 'Магазин «Хуторок»', CounterpartyKind.supplier),
    (u('p-meat'), 'ООО «Мясной двор»', CounterpartyKind.buyer),
    (u('p-bank'), 'Банк', CounterpartyKind.bank),
  ]) {
    await f.saveCounterparty(Counterparty(id: id, name: name, kind: kind));
  }
  await f.saveDebt(
    FinDebt(
      id: u('debt-bank'),
      counterpartyId: u('p-bank'),
      kind: DebtKind.received,
      openingBalance: 150000000,
      openingDate: start,
    ),
  );
  await f.savePayrollMapping(
    PayrollFinanceMapping(
      methodAccounts: {
        'cash': u('a-cash'),
        'card': u('a-card'),
        'transfer': u('a-bank'),
      },
      defaultAccountId: u('a-cash'),
      positionCategories: const {},
      defaultCategoryId: u('c-salary'),
    ),
  );
  DateTime day(int d) =>
      DateTime(today.year, today.month, d.clamp(1, today.day));
  var n = 0;
  Future<void> op(
    int d,
    OperationType type,
    int amount,
    String account, {
    String? category,
    String? counterparty,
    String? description,
    String? toAccount,
    double? quantity,
    String? unit,
  }) => f.addOperation(
    FinOperation(
      id: u('op-${n++}'),
      date: day(d),
      type: type,
      amount: amount,
      accountId: account,
      toAccountId: toAccount,
      categoryId: category,
      counterpartyId: counterparty,
      description: description,
      quantity: quantity,
      unit: unit,
    ),
  );
  const e = OperationType.expense, i = OperationType.income;
  await op(
    1,
    e,
    4860000,
    u('a-bank'),
    category: u('c-feed'),
    counterparty: u('p-feed'),
    description: 'Комбикорм КРС',
    quantity: 3,
    unit: 'т',
  );
  await op(
    2,
    e,
    1830000,
    u('a-bank'),
    category: u('c-fuel'),
    counterparty: u('p-oil'),
    description: 'Дизельное топливо',
    quantity: 300,
    unit: 'л',
  );
  await op(
    2,
    OperationType.transfer,
    3000000,
    u('a-bank'),
    toAccount: u('a-cash'),
    description: 'Снятие наличных',
  );
  await op(
    3,
    e,
    245000,
    u('a-card'),
    category: u('c-food'),
    counterparty: u('p-shop'),
    description: 'Продукты, чай, сахар',
  );
  await op(
    4,
    i,
    38750000,
    u('a-bank'),
    category: u('c-meat'),
    counterparty: u('p-meat'),
    description: 'Говядина в тушах',
    quantity: 775,
    unit: 'кг',
  );
  await op(
    5,
    e,
    1264000,
    u('a-cash'),
    category: u('c-parts'),
    description: 'Фильтры, ремень МТЗ-82',
  );
  await op(
    6,
    e,
    387000,
    u('a-card'),
    category: u('c-vet'),
    description: 'Ивермек',
  );
  await op(
    6,
    i,
    1500000,
    u('a-cash'),
    category: u('c-hay'),
    description: 'Сено в рулонах',
    quantity: 10,
    unit: 'шт',
  );
  await op(
    7,
    e,
    198000,
    u('a-cash'),
    category: u('c-food'),
    counterparty: u('p-shop'),
    description: 'Хлеб, молоко',
  );
}

// ------------------------------------------------------------------ снимки

class _Shots {
  final WidgetTester tester;
  final _key = GlobalKey();
  late Directory _root;
  late LocalDatabase _db;
  late AppProvider _app;
  late SyncProvider _sync;

  _Shots(this.tester);

  Future<void> start({
    required Size size,
    required bool operator,
    bool phone = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final server = SyncTestServer()..role = operator ? 'operator' : 'admin';
    final today = DateTime.now();
    final closed = DateTime(today.year, today.month - 2);
    server.locks.add((closed.year, closed.month));
    await tester.runAsync(() async {
      _root = await Directory.systemTemp.createTemp('kfh_help_shots');
      _db = LocalDatabase.memory();
      _app = AppProvider(
        AppDatabase(_db, ':memory:'),
        operatorMode: operator,
        backupService: operator
            ? null
            // Путь виден на снимке — без имени пользователя этого ПК.
            : BackupService(backupDirectory: p.join('Документы', 'backups')),
      );
      _sync = SyncProvider(
        appVersion: () async => '1.15.0',
        database: _db,
        onDataChanged: () => _app.reloadAfterSync(),
        backup: () async {},
        tokenStore: (_) => MemoryTokenStore(),
        httpClient: () => MockClient(server.handle),
        journal: MemorySyncJournal(),
        autoSync: false,
        debugBuild: false,
        client: operator || phone ? ClientKind.phone : ClientKind.desktop,
        onLocksChanged: () => _app.loadLockedMonths(),
      );
      await _sync.init();
      await _sync.signIn(
        'localhost',
        operator ? 'oper' : 'ivan',
        'secret-pass',
      );
      await _sync.link(await _sync.analyzeLink());
      await _seed(_db);
      await _sync.syncNow();
      await _app.loadAllData();
      if (!operator) await _app.autoBackup();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: _key,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _app),
            ChangeNotifierProvider.value(value: _sync),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ru', 'RU'),
            supportedLocales: const [Locale('ru', 'RU')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme,
            home: const MainScreen(),
          ),
        ),
      ),
    );
    await settle();
  }

  Future<void> stop() async {
    _sync.dispose();
    _app.dispose();
    await tester.runAsync(() async {
      await _db.close();
      await _root.delete(recursive: true);
      final docs = Directory('Документы');
      if (docs.existsSync()) await docs.delete(recursive: true);
    });
    tester.view.reset();
  }

  /// База, сеть и файлы идут вне поддельного времени теста.
  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> sync() async {
    await tester.runAsync(() => _sync.syncNow());
    await settle();
  }

  Future<void> openSection(String label) async {
    await tester.tap(find.text(label).last);
    await settle();
  }

  Future<void> tapTooltip(String tooltip) async {
    await tester.tap(find.byTooltip(tooltip).first);
    await settle();
  }

  Future<void> tapText(String text, {bool last = false}) async {
    final f = last ? find.text(text).last : find.text(text).first;
    // Пункт может быть ниже края окна — прокручиваем до него.
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle();
  }

  Future<void> back() async {
    await tester.binding.handlePopRoute();
    await settle();
  }

  Future<void> save(String name) async {
    expect(tester.takeException(), isNull, reason: name);
    final boundary =
        _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File(
        p.join(_out!, '$name.png'),
      ).writeAsBytes(png!.buffer.asUint8List());
    });
  }
}

/// Настоящие шрифты вместо квадратиков теста: Roboto из программы, значки
/// Material — из Flutter.
Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  final roboto = FontLoader('Roboto')
    ..addFont(bytes('assets/fonts/Roboto-Regular.ttf'))
    ..addFont(bytes('assets/fonts/Roboto-Bold.ttf'));
  await roboto.load();

  // flutter_tester лежит в bin/cache/artifacts/engine/<платформа>/.
  var dir = File(Platform.resolvedExecutable).parent;
  File? icons;
  for (var i = 0; i < 6 && icons == null; i++) {
    final candidate = File(
      p.join(
        dir.path,
        'artifacts',
        'material_fonts',
        'materialicons-regular.otf',
      ),
    );
    if (candidate.existsSync()) icons = candidate;
    dir = dir.parent;
  }
  if (icons == null) throw StateError('не найден шрифт значков Material');
  final material = FontLoader('MaterialIcons')..addFont(bytes(icons.path));
  await material.load();
}
