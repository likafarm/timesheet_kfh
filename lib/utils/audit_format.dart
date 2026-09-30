// lib/utils/audit_format.dart
//
// Журнал действий (6.7) человеческим языком: что сделано, с чем, и какие
// поля как изменились («было → стало»). Служебные поля (id, отметки
// времени, uuid сотрудника) не показываются.

import 'package:intl/intl.dart';
import 'package:kfh_sync/kfh_sync.dart';

/// Изменившееся поле записи: подпись, было, стало (null — не было / нет).
typedef AuditFieldChange = ({String label, String? before, String? after});

/// Запись журнала для экрана.
class AuditView {
  /// «Изменено: табель», «Месяц закрыт», «Вход»…
  final String title;

  /// О чём запись: «Иванов Иван · 03.09.2026», «09.2026 «сдан»».
  final String? subject;

  /// Изменившиеся поля (для добавления и удаления — все значимые).
  final List<AuditFieldChange> changes;

  /// Действие важно заметить (удаление, неудачный вход, подозрение).
  final bool warning;

  const AuditView(
    this.title, {
    this.subject,
    this.changes = const [],
    this.warning = false,
  });
}

/// Виды записей для отбора — как в `GET /audit?kind=`.
const auditKindLabels = <String, String>{
  'timesheet': 'Табель',
  'payments': 'Выплаты',
  'rates': 'Ставки',
  'employees': 'Сотрудники',
  'payroll': 'Расчёты зарплаты',
  'periods': 'Закрытие месяцев',
  'settings': 'Реквизиты',
  'access': 'Входы и пользователи',
};

const _entity = {
  'timesheet': 'табель',
  'payments': 'выплата',
  'employee_rates': 'ставка',
  'employees': 'сотрудник',
  'payroll_results': 'расчёт зарплаты',
  'company_settings': 'реквизиты хозяйства',
};

/// Подписи полей по таблицам; поля не из списка не показываются.
const _fields = <String, Map<String, String>>{
  'timesheet': {
    'date': 'Дата',
    'day_type': 'Отметка',
    'days': 'Дней',
    'work_place': 'Место',
    'notes': 'Примечание',
  },
  'payments': {
    'payment_date': 'Дата',
    'amount': 'Сумма',
    'payment_type': 'Вид',
    'payment_method': 'Способ',
    'period_start': 'Период с',
    'period_end': 'Период по',
    'document_number': 'Документ',
    'notes': 'Примечание',
  },
  'employee_rates': {
    'base_rate': 'Ставка база',
    'field_rate': 'Ставка поле',
    'start_date': 'Действует с',
    'end_date': 'Действует по',
  },
  'employees': {
    'full_name': 'ФИО',
    'position': 'Должность',
    'hire_date': 'Принят',
    'dismissal_date': 'Уволен',
    'base_rate': 'Ставка база',
    'field_rate': 'Ставка поле',
  },
  'payroll_results': {
    'base_days': 'Дней база',
    'field_days': 'Дней поле',
    'sick_days': 'Больничный',
    'vacation_days': 'Отпуск',
    'skipped_work_days': 'Дней без ставки',
    'total_salary': 'Начислено',
  },
  'company_settings': {
    'company_name': 'Название',
    'director_name': 'Руководитель',
    'inn': 'ИНН',
    'ogrn': 'ОГРН',
    'bank_account': 'Расчётный счёт',
    'bank_name': 'Банк',
    'legal_address': 'Адрес',
    'phone': 'Телефон',
  },
};

const _money = {'amount', 'base_rate', 'field_rate', 'total_salary'};
const _values = <String, Map<String, String>>{
  'day_type': {
    'work': 'Работа',
    'sick': 'Больничный',
    'vacation': 'Отпуск',
    'dayoff': 'Выходной',
  },
  'work_place': {'base': 'База', 'field': 'Поле'},
  'payment_type': {'salary': 'Зарплата', 'advance': 'Аванс', 'bonus': 'Премия'},
  'payment_method': {
    'cash': 'Наличные',
    'card': 'На карту',
    'transfer': 'Перевод',
  },
};

final _rub = NumberFormat('#,##0.00', 'ru');
final _num = NumberFormat('#,##0.##', 'ru');

String _day(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : DateFormat('dd.MM.yyyy').format(d);
}

