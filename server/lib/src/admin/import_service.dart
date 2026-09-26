import 'package:kfh_domain/kfh_domain.dart';
import 'package:shelf/shelf.dart';

import '../audit.dart';
import '../auth/users.dart';
import '../database.dart';
import '../http/responses.dart';
import '../logger.dart';
import '../payroll/payroll_calculator.dart';
import '../sql.dart';
import '../sync/change_log.dart';
import '../sync/sync_rows.dart';

/// Импорт отклонён: код, сообщение и все найденные расхождения.
class ImportRejected extends ApiException {
  final List<String> details;

  const ImportRejected(super.status, super.code, super.message, this.details);

  @override
  Response toResponse() => jsonResponse({
        'error': {'code': code, 'message': message, 'details': details},
      }, status: status);
}

/// Разовый перенос базы с устройства на сервер (`POST /admin/import`).
///
/// - только админ и только в пустую базу (ни одной записи ни в одной
///   бизнес-таблице, включая удалённые);
/// - вся выгрузка проверяется до записи; ошибки — 400 со списком;
/// - записи пишутся одной транзакцией под очередью записи журнала
///   изменений (устройства получат их обычным pull), `edited_by` — как на
///   устройстве;
/// - до COMMIT — сверка: число записей по таблицам, каждая запись поле в
///   поле, расчёт ЗП и входящий остаток каждого сотрудника за каждый месяц
///   (кодом сервера) против цифр устройства — до полкопейки. Любое
///   расхождение — откат и 422 со списком.
class ImportService {
  static const maxBytes = 20 * 1024 * 1024;

  final MySqlDatabase db;
  final PayrollCalculator payroll;
  final Logger logger;
  final _rows = const SyncRows();
  final _log = const ChangeLog();

  ImportService({required this.db, required this.payroll, required this.logger});

