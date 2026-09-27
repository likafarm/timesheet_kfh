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
