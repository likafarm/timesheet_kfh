import 'failures.dart';

/// Запись журнала действий сервера (6.7).
class AuditEntry {
  final int id;
  final DateTime at;
  final String? userUuid;
  final String? userLogin;
  final String? userName;
  final String? deviceId;

  /// `sync_insert`, `sync_update`, `sync_delete`, `payroll_auto_save`,
  /// `period_lock`, `login`, …
  final String action;

  /// Таблица (`timesheet`, `payments`, …), null — не про запись.
  final String? entity;
  final String? entityUuid;
  final String? employeeUuid;
  final String? employeeName;

  /// Данные до и после (null — записи не было / не стало).
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;

  const AuditEntry({
    required this.id,
    required this.at,
    required this.action,
    this.userUuid,
    this.userLogin,
    this.userName,
    this.deviceId,
    this.entity,
    this.entityUuid,
    this.employeeUuid,
    this.employeeName,
    this.before,
    this.after,
  });

  factory AuditEntry.fromJson(Object? json) {
    if (json is! Map) throw ServerFailure('неверная запись журнала');
    Map<String, Object?>? map(Object? v) =>
        v is Map ? v.cast<String, Object?>() : null;
    final at = DateTime.tryParse('${json['at']}');
    if (json['id'] is! int || at == null || json['action'] is! String) {
      throw ServerFailure('неверная запись журнала');
    }
    return AuditEntry(
      id: json['id'] as int,
      at: at,
      action: json['action'] as String,
      userUuid: json['user_uuid'] as String?,
      userLogin: json['user_login'] as String?,
      userName: json['user_name'] as String?,
      deviceId: json['device_id'] as String?,
      entity: json['entity'] as String?,
      entityUuid: json['entity_uuid'] as String?,
      employeeUuid: json['employee_uuid'] as String?,
      employeeName: json['employee_name'] as String?,
      before: map(json['old']),
      after: map(json['new']),
    );
  }
}

/// Страница журнала: записи новые сверху; [nextBefore] — курсор следующей
/// (null — дальше записей нет).
class AuditPage {
  final List<AuditEntry> entries;
  final int? nextBefore;

  const AuditPage(this.entries, this.nextBefore);

  factory AuditPage.fromJson(Map<String, Object?> json) {
    final list = json['entries'];
    if (list is! List) throw ServerFailure('нет записей журнала');
    return AuditPage([
      for (final e in list) AuditEntry.fromJson(e),
    ], json['next_before'] as int?);
  }
}
