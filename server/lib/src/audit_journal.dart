import 'dart:convert';

import 'auth/users.dart';
import 'database.dart';
import 'http/responses.dart';
import 'sql.dart';

/// Виды записей журнала для отбора (6.7): ключ → условие SQL. Имена таблиц
/// и действий — только отсюда, не из запроса.
const auditKinds = <String, String>{
  'timesheet': "a.entity = 'timesheet'",
  'payments': "a.entity = 'payments'",
  'rates': "a.entity = 'employee_rates'",
  'employees': "a.entity = 'employees'",
  'payroll': "a.entity = 'payroll_results'",
  'settings': "a.entity = 'company_settings'",
  'periods': "a.action IN ('period_lock', 'period_unlock')",
  'access': "a.action IN ('login', 'login_failed', 'logout', "
      "'password_change', 'password_reset', 'user_create', 'user_update', "
      "'token_reuse', 'import')",
};

/// Сотрудник, к которому относится запись: сам сотрудник или
/// `employee_uuid` в данных записи.
const _employeeOf = "CASE WHEN a.entity = 'employees' THEN a.entity_uuid "
    "ELSE CONVERT(JSON_UNQUOTE(JSON_EXTRACT(COALESCE(a.new_value, "
    "a.old_value), '\$.employee_uuid')) USING ascii) END";

/// Чтение журнала действий `audit_log` для админа (6.7): новые сверху,
/// постранично (курсор — id записи), с отбором по времени, пользователю,
/// сотруднику и виду записи.
class AuditJournal {
  static const maxLimit = 200;

  final MySqlDatabase db;

  AuditJournal({required this.db});

  Future<Map<String, Object?>> read(
    User actor, {
    DateTime? since,
    DateTime? until,
    String? userUuid,
    String? employeeUuid,
    String? kind,
    int? beforeId,
    int limit = 100,
  }) async {
    if (actor.role != Role.admin) {
      throw const ApiException(
          403, 'forbidden', 'Журнал действий доступен только администратору');
    }
    final kindSql = kind == null ? null : auditKinds[kind];
    if (kind != null && kindSql == null) {
      throw const ApiException(400, 'validation', 'Неизвестный вид записей');
    }
    final n = limit.clamp(1, maxLimit);
    final where = <String>[
      if (since != null) 'a.created_at >= :since',
      if (until != null) 'a.created_at < :until',
      if (userUuid != null) 'a.user_uuid = :user',
      if (employeeUuid != null) '$_employeeOf = :employee',
      ?kindSql,
      if (beforeId != null) 'a.id < :before',
      '1 = 1',
    ];
    final r = await db.execute(
        'SELECT a.id, a.created_at, a.user_uuid, u.login, u.full_name, '
        'a.device_id, a.action, a.entity, a.entity_uuid, a.old_value, '
        'a.new_value, $_employeeOf AS employee_uuid, e.full_name AS employee_name '
        'FROM audit_log a '
        'LEFT JOIN users u ON u.uuid = a.user_uuid '
        'LEFT JOIN employees e ON e.uuid = $_employeeOf '
        'WHERE ${where.join(' AND ')} '
        'ORDER BY a.id DESC LIMIT ${n + 1}',
        {
          if (since != null) 'since': sqlDateTime(since),
          if (until != null) 'until': sqlDateTime(until),
          'user': ?userUuid,
          'employee': ?employeeUuid,
          'before': ?beforeId,
        });
    final rows = r.rows.toList();
    final more = rows.length > n;
    final page = more ? rows.sublist(0, n) : rows;
    return {
      'entries': [
        for (final row in page)
          {
            'id': row.intOf('id'),
            'at': parseSqlDateTime(row.textOf('created_at')).toIso8601String(),
            'user_uuid': row.text('user_uuid'),
            'user_login': row.text('login'),
            'user_name': row.text('full_name'),
            'device_id': row.text('device_id'),
            'action': row.textOf('action'),
            'entity': row.text('entity'),
            'entity_uuid': row.text('entity_uuid'),
            'employee_uuid': row.text('employee_uuid'),
            'employee_name': row.text('employee_name'),
            'old': _decode(row.text('old_value')),
            'new': _decode(row.text('new_value')),
          },
      ],
      'next_before': more ? page.last.intOf('id') : null,
    };
  }

  static Object? _decode(String? value) =>
      value == null ? null : jsonDecode(value);
}
