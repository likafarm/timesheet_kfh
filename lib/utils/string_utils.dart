// lib/utils/string_utils.dart

import 'package:intl/intl.dart';

/// Утилиты для работы со строками
class StringUtils {
  static final _rateFormat = NumberFormat('#,##0.##', 'ru');

  /// Преобразует полное ФИО в формат "Фамилия И.О." (с пробелом между инициалами)
  static String getShortName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return fullName;
    if (parts.length == 1) return parts[0];
    final surname = parts[0];
    final initials = parts
        .skip(1)
        .map((p) => p.isNotEmpty ? '${p[0]}.' : '')
        .join(' ');
    return '$surname $initials';
  }

  static String formatDayRate(double? value) {
    if (value == null) return 'нет ставки';
    return '${_rateFormat.format(value)} ₽/день';
  }

  static String workPlaceLabel(
    String place, {
    double? baseRate,
    double? fieldRate,
  }) {
    switch (place) {
      case 'base':
        return 'База (${formatDayRate(baseRate)})';
      case 'field':
        return 'Поле (${formatDayRate(fieldRate)})';
      default:
        return place;
    }
  }
}
