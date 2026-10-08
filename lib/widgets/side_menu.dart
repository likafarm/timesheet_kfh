// lib/widgets/side_menu.dart
//
// Боковое меню широкого окна (8Б.1): тёмная панель с группами «Финансы»,
// «Зарплата», «Сервис» (UI_REQUIREMENTS п. 2.2). Группа сворачивается
// нажатием на заголовок; выбранный пункт свёрнутой группы остаётся виден.
// Узкое окно (меньше [wideWidth]) — только значки с подсказками.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'section_navigation.dart';

class SideMenu extends StatefulWidget {
  final List<NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const SideMenu({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Окно, с которого меню показывает подписи.
  static const wideWidth = 900.0;

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  final _collapsed = <NavGroup>{};

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= SideMenu.wideWidth;
    final children = <Widget>[];
    NavGroup? group;
    for (final (i, item) in widget.items.indexed) {
      if (item.group != group) {
        group = item.group;
        if (group != null) children.add(_header(group, wide));
      }
      final hidden =
          item.group != null &&
          _collapsed.contains(item.group) &&
          i != widget.selectedIndex;
      if (!hidden) children.add(_item(i, item, wide));
    }
    return Material(
      color: AppTheme.navigationBackground,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: wide ? 224 : 72,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _header(NavGroup group, bool wide) {
    final collapsed = _collapsed.contains(group);
    void toggle() => setState(
      () => collapsed ? _collapsed.remove(group) : _collapsed.add(group),
    );
    if (!wide) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Divider(color: AppTheme.navigationForeground, height: 1),
      );
    }
    return InkWell(
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                group.title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.navigationForeground,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              size: 18,
              color: AppTheme.navigationForeground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(int index, NavigationItem item, bool wide) {
    final selected = index == widget.selectedIndex;
    final color = selected
        ? AppTheme.navigationSelected
        : AppTheme.navigationForeground;
    final icon = Icon(
      selected ? item.selectedIcon : item.icon,
      color: color,
      size: 22,
    );
    final tile = Material(
      color: selected ? AppTheme.primaryColor : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => widget.onSelected(index),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 12 : 0,
            vertical: 10,
          ),
          child: wide
              ? Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                        // От стиля темы: в вебе — шрифт программы (Roboto).
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: color,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(child: icon),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: wide ? tile : Tooltip(message: item.label, child: tile),
    );
  }
}
