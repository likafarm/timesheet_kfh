// lib/widgets/day_mark_button.dart
//
// Кнопка отметки дня (База, Поле, ½ база, …): выбранная — залитая цветом
// отметки, остальные — контурные. Общая для ввода за день и окна ячейки
// табеля.

import 'package:flutter/material.dart';

import '../utils/day_draft.dart';
import 'choice_buttons.dart';

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
  Widget build(BuildContext context) => ChoiceButton(
    label: mark.label,
    color: mark.color,
    selected: selected,
    onPressed: onPressed,
    dense: dense,
    tooltip: tooltip,
  );
}
