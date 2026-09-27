import 'dart:convert';

import 'package:mysql_client_plus/mysql_client_plus.dart';

/// Чтение значений строки результата. `colByName` драйвера возвращает
/// dynamic: столбцы с флагом BINARY — в том числе строки со сравнением
/// `_bin` (наши uuid, хэши) и `information_schema` — приходят байтами,
/// JSON — уже разобранным. Читать только через эти методы.
extension RowValues on ResultSetRow {
  /// Значение как текст; NULL — null.
  String? text(String column) {
    final value = colByName(column);
    return switch (value) {
      null => null,
      String s => s,
      List<int> bytes => utf8.decode(bytes),
      Map() || List() => jsonEncode(value),
      _ => value.toString(),
    };
  }

  /// Значение, которое не может быть NULL.
  String textOf(String column) =>
      text(column) ?? (throw StateError('NULL в столбце $column'));

  int intOf(String column) => int.parse(textOf(column));
}

/// Момент времени для параметра SQL: `гггг-мм-дд чч:мм:сс.ffffff` в UTC
/// (DATETIME(6)). Драйвер подставил бы `DateTime.toString()` с `Z`,
/// который MySQL не принимает.
String sqlDateTime(DateTime value) {
  final u = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final micros = (u.millisecond * 1000 + u.microsecond).toString().padLeft(6, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)} '
      '${two(u.hour)}:${two(u.minute)}:${two(u.second)}.$micros';
}

/// DATETIME из MySQL (всегда UTC — см. `time_zone` пула) в `DateTime` UTC.
DateTime parseSqlDateTime(String value) =>
    DateTime.parse('${value.replaceFirst(' ', 'T')}Z');

DateTime? parseSqlDateTimeOrNull(String? value) =>
    value == null ? null : parseSqlDateTime(value);

/// TINYINT(1) из MySQL.
bool parseSqlBool(String? value) => value == '1';
