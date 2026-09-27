import 'sync_change.dart';
import 'sync_tables.dart';

/// Контроль расчёта ЗП сотрудника за месяц, посчитанный там, откуда
/// выгружены данные. Сервер после импорта считает то же самое своим кодом и
/// сравнивает.
class PayrollCheck {
  final String employeeUuid;
  final int year;
  final int month;
  final double baseDays;
  final double fieldDays;
  final double sickDays;
  final double vacationDays;
  final double totalSalary;
  final int skippedWorkDays;

  /// Входящий остаток на 1-е число месяца.
  final double startingBalance;

  const PayrollCheck({
    required this.employeeUuid,
    required this.year,
    required this.month,
    required this.baseDays,
    required this.fieldDays,
    required this.sickDays,
    required this.vacationDays,
    required this.totalSalary,
    required this.skippedWorkDays,
    required this.startingBalance,
  });

  Map<String, Object?> toJson() => {
        'employee_uuid': employeeUuid,
        'year': year,
        'month': month,
        'base_days': baseDays,
        'field_days': fieldDays,
        'sick_days': sickDays,
        'vacation_days': vacationDays,
        'total_salary': totalSalary,
        'skipped_work_days': skippedWorkDays,
        'starting_balance': startingBalance,
      };

  factory PayrollCheck.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw SyncFormatException('контроль расчёта должен быть объектом');
    }
    double real(String k) => json[k] is num
        ? (json[k] as num).toDouble()
        : throw SyncFormatException('контроль расчёта: $k — не число');
    int integer(String k) => json[k] is int
        ? json[k] as int
        : throw SyncFormatException('контроль расчёта: $k — не целое');
    final employee = json['employee_uuid'];
    if (!isCanonicalUuid(employee)) {
      throw SyncFormatException('контроль расчёта: employee_uuid — не uuid');
    }
    final month = integer('month');
    if (month < 1 || month > 12) {
      throw SyncFormatException('контроль расчёта: месяц $month');
    }
    return PayrollCheck(
      employeeUuid: employee as String,
      year: integer('year'),
      month: month,
      baseDays: real('base_days'),
      fieldDays: real('field_days'),
      sickDays: real('sick_days'),
      vacationDays: real('vacation_days'),
      totalSalary: real('total_salary'),
      skippedWorkDays: integer('skipped_work_days'),
      startingBalance: real('starting_balance'),
    );
  }
}

/// Выгрузка всей базы для разового переноса на сервер (`POST
/// /admin/import`): все записи бизнес-таблиц, включая удалённые, в формате
/// синхронизации, и контрольные цифры для сверки.
class SyncExport {
  static const format = 'kfh-export';
  static const formatVersion = 1;

  final DateTime exportedAt;

  /// id устройства, с которого выгружено.
  final String deviceId;

  /// Записи всех таблиц в порядке записи (сначала сотрудники).
  final List<SyncChange> rows;

  /// Число записей по таблицам: (всего, из них удалённых).
  final Map<String, (int, int)> counts;

  /// Расчёт каждого сотрудника за каждый месяц с данными.
  final List<PayrollCheck> payroll;

  SyncExport({
    required this.exportedAt,
    required this.deviceId,
    required this.rows,
    required this.counts,
    required this.payroll,
  });

  Map<String, Object?> toJson() => {
        'format': format,
        'version': formatVersion,
        'exported_at': formatSyncTimestamp(exportedAt),
        'device_id': deviceId,
        'counts': {
          for (final e in counts.entries)
            e.key: {'total': e.value.$1, 'deleted': e.value.$2},
        },
        'payroll': [for (final c in payroll) c.toJson()],
        'rows': [for (final r in rows) r.toJson()],
      };

  /// Разбор с полной проверкой каждой записи. Ошибки собираются все сразу
  /// (не больше [maxProblems]) — чтобы исправить их за один раз.
  factory SyncExport.fromJson(Object? json, {int maxProblems = 50}) {
    if (json is! Map<String, Object?> ||
        json['format'] != format ||
        json['version'] != formatVersion) {
      throw SyncFormatException('это не выгрузка $format версии $formatVersion');
    }
    final problems = <String>[];
    final rows = <SyncChange>[];
    final rawRows = json['rows'];
    if (rawRows is! List) throw SyncFormatException('нет списка rows');
    for (var i = 0; i < rawRows.length; i++) {
      try {
        rows.add(SyncChange.fromJson(rawRows[i]));
      } on SyncFormatException catch (e) {
        if (problems.length < maxProblems) {
          problems.add('запись ${i + 1}: ${e.message}');
        }
      }
    }
    final rawCounts = json['counts'];
    final counts = <String, (int, int)>{};
    if (rawCounts is Map<String, Object?>) {
      for (final e in rawCounts.entries) {
        final v = e.value;
        if (syncTableByName(e.key) == null ||
            v is! Map ||
            v['total'] is! int ||
            v['deleted'] is! int) {
          problems.add('counts.${e.key}: неверно');
          continue;
        }
        counts[e.key] = (v['total'] as int, v['deleted'] as int);
      }
    } else {
      problems.add('нет counts');
    }
    final payroll = <PayrollCheck>[];
    final rawPayroll = json['payroll'];
    if (rawPayroll is List) {
      for (final c in rawPayroll) {
        try {
          payroll.add(PayrollCheck.fromJson(c));
        } on SyncFormatException catch (e) {
          if (problems.length < maxProblems) problems.add(e.message);
        }
      }
    } else {
      problems.add('нет payroll');
    }
    final deviceId = json['device_id'];
    if (deviceId is! String || deviceId.isEmpty || deviceId.length > 64) {
      problems.add('device_id — строка до 64 символов');
    }
    DateTime? exportedAt;
    try {
      exportedAt = parseSyncTimestamp(json['exported_at']);
    } on SyncFormatException catch (e) {
      problems.add('exported_at: ${e.message}');
    }
    if (problems.isNotEmpty) throw SyncExportException(problems);
    return SyncExport(
      exportedAt: exportedAt!,
      deviceId: deviceId as String,
      rows: rows,
      counts: counts,
      payroll: payroll,
    );
  }
}

/// Выгрузка не прошла проверку: все найденные ошибки.
class SyncExportException implements Exception {
  final List<String> problems;
  SyncExportException(this.problems);

  @override
  String toString() => 'SyncExportException: ${problems.join('; ')}';
}
