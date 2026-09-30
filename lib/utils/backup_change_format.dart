// lib/utils/backup_change_format.dart
//
// Модуль «Резервные копии» (3.7): отличие записи копии от того, что есть
// сейчас, и правка возврата — человеческим языком. Подписи полей и значений
// — общие с журналом действий.

import 'package:kfh_domain/kfh_domain.dart';

import 'audit_format.dart';

/// Вид записи для человека.
const recordKindLabels = <String, String>{
  'company_settings': 'Реквизиты',
  'employees': 'Сотрудник',
  'employee_rates': 'Ставка',
  'timesheet': 'Табель',
  'payments': 'Выплата',
  'sick_leave': 'Больничный',
  'vacation': 'Отпуск',
  'payroll_results': 'Расчёт ЗП',
};

/// Что за запись: «Иванов Иван · 03.09.2026», «Иванов Иван · с 01.03.2025».
String recordSubject(
  String table,
  Map<String, Object?> data,
  Map<String, String> names,
) {
  String day(String field) => formatRecordValue(field, data[field]) ?? '';
  final who = table == 'employees'
      ? '${data['full_name'] ?? '—'}'
      : names[data['employee_uuid']] ?? 'Сотрудник не найден';
  final what = switch (table) {
    'company_settings' => '${data['company_name'] ?? ''}',
    'employees' => '',
    'employee_rates' => 'с ${day('start_date')}',
    'timesheet' => day('date'),
    'payments' =>
      '${day('payment_date')}, ${formatRecordValue('amount', data['amount'])}',
    'sick_leave' || 'vacation' => '${day('start_date')} – ${day('end_date')}',
    _ => '',
  };
  if (table == 'company_settings') return 'Реквизиты хозяйства';
  return [who, what].where((p) => p.isNotEmpty).join(' · ');
}

/// Что произошло с записью после копии.
String changeKindLabel(RecordChangeKind kind) => switch (kind) {
  RecordChangeKind.added => 'Добавлено после копии',
  RecordChangeKind.changed => 'Изменено после копии',
  RecordChangeKind.removed => 'Удалено после копии',
};

/// Поля «в копии → сейчас» (у добавленной — какой стала, у удалённой —
/// какой была).
List<AuditFieldChange> changeFields(RecordChange c) => auditChanges(
  c.table,
  c.then == null || c.then!.deleted ? null : c.then!.data,
  c.now == null || c.now!.deleted ? null : c.now!.data,
);

/// Что сделает правка возврата.
String restoreEditLabel(RestoreEdit e) {
  if (e.deleted) {
    return e.implied
        ? 'Будет удалено (освобождает день для записи из копии)'
        : 'Будет удалено (появилось после копии)';
  }
  final current = e.current;
  if (current == null || current.deleted) return 'Будет восстановлено';
  return 'Будет возвращено как в копии';
}

/// Имена сотрудников из копии и из текущих данных (текущие — главнее).
Map<String, String> employeeNames(DataSnapshot then, DataSnapshot now) => {
  for (final s in [then, now])
    for (final e in s.rows('employees'))
      e.uuid: e.data['full_name'] as String? ?? '—',
};
