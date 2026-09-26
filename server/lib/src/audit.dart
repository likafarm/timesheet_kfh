import 'dart:convert';

import 'auth/users.dart';

/// Запись в журнал действий `audit_log`. Пишется в той же транзакции,
/// что и само действие: нет действия без записи и записи без действия.
///
/// Значения — JSON; пароли и их хэши туда не попадают (см. `User.toJson`).
Future<void> writeAudit(
  SqlExecutor sql, {
  required String action,
  String? userUuid,
  String? deviceId,
  String? requestId,
  String? entity,
  String? entityUuid,
  Object? oldValue,
  Object? newValue,
}) =>
    sql(
        'INSERT INTO audit_log (user_uuid, device_id, request_id, action, '
        'entity, entity_uuid, old_value, new_value) VALUES (:user, :device, '
        ':request, :action, :entity, :entity_uuid, :old, :new)',
        {
          'user': userUuid,
          'device': deviceId,
          'request': requestId,
          'action': action,
          'entity': entity,
          'entity_uuid': entityUuid,
          'old': oldValue == null ? null : jsonEncode(oldValue),
          'new': newValue == null ? null : jsonEncode(newValue),
        });
