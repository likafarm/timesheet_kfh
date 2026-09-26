// lib/utils/cell_format.dart
//
// Показ и ввод значений в экранах просмотра базы и копий.
// В базе даты — строки ISO: день `гггг-мм-дд`, момент времени
// `гггг-мм-ддTчч:мм:сс[.доли][Z]`. На экране — `дд.мм.гггг`.

import 'package:intl/intl.dart';
import 'package:kfh_local_db/kfh_local_db.dart';

final _isoDay = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _isoMoment = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}');
final _ruDay = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$');

final _dayFormat = DateFormat('dd.MM.yyyy');
final _momentFormat = DateFormat('dd.MM.yyyy HH:mm:ss');

/// Значение ячейки для показа. Моменты времени в UTC — по местному времени.
String formatCell(Object? value) {
  if (value == null) return '—';
  if (value is String) {
    if (_isoDay.hasMatch(value)) {
      final day = DateTime.tryParse(value);
      if (day != null) return _dayFormat.format(day);
    }
    if (_isoMoment.hasMatch(value)) {
      final moment = DateTime.tryParse(value);
      if (moment != null) return _momentFormat.format(moment.toLocal());
    }
  }
  return value.toString();
}

/// Текст в поле правки. Дни — `дд.мм.гггг`, остальное как в базе.
String cellToInput(Object? value) {
  if (value == null) return '';
  if (value is String && _isoDay.hasMatch(value)) {
    final day = DateTime.tryParse(value);
    if (day != null) return _dayFormat.format(day);
  }
  return value.toString();
}

/// Значение для записи в колонку [column] из текста поля правки.
/// Пусто — null. Ошибка формата — [FormatException] с понятным текстом.
Object? parseCellInput(ColumnInfo column, String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  if (column.isDate) {
    final ru = _ruDay.firstMatch(t);
    DateTime? day;
    if (ru != null) {
      final d = int.parse(ru.group(1)!);
      final m = int.parse(ru.group(2)!);
      final y = int.parse(ru.group(3)!);
      final candidate = DateTime(y, m, d);
      // DateTime(2026, 2, 30) «перетекает» в март — такое не принимаем.
      if (candidate.year == y && candidate.month == m && candidate.day == d) {
        day = candidate;
      }
    } else if (_isoDay.hasMatch(t)) {
      day = DateTime.tryParse(t);
    }
    if (day == null) {
      throw FormatException('${column.name}: дата в формате дд.мм.гггг');
    }
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }
  switch (column.type) {
    case 'INTEGER':
      final v = int.tryParse(t);
      if (v == null) throw FormatException('${column.name}: целое число');
      return v;
    case 'REAL':
      final v = double.tryParse(t.replaceAll(',', '.').replaceAll(' ', ''));
      if (v == null) throw FormatException('${column.name}: число');
      return v;
    default:
      return t;
  }
}
