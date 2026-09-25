/// Календарная дата для экрана и БД: хранение ISO `гггг-мм-дд`.
String formatDateIso(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String? formatDateIsoOrNull(DateTime? date) =>
    date == null ? null : formatDateIso(date);

/// Читает `гггг-мм-дд` и старые значения с временем (`гггг-мм-ддT…`).
DateTime parseDateIso(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Пустая дата', value);
  }
  final datePart = trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
  return DateTime.parse(datePart);
}

DateTime? parseDateIsoOrNull(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return parseDateIso(value);
}

String? dateOnlyString(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final trimmed = value.trim();
  return trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
}

/// Полуинтервал [start, end] включительно как `[start, nextDay)`.
(String, String) dateRangeExclusiveEnd(DateTime start, DateTime end) {
  final startStr = formatDateIso(start);
  final next = DateTime(
    end.year,
    end.month,
    end.day,
  ).add(const Duration(days: 1));
  return (startStr, formatDateIso(next));
}
