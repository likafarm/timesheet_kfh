import 'package:kfh_domain/kfh_domain.dart';

/// Что произошло.
enum JournalKind {
  /// Локальная правка уступила более поздней (или одновременной) с сервера.
  lost,

  /// Локальная запись уступила записи с тем же днём/месяцем, пришедшей на
  /// сервер раньше.
  lostUnique,

  /// Сервер не принял изменение (месяц закрыт, нет прав…).
  rejected,

  /// Данные сервера восстановлены из копии или база разошлась — всё
  /// принято с сервера заново.
  resync,
}

/// Запись журнала синхронизации — для человека и для разбора.
class JournalEntry {
  final DateTime at;
  final JournalKind kind;
  final String? table;
  final String? uuid;

  /// Понятное описание по-русски.
  final String message;

  /// Потерянная версия записи (для [JournalKind.lost]/[JournalKind.lostUnique]
  /// и отклонённая — для [JournalKind.rejected]).
  final Map<String, Object?>? local;

  /// Победившая серверная версия, если известна.
  final Map<String, Object?>? remote;

  /// Код отказа сервера.
  final String? code;

  JournalEntry({
    required DateTime at,
    required this.kind,
    required this.message,
    this.table,
    this.uuid,
    this.local,
    this.remote,
    this.code,
  }) : at = at.toUtc();

  factory JournalEntry.fromJson(Map<String, Object?> json) => JournalEntry(
    at: DateTime.parse(json['at'] as String),
    kind: JournalKind.values.byName(json['kind'] as String),
    message: json['message'] as String? ?? '',
    table: json['table'] as String?,
    uuid: json['uuid'] as String?,
    code: json['code'] as String?,
    local: json['local'] as Map<String, Object?>?,
    remote: json['remote'] as Map<String, Object?>?,
  );

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'kind': kind.name,
    'message': message,
    'table': ?table,
    'uuid': ?uuid,
    'code': ?code,
    'local': ?local,
    'remote': ?remote,
  };
}

/// Куда пишется журнал. В приложении — файл рядом с базой.
abstract class SyncJournal {
  Future<void> add(List<JournalEntry> entries);

  /// Последние записи, новые сверху.
  Future<List<JournalEntry>> recent({int limit = 200});
}

/// Журнал в памяти — для тестов.
class MemorySyncJournal implements SyncJournal {
  final List<JournalEntry> entries = [];

  @override
  Future<void> add(List<JournalEntry> entries) async =>
      this.entries.addAll(entries);

  @override
  Future<List<JournalEntry>> recent({int limit = 200}) async =>
      entries.reversed.take(limit).toList();
}

/// Названия таблиц для сообщений.
String tableTitle(String table) => switch (table) {
  'company_settings' => 'Настройки хозяйства',
  'employees' => 'Сотрудник',
  'employee_rates' => 'Ставка',
  'timesheet' => 'Табель',
  'payments' => 'Выплата',
  'sick_leave' => 'Больничный',
  'vacation' => 'Отпуск',
  'payroll_results' => 'Расчёт ЗП',
  _ => table,
};

/// Снимок записи для журнала.
Map<String, Object?> journalSnapshot(SyncChange change) => {
  'updated_at': formatSyncTimestamp(change.updatedAt),
  'deleted': change.deleted,
  'edited_by': ?change.editedBy,
  ...change.data,
};
