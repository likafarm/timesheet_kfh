import 'package:kfh_domain/kfh_domain.dart';

import 'users.dart';

/// Права ролей на таблицы синхронизации — правило домена
/// ([roleReadableTables], [roleWritableTables], [roleHiddenColumns]): то же
/// знает программа (что догружать при смене роли на устройстве).
Set<String> writableTables(Role role) => roleWritableTables(role.name);

Set<String> readableTables(Role role) => roleReadableTables(role.name);

Set<String> hiddenColumns(Role role, String table) =>
    roleHiddenColumns(role.name, table);

/// Запись выдаётся роли: оператору — только его операции финансов.
bool rowVisible(User user, SyncChange row) =>
    user.role != Role.operator ||
    row.table != 'fin_operations' ||
    operatorSeesOperation(row.data['created_by'] as String?, user.uuid);
