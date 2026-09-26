import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';
import '../repositories/drift_repositories.dart';

/// Строка локальной таблицы (как её отдаёт SQLite) — в формате обмена.
SyncChange syncChangeFromLocalRow(SyncTable table, Map<String, Object?> row) {
  Object? value(SyncColumn column) {
    final v = row[column.name];
    if (v == null) return null;
    return switch (column.type) {
      SyncType.real => (v as num).toDouble(),
      SyncType.integer => (v as num).toInt(),
      SyncType.boolean => v == 1 || v == true,
      SyncType.text || SyncType.uuid || SyncType.date => v as String,
    };
  }

  return SyncChange(
    table: table.name,
    uuid: row['uuid'] as String,
    updatedAt: _moment(row['updated_at']),
    deleted: row['deleted'] == 1 || row['deleted'] == true,
    editedBy: row['edited_by'] as String?,
    data: {for (final c in table.columns) c.name: value(c)},
  );
}

/// `updated_at` в базе — текст ISO (drift `store_date_time_values_as_text`);
/// на всякий случай понимаем и секунды Unix.
DateTime _moment(Object? value) => switch (value) {
      String s => DateTime.parse(s).toUtc(),
      int seconds =>
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
      _ => throw FormatException('updated_at: $value'),
    };

/// Все записи бизнес-таблиц, включая удалённые, в порядке записи (сначала
/// сотрудники).
Future<List<SyncChange>> readAllSyncRows(LocalDatabase db) async => [
      for (final table in syncTables)
        for (final r in await db
            .customSelect('SELECT * FROM ${table.name} ORDER BY uuid')
            .get())
          syncChangeFromLocalRow(table, r.data),
    ];

/// Выгрузка базы для разового переноса на сервер: все записи и
/// контрольные цифры — число строк по таблицам и расчёт ЗП с входящим
/// остатком каждого сотрудника за каждый месяц, где есть табель, выплаты или
/// сохранённый расчёт. Каждая запись проверяется так же, как её проверит
/// сервер ([SyncChange.fromJson]); ошибки — [SyncExportException].
Future<SyncExport> buildSyncExport(LocalDatabase db, {DateTime? now}) async {
  final rows = await readAllSyncRows(db);
  final problems = <String>[];
  for (final r in rows) {
    try {
      SyncChange.fromJson(r.toJson());
    } on SyncFormatException catch (e) {
      problems.add('${r.table} ${r.uuid}: ${e.message}');
    }
  }
  if (problems.isNotEmpty) throw SyncExportException(problems);

  final counts = <String, (int, int)>{
    for (final t in syncTables)
      t.name: (
        rows.where((r) => r.table == t.name).length,
        rows.where((r) => r.table == t.name && r.deleted).length,
      ),
  };

  // Месяцы с данными — по живым записям.
  final months = <(int, int)>{};
  for (final r in rows.where((r) => !r.deleted)) {
    switch (r.table) {
      case 'timesheet':
      case 'payments':
        final day = parseDateIso(
            r.data[r.table == 'timesheet' ? 'date' : 'payment_date'] as String);
        months.add((day.year, day.month));
      case 'payroll_results':
        months.add((r.data['year'] as int, r.data['month'] as int));
    }
  }
  final sorted = months.toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);

  final repos = DriftRepositories(db);
  final employees = [
    for (final e in await repos.employees.all())
      if (e.id != null) e.id!,
  ];
  final payroll = <PayrollCheck>[];
  for (final (year, month) in sorted) {
    final balances =
        await repos.payrollService.startingBalances(DateTime(year, month, 1));
    for (final id in employees) {
      final c = await repos.payrollService.calculateMonth(id, year, month);
      payroll.add(PayrollCheck(
        employeeUuid: id,
        year: year,
        month: month,
        baseDays: c.baseDays,
        fieldDays: c.fieldDays,
        sickDays: c.sickDays,
        vacationDays: c.vacationDays,
        totalSalary: c.totalSalary,
        skippedWorkDays: c.skippedWorkDays,
        startingBalance: balances[id] ?? 0,
      ));
    }
  }

  return SyncExport(
    exportedAt: (now ?? DateTime.now()).toUtc(),
    deviceId: await db.deviceId(),
    rows: rows,
    counts: counts,
    payroll: payroll,
  );
}
