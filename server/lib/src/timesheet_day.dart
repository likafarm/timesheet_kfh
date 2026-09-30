import 'database.dart';
import 'sql.dart';

/// Табель за один день с авторами отметок (6.10): для напоминания «За
/// сегодня табель внесён тем-то». Автор отметки — пользователь последней
/// правки записи по журналу действий (`audit_log`); записи без журнала
/// (перенесённые импортом) — без автора.
class TimesheetDay {
  final MySqlDatabase db;

  TimesheetDay({required this.db});

  /// [date] — день `гггг-мм-дд` (проверен вызывающим).
  Future<Map<String, Object?>> day(String date) async {
    final records = await db.execute(
      'SELECT t.employee_uuid, e.full_name AS employee_name, t.day_type, '
      't.days, t.work_place, a.user_uuid, a.created_at, u.login, '
      'u.full_name AS user_name, u.role '
      'FROM timesheet t '
      'JOIN employees e ON e.uuid = t.employee_uuid '
      'LEFT JOIN audit_log a ON a.id = (SELECT MAX(a2.id) FROM audit_log a2 '
      "WHERE a2.entity = 'timesheet' AND a2.entity_uuid = t.uuid) "
      'LEFT JOIN users u ON u.uuid = a.user_uuid '
      'WHERE t.date = :d AND t.deleted = 0 '
      'ORDER BY e.full_name, t.employee_uuid',
      {'d': date},
    );
    // Работает в этот день: принят не позже, день увольнения уже нерабочий
    // (как Employee.isActiveOn).
    final active = await db.execute(
      'SELECT COUNT(*) AS n FROM employees WHERE deleted = 0 '
      'AND hire_date <= :d AND (dismissal_date IS NULL OR dismissal_date > :d)',
      {'d': date},
    );
    return {
      'date': date,
      'active_employees': active.rows.first.intOf('n'),
      'records': [
        for (final row in records.rows)
          {
            'employee_uuid': row.textOf('employee_uuid'),
            'employee_name': row.textOf('employee_name'),
            'day_type': row.textOf('day_type'),
            'days': double.parse(row.textOf('days')),
            'work_place': row.text('work_place'),
            'user_uuid': row.text('user_uuid'),
            'user_login': row.text('login'),
            'user_name': row.text('user_name'),
            'user_role': row.text('role'),
            'at': switch (row.text('created_at')) {
              final at? => parseSqlDateTime(at).toIso8601String(),
              null => null,
            },
          },
      ],
    };
  }
}
