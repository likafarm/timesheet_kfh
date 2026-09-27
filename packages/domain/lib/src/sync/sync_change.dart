import 'sync_tables.dart';

/// Изменение пришло в неверном формате. [message] — для человека.
class SyncFormatException implements Exception {
  final String message;
  SyncFormatException(this.message);

  @override
  String toString() => 'SyncFormatException: $message';
}

final _uuidPattern =
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Строка — uuid в каноническом виде (строчные hex).
bool isCanonicalUuid(Object? value) =>
    value is String && _uuidPattern.hasMatch(value);

/// Строка — существующий день `гггг-мм-дд`.
bool isIsoDay(Object? value) {
  if (value is! String || !_datePattern.hasMatch(value)) return false;
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null) return false;
  // DateTime.parse переносит 2026-02-30 на март — такое не принимаем.
  final back = '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  return back == value;
}

/// Момент `updated_at` в обмене: ISO 8601 в UTC с `Z`, до микросекунд.
DateTime parseSyncTimestamp(Object? value) {
  if (value is! String || !value.endsWith('Z')) {
    throw SyncFormatException('updated_at должен быть временем UTC '
        'в формате ISO 8601 с Z');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw SyncFormatException('updated_at не разобран: $value');
  }
  return parsed;
}

String formatSyncTimestamp(DateTime value) => value.toUtc().toIso8601String();

/// Одна запись в обмене клиент ↔ сервер: полный снимок строки.
///
/// Удаление мягкое — это та же запись с `deleted: true`, поэтому данные
/// передаются всегда полностью (и при удалении тоже).
class SyncChange {
  final String table;
  final String uuid;
  final DateTime updatedAt;
  final bool deleted;

  /// Все колонки таблицы из [SyncTable.columns] (и только они).
  final Map<String, Object?> data;

  /// Кто изменил запись (id устройства). В изменении от клиента сервер
  /// берёт его из заголовка, а не из тела.
  final String? editedBy;

  /// Номер изменения у клиента — сервер возвращает его в ответе, чтобы
  /// клиент сопоставил результат со своей очередью.
  final String? changeId;

  SyncChange({
    required this.table,
    required this.uuid,
    required DateTime updatedAt,
    required this.deleted,
    required this.data,
    this.editedBy,
    this.changeId,
  }) : updatedAt = updatedAt.toUtc();

  /// Разбор и проверка изменения. Ошибка — [SyncFormatException] с
  /// понятной причиной.
  factory SyncChange.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw SyncFormatException('изменение должно быть объектом');
    }
    final tableName = json['table'];
    final table = tableName is String ? syncTableByName(tableName) : null;
    if (table == null) {
      throw SyncFormatException('неизвестная таблица: $tableName');
    }
    final uuid = json['uuid'];
    if (!isCanonicalUuid(uuid)) {
      throw SyncFormatException('uuid записи не в каноническом виде: $uuid');
    }
    final deleted = json['deleted'];
    if (deleted is! bool) {
      throw SyncFormatException('deleted должно быть true или false');
    }
    final changeId = json['change_id'];
    if (changeId != null && (changeId is! String || changeId.length > 64)) {
      throw SyncFormatException('change_id — строка до 64 символов');
    }
    final editedBy = json['edited_by'];
    if (editedBy != null && editedBy is! String) {
      throw SyncFormatException('edited_by должно быть строкой');
    }
    return SyncChange(
      table: table.name,
      uuid: uuid as String,
      updatedAt: parseSyncTimestamp(json['updated_at']),
      deleted: deleted,
      data: validateSyncData(table, json['data']),
      editedBy: editedBy as String?,
      changeId: changeId as String?,
    );
  }

  Map<String, Object?> toJson() => {
        if (changeId != null) 'change_id': changeId,
        'table': table,
        'uuid': uuid,
        'updated_at': formatSyncTimestamp(updatedAt),
        'deleted': deleted,
        if (editedBy != null) 'edited_by': editedBy,
        'data': data,
      };
}

/// Проверяет данные записи по описанию таблицы и возвращает их копию.
/// Целые, пришедшие как `5.0`, и вещественные, пришедшие как `5`,
/// приводятся к нужному типу.
Map<String, Object?> validateSyncData(SyncTable table, Object? data) {
  if (data is! Map<String, Object?>) {
    throw SyncFormatException('data должно быть объектом');
  }
  final unknown = data.keys.where((k) => table.column(k) == null).toList();
  if (unknown.isNotEmpty) {
    throw SyncFormatException(
        '${table.name}: неизвестные поля ${unknown.join(', ')}');
  }
  final result = <String, Object?>{};
  for (final column in table.columns) {
    if (!data.containsKey(column.name)) {
      throw SyncFormatException('${table.name}: нет поля ${column.name}');
    }
    result[column.name] = _checkValue(table, column, data[column.name]);
  }
  return result;
}

Object? _checkValue(SyncTable table, SyncColumn column, Object? value) {
  final where = '${table.name}.${column.name}';
  if (value == null) {
    if (column.nullable) return null;
    throw SyncFormatException('$where не может быть пустым');
  }
  switch (column.type) {
    case SyncType.text:
      if (value is! String) throw SyncFormatException('$where — не строка');
      final max = column.maxLength;
      if (max != null && value.length > max) {
        throw SyncFormatException('$where длиннее $max символов');
      }
      final allowed = column.allowed;
      if (allowed != null && !allowed.contains(value)) {
        throw SyncFormatException('$where: недопустимое значение «$value»');
      }
      return value;
    case SyncType.uuid:
      if (!isCanonicalUuid(value)) {
        throw SyncFormatException('$where — не uuid: $value');
      }
      return value;
    case SyncType.date:
      if (!isIsoDay(value)) {
        throw SyncFormatException('$where — не день гггг-мм-дд: $value');
      }
      return value;
    case SyncType.real:
      if (value is! num || !value.isFinite) {
        throw SyncFormatException('$where — не число');
      }
      _checkRange(where, column, value);
      return value.toDouble();
    case SyncType.integer:
      if (value is! num || value != value.roundToDouble() || !value.isFinite) {
        throw SyncFormatException('$where — не целое число');
      }
      _checkRange(where, column, value);
      return value.toInt();
    case SyncType.boolean:
      if (value is! bool) throw SyncFormatException('$where — не true/false');
      return value;
  }
}

void _checkRange(String where, SyncColumn column, num value) {
  final min = column.min, max = column.max;
  if ((min != null && value < min) || (max != null && value > max)) {
    throw SyncFormatException('$where вне границ ${min ?? ''}…${max ?? ''}: '
        '$value');
  }
}
