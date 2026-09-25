// Разовый перенос старой базы (sqflite, схема v8) в новый файл схемы v2.
//
// Старый файл открывается только на чтение и не меняется. Новая база
// пишется во временный файл, затем построчно сверяется со старой
// (все поля всех таблиц через legacy_id) и пересчётом ЗП за каждый месяц,
// проходит integrity_check — и только после этого переименовывается
// в целевой файл. При любой ошибке временный файл удаляется, целевой
// не появляется.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../database.dart';

/// Версия старой схемы, которую понимает конвертер.
const legacySchemaVersion = 8;

/// Ключ в `sync_state`: откуда и когда перенесена база.
const convertedFromKey = 'converted_from_v8';

/// Бизнес-таблицы в порядке вставки и их поля-даты (`гггг-мм-дд`).
const _tables = <String, List<String>>{
  'employees': ['hire_date', 'dismissal_date'],
  'employee_rates': ['start_date', 'end_date'],
  'timesheet': ['date'],
  'payments': ['payment_date', 'period_start', 'period_end'],
  'sick_leave': ['start_date', 'end_date'],
  'vacation': ['start_date', 'end_date'],
  'payroll_results': [],
};

final _isoDay = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Перенос не выполнен; [problems] — что именно не так.
class ConversionException implements Exception {
  final String message;
  final List<String> problems;
  const ConversionException(this.message, [this.problems = const []]);

  @override
  String toString() => problems.isEmpty
      ? message
      : '$message:\n${problems.map((p) => '  - $p').join('\n')}';
}

/// Итог успешного переноса.
class ConversionReport {
  /// Число перенесённых строк по таблицам.
  final Map<String, int> rowCounts;

  /// Сколько пар «сотрудник + месяц» пересчитано и совпало.
  final int payrollMonthsChecked;

  /// Не ошибки переноса, а сведения для владельца: например, сохранённый
  /// расчёт отличается от пересчёта по табелю (его не пересчитывали после
  /// правок). Одинаково в старой и новой базе.
  final List<String> notes;

  const ConversionReport({
    required this.rowCounts,
    required this.payrollMonthsChecked,
    required this.notes,
  });

  @override
  String toString() {
    final counts = rowCounts.entries.map((e) => '${e.key}: ${e.value}');
    return 'Перенесено строк — ${counts.join(', ')}; '
        'сверено расчётов ЗП: $payrollMonthsChecked'
        '${notes.isEmpty ? '' : '\nЗамечания:\n${notes.map((n) => '  - $n').join('\n')}'}';
  }
}

/// Переносит базу v8 [sourcePath] в новый файл v2 [targetPath].
///
/// [targetPath] не должен существовать: повторного переноса не бывает.
Future<ConversionReport> convertV8ToV2({
  required String sourcePath,
  required String targetPath,
  DateTime Function()? clock,
}) async {
  if (!File(sourcePath).existsSync()) {
    throw ConversionException('Нет старой базы: $sourcePath');
  }
  if (File(targetPath).existsSync()) {
    throw ConversionException('Новая база уже существует: $targetPath');
  }

  final tmpPath = '$targetPath.tmp';
  _deleteWithSidecars(tmpPath);

  final source = sql.sqlite3.open(sourcePath, mode: sql.OpenMode.readOnly);
  try {
    final legacy = _LegacyData.read(source);
    final target = LocalDatabase(NativeDatabase(File(tmpPath)), clock: clock);
    ConversionReport report;
    try {
      await _write(target, legacy, sourcePath);
      report = await _verify(target, legacy);
    } finally {
      await target.close();
    }
    _integrityCheck(tmpPath);
    File(tmpPath).renameSync(targetPath);
    return report;
  } catch (_) {
    _deleteWithSidecars(tmpPath);
    rethrow;
  } finally {
    source.close();
  }
}

// ---------------------------------------------------------------------------
// Чтение старой базы
// ---------------------------------------------------------------------------

class _LegacyData {
  /// Строки по таблицам, даты уже приведены к `гггг-мм-дд`.
  final Map<String, List<Map<String, Object?>>> rows;
  final Map<String, Object?>? settings;

  _LegacyData(this.rows, this.settings);

  List<Map<String, Object?>> operator [](String table) => rows[table]!;

