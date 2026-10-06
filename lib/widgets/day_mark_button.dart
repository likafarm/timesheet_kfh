// lib/widgets/day_mark_button.dart
//
// Кнопка отметки дня (База, Поле, ½ база, …): выбранная — залитая цветом
// отметки, остальные — контурные. Общая для ввода за день и окна ячейки
// табеля.

import 'package:flutter/material.dart';

import '../utils/day_draft.dart';

class DayMarkButton extends StatelessWidget {
  final DayMark mark;
  final bool selected;
  final VoidCallback? onPressed;

  /// Компьютер: кнопки ниже и уже, чтобы строка сотрудника была в одну
  /// линию.
  final bool dense;

  /// Подсказка при наведении (ставка, клавиша).
  final String? tooltip;

  const DayMarkButton({
    super.key,
    required this.mark,
    required this.selected,
    required this.onPressed,
    this.dense = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final size = dense ? const Size(64, 36) : const Size(76, 48);
    final padding = EdgeInsets.symmetric(horizontal: dense ? 8 : 10);
    final label = Text(mark.label, style: const TextStyle(fontSize: 14));
    final Widget button;
    if (selected) {
      button = FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: mark.color,
          disabledBackgroundColor: mark.color.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          minimumSize: size,
          padding: padding,
        ),
        onPressed: onPressed,
        child: label,
      );
    } else {
      button = OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: mark.color,
          minimumSize: size,
          padding: padding,
        ),
        onPressed: onPressed,
        child: label,
      );
    }
    final hint = tooltip;
    return hint == null ? button : Tooltip(message: hint, child: button);
  }
}
