import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:test/test.dart';

/// Старая база v8 для тестов.
class LegacyDb {
  final sql.Database db;
  LegacyDb(String path) : db = sql.sqlite3.open(path) {
    for (final statement in legacyV8Schema) {
      db.execute(statement);
    }
    db.execute('PRAGMA user_version = 8');
    db.execute(
      "INSERT INTO company_settings (id, company_name, director_name, inn) "
      "VALUES (1, 'КФХ Лика', 'Лопатин И.', '123456789012')",
    );
  }

  int insert(String table, Map<String, Object?> values) {
    db.execute(
      'INSERT INTO $table (${values.keys.join(', ')}) '
      'VALUES (${List.filled(values.length, '?').join(', ')})',
      values.values.toList(),
    );
    return db.lastInsertRowId;
  }

  int employee(String name) => insert('employees', {
    'full_name': name,
    'position': 'Рабочий',
    'hire_date': '2025-01-01',
    'base_rate': 0,
    'field_rate': 0,
  });

  void rate(int emp, double base, double field, String start, [String? end]) =>
      insert('employee_rates', {
        'employee_id': emp,
        'base_rate': base,
        'field_rate': field,
        'start_date': start,
        'end_date': end,
      });

  void day(
    int emp,
    String date, {
    String type = 'work',
    double days = 1,
    String? place = 'field',
  }) => insert('timesheet', {
    'employee_id': emp,
    'date': date,
    'day_type': type,
    'days': days,
    'work_place': place,
    'created_at': '2026-09-01T08:00:00.000',
  });

  void payment(int emp, String date, double amount) => insert('payments', {
    'employee_id': emp,
    'payment_date': date,
    'amount': amount,
    'payment_type': 'advance',
    'payment_method': 'cash',
    'created_at': '2026-09-01T08:00:00.000',
  });

  void payroll(int emp, int year, int month, double total) =>
      insert('payroll_results', {
        'employee_id': emp,
        'year': year,
        'month': month,
        'total_salary': total,
        'calculated_at': '2026-09-01T08:00:00.000',
      });

