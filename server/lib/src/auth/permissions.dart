import 'package:kfh_domain/kfh_domain.dart';

import 'users.dart';

/// Права ролей на таблицы синхронизации (решение владельца 2026-09-26):
/// - оператор — табель и просмотр сотрудников (без их ставок); с 0.11.0 —
///   ещё свои расходы и доходы и справочники для них
///   ([operatorFinanceReadable]; чужие операции не выдаются — см.
///   [rowVisible]);
/// - бухгалтер — все данные (кроме пользователей);
/// - админ — всё.
final _allTables = {for (final t in syncTables) t.name};

Set<String> writableTables(Role role) => switch (role) {
      Role.admin || Role.accountant => _allTables,
      Role.operator => const {'timesheet', ...operatorFinanceWritable},
    };

Set<String> readableTables(Role role) => switch (role) {
      Role.admin || Role.accountant => _allTables,
      Role.operator => const {
          'employees',
          'timesheet',
          ...operatorFinanceReadable,
        },
    };

/// Поля, которые роль не видит: при выдаче заменяются нулём (пустые —
/// пустотой). Оператору ставки сотрудников, остатки кошельков и стоимость
/// имущества не нужны.
Set<String> hiddenColumns(Role role, String table) => role != Role.operator
    ? const {}
    : table == 'employees'
        ? const {'base_rate', 'field_rate'}
        : operatorFinanceHidden[table] ?? const {};

/// Запись выдаётся роли: оператору — только его операции финансов.
bool rowVisible(User user, SyncChange row) =>
    user.role != Role.operator ||
    row.table != 'fin_operations' ||
    operatorSeesOperation(row.data['created_by'] as String?, user.uuid);
