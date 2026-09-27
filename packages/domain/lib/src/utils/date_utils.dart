// Календарные дни.
//
// День в программе — местная полночь (`DateTime(год, месяц, число)`), в
// базе — строка `гггг-мм-дд`. Момент времени в UTC (с `Z`) — это не день:
// его день — по местному календарю (00:30 по Москве = 21:30Z вчерашнего
// числа, но день — сегодняшний).
//
// Сдвигать дни — только через конструктор (`DateTime(г, м, д + 1)`), а не
// прибавлением `Duration(days: 1)`: в день перехода на летнее/зимнее время
// в сутках 23 или 25 часов, и от местной полуночи «+24 часа» попадает не в
// тот день.

/// Календарный день значения: местная полночь того же числа. Момент в UTC
/// сначала переводится в местное время.
DateTime calendarDay(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  return DateTime(local.year, local.month, local.day);
}

/// День, отстоящий от [day] на [days] календарных дней.
DateTime addCalendarDays(DateTime day, int days) {
  final d = calendarDay(day);
  return DateTime(d.year, d.month, d.day + days);
}

/// Календарная дата для экрана и БД: хранение ISO `гггг-мм-дд`.
String formatDateIso(DateTime date) {
  final local = calendarDay(date);
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String? formatDateIsoOrNull(DateTime? date) =>
    date == null ? null : formatDateIso(date);

final _zoned = RegExp(r'T.*(Z|[+-]\d{2}:?\d{2})$');

/// Читает `гггг-мм-дд` и старые значения с временем (`гггг-мм-ддT…`).
/// Время без пояса — местное, берётся его число. Момент с поясом (`Z`,
/// `+03:00`) переводится в местное время: `2026-08-31T21:30:00Z` по Москве —
/// это 01.09.
DateTime parseDateIso(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Пустая дата', value);
  }
  if (_zoned.hasMatch(trimmed)) {
    return calendarDay(DateTime.parse(trimmed));
  }
  final datePart = trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
  return DateTime.parse(datePart);
}

DateTime? parseDateIsoOrNull(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return parseDateIso(value);
}

/// День `гггг-мм-дд` из значения с временем или без (правила — как у
/// [parseDateIso]). Неразборчивое значение возвращается обрезанным как
/// есть — решать, ошибка ли это, вызывающему (конвертер старой базы
/// записывает такие в проблемы).
String? dateOnlyString(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  try {
    return formatDateIso(parseDateIso(value));
  } on FormatException {
    final trimmed = value.trim();
    return trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
  }
}

/// Полуинтервал [start, end] включительно как `[start, nextDay)`.
(String, String) dateRangeExclusiveEnd(DateTime start, DateTime end) =>
    (formatDateIso(start), formatDateIso(addCalendarDays(end, 1)));
