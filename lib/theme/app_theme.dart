import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF2E7D32);
  static const Color secondaryColor = Color(0xFF1B5E20);
  static const Color accentColor = Color(0xFFFF6F00);

  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Colors.red;

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  /// Боковая навигация на широком экране — тёмная (UI_REQUIREMENTS п. 2.2).
  static const Color navigationBackground = Color(0xFF1E2B22);
  static const Color navigationForeground = Color(0xFFB8C7BC);
  static const Color navigationSelected = Colors.white;

  /// Уже этого — телефон: нижняя навигация, формы снизу экрана.
  static const double compactWidth = 600.0;

  static const double defaultRadius = 8.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;

  static final ThemeData lightTheme = _build(Brightness.light);

  // Сетка табеля — ниже, [TimesheetColors].
  static final ThemeData darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    ),
    useMaterial3: true,
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Цвета сетки табеля для светлой и тёмной темы: фон отметок, итогов,
/// выходных и сегодняшнего дня и текст поверх них. В тёмной теме фон
/// тёмный, текст светлый (светлый фон с белым текстом не читается).
class TimesheetColors {
  final Color work;
  final Color sick;
  final Color vacation;
  final Color dayoff;
  final Color total;
  final Color totalAlt;
  final Color weekend;
  final Color today;
  final Color weekendText;
  final Color text;
  final Color mutedText;
  final Color border;

  const TimesheetColors._({
    required this.work,
    required this.sick,
    required this.vacation,
    required this.dayoff,
    required this.total,
    required this.totalAlt,
    required this.weekend,
    required this.today,
    required this.weekendText,
    required this.text,
    required this.mutedText,
    required this.border,
  });

  static const _light = TimesheetColors._(
    work: Color(0xFFE8F5E9),
    sick: Color(0xFFE3F2FD),
    vacation: Color(0xFFF3E5F5),
    dayoff: Color(0xFFEEEEEE),
    total: Color(0xFFF5F5F5),
    totalAlt: Color(0xFFFAFAFA),
    weekend: Color(0xFFFFEBEE),
    today: Color(0xFFE3F2FD),
    weekendText: Color(0xFFC62828),
    text: Color(0xDD000000),
    mutedText: Color(0xFF757575),
    border: Color(0xFFE0E0E0),
  );

  static const _dark = TimesheetColors._(
    work: Color(0xFF1F3B25),
    sick: Color(0xFF1B3047),
    vacation: Color(0xFF362640),
    dayoff: Color(0xFF3A3A3A),
    total: Color(0xFF2B2B2B),
    totalAlt: Color(0xFF232323),
    weekend: Color(0xFF3E2323),
    today: Color(0xFF1B3047),
    weekendText: Color(0xFFFF8A80),
    text: Color(0xFFECECEC),
    mutedText: Color(0xFFB0B0B0),
    border: Color(0xFF4A4A4A),
  );

  static TimesheetColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}
