import 'package:kfh_domain/kfh_domain.dart';

import 'users.dart';

/// Права ролей на таблицы синхронизации (решение владельца 2026-09-26):
/// - оператор — табель и просмотр сотрудников (без их ставок);
/// - бухгалтер — все данные (кроме пользователей);
/// - админ — всё.
final _allTables = {for (final t in syncTables) t.name};

Set<String> writableTables(Role role) => switch (role) {
      Role.admin || Role.accountant => _allTables,
      Role.operator => const {'timesheet'},
    };

Set<String> readableTables(Role role) => switch (role) {
      Role.admin || Role.accountant => _allTables,
      Role.operator => const {'employees', 'timesheet'},
    };

/// Поля, которые роль не видит: при выдаче заменяются нулём. Оператору
/// ставки сотрудников не нужны.
Set<String> hiddenColumns(Role role, String table) =>
    role == Role.operator && table == 'employees'
        ? const {'base_rate', 'field_rate'}
        : const {};