  void close() => db.close();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late String sourcePath;
  late String targetPath;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kfh_v8_');
    sourcePath = '${dir.path}/kfx_time_tracking.db';
    targetPath = '${dir.path}/kfx_time_tracking_v2.db';
  });
  tearDown(() => dir.delete(recursive: true));

  /// Типичная база: смена ставки внутри месяца, полдня, база/поле,
  /// больничный, день без ставки, выплаты, расчёты, отпуск.
  (int, int) fillTypical(LegacyDb legacy) {
    final ivanov = legacy.employee('Иванов Иван');
    final petrov = legacy.employee('Петров Пётр');
    legacy.rate(ivanov, 1000, 1500, '2026-08-01', '2026-08-15');
    legacy.rate(ivanov, 1200, 1800, '2026-08-16');
    legacy.rate(petrov, 900, 1300, '2026-08-10');

    legacy.day(ivanov, '2026-08-14', place: 'base');
    legacy.day(ivanov, '2026-08-16', days: 0.5);
    legacy.day(ivanov, '2026-08-17', type: 'sick', days: 0, place: null);
    legacy.day(ivanov, '2026-09-01');
    legacy.day(petrov, '2026-08-05'); // до первой ставки — не оплачивается
    legacy.day(petrov, '2026-08-20', place: 'base');

    legacy.payment(ivanov, '2026-08-31', 1500.50);
    legacy.payment(petrov, '2026-09-05', 900);

    legacy.payroll(ivanov, 2026, 8, 1000 + 900); // совпадает с табелем
    legacy.payroll(petrov, 2026, 8, 500); // устарел: по табелю 900

    legacy.insert('vacation', {
      'employee_id': petrov,
      'start_date': '2026-07-01',
      'end_date': '2026-07-14',
      'days_count': 14,
      'is_approved': 1,
    });
    legacy.insert('sick_leave', {
      'employee_id': ivanov,
      'start_date': '2026-08-17',
      'end_date': '2026-08-17',
      'days_count': 1,
    });
    return (ivanov, petrov);
  }

  void expectNoTarget() {
    expect(File(targetPath).existsSync(), isFalse);
    expect(File('$targetPath.tmp').existsSync(), isFalse);
  }

  test('перенос типичной базы: всё на месте и сверено', () async {
    final legacy = LegacyDb(sourcePath);
    final (ivanov, _) = fillTypical(legacy);
    legacy.close();
    final sourceBytes = File(sourcePath).readAsBytesSync();

    final report = await convertV8ToV2(
      sourcePath: sourcePath,
      targetPath: targetPath,
    );

    expect(report.rowCounts, {
      'employees': 2,
      'employee_rates': 3,
      'timesheet': 6,
      'payments': 2,
      'sick_leave': 1,
      'vacation': 1,
      'payroll_results': 2,
    });
    // Иванов: 08 и 09; Петров: 08.
    expect(report.payrollMonthsChecked, 3);
    expect(report.notes, hasLength(1));
    expect(report.notes.single, contains('500.00'));

    expect(File(sourcePath).readAsBytesSync(), sourceBytes);
    expect(File('$targetPath.tmp').existsSync(), isFalse);

    final db = LocalDatabase.file(File(targetPath));
    addTearDown(db.close);

    final employees = await db.employeesDao.allEmployees();
    expect(employees.map((e) => (e.fullName, e.legacyId)), [
      ('Иванов Иван', ivanov),
      ('Петров Пётр', ivanov + 1),
    ]);
    final ivanovUuid = employees.first.uuid;

    final rates = await db.ratesDao.rateHistory(ivanovUuid);
    expect(rates.map((r) => (r.startDate, r.endDate, r.baseRate)), [
      ('2026-08-01', '2026-08-15', 1000),
      ('2026-08-16', null, 1200),
    ]);

    final august = await db.timesheetDao.recordsInPeriod(
      DateTime(2026, 8, 1),
      DateTime(2026, 8, 31),
      employeeUuid: ivanovUuid,
    );
    expect(august.map((r) => (r.date, r.dayType, r.days, r.workPlace)), [
      ('2026-08-17', 'sick', 0, null),
      ('2026-08-16', 'work', 0.5, 'field'),
      ('2026-08-14', 'work', 1, 'base'),
    ]);
    expect(august.first.createdAt, '2026-09-01T08:00:00.000');
    expect(august.every((r) => r.editedBy == august.first.editedBy), isTrue);
    expect(august.first.editedBy, await db.deviceId());

    expect(await db.paymentsDao.paidBefore(DateTime(2026, 9, 1)), {
      ivanovUuid: 1500.50,
    });

    final settings = (await db.settingsDao.getSettings())!;
    expect(settings.companyName, 'КФХ Лика');
    expect(settings.inn, '123456789012');
    expect(settings.legacyId, 1);
    expect(await db.select(db.companySettings).get(), hasLength(1));

    expect(await db.syncStateDao.getValue(convertedFromKey), contains('at'));
  });

  test('даты со временем приводятся к гггг-мм-дд', () async {
    final legacy = LegacyDb(sourcePath);
    final emp = legacy.employee('Иванов Иван');
    legacy.day(emp, '2026-08-03T00:00:00.000');
    legacy.close();

    await convertV8ToV2(sourcePath: sourcePath, targetPath: targetPath);

    final db = LocalDatabase.file(File(targetPath));
    addTearDown(db.close);
    final rows = await db.select(db.timesheet).get();
    expect(rows.single.date, '2026-08-03');
  });

  test('новая база уже есть — повторного переноса нет', () async {
    LegacyDb(sourcePath).close();
    File(targetPath).writeAsStringSync('чужой файл');

    await expectLater(
      convertV8ToV2(sourcePath: sourcePath, targetPath: targetPath),
      throwsA(isA<ConversionException>()),
    );
    expect(File(targetPath).readAsStringSync(), 'чужой файл');
  });

  test('чужая версия схемы не переносится', () async {
    final legacy = LegacyDb(sourcePath);
    legacy.db.execute('PRAGMA user_version = 7');
    legacy.close();

    await expectLater(
      convertV8ToV2(sourcePath: sourcePath, targetPath: targetPath),
      throwsA(
        isA<ConversionException>().having(
          (e) => e.message,
          'message',
          contains('версии 7'),
        ),
      ),
    );
    expectNoTarget();
  });

  test('строки без сотрудника останавливают перенос', () async {
    final legacy = LegacyDb(sourcePath);
    final emp = legacy.employee('Иванов Иван');
    legacy.day(emp, '2026-08-03');
    legacy.db.execute('PRAGMA foreign_keys = OFF');
    legacy.day(999, '2026-08-04');
    legacy.close();

    await expectLater(
      convertV8ToV2(sourcePath: sourcePath, targetPath: targetPath),
      throwsA(
        isA<ConversionException>().having(
          (e) => e.problems.single,
          'problem',
          contains('timesheet: строки без сотрудника'),
        ),
      ),
    );
    expectNoTarget();
  });

  test('испорченная дата останавливает перенос', () async {
    final legacy = LegacyDb(sourcePath);
    final emp = legacy.employee('Иванов Иван');
    legacy.day(emp, '03.08.2026');
    legacy.close();

    await expectLater(
      convertV8ToV2(sourcePath: sourcePath, targetPath: targetPath),
      throwsA(
        isA<ConversionException>().having(
          (e) => e.problems.single,
          'problem',
          contains('не дата'),
        ),
      ),
    );
    expectNoTarget();
  });

  test('два дня на одну дату после приведения дат — стоп', () async {
    final legacy = LegacyDb(sourcePath);
    final emp = legacy.employee('Иванов Иван');
    legacy.day(emp, '2026-08-03');
    legacy.day(emp, '2026-08-03T12:00:00.000');
    legacy.close();

    await expectLater(
      convertV8ToV2(sourcePath: sourcePath, targetPath: targetPath),
      throwsA(
        isA<ConversionException>().having(
          (e) => e.problems.single,
          'problem',
          contains('две записи'),
        ),
      ),
    );
    expectNoTarget();
  });

  test('колонка, которой нет в новой схеме, останавливает перенос', () async {
    final legacy = LegacyDb(sourcePath);
    legacy.db.execute('ALTER TABLE timesheet ADD COLUMN hours REAL');
    legacy.day(legacy.employee('Иванов Иван'), '2026-08-03');
    legacy.close();

    await expectLater(
      convertV8ToV2(sourcePath: sourcePath, targetPath: targetPath),
      throwsA(
        isA<ConversionException>().having(
          (e) => e.message,
          'message',
          contains('нет колонок: hours'),
        ),
      ),
    );
    expectNoTarget();
  });

  test('нет старой базы — понятная ошибка', () async {
    await expectLater(
      convertV8ToV2(sourcePath: sourcePath, targetPath: targetPath),
      throwsA(isA<ConversionException>()),
    );
    expectNoTarget();
  });
}
