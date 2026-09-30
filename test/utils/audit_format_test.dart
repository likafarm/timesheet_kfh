import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/utils/audit_format.dart';

/// Журнал действий (6.7) человеческим языком.
void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  AuditEntry entry(
    String action, {
    String? entity,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
    String? employee = 'Иванов Иван',
  }) => AuditEntry(
    id: 1,
    at: DateTime.utc(2026, 9, 29, 9),
    action: action,
    entity: entity,
    employeeName: employee,
    before: before,
    after: after,
  );

  final day = {
    'legacy_id': null,
    'employee_uuid': 'e1',
    'date': '2026-09-03',
    'day_type': 'work',
    'days': 1.0,
    'work_place': 'field',
    'notes': null,
    'created_at': '2026-09-03T10:00:00',
    'updated_at': '2026-09-03T10:00:00Z',
    'deleted': false,
  };

  test('правка табеля: только изменившиеся поля, значения по-русски', () {
    final v = describeAudit(
      entry(
        'sync_update',
        entity: 'timesheet',
        before: day,
        after: {
          ...day,
          'day_type': 'sick',
          'work_place': null,
          'updated_at': '2026-09-04T10:00:00Z',
        },
      ),
    );
    expect(v.title, 'Изменено: табель');
    expect(v.subject, 'Иванов Иван · 03.09.2026');
    expect(v.changes, [
      (label: 'Отметка', before: 'Работа', after: 'Больничный'),
      (label: 'Место', before: 'Поле', after: null),
    ]);
    expect(v.warning, isFalse);
  });

  test('добавление, мягкое удаление и восстановление', () {
    final added = describeAudit(
      entry('sync_insert', entity: 'timesheet', after: day),
    );
    expect(added.title, 'Добавлено: табель');
    expect(
      [for (final c in added.changes) c.label],
      ['Дата', 'Отметка', 'Дней', 'Место'],
    );

    final removed = describeAudit(
      entry(
        'sync_update',
        entity: 'timesheet',
        before: day,
        after: {...day, 'deleted': true},
      ),
    );
    expect((removed.title, removed.warning), ('Удалено: табель', true));
    expect(removed.changes.first, (
      label: 'Дата',
      before: '03.09.2026',
      after: null,
    ));

    final restored = describeAudit(
      entry(
        'sync_update',
        entity: 'timesheet',
        before: {...day, 'deleted': true},
        after: day,
      ),
    );
    expect(restored.title, 'Восстановлено: табель');
  });

  test('выплата и ставка: суммы в рублях', () {
    final v = describeAudit(
      entry(
        'sync_update',
        entity: 'payments',
        before: {
          'payment_date': '2026-09-05',
          'amount': 1000.0,
          'payment_type': 'salary',
        },
        after: {
          'payment_date': '2026-09-05',
          'amount': 1500.5,
          'payment_type': 'bonus',
        },
      ),
    );
    expect(v.subject, 'Иванов Иван · 05.09.2026');
    expect(v.changes, [
      (label: 'Сумма', before: '1 000,00 ₽', after: '1 500,50 ₽'),
      (label: 'Вид', before: 'Зарплата', after: 'Премия'),
    ]);
    final rate = describeAudit(
      entry(
        'sync_insert',
        entity: 'employee_rates',
        after: {
          'base_rate': 1200.0,
          'field_rate': 1800.0,
          'start_date': '2026-09-16',
          'end_date': null,
        },
      ),
    );
    expect(rate.subject, 'Иванов Иван · с 16.09.2026');
    expect(rate.changes.first.after, '1 200,00 ₽');
  });

  test('пересчёт зарплаты, закрытие месяца, входы', () {
    final payroll = describeAudit(
      entry(
        'payroll_auto_save',
        entity: 'payroll_results',
        before: {'year': 2026, 'month': 9, 'total_salary': 2000.0},
        after: {'year': 2026, 'month': 9, 'total_salary': 2500.0},
      ),
    );
    expect(payroll.title, 'Пересчёт зарплаты (автоматически)');
    expect(payroll.subject, 'Иванов Иван · 09.2026');
    expect(payroll.changes, [
      (label: 'Начислено', before: '2 000,00 ₽', after: '2 500,00 ₽'),
    ]);

    final lock = describeAudit(
      entry(
        'period_lock',
        entity: 'period_locks',
        after: {'year': 2026, 'month': 8, 'note': 'сдан'},
        employee: null,
      ),
    );
    expect((lock.title, lock.subject), ('Месяц закрыт', '08.2026 «сдан»'));
    final unlock = describeAudit(
      entry(
        'period_unlock',
        before: {'year': 2026, 'month': 8},
        employee: null,
      ),
    );
    expect((unlock.title, unlock.warning), ('Месяц открыт', true));

    final failed = describeAudit(
      entry(
        'login_failed',
        after: {'login': 'buh', 'ip': '1.2.3.4'},
        employee: null,
      ),
    );
    expect(
      (failed.title, failed.subject, failed.warning),
      ('Неудачный вход', 'buh', true),
    );
    final created = describeAudit(
      entry(
        'user_create',
        after: {'full_name': 'Бухгалтер', 'login': 'buh', 'role': 'accountant'},
        employee: null,
      ),
    );
    expect(created.subject, 'Бухгалтер (buh) бухгалтер');
  });

  test('неизвестное действие — как есть', () {
    expect(
      describeAudit(entry('something_new', employee: null)).title,
      'something_new',
    );
  });
}
