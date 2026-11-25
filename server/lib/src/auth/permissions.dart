import 'package:kfh_domain/kfh_domain.dart';

import 'users.dart';

/// Права ролей на таблицы синхронизации — правило домена
/// ([roleReadableTables], [roleWritableTables], [roleHiddenColumns]): то же
/// знает программа (что догружать при смене роли на устройстве).
Set<String> writableTables(Role role) => roleWritableTables(role.name);

Set<String> readableTables(Role role) => roleReadableTables(role.name);

Set<String> hiddenColumns(Role role, String table) =>
    roleHiddenColumns(role.name, table);

/// Запись выдаётся роли: оператору — только его операции финансов,
/// продавцу — оплаты заказов и свои операции (11.6).
bool rowVisible(User user, SyncChange row) {
  if (row.table != 'fin_operations') return true;
  final createdBy = row.data['created_by'] as String?;
  return switch (user.role) {
    Role.operator => operatorSeesOperation(createdBy, user.uuid),
    Role.sales => salesSeesOperation(
      row.data['source_ref'] as String?,
      createdBy,
      user.uuid,
    ),
    _ => true,
  };
}