  static _LegacyData read(sql.Database db) {
    final version = db.select('PRAGMA user_version').first.values.first;
    if (version != legacySchemaVersion) {
      throw ConversionException(
        'Старая база версии $version, конвертер понимает только '
        'версию $legacySchemaVersion',
      );
    }
    final existing = db
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((r) => r['name'] as String)
        .toSet();
    final missing = [
      ..._tables.keys,
      'company_settings',
    ].where((t) => !existing.contains(t));
    if (missing.isNotEmpty) {
      throw ConversionException(
        'В старой базе нет таблиц: ${missing.join(', ')}',
      );
    }

    final problems = <String>[];
    final rows = <String, List<Map<String, Object?>>>{};
    for (final MapEntry(key: table, value: dateColumns) in _tables.entries) {
      rows[table] = [
        for (final r in db.select('SELECT * FROM $table ORDER BY id'))
          _normalizeDates(table, Map.of(r), dateColumns, problems),
      ];
    }

    final employeeIds = {for (final e in rows['employees']!) e['id']};
    for (final table in _tables.keys.where((t) => t != 'employees')) {
      final orphans = rows[table]!
          .where((r) => !employeeIds.contains(r['employee_id']))
          .map((r) => r['id']);
      if (orphans.isNotEmpty) {
        problems.add('$table: строки без сотрудника, id ${orphans.join(', ')}');
      }
    }

    final seenDays = <(Object?, Object?)>{};
    for (final r in rows['timesheet']!) {
      if (!seenDays.add((r['employee_id'], r['date']))) {
        problems.add(
          'timesheet: две записи сотрудника ${r['employee_id']} '
          'на ${r['date']} (id ${r['id']})',
        );
      }
    }

    if (problems.isNotEmpty) {
      throw ConversionException('Старая база не прошла проверку', problems);
    }

    final settingsRows = db.select(
      'SELECT * FROM company_settings WHERE id = 1',
    );
    return _LegacyData(
      rows,
      settingsRows.isEmpty ? null : Map.of(settingsRows.first),
    );
  }

  static Map<String, Object?> _normalizeDates(
    String table,
    Map<String, Object?> row,
    List<String> dateColumns,
    List<String> problems,
  ) {
    for (final column in dateColumns) {
      final value = row[column];
      if (value == null) continue;
      final day = value is String ? dateOnlyString(value) : null;
      if (day == null || !_isoDay.hasMatch(day)) {
        problems.add('$table id ${row['id']}: $column = «$value» — не дата');
        continue;
      }
      row[column] = day;
    }
    return row;
  }
}

// ---------------------------------------------------------------------------
// Запись новой базы
// ---------------------------------------------------------------------------

Future<void> _write(
  LocalDatabase db,
  _LegacyData legacy,
  String sourcePath,
) async {
  final editor = await db.deviceId();
  final now = db.nowUtc();
  final newColumns = {
    for (final table in [..._tables.keys, 'company_settings'])
      table: await _columnsOf(db, table),
  };

  await db.transaction(() async {
    final employeeUuids = <Object?, String>{};
    for (final table in _tables.keys) {
      for (final row in legacy[table]) {
        final uuid = newUuid();
        if (table == 'employees') employeeUuids[row['id']] = uuid;

        final values = <String, Object?>{
          'uuid': uuid,
          'legacy_id': row['id'],
          'deleted': 0,
          'edited_by': editor,
        };
        for (final MapEntry(:key, :value) in row.entries) {
          if (key == 'id') continue;
          if (key == 'employee_id') {
            values['employee_uuid'] = employeeUuids[value];
          } else {
            values[key] = value;
          }
        }
        _checkColumns(table, values.keys, newColumns[table]!);

        final names = [...values.keys, 'updated_at'];
        await db.customInsert(
          'INSERT INTO $table (${names.join(', ')}) '
          'VALUES (${List.filled(names.length, '?').join(', ')})',
          variables: [
            for (final v in values.values) Variable(v),
            Variable<DateTime>(now),
          ],
        );
      }
    }

    final settings = legacy.settings;
    if (settings != null) {
      final values = {...settings}..remove('id');
      _checkColumns(
        'company_settings',
        values.keys,
        newColumns['company_settings']!,
      );
      await db.customUpdate(
        'UPDATE company_settings SET '
        '${values.keys.map((c) => '$c = ?').join(', ')}, '
        'legacy_id = 1, updated_at = ?, edited_by = ? WHERE uuid = ?',
        variables: [
          for (final v in values.values) Variable(v),
          Variable<DateTime>(now),
          Variable<String>(editor),
          Variable<String>(companySettingsUuid),
        ],
      );
    }

    await db.syncStateDao.setValue(
      convertedFromKey,
      jsonEncode({'source': sourcePath, 'at': now.toIso8601String()}),
    );
  });
}

