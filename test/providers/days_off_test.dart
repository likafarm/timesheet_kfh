import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/services/app_database.dart';

/// «Отметить выходные» (6.6): «В» — только в пустые клетки нерабочих по
/// производственному календарю дней и только когда сотрудник работает.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late DriftRepositories repos;
  late AppProvider app;

  Future<String> employee(String name, DateTime hired, {DateTime? dismissed}) =>
      repos.employees.add(
        Employee(
          fullName: name,
          position: 'Рабочий',
          hireDate: hired,
          dismissalDate: dismissed,
          baseRate: 0,
          fieldRate: 0,
        ),
      );

  Future<List<TimesheetRecord>> january(String id) => repos.timesheet.inPeriod(
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 31),
    employeeId: id,
  );

  setUp(() async {
    db = LocalDatabase.memory();
    repos = DriftRepositories(db);
    app = AppProvider(AppDatabase(db, ':memory:'));
    await app.loadAllData();
  });
  tearDown(() => db.close());

  test('январь 2026: праздники и переносы, приём и увольнение, занятые '
      'клетки', () async {
    // Нерабочие дни января 2026: 1–11, 17, 18, 24, 25, 31 — 16 дней.
    expect(ProductionCalendar.daysOff(2026, 1), hasLength(16));
    final all = await employee('Весь месяц', DateTime(2025, 1, 1));
    final hired = await employee('Принят 20-го', DateTime(2026, 1, 20));
    final left = await employee(
      'Уволен 10-го',
      DateTime(2025, 1, 1),
      dismissed: DateTime(2026, 1, 10),
    );
    // Уже заполнено: 3-го — работа, 17-го — больничный.
    await repos.timesheet.add(
      TimesheetRecord(
        employeeId: all,
        date: DateTime(2026, 1, 3),
        dayType: 'work',
        days: 1,
        workPlace: 'field',
      ),
    );
    await repos.timesheet.add(
      TimesheetRecord(
        employeeId: all,
        date: DateTime(2026, 1, 17),
        dayType: 'sick',
        days: 1,
      ),
    );

    final empty = await app.emptyDaysOff(2026, 1);
    final byName = <String, int>{};
    for (final (e, _) in empty) {
      byName[e.fullName] = (byName[e.fullName] ?? 0) + 1;
    }
    // Весь месяц: 16 − 2 занятых; принят 20-го: 24, 25, 31; уволен 10-го:
    // 1–9 (день увольнения уже нерабочий).
    expect(byName, {'Весь месяц': 14, 'Принят 20-го': 3, 'Уволен 10-го': 9});

    expect(await app.fillDaysOff(2026, 1), 26);
    final records = await january(all);
    expect(records, hasLength(16));
    expect(
      records.firstWhere((r) => r.date.day == 3).dayType,
      'work',
      reason: 'заполненная клетка не тронута',
    );
    expect(records.firstWhere((r) => r.date.day == 17).dayType, 'sick');
    final nine = records.firstWhere((r) => r.date.day == 9);
    expect(
      (nine.dayType, nine.days, nine.workPlace),
      ('dayoff', 1.0, null),
      reason: '9 января — перенесённый выходной',
    );
    expect(
      (await january(all)).where((r) => r.date.day == 12),
      isEmpty,
      reason: '12 января — рабочий',
    );
    expect([
      for (final r in await january(hired)) r.date.day,
    ], unorderedEquals([24, 25, 31]));
    expect([for (final r in await january(left)) r.date.day]..sort(), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
    ]);

    // Повтор ничего не добавляет.
    expect(await app.emptyDaysOff(2026, 1), isEmpty);
    expect(await app.fillDaysOff(2026, 1), 0);
  });

  test('закрытый месяц — не заполняется, объяснение', () async {
    await employee('Иванов', DateTime(2025, 1, 1));
    await LocalSyncStore(db).saveLockedMonths([(2026, 1)]);
    await app.loadLockedMonths();
    expect(await app.fillDaysOff(2026, 1), 0);
    expect(app.takeNotice(), contains('01.2026'));
    expect(
      await repos.timesheet.inPeriod(
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 31),
      ),
      isEmpty,
    );
  });
}
