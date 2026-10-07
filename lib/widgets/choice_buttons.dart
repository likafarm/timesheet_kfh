// lib/widgets/choice_buttons.dart
//
// Выбор кнопками вместо выпадающих списков (решение владельца 2026-10-06):
// выбранная кнопка залита своим цветом, остальные — контурные. Отметки
// табеля (DayMarkButton), тип и способ выплаты.

import 'package:flutter/material.dart';

/// Одна кнопка выбора.
class ChoiceButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onPressed;

  /// Компьютер: кнопки ниже и уже, чтобы строка была в одну линию.
  final bool dense;

  /// Подсказка при наведении.
  final String? tooltip;

  const ChoiceButton({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onPressed,
    this.dense = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final size = dense ? const Size(64, 36) : const Size(76, 48);
    final padding = EdgeInsets.symmetric(horizontal: dense ? 8 : 10);
    final text = Text(label, style: const TextStyle(fontSize: 14));
    final Widget button;
    if (selected) {
      button = FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          minimumSize: size,
          padding: padding,
        ),
        onPressed: onPressed,
        child: text,
      );
    } else {
      button = OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          minimumSize: size,
          padding: padding,
        ),
        onPressed: onPressed,
        child: text,
      );
    }
    final hint = tooltip;
    return hint == null ? button : Tooltip(message: hint, child: button);
  }
}

/// Вариант выбора: значение, подпись, цвет.
class ChoiceOption<T> {
  final T value;
  final String label;
  final Color color;

  const ChoiceOption(this.value, this.label, this.color);
}

/// Подпись поля и ряд кнопок; выбрана одна — [value].
class ChoiceGroup<T> extends StatelessWidget {
  final String label;
  final List<ChoiceOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;

  const ChoiceGroup({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final changed = onChanged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in options)
              ChoiceButton(
                label: o.label,
                color: o.color,
                selected: o.value == value,
                dense: true,
                onPressed: changed == null ? null : () => changed(o.value),
              ),
          ],
        ),
      ],
    );
  }
}