Future<Set<String>> _columnsOf(LocalDatabase db, String table) async =>
    (await db.customSelect('PRAGMA table_info($table)').get())
        .map((r) => r.read<String>('name'))
        .toSet();

void _checkColumns(String table, Iterable<String> used, Set<String> known) {
  final unknown = used.where((c) => !known.contains(c));
  if (unknown.isNotEmpty) {
    throw ConversionException(
      'В новой таблице $table нет колонок: ${unknown.join(', ')}',
    );
  }
}

// ---------------------------------------------------------------------------
// Сверка
// ---------------------------------------------------------------------------

Future<ConversionReport> _verify(LocalDatabase db, _LegacyData legacy) async {
  final problems = <String>[];
  final counts = <String, int>{};

  final employeeLegacyIds = {
    for (final r
        in await db.customSelect('SELECT uuid, legacy_id FROM employees').get())
      r.read<String>('uuid'): r.read<int>('legacy_id'),
  };

  // 1. Все поля всех строк, строка к строке по legacy_id.
  final converted = <String, List<Map<String, Object?>>>{};
  for (final table in _tables.keys) {
    final newRows = (await db.customSelect('SELECT * FROM $table').get())
        .map((r) => r.data)
        .toList();
    counts[table] = newRows.length;
    final oldRows = legacy[table];
    if (newRows.length != oldRows.length) {
      problems.add(
        '$table: было ${oldRows.length} строк, стало ${newRows.length}',
      );
      continue;
    }
    final byLegacy = {for (final r in newRows) r['legacy_id']: r};
    converted[table] = [];
    for (final old in oldRows) {
      final row = byLegacy[old['id']];
      if (row == null) {
        problems.add('$table id ${old['id']}: строка не перенесена');
        continue;
      }
      // Вид старой строки, восстановленный из новой.
      final restored = <String, Object?>{'id': row['legacy_id']};
      for (final key in old.keys.where((k) => k != 'id')) {
        restored[key] = key == 'employee_id'
            ? employeeLegacyIds[row['employee_uuid']]
            : row[key];
      }
      converted[table]!.add(restored);
      for (final key in old.keys) {
        if (old[key] != restored[key]) {
          problems.add(
            '$table id ${old['id']}: $key было «${old[key]}», '
            'стало «${restored[key]}»',
          );
        }
      }
      if (row['deleted'] != 0) {
        problems.add('$table id ${old['id']}: помечена удалённой');
      }
    }
  }

  // 2. Настройки хозяйства.
  final settings = legacy.settings;
  if (settings != null) {
    final row =
        (await db
                .customSelect(
                  'SELECT * FROM company_settings WHERE uuid = ?',
                  variables: [Variable<String>(companySettingsUuid)],
                )
                .getSingle())
            .data;
    for (final key in settings.keys.where((k) => k != 'id')) {
      if (settings[key] != row[key]) {
        problems.add(
          'company_settings: $key было «${settings[key]}», стало «${row[key]}»',
        );
      }
    }
  }

  // 3. Пересчёт ЗП за каждый месяц каждого сотрудника: старая и новая
  //    база должны дать одно и то же до копейки.
  final notes = <String>[];
  var monthsChecked = 0;
  if (problems.isEmpty) {
    final oldCalc = _PayrollInput(legacy.rows);
    final newCalc = _PayrollInput(converted);
    for (final (employeeId, year, month) in oldCalc.months()) {
      final before = oldCalc.calculate(employeeId, year, month);
      final after = newCalc.calculate(employeeId, year, month);
      monthsChecked++;
      final label = 'сотрудник $employeeId, ${_monthLabel(year, month)}';
      if (!_samePayroll(before, after)) {
        problems.add(
          'расчёт ЗП ($label): было ${before.totalSalary}, '
          'стало ${after.totalSalary}',
        );
      }
      final saved = oldCalc.savedTotal(employeeId, year, month);
      if (saved != null && !_sameMoney(saved, before.totalSalary)) {
        notes.add(
          'сохранённый расчёт ($label) ${saved.toStringAsFixed(2)} '
          '≠ пересчёт по табелю ${before.totalSalary.toStringAsFixed(2)}',
        );
      }
    }
  }

  if (problems.isNotEmpty) {
    throw ConversionException(
      'Сверка новой базы со старой не прошла',
      problems,
    );
  }
  return ConversionReport(
    rowCounts: counts,
    payrollMonthsChecked: monthsChecked,
    notes: notes,
  );
}

