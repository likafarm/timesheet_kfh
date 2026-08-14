// lib/utils/string_utils.dart

/// Утилиты для работы со строками
class StringUtils {
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
}