String? _format(String field, Object? v) {
  if (v == null || (v is String && v.isEmpty)) return null;
  final named = _values[field]?[v];
  if (named != null) return named;
  if (v is num) {
    return _money.contains(field) ? '${_rub.format(v)} ₽' : _num.format(v);
  }
  if (v is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
    return _day(v);
  }
  return '$v';
}

String _month(Map<String, Object?>? v) {
  final y = v?['year'], m = v?['month'];
  return y is int && m is int ? '${m.toString().padLeft(2, '0')}.$y' : '';
}

/// Поля записи, которые стали другими (добавление — все непустые,
/// удаление — все бывшие).
List<AuditFieldChange> auditChanges(
  String entity,
  Map<String, Object?>? before,
  Map<String, Object?>? after,
) {
  final labels = _fields[entity] ?? const {};
  return [
    for (final MapEntry(key: field, value: label) in labels.entries)
      if (_format(field, before?[field]) != _format(field, after?[field]))
        (
          label: label,
          before: _format(field, before?[field]),
          after: _format(field, after?[field]),
        ),
  ];
}

AuditView describeAudit(AuditEntry e) {
  final entity = e.entity;
  final label = _entity[entity];
  final before = e.before, after = e.after;
  final data = after ?? before;
  String? subject() {
    final parts = <String>[
      ?e.employeeName,
      switch (entity) {
        'timesheet' => _day('${data?['date'] ?? ''}'),
        'payments' => _day('${data?['payment_date'] ?? ''}'),
        'payroll_results' => _month(data),
        'employee_rates' => 'с ${_day('${data?['start_date'] ?? ''}')}',
        _ => '',
      },
    ]..removeWhere((p) => p.isEmpty);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  // Правки через синхронизацию: удаление мягкое — «стало deleted».
  if (e.action.startsWith('sync_') && label != null) {
    final removed = e.action == 'sync_delete' || after?['deleted'] == true;
    final restored = before?['deleted'] == true && after?['deleted'] == false;
    final (verb, changes) = e.action == 'sync_insert'
        ? ('Добавлено', auditChanges(entity!, null, after))
        : removed
        ? ('Удалено', auditChanges(entity!, before, null))
        : restored
        ? ('Восстановлено', auditChanges(entity!, null, after))
        : ('Изменено', auditChanges(entity!, before, after));
    return AuditView(
      '$verb: $label',
      subject: subject(),
      changes: changes,
      warning: removed,
    );
  }
  switch (e.action) {
    case 'payroll_auto_save' || 'payroll_save':
      return AuditView(
        e.action == 'payroll_auto_save'
            ? 'Пересчёт зарплаты (автоматически)'
            : 'Расчёт зарплаты сохранён',
        subject: subject(),
        changes: auditChanges('payroll_results', before, after),
      );
    case 'payroll_auto_delete' || 'payroll_delete':
      return AuditView(
        'Расчёт зарплаты убран (нет начислений, выплат и остатка)',
        subject: subject(),
      );
    case 'period_lock':
      final note = after?['note'];
      return AuditView(
        'Месяц закрыт',
        subject: '${_month(after)}${note == null ? '' : ' «$note»'}',
      );
    case 'period_unlock':
      return AuditView('Месяц открыт', subject: _month(before), warning: true);
    case 'login':
      return const AuditView('Вход');
    case 'login_failed':
      return AuditView(
        'Неудачный вход',
        subject: after?['login'] as String?,
        warning: true,
      );
    case 'logout':
      return const AuditView('Выход');
    case 'password_change':
      return const AuditView('Смена пароля');
    case 'password_reset':
      return AuditView(
        'Пароль сброшен администратором',
        subject: (after ?? before)?['login'] as String?,
        warning: true,
      );
    case 'user_create':
      return AuditView('Новый пользователь', subject: _user(after));
    case 'user_update':
      return AuditView('Изменён пользователь', subject: _user(after ?? before));
    case 'token_reuse':
      return const AuditView(
        'Повторное использование входа — сеансы завершены (подозрение на '
        'утечку токена)',
        warning: true,
      );
    case 'import':
      return const AuditView('Импорт базы на сервер');
  }
  return AuditView(e.action, subject: subject());
}

String? _user(Map<String, Object?>? v) {
  if (v == null) return null;
  final name = v['full_name'], login = v['login'], role = v['role'];
  final roleName = switch (role) {
    'admin' => 'администратор',
    'accountant' => 'бухгалтер',
    'operator' => 'оператор',
    _ => null,
  };
  return [
    if (name is String) name,
    if (login is String) '($login)',
    ?roleName,
  ].join(' ');
}