String _monthLabel(int year, int month) =>
    '${month.toString().padLeft(2, '0')}.$year';

bool _sameMoney(double a, double b) => (a - b).abs() < 0.005;

bool _samePayroll(PayrollCalculation a, PayrollCalculation b) =>
    _sameMoney(a.totalSalary, b.totalSalary) &&
    a.baseDays == b.baseDays &&
    a.fieldDays == b.fieldDays &&
    a.sickDays == b.sickDays &&
    a.vacationDays == b.vacationDays &&
    a.skippedWorkDays == b.skippedWorkDays;

/// Данные для расчёта ЗП в виде строк старой схемы (`employee_id` — int).
class _PayrollInput {
  final Map<int, List<TimesheetRecord>> _records = {};
  final Map<int, List<EmployeeRate>> _rates = {};
  final Map<(int, int, int), double> _saved = {};

  _PayrollInput(Map<String, List<Map<String, Object?>>> rows) {
    for (final r in rows['timesheet']!) {
      final employeeId = r['employee_id'] as int;
      _records
          .putIfAbsent(employeeId, () => [])
          .add(
            TimesheetRecord(
              employeeId: '$employeeId',
              date: parseDateIso(r['date'] as String),
              dayType: r['day_type'] as String,
              days: (r['days'] as num).toDouble(),
              workPlace: r['work_place'] as String?,
            ),
          );
    }
    for (final r in rows['employee_rates']!) {
      final employeeId = r['employee_id'] as int;
      _rates
          .putIfAbsent(employeeId, () => [])
          .add(
            EmployeeRate(
              employeeId: '$employeeId',
              baseRate: (r['base_rate'] as num).toDouble(),
              fieldRate: (r['field_rate'] as num).toDouble(),
              startDate: parseDateIso(r['start_date'] as String),
              endDate: parseDateIsoOrNull(r['end_date'] as String?),
            ),
          );
    }
    for (final r in rows['payroll_results']!) {
      _saved[(r['employee_id'] as int, r['year'] as int, r['month'] as int)] =
          (r['total_salary'] as num).toDouble();
    }
  }

  /// Все пары «сотрудник + месяц», где есть табель или сохранённый расчёт.
  List<(int, int, int)> months() {
    final result = <(int, int, int)>{
      for (final MapEntry(key: id, value: records) in _records.entries)
        for (final r in records) (id, r.date.year, r.date.month),
      ..._saved.keys,
    }.toList();
    result.sort((a, b) {
      final byEmployee = a.$1.compareTo(b.$1);
      if (byEmployee != 0) return byEmployee;
      return (a.$2 * 12 + a.$3).compareTo(b.$2 * 12 + b.$3);
    });
    return result;
  }

  PayrollCalculation calculate(int employeeId, int year, int month) =>
      calculateMonthlySalary(
        employeeId: '$employeeId',
        year: year,
        month: month,
        records: _records[employeeId] ?? const [],
        rates: _rates[employeeId] ?? const [],
      );

  double? savedTotal(int employeeId, int year, int month) =>
      _saved[(employeeId, year, month)];
}

// ---------------------------------------------------------------------------
// Файлы
// ---------------------------------------------------------------------------

void _integrityCheck(String path) {
  final db = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
  try {
    final result = db.select('PRAGMA integrity_check').first.values.first;
    if (result != 'ok') {
      throw ConversionException('integrity_check новой базы: $result');
    }
    final fk = db.select('PRAGMA foreign_key_check');
    if (fk.isNotEmpty) {
      throw ConversionException(
        'foreign_key_check новой базы: нарушений ${fk.length}',
      );
    }
  } finally {
    db.close();
  }
}

void _deleteWithSidecars(String path) {
  for (final suffix in ['', '-journal', '-wal', '-shm']) {
    final file = File('$path$suffix');
    if (file.existsSync()) file.deleteSync();
  }
}
