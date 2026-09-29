// lib/widgets/month_switcher.dart
//
// Переключатель месяца в строке заголовка экрана (табель, отчёты): ‹ месяц
// (с отметкой «закрыт», нажатие — выбор месяца) › и «текущий месяц». На
// широком окне стоит справа, после заголовка экрана; на телефоне заменяет
// заголовок (название раздела видно в нижней навигации) и становится
// плотнее.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'closed_month.dart';

class MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  /// Узкий экран: переключатель вместо заголовка.
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppTheme.compactWidth;

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    final name = DateFormat('LLLL yyyy', 'ru').format(month);
    final title = name.substring(0, 1).toUpperCase() + name.substring(1);
    final density = compact ? VisualDensity.compact : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          visualDensity: density,
          onPressed: onPrevious,
          tooltip: 'Предыдущий месяц',
        ),
        Flexible(
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 12,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ClosedMonthBadge(
                    year: month.year,
                    month: month.month,
                    compact: compact,
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          visualDensity: density,
          onPressed: onNext,
          tooltip: 'Следующий месяц',
        ),
        IconButton(
          icon: const Icon(Icons.today),
          visualDensity: density,
          onPressed: onToday,
          tooltip: 'Текущий месяц',
        ),
      ],
    );
  }
}

/// Строка заголовка экрана с переключателем месяца: широкое окно —
/// заголовок слева, переключатель и [actions] справа; телефон —
/// переключатель вместо заголовка, [actions] справа.
AppBar monthAppBar(
  BuildContext context, {
  required String title,
  required MonthSwitcher switcher,
  List<Widget> actions = const [],
}) {
  if (MonthSwitcher.isCompact(context)) {
    return AppBar(
      titleSpacing: 0,
      centerTitle: false,
      title: Align(alignment: Alignment.centerLeft, child: switcher),
      actions: [...actions, const SizedBox(width: 4)],
    );
  }
  return AppBar(
    title: Text(title),
    centerTitle: false,
    actions: [switcher, ...actions, const SizedBox(width: 8)],
  );
}
