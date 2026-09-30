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

  /// Окно, где второстепенные кнопки строки заголовка не помещаются рядом с
  /// заголовком и переключателем (с учётом боковой панели) — они в меню «⋮».
  static const menuWidth = 900.0;

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

/// Второстепенное действие строки заголовка: на широком окне — кнопка, на
/// телефоне — пункт меню «⋮» (в строке не хватает места).
class AppBarMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const AppBarMenuItem(this.icon, this.label, this.onPressed);
}

/// Строка заголовка экрана с переключателем месяца: широкое окно —
/// заголовок слева, переключатель, [menu] и [actions] справа; окно уже
/// [MonthSwitcher.menuWidth] — [menu] уходит в меню «⋮»; телефон —
/// переключатель вместо заголовка.
AppBar monthAppBar(
  BuildContext context, {
  required String title,
  required MonthSwitcher switcher,
  List<Widget> actions = const [],
  List<AppBarMenuItem> menu = const [],
}) {
  final compact = MonthSwitcher.isCompact(context);
  if (compact || MediaQuery.sizeOf(context).width < MonthSwitcher.menuWidth) {
    return AppBar(
      titleSpacing: compact ? 0 : null,
      centerTitle: false,
      title: compact
          ? Align(alignment: Alignment.centerLeft, child: switcher)
          : Text(title, overflow: TextOverflow.ellipsis),
      actions: [
        if (!compact) switcher,
        ...actions,
        if (menu.isNotEmpty)
          PopupMenuButton<int>(
            tooltip: 'Ещё',
            itemBuilder: (context) => [
              for (final (i, m) in menu.indexed)
                PopupMenuItem(
                  value: i,
                  enabled: m.onPressed != null,
                  child: ListTile(
                    leading: Icon(m.icon),
                    title: Text(m.label),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
            onSelected: (i) => menu[i].onPressed?.call(),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
  return AppBar(
    title: Text(title),
    centerTitle: false,
    actions: [
      switcher,
      for (final m in menu)
        IconButton(
          icon: Icon(m.icon),
          tooltip: m.label,
          onPressed: m.onPressed,
        ),
      ...actions,
      const SizedBox(width: 8),
    ],
  );
}