  Future<Map<String, Object?>> import(User actor, Object? json,
      {String? requestId}) async {
    if (actor.role != Role.admin) {
      throw const ApiException(403, 'forbidden', 'Импорт — только для администратора');
    }
    final SyncExport export;
    try {
      export = SyncExport.fromJson(json);
    } on SyncExportException catch (e) {
      throw ImportRejected(400, 'invalid_export', 'Выгрузка не прошла проверку', e.problems);
    } on SyncFormatException catch (e) {
      throw ImportRejected(400, 'invalid_export', e.message, const []);
    }
    _checkSelfConsistent(export);

    final rows = [...export.rows]
      ..sort((a, b) => syncTableOrder(a.table).compareTo(syncTableOrder(b.table)));

    final report = await db.transaction((conn) async {
      final sql = conn.execute;
      await _log.lock(sql);
      final existing = await _counts(sql);
      final busy = [
        for (final e in existing.entries)
          if (e.value.$1 > 0) '${e.key}: ${e.value.$1}',
      ];
      if (busy.isNotEmpty) {
        throw ImportRejected(409, 'not_empty',
            'На сервере уже есть данные — импорт только в пустую базу', busy);
      }

      for (final row in rows) {
        await _rows.insert(sql, syncTableByName(row.table)!, row,
            row.editedBy ?? export.deviceId);
        await _log.append(sql, row.table, row.uuid, deleted: row.deleted);
      }

      final mismatches = [
        ...await _verifyCounts(sql, export),
        ...await _verifyRows(sql, rows),
        ...await _verifyPayroll(sql, export),
      ];
      if (mismatches.isNotEmpty) {
        throw ImportRejected(422, 'verification_failed',
            'Данные на сервере не сошлись с выгрузкой — импорт отменён',
            mismatches.take(100).toList());
      }

      final months = {for (final c in export.payroll) (c.year, c.month)};
      final summary = <String, Object?>{
        'device_id': export.deviceId,
        'exported_at': formatSyncTimestamp(export.exportedAt),
        'counts': {
          for (final e in export.counts.entries)
            e.key: {'total': e.value.$1, 'deleted': e.value.$2},
        },
        'rows': rows.length,
        'payroll_checks': export.payroll.length,
        'months': [
          for (final (y, m) in months.toList()..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2))
            '${m.toString().padLeft(2, '0')}.$y',
        ],
      };
      await writeAudit(sql,
          action: 'import',
          userUuid: actor.uuid,
          requestId: requestId,
          newValue: summary);
      return summary;
    });
    logger.info('импорт выполнен', {'request_id': requestId, ...report});
    return {'ok': true, ...report};
  }

  /// Выгрузка сама с собой: counts совпадают с записями, uuid не повторяются.
  static void _checkSelfConsistent(SyncExport export) {
    final problems = <String>[];
    for (final t in syncTables) {
      final rows = export.rows.where((r) => r.table == t.name);
      final actual = (rows.length, rows.where((r) => r.deleted).length);
      if (export.counts[t.name] != actual) {
        problems.add('${t.name}: в counts ${export.counts[t.name]}, в записях $actual');
      }
    }
    final seen = <String>{};
    for (final r in export.rows) {
      if (!seen.add('${r.table}/${r.uuid}')) problems.add('повтор ${r.table} ${r.uuid}');
    }
    if (problems.isNotEmpty) {
      throw ImportRejected(400, 'invalid_export', 'Выгрузка противоречит сама себе', problems);
    }
  }

  Future<Map<String, (int, int)>> _counts(SqlExecutor sql) async => {
        for (final t in syncTables)
          t.name: await sql('SELECT COUNT(*) AS n, COALESCE(SUM(deleted), 0) AS d '
                  'FROM ${t.name}')
              .then((r) => (r.rows.single.intOf('n'), r.rows.single.intOf('d'))),
      };

  Future<List<String>> _verifyCounts(SqlExecutor sql, SyncExport export) async {
    final actual = await _counts(sql);
    return [
      for (final t in syncTables)
        if (actual[t.name] != (export.counts[t.name] ?? (0, 0)))
          '${t.name}: на сервере ${actual[t.name]}, в выгрузке ${export.counts[t.name]}',
    ];
  }

  Future<List<String>> _verifyRows(SqlExecutor sql, List<SyncChange> rows) async {
    final problems = <String>[];
    for (final t in syncTables) {
      final expected = {
        for (final r in rows.where((r) => r.table == t.name)) r.uuid: r,
      };
      final uuids = expected.keys.toList();
      for (var i = 0; i < uuids.length; i += 500) {
        final chunk = uuids.sublist(i, i + 500 > uuids.length ? uuids.length : i + 500);
        for (final got in await _rows.readMany(sql, t, chunk)) {
          final want = expected.remove(got.uuid)!;
          if (got.updatedAt != want.updatedAt || got.deleted != want.deleted) {
            problems.add('${t.name} ${got.uuid}: служебные поля не совпали');
          }
          for (final c in t.columnNames) {
            if (got.data[c] != want.data[c]) {
              problems.add('${t.name} ${got.uuid}.$c: на сервере «${got.data[c]}», '
                  'в выгрузке «${want.data[c]}»');
            }
          }
        }
      }
      for (final lost in expected.keys) {
        problems.add('${t.name} $lost: не записалась');
      }
    }
    return problems;
  }

  /// Расчёт ЗП и остатки кодом сервера против цифр устройства.
  Future<List<String>> _verifyPayroll(SqlExecutor sql, SyncExport export) async {
    final problems = <String>[];
    final byMonth = <(int, int), List<PayrollCheck>>{};
    for (final c in export.payroll) {
      (byMonth[(c.year, c.month)] ??= []).add(c);
    }
    bool same(double a, double b) => (a - b).abs() < balanceEpsilon;
    for (final MapEntry(key: (year, month), value: checks) in byMonth.entries) {
      final calcs = {
        for (final r in await payroll.calculateEveryone(sql, year, month))
          r.employee.uuid: r,
      };
      final where = '${month.toString().padLeft(2, '0')}.$year';
      final expectedIds = {for (final c in checks) c.employeeUuid};
      for (final extra in calcs.keys.toSet().difference(expectedIds)) {
        problems.add('$where: сотрудник $extra есть на сервере, но не в контроле');
      }
      for (final c in checks) {
        final got = calcs[c.employeeUuid];
        if (got == null) {
          problems.add('$where ${c.employeeUuid}: сотрудника нет на сервере');
          continue;
        }
        final s = got.calculation;
        final pairs = {
          'начислено': (s.totalSalary, c.totalSalary),
          'дни базы': (s.baseDays, c.baseDays),
          'дни поля': (s.fieldDays, c.fieldDays),
          'больничный': (s.sickDays, c.sickDays),
          'отпуск': (s.vacationDays, c.vacationDays),
          'дни без ставки': (s.skippedWorkDays.toDouble(), c.skippedWorkDays.toDouble()),
          'остаток на 1-е': (got.startingBalance, c.startingBalance),
        };
        for (final MapEntry(key: name, value: (server, device)) in pairs.entries) {
          if (!same(server, device)) {
            problems.add('$where ${got.employee.data['full_name']}: $name — '
                'сервер $server, устройство $device');
          }
        }
      }
    }
    return problems;
  }
}
