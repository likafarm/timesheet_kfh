// Приёмка этапа 1 на копии реальной базы v8.
//
// Запуск (путь — к КОПИИ базы, не к рабочей):
//   $env:KFH_ACCEPTANCE_DB = "C:\...\kfx_time_tracking.db"
//   flutter test test/acceptance/real_db_test.dart
// Без переменной тест пропускается.
//
// Путь первого запуска новой версии (openAppDatabase: копия → перенос →
// открытие) проходит во временной папке; исходный файл не меняется.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_local_db/native.dart';
import 'package:kfx_time_tracking/services/database_files.dart';
import 'package:kfx_time_tracking/services/db_location.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

final _source = Platform.environment['KFH_ACCEPTANCE_DB'];

void main() {
  test(
    'приёмка этапа 1 на копии реальной базы',
    () async {
      final source = File(_source!);
      final before = source.readAsBytesSync();

      final root = await Directory.systemTemp.createTemp('kfh_acceptance');
      addTearDown(() => root.delete(recursive: true));
      final dataDir = p.join(root.path, 'KFH Time Tracking');
      Directory(dataDir).createSync();
      source.copySync(p.join(dataDir, dbFileName));

      final backups = <String>[];
      Future<String> backup(String v8) async {
        final copy = p.join(root.path, 'backup_v8_${backups.length}.db');
        File(v8).copySync(copy);
        backups.add(copy);
        return copy;
      }

      // 1. Первый запуск: копия и перенос.
      final log = <String>[];
      var app = await openAppDatabase(
        dataDir: dataDir,
        legacyDirs: const [],
        backupLegacy: backup,
        log: (m) async => log.add(m),
      );
      expect(backups, hasLength(1), reason: 'копия перед переносом');
      final report = <String>['Журнал переноса:', ...log, ''];

      final v8 = sql.sqlite3.open(
        p.join(dataDir, dbFileName),
        mode: sql.OpenMode.readOnly,
      );
      addTearDown(v8.close);
      final repos = app.repos;

      // Соответствие старых id сотрудников новым uuid.
      final uuidOf = {
        for (final r
            in await app.db
                .customSelect('SELECT uuid, legacy_id FROM employees')
                .get())
          r.read<int>('legacy_id'): r.read<String>('uuid'),
      };
      final nameOf = {
        for (final r in v8.select('SELECT id, full_name FROM employees'))
          r['id'] as int: r['full_name'] as String,
      };

      // 2. Число записей.
      report.add('Число записей (было → стало):');
      for (final table in employeeTablesOrder) {
        final old = v8.select('SELECT COUNT(*) AS n FROM $table').first['n'];
        final now =
            (await app.db
                    .customSelect(
                      'SELECT COUNT(*) AS n FROM $table WHERE deleted = 0',
                    )
                    .getSingle())
                .read<int>('n');
        report.add('  $table: $old → $now');
        expect(now, old, reason: table);
      }

      // 3. Выплаты по сотрудникам.
      report.addAll(['', 'Выплаты по сотрудникам:']);
      for (final r in v8.select(
        'SELECT employee_id, SUM(amount) AS total, COUNT(*) AS n '
        'FROM payments GROUP BY employee_id',
      )) {
        final id = r['employee_id'] as int;
        final list = await repos.payments.list(employeeId: uuidOf[id]);
        final total = list.fold<double>(0, (s, x) => s + x.amount);
        report.add('  ${nameOf[id]}: ${r['n']} шт., ${_money(total)}');
        expect(list, hasLength(r['n'] as int));
        expect(total, closeTo((r['total'] as num).toDouble(), 0.005));
      }

      // 4. Расчёты ЗП: сохранённые в старой базе = сохранённые в новой =
      //    пересчёт по табелю в новой (до копейки).
      report.addAll(['', 'Расчёты ЗП за месяцы (сохранено → пересчёт):']);
      final saved = v8.select(
        'SELECT employee_id, year, month, total_salary, base_days, '
        'field_days, sick_days, vacation_days, skipped_work_days '
        'FROM payroll_results ORDER BY year, month, employee_id',
      );
      for (final r in saved) {
        final uuid = uuidOf[r['employee_id']]!;
        final year = r['year'] as int;
        final month = r['month'] as int;
        final old = (r['total_salary'] as num).toDouble();
        final stored = (await repos.payroll.resultFor(uuid, year, month))!;
        final calc = await repos.payrollService.calculateMonth(
          uuid,
          year,
          month,
        );
        report.add(
          '  ${month.toString().padLeft(2, '0')}.$year '
          '${nameOf[r['employee_id']]}: ${_money(old)} → '
          '${_money(calc.totalSalary)}',
        );
        expect(stored.totalSalary, closeTo(old, 0.005));
        expect(calc.totalSalary, closeTo(old, 0.005));
        expect(calc.baseDays, (r['base_days'] as num).toDouble());
        expect(calc.fieldDays, (r['field_days'] as num).toDouble());
        expect(calc.sickDays, (r['sick_days'] as num).toDouble());
        expect(calc.vacationDays, (r['vacation_days'] as num).toDouble());
        expect(calc.skippedWorkDays, r['skipped_work_days']);
      }

      // 5. Входящие остатки на начало каждого месяца — по формуле старой
      //    версии (начислено до месяца − выплачено до 1-го числа).
      report.addAll(['', 'Входящие остатки на 1-е число:']);
      final months = _monthsSpan(v8);
      for (final (year, month) in months) {
        final first = '$year-${month.toString().padLeft(2, '0')}-01';
        final accrued = {
          for (final r in v8.select(
            'SELECT employee_id, SUM(total_salary) AS s FROM payroll_results '
            'WHERE year < ? OR (year = ? AND month < ?) GROUP BY employee_id',
            [year, year, month],
          ))
            r['employee_id'] as int: (r['s'] as num).toDouble(),
        };
        final paid = {
          for (final r in v8.select(
            'SELECT employee_id, SUM(amount) AS s FROM payments '
            'WHERE payment_date < ? GROUP BY employee_id',
            [first],
          ))
            r['employee_id'] as int: (r['s'] as num).toDouble(),
        };
        final expected = <String, double>{
          for (final id in {...accrued.keys, ...paid.keys})
            uuidOf[id]!: (accrued[id] ?? 0) - (paid[id] ?? 0),
        };
        final actual = await repos.payrollService.startingBalances(
          DateTime(year, month, 1),
        );
        expect(actual.keys.toSet(), expected.keys.toSet(), reason: first);
        for (final e in expected.entries) {
          expect(actual[e.key], closeTo(e.value, 0.005), reason: first);
        }
        final total = expected.values.fold<double>(0, (s, v) => s + v);
        report.add('  $first: сумма остатков ${_money(total)}');
      }

      // 6. Настройки хозяйства.
      final settingsV8 = v8.select('SELECT * FROM company_settings').first;
      final settings = await repos.settings.get();
      expect(settings.companyName, settingsV8['company_name']);
      expect(settings.inn, settingsV8['inn']);

      // 7. Повторный запуск: переноса нет.
      await app.close();
      app = await openAppDatabase(
        dataDir: dataDir,
        legacyDirs: const [],
        backupLegacy: backup,
      );
      expect(backups, hasLength(1), reason: 'повторного переноса нет');
      await app.close();

      // 8. Исходный файл не изменился.
      expect(source.readAsBytesSync(), before);

      report.addAll([
        '',
        'Повторный запуск: переноса нет. Исходный файл не изменён.',
      ]);
      // ignore: avoid_print
      print(report.join('\n'));
    },
    skip: _source == null ? 'нет KFH_ACCEPTANCE_DB' : false,
  );
}

String _money(double v) => v.toStringAsFixed(2);

/// Месяцы от первого месяца с данными до месяца после последнего.
List<(int, int)> _monthsSpan(sql.Database v8) {
  final days = [
    for (final r in v8.select(
      'SELECT MIN(d) AS lo, MAX(d) AS hi FROM ('
      'SELECT date AS d FROM timesheet UNION ALL '
      'SELECT payment_date FROM payments UNION ALL '
      "SELECT printf('%04d-%02d-01', year, month) FROM payroll_results)",
    ))
      (r['lo'] as String?, r['hi'] as String?),
  ].single;
  if (days.$1 == null) return const [];
  final lo = DateTime.parse(days.$1!);
  final hi = DateTime.parse(days.$2!);
  final result = <(int, int)>[];
  var cur = DateTime(lo.year, lo.month);
  final end = DateTime(hi.year, hi.month + 1);
  while (!cur.isAfter(end)) {
    result.add((cur.year, cur.month));
    cur = DateTime(cur.year, cur.month + 1);
  }
  return result;
}
